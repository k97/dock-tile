# Localization (macOS App)

## Supported Locales

| Locale | Code | Notes |
|--------|------|-------|
| UK English | `en-GB` | Base/fallback for all non-English locales |
| US English | `en-US` | American spelling |
| AU English | `en-AU` | Same as UK spelling |

## Architecture

- **Format**: String Catalogs (`.xcstrings`)
- **Files**: `Localizable.xcstrings` (app strings), `InfoPlist.xcstrings` (metadata)
- **Accessors**: `DockTile/Constants/AppStrings.swift`

## Key Spelling Differences

| US (en-US) | UK/AU (en-GB, en-AU) |
|------------|----------------------|
| Customize | Customise |
| Color | Colour |

## Usage

All user-facing strings go through `AppStrings`:
```swift
Button(AppStrings.Button.customise) { ... }  // correct
Button("Customise") { ... }                   // wrong — never hardcode
```

Categories: `Button.*`, `Label.*`, `Menu.*`, `Navigation.*`, `Section.*`, `Empty.*`, `Error.*`, `Log.*` (logs are NOT localised).

## Editing .xcstrings outside Xcode

Insert new keys **textually**, anchored on a neighbouring key and matching the file's exact JSON
style — never load-and-redump the whole file (a `json.dump`, even key-sorted, reordered all ~2,800
lines into a 1,206-line diff on 2026-09-02; the file's own ordering is not plain-ASCII sort).
Validate with `json.load` after the insert, and check `git diff --stat` shows only the new lines.

## Adding New Strings

1. Add key + translations to `Localizable.xcstrings` in Xcode
2. Add accessor in `AppStrings.swift`
3. Use `AppStrings.Category.key` in code
4. Add test in `AppStringsTests.swift`

## Testing

```bash
# Dev builds use com.docktile.dev.app; Release uses com.docktile.app
defaults write com.docktile.dev.app AppleLanguages "(en-GB)"  # UK
defaults write com.docktile.dev.app AppleLanguages "(en-US)"  # US
defaults delete com.docktile.dev.app AppleLanguages           # Reset
```
