//! Apple actool name hashing.
//!
//! Matches `/usr/bin/actool` byte-for-byte: a djb2-family Bernstein
//! multiplicative hash (seed `0x189d7`, multiplier 33) accumulated into
//! a 64-bit register, then folded into 16 bits via Horner's scheme with
//! the same multiplier. A zero result is remapped to 1 so callers can
//! use 0 as a sentinel.

const M: u64 = 33;

pub fn hash_name(name: &str) -> u16 {
    let mut h: u64 = 0x189D7;
    for byte in name.as_bytes() {
        h = h.wrapping_mul(M).wrapping_add(*byte as u64);
    }
    let c0 = h & 0xFFFF;
    let c1 = (h >> 16) & 0xFFFF;
    let c2 = (h >> 32) & 0xFFFF;
    let c3 = (h >> 48) & 0xFFFF;
    let m3 = M.wrapping_mul(M).wrapping_mul(M);
    let m2 = M.wrapping_mul(M);
    let folded = c0.wrapping_mul(m3)
        .wrapping_add(c1.wrapping_mul(m2))
        .wrapping_add(c2.wrapping_mul(M))
        .wrapping_add(c3);
    let result = (folded & 0xFFFF) as u16;
    if result == 0 { 1 } else { result }
}

#[cfg(test)]
mod tests {
    use super::*;

    // Golden values captured from /usr/bin/actool (see tests/test_name_hash.py).
    const GOLDEN: &[(&str, u16)] = &[
        ("a", 0xa2ca),
        ("z", 0x5843),
        ("pp", 0x4062),
        ("qqq", 0xbbe2),
        ("Img001", 0x27d5),
        ("Img002", 0xb436),
        ("Img009", 0x8add),
        ("AppIcon", 0x1ac1),
        ("HelloWorld", 0x07ca),
        ("button_primary", 0xdf14),
        ("really_long_name_goes_here_abc_xyz_123", 0x3446),
        ("foo.bar.baz", 0xee88),
        ("profile-avatar@2x-like", 0x4206),
        ("aaaaaaaaaa", 0xb07b),
        ("aaaaaaaaaaaaaaa", 0x5275),
    ];

    #[test]
    fn golden_vectors() {
        for (name, expected) in GOLDEN {
            assert_eq!(hash_name(name), *expected, "hash({name:?}) mismatch");
        }
    }

    #[test]
    fn never_returns_zero() {
        for name in ["a", "b", "Img001", "HelloWorld", ""] {
            assert_ne!(hash_name(name), 0);
        }
    }
}
