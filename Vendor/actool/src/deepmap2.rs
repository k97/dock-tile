//! Dynamic loading of vImage's Deepmap2 compression API.
//!
//! Uses dlopen/dlsym to resolve `vImageDeepmap2EncodeCreateBuffer` from
//! Accelerate.framework at runtime. Undocumented Apple API that provides
//! better compression than plain LZFSE for image data.

use std::ffi::{c_void, CString};
use std::os::raw::{c_ulong, c_ushort};
use std::ptr;
use std::sync::OnceLock;

pub const PIXFMT_BGRA: &[u8; 4] = b"BGRA";
pub const PIXFMT_GA8: &[u8; 4] = b" 8AG";

#[repr(C)]
struct Deepmap2Options {
    compression_type: u32,
    quality: u32,
    param: u32,
}

#[repr(C)]
struct VImageBuffer {
    data: *mut c_void,
    height: c_ulong,
    width: c_ulong,
    row_bytes: c_ulong,
}

type EncodeFn = unsafe extern "C" fn(
    *mut VImageBuffer,
    u32,
    *mut Deepmap2Options,
    *mut *mut c_void,
) -> usize;

#[cfg(target_os = "macos")]
unsafe extern "C" {
    fn dlopen(filename: *const std::os::raw::c_char, flags: i32) -> *mut c_void;
    fn dlsym(
        handle: *mut c_void,
        symbol: *const std::os::raw::c_char,
    ) -> *mut c_void;
    fn free(ptr: *mut c_void);
}

#[cfg(target_os = "macos")]
const RTLD_LAZY: i32 = 0x1;

fn pixfmt_to_dm(pixfmt: &[u8]) -> Option<u32> {
    match pixfmt {
        b"BGRA" => Some(4),
        b" 8AG" => Some(2),
        _ => None,
    }
}

#[cfg(target_os = "macos")]
fn encode_fn() -> Option<EncodeFn> {
    static FN: OnceLock<Option<usize>> = OnceLock::new();
    let addr = FN.get_or_init(|| unsafe {
        let path = CString::new(
            "/System/Library/Frameworks/Accelerate.framework/Accelerate",
        )
        .unwrap();
        let handle = dlopen(path.as_ptr(), RTLD_LAZY);
        if handle.is_null() {
            return None;
        }
        let name = CString::new("vImageDeepmap2EncodeCreateBuffer").unwrap();
        let sym = dlsym(handle, name.as_ptr());
        if sym.is_null() {
            None
        } else {
            Some(sym as usize)
        }
    });
    addr.map(|a| unsafe { std::mem::transmute::<usize, EncodeFn>(a) })
}

#[cfg(not(target_os = "macos"))]
fn encode_fn() -> Option<EncodeFn> {
    None
}

pub fn is_available() -> bool {
    encode_fn().is_some()
}

pub fn encode(
    pixel_data: &[u8],
    pixel_format: &[u8],
    width: u32,
    height: u32,
) -> Option<Vec<u8>> {
    let fn_ptr = encode_fn()?;
    let dm_fmt = pixfmt_to_dm(pixel_format)?;

    let row_bytes = if height > 0 {
        pixel_data.len() / height as usize
    } else {
        width as usize * 4
    };

    let mut src_copy = pixel_data.to_vec();
    let mut vbuf = VImageBuffer {
        data: src_copy.as_mut_ptr() as *mut c_void,
        height: height as c_ulong,
        width: width as c_ulong,
        row_bytes: row_bytes as c_ulong,
    };
    let mut opts = Deepmap2Options {
        compression_type: 2,
        quality: 1,
        param: 10,
    };
    let mut out_ptr: *mut c_void = ptr::null_mut();

    let encoded_size = unsafe {
        fn_ptr(&mut vbuf, dm_fmt, &mut opts, &mut out_ptr)
    };

    if encoded_size == 0 || out_ptr.is_null() {
        return None;
    }

    let result = unsafe {
        std::slice::from_raw_parts(out_ptr as *const u8, encoded_size).to_vec()
    };
    #[cfg(target_os = "macos")]
    unsafe {
        free(out_ptr);
    }
    Some(result)
}

