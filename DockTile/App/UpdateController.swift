//
//  UpdateController.swift
//  DockTile
//
//  Manages Sparkle auto-updates for the main DockTile app only.
//  Helper bundles must never instantiate this class.
//

import Foundation
import Sparkle

@MainActor
final class UpdateController: NSObject, ObservableObject {
    private let updaterController: SPUStandardUpdaterController
    private let delegate = UpdaterDelegate()

    var canCheckForUpdates: Bool {
        updaterController.updater.canCheckForUpdates
    }

    override init() {
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: delegate,
            userDriverDelegate: nil
        )
        super.init()
        DiagnosticsLog.shared.log("update", "Updater started (canCheck=\(updaterController.updater.canCheckForUpdates))")
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
