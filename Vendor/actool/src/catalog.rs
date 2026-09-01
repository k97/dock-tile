//! xcassets catalog parser.
//!
//! Walks `.xcassets` directories and produces `Rendition`s.

use crate::car::{self, MultisizeImageEntry, Rendition};
use crate::name_hash::hash_name;
use crate::svg_raster;
use anyhow::{anyhow, Result};
use image::DynamicImage;
use indexmap::IndexMap;
use serde_json::Value;
use std::collections::HashSet;
use std::fs;
use std::path::{Path, PathBuf};

const ICON_DIM2_POINTS: &[(u32, u16)] = &[
    (16, 1),
    (32, 2),
    (128, 3),
    (256, 4),
    (512, 5),
];

fn icon_dim2(point_w: u32) -> u16 {
    ICON_DIM2_POINTS
        .iter()
        .find(|(p, _)| *p == point_w)
        .map(|(_, d)| *d)
        .unwrap_or(0)
}

/// iOS app-icon size index (rendition key Dimension2). Maps the point size to
/// the slot CoreUI uses to distinguish icon sizes within an idiom; 90 is the
/// synthesized Plus/Max size. Verified against `/usr/bin/actool`. Without this
/// every same-scale icon would share a rendition key and collapse to one.
fn ios_icon_dim2(point_w: u32) -> u16 {
    match point_w {
        20 => 1,
        29 => 2,
        40 => 3,
        60 => 4,
        76 => 5,
        83 => 6,
        90 => 7,
        1024 => 8,
        _ => 0,
    }
}

fn premultiply_bgra(mut buf: Vec<u8>) -> Vec<u8> {
    for chunk in buf.chunks_exact_mut(4) {
        let a = chunk[3];
        if a == 255 {
            continue;
        }
        if a == 0 {
            chunk[0] = 0;
            chunk[1] = 0;
            chunk[2] = 0;
        } else {
            chunk[0] = ((chunk[0] as u32 * a as u32 + 127) / 255) as u8;
            chunk[1] = ((chunk[1] as u32 * a as u32 + 127) / 255) as u8;
            chunk[2] = ((chunk[2] as u32 * a as u32 + 127) / 255) as u8;
        }
    }
    buf
}

fn premultiply_ga8(mut buf: Vec<u8>) -> Vec<u8> {
    for chunk in buf.chunks_exact_mut(2) {
        let a = chunk[1];
        if a == 255 {
            continue;
        }
        if a == 0 {
            chunk[0] = 0;
        } else {
            chunk[0] = ((chunk[0] as u32 * a as u32 + 127) / 255) as u8;
        }
    }
    buf
}

pub fn bgra_to_best_format(
    bgra_data: Vec<u8>,
    width: u32,
    height: u32,
    force_bgra: bool,
) -> (Vec<u8>, u32, u32, [u8; 4]) {
    if !force_bgra {
        let is_gray = bgra_data
            .chunks_exact(4)
            .all(|c| c[0] == c[1] && c[1] == c[2]);
        if is_gray {
            let mut ga = Vec::with_capacity((width * height * 2) as usize);
            for chunk in bgra_data.chunks_exact(4) {
                ga.push(chunk[0]);
                ga.push(chunk[3]);
            }
            return (ga, width, height, *b" 8AG");
        }
    }
    (bgra_data, width, height, *b"BGRA")
}

/// Convert premultiplied BGRA pixels to premultiplied GA8 by collapsing
/// the BGR channels to a single luma byte via BT.601 weights. Used by the
/// .icon variant axis where every sized rendition is stored as a
/// grayscale tinting mask. Forces conversion even when the source isn't
/// already grayscale; the caller (icon_bundle::build_icon_car) decides
/// when to use this based on the icon-level fill-specializations flag.
pub fn bgra_to_ga8_force(bgra: &[u8]) -> Vec<u8> {
    let mut out = Vec::with_capacity(bgra.len() / 2);
    for px in bgra.chunks_exact(4) {
        // Pixels are premultiplied BGRA; the luma channel inherits the
        // same alpha by virtue of being derived from the BGR components.
        let b = px[0] as u32;
        let g = px[1] as u32;
        let r = px[2] as u32;
        let a = px[3];
        // BT.601 weights ×1000 rounded.
        let y = (299 * r + 587 * g + 114 * b + 500) / 1000;
        out.push(y as u8);
        out.push(a);
    }
    out
}

/// Same as `bgra_to_ga8_force` but promotes luma + alpha to 16-bit. The
/// 16-bit values repeat the byte (x | (x << 8)) so the low and high halves
/// match — Apple uses the same convention for `61AG` (GA16) atlases.
pub fn bgra_to_ga16_force(bgra: &[u8]) -> Vec<u8> {
    let mut out = Vec::with_capacity(bgra.len());
    for px in bgra.chunks_exact(4) {
        let b = px[0] as u32;
        let g = px[1] as u32;
        let r = px[2] as u32;
        let a = px[3];
        let y = (299 * r + 587 * g + 114 * b + 500) / 1000;
        let y16 = (y << 8) | y;
        let a16 = ((a as u16) << 8) | (a as u16);
        out.extend_from_slice(&(y16 as u16).to_le_bytes());
        out.extend_from_slice(&a16.to_le_bytes());
    }
    out
}

pub fn load_image_as_bgra(
    path: &Path,
    force_bgra: bool,
) -> Result<(Vec<u8>, u32, u32, [u8; 4])> {
    let img = image::open(path)?;
    let w = img.width();
    let h = img.height();

    match &img {
        DynamicImage::ImageLuma8(luma) if !force_bgra => {
            // Grayscale → add alpha channel (fully opaque, no premultiply needed).
            let mut ga = Vec::with_capacity((w * h * 2) as usize);
            for &px in luma.as_raw() {
                ga.push(px);
                ga.push(0xFF);
            }
            Ok((ga, w, h, *b" 8AG"))
        }
        DynamicImage::ImageLumaA8(la) if !force_bgra => {
            Ok((premultiply_ga8(la.as_raw().clone()), w, h, *b" 8AG"))
        }
        DynamicImage::ImageRgba8(rgba) => {
            // Check grayscale-compatible RGBA (R==G==B) → store as GA8.
            let raw = rgba.as_raw();
            if !force_bgra {
                let is_gray = raw
                    .chunks_exact(4)
                    .all(|c| c[0] == c[1] && c[1] == c[2]);
                if is_gray {
                    let mut ga = Vec::with_capacity((w * h * 2) as usize);
                    for c in raw.chunks_exact(4) {
                        ga.push(c[0]);
                        ga.push(c[3]);
                    }
                    return Ok((premultiply_ga8(ga), w, h, *b" 8AG"));
                }
            }
            let mut bgra = Vec::with_capacity(raw.len());
            for c in raw.chunks_exact(4) {
                bgra.push(c[2]);
                bgra.push(c[1]);
                bgra.push(c[0]);
                bgra.push(c[3]);
            }
            Ok((premultiply_bgra(bgra), w, h, *b"BGRA"))
        }
        _ => {
            // Convert anything else through RGBA → BGRA.
            let rgba = img.to_rgba8();
            let raw = rgba.as_raw();
            let mut bgra = Vec::with_capacity(raw.len());
            for c in raw.chunks_exact(4) {
                bgra.push(c[2]);
                bgra.push(c[1]);
                bgra.push(c[0]);
                bgra.push(c[3]);
            }
            Ok((premultiply_bgra(bgra), w, h, *b"BGRA"))
        }
    }
}

