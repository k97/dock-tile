//! End-to-end tests for `.icon` (IconComposer) bundle compilation.
//!
//! Each test builds a synthetic `.icon` directory in a temp location
//! (no third_party assets) and asserts on structural invariants of the
//! resulting `Assets.car`. The invariants cover regressions that have
//! cost real debugging time — most notably the silent-failure shape
//! documented in `docs/load-crash.md` and the CUICatalog facet
//! resolution bugs covered by commits `e714876`, `d4ebe6f`, and the
//! `<stem>/Group` / `.icns` / palette work that followed.

use actool::icon_bundle;
use std::fs;
use std::io::Cursor;
use std::path::{Path, PathBuf};

// ---------- BOM / CAR parsing helpers (mirrors compare_car.py) ----------

#[derive(Debug)]
struct ParsedCar {
    coreui_version: u32,
    blocks: std::collections::HashMap<u32, (u32, u32)>,
    named: std::collections::HashMap<String, u32>,
    data: Vec<u8>,
}

fn read_u32_be(b: &[u8], off: usize) -> u32 {
    u32::from_be_bytes([b[off], b[off + 1], b[off + 2], b[off + 3]])
}
fn read_u16_be(b: &[u8], off: usize) -> u16 {
    u16::from_be_bytes([b[off], b[off + 1]])
}
fn read_u32_le(b: &[u8], off: usize) -> u32 {
    u32::from_le_bytes([b[off], b[off + 1], b[off + 2], b[off + 3]])
}

fn parse_car(path: &Path) -> ParsedCar {
    let data = fs::read(path).expect("read .car");
    assert_eq!(&data[..8], b"BOMStore", "not a BOM container");
    let idx_off = read_u32_be(&data, 16) as usize;
    let idx_len = read_u32_be(&data, 20) as usize;
    let idx = &data[idx_off..idx_off + idx_len];
    let n = read_u32_be(idx, 0);
    let mut blocks = std::collections::HashMap::new();
    for i in 0..n {
        let off = 4 + (i as usize) * 8;
        let addr = read_u32_be(idx, off);
        let ln = read_u32_be(idx, off + 4);
        blocks.insert(i, (addr, ln));
    }
    let vars_off = read_u32_be(&data, 24) as usize;
    let vars_ln = read_u32_be(&data, 28) as usize;
    let vd = &data[vars_off..vars_off + vars_ln];
    let nv = read_u32_be(vd, 0);
    let mut named = std::collections::HashMap::new();
    let mut p = 4usize;
    for _ in 0..nv {
        let bi = read_u32_be(vd, p);
        let nl = vd[p + 4] as usize;
        let nm = std::str::from_utf8(&vd[p + 5..p + 5 + nl])
            .expect("ascii")
            .to_string();
        p += 5 + nl;
        named.insert(nm, bi);
    }
    let (carhdr_addr, _) = blocks[&named["CARHEADER"]];
    let coreui_version = read_u32_le(&data, carhdr_addr as usize + 4);

    ParsedCar {
        coreui_version,
        blocks,
        named,
        data,
    }
}

fn block_bytes<'a>(parsed: &'a ParsedCar, idx: u32) -> &'a [u8] {
    let (addr, ln) = parsed.blocks[&idx];
    &parsed.data[addr as usize..(addr + ln) as usize]
}

fn tree_root_idx(parsed: &ParsedCar, name: &str) -> u32 {
    let header = block_bytes(parsed, parsed.named[name]);
    read_u32_be(header, 8)
}

/// Walk a fixed-key tree (RENDITIONS / FACETKEYS / APPEARANCEKEYS) and
/// return (key_bytes, value_bytes) pairs.
fn walk_tree(parsed: &ParsedCar, root: u32) -> Vec<(Vec<u8>, Vec<u8>)> {
    let mut out = Vec::new();
    fn recurse(parsed: &ParsedCar, idx: u32, out: &mut Vec<(Vec<u8>, Vec<u8>)>) {
        let b = block_bytes(parsed, idx);
        if b.len() < 12 {
            return;
        }
        let is_leaf = read_u16_be(b, 0);
        let cnt = read_u16_be(b, 2);
        if is_leaf != 0 {
            for i in 0..cnt as usize {
                let pos = 12 + i * 8;
                let vi = read_u32_be(b, pos);
                let ki = read_u32_be(b, pos + 4);
                let k = block_bytes(parsed, ki).to_vec();
                let v = block_bytes(parsed, vi).to_vec();
                out.push((k, v));
            }
        } else {
            let c0 = read_u32_be(b, 12);
            recurse(parsed, c0, out);
            for i in 0..cnt as usize {
                let c = read_u32_be(b, 16 + i * 8 + 4);
                recurse(parsed, c, out);
            }
        }
    }
    recurse(parsed, root, &mut out);
    out
}

