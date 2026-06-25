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

                analyticsRow
            }
        }
        .formStyle(.grouped)
        .navigationTitle(AppStrings.Settings.general)
        .onAppear(perform: refreshLoginState)
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