fn parse_color_component(value: &str) -> f64 {
    if value.starts_with("0x") || value.starts_with("0X") {
        return i64::from_str_radix(&value[2..], 16).unwrap_or(0) as f64 / 255.0;
    }
    if value.chars().all(|c| c.is_ascii_digit() || c == '+' || c == '-') {
        let i: i64 = value.parse().unwrap_or(0);
        if i > 1 || i < 0 {
            return i as f64 / 255.0;
        }
        return i as f64;
    }
    let f: f64 = value.parse().unwrap_or(0.0);
    if f > 1.0 {
        return f / 255.0;
    }
    // Cast through f32 to match Apple's single-precision parsing.
    f as f32 as f64
}

fn colorspace_id_for_name(name: &str) -> u32 {
    match name {
        "srgb" => 1,
        "display-p3" => 3,
        "extended-srgb" => 4,
        "extended-linear-srgb" => 7,
        "gray-gamma-22" => 2,
        _ => 1,
    }
}

fn min_ga8_version(platform: &str) -> (u32, u32) {
    match platform {
        "macosx" => (10, 11),
        "iphoneos" | "appletvos" => (9, 0),
        "watchos" => (2, 0),
        _ => (10, 11),
    }
}

/// Minimum deployment target at which host actool embeds JPEGs into the
/// CAR as DWAR-wrapped raw data. Below this, the host emits a loose file.
/// Verified against /usr/bin/actool: macOS 10.9 -> loose file, 10.10 -> CAR.
fn min_jpeg_car_version(platform: &str) -> (u32, u32) {
    match platform {
        "macosx" => (10, 10),
        "iphoneos" | "appletvos" => (9, 0),
        "watchos" => (2, 0),
        _ => (10, 10),
    }
}

pub struct AssetCatalog {
    pub path: PathBuf,
    pub platform: String,
    pub min_deploy: String,
    pub app_icon: Option<String>,
    pub include_languages: Option<Vec<String>>,
    pub development_region: Option<String>,
    identifiers: IndexMap<String, u16>,
    locales_used: HashSet<String>,
    force_bgra: bool,
    /// JPEG imageset entries to copy out as loose files when the
    /// deployment target is below the `min_jpeg_car_version`.
    /// Entries are `(imageset_stem, source_path)`.
    pub loose_jpegs: Vec<(String, PathBuf)>,
    jpeg_in_car: bool,
}

#[derive(Debug, Clone)]
pub struct Facet {
    pub element: u16,
    pub part: Option<u16>,
    pub identifier: u16,
}

/// One image entry from an `.appiconset`, retaining the metadata needed to
/// build the iOS partial plist and loose home-screen PNGs.
#[derive(Debug, Clone)]
pub struct IconImage {
    pub idiom: String,
    pub point_w: u32,
    pub scale: u32,
    pub path: PathBuf,
}

impl AssetCatalog {
    pub fn new(
        path: PathBuf,
        platform: String,
        min_deploy: String,
        app_icon: Option<String>,
        include_languages: Option<Vec<String>>,
        development_region: Option<String>,
    ) -> Self {
        let deploy = {
            let mut parts = min_deploy.split('.');
            let a: u32 = parts.next().and_then(|s| s.parse().ok()).unwrap_or(0);
            let b: u32 = parts.next().and_then(|s| s.parse().ok()).unwrap_or(0);
            (a, b)
        };
        let force_bgra = deploy < min_ga8_version(&platform);
        let jpeg_in_car = deploy >= min_jpeg_car_version(&platform);
        Self {
            path,
            platform,
            min_deploy,
            app_icon,
            include_languages,
            development_region,
            identifiers: IndexMap::new(),
            locales_used: HashSet::new(),
            force_bgra,
            loose_jpegs: Vec::new(),
            jpeg_in_car,
        }
    }

    pub fn get_locales_used(&self) -> Vec<String> {
        let mut v: Vec<_> = self.locales_used.iter().cloned().collect();
        v.sort();
        v
    }

    fn get_identifier(&mut self, name: &str) -> u16 {
        if let Some(v) = self.identifiers.get(name) {
            return *v;
        }
        let id = hash_name(name);
        self.identifiers.insert(name.to_string(), id);
        id
    }

    fn should_include_locale(&self, locale: &str) -> bool {
        let Some(filter) = &self.include_languages else {
            return true;
        };
        if let Some(dev) = &self.development_region {
            if locale == dev {
                return true;
            }
        }
        filter.iter().any(|s| s == locale)
    }

    pub fn parse(&mut self) -> Result<(Vec<Rendition>, IndexMap<String, Facet>)> {
        if !self.path.exists() {
            return Err(anyhow!("Asset catalog not found: {}", self.path.display()));
        }
        let mut renditions = Vec::new();
        let mut facets = IndexMap::new();
        let root = self.path.clone();
        self.parse_directory(&root, &mut renditions, &mut facets, "")?;
        Ok((renditions, facets))
    }