/// Walk a raw-key tree (BITMAPKEYS) and return (raw_key, value_bytes).
fn walk_raw_key_tree(parsed: &ParsedCar, root: u32) -> Vec<(u32, Vec<u8>)> {
    let b = block_bytes(parsed, root);
    let mut out = Vec::new();
    if b.len() < 12 {
        return out;
    }
    let _is_leaf = read_u16_be(b, 0);
    let cnt = read_u16_be(b, 2);
    for i in 0..cnt as usize {
        let pos = 12 + i * 8;
        let vi = read_u32_be(b, pos);
        let raw_key = read_u32_be(b, pos + 4);
        let val = block_bytes(parsed, vi).to_vec();
        out.push((raw_key, val));
    }
    out
}

// ---------- Synthetic fixture builders ----------

/// Make a temp dir cleaned at scope exit. We use tempfile so multiple
/// parallel tests don't collide.
fn tempdir() -> tempfile::TempDir {
    tempfile::TempDir::new().expect("tempdir")
}

/// Encode a 1024×1024 solid-blue RGBA PNG so a synthetic `.icon` bundle
/// has a valid PNG layer source without depending on any checked-in asset.
fn write_synthetic_png(path: &Path, dim: u32, rgba: [u8; 4]) {
    let pixels: Vec<u8> = (0..dim * dim).flat_map(|_| rgba).collect();
    let img = image::RgbaImage::from_raw(dim, dim, pixels).expect("from_raw");
    let mut out = Vec::new();
    image::DynamicImage::ImageRgba8(img)
        .write_to(&mut Cursor::new(&mut out), image::ImageFormat::Png)
        .expect("encode png");
    fs::write(path, out).expect("write png");
}

/// Encode a minimal synthetic SVG so we exercise the SVG-source `.icon`
/// path without depending on any checked-in asset. SVG rasterization needs
/// CoreSVG, so the helper and its tests are macOS-only.
#[cfg(target_os = "macos")]
fn write_synthetic_svg(path: &Path) {
    let svg = br##"<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">
    <rect width="1024" height="1024" fill="#4080FF"/>
</svg>"##;
    fs::write(path, svg).expect("write svg");
}

/// Materialize a synthetic `.icon` bundle on disk and return its path.
/// `fill_value` is dropped into the icon.json `fill` field verbatim, and
/// `extra_supported_platforms` overrides `supported-platforms` if Some.
fn build_icon_bundle(
    parent: &Path,
    stem: &str,
    image_filename: &str,
    write_image: impl Fn(&Path),
    fill_value: serde_json::Value,
    group_name: Option<&str>,
    supported_platforms: serde_json::Value,
) -> PathBuf {
    let bundle = parent.join(format!("{stem}.icon"));
    let assets = bundle.join("Assets");
    fs::create_dir_all(&assets).expect("mkdirp Assets");
    write_image(&assets.join(image_filename));

    let group_name_field = match group_name {
        Some(n) => serde_json::json!({ "name": n }),
        None => serde_json::json!({}),
    };
    let layer = serde_json::json!({
        "image-name": image_filename,
        "name": "Logo",
    });
    let mut group = serde_json::json!({
        "layers": [layer],
        "shadow": {"kind": "none", "opacity": 0.5},
        "translucency": {"enabled": false, "value": 0.5},
    });
    if let Some(name) = group_name {
        group.as_object_mut().unwrap().insert(
            "name".to_string(),
            serde_json::Value::String(name.to_string()),
        );
    }
    let _ = group_name_field; // keep helper hint visible

    let mut icon_json = serde_json::json!({
        "fill": fill_value,
        "groups": [group],
    });
    // Treat Value::Null as "omit the supported-platforms field entirely"
    // so tests can exercise the absent-key path.
    if !supported_platforms.is_null() {
        icon_json
            .as_object_mut()
            .unwrap()
            .insert("supported-platforms".to_string(), supported_platforms);
    }
    fs::write(
        bundle.join("icon.json"),
        serde_json::to_string_pretty(&icon_json).unwrap(),
    )
    .expect("write icon.json");
    bundle
}

