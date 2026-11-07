//
//  AppDelegate.swift
//  DockTile
//
//  Main application delegate for Dock integration and lifecycle management
//  Swift 6 - Strict Concurrency
//

import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    // Configuration manager (set by DockTileApp on launch)
    var configManager: ConfigurationManager? {
        didSet {
            guard let url = pendingDeepLink else { return }
            pendingDeepLink = nil
            handleDeepLink(url)
        }
    }

    /// A deep link that arrived before `configManager` existed: a cold launch can deliver the URL
    /// before the window's `onAppear` hands the manager over. Replayed when it is set.
    private var pendingDeepLink: URL?

    /// Scene identifier for the single main configuration `Window` (shared with `DockTileApp`
    /// and stamped onto the `NSWindow` by `WindowAccessor` so we can find it again).
    /// `nonisolated` so the pure `shouldReuseConfigurationWindow` seam can read it off the actor.
    nonisolated static let configurationWindowID = "com.docktile.configuration"

    /// Posted by a second launch that lost the main-app lock (`main.swift`), so this copy shows its
    /// window (#13). Asking Launch Services to open this app from that process reopened the caller
    /// itself, and nothing appeared (2026-11-07). Per environment, so dev and release never cross.
    nonisolated static let showWindowRequest = Notification.Name("\(AppEnvironment.mainAppBundleId).showWindow")

    /// SwiftUI's `openWindow` action, captured by the scene. Used to recreate the configuration
    /// window when it has been fully closed while the app stayed resident (e.g. Dock Lock on).
    var openConfigurationWindow: (() -> Void)?

    /// The main app's delegate, for `WindowAccessor` to install as every configuration window's
    /// delegate (`windowWillResize` enforces the open minimum). `NSApp.delegate` is SwiftUI's adaptor
    /// proxy, not this object. Set in `applicationDidFinishLaunching` on the main-app path only.
    @MainActor static weak var instance: AppDelegate?

    // Window width range: horizontally resizable, height unbounded
    nonisolated static let minWindowWidth: CGFloat = 700
    nonisolated static let maxWindowWidth: CGFloat = 1200
    /// Width of the trailing Customise inspector; the open minimum is this much wider.
    nonisolated static let inspectorWidth: CGFloat = 260
    /// The sidebar column's range (`DockTileConfigurationView`).
    nonisolated static let sidebarMinWidth: CGFloat = 220
    nonisolated static let sidebarMaxWidth: CGFloat = 280
    /// The minimum Tile Detail reports to the split view, deliberately below its content's own
    /// (274 pt: the hero row with its labels squeezed to nothing). With the inspector open AppKit
    /// counts the inspector twice in the split view's minimum (sidebar + detail + 2 × 260, measured
    /// 2026-10-20), so the content's own minimum asked for 1022 pt, more than the 988 open minimum:
    /// the inspector was clipped off the right edge and AppKit's update-constraints pass threw.
    /// The content's real room comes from the window minimums instead: at least 420 pt wide
    /// (700 − 280, or 960 − 280 − 260), which holds the 406 pt hero row. `MainWindowWidthTests`.
    nonisolated static let detailColumnMinWidth: CGFloat = 150

    /// Pure clamp into the allowed window width range (shared by every width fix-up site).
    /// With the inspector open the minimum is `minWindowWidth + inspectorWidth`.
    nonisolated static func clampedWindowWidth(_ width: CGFloat, inspectorShown: Bool) -> CGFloat {
        let minimum = inspectorShown ? minWindowWidth + inspectorWidth : minWindowWidth
        return min(max(width, minimum), maxWindowWidth)
    }

    /// Frame after opening/closing the inspector (AppKit coordinates). Height and y never change.
    /// The window keeps its width, as Xcode does: the detail column absorbs the inspector. Opening
    /// grows only a window narrower than the open minimum (960), to exactly that, keeping the
    /// leading edge, capped to the screen, then shifted to stay inside `visibleFrame`. Closing never
    /// changes the frame.
    nonisolated static func windowFrame(forInspectorShown shown: Bool, from frame: CGRect, visibleFrame: CGRect) -> CGRect {
        guard shown else { return frame }
        var result = frame
        let width = min(clampedWindowWidth(frame.width, inspectorShown: true), visibleFrame.width)
        guard width != frame.width else { return frame }
        result.size.width = width
        if result.maxX > visibleFrame.maxX { result.origin.x = visibleFrame.maxX - width }
        if result.minX < visibleFrame.minX { result.origin.x = visibleFrame.minX }
        return result
    }

    private static let minWindowHeight: CGFloat = 500

    // MARK: - Application Lifecycle

    /// A quiet launch (#13) drops the Dock icon only while the menu bar icon is there instead: a Dock
    /// Lock-only user's quiet Dock Tile keeps its Dock icon, or nothing would show it is running.
    private var quietLaunchHidesDockIcon: Bool { AppEnvironment.isQuietLaunch && MenuBarController.isEnabled }

    func applicationWillFinishLaunching(_ notification: Notification) {
        // Set before any Dock icon can draw, as helpers do.
        if quietLaunchHidesDockIcon { NSApp.setActivationPolicy(.accessory) }

        // A second launch asks for the window instead of running beside us (main-app lock). Listening
        // from the very start: at login the losing copy can ask while this one is still launching, and
        // a distributed notification posted before the observer exists is dropped. Delivery on `.main`
        // waits for the run loop, so it still lands after `didFinishLaunching`.
        guard !AppEnvironment.isRunningTests else { return }
        DistributedNotificationCenter.default().addObserver(forName: Self.showWindowRequest, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { AppDelegate.instance?.showWindowForSecondLaunch() }
        }
    }

    /// A background app's `activate` is refused on macOS 14+, so the window opened behind the frontmost
    /// app — which looked like nothing happened (measured 2026-11-07). `orderFrontRegardless` raises it
    /// anyway; the next turn covers a window SwiftUI is recreating. Any local process can post the
    /// request; the worst it can do is open this window.
    private func showWindowForSecondLaunch() {
        DiagnosticsLog.shared.ui("Second launch → show window")
        showConfigurationWindow()
        DispatchQueue.main.async {
            NSApp.windows.first { $0.identifier?.rawValue == Self.configurationWindowID }?.orderFrontRegardless()
        }
    }

    /// A quiet launch still creates the scene's window, so its `onAppear` hands over the manager and
    /// `openWindow` and its `.task` runs launch maintenance. SwiftUI has ordered it in by
    /// `didFinishLaunching` (with and without a window to restore) but not drawn it yet: hiding it
    /// here showed no frame in a 2 ms window-server probe (2026-11-06). Shown again at full alpha by
    /// `showConfigurationWindow`.
    private func hideQuietLaunchWindow() {
        guard AppEnvironment.isQuietLaunch else { return }
        guard let window = NSApp.windows.first(where: { $0.contentViewController != nil }) else {
            DiagnosticsLog.shared.log("lifecycle", "Quiet launch: no window at didFinishLaunching to hide")
            return
        }
        window.alphaValue = 0
        window.orderOut(nil)
        DiagnosticsLog.shared.log("lifecycle", "Quiet launch: window hidden", verbose: true)
    }

    // Main app only: `main.swift` gives a helper bundle `HelperAppDelegate` instead (`AppEnvironment.isHelper`).
    func applicationDidFinishLaunching(_ notification: Notification) {
        print(AppStrings.Log.launching)
        print("   Bundle ID: \(AppEnvironment.mainAppBundleId)")

        Self.instance = self
        DiagnosticsLog.shared.log("lifecycle", "didFinishLaunching", verbose: true)
        hideQuietLaunchWindow()
        configureAsMainApp()

        print(AppStrings.Log.ready)
    }

    private func configureAsMainApp() {
        // Main app: Use regular mode to show dock icon (not on a quiet launch to the menu bar)
        if !quietLaunchHidesDockIcon { NSApp.setActivationPolicy(.regular) }

        // Under a test host the app launches against the user's LIVE dev data. Stay inert — none of
        // the launch side effects below (Dock Lock tap, login-item registration, Smart Add
        // observing, /Applications relocation nudge) should run, or a `xcodebuild test` mutates real
        // state. Helper migration (which once corrupted a tile mid-generation) is likewise gated at
        // its own call sites. See AppEnvironment.isRunningTests.
        guard !AppEnvironment.isRunningTests else {
            print("🧪 Running under test host — skipping main-app launch side effects")
            return
        }

        // Dock Lock: resume the dock-pinning engine if it was previously enabled.
        // Controls live in the main window's Dock Lock settings pane.
        DockLockManager.shared.startIfEnabled()

        // Live icon-style tracking for the window's previews: a read-only KVO subscription that
        // republishes the raw token the instant the key changes, even while backgrounded —
        // matching how System Settings reacts. Display only; the Tahoe detection quarantine is
        // untouched. Main app only — helpers rebuild their popover content on every show().
        IconStyleManager.shared.startDisplayObservation()

        // Recovery for the one gap KVO can't cover (a change made while the machine slept, with
        // no observer running to hear it): re-read the token on every foreground activation.
        NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { _ in
            // The closure is @Sendable-typed and does NOT inherit this @MainActor context, so a
            // synchronous call here is a cross-actor call (mirrors DefaultsKeyObserver.observeValue
            // in IconStyleManager.swift, which hops the same way for the same reason).
            Task { @MainActor in
                IconStyleManager.shared.refreshRawStyle()
            }
        }

        // Start-at-login is ON by default (opt-out). Enable it on launch for new users and
        // re-assert it after a Sparkle update demotes the SMAppService agent — unless the user
        // explicitly turned it off in Settings.
        LoginItemManager.shared.reconcileOnLaunch()

        // Smart Add: begin building the on-device app-usage signal (launch history + Spotlight).
        // Main app only; stays entirely on device (independent of the analytics toggle).
        SmartAddEngine.shared.startObserving()

        // Configure window sizing after a brief delay to ensure window exists
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [self] in
            configureMainWindowSizing()

            // A quiet launch at login shows no alert; both wait for the next time the user opens Dock Tile.
            guard !AppEnvironment.isQuietLaunch else { return }

            // Nudge to /Applications if the app is translocated or running from Downloads etc.,
            // where it can't copy itself to build helper tiles. Deferred so a window exists to sit
            // the prompt above. Main-app only, suppressible, and skipped when already installed.
            AppRelocationManager.shared.checkOnLaunch()

            // Invite native speakers to review a machine-first translation: one alert, once, only
            // when the UI runs in a non-English localization. After the relocation nudge on purpose.
            TranslationInviteManager.shared.checkOnLaunch()
        }

        // Check if first launch
        let hasLaunchedBefore = UserDefaults.standard.bool(forKey: "HasLaunchedBefore")

        // Menu bar icon (#13): seeded once, before HasLaunchedBefore is written — ON for a new
        // install, OFF for an existing user.
        if UserDefaults.standard.object(forKey: UserDefaultsKeys.menuBarEnabled) == nil {
            UserDefaults.standard.set(MenuBarController.initialEnabled(hasLaunchedBefore: hasLaunchedBefore),
                                      forKey: UserDefaultsKeys.menuBarEnabled)
        }
        MenuBarController.shared.apply(enabled: MenuBarController.isEnabled)

        if !hasLaunchedBefore {
            print("🎉 First launch detected - showing configuration window")
            UserDefaults.standard.set(true, forKey: "HasLaunchedBefore")
            showConfigurationWindow()
        } else {
            print("✓ Main app ready - dock icon visible")
        }
    }

    /// Configure window size constraints at the AppKit level
    private func configureMainWindowSizing() {
        guard let window = NSApp.windows.first(where: { $0.contentViewController != nil }) else {
            return
        }

        // Bound horizontal size to the allowed range, allow vertical resize
        let inspectorShown = UserDefaults.standard.bool(forKey: UserDefaultsKeys.inspectorShown)
        window.contentMinSize = NSSize(width: Self.clampedWindowWidth(0, inspectorShown: inspectorShown), height: Self.minWindowHeight)
        window.contentMaxSize = NSSize(width: Self.maxWindowWidth, height: CGFloat.greatestFiniteMagnitude)
        // The restored frame is fixed once, by WindowAccessor (it runs first, on every window creation).

        print("✓ Window sizing configured: \(Self.minWindowWidth)…\(Self.maxWindowWidth)x\(Self.minWindowHeight)+")
    }

    /// The ONE place that moves the frame for an inspector change. Closing only lowers the minimum
    /// (the frame never changes — shrinking while the inspector collapsed also crashed AppKit's
    /// constraint pass). Opening grows a too-narrow window FIRST and raises the minimum after, so the
    /// frame change is never below the current minimum.
    /// `static`: SwiftUI's `NSApplicationDelegateAdaptor` installs its own proxy as `NSApp.delegate`,
    /// so `NSApp.delegate as? AppDelegate` is nil and an instance call never ran.
    static func resizeConfigurationWindow(forInspectorShown shown: Bool) {
        guard let window = NSApp.windows.first(where: { $0.identifier?.rawValue == Self.configurationWindowID }),
              let screen = window.screen ?? NSScreen.main else { return }
        let minimum = NSSize(width: Self.clampedWindowWidth(0, inspectorShown: shown), height: Self.minWindowHeight)
        let target = Self.windowFrame(forInspectorShown: shown, from: window.frame, visibleFrame: screen.visibleFrame)
        if target != window.frame {
            window.setFrame(target, display: true, animate: !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion)
        }
        window.contentMinSize = minimum
    }

    // MARK: - NSWindowDelegate

    /// With the menu bar icon on, Dock Tile's own Dock icon shows only while its window is open (#13).
    /// Only the configuration window has this delegate (`WindowAccessor`).
    func windowWillClose(_ notification: Notification) {
        guard MenuBarController.isEnabled else { return }
        NSApp.setActivationPolicy(.accessory)
    }

    func windowWillResize(_ sender: NSWindow, to frameSize: NSSize) -> NSSize {
        // Clamp width into the allowed range during resize
        let inspectorShown = UserDefaults.standard.bool(forKey: UserDefaultsKeys.inspectorShown)
        return NSSize(width: Self.clampedWindowWidth(frameSize.width, inspectorShown: inspectorShown), height: max(frameSize.height, Self.minWindowHeight))
    }

    /// Reopen decision for the single main configuration window (Dock-icon click /
    /// `docktile://configure` deep link / Spotlight / Mission Control all funnel here).
    ///
    /// Returns `true` when a configuration window is already on screen and can be brought to the
    /// front; `false` when none is open and SwiftUI must recreate it. Guards the duplicate-window
    /// regression: with `WindowGroup` + a title-based heuristic, every reopen spawned a *fresh*
    /// window in the same process. A single `Window` keyed off `configurationWindowID` means we
    /// reuse whenever that identifier is already present.
    nonisolated static func shouldReuseConfigurationWindow(openWindowIdentifiers identifiers: [String?]) -> Bool {
        identifiers.contains(configurationWindowID)
    }

    /// Brings the single configuration window up (reusing it when it's open, recreating it when the
    /// user has closed it). Internal, not private: the app menu's About / Settings commands call it
    /// so their pane notification has a window to land in — with Dock Lock on, the app stays
    /// resident with no window, and posting alone did nothing (nobody was observing).
    func showConfigurationWindow() {
        // The window brings the Dock icon back while the menu bar icon has it hidden (#13).
        if NSApp.activationPolicy() != .regular { NSApp.setActivationPolicy(.regular) }
        // Activate app and show configuration window
        NSApp.activate(ignoringOtherApps: true)

        // With a single `Window` scene there is at most one configuration window. Reuse it if
        // it's open; otherwise ask SwiftUI to recreate it (it may have been closed while the app
        // stayed resident for Dock Lock or the menu bar icon). The reuse rule lives in the testable seam above.
        let identifiers = NSApp.windows.map { $0.identifier?.rawValue }
        if Self.shouldReuseConfigurationWindow(openWindowIdentifiers: identifiers) {
            let window = NSApp.windows.first { $0.identifier?.rawValue == Self.configurationWindowID }
            window?.alphaValue = 1  // a quiet launch hid it at 0
            window?.makeKeyAndOrderFront(nil)
        } else {
            openConfigurationWindow?()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        print(AppStrings.Log.terminating)
    }

    // MARK: - URL Handling (Deep Linking)

    /// Handle URLs like: docktile://configure?bundleId=com.docktile.XXXXX
    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            handleDeepLink(url)
        }
    }

    private func handleDeepLink(_ url: URL) {
        print("🔗 Handling deep link: \(url)")
        DiagnosticsLog.shared.log("deeplink", "Received \(url.absoluteString)")

        guard url.scheme == "docktile" else {
            print("   ⚠️ Unknown URL scheme: \(url.scheme ?? "nil")")
            return
        }

        // Parse URL: docktile://configure?bundleId=XXX or docktile://configure?id=XXX
        guard url.host == "configure" else {
            print("   ⚠️ Unknown URL host: \(url.host ?? "nil")")
            return
        }

        // Parse query parameters
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else {
            print("   ⚠️ No query parameters found")
            return
        }

        guard let configManager else {
            // The launching window presents itself; the link replays once the manager arrives.
            pendingDeepLink = url
            return
        }

        let selected: Bool
        // Try bundleId first (from helper context menu)
        if let bundleId = queryItems.first(where: { $0.name == "bundleId" })?.value {
            print("   📦 Selecting config by bundle ID: \(bundleId)")
            selected = configManager.selectConfiguration(bundleId: bundleId)
        } else if let idString = queryItems.first(where: { $0.name == "id" })?.value,
                  let id = UUID(uuidString: idString) {
            // Try config ID (UUID)
            print("   🆔 Selecting config by ID: \(idString)")
            selected = configManager.selectConfiguration(id: id)
        } else {
            print("   ⚠️ No valid config identifier in URL")
            return
        }

        showConfigurationWindow()
        // Selecting alone is not enough: a Settings pane keeps `selectedConfigId` on the last tile,
        // so configuring that tile changed nothing and the pane stayed up (issue #31). Post on the
        // next turn so a just-recreated window's view is subscribed (as `openSettingsPane` does).
        if selected, let id = configManager.selectedConfigId {
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .revealTile, object: id)
            }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        !Self.staysResident(dockLock: DockLockManager.shared.isEnabled, menuBar: MenuBarController.isEnabled)
    }

    /// Keeps running with the window closed while Dock Lock's event tap or the menu bar icon needs
    /// the process (`MenuBarDefaultTests`).
    nonisolated static func staysResident(dockLock: Bool, menuBar: Bool) -> Bool {
        dockLock || menuBar
    }

    // MARK: - Dock Icon Click Handler

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        print("🖱️ Dock icon clicked (hasVisibleWindows: \(flag))")
        showConfigurationWindow()
        return true
    }

    // MARK: - Context Menu (Right-Click)

    /// Every tile with a submenu of its apps (`TileMenu`, shared with the menu bar icon). It used to
    /// list only the sidebar's selected tile, flat and unnamed.
    func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: AppStrings.Menu.openDockTile, action: #selector(openConfigurator), keyEquivalent: ""))

        let tiles = DiagnosticsLog.shared.measure("Build Dock menu", category: "menu") {
            TileMenu.tileItems(for: configManager?.configurations ?? [], target: self,
                               launch: #selector(launchApp(_:)), configure: #selector(configureTile(_:)))
        }
        if !tiles.isEmpty {
            menu.addItem(.separator())
            tiles.forEach(menu.addItem)
        }
        return menu
    }

    @objc private func openConfigurator() {
        NSApp.activate(ignoringOtherApps: true)
        showConfigurationWindow()
    }

    /// The popover's launch path, so folders open and a web app sharing a bundle id opens the copy
    /// the tile holds — resolving the bundle id here did neither (2026-11-04 audit).
    @objc private func launchApp(_ sender: NSMenuItem) {
        guard let appItem = sender.representedObject as? AppItem else { return }
        AppLauncher.launch(appItem, source: "main_dock_menu")
    }

    @objc private func configureTile(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? UUID else { return }
        revealTile(id: id)
    }

    /// "Configure Tile…" in the Dock and menu bar menus: the same path as a tile's gear link
    /// (select, show, reveal with Customise).
    func revealTile(id: UUID) {
        guard let url = URL(string: "docktile://configure?id=\(id.uuidString)") else { return }
        handleDeepLink(url)
    }
}
