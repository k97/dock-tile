//! PDF rasterization via macOS CoreGraphics.
//!
//! Apple's actool at any deployment target since macOS 11 turns each
//! `.pdf` imageset asset into three renditions: the PDF (`LAYOUT_PDF=9`,
//! re-serialized through CoreGraphics into a compact normalized form — see
//! `normalize_pdf`) and rasterized `@1x` + `@2x` packed_ref entries.
//! We mirror that with the CGPDFDocument APIs from CoreGraphics —
//! Rust-native PDF renderers won't match Apple's output byte-for-byte
//! (and we don't want a heavy dependency just for vector icon assets).
//!
//! Non-macOS hosts can't link CoreGraphics; on those we print a one-shot
//! warning per session and skip rasterization. The PDF rendition is
//! still emitted so the catalog stays self-consistent.

use anyhow::{anyhow, Result};
use std::ffi::CString;
use std::os::raw::{c_char, c_double, c_void};
use std::sync::OnceLock;

#[cfg(target_os = "macos")]
unsafe extern "C" {
    fn dlopen(filename: *const c_char, flags: i32) -> *mut c_void;
    fn dlsym(handle: *mut c_void, symbol: *const c_char) -> *mut c_void;
}

#[cfg(target_os = "macos")]
const RTLD_LAZY: i32 = 0x1;

#[repr(C)]
#[derive(Copy, Clone, Default)]
struct CGPoint {
    x: c_double,
    y: c_double,
}
#[repr(C)]
#[derive(Copy, Clone, Default)]
struct CGSize {
    width: c_double,
    height: c_double,
}
#[repr(C)]
#[derive(Copy, Clone, Default)]
struct CGRect {
    origin: CGPoint,
    size: CGSize,
}

const K_CG_PDF_MEDIA_BOX: u32 = 0;

type CFDataCreateFn = unsafe extern "C" fn(*const c_void, *const u8, usize) -> *mut c_void;
type CFReleaseFn = unsafe extern "C" fn(*mut c_void);
type CGDPCreateWithCFData = unsafe extern "C" fn(*mut c_void) -> *mut c_void;
type CGDPRelease = unsafe extern "C" fn(*mut c_void);
type CGPDFDocCreate = unsafe extern "C" fn(*mut c_void) -> *mut c_void;
type CGPDFDocRelease = unsafe extern "C" fn(*mut c_void);
type CGPDFDocGetPage = unsafe extern "C" fn(*mut c_void, usize) -> *mut c_void;
type CGPDFPageGetBoxRect = unsafe extern "C" fn(*mut c_void, u32) -> CGRect;
type CGColorSpaceCreateFn = unsafe extern "C" fn(*mut c_void) -> *mut c_void;
type CGColorSpaceRelease = unsafe extern "C" fn(*mut c_void);
type CGBitmapCreateFn = unsafe extern "C" fn(
    *mut c_void,
    usize,
    usize,
    usize,
    usize,
    *mut c_void,
    u32,
) -> *mut c_void;
type CGBitmapGetDataFn = unsafe extern "C" fn(*mut c_void) -> *mut u8;
type CGContextScaleFn = unsafe extern "C" fn(*mut c_void, c_double, c_double);
type CGContextDrawPDFFn = unsafe extern "C" fn(*mut c_void, *mut c_void);
type CGContextReleaseFn = unsafe extern "C" fn(*mut c_void);
// PDF re-serialization (writer side).
type CFDataCreateMutableFn = unsafe extern "C" fn(*const c_void, isize) -> *mut c_void;
type CGDataConsumerCreateFn = unsafe extern "C" fn(*mut c_void) -> *mut c_void;
type CGPDFContextCreateFn =
    unsafe extern "C" fn(*mut c_void, *const CGRect, *mut c_void) -> *mut c_void;
type CGPDFContextPageFn = unsafe extern "C" fn(*mut c_void, *mut c_void);
type CGContextVoidFn = unsafe extern "C" fn(*mut c_void);
type CFDataGetLengthFn = unsafe extern "C" fn(*mut c_void) -> isize;
type CFDataGetBytePtrFn = unsafe extern "C" fn(*mut c_void) -> *const u8;

