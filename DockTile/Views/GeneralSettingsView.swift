//
//  GeneralSettingsView.swift
//  DockTile
//
//  The "General" pane of the main window's inline Settings (⌘, opens it).
//  Hosts the global "Start tiles at login" toggle, backed by a single SMAppService
//  launcher agent (see LoginItemManager).
//
//  Swift 6 - Strict Concurrency
//

import SwiftUI

struct GeneralSettingsView: View {
    @EnvironmentObject private var configManager: ConfigurationManager

    /// Mirrors SMAppService status — the system is the source of truth, not local
    /// storage. Synced in `.onAppear` so it reflects changes the user makes in
    /// System Settings → Login Items.
    @State private var startAtLoginOn = false
    @State private var loginRequiresApproval = false
    /// Bumped per `refreshLoginState`; a reply from an older refresh is dropped.
    @State private var loginRefreshGeneration = 0
    /// What the system last said (or, before the first read, the stored intent). The toggle's
    /// `onChange` compares against this instead of re-reading `SMAppService.status` on the main thread.
    @State private var loginSystemOn = false
    @State private var loginRegistrationError: String?

    /// Drives the manual "Scan…" results dialog. `scanFoundMissing` picks the found vs all-clear
    /// variant; the scan itself runs with `raiseLaunchPrompt: false` so this dialog — not the
    /// global launch prompt — presents the outcome.
    @State private var showScanResult = false
    @State private var scanFoundMissing = false

    /// Analytics consent (opt-out, default ON). Backed by the SHARED suite so helper bundles
    /// honour the same value — see AnalyticsService.
    @AppStorage(UserDefaultsKeys.analyticsEnabled, store: UserDefaults(suiteName: UserDefaultsKeys.sharedSuiteName))
    private var analyticsEnabled = true

    /// Smart Add on/off (opt-out, default ON). Main-app domain — the suggestion flow is main-app
    /// only, so this is not stored in the shared suite.
    @AppStorage(UserDefaultsKeys.smartAddEnabled)
    private var smartAddEnabled = true

    /// The menu bar icon (#13). Seeded at launch (`MenuBarController.initialEnabled`); absent = OFF.
    @AppStorage(UserDefaultsKeys.menuBarEnabled)
    private var menuBarEnabled = false

    var body: some View {
        Form {
            // All general preferences live in a single grouped container (System Settings style):
            // Start at login → Missing apps → Share analytics.
            Section {
                startAtLoginRow

                missingAppsRow

                analyticsRow
            }

            Section(AppStrings.Settings.menuBar) {
                menuBarRow
            }

            // Adding Tiles — the Smart Add toggle only. An "Add a Tile…" link once sat below it
            // but duplicated the sidebar + (removed on review feedback 2026-09-02); adding tiles
            // stays with the sidebar + and the zero-tiles empty state.
            Section(AppStrings.Settings.addingTiles) {
                smartAddRow
            }
        }
        .formStyle(.grouped)
        .paneScrollEdgeEffect()
        .paneTitleBand(AppStrings.Settings.general)
        .onAppear {
            // Start from the stored intent (no XPC) so the switch does not draw OFF for a frame and
            // animate ON on every visit; the background read then confirms or corrects it.
            let intent = LoginItemManager.shared.shouldBeEnabled
            loginSystemOn = intent
            startAtLoginOn = intent
            refreshLoginState()
        }
        .alert(
            scanFoundMissing ? AppStrings.Alert.missingAppsTitle : AppStrings.Alert.missingAppsNoneTitle,
            isPresented: $showScanResult
        ) {
            if scanFoundMissing {
                // Primary path: send the user to the tile so they resolve it in context against
                // the dimmed "Not installed" rows. Remove All is the quick convenience.
                Button(AppStrings.Button.reviewInTiles) { reviewMissingInTiles() }
                Button(AppStrings.Button.removeAll, role: .destructive) { configManager.removeMissingApps() }
                Button(AppStrings.Button.cancel, role: .cancel) {}
            } else {
                Button(AppStrings.Button.done) {}
            }
        } message: {
            Text(scanFoundMissing ? missingAppsFoundMessage : AppStrings.Alert.missingAppsNoneMessage)
        }
    }

    // MARK: - Rows