/// Wrap raw dmp2 data in a CELM comp=11 envelope.
///
/// For inline=true: CELM ver=0 with raw dmp2 directly after the header.
/// For inline=false: 16-byte sub-header between CELM header and dmp2 payload.
pub fn make_celm_dmp2(
    dmp2_data: &[u8],
    pixel_format: &[u8],
    inline: bool,
    celm_version: u32,
) -> Vec<u8> {
    let mut out = Vec::new();
    if inline {
        out.extend_from_slice(b"MLEC");
        out.extend_from_slice(&0u32.to_le_bytes()); // version
        out.extend_from_slice(&11u32.to_le_bytes()); // comp
        out.extend_from_slice(&(dmp2_data.len() as u32).to_le_bytes());
        out.extend_from_slice(dmp2_data);
        return out;
    }

    let dm_fmt = pixfmt_to_dm(pixel_format).unwrap_or(0);
    let dmp2_len = dmp2_data.len() as u32;
    let sub_header_len = 16u32;
    let total_len = sub_header_len + dmp2_len;

    out.extend_from_slice(b"MLEC");
    out.extend_from_slice(&celm_version.to_le_bytes());
    out.extend_from_slice(&11u32.to_le_bytes());
    out.extend_from_slice(&total_len.to_le_bytes());
    // sub-header
    out.extend_from_slice(&1u32.to_le_bytes()); // version
    out.extend_from_slice(&dm_fmt.to_le_bytes());
    out.extend_from_slice(&dmp2_len.to_le_bytes());
    out.extend_from_slice(&0u32.to_le_bytes()); // zero
    out.extend_from_slice(dmp2_data);
    out
}

// Unused: silences warnings about unused types on non-macOS builds.
#[allow(dead_code)]
fn _unused_marker(_: *mut c_ushort) {}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn celm_header_fields() {
        let fake_dmp2 = [b'd', b'm', b'p', b'2']
            .iter()
            .chain([0u8; 20].iter())
            .copied()
            .collect::<Vec<u8>>();
        let celm = make_celm_dmp2(&fake_dmp2, b"BGRA", false, 2);
        assert_eq!(&celm[..4], b"MLEC");
        let ver = u32::from_le_bytes(celm[4..8].try_into().unwrap());
        let comp = u32::from_le_bytes(celm[8..12].try_into().unwrap());
        let dlen = u32::from_le_bytes(celm[12..16].try_into().unwrap());
        assert_eq!(ver, 2);
        assert_eq!(comp, 11);
        assert_eq!(dlen, 16 + fake_dmp2.len() as u32);
    }

    #[test]
    fn celm_sub_header_bgra() {
        let fake_dmp2 = vec![0u8; 30];
        let celm = make_celm_dmp2(&fake_dmp2, b"BGRA", false, 2);
        let sub_ver = u32::from_le_bytes(celm[16..20].try_into().unwrap());
        let sub_pf = u32::from_le_bytes(celm[20..24].try_into().unwrap());
        let sub_len = u32::from_le_bytes(celm[24..28].try_into().unwrap());
        let sub_zero = u32::from_le_bytes(celm[28..32].try_into().unwrap());
        assert_eq!(sub_ver, 1);
        assert_eq!(sub_pf, 4);
        assert_eq!(sub_len, 30);
        assert_eq!(sub_zero, 0);
    }

    #[test]
    fn celm_sub_header_ga8() {
        let fake_dmp2 = vec![0u8; 10];
        let celm = make_celm_dmp2(&fake_dmp2, b" 8AG", false, 2);
        let sub_pf = u32::from_le_bytes(celm[20..24].try_into().unwrap());
        assert_eq!(sub_pf, 2);
    }

    #[test]
    fn celm_contains_payload() {
        let fake_dmp2 = b"dmp2TESTPAYLOAD!";
        let celm = make_celm_dmp2(fake_dmp2, b"BGRA", false, 2);
        assert_eq!(&celm[32..], &fake_dmp2[..]);
    }

    #[test]
    fn celm_inline() {
        let fake = b"dmp2XX";
        let celm = make_celm_dmp2(fake, b"BGRA", true, 0);
        assert_eq!(&celm[..4], b"MLEC");
        let ver = u32::from_le_bytes(celm[4..8].try_into().unwrap());
        assert_eq!(ver, 0);
        assert_eq!(&celm[16..], &fake[..]);
    }

    #[test]
    fn encode_unknown_pixfmt() {
        let r = encode(&vec![0u8; 64], b"XYZW", 4, 4);
        assert!(r.is_none());
    }

    // Live-encoder tests (only run on macOS if Accelerate is available).
    #[test]
    #[cfg(target_os = "macos")]
    fn encode_bgra_magic() {
        if !is_available() {
            return;
        }
        let w = 32;
        let h = 32;
        let data: Vec<u8> = [0xAAu8, 0xBB, 0xCC, 0xFF]
            .iter()
            .copied()
            .cycle()
            .take(w * h * 4)
            .collect();
        let out = encode(&data, b"BGRA", w as u32, h as u32).unwrap();
        assert_eq!(&out[..4], b"dmp2");
        assert_eq!(out[5], 1);
        assert_eq!(out[6], 10);
        assert_eq!(out[7], 4);
    }

    #[test]
    #[cfg(target_os = "macos")]
    fn encode_ga8_magic() {
        if !is_available() {
            return;
        }
        let w = 32;
        let h = 32;
        let data: Vec<u8> = [0x80u8, 0xFF]
            .iter()
            .copied()
            .cycle()
            .take(w * h * 2)
            .collect();
        let out = encode(&data, b" 8AG", w as u32, h as u32).unwrap();
        assert_eq!(&out[..4], b"dmp2");
        assert_eq!(out[7], 2);
    }
}
