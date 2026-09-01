//! Per-appearance layer selection in `.icon` IconGroup renditions.
//!
//! Icon Composer expresses per-appearance artwork as a **layer swap**: two
//! layers occupy the same slot and `hidden-specializations` decides which one
//! is visible for each appearance. Apple's `actool` encodes that decision
//! inside every IconGroup rendition — the layer list is identical across
//! appearances, but each layer carries a per-appearance visibility (the 0x03F4
//! entry's f32 alpha and the 0x03FC entry's leading flag).
//!
//! Verified against `/usr/bin/actool` (Xcode 26.6) on a two-layer and a
//! three-layer bundle: the layers are listed in **reverse document order**
//! (painter's back-to-front, the same convention the group list already uses),
//! and exactly the layers visible for that appearance carry alpha 1.0 / flag 1.
//!
//! The regression this guards: the layer list was built once, outside the
//! appearance loop, from the raw sibling `hidden` property — so
//! `hidden-specializations` never reached the catalog, every appearance
//! declared both layers fully visible, and the last layer in document order
//! painted over the others in *every* appearance (a dark-appearance glyph
//! covering the light one in the Default appearance).

use actool::icon_bundle;
use actool::name_hash::hash_name;
use std::collections::HashMap;
use std::fs;
use std::io::Cursor;
use std::path::{Path, PathBuf};

// ---------- BOM / CAR parsing (mirrors tests/icon_bundle_e2e.rs) ----------

struct ParsedCar {
    blocks: HashMap<u32, (u32, u32)>,
    named: HashMap<String, u32>,
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
fn read_u16_le(b: &[u8], off: usize) -> u16 {
    u16::from_le_bytes([b[off], b[off + 1]])
}
fn read_f32_le(b: &[u8], off: usize) -> f32 {
    f32::from_le_bytes([b[off], b[off + 1], b[off + 2], b[off + 3]])
}

fn parse_car(path: &Path) -> ParsedCar {
    let data = fs::read(path).expect("read .car");
    assert_eq!(&data[..8], b"BOMStore", "not a BOM container");
    let idx_off = read_u32_be(&data, 16) as usize;
    let idx_len = read_u32_be(&data, 20) as usize;
    let idx = &data[idx_off..idx_off + idx_len];
    let n = read_u32_be(idx, 0);
    let mut blocks = HashMap::new();
    for i in 0..n {
        let off = 4 + (i as usize) * 8;
        blocks.insert(i, (read_u32_be(idx, off), read_u32_be(idx, off + 4)));
    }
    let vars_off = read_u32_be(&data, 24) as usize;
    let vars_ln = read_u32_be(&data, 28) as usize;
    let vd = &data[vars_off..vars_off + vars_ln];
    let nv = read_u32_be(vd, 0);
    let mut named = HashMap::new();
    let mut p = 4usize;
    for _ in 0..nv {
        let bi = read_u32_be(vd, p);
        let nl = vd[p + 4] as usize;
        let nm = std::str::from_utf8(&vd[p + 5..p + 5 + nl]).expect("ascii");
        named.insert(nm.to_string(), bi);
        p += 5 + nl;
    }
    ParsedCar { blocks, named, data }
}

fn block_bytes<'a>(parsed: &'a ParsedCar, idx: u32) -> &'a [u8] {
    let (addr, ln) = parsed.blocks[&idx];
    &parsed.data[addr as usize..(addr + ln) as usize]
}

fn walk_tree(parsed: &ParsedCar, name: &str) -> Vec<(Vec<u8>, Vec<u8>)> {
    let root = read_u32_be(block_bytes(parsed, parsed.named[name]), 8);
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
                let v = block_bytes(parsed, read_u32_be(b, pos)).to_vec();
                let k = block_bytes(parsed, read_u32_be(b, pos + 4)).to_vec();
                out.push((k, v));
            }
        } else {
            recurse(parsed, read_u32_be(b, 12), out);
            for i in 0..cnt as usize {
                recurse(parsed, read_u32_be(b, 16 + i * 8 + 4), out);
            }
        }
    }
    recurse(parsed, root, &mut out);
    out
}

/// Split a CSI's TLV region (everything after the 184-byte header) into
/// tag -> payload.
fn csi_tlvs(csi: &[u8]) -> HashMap<u32, Vec<u8>> {
    let mut out = HashMap::new();
    let mut pos = 184usize;
    while pos + 8 <= csi.len() {
        let tag = read_u32_le(csi, pos);
        let len = read_u32_le(csi, pos + 4) as usize;
        if pos + 8 + len > csi.len() {
            break;
        }
        out.insert(tag, csi[pos + 8..pos + 8 + len].to_vec());
        pos += 8 + len;
    }
    out
}

const LAYOUT_ICON_GROUP: u16 = 1020;
const APPEARANCE_DARK_AQUA: u16 = 1;
const APPEARANCE_AQUA: u16 = 8;
const APPEARANCE_TINTABLE: u16 = 10;

