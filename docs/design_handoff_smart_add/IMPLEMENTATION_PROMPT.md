# Claude Code task — implement "Smart Add" in the Dock Tile app

You are working in the **Dock Tile** macOS app (Swift 6, SwiftUI + AppKit hybrid). Implement the
**Smart Add** feature described in `README.md` (read it fully first — it has the exact spec, tokens,
copy, and integration points). `Smart Add.dc.html` is a **design reference**, not code to copy:
recreate frame `1a` natively; reuse the existing `DockTileDetailView` for frames `1b`/`1c`.

## Do this in order

1. **Read for context** (do not skip):
   - `DockTile/Managers/ConfigurationManager.swift`
   - `DockTile/Views/DockTileSidebarView.swift`
   - `DockTile/Views/DockTileConfigurationView.swift`
   - `DockTile/Views/DockTileDetailView.swift`
   - `DockTile/Models/ConfigurationModels.swift`, `Models/ConfigurationSchema.swift`
   - `DockTile/Components/DockTileIconPreview.swift`, `Utilities/AppIconLoader.swift`
   - `DockTile/Constants/AppStrings.swift`, `Resources/Localizable.xcstrings`
   Match these conventions (naming, `@MainActor`, JSON persistence in the prefs dir, string catalog).

2. **`Managers/SmartAddEngine.swift`** — on-device suggestion engine. NO Siri/network.
   Sources: `NSWorkspace` launch/activation notifications (persist a rolling log), Spotlight
   `kMDItemUseCount` / `kMDItemLastUsedDate` via `NSMetadataQuery`, and `LSApplicationCategoryType`.
   API:
   ```swift
   struct TileSuggestion: Identifiable {
       let id = UUID()
       let name: String
       let strategy: Strategy         // .category / .coLaunch / .recency
       let reason: String             // localized: "By category" / "Most used this week" / "Opened together"
       let tint: <existing tint type> // from ConfigurationSchema
       let symbol: String             // SF Symbol name
       let appItems: [AppItem]
   }
   func computeSuggestions(existing: [DockTileConfiguration], limit: Int = 3) -> [TileSuggestion]
   ```
   Rules: exclude apps already in existing tiles; ≥3 apps per group; score recency × frequency;
   de-dupe overlapping groups; best pick first; category→identity map per README.

3. **`Views/SmartAddSheet.swift`** — the sheet UI matching frame `1a` and the README tokens.
   HIG button hierarchy: exactly one `.borderedProminent` (top pick, the default), others tinted
   accent, "Create New Tile" bordered **neutral**. Header, reason chips, member-app icons
   (`AppIconLoader`), privacy footnote. Callbacks: `onUse(TileSuggestion)`, `onCreateNew()`, `onClose()`.

4. **`ConfigurationManager`** — add:
   ```swift
   @discardableResult
   func createConfiguration(from suggestion: TileSuggestion) -> DockTileConfiguration
   ```
   Seed name (via `uniqueName`), tint, symbol icon, and `appItems`; `isVisibleInDock = false`;
   select it; `selectedConfigHasBeenEdited = true`; save; log `.tileCreated` with `source: "smart_add"`.

5. **Wire the + button.** In `DockTileSidebarView` / `DockTileConfigurationView`, change the toolbar
   `+` action to:
   ```
   let s = smartAddEngine.computeSuggestions(existing: configManager.configurations)
   if s.isEmpty { configManager.createConfiguration() }
   else { show SmartAddSheet(suggestions: s) }   // hosted as a .sheet in DockTileConfigurationView
   ```
   `onUse` → `createConfiguration(from:)` + dismiss; `onCreateNew` → `createConfiguration()` + dismiss.
   Keep the existing `selectedConfigHasBeenEdited` gating on the + button.

6. **Provenance banner** (optional but specified) at the top of `DockTileDetailView` when the tile was
   just created by Smart Add — accent-tinted, sparkle glyph, copy in README. Gate it on a transient
   flag so it doesn't persist forever.

7. **Strings** — add all listed strings to `AppStrings` + `Localizable.xcstrings` (UK English base).

8. **Tests** — add the unit + UI tests listed in the README under `DockTileTests` / `DockTileUITests`.

## Guardrails
- Never auto-add to Dock from the sheet; **Add to Dock** stays the explicit confirm on Tile Detail.
- No changes to Dock Lock, popovers, or migration.
- Smart Add usage data stays on device and is independent of the analytics toggle.
- Fixed 768pt window width is unchanged; the sheet floats within it.

## Definition of done
- `+` with no suggestions == today's blank-tile flow.
- `+` with suggestions shows the sheet with one prominent + rest tinted + neutral "Create New Tile".
- Picking a suggestion creates a pre-filled, non-docked tile selected in Tile Detail.
- No network calls added; all tests pass; strings localized.
