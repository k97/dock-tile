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

// MARK: - Dock Position Detection

enum DockPosition {
    case bottom
    case left
    case right
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

    var isVisible: Bool {
        return popover?.isShown ?? false
    }

    // MARK: - Dock Detection

    /// Detect the Dock's position by comparing screen frame vs visible frame
    private func detectDockPosition() -> DockPosition {
        guard let screen = NSScreen.main else { return .bottom }

        let frame = screen.frame
        let visible = screen.visibleFrame

        // Calculate the difference on each edge
        let bottomGap = visible.minY - frame.minY
        let leftGap = visible.minX - frame.minX
        let rightGap = frame.maxX - visible.maxX

        // The Dock is on the side with the largest gap (excluding menu bar)
        // Menu bar is always at top, so we ignore top gap
        if leftGap > bottomGap && leftGap > rightGap {
            return .left
        } else if rightGap > bottomGap && rightGap > leftGap {
            return .right
        } else {
            return .bottom
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

        // Keep strong reference to prevent deallocation
        self.hostingController = controller

        // Calculate size based on layout mode and content
        let size = calculatePopoverSize()

        controller.view.frame = NSRect(origin: .zero, size: size)

        popover.contentViewController = controller
        popover.contentSize = size

        return popover
    }

    /// Calculate popover size based on layout mode and number of apps
    private func calculatePopoverSize() -> NSSize {
        guard let screen = NSScreen.main else {
            return NSSize(width: 340, height: 180)
        }

        let appCount = configuration?.appItems.count ?? 0

        // Constrain max width to 80% of visible frame for ultra-wide/small displays
        let maxWidth = screen.visibleFrame.width * 0.8

        if configuration?.layoutMode == .horizontal1x6 {
            // List view: fixed width, height based on content
            // Title (30) + apps (28 each) + divider (12) + utility items (56) + padding (16)
            let baseHeight: CGFloat = 114  // Title + divider + utilities + padding
            let appsHeight = CGFloat(max(appCount, 1)) * 28
            let totalHeight = min(baseHeight + appsHeight, 400)
            let width = min(220, maxWidth)
            return NSSize(width: width, height: totalHeight)
        } else {
            // Stack view: width fixed at 340, height based on rows
            guard appCount > 0 else {
                let width = min(340, maxWidth)
                return NSSize(width: width, height: 180)
            }
            let rows = ceil(Double(appCount) / 3.0)
            let contentHeight = rows * 100
            let totalHeight = min(CGFloat(contentHeight) + 54, 400)
            let width = min(340, maxWidth)
            return NSSize(width: width, height: totalHeight)
        }
    }

    /// Create anchor window and determine the preferred edge for popover
    /// Uses the "hard edge" rule: anchors strictly to visibleFrame boundary,
    /// ignoring mouse depth into the Dock area
    private func createAnchorWindowAndEdge() -> (window: NSWindow, edge: NSRectEdge) {
        // Safe guard: fall back to screen bounds if visibleFrame unavailable
        guard let screen = NSScreen.main else {
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

        let visibleFrame = screen.visibleFrame
        let mouseLocation = NSEvent.mouseLocation
        let dockPosition = detectDockPosition()

        let windowRect: NSRect
        let preferredEdge: NSRectEdge

        switch dockPosition {
        case .bottom:
            // Hard edge rule: anchor Y is exactly at visibleFrame.minY (top of Dock)
            // Use mouse only for X-axis positioning
            windowRect = NSRect(
                x: mouseLocation.x,
                y: visibleFrame.minY,
                width: 1,
                height: 1
            )
            preferredEdge = .minY  // Arrow points down toward Dock

        case .left:
            // Hard edge rule: anchor X is exactly at visibleFrame.minX (right edge of Dock)
            // Use mouse only for Y-axis positioning
            windowRect = NSRect(
                x: visibleFrame.minX,
                y: mouseLocation.y,
                width: 1,
                height: 1
            )
            preferredEdge = .minX  // Arrow points left toward Dock

        case .right:
            // Hard edge rule: anchor X is exactly at visibleFrame.maxX (left edge of Dock)
            // Use mouse only for Y-axis positioning
            windowRect = NSRect(
                x: visibleFrame.maxX,
                y: mouseLocation.y,
                width: 1,
                height: 1
            )
            preferredEdge = .maxX  // Arrow points right toward Dock
        }

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

        return (window, preferredEdge)
    }

    // MARK: - Show/Hide

    func show(animated: Bool = true, withKeyboardFocus: Bool = false) {
        // If already visible, don't recreate
        if popover?.isShown == true {
            return
        }

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
            self?.hide(animated: true)
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

        // Close popover (delegate will handle final cleanup)
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
                self.popover = nil
                self.cleanupAnchorWindow()
                self.hostingController = nil
            }
        }
    }
}
