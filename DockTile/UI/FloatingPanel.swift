//
//  FloatingPanel.swift
//  DockTile
//
//  NSPopover-based launcher for Dock icon
//  Uses native macOS popover with arrow pointing to dock
//  Swift 6 - Strict Concurrency
//

import AppKit
import SwiftUI

// MARK: - Dock Preferences Snapshot

/// Snapshot of the `com.apple.dock` settings that drive popover anchoring. Read fresh on
/// every popover open (`read()`, synchronize-first) so a settings change between opens —
/// magnification slider, orientation, autohide — is always honoured. Uses the shared
/// `DockEdge` (DockLockManager.swift); orientation comes from the pref, NOT from
/// visibleFrame-gap inference, because an auto-hidden Dock reserves no gap at all.
struct DockPrefs: Equatable {
    var orientation: DockEdge
    var magnificationEnabled: Bool
    var tileSize: CGFloat
    var largeSize: CGFloat
    var autohide: Bool

    /// Pure parser seam: applies macOS defaults for absent keys and clamps out-of-range
    /// values (`defaults write` accepts largesize up to 512; garbage never reaches geometry).
    nonisolated static func resolve(
        orientation: String?,
        magnification: Bool?,
        tileSize: Double?,
        largeSize: Double?,
        autohide: Bool?
    ) -> DockPrefs {
        let edge: DockEdge
        switch orientation {
        case "left": edge = .left
        case "right": edge = .right
        default: edge = .bottom
        }
        return DockPrefs(
            orientation: edge,
            magnificationEnabled: magnification ?? false,
            tileSize: CGFloat(min(max(tileSize ?? 48, 16), 128)),
            largeSize: CGFloat(min(max(largeSize ?? 128, 16), 512)),
            autohide: autohide ?? false
        )
    }

    /// Live read of another app's domain: synchronize first — cfprefsd can serve a stale
    /// cache (same lesson as the migration pipeline's Dock reads).
    static func read() -> DockPrefs {
        let domain = "com.apple.dock" as CFString
        CFPreferencesAppSynchronize(domain)
        func number(_ key: String) -> Double? {
            (CFPreferencesCopyAppValue(key as CFString, domain) as? NSNumber)?.doubleValue
        }
        func bool(_ key: String) -> Bool? {
            (CFPreferencesCopyAppValue(key as CFString, domain) as? NSNumber)?.boolValue
        }
        return resolve(
            orientation: CFPreferencesCopyAppValue("orientation" as CFString, domain) as? String,
            magnification: bool("magnification"),
            tileSize: number("tilesize"),
            largeSize: number("largesize"),
            autohide: bool("autohide")
        )
    }
}

// MARK: - Panel State

/// Explicit lifecycle state for the popover. Replaces reliance on `NSPopover.isShown`,
/// which is unreliable mid-animation and races with the async `popoverDidClose` cleanup.
/// Gating show/hide on this state prevents rapid Dock clicks from stacking multiple
/// show/close animations (the "flicker" bug after a cold launch).
enum PanelState {
    case hidden
    case showing
    case shown
    case hiding
}

@MainActor
final class FloatingPanel: NSObject, NSPopoverDelegate {

    // MARK: - Properties

    private var popover: NSPopover?
    private var anchorWindow: NSWindow?
    private var dismissObserver: NSObjectProtocol?
    private var clickOutsideMonitor: Any?

    /// Keep strong reference to hosting controller to prevent premature deallocation
    private var hostingController: NSHostingController<LauncherView>?

    /// Configuration to display in the launcher
    var configuration: DockTileConfiguration?

    /// Explicit lifecycle state — the single source of truth for visibility.
    private(set) var state: PanelState = .hidden

    /// When the popover most recently began hiding (explicit hide or transient self-dismiss).
    /// The Dock reopen handler uses this to distinguish "click to dismiss" from "click to
    /// open": the same Dock click that dismisses the popover also delivers a reopen, and we
    /// must not let that reopen immediately bounce the popover back open.
    private(set) var lastHiddenAt: CFAbsoluteTime = 0