    fn parse_directory(
        &mut self,
        dir: &Path,
        renditions: &mut Vec<Rendition>,
        facets: &mut IndexMap<String, Facet>,
        namespace: &str,
    ) -> Result<()> {
        let mut entries: Vec<PathBuf> = match fs::read_dir(dir) {
            Ok(rd) => rd.filter_map(|e| e.ok().map(|e| e.path())).collect(),
            Err(_) => return Ok(()),
        };
        entries.sort();
        for item in entries {
            let ext = item
                .extension()
                .and_then(|s| s.to_str())
                .unwrap_or("")
                .to_string();
            match ext.as_str() {
                "imageset" => self.parse_imageset(&item, renditions, facets, namespace)?,
                "appiconset" => self.parse_appiconset(&item, renditions, facets)?,
                "iconset" => self.parse_iconset(&item, renditions, facets, namespace)?,
                "colorset" => self.parse_colorset(&item, renditions, facets, namespace)?,
                "dataset" => self.parse_dataset(&item, renditions, facets, namespace)?,
                "spriteatlas" => self.parse_spriteatlas(&item, renditions, facets)?,
                "imagestack" => self.parse_imagestack(&item, renditions, facets)?,
                "" if item.is_dir() => {
                    let mut child_ns = namespace.to_string();
                    let group_json = item.join("Contents.json");
                    if group_json.exists() {
                        if let Ok(v) = read_json(&group_json) {
                            if v.get("properties")
                                .and_then(|p| p.get("provides-namespace"))
                                .and_then(|x| x.as_bool())
                                .unwrap_or(false)
                            {
                                let name =
                                    item.file_name().unwrap_or_default().to_string_lossy();
                                child_ns = if namespace.is_empty() {
                                    format!("{name}/")
                                } else {
                                    format!("{namespace}{name}/")
                                };
                            }
                        }
                    }
                    self.parse_directory(&item, renditions, facets, &child_ns)?;
                }
                _ => {}
            }
        }
        Ok(())
    }

    fn parse_imageset(
        &mut self,
        item: &Path,
        renditions: &mut Vec<Rendition>,
        facets: &mut IndexMap<String, Facet>,
        namespace: &str,
    ) -> Result<()> {
        let name = item.file_stem().unwrap_or_default().to_string_lossy().to_string();
        let facet_name = format!("{namespace}{name}");
        let ident = self.get_identifier(&facet_name);
        let count_before = renditions.len();

        let contents_path = item.join("Contents.json");
        if !contents_path.exists() {
            return Ok(());
        }
        let contents = read_json(&contents_path)?;
        let intent_str = contents
            .get("properties")
            .and_then(|p| p.get("template-rendering-intent"))
            .and_then(|v| v.as_str());
        let template_intent: i32 = match intent_str {
            Some("original") => 0,
            Some("template") => 2,
            _ => 4,
        };

        let images = contents
            .get("images")
            .and_then(|v| v.as_array())
            .cloned()
            .unwrap_or_default();
        for img_info in &images {
            let Some(filename) = img_info.get("filename").and_then(|v| v.as_str()) else {
                continue;
            };
            let img_path = item.join(filename);
            if !img_path.exists() {
                continue;
            }
            let scale = parse_scale(img_info);
            let idiom = img_info
                .get("idiom")
                .and_then(|v| v.as_str())
                .unwrap_or("universal");
            // Drop renditions whose idiom doesn't belong to the target
            // platform. iOS keeps iphone/ipad/universal; `ios-marketing` is
            // an app-icon-only idiom and is dropped from regular imagesets,
            // matching `/usr/bin/actool --platform iphoneos`.
            let idiom_applies = match self.platform.as_str() {
                "macosx" => idiom == "mac" || idiom == "universal",
                "iphoneos" | "iphonesimulator" => {
                    matches!(idiom, "iphone" | "ipad" | "universal")
                }
                _ => true,
            };
            if !idiom_applies {
                continue;
            }
            if self.platform == "macosx" && scale > 2 {
                continue;
            }
            // Idiom is only encoded into the rendition key on idiom platforms;
            // macOS keys omit attribute 15 entirely.
            let idiom_num = if car::is_idiom_platform(&self.platform) {
                car::idiom_value(idiom)
            } else {
                0
            };

            let locale = img_info
                .get("locale")
                .and_then(|v| v.as_str())
                .unwrap_or("")
                .to_string();
            if !locale.is_empty() && !self.should_include_locale(&locale) {
                continue;
            }
            if !locale.is_empty() {
                self.locales_used.insert(locale.clone());
            }

            let direction = img_info
                .get("language-direction")
                .and_then(|v| v.as_str())
                .map(|s| match s {
                    "left-to-right" => car::DIRECTION_LTR,
                    "right-to-left" => car::DIRECTION_RTL,
                    _ => car::DIRECTION_DEFAULT,
                })
                .unwrap_or(car::DIRECTION_DEFAULT);
            let appearance = appearance_from_json(img_info);

            // Renditions added below all share this image entry's idiom; stamp
            // them in one place rather than threading idiom_num through every
            // Rendition literal (PDF/JPEG/SVG/PNG branches).
            let img_rend_start = renditions.len();
            let lower_filename = filename.to_ascii_lowercase();
            if lower_filename.ends_with(".pdf") {
                let raw_pdf = fs::read(&img_path)?;
                // Apple stores the PDF re-serialized through CoreGraphics (a
                // compact, normalized rewrite — iina's 167 KB design PDFs come
                // back ~3.8 KB), not the raw source. Fall back to the raw bytes
                // when CoreGraphics is unavailable.
                let pdf_data =
                    crate::pdf_raster::normalize_pdf(&raw_pdf).unwrap_or(raw_pdf);
                let csi = car::build_pdf_csi(filename, &pdf_data);
                let mut rend = Rendition {
                    name: filename.to_string(),
                    identifier: ident,
                    element: car::ELEMENT_UNIVERSAL,
                    part: car::PART_REGULAR,
                    scale: 0,
                    appearance,
                    direction,
                    layout: car::LAYOUT_PDF,
                    pixel_format: *car::PIXELFMT_PDF,
                    template_rendering_intent: template_intent,
                    min_deploy: self.min_deploy.clone(),
                    platform: self.platform.clone(),
                    ..Rendition::default()
                };
                rend.csi_override = Some(csi);
                renditions.push(rend);

                // Apple's actool emits raster variants of every PDF imageset
                // at @1x and @2x alongside the original PDF rendition. They
                // become packed_ref entries via the existing atlas packer.
                // On non-macOS hosts CoreGraphics isn't available and we
                // skip this — the catalog stays self-consistent but apps
                // that ask for the rasterized variant get nothing.
                for scale in [1u32, 2u32] {
                    let raster = match crate::pdf_raster::rasterize_pdf(&pdf_data, scale) {
                        Ok(r) => r,
                        Err(_) => continue,
                    };
                    // Template PDFs are grayscale icons. bgra_to_best_format
                    // downconverts to ` 8AG` (gray+alpha) when the pixels
                    // have no chroma — matches Apple's PDF rasterization.
                    let (pd, pw, ph, pf) = bgra_to_best_format(
                        raster.bgra,
                        raster.width,
                        raster.height,
                        self.force_bgra,
                    );
                    let cs_id = if &pf == b" 8AG" { 2 } else { 1 };
                    renditions.push(Rendition {
                        name: filename.to_string(),
                        identifier: ident,
                        element: car::ELEMENT_UNIVERSAL,
                        part: car::PART_REGULAR,
                        scale: scale as u16,
                        appearance,
                        direction,
                        layout: car::LAYOUT_ONE_PART_SCALE,
                        pixel_format: pf,
                        width: pw,
                        height: ph,
                        pixel_data: pd,
                        template_rendering_intent: template_intent,
                        is_svg_rasterization: true,
                        colorspace_id: cs_id,
                        min_deploy: self.min_deploy.clone(),
                        platform: self.platform.clone(),
                        ..Rendition::default()
                    });
                }
                stamp_idiom(renditions, img_rend_start, idiom_num);
                continue;
            }

            if lower_filename.ends_with(".jpg") || lower_filename.ends_with(".jpeg") {
                if self.jpeg_in_car {
                    let jpeg_data = fs::read(&img_path)?;
                    let csi = car::build_jpeg_csi(filename, &jpeg_data);
                    let mut rend = Rendition {
                        name: filename.to_string(),
                        identifier: ident,
                        element: car::ELEMENT_UNIVERSAL,
                        part: car::PART_REGULAR,
                        scale: scale as u16,
                        appearance,
                        direction,
                        layout: car::LAYOUT_ONE_PART_SCALE,
                        pixel_format: *car::PIXELFMT_JPEG,
                        template_rendering_intent: template_intent,
                        locale: locale.clone(),
                        colorspace_id: 0,
                        min_deploy: self.min_deploy.clone(),
                        platform: self.platform.clone(),
                        ..Rendition::default()
                    };
                    rend.csi_override = Some(csi);
                    renditions.push(rend);
                } else {
                    // Pre-10.10 macOS targets don't support JPEG-in-CAR —
                    // emit a loose file alongside the compiled output.
                    self.loose_jpegs.push((name.clone(), img_path.clone()));
                }
                stamp_idiom(renditions, img_rend_start, idiom_num);
                continue;
            }

            if lower_filename.ends_with(".svg") {
                let svg_data = fs::read(&img_path)?;
                let csi = car::build_svg_csi(filename, &svg_data);
                let mut vec_rend = Rendition {
                    name: filename.to_string(),
                    identifier: ident,
                    element: car::ELEMENT_UNIVERSAL,
                    part: car::PART_REGULAR,
                    scale: 1,
                    appearance,
                    direction,
                    layout: car::LAYOUT_PDF,
                    pixel_format: *car::PIXELFMT_SVG,
                    min_deploy: self.min_deploy.clone(),
                    platform: self.platform.clone(),
                    ..Rendition::default()
                };
                vec_rend.csi_override = Some(csi);
                renditions.push(vec_rend);

                if svg_raster::has_coresvg() {
                    let (svg_w, svg_h) = svg_raster::parse_svg_dimensions(&svg_data);
                    if svg_w > 0 && svg_h > 0 {
                        for raster_scale in [1u16, 2] {
                            let pixel_data = svg_raster::rasterize_svg(
                                &svg_data,
                                svg_w,
                                svg_h,
                                raster_scale as u32,
                            )?;
                            let pw = svg_w * raster_scale as u32;
                            let ph = svg_h * raster_scale as u32;
                            let (pd, pw, ph, pf) =
                                bgra_to_best_format(pixel_data, pw, ph, self.force_bgra);
                            let cs_id = if &pf == b" 8AG" { 2 } else { 1 };
                            renditions.push(Rendition {
                                name: filename.to_string(),
                                identifier: ident,
                                element: car::ELEMENT_UNIVERSAL,
                                part: car::PART_REGULAR,
                                scale: raster_scale,
                                width: pw,
                                height: ph,
                                pixel_data: pd,
                                pixel_format: pf,
                                appearance,
                                direction,
                                layout: car::LAYOUT_ONE_PART_SCALE,
                                template_rendering_intent: template_intent,
                                is_svg_rasterization: true,
                                locale: locale.clone(),
                                colorspace_id: cs_id,
                                min_deploy: self.min_deploy.clone(),
                                platform: self.platform.clone(),
                                ..Rendition::default()
                            });
                        }
                    }
                }
                stamp_idiom(renditions, img_rend_start, idiom_num);
                continue;
            }

            let (pixel_data, width, height, pixel_format) =
                load_image_as_bgra(&img_path, self.force_bgra)?;
            renditions.push(Rendition {
                name: filename.to_string(),
                identifier: ident,
                element: car::ELEMENT_UNIVERSAL,
                part: car::PART_REGULAR,
                scale: scale as u16,
                width,
                height,
                pixel_data,
                pixel_format,
                appearance,
                direction,
                layout: car::LAYOUT_ONE_PART_SCALE,
                template_rendering_intent: template_intent,
                locale,
                colorspace_id: car::colorspace_for_pixel_format(&pixel_format),
                min_deploy: self.min_deploy.clone(),
                platform: self.platform.clone(),
                ..Rendition::default()
            });
            stamp_idiom(renditions, img_rend_start, idiom_num);
        }
        if count_before < renditions.len() {
            facets.insert(
                facet_name,
                Facet {
                    element: car::ELEMENT_UNIVERSAL,
                    part: Some(car::PART_REGULAR),
                    identifier: ident,
                },
            );
        }
        Ok(())
    }