    private var startAtLoginRow: some View {
        Group {
            Toggle(isOn: $startAtLoginOn) {
                Text(AppStrings.Label.startAtLogin)
                Text(AppStrings.Label.startAtLoginDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .onChange(of: startAtLoginOn) { _, enabled in
                // `refreshLoginState` writes this @State to mirror the system; ignore those
                // syncs and act only on a genuine user toggle, so we never re-register in a loop.
                guard enabled != loginSystemOn else { return }
                applyLoginSetting(enabled)
            }

            // Shown when the last registration attempt (launch reconcile or a toggle flip) was
            // refused by macOS — otherwise the switch just snaps back with no explanation.
            if let loginRegistrationError {
                Text(String(format: AppStrings.Settings.loginRegistrationFailed, loginRegistrationError))
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            // Shown when macOS is holding the launcher item for user approval.
            if loginRequiresApproval {
                HStack(spacing: 8) {
                    Text(AppStrings.Settings.loginRequiresApproval)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button(AppStrings.Button.openLoginItems) {
                        LoginItemManager.shared.openLoginItemsSettings()
                    }
                    .controlSize(.small)
                }
            }
        }
    }

    /// On-demand re-check for apps that have been moved or uninstalled. Complements the automatic
    /// once-per-launch scan — useful when an app is removed while the window is already open.
    private var missingAppsRow: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(AppStrings.Label.missingAppsScan)
                Text(AppStrings.Label.missingAppsScanDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(AppStrings.Button.scanForMissingApps) {
                runMissingAppsScan()
            }
        }
    }

    /// Smart Add on/off. When OFF, pressing + always creates a blank tile (no suggestion sheet).
    /// No leading icon, per the design.
    private var smartAddRow: some View {
        Toggle(isOn: $smartAddEnabled) {
            Text(AppStrings.SmartAdd.settingsToggleTitle)
            Text(AppStrings.SmartAdd.settingsToggleDescription)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .onChange(of: smartAddEnabled) { _, enabled in
            AnalyticsService.shared.log(.settingChanged, ["setting": "smart_add", "enabled": enabled])
            DiagnosticsLog.shared.log("settings", "Smart Add toggled \(enabled ? "ON" : "OFF")")
        }
    }

    /// Adds or removes the menu bar icon at once. Turning it off brings the Dock icon back (the
    /// window is open while toggling); the app then quits on close again unless Dock Lock is on.
    private var menuBarRow: some View {
        Toggle(isOn: $menuBarEnabled) {
            Text(AppStrings.Settings.menuBarToggle)
            Text(AppStrings.Settings.menuBarToggleDescription)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .onChange(of: menuBarEnabled) { _, enabled in
            MenuBarController.shared.apply(enabled: enabled)
            if !enabled { NSApp.setActivationPolicy(.regular) }
            AnalyticsService.shared.log(.settingChanged, ["setting": "menu_bar", "enabled": enabled])
            DiagnosticsLog.shared.log("settings", "Menu bar icon toggled \(enabled ? "ON" : "OFF")")
        }
    }

    // Privacy: opt-out analytics. Disabling stops all Analytics + Crashlytics collection.
    private var analyticsRow: some View {
        Toggle(isOn: $analyticsEnabled) {
            Text(AppStrings.Label.shareAnalytics)
            Text(AppStrings.Label.shareAnalyticsDescription)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .onChange(of: analyticsEnabled) { _, enabled in
            AnalyticsService.shared.setConsent(enabled)
            AnalyticsService.shared.log(.settingChanged, ["setting": "analytics", "enabled": enabled])
            DiagnosticsLog.shared.log("settings", "Share analytics toggled \(enabled ? "ON" : "OFF")")
        }
    }

    // MARK: - Missing App Scan

    /// Force a fresh scan and present the results dialog (not the global launch prompt).
    private func runMissingAppsScan() {
        configManager.scanForMissingApps(force: true, raiseLaunchPrompt: false)
        scanFoundMissing = !configManager.missingAppIDs.isEmpty
        showScanResult = true
        DiagnosticsLog.shared.log("settings", "Manual missing-app scan: \(configManager.missingAppIDs.count) flagged")
    }

    /// "• Tile — App, App" lines for each tile that has a missing app.
    private var missingAppsFoundMessage: String {
        let list = configManager.tilesWithMissingApps
            .map { "• \($0.config.name) — \($0.apps.map(\.name).joined(separator: ", "))" }
            .joined(separator: "\n")
        return AppStrings.Alert.missingAppsScanFoundMessage + "\n\n" + list
    }

    /// Route to the first tile holding a missing app; its dimmed rows are the resolution surface.
    /// Setting `selectedConfigId` pulls the detail column out of Settings via the configuration
    /// view's `onChange` binding.
    private func reviewMissingInTiles() {
        guard let first = configManager.tilesWithMissingApps.first else { return }
        configManager.selectedConfigId = first.config.id
    }

    /// Read the current SMAppService status into the toggle (system is source of truth). The read
    /// is an XPC round trip, so it runs off the main thread; a newer refresh supersedes an older
    /// one still in flight (the generation guard), so a slow reply can never overwrite a fresh one.
    private func refreshLoginState() {
        loginRefreshGeneration += 1
        let generation = loginRefreshGeneration
        Task {
            let status = await LoginItemManager.readStatus()
            guard generation == loginRefreshGeneration else { return }
            // Show the toggle ON whenever the user wants it on — including when macOS is holding
            // the agent for approval (common right after a Sparkle update). Rendering it OFF there
            // would look like the setting silently reset itself.
            let requiresApproval = status == .requiresApproval
            loginSystemOn = status == .enabled || requiresApproval
            startAtLoginOn = loginSystemOn
            loginRequiresApproval = requiresApproval
            loginRegistrationError = LoginItemManager.shared.lastRegistrationError
        }
    }

    /// Register/unregister the launcher agent to match the toggle. On failure, revert the
    /// toggle to the real system state so the UI never lies.
    private func applyLoginSetting(_ enabled: Bool) {
        // Until the re-read below lands, treat the user's choice as the system state, so a quick
        // second toggle is not mistaken for a sync and ignored.
        loginSystemOn = enabled
        AnalyticsService.shared.log(.settingChanged, ["setting": "start_at_login", "enabled": enabled])
        DiagnosticsLog.shared.log("settings", "Start at login toggled \(enabled ? "ON" : "OFF")")
        do {
            if enabled {
                try LoginItemManager.shared.enable()
            } else {
                try LoginItemManager.shared.disable()
            }
        } catch {
            AnalyticsService.shared.record(error, context: "loginItemToggle",
                                           keys: ["enabled": "\(enabled)"])
            print("⚠️ Login item toggle failed: \(error.localizedDescription)")
        }
        // Re-read the truth: register() can land in .requiresApproval, and a failed call
        // means the state didn't change.
        refreshLoginState()
    }
}