fn compile(bundle: &Path, app_icon: &str, out: &Path) -> Vec<PathBuf> {
    let plist = out.join("info.plist");
    icon_bundle::compile_icon_bundle(
        bundle,
        out,
        "macosx",
        "26.0",
        Some(app_icon),
        Some(&plist),
        None,
        "default",
    )
    .expect("compile_icon_bundle")
}

// ---------- Assertions / invariants ----------

/// All facets registered in FACETKEYS, decoded as strings.
fn facet_names(parsed: &ParsedCar) -> Vec<String> {
    let root = tree_root_idx(parsed, "FACETKEYS");
    walk_tree(parsed, root)
        .into_iter()
        .map(|(k, _)| String::from_utf8_lossy(&k).to_string())
        .collect()
}

/// Facet identifier values from FACETKEYS, keyed by facet name.
fn facet_identifiers(parsed: &ParsedCar) -> std::collections::HashMap<String, u16> {
    let root = tree_root_idx(parsed, "FACETKEYS");
    let mut out = std::collections::HashMap::new();
    for (k, v) in walk_tree(parsed, root) {
        let name = String::from_utf8_lossy(&k).to_string();
        // value layout: 6-byte header, then 3 (attr,val) pairs; identifier
        // is attr 17 in the (attr,val) sequence — find it explicitly.
        let n_attrs = u16::from_le_bytes([v[4], v[5]]);
        for i in 0..n_attrs as usize {
            let off = 6 + i * 4;
            let attr = u16::from_le_bytes([v[off], v[off + 1]]);
            let val = u16::from_le_bytes([v[off + 2], v[off + 3]]);
            if attr == 17 {
                out.insert(name, val);
                break;
            }
        }
    }
    out
}

/// Count BITMAPKEYS entries (one per facet identifier in a healthy
/// `.icon` catalog). Empty BITMAPKEYS is the silent-failure shape that
/// `e714876` fixed.
fn bitmapkeys_idents(parsed: &ParsedCar) -> Vec<u32> {
    let root = tree_root_idx(parsed, "BITMAPKEYS");
    walk_raw_key_tree(parsed, root).into_iter().map(|(k, _)| k).collect()
}

/// Audit the RENDITIONS leaf inline-key region. Returns true when each
/// entry's separately-stored key block bytes appear, in order, right
/// after the entry table + a 4-byte gap. False means the silent
/// CUICatalog-empty-lookup bug is back.
fn renditions_leaf_inline_matches(parsed: &ParsedCar) -> bool {
    let root = tree_root_idx(parsed, "RENDITIONS");
    let leaf = block_bytes(parsed, root);
    if read_u16_be(leaf, 0) == 0 {
        return true; // internal node — not applicable
    }
    let cnt = read_u16_be(leaf, 2) as usize;
    let entries_end = 12 + cnt * 8;
    let mut rebuilt = Vec::new();
    for i in 0..cnt {
        let pos = 12 + i * 8;
        let ki = read_u32_be(leaf, pos + 4);
        rebuilt.extend_from_slice(block_bytes(parsed, ki));
    }
    // 4-byte gap then inline keys
    let inline = &leaf[entries_end + 4..entries_end + 4 + rebuilt.len()];
    inline == rebuilt.as_slice()
}

// ---------- Tests ----------