    fn parse_appiconset(
        &mut self,
        item: &Path,
        renditions: &mut Vec<Rendition>,
        facets: &mut IndexMap<String, Facet>,
    ) -> Result<()> {
        let app_icon = match &self.app_icon {
            Some(v) => v.clone(),
            None => return Ok(()),
        };
        let name = item.file_stem().unwrap_or_default().to_string_lossy().to_string();
        if name != app_icon {
            return Ok(());
        }
        let ident = self.get_identifier(&name);
        let contents_path = item.join("Contents.json");
        if !contents_path.exists() {
            return Ok(());
        }
        let contents = read_json(&contents_path)?;
        let images = contents
            .get("images")
            .and_then(|v| v.as_array())
            .cloned()
            .unwrap_or_default();

        let appicon_start = renditions.len();
        let mut icon_renditions: Vec<(u32, u16, u16)> = Vec::new(); // (point_w, idiom, subtype)
        for img_info in &images {
            let Some(filename) = img_info.get("filename").and_then(|v| v.as_str()) else {
                continue;
            };
            let img_path = item.join(filename);
            if !img_path.exists() {
                continue;
            }
            let img_platform = img_info
                .get("platform")
                .and_then(|v| v.as_str())
                .unwrap_or("");
            if !img_platform.is_empty() && img_platform != self.platform {
                continue;
            }

            // App-icon renditions carry their device idiom on iOS (phone=1,
            // pad=2, marketing=6) so per-device icon lookups resolve. macOS
            // app icons stay idiom-less.
            let idiom_num = if car::is_idiom_platform(&self.platform) {
                let idiom = img_info
                    .get("idiom")
                    .and_then(|v| v.as_str())
                    .unwrap_or("universal");
                car::idiom_value(idiom)
            } else {
                0
            };
            let icon_rend_start = renditions.len();

            let lower_filename = filename.to_ascii_lowercase();
            let scale = parse_scale(img_info);
            let size_str = img_info.get("size").and_then(|v| v.as_str()).unwrap_or("");
            // Floor handles fractional iPad sizes ("83.5x83.5" -> 83).
            let point_w: u32 = size_str
                .split_once('x')
                .and_then(|(w, _)| w.parse::<f64>().ok())
                .map(|f| f.floor() as u32)
                .unwrap_or(0);

            if lower_filename.ends_with(".svg") {
                let svg_data = fs::read(&img_path)?;
                let dim2 = self.icon_size_index(point_w);
                let csi = car::build_svg_csi(filename, &svg_data);
                let mut vec_rend = Rendition {
                    name: filename.to_string(),
                    identifier: ident,
                    element: car::ELEMENT_UNIVERSAL,
                    part: car::PART_ICON,
                    scale: 1,
                    dim2,
                    layout: car::LAYOUT_PDF,
                    pixel_format: *car::PIXELFMT_SVG,
                    min_deploy: self.min_deploy.clone(),
                    platform: self.platform.clone(),
                    ..Rendition::default()
                };
                vec_rend.csi_override = Some(csi);
                renditions.push(vec_rend);

                if svg_raster::has_coresvg() && point_w > 0 {
                    let (mut svg_w, mut svg_h) =
                        svg_raster::parse_svg_dimensions(&svg_data);
                    if svg_w == 0 {
                        svg_w = point_w;
                        svg_h = point_w;
                    }
                    for raster_scale in [1u16, 2] {
                        let pixel_data = svg_raster::rasterize_svg(
                            &svg_data,
                            svg_w,
                            svg_h,
                            raster_scale as u32,
                        )?;
                        let pw = svg_w * raster_scale as u32;
                        let ph = svg_h * raster_scale as u32;
                        let (pd, pw, ph, pf) =
                            bgra_to_best_format(pixel_data, pw, ph, self.force_bgra);
                        let cs_id = if &pf == b" 8AG" { 2 } else { 1 };
                        renditions.push(Rendition {
                            name: filename.to_string(),
                            identifier: ident,
                            element: car::ELEMENT_UNIVERSAL,
                            part: car::PART_ICON,
                            scale: raster_scale,
                            width: pw,
                            height: ph,
                            pixel_data: pd,
                            pixel_format: pf,
                            layout: car::LAYOUT_ONE_PART_SCALE,
                            dim2,
                            template_rendering_intent: 0,
                            is_svg_rasterization: true,
                            colorspace_id: cs_id,
                            min_deploy: self.min_deploy.clone(),
                            platform: self.platform.clone(),
                            ..Rendition::default()
                        });
                        icon_renditions.push((point_w, idiom_num, 0));
                    }
                }
                stamp_idiom(renditions, icon_rend_start, idiom_num);
                continue;
            }

            let (pixel_data, width, height, pixel_format) =
                load_image_as_bgra(&img_path, self.force_bgra)?;
            let dim2 = self.icon_size_index(point_w);
            renditions.push(Rendition {
                name: filename.to_string(),
                identifier: ident,
                element: car::ELEMENT_UNIVERSAL,
                part: car::PART_ICON,
                scale: scale as u16,
                width,
                height,
                pixel_data,
                pixel_format,
                layout: car::LAYOUT_ONE_PART_SCALE,
                dim2,
                template_rendering_intent: 0,
                colorspace_id: car::colorspace_for_pixel_format(&pixel_format),
                min_deploy: self.min_deploy.clone(),
                platform: self.platform.clone(),
                ..Rendition::default()
            });
            stamp_idiom(renditions, icon_rend_start, idiom_num);
            icon_renditions.push((point_w, idiom_num, 0));
        }

        if icon_renditions.is_empty() {
            return Ok(());
        }

        // iPhone Plus/Max: actool synthesizes a 90pt@2x icon (subtype 1792)
        // by reusing the 60pt@3x source — both are 180px — whenever that icon
        // is present. It also gets its own phone/subtype-1792 multisize facet.
        if car::is_idiom_platform(&self.platform) {
            let dim2_60 = self.icon_size_index(60);
            let src = renditions[appicon_start..]
                .iter()
                .find(|r| {
                    r.idiom == car::idiom_value("iphone")
                        && r.scale == 3
                        && r.dim2 == dim2_60
                        && r.part == car::PART_ICON
                })
                .cloned();
            if let Some(mut synth) = src {
                synth.scale = 2;
                synth.subtype = 1792;
                synth.dim2 = self.icon_size_index(90);
                renditions.push(synth);
                icon_renditions.push((90, car::idiom_value("iphone"), 1792));
            }
        }

        // Group the icon point sizes by (idiom, subtype) and emit one
        // MultiSized rendition per group. iOS keys each by idiom (attr 15) and
        // subtype (attr 16), so phone, pad, marketing and the Plus-phone
        // subtype-1792 facet are distinct; macOS uses idiom 0 / subtype 0
        // throughout, collapsing to the single combined facet as before.
        let mut sizes_by_group: IndexMap<(u16, u16), Vec<u32>> = IndexMap::new();
        for (point_w, idiom, subtype) in &icon_renditions {
            let sizes = sizes_by_group.entry((*idiom, *subtype)).or_default();
            if !sizes.contains(point_w) {
                sizes.push(*point_w);
            }
        }
        let mut groups: Vec<(u16, u16)> = sizes_by_group.keys().copied().collect();
        groups.sort_unstable();
        for (idiom, subtype) in groups {
            let mut sizes = sizes_by_group.shift_remove(&(idiom, subtype)).unwrap();
            // Apple lists multisize entries in ascending point-size order; our
            // discovery order is filesystem-defined ("128" sorts before "16").
            sizes.sort_unstable();
            let ms_entries: Vec<MultisizeImageEntry> = sizes
                .iter()
                .map(|w| MultisizeImageEntry {
                    width: *w,
                    height: *w,
                    index: self.icon_size_index(*w) as u32,
                })
                .collect();
            let mut ms_rend = car::build_multisize_rendition(&name, ident, &ms_entries);
            ms_rend.idiom = idiom;
            ms_rend.subtype = subtype;
            renditions.push(ms_rend);
        }

        facets.insert(
            name,
            Facet {
                element: car::ELEMENT_UNIVERSAL,
                part: Some(car::PART_ICON),
                identifier: ident,
            },
        );
        Ok(())
    }