    /// True while the popover is on screen or animating in. Callers use this to decide
    /// whether a Dock click should show or hide.
    var isVisible: Bool {
        return state == .showing || state == .shown
    }

    // MARK: - Anchor Resolution (pure seam)

    /// Result of `resolveAnchor`: where the 1×1 anchor window goes (Cocoa screen coords)
    /// and which popover edge the arrow should prefer.
    struct ResolvedAnchor: Equatable {
        var point: CGPoint
        var edge: NSRectEdge
    }

    /// Perpendicular breathing room above the magnified icon / autohidden Dock band.
    /// 25pt matches the shipped constant in DockAltTab (`largesize + 25`), the only known
    /// tool that compensates for magnification; verified visually against the real Dock's
    /// stack popover on this project's design pass.
    nonisolated static let dockClearancePadding: CGFloat = 25

    /// A measured visibleFrame gap below this is menu-bar/safe-area noise, not a Dock band
    /// (same threshold as DockLockManager's display detection) — treat as "Dock reserves
    /// nothing", i.e. autohide.
    nonisolated static let minimumMeasuredInset: CGFloat = 20

    /// Hard cap on clearance as a fraction of the screen's perpendicular axis, so garbage
    /// prefs (largesize 512) can never float the popover into the middle of the screen.
    nonisolated static let maxClearanceFraction: CGFloat = 0.4

    /// The single source of truth for where the popover anchors, given plain values.
    ///
    /// Rules (mirrors the real Dock's stack-popover behaviour, observed under magnification):
    /// - Resting clearance is the **measured** visibleFrame gap (self-corrects when a crowded
    ///   Dock auto-shrinks below the `tilesize` pref). When the Dock reserves nothing
    ///   (autohide), fall back to `tilesize + padding` — the click that opened us proves the
    ///   Dock is revealed right now.
    /// - Magnification lifts clearance to `largesize + padding`: AX/CGWindow/CoreDock all
    ///   report the *resting* layout while icons are magnified, so the worst-case envelope is
    ///   the only reliable geometry — and since the user just clicked our icon, the cursor is
    ///   on it and it IS at full largesize (the worst case is the exact case).
    /// - `largesize <= tilesize` means magnification doesn't grow icons: no lift.
    /// - The mouse coordinate is used only for the Dock-parallel axis (the cursor sits inside
    ///   the clicked icon, making it the best icon-center estimate available without AX),
    ///   clamped into the screen. NSPopover slides its arrow within the preferred edge when
    ///   the anchor is near a screen corner, so no lateral compensation is needed here.
    nonisolated static func resolveAnchor(
        screenFrame: CGRect,
        visibleFrame: CGRect,
        mouse: CGPoint,
        prefs: DockPrefs
    ) -> ResolvedAnchor {
        let measuredGap: CGFloat
        switch prefs.orientation {
        case .bottom: measuredGap = visibleFrame.minY - screenFrame.minY
        case .left:   measuredGap = visibleFrame.minX - screenFrame.minX
        case .right:  measuredGap = screenFrame.maxX - visibleFrame.maxX
        }

        let restingBand = measuredGap >= Self.minimumMeasuredInset
            ? measuredGap
            : prefs.tileSize + Self.dockClearancePadding

        var clearance = restingBand
        if prefs.magnificationEnabled && prefs.largeSize > prefs.tileSize {
            clearance = max(restingBand, prefs.largeSize + Self.dockClearancePadding)
        }

        let axisLength = prefs.orientation == .bottom ? screenFrame.height : screenFrame.width
        clearance = min(clearance, axisLength * Self.maxClearanceFraction)

        switch prefs.orientation {
        case .bottom:
            let x = min(max(mouse.x, screenFrame.minX), screenFrame.maxX)
            return ResolvedAnchor(point: CGPoint(x: x, y: screenFrame.minY + clearance), edge: .minY)
        case .left:
            let y = min(max(mouse.y, screenFrame.minY), screenFrame.maxY)
            return ResolvedAnchor(point: CGPoint(x: screenFrame.minX + clearance, y: y), edge: .minX)
        case .right:
            let y = min(max(mouse.y, screenFrame.minY), screenFrame.maxY)
            return ResolvedAnchor(point: CGPoint(x: screenFrame.maxX - clearance, y: y), edge: .maxX)
        }
    }

