# Development Patterns

## Test Writing Guidelines

**Environment-agnostic paths** — never hardcode paths like `/Users/karthik/...`:
```swift
let projectPath = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .path
```

**Parallel execution** — use `.serialized` trait when tests share mutable state (UserDefaults, files).

**Localization testing** — `NSLocalizedString` is cached at app launch. Parse `.xcstrings` JSON directly for locale-specific tests; don't rely on `Bundle.main`.

## Schema Evolution

When adding fields to `DockTileConfiguration`:
1. Add field with default value
2. Add default in `ConfigurationDefaults` (in `ConfigurationSchema.swift`)
3. Add to `CodingKeys` enum
4. Use `decodeIfPresent` with fallback to default

Old configs must always load — never break backward compatibility.

## Shared Utilities

| File | Use instead of |
|------|---------------|
| `AppIconLoader.icon(for:)` | Inline icon loading / `NSWorkspace.shared.icon(forFile:)` |
| `AppLauncher.launch(app)` | Inline `NSWorkspace.openApplication` logic |
| `NativeBackgroundViews` | Per-file NSViewRepresentable wrappers for NSColor |
| `UserDefaultsKeys` | Raw string keys for UserDefaults |

## Native macOS Colors

`Color(nsColor:)` doesn't reliably bridge dynamic AppKit colors. Use `NSViewRepresentable` wrappers from `NativeBackgroundViews.swift` (`.formGroup`, `.windowBackground`).
Their backing `AppearanceColorView` re-resolves the colour in `updateLayer()` under its own
`effectiveAppearance` on every appearance change. Never assign `someDynamicNSColor.cgColor` to a
layer once: it freezes the colour for the appearance current at that moment — the Customise Tile
inspector stayed dark after a switch to Light Mode (2026-10-21; `AppearanceColorViewTests`).

## Product Name Has a Space

The app product name is **"Dock Tile"** (with space), not "DockTile". File system paths must use the correct name:
- Production: `/Applications/Dock Tile.app`
- Dev DerivedData: `Build/Products/Debug/Dock Tile Dev.app`
- Never use `DockTile.app` (no space) in file paths — it doesn't exist

## Key Patterns

- **Debounce**: Use monotonic `@State` counter as `.task(id:)` identity, not full struct equality (avoids O(n x icon_data_size) comparisons)
- **View identity**: Add `.id(selectedConfig.id)` when switching configs to force view recreation and avoid stale `@State`.
  It is not free: the rebuild is roughly half of what a heavy pane costs per switch (the Customise
  inspector: view creation +0.52 s per 12 switches, SwiftUI template, 2026-10-22). Removing it means
  owning every reset and every delayed write by hand — see the Tile Detail risks in
  `docs/superpowers/specs/2026-10-22-stable-tile-identity-design.md` before trying.
- **State updates**: Wrap `configManager.markSelectedConfigAsEdited()` in `DispatchQueue.main.async` inside `.onChange` to avoid "Publishing changes from within view updates" warnings
- **Platform APIs**: Use `@available(macOS 26.0, *)` with separate computed properties and `@ViewBuilder` runtime checks; always provide fallback
- **`.help` (tooltips) never fires on a `.disabled` control** — `.disabled` turns off
  hit-testing for the subtree, so a tooltip attached to (or inside) it is silently dead. Gate a
  control by putting `.disabled` on the control alone, fading the enclosing row with `.opacity`
  for the visible dimming (`.disabled` barely dims a mini switch), and attaching `.help` to the
  still-enabled row. Shipped wrong once (Show in App Switcher, 2026-09-02) — the tooltip only
  appeared after this restructure.
- **Don't rely on a SwiftUI layer filter for what a test or a bake checks.** `.saturation(0)` on
  the App Grid minis was skipped by the CI runner's renderer and by `cacheDisplay` (2026-10-20), so
  the preview looked right on one Mac only. Transform the bitmap itself (`IconGenerator.desaturated`).
- **Never block a thread waiting for work queued on `DispatchQueue.global` (critical).** Draining a
  `Process`'s pipes in global-queue blocks while the caller `DispatchGroup.wait()`s deadlocked when
  every pool thread was itself blocked in that wait: CI's 3-core runner hung six hours with three
  concurrent compile tests (2026-10-19); 15 compiles on a 14-core Mac reproduce it
  (`IconCompilerTests.concurrentCompilesFinish`). Read the one pipe you need on the calling thread
  and send the other stream to a file or `/dev/null`. A bounded `wait(timeout:)` is acceptable.
- **"Same folder?" is a file-identity question, never a string compare (critical).** The boot volume is
  case-insensitive APFS: `utils.app` and `Utils.app` are one folder, and `contentsOfDirectory` vs
  `appendingPathComponent` spell paths differently. Before deleting or replacing by path, compare with
  `HelperBundleManager.isSameFile` (device + inode). The 2.6.3 staged swap deleted its own new bundle
  on a case-only rename until review caught it (`oldFolderIsKeptOnACaseOnlyRename`); a test of such
  a rule must touch the real file system, since string-only fixtures cannot reproduce it.
- **Assets fail SILENTLY — never assume one rendered.** An unknown SF Symbol name
  (`Image(systemName:)`) and a bundled image that fails to decode both draw **nothing**: no warning,
  no placeholder, no crash — the affordance is simply absent. `app.badge.plus` shipped that way in
  the popover's empty state and was invisible until the panel was widened enough to show the hole.
  So: symbol literals are swept by `SystemSymbolNameTests` (read its header — it can't see the
  macOS 15 floor), and a bundled image gets an explicit fallback (`VendorMark` in `AboutView`).
  When adding either, confirm on screen that it actually drew.

## CI/CD Feature Checklist

Before using platform-specific APIs:
1. Check GitHub Actions runner availability (e.g., macos-26)
2. Verify SDK version matches local environment
3. Add `@available` checks with fallback implementations
4. Test locally AND in CI before merging

## User feedback is personal data

Emails, screenshots and reply drafts from users live in `docs/feedback/`, which is gitignored.
This repo is public: never commit them, and never put a reporter's name or address in a tracked
file or a commit message. Describe the report instead ("a macOS 15.6 user reported…").

The author is named only by GitHub username, **`k97`**, in every tracked file (LICENSE, copyright
strings, docs, release notes). Never a personal name: an unrecognised surname sat in
`InfoPlist.xcstrings` from 2026-02-05 until 2026-10-17 and nearly propagated into the LICENSE.