struct PdfSyms {
    cf_data_create: CFDataCreateFn,
    cf_release: CFReleaseFn,
    dp_create: CGDPCreateWithCFData,
    dp_release: CGDPRelease,
    doc_create: CGPDFDocCreate,
    doc_release: CGPDFDocRelease,
    doc_get_page: CGPDFDocGetPage,
    page_get_box_rect: CGPDFPageGetBoxRect,
    cs_create_named: CGColorSpaceCreateFn,
    cs_release: CGColorSpaceRelease,
    bitmap_create: CGBitmapCreateFn,
    bitmap_get_data: CGBitmapGetDataFn,
    ctx_scale: CGContextScaleFn,
    ctx_draw_pdf: CGContextDrawPDFFn,
    ctx_release: CGContextReleaseFn,
    cf_data_create_mutable: CFDataCreateMutableFn,
    data_consumer_create: CGDataConsumerCreateFn,
    data_consumer_release: CGDPRelease,
    pdf_ctx_create: CGPDFContextCreateFn,
    pdf_begin_page: CGPDFContextPageFn,
    pdf_end_page: CGContextVoidFn,
    pdf_close: CGContextVoidFn,
    cf_data_get_length: CFDataGetLengthFn,
    cf_data_get_byte_ptr: CFDataGetBytePtrFn,
    srgb_name: *mut c_void,
}

unsafe impl Sync for PdfSyms {}
unsafe impl Send for PdfSyms {}

#[cfg(target_os = "macos")]
fn load_syms() -> Option<&'static PdfSyms> {
    static CELL: OnceLock<Option<PdfSyms>> = OnceLock::new();
    CELL.get_or_init(|| unsafe {
        let cg = dlopen(
            CString::new("/System/Library/Frameworks/CoreGraphics.framework/CoreGraphics")
                .unwrap()
                .as_ptr(),
            RTLD_LAZY,
        );
        let cf = dlopen(
            CString::new("/System/Library/Frameworks/CoreFoundation.framework/CoreFoundation")
                .unwrap()
                .as_ptr(),
            RTLD_LAZY,
        );
        if cg.is_null() || cf.is_null() {
            return None;
        }
        macro_rules! sym {
            ($handle:expr, $name:expr, $ty:ty) => {{
                let n = CString::new($name).unwrap();
                let p = dlsym($handle, n.as_ptr());
                if p.is_null() {
                    return None;
                }
                std::mem::transmute::<_, $ty>(p)
            }};
        }
        let srgb_name_ptr = {
            let n = CString::new("kCGColorSpaceSRGB").unwrap();
            let p = dlsym(cg, n.as_ptr());
            if p.is_null() {
                return None;
            }
            *(p as *mut *mut c_void)
        };
        Some(PdfSyms {
            cf_data_create: sym!(cf, "CFDataCreate", CFDataCreateFn),
            cf_release: sym!(cf, "CFRelease", CFReleaseFn),
            dp_create: sym!(cg, "CGDataProviderCreateWithCFData", CGDPCreateWithCFData),
            dp_release: sym!(cg, "CGDataProviderRelease", CGDPRelease),
            doc_create: sym!(cg, "CGPDFDocumentCreateWithProvider", CGPDFDocCreate),
            doc_release: sym!(cg, "CGPDFDocumentRelease", CGPDFDocRelease),
            doc_get_page: sym!(cg, "CGPDFDocumentGetPage", CGPDFDocGetPage),
            page_get_box_rect: sym!(cg, "CGPDFPageGetBoxRect", CGPDFPageGetBoxRect),
            cs_create_named: sym!(cg, "CGColorSpaceCreateWithName", CGColorSpaceCreateFn),
            cs_release: sym!(cg, "CGColorSpaceRelease", CGColorSpaceRelease),
            bitmap_create: sym!(cg, "CGBitmapContextCreate", CGBitmapCreateFn),
            bitmap_get_data: sym!(cg, "CGBitmapContextGetData", CGBitmapGetDataFn),
            ctx_scale: sym!(cg, "CGContextScaleCTM", CGContextScaleFn),
            ctx_draw_pdf: sym!(cg, "CGContextDrawPDFPage", CGContextDrawPDFFn),
            ctx_release: sym!(cg, "CGContextRelease", CGContextReleaseFn),
            cf_data_create_mutable: sym!(cf, "CFDataCreateMutable", CFDataCreateMutableFn),
            data_consumer_create: sym!(cg, "CGDataConsumerCreateWithCFData", CGDataConsumerCreateFn),
            data_consumer_release: sym!(cg, "CGDataConsumerRelease", CGDPRelease),
            pdf_ctx_create: sym!(cg, "CGPDFContextCreate", CGPDFContextCreateFn),
            pdf_begin_page: sym!(cg, "CGPDFContextBeginPage", CGPDFContextPageFn),
            pdf_end_page: sym!(cg, "CGPDFContextEndPage", CGContextVoidFn),
            pdf_close: sym!(cg, "CGPDFContextClose", CGContextVoidFn),
            cf_data_get_length: sym!(cf, "CFDataGetLength", CFDataGetLengthFn),
            cf_data_get_byte_ptr: sym!(cf, "CFDataGetBytePtr", CFDataGetBytePtrFn),
            srgb_name: srgb_name_ptr,
        })
    })
    .as_ref()
}