/// For each appearance, the IconGroup's layers in stored order as
/// (layer identifier, visible).
fn icon_group_layers(parsed: &ParsedCar) -> HashMap<u16, Vec<(u16, bool)>> {
    let mut out = HashMap::new();
    for (key, csi) in walk_tree(parsed, "RENDITIONS") {
        if csi.len() < 184 || &csi[..4] != b"ISTC" {
            continue;
        }
        if read_u16_le(&csi, 36) != LAYOUT_ICON_GROUP {
            continue;
        }
        let appearance = read_u16_le(&key, 0);
        let tlvs = csi_tlvs(&csi);
        let f4 = tlvs.get(&0x03F4).expect("IconGroup 0x03F4 layer list");
        let fc = tlvs.get(&0x03FC).expect("IconGroup 0x03FC layer flags");
        let count = read_u32_le(f4, 0) as usize;
        assert!(count > 0, "IconGroup must reference at least one layer");
        let stride = (f4.len() - 8) / count;
        let mut layers = Vec::new();
        for i in 0..count {
            let off = 4 + i * stride;
            let alpha = read_f32_le(f4, off + 28);
            let ident = read_u16_le(f4, off + 46);
            let flag = read_u32_le(fc, 8 + i * 13);
            // Apple keeps alpha and the flag in lockstep; a mismatch means we
            // encoded visibility in only one of the two places.
            assert_eq!(
                alpha == 1.0,
                flag == 1,
                "layer {i} alpha ({alpha}) and flag ({flag}) disagree for appearance {appearance}"
            );
            layers.push((ident, alpha == 1.0));
        }
        out.insert(appearance, layers);
    }
    out
}

// ---------- Fixture ----------

fn write_png(path: &Path, rgba: [u8; 4]) {
    let dim = 1024u32;
    let pixels: Vec<u8> = (0..dim * dim).flat_map(|_| rgba).collect();
    let img = image::RgbaImage::from_raw(dim, dim, pixels).expect("from_raw");
    let mut out = Vec::new();
    image::DynamicImage::ImageRgba8(img)
        .write_to(&mut Cursor::new(&mut out), image::ImageFormat::Png)
        .expect("encode png");
    fs::write(path, out).expect("write png");
}

/// A synthetic two-layer bundle mirroring the shipping `devtile-fix.icon`
/// authoring model: one group, two glyph layers in the same slot, swapped by
/// `hidden-specializations`. `glyph-light` is visible by default and hidden in
/// dark; `glyph-dark` is the exact inverse.
fn build_layer_swap_bundle(parent: &Path, stem: &str) -> PathBuf {
    let bundle = parent.join(format!("{stem}.icon"));
    let assets = bundle.join("Assets");
    fs::create_dir_all(&assets).expect("mkdirp Assets");
    write_png(&assets.join("glyph-light.png"), [255, 255, 255, 255]);
    write_png(&assets.join("glyph-dark.png"), [107, 207, 128, 255]);

    let icon_json = serde_json::json!({
        "fill": {
            "linear-gradient": ["display-p3:0.41961,0.81176,0.49804,1.00000",
                                "display-p3:0.20392,0.78039,0.34902,1.00000"],
            "orientation": {"start": {"x": 0.5, "y": 0}, "stop": {"x": 0.5, "y": 1}}
        },
        "fill-specializations": [
            {"value": {
                "linear-gradient": ["display-p3:0.41961,0.81176,0.49804,1.00000",
                                    "display-p3:0.20392,0.78039,0.34902,1.00000"],
                "orientation": {"start": {"x": 0.5, "y": 0}, "stop": {"x": 0.5, "y": 1}}}},
            {"appearance": "dark", "value": {
                "linear-gradient": ["display-p3:0.10980,0.10980,0.11765,1.00000",
                                    "display-p3:0.05490,0.05490,0.06275,1.00000"],
                "orientation": {"start": {"x": 0.5, "y": 0}, "stop": {"x": 0.5, "y": 1}}}}
        ],
        "groups": [{
            "layers": [
                {
                    "name": "glyph-light",
                    "image-name": "glyph-light.png",
                    "fill": "none",
                    "hidden-specializations": [
                        {"value": false},
                        {"appearance": "dark", "value": true}
                    ]
                },
                {
                    "name": "glyph-dark",
                    "image-name": "glyph-dark.png",
                    "fill": "none",
                    "hidden-specializations": [
                        {"value": true},
                        {"appearance": "dark", "value": false}
                    ]
                }
            ]
        }],
        "supported-platforms": {"circles": [], "squares": ["macOS"]}
    });
    fs::write(
        bundle.join("icon.json"),
        serde_json::to_string_pretty(&icon_json).unwrap(),
    )
    .expect("write icon.json");
    bundle
}

fn compile(bundle: &Path, app_icon: &str, out: &Path) {
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
    .expect("compile_icon_bundle");
}

