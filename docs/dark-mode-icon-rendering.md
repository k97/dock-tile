# Dark-Mode Tile Icon Rendering — Design Notes

How Dock Tile renders a helper tile's icon in the macOS Tahoe **Dark** icon style
(`AppleIconAppearanceTheme = "RegularDark"`). This is one of the four icon-style variants
generated up front per tile — see [icon-system rule](../.claude/rules/icon-system.md) for the
full system and [IconStyleManager.swift](../DockTile/Managers/IconStyleManager.swift) for the code.

## The problem (what was broken)

The original Dark variant rendered **every** tile as the *same* fixed dark-grey gradient
(`#2C2C2E → #1C1C1E`) with the symbol painted in the tile's **raw tint colour**. Two failures
fell out of that:

1. **Colour identity was lost.** A light amber tile and a deep violet tile both became the same
   grey slab. Tiles are distinguished by colour, so in Dark style they became indistinguishable —
   and a user's "lighter coloured" tile never darkened *into its own colour*, it just went grey.
2. **The symbol could be invisible.** With no contrast floor, the **default grey** tint
   (`#8E8E93`) drew grey-on-grey, and low-perceived-luminance tints (e.g. Media's `#5F00FF`, a
   deep blue-violet) washed into the near-black background. The icon was generated correctly and
   *did* draw — it simply could not be seen at Dock size.

The trigger that surfaced this: a tile named **Media** with custom tint `#5F00FF` "did not show
up" in Dark style. Diagnosis confirmed the `.icns` and its dark variant existed and rendered; the
violet symbol on near-black was just below usable contrast.

### Why a naïve "brighten the symbol" fix is wrong

`#5F00FF` already has **maximum HSB brightness** (its bright channel is blue). It reads as dark
only in *perceived luminance* (`0.299R + 0.587G + 0.114B` — blue is weighted 0.114). So "increase
HSB brightness" is a no-op on exactly the colours that need help. Any contrast fix has to operate
on perceived luminance, not HSB brightness.

## Apple HIG guidance

For the **Dark** app-icon variant Apple's guidance is to keep the icon's own colour but darken
the presentation and keep the foreground legible — *not* to recolour or monochrome it:

