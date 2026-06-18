//
//  DockLockSettingsView.swift
//  DockTile
//
//  Dock Lock controls for the Settings window (⌘,). Pins the Dock to a chosen
//  display so it stops jumping between screens. Backed by DockLockManager
//  (CGEvent-tap engine + Accessibility permission).
//
//  Swift 6 - Strict Concurrency
//

import SwiftUI

struct DockLockSettingsView: View {
    @ObservedObject private var manager = DockLockManager.shared

    var body: some View {
        Form {
            Section {
                Toggle(isOn: $manager.isEnabled) {
                    Text(AppStrings.Settings.dockLockToggle)
                    Text(AppStrings.Settings.dockLockDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .onChange(of: manager.isEnabled) { _, enabled in
                    AnalyticsService.shared.log(.settingChanged, ["setting": "dock_lock", "enabled": enabled])
                }
            }

            // Accessibility permission status — only relevant once enabled.
            if manager.isEnabled {
                Section {
                    accessibilityRow
                }
            }

            // Anchor display + manual nudge
            Section {
                Picker(AppStrings.Settings.dockLockAnchor, selection: $manager.anchorDisplayID) {
                    ForEach(manager.displays) { display in
                        Text(displayLabel(display)).tag(display.id)
                    }
                }
                .disabled(!manager.isEnabled || !manager.isAccessibilityTrusted)

                Button(AppStrings.Settings.dockLockMoveDock) {
                    manager.moveDockToAnchor()
                }
                .disabled(!manager.isEnabled || !manager.isAccessibilityTrusted)
            } footer: {
                Text(AppStrings.Settings.dockLockNote)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 460)
        .fixedSize(horizontal: false, vertical: true)
        .navigationTitle(AppStrings.Settings.dockLock)
        // Re-check trust when the pane appears (covers the case where the user
        // granted access while this window was already open).
        .onAppear { manager.refreshTrust() }
    }

    @ViewBuilder
    private var accessibilityRow: some View {
        if manager.isAccessibilityTrusted {
            Label {
                Text(AppStrings.Settings.dockLockAccessibilityGranted)
            } icon: {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Label {
                    Text(AppStrings.Settings.dockLockAccessibilityNeeded)
                        .fontWeight(.medium)
                } icon: {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }

                Text(AppStrings.Settings.dockLockAccessibilityNeededDetail)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button(AppStrings.Settings.dockLockOpenSettings) {
                    manager.openAccessibilitySettings()
                }
            }
        }
    }

    private func displayLabel(_ display: DockLockManager.DisplayInfo) -> String {
        display.isMain
            ? "\(display.name) (\(AppStrings.Settings.dockLockMainDisplay))"
            : display.name
    }
}
