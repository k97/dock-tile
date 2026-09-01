//! Objective-C / Swift asset symbol generation.

use anyhow::Result;
use indexmap::IndexMap;
use std::collections::HashSet;
use std::fs;
use std::path::{Path, PathBuf};

fn platform_idioms(platform: &str) -> HashSet<&'static str> {
    match platform {
        "macosx" => ["mac", "universal"].into_iter().collect(),
        "iphoneos" | "iphonesimulator" => {
            ["iphone", "ipad", "ios-marketing", "car", "universal"]
                .into_iter()
                .collect()
        }
        "watchos" | "watchsimulator" => {
            ["watch", "universal"].into_iter().collect()
        }
        "appletvos" | "appletvsimulator" => {
            ["tv", "universal"].into_iter().collect()
        }
        _ => ["universal"].into_iter().collect(),
    }
}

#[derive(Debug, Clone)]
pub enum AssetKind {
    Image,
    Color,
}

impl AssetKind {
    fn as_str(&self) -> &'static str {
        match self {
            AssetKind::Image => "image",
            AssetKind::Color => "color",
        }
    }
}

#[derive(Debug, Clone)]
pub struct Asset {
    pub kind: AssetKind,
    pub leaf_name: String,
    pub namespaced_name: String,
    pub relative_path: String,
}

fn entry_applies(contents_path: &Path, platform: &str, keys: &[&str]) -> bool {
    let content = match fs::read_to_string(contents_path) {
        Ok(s) => s,
        Err(_) => return false,
    };
    let parsed: serde_json::Value = match serde_json::from_str(&content) {
        Ok(v) => v,
        Err(_) => return false,
    };
    let allowed = platform_idioms(platform);
    for key in keys {
        if let Some(arr) = parsed.get(key).and_then(|v| v.as_array()) {
            for entry in arr {
                let idiom = entry
                    .get("idiom")
                    .and_then(|v| v.as_str())
                    .unwrap_or("universal");
                if allowed.contains(idiom) {
                    return true;
                }
            }
        }
    }
    false
}

pub fn walk_assets(xcassets_path: &Path, platform: &str) -> Vec<Asset> {
    let mut results = Vec::new();
    walk_assets_inner(xcassets_path, platform, "", "", &mut results);
    results
}

fn walk_assets_inner(
    root: &Path,
    platform: &str,
    rel_prefix: &str,
    namespace: &str,
    out: &mut Vec<Asset>,
) {
    if !root.is_dir() {
        return;
    }
    let mut entries: Vec<PathBuf> = match fs::read_dir(root) {
        Ok(rd) => rd.filter_map(|e| e.ok().map(|e| e.path())).collect(),
        Err(_) => return,
    };
    entries.sort();
    for item in entries {
        if !item.is_dir() {
            continue;
        }
        let contents = item.join("Contents.json");
        let name = item.file_stem().unwrap_or_default().to_string_lossy().to_string();
        let namespaced = format!("{namespace}{name}");
        let file_name = item.file_name().unwrap_or_default().to_string_lossy().to_string();
        let rel = if rel_prefix.is_empty() {
            file_name.clone()
        } else {
            format!("{rel_prefix}{file_name}")
        };

        let suffix = item.extension().and_then(|s| s.to_str()).unwrap_or("");
        match suffix {
            "imageset" => {
                if entry_applies(&contents, platform, &["images"]) {
                    out.push(Asset {
                        kind: AssetKind::Image,
                        leaf_name: name,
                        namespaced_name: namespaced,
                        relative_path: rel,
                    });
                }
            }
            "colorset" => {
                if entry_applies(&contents, platform, &["colors"]) {
                    out.push(Asset {
                        kind: AssetKind::Color,
                        leaf_name: name,
                        namespaced_name: namespaced,
                        relative_path: rel,
                    });
                }
            }
            "" => {
                let mut child_ns = namespace.to_string();
                if contents.exists() {
                    if let Ok(raw) = fs::read_to_string(&contents) {
                        if let Ok(json) = serde_json::from_str::<serde_json::Value>(&raw) {
                            if json
                                .get("properties")
                                .and_then(|p| p.get("provides-namespace"))
                                .and_then(|v| v.as_bool())
                                .unwrap_or(false)
                            {
                                child_ns = format!("{namespace}{name}/");
                            }
                        }
                    }
                }
                let child_rel = format!("{rel_prefix}{file_name}/");
                walk_assets_inner(&item, platform, &child_rel, &child_ns, out);
            }
            _ => {}
        }
    }
}

