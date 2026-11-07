//
//  UpdateController.swift
//  DockTile
//
//  Manages Sparkle auto-updates for the main DockTile app only.
//  Helper bundles must never instantiate this class.
//

import AppKit
import Combine
import Sparkle

@MainActor
final class UpdateController: NSObject, ObservableObject {
    private let updaterController: SPUStandardUpdaterController
    private let delegate = UpdaterDelegate()
    private var canCheckObservation: AnyCancellable?

    /// Mirrors `SPUUpdater.canCheckForUpdates`. Published so a "Check for Updates" button can
    /// disable itself while a check/install session is already in flight (Sparkle's recommended
    /// pattern — observe the KVO-compliant property rather than reading it once).
    @Published private(set) var canCheckForUpdates = false

    override init() {
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: delegate,
            userDriverDelegate: nil
        )
        super.init()
        canCheckForUpdates = updaterController.updater.canCheckForUpdates
        canCheckObservation = updaterController.updater
            .publisher(for: \.canCheckForUpdates)
            .receive(on: RunLoop.main)
            .sink { [weak self] value in
                // Delivered on the main run loop above, so we are on the main actor here.
                MainActor.assumeIsolated { self?.canCheckForUpdates = value }
            }
        DiagnosticsLog.shared.log("update", "Updater started (canCheck=\(canCheckForUpdates))")
    }

    func checkForUpdates() {
        DiagnosticsLog.shared.log("update", "User requested 'Check for Updates'")
        updaterController.checkForUpdates(nil)
    }
}

// MARK: - Update analytics (pure mapping, guarded by UpdateAnalyticsTests)

/// Maps Sparkle callbacks to the `update_check` / `update_choice` analytics values. Added
/// 2026-10-18 to learn why most users stay on old versions: are checks running, are updates
/// found, and what do people do with the prompt.
enum UpdateAnalytics {
    /// `update_check` result for an aborted update cycle, or nil when the abort is Sparkle's
    /// routine "no update found" (SUNoUpdateError, 1001), which `updaterDidNotFindUpdate` has
    /// already counted as "none". A declined or deferred install authorization (4007 / 4008 —
    /// likely under silent installs when the app's folder needs an admin password) is "declined".
    nonisolated static func abortResult(for error: Error) -> String? {
        let ns = error as NSError
        guard ns.domain == SUSparkleErrorDomain else { return "error" }
        switch ns.code {
        case 1001: return nil
        case 4007, 4008: return "declined"
        default: return "error"
        }
    }

    nonisolated static func choiceValue(_ choice: SPUUserUpdateChoice) -> String {
        switch choice {
        case .install: return "install"
        case .skip: return "skip"
        case .dismiss: return "dismiss"
        @unknown default: return "unknown"
        }
    }
}

// MARK: - Install while idle (#13)

/// Sparkle installs a silently downloaded update when the app quits, and with the menu bar icon or
/// Dock Lock on Dock Tile rarely quits. So while it stays resident it installs once the user is away
/// (`IdleInstallTests`).
enum IdleInstall {
    nonisolated static let idleThreshold: TimeInterval = 600
    nonisolated static let quietRelaunchWindow: TimeInterval = 120

    /// Never while the window is on screen (a hidden quiet-launch window still exists, so `isVisible`),
    /// never mid-build or mid-Dock-restart, and only after ten minutes without any input.
    nonisolated static func shouldInstall(windowVisible: Bool, secondsSinceInput: TimeInterval, dockBusy: Bool) -> Bool {
        !windowVisible && !dockBusy && secondsSinceInput >= idleThreshold
    }

    /// The relaunch after an idle install starts quietly only if the flag was written moments ago.
    nonisolated static func isQuietRelaunch(flaggedAt: Date, now: Date) -> Bool {
        let age = now.timeIntervalSince(flaggedAt)
        return age >= 0 && age < quietRelaunchWindow
    }
}

/// Holds Sparkle's install handler and checks every 60 s, only while one is held. Holding it stalls
/// Sparkle's update cycle until it runs or the app quits.
@MainActor
final class IdleInstaller {
    static let shared = IdleInstaller()
    private var install: (() -> Void)?
    private var timer: Timer?

