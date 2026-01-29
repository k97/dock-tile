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

@MainActor
final class FloatingPanel: NSObject, NSPopoverDelegate {

    // MARK: - Properties

    private var popover: NSPopover?
    private var anchorWindow: NSWindow?
    private var dismissObserver: NSObjectProtocol?

    /// Keep strong reference to hosting controller to prevent premature deallocation
    private var hostingController: NSHostingController<LauncherView>?

    /// Configuration to display in the launcher
    var configuration: DockTileConfiguration?

    var isVisible: Bool {
        return popover?.isShown ?? false
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

        // Calculate size based on layout mode
        let size: NSSize
        if configuration?.layoutMode == .horizontal1x6 {
            size = NSSize(width: 520, height: 120)
        } else {
            size = NSSize(width: 360, height: 240)
        }

        controller.view.frame = NSRect(origin: .zero, size: size)

        popover.contentViewController = controller
        popover.contentSize = size

        return popover
    }

    private func createAnchorWindow() -> NSWindow {
        // Create an invisible anchor window positioned at dock icon location
        guard let screen = NSScreen.main else {
            return NSWindow()
        }

        // Get mouse location (where user clicked the dock icon)
        let mouseLocation = NSEvent.mouseLocation

        // Dock height is typically ~70 points
        // Position anchor just above the dock
        let dockHeight: CGFloat = 70
        let anchorY = screen.frame.minY + dockHeight

        let windowRect = NSRect(
            x: mouseLocation.x - 32,  // 64pt wide anchor centered on click
            y: anchorY,
            width: 64,
            height: 1  // Minimal height - just an anchor point
        )

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

        return window
    }

    // MARK: - Show/Hide

    func show(animated: Bool = true) {
        // If already visible, don't recreate
        if popover?.isShown == true {
            return
        }

        // Cleanup any stale state
        cleanupPopover()

        popover = createPopover()
        anchorWindow = createAnchorWindow()

        guard let popover = popover,
              let anchorWindow = anchorWindow,
              let anchorView = anchorWindow.contentView else {
            return
        }

        // Make anchor window visible (but transparent)
        anchorWindow.orderFront(nil)

        // Show popover anchored to the window
        // .maxY means the popover appears ABOVE the anchor, with arrow pointing DOWN
        popover.show(
            relativeTo: anchorView.bounds,
            of: anchorView,
            preferredEdge: .maxY
        )

        // Listen for dismissal notification from LauncherView
        dismissObserver = NotificationCenter.default.addObserver(
            forName: .dismissLauncher,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.hide(animated: true)
        }
    }

    func hide(animated: Bool = true) {
        // Remove notification observer first
        if let observer = dismissObserver {
            NotificationCenter.default.removeObserver(observer)
            dismissObserver = nil
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
