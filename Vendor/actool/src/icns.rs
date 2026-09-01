//! ICNS (macOS icon) file writer.
//!
//! Generates .icns files with Apple's actool layout: `ic13`, `ic11`, and
//! `ic07` as PNG entries (re-encoded with sRGB + EXIF metadata) plus
//! `ic04` as a PackBits-compressed ARGB entry.

use byteorder::{BigEndian, WriteBytesExt};
use image::imageops::FilterType;
use std::io::Write;
use std::path::{Path, PathBuf};

/// (point_size, scale, type_code, format)
const ENTRIES: &[(u32, u32, &[u8; 4], &str)] = &[
    (128, 2, b"ic13", "png"),
    (16, 2, b"ic11", "png"),
    (16, 1, b"ic04", "argb"),
    (128, 1, b"ic07", "png"),
];

fn packbits(data: &[u8]) -> Vec<u8> {
    let mut out = Vec::with_capacity(data.len());
    let n = data.len();
    let mut i = 0;
    while i < n {
        if i + 1 < n && data[i] == data[i + 1] {
            let run_val = data[i];
            let mut run_len = 1;
            while i + run_len < n && data[i + run_len] == run_val && run_len < 130 {
                run_len += 1;
            }
            if run_len >= 3 {
                out.push((run_len + 125) as u8);
                out.push(run_val);
                i += run_len;
                continue;
            }
        }

        let mut lit_len = 0usize;
        while i + lit_len < n && lit_len < 128 {
            if i + lit_len + 2 < n
                && data[i + lit_len] == data[i + lit_len + 1]
                && data[i + lit_len + 1] == data[i + lit_len + 2]
            {
                break;
            }
            lit_len += 1;
        }
        if lit_len > 0 {
            out.push((lit_len - 1) as u8);
            out.extend_from_slice(&data[i..i + lit_len]);
            i += lit_len;
        } else {
            out.push(0);
            out.push(data[i]);
            i += 1;
        }
    }
    out
}

fn make_argb(img_path: &Path, pixel_size: u32) -> anyhow::Result<Vec<u8>> {
    let img = image::open(img_path)?.to_rgba8();
    let img = if img.width() != pixel_size || img.height() != pixel_size {
        image::imageops::resize(&img, pixel_size, pixel_size, FilterType::Lanczos3)
    } else {
        img
    };
    let pixels = img.as_raw();

    let len = (pixel_size * pixel_size) as usize;
    let mut a = Vec::with_capacity(len);
    let mut r = Vec::with_capacity(len);
    let mut g = Vec::with_capacity(len);
    let mut b = Vec::with_capacity(len);
    for chunk in pixels.chunks_exact(4) {
        r.push(chunk[0]);
        g.push(chunk[1]);
        b.push(chunk[2]);
        a.push(chunk[3]);
    }

    let mut out = Vec::new();
    out.extend_from_slice(b"ARGB");
    out.extend_from_slice(&packbits(&a));
    out.extend_from_slice(&packbits(&r));
    out.extend_from_slice(&packbits(&g));
    out.extend_from_slice(&packbits(&b));
    Ok(out)
}

fn make_exif(width: u32, height: u32) -> Vec<u8> {
    let mut buf = Vec::new();
    buf.extend_from_slice(b"Exif\x00\x00");
    buf.extend_from_slice(b"MM");
    buf.write_u16::<BigEndian>(42).unwrap();
    buf.write_u32::<BigEndian>(8).unwrap();

    // IFD0
    buf.write_u16::<BigEndian>(1).unwrap(); // count
    let exif_ifd_offset: u32 = 26;
    buf.write_u16::<BigEndian>(0x8769).unwrap();
    buf.write_u16::<BigEndian>(4).unwrap();
    buf.write_u32::<BigEndian>(1).unwrap();
    buf.write_u32::<BigEndian>(exif_ifd_offset).unwrap();
    buf.write_u32::<BigEndian>(0).unwrap(); // next IFD

    // ExifIFD
    buf.write_u16::<BigEndian>(2).unwrap();
    buf.write_u16::<BigEndian>(0xA002).unwrap();
    buf.write_u16::<BigEndian>(4).unwrap();
    buf.write_u32::<BigEndian>(1).unwrap();
    buf.write_u32::<BigEndian>(width).unwrap();
    buf.write_u16::<BigEndian>(0xA003).unwrap();
    buf.write_u16::<BigEndian>(4).unwrap();
    buf.write_u32::<BigEndian>(1).unwrap();
    buf.write_u32::<BigEndian>(height).unwrap();
    buf.write_u32::<BigEndian>(0).unwrap();

    buf
}