    fn parse_iconset(
        &mut self,
        item: &Path,
        renditions: &mut Vec<Rendition>,
        facets: &mut IndexMap<String, Facet>,
        namespace: &str,
    ) -> Result<()> {
        let name = item.file_stem().unwrap_or_default().to_string_lossy().to_string();
        let facet_name = format!("{namespace}{name}");
        let ident = self.get_identifier(&facet_name);
        let re = regex::Regex::new(r"^icon_(\d+)x(\d+)(?:@(\d+)x)?\.png$").unwrap();
        let mut icon_renditions: Vec<u32> = Vec::new();
        let mut entries: Vec<PathBuf> = match fs::read_dir(item) {
            Ok(rd) => rd.filter_map(|e| e.ok().map(|e| e.path())).collect(),
            Err(_) => return Ok(()),
        };
        entries.sort();
        for img_file in entries {
            if !img_file.is_file() {
                continue;
            }
            let fname = img_file.file_name().unwrap().to_string_lossy().to_string();
            let Some(cap) = re.captures(&fname) else {
                continue;
            };
            let point_w: u32 = cap[1].parse().unwrap_or(0);
            let scale: u32 = cap
                .get(3)
                .map(|m| m.as_str().parse().unwrap_or(1))
                .unwrap_or(1);
            if self.platform == "macosx" && scale > 2 {
                continue;
            }
            let (pixel_data, width, height, pixel_format) =
                load_image_as_bgra(&img_file, self.force_bgra)?;
            let dim2 = icon_dim2(point_w);
            renditions.push(Rendition {
                name: fname,
                identifier: ident,
                element: car::ELEMENT_UNIVERSAL,
                part: car::PART_ICON,
                scale: scale as u16,
                width,
                height,
                pixel_data,
                pixel_format,
                layout: car::LAYOUT_ONE_PART_SCALE,
                dim2,
                template_rendering_intent: 0,
                colorspace_id: car::colorspace_for_pixel_format(&pixel_format),
                min_deploy: self.min_deploy.clone(),
                platform: self.platform.clone(),
                ..Rendition::default()
            });
            icon_renditions.push(point_w);
        }
        if icon_renditions.is_empty() {
            return Ok(());
        }

        let mut ms_entries: Vec<MultisizeImageEntry> = Vec::new();
        let mut seen: HashSet<u32> = HashSet::new();
        for pw in &icon_renditions {
            if seen.insert(*pw) {
                ms_entries.push(MultisizeImageEntry {
                    width: *pw,
                    height: *pw,
                    index: icon_dim2(*pw) as u32,
                });
            }
        }
        // Match Apple's ascending point-size order — read_dir + sort()
        // above lists "icon_128x128.png" before "icon_16x16.png" because
        // the comparison is lexical.
        ms_entries.sort_by_key(|e| e.width);
        let ms_rend = car::build_multisize_rendition(&name, ident, &ms_entries);
        renditions.push(ms_rend);

        facets.insert(
            facet_name,
            Facet {
                element: car::ELEMENT_UNIVERSAL,
                part: Some(car::PART_ICON),
                identifier: ident,
            },
        );
        Ok(())
    }

