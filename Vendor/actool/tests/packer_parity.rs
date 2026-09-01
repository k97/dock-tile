//! Parity with the Python packer.py shelf algorithm.
//!
//! Uses a fixed set of image dimensions (originally generated from
//! `random.seed(42)` in Python) and compares placement coordinates
//! against the Python implementation's output.

use actool::packer::{pack_images_split, PackedImage};

// (name, width, height) — captured from:
//   random.seed(42)
//   [(w=randint(8,60), h=randint(8,40)) for _ in range(20)]
const INPUTS: &[(&str, u32, u32)] = &[
    ("img_0", 48, 15),
    ("img_1", 9, 25),
    ("img_2", 23, 22),
    ("img_3", 16, 14),
    ("img_4", 51, 13),
    ("img_5", 45, 35),
    ("img_6", 10, 9),
    ("img_7", 13, 21),
    ("img_8", 22, 40),
    ("img_9", 46, 9),
    ("img_10", 43, 20),
    ("img_11", 53, 34),
    ("img_12", 22, 36),
    ("img_13", 45, 25),
    ("img_14", 59, 8),
    ("img_15", 56, 18),
    ("img_16", 52, 35),
    ("img_17", 29, 25),
    ("img_18", 17, 21),
    ("img_19", 56, 29),
];

// Expected placement (name, x, y) from the Python implementation.
const EXPECTED: &[(&str, u32, u32)] = &[
    ("img_8", 2, 2),
    ("img_12", 26, 2),
    ("img_16", 50, 2),
    ("img_5", 104, 2),
    ("img_11", 151, 2),
    ("img_19", 2, 44),
    ("img_13", 206, 2),
    ("img_17", 60, 44),
    ("img_1", 91, 44),
    ("img_2", 102, 44),
    ("img_18", 127, 44),
    ("img_7", 146, 44),
    ("img_10", 161, 44),
    ("img_15", 2, 75),
    ("img_0", 60, 75),
    ("img_3", 206, 44),
    ("img_4", 110, 75),
    ("img_9", 163, 75),
    ("img_6", 206, 29),
    ("img_14", 2, 95),
];

#[test]
fn parity_with_python_shelf_layout() {
    let inputs: Vec<PackedImage> = INPUTS
        .iter()
        .enumerate()
        .map(|(i, (name, w, h))| PackedImage::new(name.to_string(), i as u32, *w, *h))
        .collect();

    let atlases = pack_images_split(inputs, 262, 196);
    assert_eq!(atlases.len(), 1, "expected single atlas");
    let atlas = &atlases[0];
    assert_eq!(atlas.width, 253);
    assert_eq!(atlas.height, 105);

    let mut by_name = std::collections::HashMap::new();
    for img in &atlas.images {
        by_name.insert(img.name.clone(), (img.x, img.y));
    }
    for (name, ex_x, ex_y) in EXPECTED {
        let (gx, gy) = by_name.get(*name).unwrap_or_else(|| panic!("missing {name}"));
        assert_eq!(
            (*gx, *gy),
            (*ex_x, *ex_y),
            "{name}: rust=({gx},{gy}) python=({ex_x},{ex_y})"
        );
    }
}
