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

## Product Name Has a Space

The app product name is **"Dock Tile"** (with space), not "DockTile". File system paths must use the correct name:
- Production: `/Applications/Dock Tile.app`
- Dev DerivedData: `Build/Products/Debug/Dock Tile Dev.app`
- Never use `DockTile.app` (no space) in file paths — it doesn't exist

## Key Patterns

- **Debounce**: Use monotonic `@State` counter as `.task(id:)` identity, not full struct equality (avoids O(n x icon_data_size) comparisons)
- **View identity**: Add `.id(selectedConfig.id)` when switching configs to force view recreation and avoid stale `@State`
- **State updates**: Wrap `configManager.markSelectedConfigAsEdited()` in `DispatchQueue.main.async` inside `.onChange` to avoid "Publishing changes from within view updates" warnings
- **Platform APIs**: Use `@available(macOS 26.0, *)` with separate computed properties and `@ViewBuilder` runtime checks; always provide fallback

## CI/CD Feature Checklist

Before using platform-specific APIs:
1. Check GitHub Actions runner availability (e.g., macos-26)
2. Verify SDK version matches local environment
3. Add `@available` checks with fallback implementations
4. Test locally AND in CI before merging
