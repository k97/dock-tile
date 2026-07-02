# Diagnostics & Verbose Dev Logging

Cross-process event capture so **File → Copy Diagnostics** (⌘-menu) yields one timeline covering the
main app **and every helper tile**. Rich in dev, lean in prod. Engine:
[DiagnosticsLog.swift](../../DockTile/Managers/DiagnosticsLog.swift).

## Cross-process model

- Main app + all helpers are binary copies sharing one Application Support folder
  (`AppEnvironment.supportURL`) and the app is not sandboxed → every process appends to ONE shared
  file (`diagnostics.log`) with atomic `O_APPEND` writes. Each line: `ISO8601 [role:tile pid]
  [category] message`. Main app trims to the last hour on launch (`prepareOnLaunch`); helpers
  append-only (no trim races). `report()` reads the shared file so the copied report spans all
  processes. Mirrored to the unified log (subsystem `com.docktile.diagnostics`) for Console.app.
- Helpers tag themselves via `setLabel("helper:<tile>")` once their config loads.

## Verbosity: dev-rich / prod-quiet (critical)

- `log(category, message, verbose:)` — `verbose: true` events are **dropped in Release, kept in
  Debug/dev**. Gate is the pure seam `DiagnosticsLog.shouldRecord(verbose:isRelease:)` (mirrors
  `AnalyticsService.shouldCollect`), guarded by `DiagnosticsLogTests`. Dev and prod write to
  **separate files** (separate support folders), so dev's firehose never reaches a user's prod log.
- **`ui(_:)`** — semantic shorthand for `log("ui", …, verbose: true)`. Use for the *gesture that
  triggers work* (`"+ pressed"`, `"Add to Dock pressed"`, `"Dock icon clicked → show popover"`,
  menu/sidebar/sheet selections). ALWAYS verbose → the click firehose enriches dev reports and is
  auto-dropped in prod, with no per-call bookkeeping. It **complements** the non-verbose
  state-change logs that record the *outcome* ("Added tile 'X' in Dock"): `ui` = what the user did,
  `log` = what the app did.
- The report header prints a `Verbose: on/off` line so it's obvious whether click/workflow traces
  are present.

## Workflow timing: `measure(_:_:)`

Brackets a unit of work with `▶ <name>` / `✔ <name> (Nms)` lines (verbose — dev only) **and** an
`OSSignposter` interval on the `com.docktile.diagnostics` "workflow" track (profilable in
Instruments). A thrown error logs `✗ <name> FAILED (Nms)` **non-verbose** (failures matter in prod)
and re-throws. Returns the body's value unchanged — wrapping never alters behaviour
(`DiagnosticsMeasureTests`).

- Async + sync overloads. The **async overload inherits caller isolation via `isolation: isolated
  (any Actor)? = #isolation`** — required so a `@MainActor` workflow closure capturing actor state
  (e.g. `HelperMigrationManager.regenerateBatch`) isn't "sent" across actors (Swift 6 non-Sendable
  closure error). Do not drop that parameter.
- Wrapped workflows today: helper install/update + remove (`DockTileDetailView.performDockAction`),
  the migration + popover-appearance reapply batches (`HelperMigrationManager`), popover build+show
  (`HelperAppDelegate.showPopover`).

## Instrumentation conventions

- **Errors + state changes** → non-verbose `log(category, …)` (kept in prod). **Clicks / high-freq
  UI churn** (colour drag, icon-size stepper, watcher debounce, poll ticks, reorder) → `verbose:
  true` or `ui(…)`.
- **Main-app-only** paths and **helper-only** paths both call `DiagnosticsLog.shared` directly (it's
  compiled into every helper). No process guard is needed on the logger itself.
- `DiagnosticsLog.swift` lives in `Managers/` (classic Xcode group — a **new** manager file needs a
  `project.pbxproj` entry; editing it does not). New `DockTileTests/` files auto-join the target.

See also [[project_diagnostics_expansion]] for the base feature's history.
