//
//  NativeBackgroundViews.swift
//  DockTile
//
//  Shared NSViewRepresentable wrappers for native AppKit background colors.
//  Uses layer-backed NSViews for reliable color rendering in SwiftUI.
//  Swift 6 - Strict Concurrency
//

import AppKit
import SwiftUI

/// Generic NSColor background view using layer-backed NSView.
///
/// **Why NSViewRepresentable instead of SwiftUI `Color(nsColor:)`?**
/// SwiftUI's `Color(nsColor:)` initializer doesn't reliably bridge all AppKit dynamic colors
/// (e.g., `.windowBackgroundColor`, `.quaternarySystemFill`). These colors adapt to appearance
/// changes (light/dark mode) at the AppKit layer, but SwiftUI may not pick up the change.
/// Using a layer-backed NSView with direct `cgColor` assignment ensures correct rendering.
struct NSColorBackgroundView: NSViewRepresentable {
    let color: () -> NSColor

    init(_ color: @escaping @autoclosure () -> NSColor) {
        self.color = color
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        view.wantsLayer = true
        view.layer?.backgroundColor = color().cgColor
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        nsView.layer?.backgroundColor = color().cgColor
    }
}

// MARK: - Convenience Initializers

extension NSColorBackgroundView {
    /// Form group background using quaternarySystemFill
    static var formGroup: NSColorBackgroundView {
        NSColorBackgroundView(NSColor.quaternarySystemFill)
    }

    /// Window background color
    static var windowBackground: NSColorBackgroundView {
        NSColorBackgroundView(NSColor.windowBackgroundColor)
    }
}

// MARK: - Studio Canvas Background

/// The "studio canvas" backdrop used behind a live preview hero — a vibrant, semi-transparent
/// frosted surface (`underWindowBackground`). Shared by the Customise-Tile icon studio and the
/// Popover Appearance preview so both hero previews sit on the identical treatment.
///
/// `behindWindow` lets the desktop bleed through for the Liquid Glass look; `active` keeps the
/// vibrancy alive even when the app isn't frontmost (otherwise it flattens to grey).
struct StudioCanvasBackgroundView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .underWindowBackground
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