#[derive(Debug, PartialEq, Eq)]
enum Kind {
    Upper,
    Lower,
    Digit,
    Sep,
}

fn kind_of(ch: char) -> Kind {
    if ch.is_alphabetic() {
        if ch.is_uppercase() {
            Kind::Upper
        } else {
            Kind::Lower
        }
    } else if ch.is_ascii_digit() {
        Kind::Digit
    } else {
        Kind::Sep
    }
}

pub fn split_words(name: &str) -> Vec<String> {
    let mut words: Vec<String> = Vec::new();
    let mut current = String::new();
    let mut prev: Option<Kind> = None;
    for ch in name.chars() {
        let k = kind_of(ch);
        if let Kind::Sep = k {
            if !current.is_empty() {
                words.push(std::mem::take(&mut current));
            }
            prev = Some(Kind::Sep);
            continue;
        }
        match prev {
            None | Some(Kind::Sep) => {
                current.push(ch);
            }
            Some(ref pk) if pk == &k => {
                current.push(ch);
            }
            Some(Kind::Lower) if k == Kind::Upper => {
                words.push(std::mem::take(&mut current));
                current.push(ch);
            }
            Some(Kind::Upper) if k == Kind::Lower => {
                // UPPERLower: last upper belongs with the lower run
                if current.chars().count() > 1 {
                    let mut chars: Vec<char> = current.chars().collect();
                    let last = chars.pop().unwrap();
                    let head: String = chars.into_iter().collect();
                    words.push(head);
                    current = String::from(last);
                }
                current.push(ch);
            }
            _ => {
                words.push(std::mem::take(&mut current));
                current.push(ch);
            }
        }
        prev = Some(k);
    }
    if !current.is_empty() {
        words.push(current);
    }
    words
}

pub fn objc_identifier(name: &str) -> String {
    let words = split_words(name);
    let mut out = String::new();
    for w in &words {
        if w.is_empty() {
            continue;
        }
        let mut chars = w.chars();
        if let Some(first) = chars.next() {
            if first.is_alphabetic() {
                for c in first.to_uppercase() {
                    out.push(c);
                }
                for c in chars {
                    out.push(c);
                }
            } else {
                out.push_str(w);
            }
        }
    }
    out
}

pub fn swift_identifier(name: &str, kind: &str) -> String {
    let mut words = split_words(name);
    let strip = match kind {
        "image" => Some("image"),
        "color" => Some("color"),
        "symbol" => Some("symbol"),
        _ => None,
    };
    if let Some(s) = strip {
        if words.len() > 1 && words.last().map(|w| w.to_lowercase()).as_deref() == Some(s) {
            words.pop();
        }
    }

    let mut out = String::new();
    for (i, w) in words.iter().enumerate() {
        if w.is_empty() {
            continue;
        }
        if i == 0 {
            let all_upper_alpha =
                w.chars().all(|c| c.is_alphabetic()) && w.chars().all(|c| c.is_uppercase());
            if all_upper_alpha {
                out.push_str(&w.to_lowercase());
            } else {
                let mut chars = w.chars();
                if let Some(first) = chars.next() {
                    if first.is_alphabetic() {
                        for c in first.to_lowercase() {
                            out.push(c);
                        }
                        for c in chars {
                            out.push(c);
                        }
                    } else {
                        out.push_str(w);
                    }
                }
            }
        } else {
            let mut chars = w.chars();
            if let Some(first) = chars.next() {
                if first.is_alphabetic() {
                    for c in first.to_uppercase() {
                        out.push(c);
                    }
                    for c in chars {
                        out.push(c);
                    }
                } else {
                    out.push_str(w);
                }
            }
        }
    }
    if out.chars().next().map(|c| c.is_ascii_digit()).unwrap_or(false) {
        out.insert(0, '_');
    }
    out
}

