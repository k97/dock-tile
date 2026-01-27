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
final class FloatingPanel: NSObject {

    // MARK: - Properties

    private var popover: NSPopover?
    private var anchorWindow: NSWindow?
    private var dismissObserver: NSObjectProtocol?

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

        // Set content view with configuration
        let launcherView = LauncherView(configuration: configuration)
        let hostingController = NSHostingController(rootView: launcherView)

        // Calculate size based on layout mode
        let size: NSSize
        if configuration?.layoutMode == .horizontal1x6 {
            size = NSSize(width: 520, height: 120)
        } else {
            size = NSSize(width: 360, height: 240)
        }

        hostingController.view.frame = NSRect(origin: .zero, size: size)

        popover.contentViewController = hostingController
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
        // Recreate popover and anchor window each time for fresh state
        cleanup()

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
        cleanup()
    }

    // MARK: - Cleanup

    private func cleanup() {
        // Remove notification observer
        if let observer = dismissObserver {
            NotificationCenter.default.removeObserver(observer)
            dismissObserver = nil
        }

        if let popover = popover {
            popover.close()
            self.popover = nil
        }

        if let anchorWindow = anchorWindow {
            anchorWindow.orderOut(nil)
            anchorWindow.close()
            self.anchorWindow = nil
        }
    }

    deinit {
        // Cannot call MainActor cleanup from deinit
        // Objects will be released automatically
    }
}