    fn parse_colorset(
        &mut self,
        item: &Path,
        renditions: &mut Vec<Rendition>,
        facets: &mut IndexMap<String, Facet>,
        namespace: &str,
    ) -> Result<()> {
        let name = item.file_stem().unwrap_or_default().to_string_lossy().to_string();
        let facet_name = format!("{namespace}{name}");
        let ident = self.get_identifier(&facet_name);
        let contents_path = item.join("Contents.json");
        if !contents_path.exists() {
            return Ok(());
        }
        let contents = read_json(&contents_path)?;
        let mut added = false;
        if let Some(arr) = contents.get("colors").and_then(|v| v.as_array()) {
            for entry in arr {
                let color = entry.get("color").cloned().unwrap_or(Value::Null);
                let components = color.get("components").cloned().unwrap_or(Value::Null);
                if components.is_null() {
                    continue;
                }
                let r = parse_color_component(
                    components.get("red").and_then(|v| v.as_str()).unwrap_or("0"),
                );
                let g = parse_color_component(
                    components.get("green").and_then(|v| v.as_str()).unwrap_or("0"),
                );
                let b = parse_color_component(
                    components.get("blue").and_then(|v| v.as_str()).unwrap_or("0"),
                );
                let a = parse_color_component(
                    components.get("alpha").and_then(|v| v.as_str()).unwrap_or("1"),
                );
                let cs_name = color
                    .get("color-space")
                    .and_then(|v| v.as_str())
                    .unwrap_or("srgb");
                let cs_id = colorspace_id_for_name(cs_name);
                let appearance = appearance_from_json(entry);

                let csi = car::build_color_csi(&name, r, g, b, a, cs_id);
                let mut rend = Rendition {
                    name: name.clone(),
                    identifier: ident,
                    element: car::ELEMENT_UNIVERSAL,
                    part: car::PART_COLOR,
                    scale: 1,
                    appearance,
                    layout: car::LAYOUT_COLOR,
                    pixel_format: [0, 0, 0, 0],
                    colorspace_id: 0,
                    min_deploy: self.min_deploy.clone(),
                    platform: self.platform.clone(),
                    ..Rendition::default()
                };
                rend.csi_override = Some(csi);
                renditions.push(rend);
                added = true;
            }
        }
        if added {
            facets.insert(
                facet_name,
                Facet {
                    element: car::ELEMENT_UNIVERSAL,
                    part: Some(car::PART_COLOR),
                    identifier: ident,
                },
            );
        }
        Ok(())
    }

