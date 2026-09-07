# Testing

## Framework

| Purpose | Framework |
|---------|-----------|
| Unit Tests | Swift Testing (`@Test`, `#expect`, parallel by default) |
| UI Tests | XCUITest (locally only — requires Dock interaction) |

Module import name: `Dock_Tile`

## Commands

```bash
# All unit tests
xcodebuild test -project DockTile.xcodeproj -scheme DockTile \
  -configuration Debug -destination 'platform=macOS' \
  -only-testing:DockTileTests CODE_SIGNING_ALLOWED=NO

# Specific test class
xcodebuild test -project DockTile.xcodeproj -scheme DockTile \
  -destination 'platform=macOS' \
  -only-testing:DockTileTests/ConfigurationModelsTests

# With coverage
xcodebuild test -project DockTile.xcodeproj -scheme DockTile \
  -destination 'platform=macOS' -enableCodeCoverage YES
```

## Regression-Guard Convention

The recurring regressions came from critical invariants buried in `@MainActor` singletons
touching real CFPreferences/FileManager — untestable, so unguarded. When a regression-prone
**decision** lives in a singleton/view, extract the rule into a `nonisolated static func` (or
plain `static` on an already-`@MainActor` type) taking plain values, delegate the call site to
it, and unit-test the seam so a broken rule fails loudly. Existing seams: `resolveDockVisibility`,
`IconStyle.from(…isDarkMode:)` / `.resolve(…isDarkMode:)` (unrecognised value → nil = don't act, never Default; the observed macOS value set is guarded by `IconStyleResolveTests`),
`HelperBundleManager.iconMatchesStyle` (launch self-heal: live icon vs the resolved style's variant, byte-compared; unanswerable → match — guarded by `HelperIconMatchTests`),
`shouldReregisterOnLaunch`, `classifyForMigration`,
`runRegenerationBatch`, `helperInfoPlist` / `stripMainAppIcons`, `Debouncer`,
`AppInstallChecker.classifyInstallStatus`, `PopoverMetrics` / `PopoverSettings.resolve`,
`SmartAddEngine.rankGroups` (app + identity de-dup — no two cards share a name/icon) / `.score` / `.coLaunchClusters` / `.dominantCategory` (nil without signal, never a silent `.productivity`) / `SmartAddCategory.identity` + `Identity.coLaunch` backstop,
`AnalyticsService.resolveConsent` / `.shouldCollect`,
`DockTileDetailView.resolveDockAction` / `.dockActionIsEnabled` / `.contentSignature`,
`HelperBundleManager.shouldPerformDockRemoval` / `.helperFolderName` (same-name tiles disambiguate to distinct folders) / `.dockFileLabel` (Dock tooltip = display name, never the folder stem) / `.helperIconsComplete` (bundle icon-integrity probe), `HelperMigrationManager.classifyHelperHealth` (self-heal targets pinned-and-broken bundles only — drafts safe), `DiagnosticsLog.shouldRecord` (verbose dev/prod gate),
`ConfigurationManager.canCreateNewTile` (sidebar + gate — never deadlock at zero tiles),
`IconDepthMetrics` (glyph size-ratio cap + glass stroke + Liquid-Glass surface/glyph sheen + shadow + shading, per style, size-gated — shared by the baked `.icns` renderer and the live preview; `glyphSheen` covers symbols 0.55 and emoji 0.18),
`NSColor/Color.liftedForDarkGlyph` (perceived-luminance floor for the Dark-style tinted glyph — `#5F00FF` visibility) + `TintColor.colors`/`.nsColors(for:iconType:)` (Dark splits SF Symbol vs emoji, guarded by `DarkGlyphTreatmentTests`) + `.badgeColors(for:tint:)` (Settings-badge mirror, lock-step guarded by `BadgeColorMappingTests`),
`AppRelocation.classify` / `.blocksBundleGeneration` / `.requiresRelocation` (translocation → move-to-/Applications decision),
`FloatingPanel.resolveAnchor` / `DockPrefs.resolve` (popover pin point — magnification `largesize+25` envelope, autohide tilesize fallback, orientation from pref; guarded by `FloatingPanelAnchorTests`),
`AppListEditor.removing(_:from:)` / `.moving(_:onto:in:)` (tile editor's remove/reorder reducer, guarded by `AppListEditorTests`),
`PopoverPreviewCanvas.fitScale` (hero zoom that scales the fixed-size real popover into a `.worstCase` frame, guarded by `PopoverPreviewCanvasTests`),
`PopoverPanelLayout.gridPanelSize` / `.listPanelSize` (the panel size formulas shared by the real panels and the editor canvas — the list pins only its width, so an undershoot here CLIPS the panel; the grid's `includesMissingCaption` bills the editor-only "Not installed" line),
`PopoverPreviewCanvas.naturalPanelSize` / `.naturalScale` (the `.natural` fit — the panel's intrinsic size and the scale that fits it into the fixed-width detail column),
`ConfigurationManager.displayName(for:)` / `.commitDisplayName` (the sidebar/title-band name lags the stored one until an explicit commit — seeded on load, or the mechanism is silently inert),
`SmartAddEngine.suggestionsForAddFlow` (filters what an opened add dialog shows; since 2026-09-02 the dialog only opens while Smart Add is on — off creates a blank tile directly),
`ConfigurationDefaults.iconValue` (new tiles default to the `"plus"` placeholder glyph, not a category icon).

Assertion rules: prefer `#require` over `if`-guarded `#expect`; assert exact values/magnitudes,
not `!=nil` / `.isValid` / `a>b`; never write `UserDefaults.standard` in tests — use
`MockUserDefaults`. New files under `DockTileTests/` auto-join the target (synchronized group);
new **app-target** files do not — append to an existing file or edit the pbxproj.

## A guard must be able to fail

Three icon-side guards passed for a *provably broken* implementation: a comparison whose two
sides both collapsed to the same default under the exact regression it targeted; a "no baked
background" check sampling only corners that lay outside the shape anyway; and
`saturation > 0.3`, which the unfixed value already satisfied. Before writing a guard, name the
regression and ask which value would make it fail — if none would, it is decorative, and worse
than nothing because it invites trust.

Prefer a **structural** guarantee wherever one is expressible: deleting a stored property's
default (definite initialisation then forces the seed) or a function parameter's default turns
the regression into a compile error, which no test can beat. State plainly where such a
guarantee stops — definite initialisation catches a naive reorder, not a placeholder-then-real-
assignment restructure.

## Coverage Targets

| Component | Target |
|-----------|--------|
| Managers | 85-90% |
| Models | 80-90% |
| Utilities | 90%+ |
| UI Views | 50-60% |
| **Overall** | **75-80%** |

## Test Structure

```
DockTileTests/
├── Unit/
│   ├── Constants/AppStringsTests.swift
│   ├── Models/ConfigurationModelsTests.swift, TintColorTests.swift
│   └── Utilities/IconGeneratorTests.swift
├── Integration/DockRestartConsentTests.swift
└── Mocks/
```

## Test-host guard (don't mutate live dev data)

`DockTileTests` is **hosted by the dev app** (`TEST_HOST = Dock Tile Dev.app`), so `xcodebuild test`
launches the real app, whose normal launch path runs against the user's **live dev** support folder,
config, and Dock plist. `AppEnvironment.isRunningTests` (env `XCTestConfigurationFilePath` /
`XCTestCase` present) gates every launch-time mutator on `!isRunningTests`: `configureAsMainApp`
(Dock Lock, login items, Smart Add, relocation), the `DockTileApp` `.task` (helper
migration/regeneration + missing-app scan — migration once corrupted a tile mid-generation),
`ConfigurationManager` init (Dock reconcile + watch), and `main.swift` diagnostics-log trim.
`TestEnvironmentTests` asserts the flag is true so the guard can't silently regress.

## CI

Unit tests run in GitHub Actions (`ci.yml`). UI/integration tests run locally only.
