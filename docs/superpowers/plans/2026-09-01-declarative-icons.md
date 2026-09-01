# Declarative Icons Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. Load the repo skill `.claude/skills/icon-rendering/SKILL.md` before ANY task that touches rendering code.

**Goal:** Replace runtime icon-style detection/swapping on macOS 26 with a per-tile compiled `Assets.car` that macOS renders itself; the legacy path survives only as a quarantined pre-macOS-26 fallback.

**Architecture:** The main app authors a `.icon` document per tile (`IconDocumentBuilder`, pure seam), renders lean glyph-layer PNGs (`IconGenerator` lean entry point), compiles with a vendored Rust `actool` invoked as a subprocess (`IconCompiler`), and installs the validated car + one fallback `.icns` into the helper before signing. One availability seam (`IconPipeline.isDeclarative`) at exactly three activation points. Nothing about a helper's icon ever changes after signing on macOS 26.

**Tech Stack:** Swift 6 / AppKit / SwiftUI, Swift Testing, Rust (vendored viraptor/actool, MIT), `assetutil` (ships with macOS), Xcode build phase + GitHub Actions `macos-26`.

**Spec:** `docs/superpowers/specs/2026-09-01-declarative-icons-design.md` — read it first. Evidence and closed dead ends: `docs/icon-rendering-history.md`. Canonical fixture: `docs/icon-spike-fixtures/devtile-fix.icon`.

## Global Constraints

- macOS floor 15.0; declarative path is `#available(macOS 26, *)` ONLY, via the single seam `IconPipeline.isDeclarative` — never a second scattered availability check for icon behaviour.
- The legacy path (4 variants + detection + swap + reseal) is FROZEN: no edits beyond what a task explicitly lists.
- A helper's seal must never be broken after signing on the declarative path — no runtime writes into the bundle, ever.
- Regression-guard convention: every new decision is a `nonisolated static` (or plain static) pure function taking plain values, unit-tested (see `.claude/rules/testing.md`).
- New files under `DockTileTests/` auto-join the target; **new app-target files need a `project.pbxproj` entry** — this plan creates exactly ONE new app file (`DeclarativeIconPipeline.swift`) to keep that surgery to one spot.
- Never write `UserDefaults.standard` in tests; use scratch directories under `FileManager.default.temporaryDirectory`.
- Never touch the user's live helpers (`~/Library/Application Support/DockTile*/`) or the real Dock plist from tests or manual probes — scratch bundles only (memory: never mutate prod data uninvited).
- Test command (run after every task): `xcodebuild test -project DockTile.xcodeproj -scheme DockTile -configuration Debug -destination 'platform=macOS' -only-testing:DockTileTests CODE_SIGNING_ALLOWED=NO`
- Commits: each `git commit` in its own Bash invocation, never any bare `-n` token in the same command (repo hook). End messages with the standard co-author line.
- Copy/paste hex tint values and JSON keys exactly as given — the `icon.json` schema is community-documented; the fixture is the contract.

---

### Task 1: Vendor the compiler and build it