#[test]
fn synthetic_png_automatic_fill_produces_iconcomposer_catalog() {
    let dir = tempdir();
    let bundle = build_icon_bundle(
        dir.path(),
        "Synth",
        "main.png",
        |p| write_synthetic_png(p, 1024, [255, 80, 80, 255]),
        serde_json::Value::String("automatic".to_string()),
        Some("Figma"),
        serde_json::json!({"squares": ["macOS"]}),
    );
    let out = dir.path().join("out");
    fs::create_dir_all(&out).unwrap();
    let files = compile(&bundle, "Synth", &out);

    // Bundle stem "Synth" matches --app-icon "Synth" → icns emitted.
    assert!(files.iter().any(|p| p.ends_with("Assets.car")));
    assert!(files.iter().any(|p| p.ends_with("Synth.icns")),
        "bundle stem matches --app-icon: standalone .icns required");

    let car = parse_car(&out.join("Assets.car"));

    // CARHEADER must declare CoreUI 975 — lower values cause silent
    // CUICatalog lookup failures (commit e714876).
    assert_eq!(car.coreui_version, 975, "CoreUI version must be 975 for .icon catalogs");

    // Required named blocks present.
    for required in ["CARHEADER", "RENDITIONS", "FACETKEYS", "APPEARANCEKEYS",
                      "KEYFORMAT", "EXTENDED_METADATA", "BITMAPKEYS"] {
        assert!(car.named.contains_key(required), "missing named block: {required}");
    }

    // Facet inventory: main icon + group + per-layer asset + automatic-fill
    // palette (5 Colors + 2 Gradients).
    let facets: std::collections::HashSet<_> = facet_names(&car).into_iter().collect();
    let expected: std::collections::HashSet<_> = [
        "Synth",
        "Synth/Figma",
        "Synth_Assets/main",
        "Synth_Assets/Color-1",
        "Synth_Assets/Color-2",
        "Synth_Assets/Color-3",
        "Synth_Assets/Color-4",
        "Synth_Assets/Color-5",
        "Synth_Assets/Gradient-1",
        "Synth_Assets/Gradient-2",
    ].iter().map(|s| s.to_string()).collect();
    assert_eq!(facets, expected, "facet inventory mismatch for automatic fill");

    // BITMAPKEYS must list one entry per facet identifier — empty
    // BITMAPKEYS is the silent CUICatalog-failure mode.
    let bk = bitmapkeys_idents(&car);
    let ident_values: std::collections::HashSet<u32> =
        facet_identifiers(&car).into_values().map(|v| v as u32).collect();
    let bk_set: std::collections::HashSet<u32> = bk.into_iter().collect();
    assert_eq!(bk_set, ident_values,
        "BITMAPKEYS must contain one entry per facet identifier");

    // Inline-key region right after the entry table + 4-byte gap must
    // mirror the separately-stored key blocks. This catches the
    // build_leaf_node regression that produced empty lookups.
    assert!(renditions_leaf_inline_matches(&car),
        "RENDITIONS leaf inline-key region doesn't match key blocks");
}

