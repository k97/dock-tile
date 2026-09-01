//! Byte-for-byte parity with Python's CoreSVG-based rasterizer.
//!
//! Both implementations call the same private framework entry points,
//! so the raster output must match exactly. CoreSVG is macOS-only, so the
//! whole file is gated; the `has_coresvg()` check still covers a macOS host
//! where the private framework can't be loaded.
#![cfg(target_os = "macos")]

use actool::svg_raster::{has_coresvg, rasterize_svg};

const SVG: &[u8] = br##"<svg xmlns="http://www.w3.org/2000/svg" width="32" height="32" viewBox="0 0 32 32"><circle cx="16" cy="16" r="14" fill="#FF0000"/></svg>"##;

#[test]
fn matches_python_reference() {
    if !has_coresvg() {
        eprintln!("Skipping: CoreSVG not available");
        return;
    }
    let reference_path = "tests/parity_references/svg_python_reference.bin";
    if !std::path::Path::new(reference_path).exists() {
        eprintln!("Skipping: {reference_path} not present");
        return;
    }
    let ours = rasterize_svg(SVG, 32, 32, 1).expect("rasterize");
    let reference = std::fs::read(reference_path).expect("read reference");
    assert_eq!(ours.len(), reference.len());
    // Count differing pixels to avoid printing a gigantic diff
    let diffs = ours.iter().zip(reference.iter()).filter(|(a, b)| a != b).count();
    if diffs > 0 {
        let _ = std::fs::write("tmp/svg_rust_output.bin", &ours);
        panic!("SVG raster mismatch: {diffs} differing bytes");
    }
}