    // MARK: - Popover Management

    private func createPopover() -> NSPopover {
        let popover = NSPopover()

        // Appearance configuration
        popover.behavior = .transient  // Closes when clicking outside
        popover.animates = true
        popover.delegate = self

        // Set content view with configuration
        let launcherView = LauncherView(configuration: configuration)
        let controller = NSHostingController(rootView: launcherView)

        // Let the SwiftUI content drive the popover size. `LauncherView` routes to
        // `StackPopoverView` / `ListPopoverView`, which size themselves entirely from the
        // `PopoverMetrics` seam (the global Popover Appearance settings). Sizing the popover from
        // that ideal size — instead of the old hard-coded `calculatePopoverSize()` — is what makes
        // the saved settings (Popover Size / Tile Size / Spacing / Labels) actually apply to each
        // helper tile's real Dock popover, per its own grid/list layout, matching the live preview.
        controller.sizingOptions = [.preferredContentSize]

        // Keep strong reference to prevent deallocation
        self.hostingController = controller

        popover.contentViewController = controller

        return popover
    }

    /// Create anchor window and determine the preferred edge for popover.
    /// Anchoring is "anchor-and-hold": resolved once per show from the click-time mouse
    /// location and the current Dock prefs, then never chased — the same settle behaviour
    /// as the real Dock's stack popover (its body holds position when magnification
    /// collapses; only its tail tracks, which nothing public can replicate).
    private func createAnchorWindowAndEdge() -> (window: NSWindow, edge: NSRectEdge) {
        let mouseLocation = NSEvent.mouseLocation

        // A Dock click lands on the display hosting the Dock, so the screen under the
        // cursor is the right one — NSScreen.main is the *key window's* screen, which can
        // differ on multi-display setups (especially with Dock Lock pinning the Dock).
        let screen = NSScreen.screens.first { NSMouseInRect(mouseLocation, $0.frame, false) }
            ?? NSScreen.main

        // Safe guard: fall back to a degenerate anchor if no screen is available
        guard let screen else {
            let fallbackWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 1, height: 1),
                styleMask: .borderless,
                backing: .buffered,
                defer: false
            )
            fallbackWindow.backgroundColor = .clear
            fallbackWindow.isOpaque = false
            return (fallbackWindow, .minY)
        }

        let prefs = DockPrefs.read()
        let anchor = FloatingPanel.resolveAnchor(
            screenFrame: screen.frame,
            visibleFrame: screen.visibleFrame,
            mouse: mouseLocation,
            prefs: prefs
        )
        DiagnosticsLog.shared.log(
            "helper",
            "Popover anchor \(Int(anchor.point.x)),\(Int(anchor.point.y)) " +
            "edge=\(prefs.orientation) mag=\(prefs.magnificationEnabled) " +
            "tile=\(Int(prefs.tileSize)) large=\(Int(prefs.largeSize)) autohide=\(prefs.autohide)",
            verbose: true
        )

        let windowRect = NSRect(x: anchor.point.x, y: anchor.point.y, width: 1, height: 1)

        let window = NSWindow(
            contentRect: windowRect,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )

        window.backgroundColor = .clear
        window.isOpaque = false
        window.level = .popUpMenu
        window.ignoresMouseEvents = true
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        return (window, anchor.edge)
    }

    // MARK: - Show/Hide

    func show(animated: Bool = true, withKeyboardFocus: Bool = false) {
        // Only show from a settled hidden state. Ignore re-entrant calls while we're
        // already showing/shown, or mid-close — this is what stops click bursts from
        // stacking animations and flickering the popover.
        guard state == .hidden else {
            return
        }
        state = .showing

        // Cleanup any stale state
        cleanupPopover()

        // Create popover and anchor window with appropriate edge
        popover = createPopover()
        let (window, preferredEdge) = createAnchorWindowAndEdge()
        anchorWindow = window

        // Activate app
        NSApp.activate(ignoringOtherApps: true)

        guard let popover = popover,
              let anchorWindow = anchorWindow,
              let anchorView = anchorWindow.contentView else {
            state = .hidden
            return
        }

        // Make anchor window visible (but transparent)
        anchorWindow.orderFront(nil)

        // Show popover with arrow pointing toward the Dock
        popover.show(
            relativeTo: anchorView.bounds,
            of: anchorView,
            preferredEdge: preferredEdge
        )
        state = .shown

        // If keyboard focus requested (Cmd+Tab activation), notify the view
        if withKeyboardFocus {
            NotificationCenter.default.post(name: .enableKeyboardNavigation, object: nil)
        }

        // Listen for dismissal notification from LauncherView
        dismissObserver = NotificationCenter.default.addObserver(
            forName: .dismissLauncher,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.hide(animated: true)
            }
        }

        // Add global click monitor to dismiss on click outside
        clickOutsideMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self = self, let popover = self.popover, popover.isShown else { return }

            // Check if click is outside the popover
            if let popoverWindow = popover.contentViewController?.view.window {
                let windowFrame = popoverWindow.frame

                // Convert global click location to check against popover window
                let globalClickLocation = NSEvent.mouseLocation

                if !windowFrame.contains(globalClickLocation) {
                    Task { @MainActor in
                        self.hide(animated: true)
                    }
                }
            }
        }
    }

    func hide(animated: Bool = true) {
        // Only hide from a visible state. Ignore calls while already hiding/hidden so a
        // queued click can't fire a second close mid-animation.
        guard state == .showing || state == .shown else {
            return
        }
        state = .hiding
        lastHiddenAt = CFAbsoluteTimeGetCurrent()

        // Remove notification observer first
        if let observer = dismissObserver {
            NotificationCenter.default.removeObserver(observer)
            dismissObserver = nil
        }

        // Remove click outside monitor
        if let monitor = clickOutsideMonitor {
            NSEvent.removeMonitor(monitor)
            clickOutsideMonitor = nil
        }

        // Close popover (delegate will handle final cleanup and reset state to .hidden)
        popover?.close()
    }

    // MARK: - Cleanup

    private func cleanupPopover() {
        // Remove notification observer
        if let observer = dismissObserver {
            NotificationCenter.default.removeObserver(observer)
            dismissObserver = nil
        }

        // Remove click outside monitor
        if let monitor = clickOutsideMonitor {
            NSEvent.removeMonitor(monitor)
            clickOutsideMonitor = nil
        }

        // Release popover resources
        popover?.close()
        popover = nil

        // Clean up anchor window
        cleanupAnchorWindow()

        // Release hosting controller
        hostingController = nil
    }

    private func cleanupAnchorWindow() {
        if let anchorWindow = anchorWindow {
            anchorWindow.orderOut(nil)
            self.anchorWindow = nil
        }
    }

    // MARK: - NSPopoverDelegate

    nonisolated func popoverDidClose(_ notification: Notification) {
        // Called after the popover close animation completes
        // Use MainActor.assumeIsolated for synchronous cleanup on main thread
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            MainActor.assumeIsolated {
                // Reset state here so it also covers transient self-dismissals
                // (click-outside) that never go through hide().
                self.state = .hidden
                // Stamp the dismissal time for transient closes that bypass hide(), so the
                // Dock reopen handler can suppress an immediate same-click reshow.
                self.lastHiddenAt = CFAbsoluteTimeGetCurrent()
                self.popover = nil
                self.cleanupAnchorWindow()
                self.hostingController = nil
            }
        }
    }
}
