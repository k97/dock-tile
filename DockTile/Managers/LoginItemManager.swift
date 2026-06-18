//
//  LoginItemManager.swift
//  DockTile
//
//  Manages "Start tiles at login" via a single SMAppService launcher agent.
//
//  WHY THIS DESIGN: SMAppService can't register the external, ad-hoc-signed helper
//  bundles directly (it only manages items inside the main app bundle). So instead of
//  one LaunchAgent per tile (noisy in System Settings, attributed as "Unknown", and
//  prone to desync), we register ONE agent — a plist bundled at
//  Contents/Library/LaunchAgents/ — that runs the main app binary headless with
//  `--login-spawn-tiles` (see LoginTileSpawner) to warm every visible tile at login.
//
//  Result: a single, Developer-ID-attributed "Dock Tile" row in System Settings →
//  Login Items & Extensions, the Apple-recommended API, and `status` as the source of
//  truth (so the UI reflects what the user did in System Settings).
//
//  Swift 6 - Strict Concurrency
//

import Foundation
import ServiceManagement

@MainActor
final class LoginItemManager {
    static let shared = LoginItemManager()

    private init() {}

    /// The bundled launcher agent for this environment. `plistName` matches the file in
    /// Contents/Library/LaunchAgents/ — derived from the bundle ID so dev/release each
    /// pick their own plist (com.docktile.app… vs com.docktile.dev.app…).
    private var service: SMAppService {
        SMAppService.agent(plistName: "\(AppEnvironment.mainAppBundleId).tilelauncher.plist")
    }

    // MARK: - State (read from the system, never from local storage)

    var status: SMAppService.Status { service.status }

    var isEnabled: Bool { service.status == .enabled }

    /// True when macOS is holding the item for user approval in System Settings.
    var requiresApproval: Bool { service.status == .requiresApproval }

    // MARK: - Toggle

    /// Register the launcher agent so visible tiles warm at login.
    func enable() throws {
        cleanupLegacyPerTileAgents()
        try service.register()
        print("✅ LoginItem: launcher agent registered (status: \(statusDescription))")
    }

    /// Unregister the launcher agent.
    func disable() throws {
        try service.unregister()
        print("✅ LoginItem: launcher agent unregistered (status: \(statusDescription))")
    }

    /// Open System Settings → Login Items so the user can approve a held item.
    func openLoginItemsSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }

    // MARK: - Legacy cleanup

    /// Remove any leftover per-tile LaunchAgent plists written by the earlier approach
    /// (`~/Library/LaunchAgents/<helperPrefix>.<UUID>.plist`). This is unreleased work,
    /// so this only ever cleans up developer machines — but it keeps things tidy.
    private func cleanupLegacyPerTileAgents() {
        let dir = FileManager.default
            .urls(for: .libraryDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("LaunchAgents")
        let prefix = "\(AppEnvironment.helperBundlePrefix)."
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: nil
        ) else { return }

        for url in contents where url.pathExtension == "plist" {
            let name = url.deletingPathExtension().lastPathComponent
            // Match per-tile agents (com.docktile.<UUID>) but NOT the launcher agent.
            guard name.hasPrefix(prefix), !name.hasSuffix(".tilelauncher") else { continue }
            let target = "gui/\(getuid())/\(name)"
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/bin/launchctl")
            p.arguments = ["bootout", target]
            p.standardOutput = FileHandle.nullDevice
            p.standardError = FileHandle.nullDevice
            try? p.run(); p.waitUntilExit()
            try? FileManager.default.removeItem(at: url)
            print("🧹 LoginItem: removed legacy per-tile agent \(name)")
        }
    }

    private var statusDescription: String {
        switch service.status {
        case .notRegistered: return "notRegistered"
        case .enabled: return "enabled"
        case .requiresApproval: return "requiresApproval"
        case .notFound: return "notFound"
        @unknown default: return "unknown"
        }
    }
}
