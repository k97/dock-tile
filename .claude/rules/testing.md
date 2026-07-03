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
`IconStyle.from(…isDarkMode:)`, `shouldReregisterOnLaunch`, `classifyForMigration`,
`runRegenerationBatch`, `helperInfoPlist` / `stripMainAppIcons`, `Debouncer`,
`AppInstallChecker.classifyInstallStatus`, `PopoverMetrics` / `PopoverSettings.resolve`,
`SmartAddEngine.rankGroups` / `.score` / `.coLaunchClusters` / `SmartAddCategory.identity`,
`AnalyticsService.resolveConsent` / `.shouldCollect`,
`DockTileDetailView.resolveDockAction` / `.dockActionIsEnabled` / `.contentSignature`,
`HelperBundleManager.shouldPerformDockRemoval` / `.helperFolderName` (same-name tiles disambiguate to distinct folders) / `.helperIconsComplete` (bundle icon-integrity probe), `HelperMigrationManager.classifyHelperHealth` (self-heal targets pinned-and-broken bundles only — drafts safe), `DiagnosticsLog.shouldRecord` (verbose dev/prod gate),
`ConfigurationManager.canCreateNewTile` (sidebar + gate — never deadlock at zero tiles),
`IconDepthMetrics` (glyph size-ratio cap + glass stroke + Liquid-Glass surface/glyph sheen + shadow + shading, per style, size-gated — shared by the baked `.icns` renderer and the live preview; `glyphSheen` covers symbols 0.55 and emoji 0.18),
`NSColor/Color.liftedForDarkGlyph` (perceived-luminance floor for the Dark-style tinted glyph — `#5F00FF` visibility) + `TintColor.colors`/`.nsColors(for:iconType:)` (Dark splits SF Symbol vs emoji, guarded by `DarkGlyphTreatmentTests`),
`AppRelocation.classify` / `.blocksBundleGeneration` / `.requiresRelocation` (translocation → move-to-/Applications decision),
`FloatingPanel.resolveAnchor` / `DockPrefs.resolve` (popover pin point — magnification `largesize+25` envelope, autohide tilesize fallback, orientation from pref; guarded by `FloatingPanelAnchorTests`).

Assertion rules: prefer `#require` over `if`-guarded `#expect`; assert exact values/magnitudes,
not `!=nil` / `.isValid` / `a>b`; never write `UserDefaults.standard` in tests — use
`MockUserDefaults`. New files under `DockTileTests/` auto-join the target (synchronized group);
new **app-target** files do not — append to an existing file or edit the pbxproj.

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