    fn parse_dataset(
        &mut self,
        item: &Path,
        renditions: &mut Vec<Rendition>,
        facets: &mut IndexMap<String, Facet>,
        namespace: &str,
    ) -> Result<()> {
        let name = item.file_stem().unwrap_or_default().to_string_lossy().to_string();
        let facet_name = format!("{namespace}{name}");
        let ident = self.get_identifier(&facet_name);
        let contents_path = item.join("Contents.json");
        if !contents_path.exists() {
            return Ok(());
        }
        let contents = read_json(&contents_path)?;
        if let Some(arr) = contents.get("data").and_then(|v| v.as_array()) {
            for entry in arr {
                let Some(filename) = entry.get("filename").and_then(|v| v.as_str()) else {
                    continue;
                };
                let p = item.join(filename);
                if !p.exists() {
                    continue;
                }
                let raw = fs::read(&p)?;
                let csi = car::build_data_csi(&raw);
                let mut rend = Rendition {
                    name: "CoreStructuredImage".to_string(),
                    identifier: ident,
                    element: car::ELEMENT_UNIVERSAL,
                    part: car::PART_REGULAR,
                    scale: 1,
                    layout: car::LAYOUT_RAW_DATA,
                    pixel_format: *car::PIXELFMT_DATA,
                    min_deploy: self.min_deploy.clone(),
                    platform: self.platform.clone(),
                    ..Rendition::default()
                };
                rend.csi_override = Some(csi);
                renditions.push(rend);
            }
        }
        facets.insert(
            facet_name,
            Facet {
                element: car::ELEMENT_UNIVERSAL,
                part: Some(car::PART_REGULAR),
                identifier: ident,
            },
        );
        Ok(())
    }

    fn parse_spriteatlas(
        &mut self,
        item: &Path,
        renditions: &mut Vec<Rendition>,
        facets: &mut IndexMap<String, Facet>,
    ) -> Result<()> {
        let atlas_name = item.file_stem().unwrap_or_default().to_string_lossy().to_string();
        let atlas_ident = self.get_identifier(&atlas_name);
        facets.insert(
            atlas_name.clone(),
            Facet {
                element: car::ELEMENT_PACKED,
                part: None,
                identifier: atlas_ident,
            },
        );
        let mut entries: Vec<PathBuf> = match fs::read_dir(item) {
            Ok(rd) => rd.filter_map(|e| e.ok().map(|e| e.path())).collect(),
            Err(_) => return Ok(()),
        };
        entries.sort();
        for sprite_item in entries {
            if sprite_item.extension().and_then(|s| s.to_str()) != Some("imageset") {
                continue;
            }
            let sprite_name =
                sprite_item.file_stem().unwrap_or_default().to_string_lossy().to_string();
            let full = format!("{atlas_name}/{sprite_name}");
            let sprite_ident = self.get_identifier(&full);
            let contents_path = sprite_item.join("Contents.json");
            if !contents_path.exists() {
                continue;
            }
            let contents = read_json(&contents_path)?;
            if let Some(arr) = contents.get("images").and_then(|v| v.as_array()) {
                for img_info in arr {
                    let Some(filename) = img_info.get("filename").and_then(|v| v.as_str())
                    else {
                        continue;
                    };
                    let img_path = sprite_item.join(filename);
                    if !img_path.exists() {
                        continue;
                    }
                    let scale = parse_scale(img_info);
                    let (pd, w, h, pf) = load_image_as_bgra(&img_path, self.force_bgra)?;
                    renditions.push(Rendition {
                        name: filename.to_string(),
                        identifier: sprite_ident,
                        element: car::ELEMENT_UNIVERSAL,
                        part: car::PART_REGULAR,
                        scale: scale as u16,
                        width: w,
                        height: h,
                        pixel_data: pd,
                        pixel_format: pf,
                        layout: car::LAYOUT_ONE_PART_SCALE,
                        sprite_atlas_id: atlas_ident,
                        colorspace_id: car::colorspace_for_pixel_format(&pf),
                        min_deploy: self.min_deploy.clone(),
                        platform: self.platform.clone(),
                        ..Rendition::default()
                    });
                }
            }
            facets.insert(
                full,
                Facet {
                    element: car::ELEMENT_UNIVERSAL,
                    part: Some(car::PART_REGULAR),
                    identifier: sprite_ident,
                },
            );
        }
        Ok(())
    }

    fn parse_imagestack(
        &mut self,
        item: &Path,
        renditions: &mut Vec<Rendition>,
        facets: &mut IndexMap<String, Facet>,
    ) -> Result<()> {
        let stack_name = item.file_stem().unwrap_or_default().to_string_lossy().to_string();
        let contents_path = item.join("Contents.json");
        if !contents_path.exists() {
            return Ok(());
        }
        let contents = read_json(&contents_path)?;
        if let Some(layers) = contents.get("layers").and_then(|v| v.as_array()) {
            for layer in layers {
                let Some(layer_filename) =
                    layer.get("filename").and_then(|v| v.as_str())
                else {
                    continue;
                };
                let layer_path = item.join(layer_filename);
                if !layer_path.exists() {
                    continue;
                }
                let layer_name = Path::new(layer_filename)
                    .file_stem()
                    .unwrap_or_default()
                    .to_string_lossy()
                    .to_string();
                let content_imageset = layer_path.join("Content.imageset");
                if !content_imageset.exists() {
                    continue;
                }
                let full = format!("{stack_name}/{layer_name}/Content");
                let layer_ident = self.get_identifier(&full);
                let img_contents_path = content_imageset.join("Contents.json");
                if !img_contents_path.exists() {
                    continue;
                }
                let img_contents = read_json(&img_contents_path)?;
                if let Some(arr) = img_contents.get("images").and_then(|v| v.as_array())
                {
                    for img_info in arr {
                        let Some(filename) =
                            img_info.get("filename").and_then(|v| v.as_str())
                        else {
                            continue;
                        };
                        let p = content_imageset.join(filename);
                        if !p.exists() {
                            continue;
                        }
                        let scale = parse_scale(img_info);
                        let idiom = img_info
                            .get("idiom")
                            .and_then(|v| v.as_str())
                            .unwrap_or("universal");
                        if self.platform == "macosx"
                            && idiom != "mac"
                            && idiom != "universal"
                        {
                            continue;
                        }
                        let (pd, w, h, pf) = load_image_as_bgra(&p, false)?;
                        renditions.push(Rendition {
                            name: filename.to_string(),
                            identifier: layer_ident,
                            element: car::ELEMENT_UNIVERSAL,
                            part: car::PART_REGULAR,
                            scale: scale as u16,
                            width: w,
                            height: h,
                            pixel_data: pd,
                            pixel_format: pf,
                            layout: car::LAYOUT_ONE_PART_SCALE,
                            colorspace_id: car::colorspace_for_pixel_format(&pf),
                            min_deploy: self.min_deploy.clone(),
                            platform: self.platform.clone(),
                            ..Rendition::default()
                        });
                    }
                }
                facets.insert(
                    full,
                    Facet {
                        element: car::ELEMENT_UNIVERSAL,
                        part: Some(car::PART_REGULAR),
                        identifier: layer_ident,
                    },
                );
            }
        }
        Ok(())
    }

