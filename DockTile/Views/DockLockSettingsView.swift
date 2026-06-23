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

    /// Drives the Accessibility permission primer sheet. The system permission dialog is only
    /// ever triggered from inside that sheet — never automatically.
    @State private var showingPrimer = false

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
                    DiagnosticsLog.shared.log("docklock", "Dock Lock toggled \(enabled ? "ON" : "OFF")")
                    // Turning the feature on without permission: explain first, prompt later.
                    if enabled && !manager.isAccessibilityTrusted {
                        showingPrimer = true
                    }
                }
            }

            // Gentle inline state while permission is missing (the sheet may have been dismissed).
            // No system dialog fires from here — the button just reopens the primer.
            if manager.isEnabled && !manager.isAccessibilityTrusted {
                Section {
                    permissionNeededRow
                }
            }

            // Anchor display picker — selecting a display moves the Dock there in real time.
            // Only meaningful once the lock is on and Accessibility is granted.
            if manager.isEnabled && manager.isAccessibilityTrusted {
                if manager.isMultiDisplay {
                    Section {
                        Picker(AppStrings.Settings.dockLockAnchor, selection: anchorSelection) {
                            Text(AppStrings.Settings.dockLockDefaultDisplay).tag(CGDirectDisplayID(0))
                            ForEach(manager.displays) { display in
                                Text(displayLabel(display)).tag(display.id)
                            }
                        }

                        moveStatusRow
                    } footer: {
                        Text(AppStrings.Settings.dockLockNote)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Section {
                        Label {
                            Text(AppStrings.Settings.dockLockSingleDisplay)
                        } icon: {
                            Image(systemName: "display")
                                .foregroundStyle(.secondary)
                        }
                        .font(.caption)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 460)
        .fixedSize(horizontal: false, vertical: true)
        .navigationTitle(AppStrings.Settings.dockLock)
        // Re-check trust when the pane appears (covers the case where the user
        // granted access while this window was already open).
        .onAppear { manager.refreshTrust() }
        // Dismiss the primer the moment access is granted.
        .onChange(of: manager.isAccessibilityTrusted) { _, trusted in
            if trusted { showingPrimer = false }
        }
        .sheet(isPresented: $showingPrimer) {
            DockLockPermissionPrimer(
                onContinue: { manager.requestAccessibility() },
                onCancel: {
                    showingPrimer = false
                    manager.isEnabled = false
                }
            )
        }
    }

    /// Live feedback for the relocation: spinner while moving, a green lock on success, and a
    /// red warning with a retry button if the Dock didn't land where it was asked to.
    @ViewBuilder
    private var moveStatusRow: some View {
        switch manager.moveState {
        case .moving(let name):
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text(AppStrings.Settings.dockLockMoving(name))
            }
            .font(.caption)
            .foregroundStyle(.secondary)

        case .succeeded(let name):
            Label {
                Text(AppStrings.Settings.dockLockLockedTo(name))
            } icon: {
                Image(systemName: "lock.fill")
                    .foregroundStyle(.green)
            }
            .font(.caption)

        case .failed(let name):
            VStack(alignment: .leading, spacing: 8) {
                Label {
                    Text(AppStrings.Settings.dockLockMoveFailed(name))
                } icon: {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                }
                .font(.caption)

                Button(AppStrings.Settings.dockLockRetry) {
                    manager.retryMove()
                }
            }

        case .idle:
            // Anchor chosen but no move in flight (e.g. Default) — fall back to a static label.
            if let anchor = manager.anchorDisplay {
                Label {
                    Text(AppStrings.Settings.dockLockLockedTo(displayLabel(anchor)))
                } icon: {
                    Image(systemName: "lock.fill")
                        .foregroundStyle(.green)
                }
                .font(.caption)
            }
        }
    }

    /// Shown inline while the lock is on but permission is missing. Re-opens the primer rather
    /// than firing the system dialog directly, and offers the System Settings deep link as a
    /// fallback for when the one-shot native prompt has already been shown.
    @ViewBuilder
    private var permissionNeededRow: some View {
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

            HStack {
                Button(AppStrings.Settings.dockLockPrimerContinue) {
                    showingPrimer = true
                }
                Button(AppStrings.Settings.dockLockOpenSettings) {
                    manager.openAccessibilitySettings()
                }
            }
        }
    }

    /// Routes picker changes through `selectAnchor`, which persists the choice and moves the
    /// Dock onto the selected display immediately.
    private var anchorSelection: Binding<CGDirectDisplayID> {
        Binding(
            get: { manager.anchorDisplayID },
            set: { manager.selectAnchor($0) }
        )
    }

    private func displayLabel(_ display: DockLockManager.DisplayInfo) -> String {
        display.isMain
            ? "\(display.name) (\(AppStrings.Settings.dockLockMainDisplay))"
            : display.name
    }
}

/// A macOS-style permission primer: explains *why* Dock Lock needs Accessibility before the
/// system dialog appears, so the request never feels like it came out of nowhere. "Continue"
/// triggers the native prompt; "Not Now" backs out and turns the feature off.
private struct DockLockPermissionPrimer: View {
    let onContinue: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.accentColor, Color.accentColor.opacity(0.65)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 68, height: 68)
                Image(systemName: "accessibility")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .shadow(color: Color.accentColor.opacity(0.35), radius: 10, y: 4)
            .padding(.top, 4)

            Text(AppStrings.Settings.dockLockPrimerTitle)
                .font(.title2)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)

            Text(AppStrings.Settings.dockLockPrimerBody)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Label(AppStrings.Settings.dockLockPrimerReassurance, systemImage: "info.circle")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.leading)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.secondary.opacity(0.1))
                )

            HStack(spacing: 12) {
                Button(AppStrings.Settings.dockLockPrimerNotNow, action: onCancel)
                    .keyboardShortcut(.cancelAction)

                Button(AppStrings.Settings.dockLockPrimerContinue, action: onContinue)
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
            }
            .padding(.top, 4)
        }
        .padding(28)
        .frame(width: 400)
    }
}
