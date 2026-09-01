//! Regression tests for DMP2 (deepmap2) compression selection.

use actool::{car::compress_data, deepmap2};

fn pixel_data(w: u32, h: u32, bpp: u32) -> Vec<u8> {
    let colors: [u8; 4] = [0xAA, 0xBB, 0xCC, 0xFF];
    (0..(w * h) as usize)
        .flat_map(|_| colors[..bpp as usize].iter().copied())
        .collect()
}

#[test]
fn dmp2_used_for_atlas_at_11_0() {
    if !deepmap2::is_available() {
        return;
    }
    let data = pixel_data(64, 64, 4);
    let out = compress_data(&data, b"BGRA", 64, 64, "11.0", "macosx", true, false, true);
    assert_eq!(&out[..4], b"MLEC");
    let ver = u32::from_le_bytes(out[4..8].try_into().unwrap());
    let comp = u32::from_le_bytes(out[8..12].try_into().unwrap());
    assert_eq!(comp, 11, "expected DMP2");
    assert_eq!(ver, 2, "expected CELM ver=2 for opaque DMP2");
}

#[test]
fn lzfse_used_for_standalone_at_11_0() {
    let data = pixel_data(64, 64, 4);
    let out = compress_data(&data, b"BGRA", 64, 64, "11.0", "macosx", false, false, false);
    let comp = u32::from_le_bytes(out[8..12].try_into().unwrap());
    assert_ne!(comp, 11, "standalone images should not use DMP2");
}

#[test]
fn no_dmp2_at_10_15() {
    let data = pixel_data(64, 64, 4);
    let out = compress_data(&data, b"BGRA", 64, 64, "10.15", "macosx", true, false, false);
    let comp = u32::from_le_bytes(out[8..12].try_into().unwrap());
    assert_ne!(comp, 11, "DMP2 should not be used for target < 11.0");
}

#[test]
fn no_dmp2_at_10_11() {
    let data = pixel_data(64, 64, 4);
    let out = compress_data(&data, b"BGRA", 64, 64, "10.11", "macosx", true, false, false);
    let comp = u32::from_le_bytes(out[8..12].try_into().unwrap());
    assert_ne!(comp, 11);
}

#[test]
fn dmp2_for_ga8_atlas() {
    if !deepmap2::is_available() {
        return;
    }
    let data = pixel_data(64, 64, 2);
    let out = compress_data(&data, b" 8AG", 64, 64, "11.0", "macosx", true, false, false);
    let comp = u32::from_le_bytes(out[8..12].try_into().unwrap());
    assert_eq!(comp, 11, "GA8 atlas should use DMP2 at 11.0+");
}

#[test]
fn small_data_skips_dmp2() {
    let data = vec![0u8; 256];
    let out = compress_data(&data, b"BGRA", 8, 8, "11.0", "macosx", true, false, false);
    let comp = u32::from_le_bytes(out[8..12].try_into().unwrap());
    assert_ne!(comp, 11, "data <= 256 bytes should skip DMP2");
}