#[test]
fn solid_srgb_fill_emits_4_colors_1_gradient_with_user_color() {
    let dir = tempdir();
    let bundle = build_icon_bundle(
        dir.path(),
        "Solid",
        "main.png",
        |p| write_synthetic_png(p, 1024, [200, 200, 200, 255]),
        serde_json::json!({"solid": "srgb:0.5,0.25,0.125,1.0"}),
        None, // unnamed group → "Solid/Group" facet
        serde_json::json!({"squares": "shared"}),
    );
    let out = dir.path().join("out");
    fs::create_dir_all(&out).unwrap();
    let files = compile(&bundle, "Solid", &out);

    // Stem "Solid" matches --app-icon "Solid" → icns emitted regardless
    // of supported-platforms shape.
    assert!(files.iter().any(|p| p.ends_with("Solid.icns")),
        "matching stem requires standalone .icns");

    let car = parse_car(&out.join("Assets.car"));
    let facets: std::collections::HashSet<_> = facet_names(&car).into_iter().collect();
    // Unnamed group falls back to "Group".
    assert!(facets.contains("Solid/Group"),
        "unnamed group should produce `<stem>/Group` facet");
    // Solid fill produces 4 Colors + 1 Gradient (vs automatic's 5 + 2).
    let color_count = facets.iter().filter(|f| f.contains("_Assets/Color-")).count();
    let gradient_count = facets.iter().filter(|f| f.contains("_Assets/Gradient-")).count();
    assert_eq!(color_count, 4, "solid fill expected 4 Colors, got {color_count}");
    assert_eq!(gradient_count, 1, "solid fill expected 1 Gradient, got {gradient_count}");

    // Color-2 should carry the user's srgb spec at cspace=1 with rounded
    // f32 components. Find its CSI by name and inspect.
    let renditions_root = tree_root_idx(&car, "RENDITIONS");
    let mut color2_components: Option<Vec<f64>> = None;
    let mut color2_cspace: Option<u32> = None;
    for (_, val) in walk_tree(&car, renditions_root) {
        if val.len() < 184 || &val[..4] != b"ISTC" {
            continue;
        }
        let layout = u16::from_le_bytes([val[36], val[37]]);
        if layout != 1009 {
            continue;
        }
        let name_end = 40 + val[40..168].iter().position(|&b| b == 0).unwrap_or(0);
        let name = std::str::from_utf8(&val[40..name_end]).unwrap_or("");
        if !name.ends_with("Color-2") {
            continue;
        }
        let tlv_len = u32::from_le_bytes([val[168], val[169], val[170], val[171]]) as usize;
        let rd = &val[184 + tlv_len..];
        color2_cspace = Some(u32::from_le_bytes([rd[8], rd[9], rd[10], rd[11]]));
        let n_comp = u32::from_le_bytes([rd[12], rd[13], rd[14], rd[15]]) as usize;
        let mut comps = Vec::with_capacity(n_comp);
        for i in 0..n_comp {
            let off = 16 + i * 8;
            let mut buf = [0u8; 8];
            buf.copy_from_slice(&val[184 + tlv_len + off..184 + tlv_len + off + 8]);
            comps.push(f64::from_le_bytes(buf));
        }
        color2_components = Some(comps);
        break;
    }
    let cspace = color2_cspace.expect("Color-2 not found");
    let comps = color2_components.expect("Color-2 components not parsed");
    assert_eq!(cspace, 1, "srgb fill must store Color-2 with cspace=1");
    // Spec values 0.5, 0.25, 0.125 are exactly representable; 1.0 too.
    // The rounding-to-3-decimals path still produces exact values here.
    assert_eq!(comps.len(), 4, "srgb is 4-component");
    assert!((comps[0] - 0.5).abs() < 1e-6, "Color-2[r] mismatch");
    assert!((comps[1] - 0.25).abs() < 1e-6, "Color-2[g] mismatch");
    assert!((comps[2] - 0.125).abs() < 1e-6, "Color-2[b] mismatch");
    assert!((comps[3] - 1.0).abs() < 1e-6, "Color-2[a] mismatch");

    // The RENDITION KEY for Color-2 must use scale=1 (not 0) — that was a
    // separate silent CUICatalog filter bug fixed in e714876.
    let kf_block = block_bytes(&car, car.named["KEYFORMAT"]);
    let n_kf = u32::from_le_bytes([kf_block[8], kf_block[9], kf_block[10], kf_block[11]])
        as usize;
    let attrs: Vec<u16> = (0..n_kf)
        .map(|i| {
            u16::from_le_bytes([
                kf_block[12 + i * 4],
                kf_block[13 + i * 4],
            ])
        })
        .collect();
    let scale_pos = attrs.iter().position(|&a| a == 12).expect("scale attr 12 in keyformat");
    let mut found_color2_with_scale_1 = false;
    for (key, val) in walk_tree(&car, renditions_root) {
        if val.len() < 184 || &val[..4] != b"ISTC" {
            continue;
        }
        if u16::from_le_bytes([val[36], val[37]]) != 1009 {
            continue;
        }
        let name_end = 40 + val[40..168].iter().position(|&b| b == 0).unwrap_or(0);
        let name = std::str::from_utf8(&val[40..name_end]).unwrap_or("");
        if !name.ends_with("Color-2") {
            continue;
        }
        let scale = u16::from_le_bytes([
            key[scale_pos * 2],
            key[scale_pos * 2 + 1],
        ]);
        assert_eq!(scale, 1, "Color rendition KEY must have scale=1 (was {scale})");
        found_color2_with_scale_1 = true;
    }
    assert!(found_color2_with_scale_1, "Color-2 rendition not found in tree");
}

