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
    }

    func checkForUpdates() {
        updaterController.checkForUpdates(nil)
    }
}

// MARK: - Updater Delegate

private final class UpdaterDelegate: NSObject, SPUUpdaterDelegate {
    func updater(_ updater: SPUUpdater, didAbortWithError error: any Error) {
        #if DEBUG
        print("[Sparkle] Update check error (expected in dev builds): \(error.localizedDescription)")
        #else
        print("[Sparkle] Update check error: \(error.localizedDescription)")
        #endif
    }
}
