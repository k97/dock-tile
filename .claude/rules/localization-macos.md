# Localization (macOS App)

## Languages

| Locale | Role |
|---|---|
| `en-GB` | Source language and development region |
| `en-AU`, `en-US` | Spelling variants (Customise/Customize, Colour/Color) |
| `zh-Hans`, `ja`, `de`, `ru`, `fr` | **Machine-first**, reviewed by native speakers from the user base |

Chosen from GA4 (2026-10-17): non-English Macs were 45% of monthly actives; zh-Hans is the only
cohort above 10 users. Adding a language costs one `export --lang`, one machine pass, one `import`.

## Architecture

- **Format**: String Catalog `Localizable.xcstrings`, in the app target since 2026-10-17 — **it never
  was before**, so no `.lproj` shipped and en-US/en-AU spellings never reached a user. `InfoPlist.xcstrings`
  stays OUT of the target on purpose: a localized `InfoPlist.strings` overrides `Info.plist` for Launch
  Services, and every helper is a copy with `CFBundleName` rewritten to the tile's name, so shipping it
  would make every tile read "Dock Tile" in ⌘Tab and Finder (`catalogShipsAndInfoPlistStringsDoesNot`).
- **Development region is `en-GB`** (= the catalog's `sourceLanguage`), not a nonexistent `en.lproj`.
  The real bundle with `AppleLanguages (ko)` resolves to **en-GB** ("Customise"; verified in the
  running dev app 2026-10-18 — an earlier synthetic `preferredLocalizations` probe said en-US and
  was wrong). The invitation test stays "not `en*`" so it holds whichever English is picked.
- **Accessors**: `DockTile/Constants/AppStrings.swift`, always `NSLocalizedString(key, value:, comment:)`
  in that three-argument shape — `Scripts/l10n/l10n.py` parses it and refuses any other shape.
- **The catalog is the runtime source; the review sheets `docs/l10n/<lang>.md` are derived.**
  `l10n.py` is the only writer of non-English entries and of new keys (`sync-keys`). Machine
  entries carry state `needs_review`, reviewed ones `translated`; both compile and ship (verified
  with `xcstringstool compile`, 2026-10-17). `LocalizationCatalogTests` pins the language set,
  code-key ⊆ catalog, per-language completeness and format-placeholder parity.
- **Invitation**: `TranslationInvite` seams (`TranslationInviteTests`) show the About Translation
  row and a one-time alert only when `Bundle.main.preferredLocalizations.first` is non-English — an
  unsupported language resolves to one of the English localizations, so it is never invited. Events `translation_invite_shown`
  / `translation_help_tapped` carry `ui_language` (never `language`, GA4's automatic dimension).

## Workflow

| When | Run |
|---|---|
| New `AppStrings` key | `python3 -I Scripts/l10n/l10n.py sync-keys`, fix any en-US spelling it warns about, then `export` |
| Changed English copy | Edit the `value:` in `AppStrings.swift` AND the en-GB/en-AU/en-US values in the catalog (textually, in place), then `export`. The catalog overrides the Swift default at runtime and `sync-keys` skips existing keys, so editing only one changes nothing a user sees; `check` fails when they differ |
| Reviewer PR merged | `python3 -I Scripts/l10n/l10n.py import <lang>`, commit the catalog |
| Before pushing | `python3 -I Scripts/l10n/l10n.py check` (CI runs it with the Python tests). Green while a reviewer's sheet is *ahead* of the catalog; red on a stale export, unknown key, lost placeholder or dropped glossary term |

Editing `.xcstrings` by hand is allowed only to fix an **English** value, textually in place
(anchored on the neighbouring key, matching the file's `json.dumps(indent=2)` style). Never
load-and-redump it by any other route than `l10n.py`, which preserves key order. Xcode's catalog
editor rewrites the whole file in its own style (`"key" : value`, sorted) — harmless to the round
trip, but a noisy diff; prefer not to open it there.

**Removing a key** (2026-11-22): `l10n.py` has no remove command. Delete the key's block textually
(from `    "key": {` to its own `    },`), confirm the file still parses (`json.loads`), delete the
`AppStrings` accessor in the same commit, then `l10n.py export` + `check` — the sheets drop the row.

## Usage

```swift
Button(AppStrings.Button.update) { ... }  // correct
Button("Update") { ... }                   // wrong — never hardcode
```

Categories: `Button.*`, `Label.*`, `Menu.*`, `Navigation.*`, `Section.*`, `Empty.*`, `Error.*`,
`SmartAdd.*`, `Translation.*`, `Layout.*`, `IconWeight.*`, `EmojiCategory.*`, `SymbolCategory.*`, `Log.*` (logs are NOT localised).

- **A model's display name is a hardcoded string too (critical)**: a `displayName`/`title`
  property that returns a literal and reaches a view must route through `AppStrings`. The first
  sweep matched only `Text("…")` / `title: "…"` literals and missed `LayoutMode.displayName`,
  `IconWeight.displayName`, the emoji-category enum and `SymbolPickerGrid.categoryDisplayName(for:)`
  — all shown in pickers, found by the German hands-on run (fixed in 93b25ae, 45 keys under
  `Layout.*` / `IconWeight.*` / `EmojiCategory.*` / `SymbolCategory.*`). `IconStyle.displayName`
  and `TintColor` preset names are diagnostics-only and stay English.
- **Smart Add identity names must be pairwise distinct per language (critical)**: `SmartAddEngine`
  de-duplicates cards by the *localized* name (`usedIdentityNames`), so two `smartAdd.identity.*`
  translations that collide silently drop a card. The machine pass checked this; reviewers must
  keep it.
- **Don't put the product name in copy that means "a tile"**: the lint keeps "Dock Tile" verbatim, so
  the ⌘N item "New Dock Tile" came out as 新建Dock Tile / „Dock Tile erstellen“. It reads "New Tile"
  since 2026-10-18, translated like `button.newTile` (pinned in `AppStringsTests`).

## Glossary caveats

Terms in `docs/l10n/GLOSSARY.md` were read from Apple's **macOS 27** loctables; the floor is macOS
15, where some may differ (zh-Hans Accessibility may be 辅助功能 there). Not verified on macOS 15.
French typographic spacing is U+00A0 (Apple's French), not U+202F. The French popover is
« fenêtre surgissante » (Apple's AppKit term), never « contextuel » — that word is the item
context menu.

## Testing a language by hand

```bash
defaults write com.docktile.dev.app AppleLanguages "(de)"        # or zh-Hans, ja, ru, fr, en-US
defaults delete com.docktile.dev.app AppleLanguages              # reset
defaults delete com.docktile.dev.app translationInviteShown      # see the one-time alert again
```

`AppleLanguages` on `com.docktile.dev.app` (and System Settings' per-app language) reaches the MAIN
app only. Helper tiles have their own bundle IDs, so popovers and helper Dock menus follow the system
language (or `AppleLanguages` on that helper's bundle ID).

Capture windows by ID (driving-the-dev-build.md). German and Russian run ~30% long: check toggle
labels, the title-band action button, Smart Add cards. Glossary and register rules:
`docs/l10n/GLOSSARY.md`; reviewer guide: `docs/l10n/README.md`.

- **Never `.fixedSize()` a control whose title is translated inside the 260 pt Customise inspector
  (2026-10-28).** PR #32's Background menu did: "Systemeinstellung folgen" / "Следовать системным
  настройкам" at full width pushed the content past the column (row label gone, column shifted —
  the architecture.md constraint-loop risk). Use `.controlSize(.small)` and let it truncate.
- **`l10n.py check` does not enforce the glossary beyond its protected terms.** Check every new row
  against `GLOSSARY.md` by eye, especially rows from outside contributors: #32's zh-Hans rows used
  分组 for "tile" (glossary 磁贴) and "Dock" for 程序坞, and passed `check`.