#[test]
#[cfg(target_os = "macos")] // SVG-source bundle requires CoreSVG rasterization
fn svg_source_bundle_does_not_emit_legacy_pdf_only_catalog() {
    // The KYA SIGSEGV regression. Pre-d4ebe6f, an SVG-source `.icon`
    // would emit a single LAYOUT_PDF (9) rendition + a FACETKEYS entry
    // pointing at it — CUICatalog crashed during enumeration. The catalog
    // must instead be a full IconComposer catalog (multisize aggregate +
    // sized renditions). Apple stores the SVG layer source itself as a
    // single Vector rendition named "image.svg" (LAYOUT_PDF), so a lone
    // PDF rendition coexisting with the full structure is now expected —
    // what must never recur is a PDF-*only* catalog.
    let dir = tempdir();
    let bundle = build_icon_bundle(
        dir.path(),
        "Vec",
        "main.svg",
        |p| write_synthetic_svg(p),
        serde_json::Value::String("automatic".to_string()),
        Some("Figma"),
        serde_json::json!({"squares": ["macOS"]}),
    );
    let out = dir.path().join("out");
    fs::create_dir_all(&out).unwrap();
    compile(&bundle, "Vec", &out);
    let car = parse_car(&out.join("Assets.car"));

    let root = tree_root_idx(&car, "RENDITIONS");
    let mut total_renditions = 0usize;
    let mut has_multisize = false;
    let mut svg_layer_rendition_count = 0usize;
    let mut png_layer_rendition_count = 0usize;
    let mut pdf_layout_count = 0usize;
    for (_, val) in walk_tree(&car, root) {
        if val.len() < 184 || &val[..4] != b"ISTC" {
            continue;
        }
        total_renditions += 1;
        let layout = u16::from_le_bytes([val[36], val[37]]);
        if layout == 1010 {
            has_multisize = true;
        }
        if layout == 9 {
            pdf_layout_count += 1;
        }
        let name_end = 40 + val[40..168].iter().position(|&b| b == 0).unwrap_or(0);
        let name = std::str::from_utf8(&val[40..name_end]).unwrap_or("");
        if name == "image.svg" {
            svg_layer_rendition_count += 1;
        }
        if name == "image.png" {
            png_layer_rendition_count += 1;
        }
    }
    assert!(has_multisize, "SVG-source .icon must emit a multisize aggregate");
    assert_eq!(
        svg_layer_rendition_count, 1,
        "SVG-source layer should be stored as exactly one Vector image.svg rendition"
    );
    assert_eq!(
        png_layer_rendition_count, 0,
        "SVG-source layer must not be rasterized to an image.png rendition"
    );
    // Exactly one LAYOUT_PDF — the layer vector — and it must not be the
    // whole catalog (the legacy PDF-only path is the SIGSEGV regression).
    assert_eq!(pdf_layout_count, 1, "expected exactly the layer Vector rendition");
    assert!(
        total_renditions > 5,
        "PDF-only catalog regression: only {total_renditions} renditions"
    );
    // The catalog must still pass the inline-key audit — same invariant
    // as the PNG path.
    assert!(renditions_leaf_inline_matches(&car));
}

#[test]
fn icns_gate_matches_apple_on_bundle_stem_vs_app_icon() {
    // Apple's true rule (verified by toggling stem + --app-icon against
    // /usr/bin/actool): emit `<app-icon>.icns` and a populated partial
    // plist iff the bundle's filename stem matches --app-icon
    // case-sensitively. `supported-platforms` and
    // `--standalone-icon-behavior` do NOT affect this gate.
    let parent = tempdir();
    for (label, stem, app_icon, supported, expect_icns) in [
        // Match — must emit, regardless of supported-platforms.
        ("match_macos_only", "Match", "Match",
            serde_json::json!({"squares": ["macOS"]}), true),
        ("match_shared", "Match2", "Match2",
            serde_json::json!({"squares": "shared"}), true),
        ("match_absent", "Match3", "Match3", serde_json::Value::Null, true),
        // Mismatch — case-sensitive comparison fails → no icns.
        ("case_mismatch", "icon", "Icon",
            serde_json::json!({"squares": ["macOS"]}), false),
        // Mismatch — entirely different names.
        ("name_mismatch", "Mismatch", "Other",
            serde_json::json!({"squares": "shared"}), false),
    ] {
        let bundle = build_icon_bundle(
            parent.path(),
            stem,
            "main.png",
            |p| write_synthetic_png(p, 1024, [128, 128, 128, 255]),
            serde_json::Value::String("automatic".to_string()),
            Some("Figma"),
            supported,
        );
        let out = parent.path().join(format!("out_{label}"));
        fs::create_dir_all(&out).unwrap();
        let files = compile(&bundle, app_icon, &out);
        let icns_emitted = files
            .iter()
            .any(|p| p.extension().is_some_and(|e| e == "icns"));
        assert_eq!(
            icns_emitted, expect_icns,
            "{label}: icns gating mismatch (expect={expect_icns} got={icns_emitted})"
        );

        let plist = fs::read_to_string(out.join("info.plist")).expect("plist");
        if expect_icns {
            assert!(plist.contains("CFBundleIconFile"),
                "{label}: expected populated plist when emitting icns");
            assert!(plist.contains(&format!("<string>{app_icon}</string>")),
                "{label}: plist must reference the --app-icon name");
        } else {
            assert!(plist.contains("<dict/>"),
                "{label}: expected empty <dict/> plist when not emitting icns");
        }
    }
}

