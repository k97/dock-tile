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
it, and unit-test the seam so a broken rule fails loudly. Existing seams: `resolveDockVisibility` (an operation in flight → `.inSync` before any rule; `DockVisibilityReconcileTests`) + `HelperBundleManager.dockOperationInFlight` (building, removing or verifying; `DockOperationInFlightTests`),
`IconStyle.from(…isDarkMode:)` / `.resolve(…isDarkMode:)` (unrecognised value → nil = don't act, never Default; the observed macOS value set is guarded by `IconStyleResolveTests`),
`HelperBundleManager.iconMatchesStyle` (launch self-heal: live icon vs the resolved style's variant, byte-compared; unanswerable → match — guarded by `HelperIconMatchTests`),
`shouldReregisterOnLaunch`, `classifyForMigration`,
`runRegenerationBatch`, `helperInfoPlist` / `stripMainAppIcons`, `Debouncer`,
`AppInstallChecker.classifyInstallStatus`, `PopoverMetrics` / `PopoverSettings.resolve`,
`SmartAddEngine.rankGroups` (app + identity de-dup — no two cards share a name/icon) / `.score` / `.coLaunchClusters` / `.dominantCategory` (nil without signal, never a silent `.productivity`) / `SmartAddCategory.identity` + `Identity.coLaunch` backstop,
`AnalyticsService.resolveConsent` / `.shouldCollect`,
`IconLift.metrics(size:)` (App Store-style lift per icon size; hero Light = tight 3 / 1.5 shadow at 0.22, no hairline — matched to the App Store's measured edge; `IconLiftTests`),
`NSColorBackgroundView.inspectorCardColor` + `AppearanceColorView` (inspector card = translucent white 50% Light / 8% Dark; dynamic colours re-resolve on every appearance change; `AppearanceColorViewTests`),
`DockTileDetailView.resolveDockAction` / `.dockActionIsEnabled` / `.contentSignature` / `.actionIsProminent` + `DockTileConfiguration.dockSignature` (Update is accent only while the helper's `DTDockSignature` differs from the tile; bookkeeping never moves it; `DockSignatureTests`),
`HelperBundleManager.dockEntriesAreCurrent` / `.reconciledDockApps` / `.isSameFile` (one entry that is the same file as the helper — device + inode, so symlinks and the Data-volume spelling pass — is current; a missing path, another bundle at the path, an unparseable entry or a duplicate is replaced in the first slot; another tile's entry is never touched; `DockEntryPathTests` + `DockEntryReconcileTests`), `HelperBundleManager.dockRestartArguments` (SIGKILL; `DockRestartSignalTests`),
`HelperBundleManager.unmetExpectations` / `.batchExpectations` / `.retryableExpectations` / `.incrementingCounts` + `.decrementingCounts` / `.runDockVerification` (the verified restart: absent = no entry, present = the shared predicate; a batch expects only tiles pinned before it; a retry never touches a tile another operation is building or removing, except the caller's own; overlapping checks of one tile are counted; retry once, never loop, re-check only what was retried; `DockExpectationTests`),
`HelperBundleManager.runStagedRebuild` (the 2.6.3 rebuild order: build/sign while the old helper runs → quit → swap → remove a renamed tile's old folder → register → quit again → launch; a build failure cancels the bar and never touches the old tile, a swap failure relaunches it; `StagedRebuildTests`) / `.swapIntoPlace` / `.oldFolderToRemove` (path-normalised, decided before the swap — a trailing slash must not delete the new bundle) / `.stagingBundleURL` / `.removeStaleStaging` + `TileBuildLock` (per-tile flock, conflicts across opens; `HelperSwapTests`),
`TileRebuildSignal` / `RebuildBarState` (bar never moves back, 30 s expiry, `eased` lands exactly so the animation timer stops) / `RebuildTileView.barRect` / `.shapeRect` (icon drawn at full bounds — no second icon-grid inset; `TileRebuildBarTests`),
`HelperBundleManager.shouldPerformDockRemoval` / `.helperFolderName` (same-name tiles disambiguate to distinct folders) / `.dockFileLabel` (Dock tooltip = display name, never the folder stem) / `.helperIconsComplete` (bundle icon-integrity probe), `HelperMigrationManager.classifyHelperHealth` (self-heal targets pinned tiles only — drafts safe — whose bundle is broken OR whose Dock entry is stale by the shared predicate), `DiagnosticsLog.shouldRecord` (verbose dev/prod gate),
`ConfigurationManager.canCreateNewTile` (sidebar + gate — never deadlock at zero tiles),
`IconDepthMetrics` (glyph size-ratio cap + glass stroke + Liquid-Glass surface/glyph sheen + shadow + shading, per style, size-gated — shared by the baked `.icns` renderer and the live preview; `glyphSheen` covers symbols 0.55 and emoji 0.18),
`ToneMap.fit` / `.contrastRatio` + `TilePalette.resolve` (+ `fillWasDeepened`) (every tile colour role derived with every drawn pair >= 3:1 — the Dark-glyph `#5F00FF` visibility case lives here; replaced `liftedForDarkGlyph`), `CustomiseTileView.colourRowState`, `DockTileIconPreview.displayStyle` (canonical forced previews), `HelperBundleManager.declarativeFillsP3`, + `TintColor.colors`/`.nsColors(for:iconType:background:)` (Dark splits SF Symbol vs emoji, guarded by `DarkGlyphTreatmentTests`) + `.badgeColors(for:tint:)` (Settings-badge mirror, lock-step guarded by `BadgeColorMappingTests`),
`AppRelocation.classify` / `.blocksBundleGeneration` / `.requiresRelocation` (translocation → move-to-/Applications decision),
`FloatingPanel.resolveAnchor` / `DockPrefs.resolve` (popover pin point — magnification `largesize+25` envelope, autohide tilesize fallback, orientation from pref; guarded by `FloatingPanelAnchorTests`),
`HelperAppDelegate.shouldSwallowReopen` (post-cold-launch reopen swallow is time-bounded ~1s — an unbounded flag silently ate the next Dock click when macOS skipped the trailing reopen, issue #12; guarded by `HelperReopenSwallowTests`. The ⌘Tab use of it (issue #15) is delegate wiring no unit test reaches — verify with the `NSWorkspace.openApplication` replay in architecture.md),
`FloatingPanel.keyboardAnchorPoint` (⌘Tab popover anchors at the last Dock click while its screen is connected, else the centre of the screen passed in — the primary screen at the call site — never the mouse; issue #15, guarded by `FloatingPanelKeyboardAnchorTests`),
`PaneScrollEdgeEffect.opacity(forOffset:)` (title-band scroll scrim ramp — 0 at rest AND during rubber-band overscroll so the chromeless v2 band stays chromeless, 1 past the ramp, linear between; guarded by `PaneScrollEdgeEffectTests`),
`AppListEditor.removing(_:from:)` / `.moving(_:onto:in:)` (tile editor's remove/reorder reducer, guarded by `AppListEditorTests`),
`PopoverPreviewCanvas.fitScale` (hero zoom that scales the fixed-size real popover into a `.worstCase` frame, guarded by `PopoverPreviewCanvasTests`),
`PopoverPanelLayout.gridPanelSize` / `.listPanelSize` (the panel size formulas shared by the real panels and the editor canvas — the list pins only its width, so an undershoot here CLIPS the panel; the grid's `includesMissingCaption` bills the editor-only "Not installed" line),
`PopoverPreviewCanvas.naturalPanelSize` / `.naturalScale` (the `.natural` fit — the panel's intrinsic size and the scale that fits it into the fixed-width detail column),
`ConfigurationManager.displayName(for:)` / `.commitDisplayName` (the sidebar/title-band name lags the stored one until an explicit commit — seeded on load, or the mechanism is silently inert),
`SmartAddEngine.cardStyles(count:using:)` (Add a Tile cards: one App Grid, one Symbol, one Emoji, shuffled per open; the created tile follows its card; `SmartAddCardStyleTests` + `tileMatchesTheCardsDesign`),
`SmartAddEngine.suggestionsForAddFlow` (filters what an opened add dialog shows; since 2026-09-02 the dialog only opens while Smart Add is on — off creates a blank tile directly),
`IconStyleManager.displayPollAction` (main-app icon-style display poll runs only while the app is visible — never restarted while running, never left running hidden; issue #22, guarded by `IconStyleDisplayPollTests`),
`TileFace.showsSystemIcon` + `DockTileConfiguration.iconSignature` (Tinted and Clear tile faces show the system's render only when the helper's `DTIconSignature` matches the tile's current look — stale/unstamped/other styles draw our own; every icon field moves the signature, non-icon fields don't; issue #22, guarded by `TileFaceTests`),
`ConfigurationDefaults.starterGlyphs(using:)` (a new blank tile draws a random symbol — its glyph — and a random emoji — its saved emoji — from curated pools, owner 2026-10-22; `"plus"` stays only the decode/restore fallback; `StarterGlyphTests` resolves every pool symbol),
`DockTileConfiguration.duplicate(named:)` (a duplicate keeps every content field; only id/name/bundle id/Dock bookkeeping reset — compared through the encoded JSON, issue #21; guarded by `DockTileDuplicateTests`),
`PopoverItemMenu.targetPath` / `.entries` / `.dismissesPopover` / `.runningMatchIndex` / `.claimsEvent` (popover item context menu — missing → no target → no menu, apps target the copy `AppLauncher` launches (lastKnownPath first), apps never get a bundle hand-off item (App Management alert), folders never get running rows, hidden app → no Hide, running match by bundle path not id, overlay claims only right-/Control-clicks so left-click launch and scrolling stay SwiftUI's; guarded by `PopoverItemMenuTests`),
`AppsFaceGrid.emptySlotFill` (an App Grid with no installed apps = four faint slots in the 2×2, never the glyph; `emptySlots`, `emptyGridShowsFourSlots`, `emptyGridLayerDrawsFourSlots`, `allMissingShowsTheEmptyGrid`) / `AppsFaceGrid.columns` / `.cells` / `.drawBox` / `.miniShadow` / `.fillGrays` / `.desaturatesMinis` / `.select` (Apps face: two grids only — 2×2 for 1–4 (one app in the top-left cell) → 3×3 from 5, folders fitted to the cell, missing skipped, nine max; guarded by `AppsFaceGridTests` + `AppsFaceRenderTests` + `AppsFacePreviewTests`),
`AppsFaceGrid.fillColors` / `.usesDarkPlate` / `.layerOnDarkGlass(slot:background:customHex:)` + `AppsGridBackground` tolerant decode (the App Grid plate, v12: Follow System bakes exactly the pre-v12 tones — tinted slot always dark glass; the Custom plate's stop is pre-compensated for macOS's Generic-RGB fill rendering and checked through a real IconServices render; `AppsBackgroundTests`),
`IconDocumentBuilder.appsFaceIconJSON` (system fills + explicit flat keys + one grid per appearance slot, glyph documents never gain a tinted hiding; `IconDocumentBuilderTests`, compiled end-to-end in `IconCompilerTests`, which also asserts each appearance stack shows only its own grid),
`AppIconStyleRenderer.descriptorValues` / `.render` + `HelperBundleManager.styledAppsFaceMinis` (App Grid minis rendered in a NAMED style via private IconServices — Default/Dark/Clear Dark differ by luminance, same icon-grid margin as the public render, folders keep the public icon; `AppIconStyleRendererTests`, which fail rather than skip on macOS 26+ when a render is nil),
`AppInstallChecker.isInstalled` (the one installed-predicate shared by the Apps-face bake, the preview and the Customise Apps card),
`CustomiseTileView.TileStyle(face:iconType:)` / `.applyStyle` / `.inspectorSections` / `.appsSummary(items:isInstalled:)` (the Style picker and the Apps card; `applyStyle` saves the outgoing symbol/emoji + size + Colour/Mono background + tile colour into `savedSymbol` / `savedEmoji` (schema v11) and restores the incoming one, so switching cards never loses a choice; `CustomiseStyleTests` + `SavedGlyphTests`, English host),
`DockTileDetailView.dockActionParameters` (`tile_added_to_dock` / `tile_updated` parameters incl. `face`; `DockActionResolutionTests`),
`AppDelegate.clampedWindowWidth(_:inspectorShown:)` / `.windowFrame(forInspectorShown:from:visibleFrame:)` (window 700 closed, 960 open, 1200 max; the window keeps its width on a toggle, opening only grows it, closing never moves the frame; plus the split-view fit: widest sidebar + `detailColumnMinWidth` (+ 2 × `inspectorWidth` open: the split view counts the inspector twice, once in the SwiftUI hosting view's fitting size and again as the NSSplitView column) stays 8 pt inside each minimum; `MainWindowWidthTests`),
`DockTileConfigurationView.inspectorIsPresented(stored:selection:)` (the inspector shows only for a tile row while the stored flag is on; `InspectorVisibilityTests`),
`DockTileConfigurationView.inspectorSetterWrites(newValue:stored:selection:)` (the `.inspector` binding setter: nil = ignore a write-back of what is presented — our own echo, or `false` on a Settings pane, which must not clear the flag — else exactly `newValue`; `InspectorVisibilityTests`),
`DockTileDetailView.heroForcedStyle(inspectorShown:colorScheme:followsAppearance:)` / `DockTileConfigurationView.inspectorCommandIsEnabled` (hero is canonical Default/Dark while the inspector is open, Dark only when `followsAppearance` — `IconPipeline.isDeclarative`, so never on macOS 15; ⌥⌘I enabled only for a tile row; `InspectorEntryPointTests`),
`IconFace` tolerant decode + the two defaults (missing key → glyph, new tile → apps; unknown value → glyph; `IconFaceTests`),
`MacOSFloorGuardTests` (the deployment target ↔ appcast floor ↔ macOS 15 CI leg ↔ website requirement claims — read from the files, so the macOS 15 leg cannot be dropped while 15 is supported, and must be once it is not).

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

**A CI check is a guard too, and green is not evidence (2026-10-02).** The first Dock render
check went green while its measurement was INCONCLUSIVE: the measurer could not separate the
icons and exited 0. A check that cannot measure must exit non-zero, and its verdict is read from
what it measured (`measure.txt`), never from the job colour. Same family: an expectation computed
from the thing under test (`== IconPipeline.isDeclarative`) cannot catch that thing regressing —
keep one independent pin beside it. And a check script's argument parsing is part of the guard:
a missing or malformed value must be a usage error, never a silently skipped check
(`dock-measure.swift --expect-apps abc` passed, exit 0, until it was made to exit 2).

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

Unit tests run in GitHub Actions (`ci.yml`) on **two hosts**: macos-26, where the project is
built, and macos-15 via `test-without-building` — the only host that runs the legacy icon path
(see [CI & Release](ci-release.md)). So a test must not assume its host: no expectation
hard-coded to the macOS 26 pipeline (follow `IconPipeline.isDeclarative`, or `#available`-gate
the test), and a test that reads the source tree through `#filePath` works on macOS 15 only
because that job checks the repo out at the same path. The first macOS 15 run failed 11 tests for
exactly these two reasons. Since the String Catalog ships (2026-10-17), runtime `AppStrings` values
also follow the test host's language: pin locale-specific expectations through the catalog JSON,
never through `AppStrings` at runtime. Likewise the owner's Mac **icon style**: a test that reads a
real app's icon through `NSWorkspace` gets the CURRENT style, so `AppsFacePreviewTests`
(`oneAppOnLightGlass`, `clearAndTintedDesaturate`, Finder saturation) fail whenever the host is on
Clear or Tinted (2026-10-19). Run the suite on Default, or pin a style with `AppIconStyleRenderer`.
UI/integration tests run locally only.

**Filesystem tests: resolve temp paths with `realpath()`, not `URL.resolvingSymlinksInPath()`** —
the latter deliberately strips `/private`, so a `/System/Volumes/Data` spelling built from it does
not exist (`dataVolumeSpellingIsCurrent` caught this with a `#require`, 2026-10-29). Count suites by
`Test case '<Suite>/` prefixes: a name regex without digits silently undercounts.

**Count tests per suite, not by grepping a whole log.** `grep -c "passed"` over an `xcodebuild`
log drifted between runs of the same tree (748/750/765 for one branch), so a "+N tests" claim
built on it cannot be checked. Report `-only-testing:` per-suite executed counts and the
`TEST SUCCEEDED`/`FAILED` line. `DockPlistWatcherReplaceTests.survivesAtomicReplace` flakes on
macos-26 CI under the full parallel suite: first after `81507dd` (2.2.0), then 6 of 10 runs on
2026-10-28 at its 20 s deadline — with old AND new action pins alike (a same-window A/B ruled out
the #34 bump), while 40/40 passed locally. Its deadline is now 60 s, and a failure of the second
check states how long the FIRST event took: slow (seconds) means main-actor contention on the
runner, fast (~0.2 s) means the watcher really went deaf. The test host's stdout reaches no CI log,
so a `print` there is invisible — put diagnostics in the `#expect` message. Reverting the
watcher's re-arm still fails it (at 60 s, verified that day).