    func hold(_ install: @escaping () -> Void, version: String) {
        self.install = install
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
            MainActor.assumeIsolated { IdleInstaller.shared.check() }
        }
        DiagnosticsLog.shared.log("update", "Update \(version) waits for an idle moment to install")
    }

    private func check() {
        guard let install else { return }
        // Any input event (kCGAnyInputEventType); `.null` is event 0 and reads far older.
        let idle = CGEventType(rawValue: ~0).map {
            CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: $0)
        } ?? 0
        let windowVisible = NSApp.windows.contains {
            // A minimised window is in use too: the quiet relaunch would not bring it back.
            $0.identifier?.rawValue == AppDelegate.configurationWindowID && ($0.isVisible || $0.isMiniaturized)
        }
        let dockBusy = HelperBundleManager.shared.isAnyDockOperationInFlight
        guard IdleInstall.shouldInstall(windowVisible: windowVisible, secondsSinceInput: idle, dockBusy: dockBusy) else {
            DiagnosticsLog.shared.log("update", "Idle check: \(Int(idle)) s idle, window \(windowVisible), Dock busy \(dockBusy)", verbose: true)
            return
        }
        timer?.invalidate()
        timer = nil
        self.install = nil
        UserDefaults.standard.set(Date(), forKey: UserDefaultsKeys.relaunchQuietlyAt)
        DiagnosticsLog.shared.log("update", "Installing while idle after \(Int(idle)) s")
        install()
    }
}

// MARK: - Updater Delegate

private final class UpdaterDelegate: NSObject, SPUUpdaterDelegate {
    /// Sparkle's SPUUpdater is main-thread only and calls its delegate there, so the main-actor
    /// AnalyticsService can be reached synchronously (same pattern as the Quick Look controller).
    private func track(_ event: AnalyticsEvent, _ parameters: [String: Any] = [:]) {
        MainActor.assumeIsolated { AnalyticsService.shared.log(event, parameters) }
    }

    func updater(_ updater: SPUUpdater, didFinishLoading appcast: SUAppcast) {
        DiagnosticsLog.shared.log("update", "Loaded appcast (\(appcast.items.count) item(s))")
    }

    func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        // The download URL is the single most useful field for diagnosing a failed update —
        // a 404 / wrong host here is exactly what breaks "downloading the update".
        let url = item.fileURL?.absoluteString ?? "nil"
        DiagnosticsLog.shared.log("update", "Found update \(item.displayVersionString) — download URL: \(url)")
        track(.updateCheck, ["result": "found"])
    }

    func updaterDidNotFindUpdate(_ updater: SPUUpdater) {
        DiagnosticsLog.shared.log("update", "No update found (already up to date)")
        track(.updateCheck, ["result": "none"])
    }

    func updater(_ updater: SPUUpdater, userDidMake choice: SPUUserUpdateChoice,
                 forUpdate updateItem: SUAppcastItem, state: SPUUserUpdateState) {
        let value = UpdateAnalytics.choiceValue(choice)
        DiagnosticsLog.shared.log("update", "User chose '\(value)' for \(updateItem.displayVersionString)")
        track(.updateChoice, ["choice": value])
    }

    /// Resident (menu bar icon or Dock Lock): take the install and run it while the user is away.
    /// Otherwise NO, unchanged: Sparkle installs at the next quit.
    func updater(_ updater: SPUUpdater, willInstallUpdateOnQuit item: SUAppcastItem,
                 immediateInstallationBlock immediateInstallHandler: @escaping () -> Void) -> Bool {
        MainActor.assumeIsolated {
            guard AppDelegate.staysResident(dockLock: DockLockManager.shared.isEnabled,
                                            menuBar: MenuBarController.isEnabled) else { return false }
            IdleInstaller.shared.hold(immediateInstallHandler, version: item.displayVersionString)
            return true
        }
    }

    func updater(_ updater: SPUUpdater, willInstallUpdate item: SUAppcastItem) {
        DiagnosticsLog.shared.log("update", "Will install update \(item.displayVersionString)")
        track(.updateInstalling)
    }

    func updater(_ updater: SPUUpdater, didAbortWithError error: any Error) {
        let ns = error as NSError
        var detail = "\(ns.domain) code=\(ns.code): \(ns.localizedDescription)"
        if let underlying = ns.userInfo[NSUnderlyingErrorKey] as? NSError {
            detail += " | underlying: \(underlying.domain) code=\(underlying.code) \(underlying.localizedDescription)"
        }
        if let failingURL = ns.userInfo[NSURLErrorFailingURLStringErrorKey] as? String {
            detail += " | url: \(failingURL)"
        }
        DiagnosticsLog.shared.log("update", "Update aborted: \(detail)")
        if let result = UpdateAnalytics.abortResult(for: error) {
            track(.updateCheck, ["result": result])
        }

        #if DEBUG
        print("[Sparkle] Update aborted (expected in dev builds): \(error.localizedDescription)")
        #else
        print("[Sparkle] Update aborted: \(error.localizedDescription)")
        #endif
    }
}