/// Two overlapping glass groups with `shadow: layer-color` — the multi-group
/// tinted-glass case the renderer reverse-engineered against a synthetic
/// fixture (each group keeps its own colour; overlaps stack their multiplies).
/// Here we only assert the *structural* invariants — that such a bundle
/// compiles and loads (both group facets present, BITMAPKEYS populated). The
/// pixel-level multiply/stack behaviour is unit-tested in `icon_bundle`.
#[test]
#[cfg(target_os = "macos")] // SVG layer sources require CoreSVG rasterization
fn two_overlapping_glass_groups_compile_and_load() {
    let dir = tempdir();
    let bundle = dir.path().join("MultiGlass.icon");
    let assets = bundle.join("Assets");
    fs::create_dir_all(&assets).unwrap();
    // Left and right overlapping rectangles (overlap in x:384..640).
    fs::write(
        assets.join("Left.svg"),
        br##"<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">
  <rect x="0" y="0" width="640" height="1024" fill="#0033E5"/>
</svg>"##,
    )
    .unwrap();
    fs::write(
        assets.join("Right.svg"),
        br##"<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">
  <rect x="384" y="0" width="640" height="1024" fill="#E51900"/>
</svg>"##,
    )
    .unwrap();
    let group = |name: &str, img: &str, value: f32| {
        serde_json::json!({
            "name": name,
            "layers": [{ "glass": true, "image-name": img, "name": name }],
            "shadow": {"kind": "layer-color", "opacity": 0.5},
            "translucency": {"enabled": true, "value": value},
        })
    };
    let icon_json = serde_json::json!({
        "fill": {"linear-gradient": ["display-p3:0.8,0.8,0.8,1.0", "srgb:0.4,0.4,0.4,1.0"]},
        "groups": [group("Front", "Left.svg", 0.3), group("Back", "Right.svg", 0.5)],
        "supported-platforms": {"squares": ["macOS"]},
    });
    fs::write(
        bundle.join("icon.json"),
        serde_json::to_string_pretty(&icon_json).unwrap(),
    )
    .unwrap();

    let out = dir.path().join("out");
    fs::create_dir_all(&out).unwrap();
    let files = compile(&bundle, "MultiGlass", &out);
    assert!(files.iter().any(|p| p.ends_with("Assets.car")));

    let car = parse_car(&out.join("Assets.car"));
    assert_eq!(car.coreui_version, 975);
    let facets: std::collections::HashSet<_> = facet_names(&car).into_iter().collect();
    for required in ["MultiGlass", "MultiGlass/Front", "MultiGlass/Back"] {
        assert!(facets.contains(required), "missing group facet: {required}");
    }
    // BITMAPKEYS must list one entry per facet identifier (silent-failure guard).
    let bk: std::collections::HashSet<u32> = bitmapkeys_idents(&car).into_iter().collect();
    let idents: std::collections::HashSet<u32> =
        facet_identifiers(&car).into_values().map(|v| v as u32).collect();
    assert_eq!(bk, idents, "BITMAPKEYS must cover every facet identifier");
}
