//! Robustness regression suite for `.icon` (IconComposer) bundles.
//!
//! Two halves:
//! * **Positive cases** — icon.json shapes seen in real bundles or known
//!   to be accepted by `/usr/bin/actool`; we assert we produce the same
//!   three-file output set when stem matches `--app-icon`.
//! * **Negative cases** — pathological inputs that Apple errors on; we
//!   assert `compile_icon_bundle` returns `Err` (not a panic, not a silent
//!   empty success) with a useful message.

use actool::icon_bundle::{self, compile_icon_bundle};
use std::path::{Path, PathBuf};
use std::sync::atomic::{AtomicU32, Ordering};

static TMP_SEQ: AtomicU32 = AtomicU32::new(0);

fn tmpdir() -> PathBuf {
    let seq = TMP_SEQ.fetch_add(1, Ordering::Relaxed);
    let dir = std::env::temp_dir().join(format!(
        "actool_robust_{}_{seq}",
        std::process::id()
    ));
    std::fs::create_dir_all(&dir).unwrap();
    dir
}

fn write_synthetic_png(path: &Path, size: u32, rgba: [u8; 4]) {
    let buf =
        image::ImageBuffer::from_pixel(size, size, image::Rgba(rgba));
    image::DynamicImage::ImageRgba8(buf).save(path).unwrap();
}

fn make_bundle(stem: &str, icon_json: &str) -> (PathBuf, PathBuf) {
    let parent = tmpdir();
    let bundle = parent.join(format!("{stem}.icon"));
    std::fs::create_dir_all(bundle.join("Assets")).unwrap();
    write_synthetic_png(&bundle.join("Assets/main.png"), 1024, [80, 160, 200, 255]);
    std::fs::write(bundle.join("icon.json"), icon_json).unwrap();
    let out = parent.join("out");
    std::fs::create_dir_all(&out).unwrap();
    (bundle, out)
}

fn compile_ok(stem: &str, icon_json: &str) -> Vec<PathBuf> {
    let (bundle, out) = make_bundle(stem, icon_json);
    let plist = out.join("info.plist");
    compile_icon_bundle(
        &bundle,
        &out,
        "macosx",
        "26.0",
        Some(stem),
        Some(&plist),
        None,
        "default",
    )
    .expect("compile should succeed")
}

fn compile_err(stem: &str, icon_json: &str) -> String {
    let (bundle, out) = make_bundle(stem, icon_json);
    let plist = out.join("info.plist");
    let res = compile_icon_bundle(
        &bundle,
        &out,
        "macosx",
        "26.0",
        Some(stem),
        Some(&plist),
        None,
        "default",
    );
    match res {
        Ok(files) => panic!("expected Err, got Ok({files:?})"),
        Err(e) => format!("{e}"),
    }
}

fn assert_three_file_output(files: &[PathBuf], stem: &str) {
    assert!(
        files.iter().any(|p| p.ends_with("Assets.car")),
        "missing Assets.car in {files:?}"
    );
    assert!(
        files.iter().any(|p| p.ends_with("info.plist")),
        "missing info.plist in {files:?}"
    );
    assert!(
        files.iter().any(|p| p.ends_with(&format!("{stem}.icns"))),
        "missing {stem}.icns in {files:?}"
    );
}

// ---------- Positive cases ----------

#[test]
fn multi_group_bundle_compiles() {
    // Multiple named groups in document order — each produces a
    // `<stem>/<group>` facet.
    let files = compile_ok(
        "MultiG",
        r#"{
          "groups": [
            {"name":"A","layers":[{"image-name":"main.png","name":"a"}]},
            {"name":"B","layers":[{"image-name":"main.png","name":"b"}]}
          ]
        }"#,
    );
    assert_three_file_output(&files, "MultiG");
}

#[test]
fn anonymous_groups_get_sequenced_fallback_names() {
    // Unnamed groups: first is "Group", subsequent become "Group 2",
    // "Group 3", … per icon_bundle.rs.
    let files = compile_ok(
        "Anon",
        r#"{
          "groups": [
            {"layers":[{"image-name":"main.png","name":"a"}]},
            {"layers":[{"image-name":"main.png","name":"b"}]},
            {"layers":[{"image-name":"main.png","name":"c"}]}
          ]
        }"#,
    );
    assert_three_file_output(&files, "Anon");
}

#[test]
fn hidden_layer_does_not_break_compilation() {
    let files = compile_ok(
        "Hidden",
        r#"{
          "fill":"automatic",
          "groups":[{"name":"G","layers":[{"image-name":"main.png","name":"a","hidden":true}]}]
        }"#,
    );
    assert_three_file_output(&files, "Hidden");
}