#[cfg(not(target_os = "macos"))]
fn load_syms() -> Option<&'static PdfSyms> {
    None
}

static WARNED: OnceLock<()> = OnceLock::new();

fn warn_unavailable_once() {
    WARNED.get_or_init(|| {
        eprintln!(
            "actool: PDF rasterization requires macOS CoreGraphics; skipping \
             per-scale rasterization. The catalog will still contain the \
             original PDF rendition but downstream packed_ref entries will \
             be absent."
        );
    });
}

/// One rasterized variant of a source PDF at a specific scale.
pub struct RasterizedPdf {
    pub width: u32,
    pub height: u32,
    pub scale: u32,
    pub bgra: Vec<u8>,
}

/// Rasterize the first page of `pdf_data` at the given integer scale
/// factor and return premultiplied BGRA pixel rows.
/// Returns Err on hosts without CoreGraphics or when the PDF can't be
/// rendered; callers should keep the original PDF rendition either way.
pub fn rasterize_pdf(pdf_data: &[u8], scale: u32) -> Result<RasterizedPdf> {
    let syms = match load_syms() {
        Some(s) => s,
        None => {
            warn_unavailable_once();
            return Err(anyhow!("CoreGraphics PDF support unavailable on this host"));
        }
    };
    unsafe {
        let cf = (syms.cf_data_create)(std::ptr::null(), pdf_data.as_ptr(), pdf_data.len());
        if cf.is_null() {
            return Err(anyhow!("CFDataCreate failed"));
        }
        let dp = (syms.dp_create)(cf);
        if dp.is_null() {
            (syms.cf_release)(cf);
            return Err(anyhow!("CGDataProviderCreateWithCFData failed"));
        }
        let doc = (syms.doc_create)(dp);
        (syms.dp_release)(dp);
        (syms.cf_release)(cf);
        if doc.is_null() {
            return Err(anyhow!("CGPDFDocumentCreateWithProvider failed"));
        }
        let page = (syms.doc_get_page)(doc, 1);
        if page.is_null() {
            (syms.doc_release)(doc);
            return Err(anyhow!("PDF has no first page"));
        }

        // Pixel dimensions are round(mediaBox · scale) from the *raw* fractional
        // mediaBox — Apple rounds after scaling, not before. For a fractional
        // page (iina's playing_in_pip is 86.25×67.5) round(W)·scale would give
        // 172×136 where Apple emits round(W·2)=173×135.
        let mb = (syms.page_get_box_rect)(page, K_CG_PDF_MEDIA_BOX);
        let px_w = (mb.size.width * scale as f64).round() as u32;
        let px_h = (mb.size.height * scale as f64).round() as u32;
        if px_w == 0 || px_h == 0 {
            (syms.doc_release)(doc);
            return Err(anyhow!("PDF page has zero dimensions"));
        }

        let cs = (syms.cs_create_named)(syms.srgb_name);
        if cs.is_null() {
            (syms.doc_release)(doc);
            return Err(anyhow!("CGColorSpaceCreateWithName failed"));
        }
        const K_CG_IMAGE_ALPHA_PREMULTIPLIED_FIRST: u32 = 2;
        const K_CG_BITMAP_BYTE_ORDER_32_LITTLE: u32 = 2 << 12;
        let bitmap_info = K_CG_IMAGE_ALPHA_PREMULTIPLIED_FIRST
            | K_CG_BITMAP_BYTE_ORDER_32_LITTLE;
        let bpr = (px_w as usize) * 4;
        let ctx = (syms.bitmap_create)(
            std::ptr::null_mut(),
            px_w as usize,
            px_h as usize,
            8,
            bpr,
            cs,
            bitmap_info,
        );
        if ctx.is_null() {
            (syms.cs_release)(cs);
            (syms.doc_release)(doc);
            return Err(anyhow!("CGBitmapContextCreate failed"));
        }
        if scale > 1 {
            (syms.ctx_scale)(ctx, scale as c_double, scale as c_double);
        }
        (syms.ctx_draw_pdf)(ctx, page);
        let data_ptr = (syms.bitmap_get_data)(ctx);
        let byte_len = bpr * (px_h as usize);
        let bgra = std::slice::from_raw_parts(data_ptr, byte_len).to_vec();

        (syms.ctx_release)(ctx);
        (syms.cs_release)(cs);
        (syms.doc_release)(doc);

        Ok(RasterizedPdf {
            width: px_w,
            height: px_h,
            scale,
            bgra,
        })
    }
}