fn reencode_png_at_size(img_path: &Path, pixel_size: u32) -> anyhow::Result<Vec<u8>> {
    let img = image::open(img_path)?.to_rgba8();
    let resized = if img.width() != pixel_size || img.height() != pixel_size {
        image::imageops::resize(&img, pixel_size, pixel_size, FilterType::Lanczos3)
    } else {
        img
    };
    let exif = make_exif(pixel_size, pixel_size);
    encode_rgba_png(&resized, pixel_size, pixel_size, &exif)
}

fn encode_rgba_png(
    rgba: &image::ImageBuffer<image::Rgba<u8>, Vec<u8>>,
    w: u32,
    h: u32,
    exif: &[u8],
) -> anyhow::Result<Vec<u8>> {

    let mut out = Vec::new();
    {
        let mut encoder = png::Encoder::new(&mut out, w, h);
        encoder.set_color(png::ColorType::Rgba);
        encoder.set_depth(png::BitDepth::Eight);
        encoder.set_compression(png::Compression::Fast);
        encoder.set_source_srgb(png::SrgbRenderingIntent::Perceptual);
        let mut writer = encoder.write_header()?;
        writer.write_chunk(png::chunk::ChunkType(*b"eXIf"), exif)?;
        writer.write_image_data(rgba.as_raw())?;
    }
    Ok(out)
}

pub fn create_icns<P: AsRef<Path>>(
    icon_images: &[(PathBuf, u32, u32)],
    output_path: P,
) -> anyhow::Result<()> {
    // (point_size, scale) -> image path; also track best source per point
    // size so we can synthesize ic04/ic07 (scale 1) from a @2x source when
    // the bundle only ships @2x sized renditions.
    let mut exact: std::collections::HashMap<(u32, u32), &PathBuf> =
        std::collections::HashMap::new();
    let mut by_point: std::collections::HashMap<u32, &PathBuf> =
        std::collections::HashMap::new();
    for (path, pixel_size, scale) in icon_images {
        let point = pixel_size / scale;
        exact.insert((point, *scale), path);
        by_point.entry(point).or_insert(path);
    }

    let mut entries: Vec<([u8; 4], Vec<u8>)> = Vec::new();
    for (point, scale, type_code, fmt) in ENTRIES {
        let path_opt = exact.get(&(*point, *scale)).or_else(|| by_point.get(point));
        let Some(path) = path_opt else { continue };
        let pixel_size = point * scale;
        let data = match *fmt {
            "argb" => make_argb(path, pixel_size)?,
            _ => reencode_png_at_size(path, pixel_size)?,
        };
        entries.push((**type_code, data));
    }

    if entries.is_empty() {
        return Ok(());
    }

    let mut total_size: u32 = 8;
    for (_, data) in &entries {
        total_size += 8 + data.len() as u32;
    }

    let mut file = std::fs::File::create(output_path)?;
    file.write_all(b"icns")?;
    file.write_u32::<BigEndian>(total_size)?;
    for (type_code, data) in &entries {
        file.write_all(type_code)?;
        file.write_u32::<BigEndian>(8 + data.len() as u32)?;
        file.write_all(data)?;
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn packbits_short_literal() {
        // Non-repeating bytes become a single literal run
        let out = packbits(&[1, 2, 3]);
        assert_eq!(out[0], 2); // literal length - 1
        assert_eq!(&out[1..], &[1, 2, 3]);
    }

    #[test]
    fn packbits_run() {
        let out = packbits(&[5, 5, 5, 5]);
        // run marker = 128 + run_len - 3 = 128 + 1 = 129; Python uses + 125 with run_len
        // so run_len=4 -> 4 + 125 = 129
        assert_eq!(out, vec![129, 5]);
    }

    #[test]
    fn packbits_mixed() {
        let out = packbits(&[1, 2, 3, 7, 7, 7, 7]);
        // literal [1,2,3] then run of 7
        assert_eq!(out[0], 2);
        assert_eq!(&out[1..4], &[1, 2, 3]);
        assert_eq!(out[4], 129);
        assert_eq!(out[5], 7);
    }

    #[test]
    fn exif_structure() {
        let exif = make_exif(128, 128);
        assert_eq!(&exif[..6], b"Exif\x00\x00");
        assert_eq!(&exif[6..8], b"MM");
    }
}