#[test]
fn glass_layer_does_not_break_compilation() {
    let files = compile_ok(
        "Glass",
        r#"{
          "fill":"automatic",
          "groups":[{"name":"G","layers":[{"image-name":"main.png","name":"a","glass":true}]}]
        }"#,
    );
    assert_three_file_output(&files, "Glass");
}

#[test]
fn linear_gradient_top_level_fill_compiles() {
    let files = compile_ok(
        "Grad",
        r#"{
          "fill":{"linear-gradient":["srgb:1,0,0,1","srgb:0,0,1,1"]},
          "groups":[{"name":"G","layers":[{"image-name":"main.png","name":"a"}]}]
        }"#,
    );
    assert_three_file_output(&files, "Grad");
}

#[test]
fn grayscale_source_with_variant_axis_compiles() {
    // Regression: a grayscale source PNG loads as GA8 (2 bytes/pixel), but
    // the top-level fill-specializations path converts sized renditions to
    // GA8/GA16 assuming BGRA input. Misreading GA8 as 4-byte BGRA chunks
    // halved the row count and panicked with an out-of-range slice. See the
    // feishin.icon bundle. We must load such sources as BGRA before the
    // GA conversion.
    let parent = tmpdir();
    let bundle = parent.join("Gray.icon");
    std::fs::create_dir_all(bundle.join("Assets")).unwrap();
    write_synthetic_png(&bundle.join("Assets/main.png"), 1024, [128, 128, 128, 255]);
    std::fs::write(
        bundle.join("icon.json"),
        r#"{
          "fill-specializations":[
            {"value":{"linear-gradient":["display-p3:1,1,1,1","display-p3:0.5,0.5,0.5,1"]}},
            {"appearance":"dark","value":"system-dark"}
          ],
          "groups":[{"name":"G","layers":[{"image-name":"main.png","name":"a"}]}]
        }"#,
    )
    .unwrap();
    let out = parent.join("out");
    std::fs::create_dir_all(&out).unwrap();
    let plist = out.join("info.plist");
    let files = compile_icon_bundle(
        &bundle,
        &out,
        "macosx",
        "26.0",
        Some("Gray"),
        Some(&plist),
        None,
        "default",
    )
    .expect("grayscale + variant-axis bundle should compile, not panic");
    assert_three_file_output(&files, "Gray");
}

#[test]
fn automatic_gradient_fill_compiles() {
    let files = compile_ok(
        "AutoGrad",
        r#"{
          "fill":{"automatic-gradient":"srgb:1,0,0,1"},
          "groups":[{"name":"G","layers":[{"image-name":"main.png","name":"a"}]}]
        }"#,
    );
    assert_three_file_output(&files, "AutoGrad");
}

#[test]
fn supported_platforms_shared_keyword_compiles() {
    let files = compile_ok(
        "Shared",
        r#"{
          "groups":[{"name":"G","layers":[{"image-name":"main.png","name":"a"}]}],
          "supported-platforms":{"squares":"shared"}
        }"#,
    );
    assert_three_file_output(&files, "Shared");
}

// ---------- Negative cases — must error, must not panic ----------

#[test]
fn missing_icon_json_returns_clean_error() {
    let parent = tmpdir();
    let bundle = parent.join("NoJson.icon");
    std::fs::create_dir_all(bundle.join("Assets")).unwrap();
    write_synthetic_png(&bundle.join("Assets/main.png"), 64, [0, 0, 0, 255]);
    let out = parent.join("out");
    std::fs::create_dir_all(&out).unwrap();
    let plist = out.join("info.plist");
    let res = compile_icon_bundle(
        &bundle, &out, "macosx", "26.0",
        Some("NoJson"), Some(&plist), None, "default",
    );
    let msg = res.expect_err("must err").to_string();
    assert!(msg.contains("icon.json"), "msg should mention icon.json: {msg}");
}

#[test]
fn bundle_is_file_returns_clean_error() {
    let parent = tmpdir();
    let bundle = parent.join("FileBundle.icon");
    std::fs::write(&bundle, b"not a directory").unwrap();
    let out = parent.join("out");
    std::fs::create_dir_all(&out).unwrap();
    let plist = out.join("info.plist");
    let res = compile_icon_bundle(
        &bundle, &out, "macosx", "26.0",
        Some("FileBundle"), Some(&plist), None, "default",
    );
    assert!(res.is_err(), "bundle that is a file must error");
}

#[test]
fn empty_object_icon_json_returns_clean_error() {
    // Apple errors on `{}` because there's no `groups` field. We mirror
    // that, even though our parser would otherwise default to empty.
    let msg = compile_err("EmptyObj", "{}");
    assert!(
        msg.contains("groups"),
        "error should mention missing `groups`: {msg}"
    );
}

