//! SVG rasterization via macOS CoreSVG private framework.
//!
//! Mirrors the Python implementation that calls `CGSVGDocumentCreateFromData`
//! and `CGContextDrawSVGDocument` from `PrivateFrameworks/CoreSVG.framework`.
//! Rust-native SVG renderers (resvg, etc.) will not match Apple's output
//! byte-for-byte, so we use the same private API the system `actool` does.
//!
//! All of the CoreGraphics/CoreSVG FFI lives in the macOS-only [`imp`] module.
//! On every other platform `rasterize_svg`/`has_coresvg` are safe no-ops
//! ([`has_coresvg`] returns `false`; [`rasterize_svg`] returns an error), so the
//! crate compiles and links without referencing any Apple framework. Callers
//! gate on `has_coresvg()` (xcassets) or treat the error as "SVG unsupported
//! here" (`.icon`), exactly as on macOS when the framework is unavailable.

#[cfg(not(target_os = "macos"))]
use anyhow::Result;
use regex::Regex;

/// Extract (width, height) from SVG root element attributes. Falls back
/// to the viewBox when width/height aren't specified. Pure parsing — available
/// on every platform.
pub fn parse_svg_dimensions(svg: &[u8]) -> (u32, u32) {
    let slice = &svg[..svg.len().min(2048)];
    let text = String::from_utf8_lossy(slice);

    let w_re = Regex::new(r#"width="(\d+(?:\.\d+)?)""#).unwrap();
    let h_re = Regex::new(r#"height="(\d+(?:\.\d+)?)""#).unwrap();
    if let (Some(w), Some(h)) = (w_re.captures(&text), h_re.captures(&text)) {
        let wv: f64 = w[1].parse().unwrap_or(0.0);
        let hv: f64 = h[1].parse().unwrap_or(0.0);
        return (wv as u32, hv as u32);
    }

    let vb_re = Regex::new(
        r#"viewBox="[\d.]+\s+[\d.]+\s+([\d.]+)\s+([\d.]+)""#,
    )
    .unwrap();
    if let Some(cap) = vb_re.captures(&text) {
        let wv: f64 = cap[1].parse().unwrap_or(0.0);
        let hv: f64 = cap[2].parse().unwrap_or(0.0);
        return (wv as u32, hv as u32);
    }
    (0, 0)
}

/// Whether CoreSVG rasterization is available (always `false` off macOS).
#[cfg(not(target_os = "macos"))]
pub fn has_coresvg() -> bool {
    false
}

/// Safe no-op on non-macOS: there is no CoreSVG framework to call, so report
/// the failure and let the caller skip/fall back (it never panics or links an
/// Apple framework).
#[cfg(not(target_os = "macos"))]
pub fn rasterize_svg(
    _svg_data: &[u8],
    _width: u32,
    _height: u32,
    _scale: u32,
) -> Result<Vec<u8>> {
    Err(anyhow::anyhow!(
        "CoreSVG rasterization is only available on macOS"
    ))
}

#[cfg(target_os = "macos")]
pub use imp::{has_coresvg, rasterize_svg};

#[cfg(target_os = "macos")]
mod imp {
    use super::parse_svg_dimensions;
    use anyhow::{anyhow, Result};
    use std::ffi::CString;
    use std::os::raw::{c_char, c_double, c_void};
    use std::sync::OnceLock;

    unsafe extern "C" {
        fn dlopen(filename: *const c_char, flags: i32) -> *mut c_void;
        fn dlsym(handle: *mut c_void, symbol: *const c_char) -> *mut c_void;
    }

    const RTLD_LAZY: i32 = 0x1;

    type CFDataCreateFn = unsafe extern "C" fn(*const c_void, *const u8, usize) -> *mut c_void;
    type CFReleaseFn = unsafe extern "C" fn(*mut c_void);

    type CGSVGDocCreateFn = unsafe extern "C" fn(*mut c_void, *mut c_void) -> *mut c_void;
    type CGContextDrawSVGFn = unsafe extern "C" fn(*mut c_void, *mut c_void);

    type CGBitmapCreateFn = unsafe extern "C" fn(
        *mut c_void,
        usize,
        usize,
        usize,
        usize,
        *mut c_void,
        u32,
    ) -> *mut c_void;
    type CGColorSpaceCreateFn = unsafe extern "C" fn(*mut c_void) -> *mut c_void;
    type CGContextScaleFn = unsafe extern "C" fn(*mut c_void, c_double, c_double);
    type CGBitmapGetDataFn = unsafe extern "C" fn(*mut c_void) -> *mut u8;
    type CGContextReleaseFn = unsafe extern "C" fn(*mut c_void);

    struct CoreSvgSyms {
        cf_data_create: CFDataCreateFn,
        cf_release: CFReleaseFn,
        svg_create: CGSVGDocCreateFn,
        ctx_draw_svg: CGContextDrawSVGFn,
        bitmap_create: CGBitmapCreateFn,
        cs_create_named: CGColorSpaceCreateFn,
        ctx_scale: CGContextScaleFn,
        bitmap_get_data: CGBitmapGetDataFn,
        ctx_release: CGContextReleaseFn,
        cs_release: CGContextReleaseFn,
        srgb_name: *mut c_void,
    }

    // Function pointers live inside Apple system libs for the process lifetime.
    unsafe impl Sync for CoreSvgSyms {}
    unsafe impl Send for CoreSvgSyms {}

    fn load_syms() -> Option<&'static CoreSvgSyms> {
        static CELL: OnceLock<Option<CoreSvgSyms>> = OnceLock::new();
        CELL.get_or_init(|| unsafe {
            let cg = dlopen(
                CString::new(
                    "/System/Library/Frameworks/CoreGraphics.framework/CoreGraphics",
                )
                .unwrap()
                .as_ptr(),
                RTLD_LAZY,
            );
            let cf = dlopen(
                CString::new(
                    "/System/Library/Frameworks/CoreFoundation.framework/CoreFoundation",
                )
                .unwrap()
                .as_ptr(),
                RTLD_LAZY,
            );
            let svg = dlopen(
                CString::new(
                    "/System/Library/PrivateFrameworks/CoreSVG.framework/CoreSVG",
                )
                .unwrap()
                .as_ptr(),
                RTLD_LAZY,
            );
            if cg.is_null() || cf.is_null() || svg.is_null() {
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
            Some(CoreSvgSyms {
                cf_data_create: sym!(cf, "CFDataCreate", CFDataCreateFn),
                cf_release: sym!(cf, "CFRelease", CFReleaseFn),
                svg_create: sym!(svg, "CGSVGDocumentCreateFromData", CGSVGDocCreateFn),
                ctx_draw_svg: sym!(
                    svg,
                    "CGContextDrawSVGDocument",
                    CGContextDrawSVGFn
                ),
                bitmap_create: sym!(cg, "CGBitmapContextCreate", CGBitmapCreateFn),
                cs_create_named: sym!(
                    cg,
                    "CGColorSpaceCreateWithName",
                    CGColorSpaceCreateFn
                ),
                ctx_scale: sym!(cg, "CGContextScaleCTM", CGContextScaleFn),
                bitmap_get_data: sym!(cg, "CGBitmapContextGetData", CGBitmapGetDataFn),
                ctx_release: sym!(cg, "CGContextRelease", CGContextReleaseFn),
                cs_release: sym!(cg, "CGColorSpaceRelease", CGContextReleaseFn),
                srgb_name: srgb_name_ptr,
            })
        })
        .as_ref()
    }

    pub fn has_coresvg() -> bool {
        load_syms().is_some()
    }

    /// Rasterize SVG data into a `BGRA` (little-endian ARGB premultiplied)
    /// pixel buffer of `(width*scale) x (height*scale)`.
    pub fn rasterize_svg(
        svg_data: &[u8],
        width: u32,
        height: u32,
        scale: u32,
    ) -> Result<Vec<u8>> {
        let syms = load_syms().ok_or_else(|| anyhow!("CoreSVG framework not available"))?;
        let pixel_w = (width * scale) as usize;
        let pixel_h = (height * scale) as usize;

        unsafe {
            let cf_data =
                (syms.cf_data_create)(std::ptr::null(), svg_data.as_ptr(), svg_data.len());
            if cf_data.is_null() {
                return Err(anyhow!("CFDataCreate failed"));
            }
            let svg_doc = (syms.svg_create)(cf_data, std::ptr::null_mut());
            if svg_doc.is_null() {
                (syms.cf_release)(cf_data);
                return Err(anyhow!("CGSVGDocumentCreateFromData failed"));
            }

            let cs = (syms.cs_create_named)(syms.srgb_name);
            if cs.is_null() {
                (syms.cf_release)(svg_doc);
                (syms.cf_release)(cf_data);
                return Err(anyhow!("CGColorSpaceCreateWithName failed"));
            }

            const K_CG_IMAGE_ALPHA_PREMULTIPLIED_FIRST: u32 = 2;
            const K_CG_BITMAP_BYTE_ORDER_32_LITTLE: u32 = 2 << 12;
            let bitmap_info = K_CG_IMAGE_ALPHA_PREMULTIPLIED_FIRST
                | K_CG_BITMAP_BYTE_ORDER_32_LITTLE;
            let bpr = pixel_w * 4;
            let ctx = (syms.bitmap_create)(
                std::ptr::null_mut(),
                pixel_w,
                pixel_h,
                8,
                bpr,
                cs,
                bitmap_info,
            );
            if ctx.is_null() {
                (syms.cs_release)(cs);
                (syms.cf_release)(svg_doc);
                (syms.cf_release)(cf_data);
                return Err(anyhow!("CGBitmapContextCreate failed"));
            }

            // CGContextDrawSVGDocument draws the SVG at its intrinsic size, so to
            // fill a buffer of a different size we must scale the SVG to fit it
            // (otherwise a 1024-pt SVG asked for at 824 px is clipped to its
            // top-left corner instead of scaled). When the requested width matches
            // the SVG's native size this reduces to the integer `scale` and stays
            // byte-identical to the old behaviour.
            let (nw, nh) = parse_svg_dimensions(svg_data);
            let (nw, nh) = if nw > 0 && nh > 0 {
                (nw, nh)
            } else {
                (width.max(1), height.max(1))
            };
            let sx = pixel_w as c_double / nw as c_double;
            let sy = pixel_h as c_double / nh as c_double;
            if sx != 1.0 || sy != 1.0 {
                (syms.ctx_scale)(ctx, sx, sy);
            }
            (syms.ctx_draw_svg)(ctx, svg_doc);
            let data_ptr = (syms.bitmap_get_data)(ctx);
            let byte_len = pixel_w * pixel_h * 4;
            let data = std::slice::from_raw_parts(data_ptr, byte_len).to_vec();

            (syms.ctx_release)(ctx);
            (syms.cs_release)(cs);
            (syms.cf_release)(svg_doc);
            (syms.cf_release)(cf_data);

            Ok(data)
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parse_width_height() {
        let svg = br#"<svg xmlns="http://www.w3.org/2000/svg" width="64" height="48" viewBox="0 0 64 48"></svg>"#;
        assert_eq!(parse_svg_dimensions(svg), (64, 48));
    }

    #[test]
    fn parse_from_viewbox() {
        let svg = br#"<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32"></svg>"#;
        assert_eq!(parse_svg_dimensions(svg), (32, 32));
    }

    #[test]
    fn parse_fractional_width() {
        let svg = br#"<svg width="10.5" height="20.75" viewBox="0 0 10 20"></svg>"#;
        assert_eq!(parse_svg_dimensions(svg), (10, 20));
    }

    #[test]
    fn parse_missing() {
        let svg = br#"<svg></svg>"#;
        assert_eq!(parse_svg_dimensions(svg), (0, 0));
    }

    #[test]
    #[cfg(target_os = "macos")]
    fn rasterize_simple_circle() {
        if !has_coresvg() {
            return;
        }
        let svg = br##"<svg xmlns="http://www.w3.org/2000/svg" width="8" height="8" viewBox="0 0 8 8"><rect width="8" height="8" fill="#FF0000"/></svg>"##;
        let data = rasterize_svg(svg, 8, 8, 1).unwrap();
        assert_eq!(data.len(), 8 * 8 * 4);
        // Center pixel should be red (BGRA = 00 00 FF FF premultiplied with alpha=255)
        let center = 4 * 4 + 4 * 4 * 8; // y=4, x=4
        assert_eq!(data[center + 2], 0xFF); // R
        assert_eq!(data[center + 3], 0xFF); // A
    }
}
