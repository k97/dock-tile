//! Frozen-snapshot regression test for `BomWriter` output.
//! Regenerate `tests/parity_references/bom_reference.bin` from the test's
//! debug dump (`tmp/bom_rust_output.bin`) when the writer changes intentionally.

use actool::bom::BomWriter;

#[test]
fn matches_frozen_snapshot() {
    let mut bom = BomWriter::new();
    bom.add_named_block("CARHEADER", b"hello world data".to_vec());
    let entries = vec![
        (b"key1".to_vec(), b"valA".to_vec()),
        (b"key2".to_vec(), b"valB".to_vec()),
    ];
    bom.add_tree("TESTTREE", &entries, 4096);
    let raw: Vec<(u32, Vec<u8>)> =
        vec![(1, b"aaaa".to_vec()), (2, b"bbbb".to_vec())];
    bom.add_raw_key_tree("RTBL", &raw, 1024);
    let ours = bom.to_bytes();

    let reference_path = "tests/parity_references/bom_reference.bin";
    let reference = std::fs::read(reference_path).expect("read reference");
    if ours != reference {
        let _ = std::fs::create_dir_all("tmp");
        let _ = std::fs::write("tmp/bom_rust_output.bin", &ours);
        let mut diffs = 0;
        for (i, (a, b)) in ours.iter().zip(reference.iter()).enumerate() {
            if a != b && diffs < 20 {
                eprintln!("@{i:#06x}: rust={a:02x} reference={b:02x}");
                diffs += 1;
            }
        }
        panic!(
            "BOM byte mismatch: rust_len={} reference_len={}",
            ours.len(),
            reference.len()
        );
    }
}