    /// App-icon size index (rendition key Dimension2), using the platform's
    /// size table. iOS sizes differ from macOS, and an incorrect index makes
    /// same-scale icons collide on a shared key.
    fn icon_size_index(&self, point_w: u32) -> u16 {
        if car::is_idiom_platform(&self.platform) {
            ios_icon_dim2(point_w)
        } else {
            icon_dim2(point_w)
        }
    }

    /// App-icon images with their idiom and point size preserved, for the iOS
    /// partial-plist and loose-PNG emission (which key off idiom + home-screen
    /// size). Unlike `get_icon_images` (macOS .icns input) this keeps the
    /// idiom string and the declared point width, and skips vector sources.
    pub fn get_appicon_images(&self) -> Result<Vec<IconImage>> {
        let app_icon = match &self.app_icon {
            Some(v) => v.clone(),
            None => return Ok(Vec::new()),
        };
        let icon_dir = self.path.join(format!("{app_icon}.appiconset"));
        let contents_path = icon_dir.join("Contents.json");
        if !contents_path.exists() {
            return Ok(Vec::new());
        }
        let contents = read_json(&contents_path)?;
        let mut result = Vec::new();
        if let Some(arr) = contents.get("images").and_then(|v| v.as_array()) {
            for img_info in arr {
                let Some(filename) = img_info.get("filename").and_then(|v| v.as_str())
                else {
                    continue;
                };
                let path = icon_dir.join(filename);
                if !path.exists() {
                    continue;
                }
                let idiom = img_info
                    .get("idiom")
                    .and_then(|v| v.as_str())
                    .unwrap_or("universal")
                    .to_string();
                let size_str = img_info.get("size").and_then(|v| v.as_str()).unwrap_or("");
                let point_w: u32 = size_str
                    .split_once('x')
                    .and_then(|(w, _)| w.parse().ok())
                    .unwrap_or(0);
                result.push(IconImage {
                    idiom,
                    point_w,
                    scale: parse_scale(img_info),
                    path,
                });
            }
        }
        Ok(result)
    }

    pub fn get_icon_images(&self) -> Result<Vec<(PathBuf, u32, u32)>> {
        let app_icon = match &self.app_icon {
            Some(v) => v.clone(),
            None => return Ok(Vec::new()),
        };
        let icon_dir = self.path.join(format!("{app_icon}.appiconset"));
        if !icon_dir.exists() {
            return Ok(Vec::new());
        }
        let contents_path = icon_dir.join("Contents.json");
        if !contents_path.exists() {
            return Ok(Vec::new());
        }
        let contents = read_json(&contents_path)?;
        let mut result = Vec::new();
        if let Some(arr) = contents.get("images").and_then(|v| v.as_array()) {
            for img_info in arr {
                let Some(filename) = img_info.get("filename").and_then(|v| v.as_str())
                else {
                    continue;
                };
                if filename.to_ascii_lowercase().ends_with(".svg") {
                    continue;
                }
                let p = icon_dir.join(filename);
                if !p.exists() {
                    continue;
                }
                let scale = parse_scale(img_info);
                let size_str = img_info.get("size").and_then(|v| v.as_str()).unwrap_or("");
                let Some((w_part, _)) = size_str.split_once('x') else {
                    continue;
                };
                let point_w: u32 = w_part.parse().unwrap_or(0);
                let pixel_size = point_w * scale;
                result.push((p, pixel_size, scale));
            }
        }
        Ok(result)
    }
}

/// Stamp the device idiom onto every rendition appended since `start`. Used to
/// tag all of an image entry's renditions (a PDF/SVG entry expands into several)
/// without repeating `idiom` in each Rendition literal.
fn stamp_idiom(renditions: &mut [Rendition], start: usize, idiom: u16) {
    if idiom == 0 {
        return;
    }
    for r in &mut renditions[start..] {
        r.idiom = idiom;
    }
}

fn parse_scale(img_info: &Value) -> u32 {
    let s = img_info
        .get("scale")
        .and_then(|v| v.as_str())
        .unwrap_or("1x");
    s.trim_end_matches('x').parse().unwrap_or(1)
}

fn appearance_from_json(v: &Value) -> u16 {
    if let Some(arr) = v.get("appearances").and_then(|x| x.as_array()) {
        for app in arr {
            if app.get("appearance").and_then(|s| s.as_str()) == Some("luminosity")
                && app.get("value").and_then(|s| s.as_str()) == Some("dark")
            {
                return 1;
            }
        }
    }
    0
}

fn read_json(path: &Path) -> Result<Value> {
    let raw = fs::read_to_string(path)?;
    Ok(serde_json::from_str(&raw)?)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parse_color_integer_normalised() {
        assert!((parse_color_component("128") - 128.0 / 255.0).abs() < 1e-10);
        assert_eq!(parse_color_component("0"), 0.0);
        assert_eq!(parse_color_component("1"), 1.0);
    }

    #[test]
    fn parse_color_hex() {
        assert!((parse_color_component("0x80") - 128.0 / 255.0).abs() < 1e-10);
    }

    #[test]
    fn parse_color_float_f32_roundtrip() {
        let v = parse_color_component("0.5");
        let f: f64 = 0.5f32 as f64;
        assert_eq!(v, f);
    }

    #[test]
    fn premultiply_bgra_zero_alpha() {
        let data = vec![0xFF, 0xFF, 0xFF, 0x00];
        let out = premultiply_bgra(data);
        assert_eq!(out, vec![0, 0, 0, 0]);
    }

    #[test]
    fn premultiply_bgra_half_alpha() {
        let data = vec![0xFF, 0xFF, 0xFF, 0x80];
        let out = premultiply_bgra(data);
        // (255 * 128 + 127) / 255 = 128
        assert_eq!(out, vec![128, 128, 128, 128]);
    }

    #[test]
    fn bgra_grayscale_detected() {
        // R=G=B=0x80, A=0xFF → GA8
        let data = vec![0x80, 0x80, 0x80, 0xFF, 0x80, 0x80, 0x80, 0xFF];
        let (out, w, h, fmt) = bgra_to_best_format(data, 2, 1, false);
        assert_eq!(&fmt, b" 8AG");
        assert_eq!(out, vec![0x80, 0xFF, 0x80, 0xFF]);
        assert_eq!(w, 2);
        assert_eq!(h, 1);
    }

    #[test]
    fn bgra_nongray_kept() {
        let data = vec![0xFF, 0x00, 0x00, 0xFF];
        let (_, _, _, fmt) = bgra_to_best_format(data, 1, 1, false);
        assert_eq!(&fmt, b"BGRA");
    }
}