pub fn objc_symbol_name(kind: &AssetKind, leaf_name: &str) -> String {
    let prefix = match kind {
        AssetKind::Color => "ACColorName",
        AssetKind::Image => "ACImageName",
    };
    format!("{prefix}{}", objc_identifier(leaf_name))
}

pub fn generate_symbols_header(
    xcassets_path: &Path,
    output_path: &Path,
    bundle_identifier: &str,
    platform: &str,
) -> Result<()> {
    let assets = walk_assets(xcassets_path, platform);
    let mut images: Vec<_> = assets
        .iter()
        .filter(|a| matches!(a.kind, AssetKind::Image))
        .collect();
    let mut colors: Vec<_> = assets
        .iter()
        .filter(|a| matches!(a.kind, AssetKind::Color))
        .collect();
    images.sort_by(|a, b| a.namespaced_name.cmp(&b.namespaced_name));
    colors.sort_by(|a, b| a.namespaced_name.cmp(&b.namespaced_name));

    let mut s = String::new();
    s.push_str("#import <Foundation/Foundation.h>\n\n");
    s.push_str("#if __has_attribute(swift_private)\n");
    s.push_str("#define AC_SWIFT_PRIVATE __attribute__((swift_private))\n");
    s.push_str("#else\n");
    s.push_str("#define AC_SWIFT_PRIVATE\n");
    s.push_str("#endif\n\n");

    if !colors.is_empty() {
        s.push_str("/// The resource bundle ID.\n");
        s.push_str(&format!(
            "static NSString * const ACBundleID AC_SWIFT_PRIVATE = @\"{bundle_identifier}\";\n\n"
        ));
    }

    for c in &colors {
        let ident = objc_identifier(&c.namespaced_name);
        s.push_str(&format!(
            "/// The \"{}\" asset catalog color resource.\n",
            c.namespaced_name
        ));
        s.push_str(&format!(
            "static NSString * const ACColorName{ident} AC_SWIFT_PRIVATE = @\"{}\";\n\n",
            c.namespaced_name
        ));
    }

    for i in &images {
        let ident = objc_identifier(&i.namespaced_name);
        s.push_str(&format!(
            "/// The \"{}\" asset catalog image resource.\n",
            i.namespaced_name
        ));
        s.push_str(&format!(
            "static NSString * const ACImageName{ident} AC_SWIFT_PRIVATE = @\"{}\";\n\n",
            i.namespaced_name
        ));
    }

    s.push_str("#undef AC_SWIFT_PRIVATE\n");

    if let Some(parent) = output_path.parent() {
        if !parent.as_os_str().is_empty() {
            fs::create_dir_all(parent)?;
        }
    }
    fs::write(output_path, s)?;
    Ok(())
}