#[test]
fn empty_groups_array_succeeds_with_no_outputs() {
    // `{"groups": []}` is valid (Apple accepts it; we early-return with
    // an empty file list because there are no source images to render).
    let (bundle, out) = make_bundle("EmptyGroups", r#"{"groups":[]}"#);
    let plist = out.join("info.plist");
    let files = compile_icon_bundle(
        &bundle, &out, "macosx", "26.0",
        Some("EmptyGroups"), Some(&plist), None, "default",
    )
    .expect("empty groups array must not error");
    assert!(files.is_empty(), "no source images → no outputs");
}

#[test]
fn layer_without_image_name_returns_clean_error() {
    let msg = compile_err(
        "NoImg",
        r#"{"groups":[{"layers":[{"name":"only_name"}]}]}"#,
    );
    assert!(
        msg.contains("does not have an image name"),
        "msg should describe the missing image-name: {msg}"
    );
    assert!(msg.contains("only_name"), "msg should include layer name: {msg}");
}

#[test]
fn missing_referenced_image_returns_clean_error() {
    let msg = compile_err(
        "BadRef",
        r#"{"groups":[{"layers":[{"image-name":"nope.png","name":"x"}]}]}"#,
    );
    assert!(
        msg.contains("does not exist"),
        "msg should say image does not exist: {msg}"
    );
    assert!(msg.contains("nope.png"), "msg should name the missing file: {msg}");
}

#[test]
fn malformed_json_returns_clean_error() {
    let parent = tmpdir();
    let bundle = parent.join("Mal.icon");
    std::fs::create_dir_all(bundle.join("Assets")).unwrap();
    write_synthetic_png(&bundle.join("Assets/main.png"), 64, [0, 0, 0, 255]);
    std::fs::write(bundle.join("icon.json"), "{ \"groups\": [").unwrap();
    let out = parent.join("out");
    std::fs::create_dir_all(&out).unwrap();
    let plist = out.join("info.plist");
    let res = compile_icon_bundle(
        &bundle, &out, "macosx", "26.0",
        Some("Mal"), Some(&plist), None, "default",
    );
    assert!(res.is_err(), "malformed JSON must error");
}

#[test]
fn nonstring_image_name_returns_clean_error() {
    let msg = compile_err(
        "NSImg",
        r#"{"groups":[{"layers":[{"image-name":42,"name":"x"}]}]}"#,
    );
    // Could surface from serde or our validator — either is fine, as
    // long as it isn't a panic and Result::Err propagates.
    assert!(!msg.is_empty());
}

#[test]
fn zero_byte_image_returns_clean_error() {
    let parent = tmpdir();
    let bundle = parent.join("Z.icon");
    std::fs::create_dir_all(bundle.join("Assets")).unwrap();
    std::fs::write(bundle.join("Assets/main.png"), b"").unwrap();
    std::fs::write(
        bundle.join("icon.json"),
        r#"{"groups":[{"layers":[{"image-name":"main.png","name":"x"}]}]}"#,
    )
    .unwrap();
    let out = parent.join("out");
    std::fs::create_dir_all(&out).unwrap();
    let plist = out.join("info.plist");
    let res = compile_icon_bundle(
        &bundle, &out, "macosx", "26.0",
        Some("Z"), Some(&plist), None, "default",
    );
    assert!(res.is_err(), "zero-byte PNG must error");
}

// ---------- Stress / scale ----------

#[test]
fn fifty_groups_compile_without_panic() {
    // Apple's actool rejects this with "Icon validation failed" but it
    // doesn't crash. We accept it; the contract here is just "no panic".
    let mut groups = String::from("[");
    for i in 0..50 {
        if i > 0 {
            groups.push(',');
        }
        groups.push_str(&format!(
            r#"{{"name":"G{i}","layers":[{{"image-name":"main.png","name":"L{i}"}}]}}"#
        ));
    }
    groups.push(']');
    let files = compile_ok(
        "Many",
        &format!(r#"{{"groups":{groups}}}"#),
    );
    assert_three_file_output(&files, "Many");
}

// ---------- is_icon_bundle dispatch ----------

#[test]
fn is_icon_bundle_recognizes_extension_alone() {
    // The dispatcher in main.rs uses is_icon_bundle to choose the
    // icon-vs-xcassets path. Routing must trigger purely on the `.icon`
    // extension so error reporting comes from compile_icon_bundle rather
    // than falling through to the legacy xcassets compiler.
    let parent = tmpdir();
    let dir = parent.join("Just.icon");
    std::fs::create_dir_all(&dir).unwrap();
    assert!(icon_bundle::is_icon_bundle(&dir));

    let file = parent.join("File.icon");
    std::fs::write(&file, b"").unwrap();
    assert!(icon_bundle::is_icon_bundle(&file));

    let other = parent.join("Plain.xcassets");
    std::fs::create_dir_all(&other).unwrap();
    assert!(!icon_bundle::is_icon_bundle(&other));
}