> "You can keep the original color scheme and use the main color in the foreground of your icon.
> Just keep in mind that the foreground color may need to be made lighter for better contrast with
> the background."
> — [Preparing your App Icon for dark and tinted appearance](https://www.createwithswift.com/preparing-your-app-icon-for-dark-and-tinted-appearance/)

Grayscale/monochrome is reserved for the **Tinted** variant, where the system supplies the
gradient and applies its own tint over a fully opaque grayscale image
([Apple HIG: Dark Mode](https://developer.apple.com/design/human-interface-guidelines/dark-mode)).
Dock Tile already follows this — the Clear and Tinted variants are grayscale-only and are
unaffected by this change.

## The decision

Dark style **splits by icon type**, because the original white-on-darkened-tint reads too
high-contrast ("punchy") for an SF Symbol, while an emoji can't be recoloured at all.

**Dark + SF Symbol — colored glyph on neutral near-black (HIG-native).** Flip the roles: the
tile's picked colour becomes the *glyph*, sitting on a neutral near-black background.

- **Background** = the neutral near-black gradient `#2C2C2E → #1C1C1E` (the pre-tint values). A
  monochrome surface is what lets a coloured glyph read, and it matches Tahoe's native dark-icon
  model.
- **Foreground** = the tile's `colorBottom` (its "primary tint"), **lifted on perceived
  luminance** to a floor so it stays visible — see `liftedForDarkGlyph` below. This is the HIG
  guidance "the foreground color may need to be made lighter for better contrast" applied
  *per-hue* rather than collapsed to white, so each tile keeps its colour identity and the result
  is calmer than a stark white glyph.

**Dark + emoji — darkened-own-tint background (unchanged).** An emoji renders in full colour and
can't be recoloured, so it keeps the darkened shade of the tile's own tint as its background
(brightness-capped: **top `0.22`, bottom `0.13`**), with the emoji + contact shadow on top.

### `liftedForDarkGlyph(minLuminance:)` — the contrast floor

Added to **both** colour spaces (`NSColor` in [AppearanceManager.swift](../DockTile/Managers/AppearanceManager.swift),
`Color` in [ColorExtensions.swift](../DockTile/Extensions/ColorExtensions.swift)), mirroring the
`darkenedForDarkMode` pair. It reads device-RGB, computes perceived luminance
`L = 0.299R + 0.587G + 0.114B`, and — only if `L` is below the floor — blends the colour toward
white by `t = (floor − L) / (1 − L)` per channel. Because luminance is linear in RGB, that lands
`L'` exactly on the floor while preserving hue (it sheds saturation only as far as needed). This is
the fix for the `#5F00FF` case: violet has max HSB brightness but low *perceived* luminance, so an
HSB "brighten" is a no-op — the lift must be on perceived luminance.

**Floor = `0.55`** (`TintColor.darkGlyphLuminanceFloor`). Deliberately restrained rather than a
hotter `0.6`+: a higher floor pushes glyphs toward white and reintroduces the "too bright / punchy"
feel this change set out to fix. `0.55` keeps even deep violet/blue clearly legible on near-black
while staying calm. Tunable in one place.

### Alternatives considered and rejected

| Approach | Why rejected |
|----------|--------------|
| **White symbol on darkened-own-tint** (the previous shipping decision) | Robust and uniformly legible, but the pure-white glyph reads too high-contrast/"punchy" against the dark tile — the complaint that motivated this change. |
| **Translucent white symbol** on the darkened-own-tint background | The minimal one-line softening, but translucency is the mechanism of the *Clear* icon style, not Dark; it's off-spec and doesn't restore per-hue identity. Kept as the fallback option, not chosen. |
| **Darkened-own-tint background _with_ a tinted glyph** | Colour-on-same-hue-dark is low, hue-dependent contrast; the neutral near-black background is what makes a coloured glyph read reliably. |
| **Blend the tint toward white unconditionally** | Desaturates *every* dark-style symbol, not just the dark ones; muddies bright tints. The luminance floor only lifts colours that actually need it. |

## Implementation

- **`darkenedForDarkMode(maxBrightness:)`** — on both `NSColor`
  ([AppearanceManager.swift](../DockTile/Managers/AppearanceManager.swift)) and `Color`
  ([ColorExtensions.swift](../DockTile/Extensions/ColorExtensions.swift)). Converts to
  `.deviceRGB` HSB, preserves hue and saturation, returns the colour with
  `brightness = min(brightness, maxBrightness)` at full opacity. Still used for the **Dark + emoji**
  background.
- **`liftedForDarkGlyph(minLuminance:)`** — the perceived-luminance lift described above, added
  next to it in both colour spaces. Used for the **Dark + SF Symbol** glyph.
- **`TintColor` Dark cases** in [IconStyleManager.swift](../DockTile/Managers/IconStyleManager.swift)
  now take an `iconType` and branch:
  - `.sfSymbol`: background = neutral near-black pair (`TintColor.darkNeutralTopHex/BottomHex`);
    foreground = `nsColorBottom.liftedForDarkGlyph(minLuminance: TintColor.darkGlyphLuminanceFloor)`.
  - `.emoji`: background = `darkenedForDarkMode(0.22)`/`(0.13)`; foreground `.white` (unused by the
    emoji draw path).
  - `nsColors(for:iconType:)` (renders the `.icns`) and `colors(for:iconType:)` (the SwiftUI
    preview) are kept in lock-step. Call sites: [IconGenerator.swift](../DockTile/Utilities/IconGenerator.swift)
    and [DockTileIconPreview.swift](../DockTile/Components/DockTileIconPreview.swift).

The two colour spaces are kept in sync deliberately — the SwiftUI preview must match the
`NSBitmapImageRep`-rendered `.icns`. Guarded by `DarkGlyphTreatmentTests`.

## Applying the change to existing tiles

Each helper bundle has its four variant `.icns` files **baked in at generation time**; style
switching is an instant file copy, not a re-render. So existing tiles keep their *old* Dark
variant until they are regenerated. This change does **not** retroactively touch installed tiles
or restart the Dock on its own — that is the migration pipeline's job.

[`HelperMigrationManager.migrateIfNeeded()`](../DockTile/Managers/HelperMigrationManager.swift)
runs once on main-app launch. It compares `lastMigratedAppVersion` against
`HelperBundleManager.currentAppVersion` — which is **`CFBundleShortVersionString`
(`MARKETING_VERSION`)**, not the build number. On the first launch after an update that bumps the
marketing version, every visible helper's stamped `helperAppVersion` is stale, so all are
batch-regenerated (all four variants rebuilt with the new Dark logic) and the Dock is restarted
**exactly once** for the whole batch, then the helpers relaunch. Re-saving a single tile also
regenerates it (with its own Dock restart).

**Caveat:** migration keys on the *marketing* version. A normal release bumps both
`MARKETING_VERSION` and `CURRENT_PROJECT_VERSION`, so it triggers. A build-number-only bump
(`CURRENT_PROJECT_VERSION` alone — which drives Sparkle's `sparkle:version`) would **not**
trigger regeneration, and tiles would keep the old icons. This change must therefore ship in a
release that bumps `MARKETING_VERSION`.

## Prerequisite: the "Automatic" icon style must select Dark

The redesigned Dark rendering only matters once the Dark style is actually *selected*. A separate
bug blocked that: macOS Tahoe's **default** "Icon & widget style" is **Automatic**
(`AppleIconAppearanceTheme = "RegularAutomatic"`), which follows the system appearance. The
original `IconStyle.from()` did not recognise `"RegularAutomatic"` and fell through to
`.defaultStyle`, so in Automatic mode DockTile applied the colourful default to every tile even
when the system was in Dark appearance — the dark variant was never chosen. (This is what made a
tile look "not dark" despite a valid dark `.icns` on disk.)

Fix: `IconStyle.from()` now maps `"RegularAutomatic"`/`"Automatic"` to `.dark` when
`systemAppearanceIsDark` (read from `AppleInterfaceStyle` via CFPreferences, no `NSApplication`
dependency), else `.defaultStyle`; `"RegularLight"`/`"Light"` map to `.defaultStyle`. Because
`IconStyle.current` now resolves dynamically, the existing 2-second poll also catches a Light↔Dark
toggle while in Automatic mode. This logic lives in the helper binaries (copies of the main app),
so it reaches installed tiles only when the app is updated and helpers are regenerated.

## Scope

- **Default** style (colourful gradient, white symbol) — unchanged.
- **Clear** / **Tinted** styles (grayscale-only, system tinting) — unchanged; HIG-correct already.
- **Dark** style background and foreground derivation changed (this document's main subject).
- **Automatic** style (`RegularAutomatic`) now resolves to Dark/Default by system appearance.
