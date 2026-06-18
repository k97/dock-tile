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
            Section {
                Toggle(isOn: $startAtLoginOn) {
                    Text(AppStrings.Label.startAtLogin)
                    Text(AppStrings.Label.startAtLoginDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .onChange(of: startAtLoginOn) { _, enabled in
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

            // Privacy: opt-out analytics. Disabling stops all Analytics + Crashlytics collection.
            Section {
                Toggle(isOn: $analyticsEnabled) {
                    Text(AppStrings.Label.shareAnalytics)
                    Text(AppStrings.Label.shareAnalyticsDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .onChange(of: analyticsEnabled) { _, enabled in
                    AnalyticsService.shared.setConsent(enabled)
                    AnalyticsService.shared.log(.settingChanged, ["setting": "analytics", "enabled": enabled])
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 460)
        .fixedSize(horizontal: false, vertical: true)
        .navigationTitle(AppStrings.Settings.general)
        .onAppear(perform: refreshLoginState)
    }

    /// Read the current SMAppService status into the toggle (system is source of truth).
    private func refreshLoginState() {
        startAtLoginOn = LoginItemManager.shared.isEnabled
        loginRequiresApproval = LoginItemManager.shared.requiresApproval
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