pub fn generate_symbol_index(
    xcassets_path: &Path,
    output_path: &Path,
    platform: &str,
) -> Result<()> {
    let assets = walk_assets(xcassets_path, platform);
    let catalog_abs = fs::canonicalize(xcassets_path)
        .unwrap_or_else(|_| xcassets_path.to_path_buf());
    let catalog_str = catalog_abs.to_string_lossy().into_owned();

    let mut colors: Vec<_> = assets
        .iter()
        .filter(|a| matches!(a.kind, AssetKind::Color))
        .collect();
    let mut images: Vec<_> = assets
        .iter()
        .filter(|a| matches!(a.kind, AssetKind::Image))
        .collect();
    colors.sort_by(|a, b| a.relative_path.cmp(&b.relative_path));
    images.sort_by(|a, b| a.relative_path.cmp(&b.relative_path));

    fn entry(asset: &Asset, catalog: &str) -> IndexMap<String, plist::Value> {
        let mut m = IndexMap::new();
        m.insert("catalogPath".to_string(), plist::Value::String(catalog.to_string()));
        m.insert(
            "objcSymbol".to_string(),
            plist::Value::String(objc_symbol_name(&asset.kind, &asset.leaf_name)),
        );
        m.insert(
            "relativePath".to_string(),
            plist::Value::String(format!("./{}", asset.relative_path)),
        );
        m.insert(
            "swiftSymbol".to_string(),
            plist::Value::String(swift_identifier(&asset.leaf_name, asset.kind.as_str())),
        );
        m
    }

    let mut root = plist::Dictionary::new();
    let colors_arr: Vec<plist::Value> = colors
        .iter()
        .map(|a| {
            let m = entry(a, &catalog_str);
            let mut d = plist::Dictionary::new();
            for (k, v) in m {
                d.insert(k, v);
            }
            plist::Value::Dictionary(d)
        })
        .collect();
    let images_arr: Vec<plist::Value> = images
        .iter()
        .map(|a| {
            let m = entry(a, &catalog_str);
            let mut d = plist::Dictionary::new();
            for (k, v) in m {
                d.insert(k, v);
            }
            plist::Value::Dictionary(d)
        })
        .collect();
    root.insert("colors".to_string(), plist::Value::Array(colors_arr));
    root.insert("images".to_string(), plist::Value::Array(images_arr));
    root.insert("symbols".to_string(), plist::Value::Array(vec![]));

    if let Some(parent) = output_path.parent() {
        if !parent.as_os_str().is_empty() {
            fs::create_dir_all(parent)?;
        }
    }
    plist::to_file_xml(output_path, &plist::Value::Dictionary(root))?;
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn objc_identifier_simple() {
        assert_eq!(objc_identifier("Img001"), "Img001");
        assert_eq!(objc_identifier("TestAccent"), "TestAccent");
    }

    #[test]
    fn objc_identifier_separators() {
        assert_eq!(objc_identifier("my-image"), "MyImage");
        assert_eq!(objc_identifier("test_color"), "TestColor");
        assert_eq!(objc_identifier("foo.bar"), "FooBar");
        assert_eq!(objc_identifier("All Caps"), "AllCaps");
    }

    #[test]
    fn objc_identifier_all_uppercase_word_preserved() {
        assert_eq!(objc_identifier("IMAGE_test"), "IMAGETest");
    }

    #[test]
    fn objc_identifier_digit_letter_boundary() {
        assert_eq!(objc_identifier("123num"), "123Num");
    }

    #[test]
    fn swift_simple() {
        assert_eq!(swift_identifier("Img001", "image"), "img001");
        assert_eq!(swift_identifier("TestAccent", "color"), "testAccent");
    }

    #[test]
    fn swift_strip_trailing_type_suffix() {
        assert_eq!(swift_identifier("foo_image", "image"), "foo");
        assert_eq!(swift_identifier("bar_color", "color"), "bar");
        assert_eq!(swift_identifier("my-image", "image"), "my");
        assert_eq!(swift_identifier("myImage", "image"), "my");
    }

    #[test]
    fn swift_do_not_strip_non_trailing() {
        assert_eq!(swift_identifier("image_foo", "image"), "imageFoo");
    }

    #[test]
    fn swift_leading_acronym_lowercased() {
        assert_eq!(swift_identifier("IMAGE_test", "image"), "imageTest");
    }

    #[test]
    fn swift_digit_prefix_underscored() {
        assert_eq!(swift_identifier("123num", "image"), "_123Num");
    }
}
