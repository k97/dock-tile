//
//  GeneralSettingsView.swift
//  DockTile
//
//  The "General" pane of the native macOS Settings window (⌘,).
//  Hosts the global "Start tiles at login" toggle, backed by a single SMAppService
//  launcher agent (see LoginItemManager).
//
//  Swift 6 - Strict Concurrency
//

import SwiftUI

struct GeneralSettingsView: View {
    @EnvironmentObject private var configManager: ConfigurationManager
    @EnvironmentObject private var updateController: UpdateController

    /// Mirrors SMAppService status — the system is the source of truth, not local
    /// storage. Synced in `.onAppear` so it reflects changes the user makes in
    /// System Settings → Login Items.
    @State private var startAtLoginOn = false
    @State private var loginRequiresApproval = false

    /// Drives the manual "Scan…" results dialog. `scanFoundMissing` picks the found vs all-clear
    /// variant; the scan itself runs with `raiseLaunchPrompt: false` so this dialog — not the
    /// global launch prompt — presents the outcome.
    @State private var showScanResult = false
    @State private var scanFoundMissing = false

    /// Analytics consent (opt-out, default ON). Backed by the SHARED suite so helper bundles
    /// honour the same value — see AnalyticsService.
    @AppStorage(UserDefaultsKeys.analyticsEnabled, store: UserDefaults(suiteName: UserDefaultsKeys.sharedSuiteName))
    private var analyticsEnabled = true

    var body: some View {
        Form {
            // All general preferences live in a single grouped container (System Settings style):
            // Start at login → Software update → Share analytics.
            Section {
                startAtLoginRow

                softwareUpdateRow

                missingAppsRow

                analyticsRow
            }
        }
        .formStyle(.grouped)
        .navigationTitle(AppStrings.Settings.general)
        .onAppear(perform: refreshLoginState)
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
                let manager = LoginItemManager.shared
                let systemOn = manager.isEnabled || manager.requiresApproval
                guard enabled != systemOn else { return }
                applyLoginSetting(enabled)
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

    /// Manual update check (Sparkle). Sits between login and analytics. The trailing button
    /// disables itself while a check/install session is already running.
    private var softwareUpdateRow: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(AppStrings.Label.softwareUpdate)
                Text(AppStrings.Label.softwareUpdateDescription(AppEnvironment.appVersion))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(AppStrings.Button.checkForUpdates) {
                updateController.checkForUpdates()
            }
            .disabled(!updateController.canCheckForUpdates)
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

    /// Read the current SMAppService status into the toggle (system is source of truth).
    private func refreshLoginState() {
        let manager = LoginItemManager.shared
        // Show the toggle ON whenever the user wants it on — including when macOS is holding
        // the agent for approval (common right after a Sparkle update). Rendering it OFF there
        // would look like the setting silently reset itself.
        startAtLoginOn = manager.isEnabled || manager.requiresApproval
        loginRequiresApproval = manager.requiresApproval
    }

    /// Register/unregister the launcher agent to match the toggle. On failure, revert the
    /// toggle to the real system state so the UI never lies.
    private func applyLoginSetting(_ enabled: Bool) {
        AnalyticsService.shared.log(.settingChanged, ["setting": "start_at_login", "enabled": enabled])
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