// ---------- Tests ----------

/// A layer hidden for `dark` (visible by default) belongs to the light
/// appearances only; a layer visible only for `dark` belongs to the dark
/// appearance only. `tinted` has no specialization of its own, so it inherits
/// the default (no-appearance) entry — i.e. it tracks the light layer.
#[test]
fn hidden_specializations_partition_the_appearance_stacks() {
    let tmp = tempfile::TempDir::new().expect("tempdir");
    let bundle = build_layer_swap_bundle(tmp.path(), "Swap");
    let out = tmp.path().join("out");
    fs::create_dir_all(&out).unwrap();
    compile(&bundle, "Swap", &out);

    let car = parse_car(&out.join("Assets.car"));
    let groups = icon_group_layers(&car);

    let light = hash_name("Swap_Assets/glyph-light");
    let dark = hash_name("Swap_Assets/glyph-dark");

    // Painter's order: icon.json lists layers front-to-back (index 0 topmost),
    // so the stored list runs back-to-front — glyph-dark (doc index 1) first.
    assert_eq!(
        groups.get(&APPEARANCE_AQUA),
        Some(&vec![(dark, false), (light, true)]),
        "Aqua must show only glyph-light"
    );
    assert_eq!(
        groups.get(&APPEARANCE_DARK_AQUA),
        Some(&vec![(dark, true), (light, false)]),
        "DarkAqua must show only glyph-dark"
    );
    assert_eq!(
        groups.get(&APPEARANCE_TINTABLE),
        Some(&vec![(dark, false), (light, true)]),
        "Tintable has no specialization and must inherit the default layer"
    );
}

/// The three appearances must not share one blob: if the IconGroup CSIs are
/// byte-identical, per-appearance visibility was never encoded at all. This is
/// the exact shape of the original defect, and it survives any future change
/// that keeps the layer list but drops the visibility encoding.
#[test]
fn icon_group_renditions_differ_between_appearances() {
    let tmp = tempfile::TempDir::new().expect("tempdir");
    let bundle = build_layer_swap_bundle(tmp.path(), "Swap2");
    let out = tmp.path().join("out");
    fs::create_dir_all(&out).unwrap();
    compile(&bundle, "Swap2", &out);

    let car = parse_car(&out.join("Assets.car"));
    let mut blobs: HashMap<u16, Vec<u8>> = HashMap::new();
    for (key, csi) in walk_tree(&car, "RENDITIONS") {
        if csi.len() >= 184
            && &csi[..4] == b"ISTC"
            && read_u16_le(&csi, 36) == LAYOUT_ICON_GROUP
        {
            blobs.insert(read_u16_le(&key, 0), csi);
        }
    }
    assert_eq!(blobs.len(), 3, "expected one IconGroup per appearance");
    let aqua = blobs.get(&APPEARANCE_AQUA).expect("Aqua IconGroup");
    let dark = blobs.get(&APPEARANCE_DARK_AQUA).expect("DarkAqua IconGroup");
    assert_ne!(
        aqua, dark,
        "Aqua and DarkAqua IconGroups are byte-identical — the layer swap was not encoded"
    );
}

/// A layer with no `hidden-specializations` is visible in every appearance, so
/// a swap in a sibling layer must not switch it off.
#[test]
fn unspecialized_layers_stay_visible_in_every_appearance() {
    let tmp = tempfile::TempDir::new().expect("tempdir");
    let bundle = build_layer_swap_bundle(tmp.path(), "Swap3");
    // Insert a plain middle layer between the two swapped ones.
    let mut json: serde_json::Value =
        serde_json::from_str(&fs::read_to_string(bundle.join("icon.json")).unwrap()).unwrap();
    write_png(&bundle.join("Assets").join("glyph-mid.png"), [10, 20, 30, 255]);
    let layers = json["groups"][0]["layers"].as_array_mut().unwrap();
    layers.insert(
        1,
        serde_json::json!({
            "name": "glyph-mid", "image-name": "glyph-mid.png", "fill": "none"
        }),
    );
    fs::write(
        bundle.join("icon.json"),
        serde_json::to_string_pretty(&json).unwrap(),
    )
    .unwrap();

    let out = tmp.path().join("out");
    fs::create_dir_all(&out).unwrap();
    compile(&bundle, "Swap3", &out);

    let car = parse_car(&out.join("Assets.car"));
    let groups = icon_group_layers(&car);
    let mid = hash_name("Swap3_Assets/glyph-mid");
    for appearance in [APPEARANCE_AQUA, APPEARANCE_DARK_AQUA, APPEARANCE_TINTABLE] {
        let layers = groups.get(&appearance).expect("IconGroup for appearance");
        assert_eq!(
            layers.iter().find(|(id, _)| *id == mid).map(|(_, v)| *v),
            Some(true),
            "unspecialized layer must stay visible in appearance {appearance}"
        );
    }
}
