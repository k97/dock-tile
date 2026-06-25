//
//  UpdateController.swift
//  DockTile
//
//  Manages Sparkle auto-updates for the main DockTile app only.
//  Helper bundles must never instantiate this class.
//

import Foundation
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

// MARK: - Updater Delegate

private final class UpdaterDelegate: NSObject, SPUUpdaterDelegate {
    func updater(_ updater: SPUUpdater, didFinishLoading appcast: SUAppcast) {
        DiagnosticsLog.shared.log("update", "Loaded appcast (\(appcast.items.count) item(s))")
    }

    func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        // The download URL is the single most useful field for diagnosing a failed update —
        // a 404 / wrong host here is exactly what breaks "downloading the update".
        let url = item.fileURL?.absoluteString ?? "nil"
        DiagnosticsLog.shared.log("update", "Found update \(item.displayVersionString) — download URL: \(url)")
    }

    func updaterDidNotFindUpdate(_ updater: SPUUpdater) {
        DiagnosticsLog.shared.log("update", "No update found (already up to date)")
    }

    func updater(_ updater: SPUUpdater, willInstallUpdate item: SUAppcastItem) {
        DiagnosticsLog.shared.log("update", "Will install update \(item.displayVersionString)")
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

        #if DEBUG
        print("[Sparkle] Update aborted (expected in dev builds): \(error.localizedDescription)")
        #else
        print("[Sparkle] Update aborted: \(error.localizedDescription)")
        #endif
    }
}
