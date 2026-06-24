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

    // MARK: - Persisted choice (opt-out, ON by default)

    /// Whether the user has explicitly turned start-at-login OFF. Persisted locally so it survives
    /// bundle replacement — a Sparkle update can demote the SMAppService agent, and SMAppService's
    /// `status` alone can't tell "user turned it off" from "macOS dropped it". Default false → the
    /// feature is ON by default; `reconcileOnLaunch` enables it unless the user opted out.
    var userOptedOut: Bool {
        get { UserDefaults.standard.bool(forKey: UserDefaultsKeys.startAtLoginOptedOut) }
        set { UserDefaults.standard.set(newValue, forKey: UserDefaultsKeys.startAtLoginOptedOut) }
    }

    /// Whether start-at-login should be active given the user's choice (ON unless opted out).
    var shouldBeEnabled: Bool { !userOptedOut }

    /// Pure decision seam for `reconcileOnLaunch`: re-register the agent only when the user has
    /// NOT opted out AND the system isn't already `.enabled`. This is what re-asserts the agent
    /// after a Sparkle update demotes it to `.requiresApproval`/`.notRegistered`, while honouring
    /// a genuine opt-out. Extracted so the Sparkle-update scenario is unit-testable without
    /// SMAppService. See rules/login-items.md "Reconcile on launch (Sparkle fix)".
    nonisolated static func shouldReregisterOnLaunch(
        userOptedOut: Bool,
        status: SMAppService.Status
    ) -> Bool {
        !userOptedOut && status != .enabled
    }

    // MARK: - Toggle

    /// Register the launcher agent so visible tiles warm at login. Clears the opt-out flag.
    func enable() throws {
        cleanupLegacyPerTileAgents()
        try service.register()
        userOptedOut = false
        print("✅ LoginItem: launcher agent registered (status: \(statusDescription))")
        DiagnosticsLog.shared.log("login", "Start-at-login enabled — registered (status: \(statusDescription))")
    }

    /// Unregister the launcher agent and record the user's opt-out so we don't re-enable it.
    func disable() throws {
        try service.unregister()
        userOptedOut = true
        print("✅ LoginItem: launcher agent unregistered (status: \(statusDescription))")
        DiagnosticsLog.shared.log("login", "Start-at-login disabled — unregistered (status: \(statusDescription))")
    }

    /// Bring the registration in line with the user's choice on app launch. Because start-at-login
    /// is ON by default (opt-out), this enables it for new users AND re-asserts it after a Sparkle
    /// update demotes the agent — unless the user explicitly turned it off. No-op when already
    /// enabled. If macOS insists on re-approval the status stays `.requiresApproval` and the
    /// Settings pane surfaces the approval prompt — we never silently fail or lie about the state.
    func reconcileOnLaunch() {
        guard Self.shouldReregisterOnLaunch(userOptedOut: userOptedOut, status: service.status) else { return }
        do {
            try service.register()
            print("🔁 LoginItem: reconciled on launch → \(statusDescription)")
            DiagnosticsLog.shared.log("login", "Reconciled on launch → \(statusDescription)")
        } catch {
            print("⚠️ LoginItem: reconcile register failed: \(error.localizedDescription)")
            DiagnosticsLog.shared.log("login", "Reconcile register FAILED: \(error.localizedDescription)")
        }
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
