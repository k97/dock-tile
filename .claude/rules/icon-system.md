# Icon System

## Two Separate Systems

| | Main App | Helper Tiles |
|---|---|---|
| Source | Icon Composer (`AppIcon.icon/`) | `IconGenerator.swift` |
| Output | `Assets.car` + `AppIcon.icns` (Xcode build) | Custom `.icns` (runtime) |
| Variants | light/dark/tinted PNGs in icon.json | 4 style variants per tile |

## Icon Generation (IconGenerator.swift)

**Shape**: Continuous corners (squircle) via `RoundedRectangle(.continuous)`, radius = 22.5% of width.

**Background**: Linear gradient from `TintColor.colorTop` to `colorBottom`.

**Glass effect**: White inner stroke at 50% opacity, line width scales proportionally (0.5pt at 160pt).

**Content**: SF Symbols (white, `.semibold`) or emojis. Size controlled by `iconScale` (10-20, default 14).

**Output**: All 10 sizes (16, 32, 128, 256, 512 @ 1x and 2x) via `iconutil`.

**Critical gotcha**: Use `NSBitmapImageRep` with explicit pixel dimensions — not `NSImage(size:).lockFocus()` which creates Retina-scaled backing stores that produce wrong pixel counts for `iconutil`.

**No baked-in shadows** — the Dock adds these dynamically. Baking would cause doubled shadows.

## Icon Scale Safe Area

Max ratio: 0.60 of icon size. Stepper capped at 17 (SF Symbols) / 16 (emojis).

## Icon Style Manager (macOS Tahoe)

macOS Tahoe has an independent "Icon and widget style" setting (separate from Light/Dark appearance), read from `AppleIconAppearanceTheme` in UserDefaults.

| Style | UserDefaults Value | Design |
|-------|-------------------|--------|
| Default | `nil` | Colorful gradient, white symbol |
| Automatic | `"RegularAutomatic"` | **Follows system appearance** — `.dark` in Dark mode, `.defaultStyle` in Light. This is the Tahoe default; `IconStyle.from()` MUST map it or dark icons never apply in Automatic mode |
| Dark | `"RegularDark"` | Darkened shade of the tile's own tint (brightness-capped via `darkenedForDarkMode`, hue preserved), white symbol |
| Clear | `"ClearAutomatic"` | Light gray, dark gray symbol (grayscale only) |
| Tinted | `"TintedAutomatic"` | Medium gray, white symbol (grayscale only) |

`IconStyle.from()` resolves `"RegularAutomatic"`/`"Automatic"` via `systemAppearanceIsDark` (reads `AppleInterfaceStyle` through CFPreferences, no `NSApplication` dependency). Because `IconStyle.current` resolves dynamically, the 2-second poll also catches a Light↔Dark appearance toggle while in Automatic mode (the enum flips, `switchIcon` fires).

- Single `IconStyleManager.shared` with 2-second polling (notifications unreliable)
- All 4 variants generated upfront during `installHelper()` (~200-400ms)
- Style switching is instant file copy, no regeneration
- Reference `iconStyleManager.currentStyle` in view body with `let _ =` to trigger re-renders
- **Dark variant rationale + HIG sources**: [docs/dark-mode-icon-rendering.md](../../docs/dark-mode-icon-rendering.md) (darkened-own-tint background + white symbol, and why)

## App Icon Loading

- Apps WITH `Assets.car`: Use `NSWorkspace.shared.icon(forFile:)` (respects icon style)
- Apps WITHOUT `Assets.car`: Load `.icns` directly (avoids unwanted dark tinting)
- Detection via `AppIconLoader` checking for `Contents/Resources/Assets.car`

## Helper Bundle Icon Priority

macOS loads: `Assets.car` > `CFBundleIconFile`. Helpers **must** have `Assets.car` removed after copying from main app, and `CFBundleIconFile = "AppIcon"` set in Info.plist.

## Custom Colour Gradients

Custom colours use `lighterShade(by:)` (increases brightness) for the top gradient — not `opacity()`, which creates semi-transparent colours that leave gaps in CoreGraphics gradient rendering.

## Runtime Icon Updates

Never set `NSApp.applicationIconImage` at runtime — causes size mismatch in Dock. Use file-based approach: copy icon variant → `touchBundle()` → re-register with Launch Services.

## Cache Clearing

```bash
killall iconservicesd && killall Dock
lsregister -f -R /path/to/DockTile.app
```