**Files:**
- Create: `Vendor/actool/` (full source of https://github.com/viraptor/actool at tag `v2.2.4`)
- Create: `Vendor/actool/DOCKTILE-README.md`
- Create: `Scripts/build-compiler.sh`

**Interfaces:**
- Produces: executable at `Vendor/actool/target/release/docktile-actool` (release build of the crate's binary, renamed); `Scripts/build-compiler.sh` (idempotent, fails loudly without cargo).

- [ ] **Step 1: Check the toolchain** — `cargo --version`. If absent, install via `rustup` (https://rustup.rs, stable default) before continuing; note the version in the task report.
- [ ] **Step 2: Vendor the source.** Clone upstream at `v2.2.4` into a temp dir, copy everything except `.git/` into `Vendor/actool/`. Record in `Vendor/actool/DOCKTILE-README.md`:

```markdown
# Vendored: viraptor/actool v2.2.4 (commit <sha>)
Cleanroom Rust reimplementation of Apple's actool for Icon Composer `.icon` documents.
Cargo.toml declares `license = "MIT"`; upstream has no LICENSE file (issue to file upstream).
Local changes: see git log for this directory. Defect fixes carry fixture tests in tests/.
Do NOT update from upstream without re-running the fixture tests AND the manual Dock matrix.
```

- [ ] **Step 3: Write `Scripts/build-compiler.sh`:**

```bash
#!/bin/bash
# Builds the vendored actool into the standalone compiler the app bundles.
# Output: Vendor/actool/target/release/docktile-actool
set -euo pipefail
cd "$(dirname "$0")/../Vendor/actool"
command -v cargo >/dev/null || { echo "error: Rust toolchain required — install via https://rustup.rs" >&2; exit 1; }
cargo build --release --locked
BIN=$(ls target/release/ | grep -x 'actool' || true)
cp "target/release/${BIN:-actool}" target/release/docktile-actool
strip target/release/docktile-actool
echo "built: $(pwd)/target/release/docktile-actool ($(du -h target/release/docktile-actool | cut -f1))"
```

(Adjust the binary name to whatever `[[bin]]`/package name the crate actually declares — check `Cargo.toml` — and keep the `docktile-actool` output name.)
- [ ] **Step 4: Build and smoke-test against the fixture:**

```bash
chmod +x Scripts/build-compiler.sh && Scripts/build-compiler.sh
OUT=$(mktemp -d)
Vendor/actool/target/release/docktile-actool docs/icon-spike-fixtures/devtile-fix.icon --compile "$OUT" <flags per the crate's --help; mirror the spike's usage>
xcrun assetutil --info "$OUT/Assets.car" | grep -c "IconImageStack"   # expect ≥1
```

Expected: car produced, `IconImageStack` renditions present. If the CLI surface differs from Apple's flags, record the working invocation in `DOCKTILE-README.md` — Task 5 needs it verbatim.
- [ ] **Step 5: Ensure `Vendor/actool/target/` is git-ignored** (add to `.gitignore`), then commit the vendored source + script (this is a large commit of third-party code; keep it free of any other change).

### Task 2: Fix OSS defect 2 (layer stack picks the wrong appearance) — THE SHIP GATE

**Files:**
- Modify: `Vendor/actool/src/icon_bundle.rs` (suspected; follow the evidence)
- Create: `Vendor/actool/tests/docktile_appearance.rs`
- Create: `Vendor/actool/tests/fixtures/devtile-fix.icon/` (copy of the repo fixture, so the crate's tests are self-contained)

**Interfaces:**
- Produces: a compiler whose output, for the fixture, renders the LIGHT glyph in Default and the DARK glyph in Dark (Apple-parity), with rendition counts matching Apple's (7 `Icon Image` + 1 `PackedImage` for this input, vs the defective 14 + 2).

This is a debugging task — follow superpowers:systematic-debugging. Phase 1 evidence already recorded (`docs/icon-rendering-history.md`, OSS defects section): defect 1 is root-caused (positional `resolve_background_fills` after `fill_specializations_assets` skips top-level `fill` — worked around in authoring, upstream fix optional); defect 2 is characterised only.

- [ ] **Step 1: Reproduce with instrumentation.** Compile the fixture with the vendored tool; dump the produced car (`xcrun assetutil --info`) and record which image lands in which `IconImageStack`/appearance slot. Add temporary `eprintln!` probes in `collect_stack_layers(…, Appearance::Light|Dark)` and wherever "primary variant"/"alternate" stacks are assigned, showing: layer name, its resolved `hidden` value per appearance, and which stack it joins.
- [ ] **Step 2: Localise.** The two candidate faults from the characterisation: (a) `hidden-specializations` is not resolved when collecting stack layers (both glyph layers land in every stack — would also explain the 14-vs-7 rendition inflation), or (b) the light/dark stack assignment is inverted at primary/alternate mapping. The probe output distinguishes them. State the confirmed root cause in the commit message.
- [ ] **Step 3: Write the failing Rust test** (shape it to the crate's actual internals; the *contract* is fixed even if the assertion mechanism must adapt):

```rust
// tests/docktile_appearance.rs — guards defect 2: per-appearance layer selection.
// Contract: a layer hidden for `dark` (default visible) is in the LIGHT stack only;
// a layer visible only for `dark` is in the DARK stack only; and the fixture compiles
// to exactly the rendition population Apple's actool produces for the same input.
#[test]
fn hidden_specializations_partition_the_stacks() {
    let compiled = compile_fixture("tests/fixtures/devtile-fix.icon"); // helper: run the compile path in-process
    assert_eq!(compiled.stack_layers(Appearance::Light), vec!["glyph-light"]);
    assert_eq!(compiled.stack_layers(Appearance::Dark),  vec!["glyph-dark"]);
}
```

If internals aren't reachable from an integration test, unit-test the layer-resolution function directly in `icon_bundle.rs` (`#[cfg(test)]`) with a two-layer input mirroring the fixture's `hidden-specializations`. Run: `cargo test` in `Vendor/actool` — expected FAIL on current code.
- [ ] **Step 4: Implement the minimal fix** at the confirmed fault site. No drive-by refactors of the crate.
- [ ] **Step 5: Verify** — `cargo test` green; recompile the fixture; `assetutil --info` rendition counts now 7 `Icon Image` + 1 `PackedImage`; remove the probes.
- [ ] **Step 6: Manual oracle check (Dock, scratch only).** Build a scratch bundle (copy the spike recipe in `docs/icon-spike-fixtures/README.md`: car + generated icns + `CFBundleIconName`/`CFBundleIconFile`, ad-hoc sign, pin). Cycle Icon & widget style Default/Dark/Clear/Tinted × Light/Dark. Expected: green + WHITE glyph in Default, near-black + green glyph in Dark — matching `reference-apple-default.png`. Unpin and delete the scratch bundle afterwards.
- [ ] **Step 7: Commit** (fix + tests + fixtures). Then open the upstream PR + the missing-LICENSE issue (separate from this repo's flow; do not block on upstream).

### Task 3: `IconPipeline` seam + `IconDocumentBuilder` (the `.icon` author)

**Files:**
- Create: `DockTile/Utilities/DeclarativeIconPipeline.swift` (+ `project.pbxproj` entry — mirror how `DiagnosticsLog.swift` is registered)
- Create: `DockTileTests/Unit/Utilities/IconDocumentBuilderTests.swift`

**Interfaces:**
- Produces (used by Tasks 4–8):

```swift
enum IconPipeline {
    /// THE one availability branch. Consulted at exactly three activation points
    /// (bundle generation, IconStyleManager activation, migration/self-heal probes).
    static var isDeclarative: Bool {
        if #available(macOS 26.0, *) { return true } else { return false }
    }
}

enum IconAppearance: String { case light, dark, tinted }  // `clear` is NOT authorable

enum IconDocumentBuilder {
    /// Pure: gradient stops as display-P3 components. Encodes the authoring rules:
    /// default entry FIRST inside fill-specializations (OSS defect-1 workaround; harmless
    /// for Apple's compiler), dark override second, tinted omitted (system-controlled
    /// background unless we supply one — we don't; fixture proves 2-layer model).
    nonisolated static func iconJSON(
        fillTopP3: (r: Double, g: Double, b: Double),
        fillBottomP3: (r: Double, g: Double, b: Double),
        darkFillTopP3: (r: Double, g: Double, b: Double),
        darkFillBottomP3: (r: Double, g: Double, b: Double),
        tintedFillTopP3: (r: Double, g: Double, b: Double),
        tintedFillBottomP3: (r: Double, g: Double, b: Double),
        layers: [LayerSpec]
    ) -> [String: Any]
    // The tinted entry matches the PROVEN fixture (which authors a grey tinted background
    // and renders correctly under the system tint). Feed it the same greys the legacy
    // Tinted style uses (tintColor.nsColors(for: .tinted, iconType:)). Do not drop it —
    // the fixture is the contract; whether the system would supply a background without
    // it is unverified.

    struct LayerSpec {
        let name: String            // "glyph-light" | "glyph-dark" | "glyph-emoji"
        let imageName: String       // "\(name).png"
        /// nil = visible in every appearance (emoji single-layer model);
        /// otherwise the ONE appearance this layer is exclusive to (light layer =
        /// hidden for dark; dark layer = hidden by default, shown for dark).
        let exclusiveTo: IconAppearance?
    }

    /// Writes icon.json + Assets/<imageName>.png into a new `<name>.icon` dir under `parent`.
    nonisolated static func writeDocument(
        json: [String: Any], layerPNGs: [String: Data], name: String, parent: URL
    ) throws -> URL
}
```

- [ ] **Step 1: Write failing tests.** Assert against the fixture's exact schema (`docs/icon-spike-fixtures/devtile-fix.icon/icon.json` is the contract):

```swift
@Suite("IconDocumentBuilder JSON shape")
struct IconDocumentBuilderTests {
    private func makeJSON(layers: [IconDocumentBuilder.LayerSpec]) -> [String: Any] {
        IconDocumentBuilder.iconJSON(
            fillTopP3: (0.41961, 0.81176, 0.49804), fillBottomP3: (0.20392, 0.78039, 0.34902),
            darkFillTopP3: (0.10980, 0.10980, 0.11765), darkFillBottomP3: (0.05490, 0.05490, 0.06275),
            tintedFillTopP3: (0.55686, 0.55686, 0.57647), tintedFillBottomP3: (0.42353, 0.42353, 0.43922),
            layers: layers)
    }

    @Test("Top-level fill AND a no-appearance first entry in fill-specializations (defect-1 workaround)")
    func defaultFillIsDuplicatedIntoSpecializations() throws {
        let json = makeJSON(layers: [])
        let fill = try #require(json["fill"] as? [String: Any])
        let stops = try #require(fill["linear-gradient"] as? [String])
        #expect(stops == ["display-p3:0.41961,0.81176,0.49804,1.00000",
                          "display-p3:0.20392,0.78039,0.34902,1.00000"])
        let specs = try #require(json["fill-specializations"] as? [[String: Any]])
        #expect(specs.count == 3)                       // fixture parity: default, dark, tinted
        #expect(specs[0]["appearance"] == nil)          // the default IN the list, first
        #expect(specs[1]["appearance"] as? String == "dark")
        #expect(specs[2]["appearance"] as? String == "tinted")
    }

    @Test("Symbol model: light layer hidden for dark; dark layer default-hidden, shown for dark")
    func symbolLayersSwapByHiddenSpecializations() throws {
        let json = makeJSON(layers: [
            .init(name: "glyph-light", imageName: "glyph-light.png", exclusiveTo: .light),
            .init(name: "glyph-dark",  imageName: "glyph-dark.png",  exclusiveTo: .dark)])
        let groups = try #require(json["groups"] as? [[String: Any]])
        let layers = try #require(groups[0]["layers"] as? [[String: Any]])
        let lightHidden = try #require(layers[0]["hidden-specializations"] as? [[String: Any]])
        #expect(lightHidden[0]["appearance"] == nil && lightHidden[0]["value"] as? Bool == false)
        #expect(lightHidden[1]["appearance"] as? String == "dark" && lightHidden[1]["value"] as? Bool == true)
        let darkHidden = try #require(layers[1]["hidden-specializations"] as? [[String: Any]])
        #expect(darkHidden[0]["value"] as? Bool == true)
        #expect(darkHidden[1]["appearance"] as? String == "dark" && darkHidden[1]["value"] as? Bool == false)
    }

    @Test("Emoji model: single always-visible layer, NO hidden-specializations")
    func emojiSingleLayerHasNoSpecializations() throws {
        let json = makeJSON(layers: [.init(name: "glyph-emoji", imageName: "glyph-emoji.png", exclusiveTo: nil)])
        let layers = try #require((json["groups"] as? [[String: Any]])?[0]["layers"] as? [[String: Any]])
        #expect(layers[0]["hidden-specializations"] == nil)
        #expect(layers[0]["fill"] as? String == "none")
    }

    @Test("Platforms + layer position match the proven fixture")
    func fixtureInvariants() throws {
        let json = makeJSON(layers: [.init(name: "glyph-light", imageName: "glyph-light.png", exclusiveTo: .light)])
        let platforms = try #require(json["supported-platforms"] as? [String: [String]])
        #expect(platforms["squares"] == ["macOS"])
        let layer = try #require((json["groups"] as? [[String: Any]])?[0]["layers"] as? [[String: Any]])?[0]
        let position = try #require(layer?["position"] as? [String: Any])
        #expect(position["scale"] as? Double == 1.0)
    }

    @Test("writeDocument lays out icon.json + Assets/")
    func writeDocumentLayout() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = try IconDocumentBuilder.writeDocument(
            json: makeJSON(layers: []), layerPNGs: ["glyph-light.png": Data([1, 2, 3])],
            name: "tile", parent: dir)
        #expect(url.lastPathComponent == "tile.icon")
        #expect(FileManager.default.fileExists(atPath: url.appendingPathComponent("icon.json").path))
        #expect(try Data(contentsOf: url.appendingPathComponent("Assets/glyph-light.png")) == Data([1, 2, 3]))
    }
}
```

- [ ] **Step 2: Run — expected FAIL** (type not defined / doesn't compile until Step 3's file + pbxproj entry exist; add the file skeleton first if needed to get a red run rather than a build error).
- [ ] **Step 3: Implement** `DeclarativeIconPipeline.swift`: `IconPipeline`, `IconAppearance`, `IconDocumentBuilder.iconJSON` (gradient dict helper `gradientValue(top:bottom:)` producing the fixture's `linear-gradient` + `orientation` shape, stops formatted `String(format: "display-p3:%.5f,%.5f,%.5f,1.00000", r, g, b)`), and `writeDocument` (create `<name>.icon/Assets/`, `JSONSerialization` with `.prettyPrinted, .sortedKeys`, write PNGs).
- [ ] **Step 4: Run tests — expected PASS.** Also compile a builder-produced document with the vendored compiler as a spot check:

```bash
swift snippet or a tiny test-only dump is unnecessary — instead: copy the fixture's PNGs over a
builder-emitted icon.json (same layer names) and run docktile-actool on it; assetutil must show
IconImageStack renditions.
```

- [ ] **Step 5: Commit.**

### Task 4: Lean glyph-layer renderer (+ the V1 emoji-tinted pre-check)

**Files:**
- Modify: `DockTile/Utilities/IconGenerator.swift` (new entry point; reuse `drawGlyph`/`gradientFilledGlyph`/`drawEmoji` internals — do NOT touch the legacy `generateIcon` composition)
- Create: `DockTileTests/Unit/Utilities/GlyphLayerRenderTests.swift`

**Interfaces:**
- Produces:

```swift
extension IconGenerator {
    /// A single 1024×1024 transparent-background layer PNG: glyph + shading gradient +
    /// contact shadow ONLY (no squircle, stroke, or sheens — the system supplies shape+glass).
    /// appearance drives glyph colour: .light → white, .dark → tint.liftedForDarkGlyph,
    /// .tinted → white. Emoji ignore appearance (single full-colour layer; ink-normalised,
    /// lighter contact shadow). Ratio: IconDepthMetrics ratios × canvas — same ratios, new canvas.
    static func generateGlyphLayerPNG(
        appearance: IconAppearance, tintColor: TintColor, iconType: IconType,
        iconValue: String, iconScale: Int, iconWeight: IconWeight,
        canvas: Int = 1024
    ) throws -> Data
}
```

- [ ] **Step 1 (V1 pre-check, BEFORE writing emoji code): emoji under the system tinted pass.** Hand-build one emoji `.icon` (copy `devtile-fix.icon`, replace layers with a single emoji PNG rendered at 1024 via the existing `drawEmoji` path, single always-visible layer), compile, scratch-pin, and check the **Tinted** style in the Dock. Acceptable → proceed with the single-layer emoji model. Unacceptable (illegible/ugly) → add a third grayscale emoji layer `exclusiveTo: .tinted` (bake grayscale via `CIPhotoEffectMono` or luminance draw) and note the deviation in the task report + spec. Record the outcome either way. Unpin + delete scratch.
- [ ] **Step 2: Write failing render tests** (pixel-scan style, mirroring `EmojiInkFitRenderTests` — real draw path, no mocks):

```swift
@Suite("Lean glyph layer rendering")
struct GlyphLayerRenderTests {
    private func bitmap(_ data: Data) throws -> NSBitmapImageRep {
        try #require(NSBitmapImageRep(data: data))
    }

    @Test("Layer canvas is exactly 1024×1024 with transparent corners (no baked squircle)")
    func canvasIsTransparentOutsideGlyph() throws {
        let data = try IconGenerator.generateGlyphLayerPNG(
            appearance: .light, tintColor: .green, iconType: .sfSymbol,
            iconValue: "hammer.fill", iconScale: 14, iconWeight: .medium)
        let rep = try bitmap(data)
        #expect(rep.pixelsWide == 1024 && rep.pixelsHigh == 1024)
        for (x, y) in [(2, 2), (1021, 2), (2, 1021), (1021, 1021)] {
            #expect(rep.colorAt(x: x, y: y)?.alphaComponent == 0)
        }
    }

    @Test("Light layer glyph is white-family; dark layer carries the lifted tint")
    func appearanceDrivesGlyphColour() throws {
        func centreColour(_ appearance: IconAppearance) throws -> NSColor {
            let rep = try bitmap(try IconGenerator.generateGlyphLayerPNG(
                appearance: appearance, tintColor: .green, iconType: .sfSymbol,
                iconValue: "square.fill", iconScale: 14, iconWeight: .medium))
            return try #require(rep.colorAt(x: 512, y: 512)?.usingColorSpace(.sRGB))
        }
        let light = try centreColour(.light)
        #expect(light.brightnessComponent > 0.85 && light.saturationComponent < 0.15)
        let dark = try centreColour(.dark)
        #expect(dark.saturationComponent > 0.3)   // tinted glyph, not white
        let tinted = try centreColour(.tinted)
        #expect(tinted.saturationComponent < 0.15) // mono for the system tint pass
    }

    @Test("Glyph honours the seam ratio on the new canvas")
    func glyphSizeFollowsSeamRatio() throws {
        let rep = try bitmap(try IconGenerator.generateGlyphLayerPNG(
            appearance: .light, tintColor: .green, iconType: .sfSymbol,
            iconValue: "square.fill", iconScale: 14, iconWeight: .medium))
        // Scan the horizontal extent of non-transparent pixels on the centre row.
        var minX = 1024, maxX = 0
        for x in 0..<1024 where (rep.colorAt(x: x, y: 512)?.alphaComponent ?? 0) > 0.1 {
            minX = min(minX, x); maxX = max(maxX, x)
        }
        let measured = Double(maxX - minX + 1) / 1024.0
        let expected = IconDepthMetrics.glyphSizeRatio(iconScale: 14, iconType: .sfSymbol,
                                                       iconValue: "square.fill")
        #expect(abs(measured - expected) < 0.05)   // square.fill ≈ its bounding box
    }

    @Test("Emoji layer renders identically for every appearance (single-layer model)")
    func emojiIgnoresAppearance() throws {
        let a = try IconGenerator.generateGlyphLayerPNG(appearance: .light, tintColor: .green,
            iconType: .emoji, iconValue: "🔨", iconScale: 14, iconWeight: .medium)
        let b = try IconGenerator.generateGlyphLayerPNG(appearance: .dark, tintColor: .green,
            iconType: .emoji, iconValue: "🔨", iconScale: 14, iconWeight: .medium)
        #expect(a == b)
    }
}
```

(Adapt `IconDepthMetrics.glyphSizeRatio`'s exact signature to what the seam declares — check before writing; the assertion contract stands.)
- [ ] **Step 3: Run — expected FAIL** (entry point undefined).
- [ ] **Step 4: Implement.** Explicit-pixel `NSBitmapImageRep` (the `generateIcon` pattern verbatim), transparent fill, then reuse the existing glyph pipeline: for symbols/brand, `gradientFilledGlyph` + contact shadow + glyph sheen? — NO sheen: lean = shading gradient + contact shadow only (spec). Colour per appearance: `.light`/`.tinted` → white foreground; `.dark` → `tintColor`'s `liftedForDarkGlyph` value (same colour the legacy dark bake uses — reuse the existing helper, do not re-derive the luminance floor). Emoji: `drawEmoji` minus the sheen call, lighter contact shadow as today. Brand glyph routes exactly like a symbol (template raster, existing `drawBrandGlyph` internals).
- [ ] **Step 5: Run tests — PASS. Then full suite** (legacy render tests must be untouched-green).
- [ ] **Step 6: Commit.**

### Task 5: `IconCompiler` — subprocess + structural validation

**Files:**
- Modify: `DockTile/Utilities/DeclarativeIconPipeline.swift`
- Create: `DockTileTests/Unit/Utilities/IconCompilerTests.swift`

**Interfaces:**
- Produces:

```swift
enum IconCompilerError: Error { case compilerMissing, compileFailed(String), invalidOutput(String) }

enum IconCompiler {
    /// Bundled compiler URL (main app only; nil in helpers — they must never compile).
    static var bundledCompilerURL: URL? {
        Bundle.main.url(forResource: "docktile-actool", withExtension: nil)
    }

    /// .icon dir → Assets.car in outputDir. Throws loudly; NEVER installs an unvalidated car.
    static func compile(document: URL, outputDir: URL, compilerURL: URL) throws -> URL

    /// Pure classification of `assetutil --info` JSON: the flattening-bug guard.
    /// Valid ⇐ non-empty AND contains ≥1 "IconImageStack" rendition.
    nonisolated static func validate(assetutilJSON: Data) -> Bool
}
```

- [ ] **Step 1: Write failing tests.** `validate` is pure — feed it captured JSON:

```swift
@Suite("IconCompiler validation")
struct IconCompilerTests {
    @Test("A car with IconImageStack renditions validates")
    func stackRenditionsValidate() {
        let json = #"[{"AssetType":"IconImageStack","Name":"x"},{"AssetType":"Color"}]"#
        #expect(IconCompiler.validate(assetutilJSON: Data(json.utf8)))
    }
    @Test("A flattened car (no stack) is INVALID — the Xcode silent-flattening class")
    func flattenedCarIsInvalid() {
        let json = #"[{"AssetType":"MultiSized Image","Name":"x"},{"AssetType":"Color"}]"#
        #expect(!IconCompiler.validate(assetutilJSON: Data(json.utf8)))
        #expect(!IconCompiler.validate(assetutilJSON: Data("[]".utf8)))
        #expect(!IconCompiler.validate(assetutilJSON: Data("not json".utf8)))
    }
}
```

(Before writing `validate`, run `xcrun assetutil --info` on the Task 1 fixture car and match the REAL key names — if the type key isn't `AssetType`, fix the test constants to the observed schema, then implement against those.)
- [ ] **Step 2: Run — FAIL.** **Step 3: Implement** — `compile`: `Process` with the invocation recorded in Task 1 (drain stdout/stderr pipes concurrently *before* `waitUntilExit` — the diagnostics-rule deadlock lesson), non-zero exit → `.compileFailed(stderr)`; then run `/usr/bin/assetutil --info <car>` and gate on `validate` → else `.invalidOutput`. Wrap the whole call in `DiagnosticsLog.measure("compile tile car")`.
- [ ] **Step 4: Integration check (local + CI):** end-to-end test compiling the repo fixture with the built compiler — mark it so it skips (not fails) when `Vendor/actool/target/release/docktile-actool` is absent:

```swift
@Test("End-to-end: fixture .icon compiles to a valid layered car",
      .enabled(if: FileManager.default.fileExists(atPath: IconCompilerTests.builtCompilerPath)))
func fixtureCompilesToValidCar() throws { /* compile devtile-fix.icon into a temp dir; expect no throw */ }
```

- [ ] **Step 5: Full suite green. Commit.**

### Task 6: Wire the Tahoe pipeline into helper generation

**Files:**
- Modify: `DockTile/Managers/HelperBundleManager.swift` (`generateHelperBundle` icon stage, `updateInfoPlist`/`helperInfoPlist` seam, `stripMainAppIcons` sibling strip)
- Modify: `DockTile/Utilities/IconGenerator.swift` (fallback icns: margined lean composition)
- Test: extend `DockTileTests/Unit/Managers/HelperBundlePrepTests.swift`

**Interfaces:**
- Consumes: Tasks 3–5 (`IconDocumentBuilder`, `generateGlyphLayerPNG`, `IconCompiler`).
- Produces: on `IconPipeline.isDeclarative`, a generated helper contains `Resources/Assets.car` (per-tile) + `Resources/AppIcon.icns` (fallback) + Info.plist `CFBundleIconName = "AppIcon"`; NO `AppIcon-{default,dark,clear,tinted}.icns`; NO `docktile-actool`. Legacy branch byte-identical to today.

- [ ] **Step 1: Failing seam tests** in `HelperBundlePrepTests` style: `helperInfoPlist(...declarative: true)` sets `CFBundleIconName` AND keeps `CFBundleIconFile`; `declarative: false` omits `CFBundleIconName`. New pure strip decision: `HelperBundleManager.resourcesToStripFromHelper(declarative: Bool) -> [String]` returns `["Assets.car", "docktile-actool"]` (+ the template icns) — test both modes.
- [ ] **Step 2: Implement the branch** in `generateHelperBundle`:

```swift
if IconPipeline.isDeclarative {
    let layers = try declarativeLayerSpecs(for: config)          // symbol/brand: light+dark; emoji: single
    let json = IconDocumentBuilder.iconJSON(/* P3 components from config.tintColor via
        NSColor.usingColorSpace(.displayP3); dark fill = near-black for symbol/brand,
        tintColor.darkenedForDarkMode for emoji — the same colours the legacy dark bake uses */)
    let doc = try IconDocumentBuilder.writeDocument(json: json, layerPNGs: pngs,
        name: "AppIcon", parent: FileManager.default.temporaryDirectory…)
    defer { try? FileManager.default.removeItem(at: doc) }        // scratch never in the bundle
    guard let compiler = IconCompiler.bundledCompilerURL else { throw IconCompilerError.compilerMissing }
    let car = try IconCompiler.compile(document: doc, outputDir: tempOut, compilerURL: compiler)
    try FileManager.default.copyItem(at: car, to: resources.appendingPathComponent("Assets.car"))
    try IconGenerator.generateFallbackIcns(for: config, outputURL: resources.appendingPathComponent("AppIcon.icns"))
} else {
    /* existing 4-variant code, UNTOUCHED */
}
```

`generateFallbackIcns`: per rendition size, gradient squircle inset to 206/256 of the canvas (transparent margin) + the light lean glyph — reuses `createSquirclePath`/`drawGradient`/the Task 4 glyph draw; no stroke/sheen. Ordering note: the per-tile car is copied in AFTER `stripMainAppIcons` removed the main app's car; signing comes after everything.
- [ ] **Step 3: Full suite green** (the declarative branch runs on this Mac — macOS 26 — so `installHelper`-adjacent tests may exercise it; fix fallout in this task, never by weakening a legacy test).
- [ ] **Step 4: Manual smoke: one real dev tile** (dev build, dev Dock only): create tile → Add to Dock → verify car+icns in the bundle, `codesign --verify` clean, styles cycle correctly, `docktile-actool` absent from the helper.
- [ ] **Step 5: Commit.**

### Task 7: Quarantine detection (activation point 2)

**Files:**
- Modify: `DockTile/Managers/IconStyleManager.swift` (`startObserving`, wake/popover reconciles)
- Modify: `DockTile/App/HelperAppDelegate.swift` (launch heal + `.iconStyleDidChange` reaction)
- Test: `DockTileTests/Unit/Managers/IconStyleQuarantineTests.swift` (new)

**Interfaces:**
- Produces: pure decision `IconStyleManager.shouldRunDetection(isDeclarative: Bool) -> Bool` (= `!isDeclarative`); on Tahoe: no KVO/notification/reconcile registration, no launch heal byte-compare, no switchIcon ever; `currentStyle` remains a passive read (popover `.id`s).

- [ ] **Step 1: Failing test** — `#expect(IconStyleManager.shouldRunDetection(isDeclarative: true) == false)`; `#expect(IconStyleManager.shouldRunDetection(isDeclarative: false) == true)`. (Trivial by design: the seam exists so the gate is visible and greppable, not clever.)
- [ ] **Step 2: Implement**: early-return in `startObserving()`/`reconcile(reason:)` via the seam fed `IconPipeline.isDeclarative`; in `HelperAppDelegate.setupIconStyleObservation()` gate the `iconMatchesStyle` heal and the `.iconStyleDidChange` subscription the same way (seeding `currentIconStyle` stays — it's a passive read). Do NOT touch `checkAndUpdateStyle` internals or the never-fired self-test — frozen.
- [ ] **Step 3: Full suite green; manual check** — dev helper on this Mac logs no `[icon-style]` observer lines, popover still renders third-party icons. **Step 4: Commit.**

### Task 8: Migration + self-heal probes (activation point 3)

**Files:**
- Modify: `DockTile/Managers/HelperBundleManager.swift` (`helperIconsComplete`)
- Modify: `DockTile/Managers/HelperMigrationManager.swift` (only if `classifyHelperHealth` hard-codes the variant list)
- Test: extend `DockTileTests/Unit/Managers/HelperSelfHealTests.swift`

**Interfaces:**
- Produces: `helperIconsComplete(resourcesContents: [String: Int], declarative: Bool) -> Bool` (adapt to the seam's real current signature — keep it pure). Declarative: complete ⇔ `Assets.car` AND `AppIcon.icns` present, non-empty. Legacy: unchanged (AppIcon.icns + 4 variants).

- [ ] **Step 1: Failing tests**: declarative bundle with car+icns → complete; missing car → incomplete; zero-byte car → incomplete; a LEGACY-shaped bundle (4 variants, no car) evaluated with `declarative: true` → incomplete (this is exactly what makes every old helper regenerate on first Tahoe launch of the new version — assert it explicitly, it IS the migration trigger).
- [ ] **Step 2: Implement; run suite. Step 3:** verify `regenerateBatch` needs no change (it calls `regenerateHelperBundle` → Task 6's branch → `refreshDockEntry` already re-seats — REQUIRED here since the entry's icon source changes kind). **Step 4: Commit.**

### Task 9: Copy Diagnostics icon inventory

**Files:**
- Modify: `DockTile/Managers/DiagnosticsLog.swift` (report section), `DockTile/Managers/HelperBundleManager.swift` (collector)
- Test: `DockTileTests/Unit/Managers/IconInventoryFormatTests.swift` (new)

**Interfaces:**
- Produces:

```swift
struct HelperIconInventory {   // plain values, one per pinned helper
    let tileName: String       // config.diagnosticName — never bare name
    let sealValid: Bool
    let liveIconMatchesVariant: String?   // legacy: which variant AppIcon.icns byte-matches; nil declarative
    let carPresent: Bool, carRenditionSummary: String?   // declarative
    let iconFileMTimes: [String: Date]
}
nonisolated static func formatIconInventory(_ items: [HelperIconInventory]) -> String  // pure, tested
```

- [ ] **Step 1: Failing format tests** (legacy row shows variant match + seal; declarative row shows car summary; empty list → "no pinned helpers" line). **Step 2: Implement** the collector (main-app only, report-time only: `codesign --verify` per pinned helper, byte-compare vs variants on legacy, `assetutil --info` summary on declarative) + append the section in `report()`. **Step 3: Suite green; run File → Copy Diagnostics on the dev build and eyeball the section. Step 4: Commit.**

### Task 10: Hardening — loud fallbacks + tolerant `IconWeight` decode

**Files:**
- Modify: `DockTile/Utilities/IconGenerator.swift` (`drawFallbackSymbol` path, brand-glyph-nil path), `DockTile/Models/ConfigurationModels.swift` (`IconWeight.init(from:)`)
- Test: extend `DockTileTests/Unit/Models/IconWeightTests.swift`

- [ ] **Step 1: Failing test** — `IconWeight` decoding an unknown raw value yields `.medium`, never throws:

```swift
@Test("Unknown IconWeight raw value decodes to .medium (whole-config decode must survive)")
func unknownWeightDecodesToMedium() throws {
    let weight = try JSONDecoder().decode(IconWeight.self, from: Data(#""futureUltraBlack""#.utf8))
    #expect(weight == .medium)
}
```

- [ ] **Step 2: Implement** custom `init(from:)` (`Self(rawValue: raw) ?? .medium`). **Step 3:** in the symbol-unresolvable and brand-resource-missing paths: `DiagnosticsLog.shared.log("icon", "…fell back to star.fill for '\(iconValue)'")` (non-verbose) + `AnalyticsService.shared.record(...)` non-fatal — silent wrong icons are against the loud-failure posture. **Step 4: Suite green; commit.**

### Task 11: Hardening — legacy renderer fixes + parity tests

**Files:**
- Modify: `DockTile/Utilities/IconGenerator.swift` (`drawBeveledStroke` inner-stroke geometry; `tinted(with:)` lockFocus retirement), `DockTile/Utilities/IconDepthMetrics.swift` (stale comments: "emoji 0.67"→0.78, scale "to 26"→22)
- Test: extend `DockTileTests/Unit/Models/TintColorTests.swift` (or `DarkGlyphTreatmentTests`), extend `IconGeneratorTests`

- [ ] **Step 1: Failing parity test** — extend the existing `.dark`-only `colors(for:)`/`nsColors(for:)` mirror test to loop ALL four styles × both icon types. **Step 2: Failing rendition test** — `generateIcns` output opened and asserted: exactly 10 reps at 16/32/128/256/512 @1x/2x (the wrong-pixel-count class, and the flap investigation's probe, as a permanent test). **Step 3: Implement**: stroke = clip to squircle then stroke at 2× width (inner-stroke equivalence with `strokeBorder` preview); `tinted(with:)` → explicit-pixel `NSBitmapImageRep` pattern; comment fixes. **Step 4:** visual spot check one baked icon before/after stroke fix (the halo disappears; inside width now matches preview). Suite green. **Step 5: Commit.**

### Task 12: Delete `AppearanceManager` dead code

**Files:**
- Modify: `DockTile/Managers/AppearanceManager.swift` — delete `AppearanceManager`, `AppearanceMode`, and the two `colors(for:/nsColors(for: AppearanceMode)` overloads; KEEP the `NSColor`/`Color` extensions below (incl. `darkenedForDarkMode`, `liftedForDarkGlyph` — live code). Rename file only if Xcode tolerates it without pbxproj pain; otherwise keep the filename with a header comment.

- [ ] **Step 1:** `grep -rn "AppearanceMode\|AppearanceManager" DockTile DockTileTests` — confirm zero call sites outside the file (the review found none; verify, don't trust). **Step 2: Delete; build; full suite green.** The `.dark` overload trap dies with it. **Step 3: Commit.**

### Task 13: CI — Rust toolchain, caches, build phase

**Files:**
- Modify: `.github/workflows/ci.yml`, `.github/workflows/release.yml`
- Modify: Xcode project — a "Bundle Icon Compiler" build phase (main app target)

- [ ] **Step 1: Build phase** (Run Script, before Copy Bundle Resources): if `Vendor/actool/target/release/docktile-actool` missing → `echo "error: run Scripts/build-compiler.sh once (requires Rust)" && exit 1`; else copy into `${BUILT_PRODUCTS_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}/`. Local `xcodebuild build` passes (Task 1 built it).
- [ ] **Step 2: Both workflows**, before the xcodebuild step: `rustup default stable` (preinstalled on macos runners — verify with `rustup --version`, add install fallback), `actions/cache` on `Vendor/actool/target` + `~/.cargo/registry` keyed on `hashFiles('Vendor/actool/Cargo.lock')`, then `Scripts/build-compiler.sh` and `cd Vendor/actool && cargo test` (the defect-2 guards run in CI).
- [ ] **Step 3:** release.yml only: confirm the signing step signs nested executables in Resources (`--deep` or explicit) so notarization accepts `docktile-actool`; add it explicitly if the current invocation doesn't cover it.
- [ ] **Step 4: Commit; push to a branch or rely on the next push's CI run to validate** (per repo flow — nothing pushes without the maintainer's go).

### Task 14: Full matrix verification + documentation flip

**Files:**
- Modify: `.claude/skills/icon-rendering/SKILL.md` (status line), `.claude/rules/icon-system.md` (declarative section becomes "how it works", legacy demoted to pre-Tahoe), `.claude/rules/icon-style-detection.md` (header: pre-Tahoe-only), `docs/superpowers/specs/2026-09-01-declarative-icons-design.md` (mark implemented), `CLAUDE.md` (rules index line if wording changes)

- [ ] **Step 1: Manual matrix (dev build, dev Dock)** — three tiles (SF Symbol, emoji, brand glyph): Add to Dock, cycle Style Default/Dark/Clear/Tinted × Light/Dark with helpers never launched; `codesign --verify` clean throughout; edit + Update re-renders; V2 note: record the shipped car size per tile (the 400 KB-vs-1.69 MB question — understand, not block).
- [ ] **Step 2: Migration rehearsal** — with legacy-shaped dev helpers on disk (generate one with the legacy branch forced, or use a pre-change build), launch the new build: the helper regenerates to car-shape, re-seats, one Dock restart. Copy Diagnostics inventory shows declarative rows.
- [ ] **Step 3: Docs flip** (each doc: declarative = present tense, legacy = pre-Tahoe fallback; keep edits surgical). **Step 4: Full suite one last time. Commit.**
- [ ] **Step 5: STOP.** Release (version bump, tag, GA4 watch per the spec's verification section) is the maintainer's go/no-go — do not tag, do not push.

---

## Self-review notes

- Spec coverage: architecture units (T3, T5), pipeline wiring + strip + Info.plist (T6), quarantine point 2 (T7), point 3 probes (T8), depth/lean layers + V1 (T4), fallback icns (T6), compiler vendoring + defect 2 + CI (T1, T2, T13), migration (T8 + T14 rehearsal), diagnostics inventory / size-flap section (T9), Batch B hardening (T10–T12), verification matrix + V2 (T14). Release plan (one version, 5e2ac2e inside) needs no task — it's the absence of an interim release.
- Preview fidelity (spec's accepted compromise) intentionally has no task: the preview keeps rendering the legacy composition as the approximation; revisit only if the matrix in T14 shows it misleading.
- Type consistency: `IconAppearance`, `LayerSpec.exclusiveTo`, `generateGlyphLayerPNG`, `IconCompiler.validate`, `shouldRunDetection`, `HelperIconInventory` are each defined once (T3/T4/T5/T7/T9) and consumed by name afterwards.
