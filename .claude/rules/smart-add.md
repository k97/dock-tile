# Smart Add

Suggests ready-made tiles from the user's **recent app usage** on every add entry point. A modal
sheet always opens (see "The + flow" below); it offers suggestion cards when the engine has some,
otherwise a blank-tile row. A **global app feature**, ON by default (opt-out).

## On-device signal (`SmartAddEngine`)

Single `@MainActor` `ObservableObject` singleton (`SmartAddEngine.shared`) — the only access point.
There is **no Siri and no public Apple API for app-usage frequency**, so the engine builds its own
signal, entirely on device:

- **Launch/activation history** — observes `NSWorkspace.shared.notificationCenter`
  (`didLaunchApplicationNotification` / `didActivateApplicationNotification`), persisted as a
  rolling JSON log beside the config file (dev/release split name, retention + size caps).
- **Spotlight metadata** — `kMDItemUseCount` / `kMDItemLastUsedDate` via `NSMetadataQuery` over the
  Applications dirs, harvested async into a cache on `warmUp()` so `computeSuggestions` stays cheap.
- **Category** — `LSApplicationCategoryType` from each app bundle's Info.plist.

**Stays on device (critical)**: Smart Add data is never transmitted and is **independent of the
analytics consent toggle** — it is not analytics. The sheet says so ("Learned on your Mac. Never
leaves your device."). **Main-app only**: `startObserving()` / `warmUp()` early-return via
`AppEnvironment.isHelper` (helpers only render popovers); the engine also skips Dock Tile's own
bundles so it never suggests itself.

## Pure ranking seams (regression-guard convention)

The regression-prone decisions are `nonisolated static` functions taking plain values (mirrors
`resolveDockVisibility`), unit-tested without NSWorkspace/Spotlight/FileManager:

- `SmartAddCategory(lsCategory:)` + `.identity` — category → tile identity (name / SF Symbol / tint)
  per the design handoff (browsers→Browse/globe/blue · video→Watch/play.fill/pink ·
  developer-tools→Ship/chevron.../indigo · social→Chat/bubble.../green · productivity→Work/folder/blue).
  `Identity.coLaunch` (Together/link/orange) is the backstop for a co-launch cluster that can't borrow
  a category identity — distinct from every category in name, symbol AND tint.
- `score(for:now:)` — recency × frequency, with a floor for undated apps.
- `rankGroups(...)` — group by category (+ cross-category co-launch clusters), require **≥3 apps**,
  score, sort best-first, **greedy de-dup** (no app in two suggestions), relabel the top surviving
  group `.recency` ("Most used this week"). Caps apps per tile at `maxAppsPerGroup`.
  **Identities are unique across cards (critical)**: a second pass assigns identities — a surviving
  category group always owns its category identity (rank order never strips it); a co-launch cluster
  borrows its dominant category only when no surviving category group is that category, else it takes
  `Identity.coLaunch`; a group that can't get a free identity is dropped. `dominantCategory` returns
  `nil` when no member has a mapped category — it used to fall back to `.productivity`, so every
  uncategorised cluster (Chrome has no `LSApplicationCategoryType`) became a second "Work"/folder card
  beside the real productivity group.
- `coLaunchClusters(...)` — sessionize the log on a time gap, connected components of app pairs that
  co-occur in ≥N sessions.

Guarded by `SmartAddEngineTests`.

## The + flow (v3: the dialog opens only while Smart Add is ON)

Every add entry point — sidebar `+` and the zero-tiles button (General's *Add a Tile…* row was a
third until 2026-09-02, removed as a duplicate of the sidebar `+`) — calls the SAME `handleAddTapped`.
**Smart Add ON** → it presents `SmartAddSheet` via `.sheet(item:)`, showing suggestions when the
engine has some, else the blank-first row + "No suggestions yet". **Smart Add OFF** → no dialog at
all: the + creates the blank tile directly (a sheet holding only the blank row was a pointless
extra step — 2026-09-02 feedback, superseding v2's "dialog always opens").
`SmartAddEngine.suggestionsForAddFlow(enabled:computed:)` still filters what an opened dialog
shows; its disabled branch is a pure-seam back-stop, no longer a reachable UI state. The sheet's
Return default is **Create New Tile** (blank); *Use This Tile* pre-fills Tile Detail. ⌘N *New Dock
Tile* still creates a blank tile directly. Nothing in the dialog docks a tile.

- **`.sheet(item:)`, NOT `.sheet(isPresented:)` (critical)**: the suggestions ride *inside* the
  presentation item. With a separate `Bool` + `@State` array, SwiftUI evaluated the sheet content
  while the array was still its old empty value → the sheet opened with **zero cards**. `item:`
  builds the content from the exact value that opened it, so it can never present empty.
- **Never auto-adds to Dock (critical)**: picking a suggestion only pre-fills Tile Detail. **Add to
  Dock** stays the explicit confirm there. The ⌘N menu item still creates a blank tile directly.
- The `+` keeps its existing `selectedConfigHasBeenEdited` enable/disable gating.

## `createConfiguration(from:)`

Seeds a `DockTileConfiguration` from a `TileSuggestion` (name via `uniqueName`, tint, SF Symbol
icon, `appItems`), selects it, marks it edited, logs `.tileCreated` with `source: "smart_add"`.

- **`isVisibleInDock = true`** — matches a blank new tile's default so the **Show Tile** switch
  reads on while reviewing. This does **not** pin anything: with no helper bundle on disk the action
  button still reads **Add to Dock**, and the reconciler's **never-pinned guard** (see
  architecture.md "Never-pinned guard") spares this brand-new-visible-but-unpinned state.

## Opt-out toggle & provenance banner

- **General settings toggle** — "Suggest tiles from my apps" is the sole row of
  `GeneralSettingsView`'s "Adding Tiles" section (no leading icon). Opt-out, default ON, key
  `UserDefaultsKeys.smartAddEnabled` (main-app domain — the flow is main-app only, so **not** the
  shared suite). When off, the + skips the dialog and creates a blank tile directly (see "The +
  flow").
- **Provenance banner** — accent-tinted sparkle banner atop `DockTileDetailView` for a just-created
  Smart Add tile. Gated on `ConfigurationManager.smartAddProvenanceIDs` — **runtime-only, never
  persisted**, so it never reappears after relaunch; cleared when dismissed or when the tile is
  added to the Dock.