/// Re-serialize a PDF the way Apple's actool does: draw the first page into a
/// fresh `CGPDFContext` and return the resulting bytes. CoreGraphics rewrites
/// the page into a compact, normalized PDF (recompressed streams, dropped
/// cruft) — iina's 167 KB design-tool PDFs come back at ~3.8 KB, matching
/// Apple's stored renditions to within a few bytes. Returns `None` on hosts
/// without CoreGraphics or if any step fails, so callers fall back to the raw
/// bytes. Not byte-identical to Apple (the emitted PDF carries a CreationDate /
/// document ID that varies per run, like the `.icon` UUIDs), but size- and
/// content-equivalent.
pub fn normalize_pdf(pdf_data: &[u8]) -> Option<Vec<u8>> {
    let syms = load_syms()?;
    unsafe {
        let cf = (syms.cf_data_create)(std::ptr::null(), pdf_data.as_ptr(), pdf_data.len());
        if cf.is_null() {
            return None;
        }
        let dp = (syms.dp_create)(cf);
        if dp.is_null() {
            (syms.cf_release)(cf);
            return None;
        }
        let doc = (syms.doc_create)(dp);
        (syms.dp_release)(dp);
        (syms.cf_release)(cf);
        if doc.is_null() {
            return None;
        }
        let page = (syms.doc_get_page)(doc, 1);
        if page.is_null() {
            (syms.doc_release)(doc);
            return None;
        }
        let media_box = (syms.page_get_box_rect)(page, K_CG_PDF_MEDIA_BOX);

        let out = (syms.cf_data_create_mutable)(std::ptr::null(), 0);
        if out.is_null() {
            (syms.doc_release)(doc);
            return None;
        }
        let consumer = (syms.data_consumer_create)(out);
        if consumer.is_null() {
            (syms.cf_release)(out);
            (syms.doc_release)(doc);
            return None;
        }
        let ctx = (syms.pdf_ctx_create)(consumer, &media_box, std::ptr::null_mut());
        if ctx.is_null() {
            (syms.data_consumer_release)(consumer);
            (syms.cf_release)(out);
            (syms.doc_release)(doc);
            return None;
        }
        (syms.pdf_begin_page)(ctx, std::ptr::null_mut());
        (syms.ctx_draw_pdf)(ctx, page);
        (syms.pdf_end_page)(ctx);
        (syms.pdf_close)(ctx);

        let len = (syms.cf_data_get_length)(out);
        let ptr = (syms.cf_data_get_byte_ptr)(out);
        let bytes = if len > 0 && !ptr.is_null() {
            Some(std::slice::from_raw_parts(ptr, len as usize).to_vec())
        } else {
            None
        };

        (syms.ctx_release)(ctx);
        (syms.data_consumer_release)(consumer);
        (syms.cf_release)(out);
        (syms.doc_release)(doc);
        bytes
    }
}

pub fn has_coregraphics_pdf() -> bool {
    load_syms().is_some()
}
