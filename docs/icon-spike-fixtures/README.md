# Icon spike fixtures

Preserved from the 2026-09-01 declarative-icon spike. Evidence and compiler-defect record:
[../icon-rendering-history.md](../icon-rendering-history.md).

## `devtile-fix.icon`

The **canonical working reference**: Dev Tile's real config (green tint, `hammer.fill`, medium,
scale 14) expressed as an Icon Composer document with all three authorable appearances, and with
the OSS-compiler workaround applied.

Demonstrates the four things that were expensive to learn:

1. **Three authorable appearances** — `light` (default), `dark`, `tinted`. `clear` is NOT
   authorable; macOS derives it as a glass pass.
2. **The default belongs IN the specializations list**, as an entry with no `appearance` key. A
   sibling property (`"hidden": true`) is not overridable by a specialization.
3. **Per-appearance artwork is a LAYER SWAP** via `hidden-specializations` — per-layer `fill` does
   NOT recolour a glyph in either compiler. Pre-colour the PNG.
4. **The OSS workaround**: the top-level `fill` is *also* emitted as the first no-appearance entry
   in `fill-specializations`, because `fill_specializations_assets()` never reads the top-level
   `fill` (defect 1). Harmless for Apple's compiler.

Compile with either:

```
xcrun actool devtile-fix.icon --compile OUT --app-icon devtile-fix \
  --output-partial-info-plist OUT/partial.plist \
  --platform macosx --target-device mac --minimum-deployment-target 15.0
```

Drop `Assets.car` + the generated `.icns` into a bundle with `CFBundleIconName` and
`CFBundleIconFile` set to the icon name, ad-hoc sign, and pin it.

## The three renders (Default / no icon-style set)

| File | Compiler | Result |
|---|---|---|
| `reference-apple-default.png` | Apple | green + **white** glyph — correct |
| `defect-oss-default-renders-dark.png` | OSS, before workaround | near-black + green glyph — **defect 1** |
| `workaround-oss-default-fixed.png` | OSS, after workaround | green background restored; glyph still wrong — **defect 2, unfixed** |

Defect 2 (layer stack picks the wrong appearance) **must be fixed before shipping**.
