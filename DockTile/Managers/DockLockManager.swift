//
//  DockLockManager.swift
//  DockTile
//
//  Prototype: locks the macOS Dock to a single ("anchor") display so it stops
//  jumping between screens on multi-monitor setups.
//
//  Technique (real-time event-tap blocking, à la DockAnchor / DockLock Pro):
//  macOS relocates the Dock to whichever display the cursor pushes against the
//  Dock edge and holds. There is no public API to pin it. We install a
//  CGEvent tap on mouse-move events and, when the pointer enters the bottom
//  edge band of a NON-anchor display, clamp its Y just above that band so the
//  Dock's relocation trigger never fires on those displays. The anchor display
//  is left untouched, so the Dock keeps working there.
//
//  Requires Accessibility (TCC) permission — an active event tap that mutates
//  events cannot be created without it.
//
//  Swift 6 - Strict Concurrency
//

import AppKit
import ApplicationServices

// MARK: - Shared callback state

/// A bottom-edge band on a non-anchor display, expressed in CoreGraphics global
/// coordinates (top-left origin, Y increasing downward — same space as
/// `CGEvent.location` and `CGDisplayBounds`).
enum DockEdge {
    case bottom, left, right
}

/// An exposed Dock-trigger band on a non-anchor display. `range` runs along the
/// edge (x for `.bottom`, y for `.left`/`.right`); `clamp` is the value the
/// perpendicular axis is held to, just inside the display.
private struct TriggerZone {
    let edge: DockEdge
    let rangeMin: CGFloat
    let rangeMax: CGFloat
    let clamp: CGFloat
}

/// Snapshot consumed by the C event-tap callback. Both the writer
/// (`DockLockManager`, main actor) and the reader (the tap callback, which fires
/// on the main run loop) execute on the main thread, so there is no concurrent
/// access despite the `@unchecked Sendable` conformance.
private final class DockLockState: @unchecked Sendable {
    static let shared = DockLockState()
    var zones: [TriggerZone] = []
    var active = false
    private init() {}
}

// MARK: - Event tap callback

private func dockLockEventCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    // The system disables a tap if our callback is too slow or on certain input
    // events. Re-enable it so protection keeps working.
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        if let userInfo {
            let manager = Unmanaged<DockLockManager>.fromOpaque(userInfo).takeUnretainedValue()
            MainActor.assumeIsolated { manager.reEnableTap() }
        }
        return Unmanaged.passUnretained(event)
    }

    let state = DockLockState.shared
    guard state.active, !state.zones.isEmpty else {
        return Unmanaged.passUnretained(event)
    }

    let loc = event.location
    for zone in state.zones {
        switch zone.edge {
        case .bottom:
            if loc.x >= zone.rangeMin, loc.x <= zone.rangeMax, loc.y > zone.clamp {
                event.location = CGPoint(x: loc.x, y: zone.clamp)
                return Unmanaged.passUnretained(event)
            }
        case .left:
            if loc.y >= zone.rangeMin, loc.y <= zone.rangeMax, loc.x < zone.clamp {
                event.location = CGPoint(x: zone.clamp, y: loc.y)
                return Unmanaged.passUnretained(event)
            }
        case .right:
            if loc.y >= zone.rangeMin, loc.y <= zone.rangeMax, loc.x > zone.clamp {
                event.location = CGPoint(x: zone.clamp, y: loc.y)
                return Unmanaged.passUnretained(event)
            }
        }
    }

    return Unmanaged.passUnretained(event)
}

// MARK: - Manager

@MainActor
final class DockLockManager: ObservableObject {
    static let shared = DockLockManager()

    /// One connected display.
    struct DisplayInfo: Identifiable, Hashable {
        let id: CGDirectDisplayID
        let name: String
        let isMain: Bool
    }

    // MARK: Published state

    @Published var isEnabled: Bool {
        didSet {
            guard oldValue != isEnabled else { return }
            UserDefaults.standard.set(isEnabled, forKey: UserDefaultsKeys.dockLockEnabled)
            apply()
        }
    }

    @Published var anchorDisplayID: CGDirectDisplayID {
        didSet {
            guard oldValue != anchorDisplayID else { return }
            UserDefaults.standard.set(Int(anchorDisplayID), forKey: UserDefaultsKeys.dockLockAnchorDisplay)
            recomputeZones()
        }
    }

    @Published private(set) var isAccessibilityTrusted: Bool = false
    @Published private(set) var displays: [DisplayInfo] = []

    /// The pointer is held this many points clear of each non-anchor display's
    /// bottom edge. Small enough to stay out of the way, large enough that the
    /// Dock-relocation trigger never fires.
    private let bandHeight: CGFloat = 4

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    /// Watches `com.apple.dock.plist` so a Dock orientation change (bottom↔left↔right)
    /// recomputes trigger bands instantly, without waiting for a toggle.
    private let dockWatcher = DockPlistWatcher()

    // MARK: Init

    private init() {
        let defaults = UserDefaults.standard
        self.isEnabled = defaults.bool(forKey: UserDefaultsKeys.dockLockEnabled)

        let storedAnchor = defaults.integer(forKey: UserDefaultsKeys.dockLockAnchorDisplay)
        self.anchorDisplayID = storedAnchor > 0 ? CGDirectDisplayID(storedAnchor) : CGMainDisplayID()

        self.isAccessibilityTrusted = AXIsProcessTrusted()

        refreshDisplays()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )

        // Re-check Accessibility trust whenever we return to the foreground — this
        // is what catches the user granting access in System Settings and switching
        // back to the app.
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidBecomeActive),
            name: NSApplication.didBecomeActiveNotification,
            object: nil
        )

        // System-wide signal posted when Accessibility (AX) API authorization
        // changes. This is the established mechanism used across Mac accessibility
        // apps to react the instant the user flips the toggle — even if our app is
        // still in the background.
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(accessibilityApiChanged),
            name: NSNotification.Name("com.apple.accessibility.api"),
            object: nil
        )
    }

    // MARK: Public API

    /// Apply persisted state on launch. Call once after the app is up.
    func startIfEnabled() {
        if isEnabled { apply() }
    }

    /// Request Accessibility access the canonical way: this registers the app in
    /// the Accessibility list and shows the system's native consent prompt (which
    /// offers an "Open System Settings" button). The grant is detected later when
    /// the app returns to the foreground — see `refreshTrust()`.
    func requestAccessibility() {
        // `kAXTrustedCheckOptionPrompt` is a C global that Swift 6 flags as
        // non-concurrency-safe; its value is the documented constant string.
        let key = "AXTrustedCheckOptionPrompt"
        let trusted = AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
        if trusted != isAccessibilityTrusted {
            isAccessibilityTrusted = trusted
            apply()
        }
    }

    /// Open System Settings → Privacy & Security → Accessibility. Needed because
    /// the native consent prompt only appears once; afterwards the user reaches
    /// the toggle through this deep link.
    func openAccessibilitySettings() {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        ) else { return }
        NSWorkspace.shared.open(url)
    }

    /// Best-effort: nudge the Dock onto the anchor display by warping the cursor
    /// to its Dock edge. Not automatic — wired to an explicit menu action.
    func moveDockToAnchor() {
        guard let bounds = displayBounds(anchorDisplayID) else { return }
        let target: CGPoint
        switch currentDockEdge() {
        case .bottom: target = CGPoint(x: bounds.midX, y: bounds.maxY - 1)
        case .left:   target = CGPoint(x: bounds.minX + 1, y: bounds.midY)
        case .right:  target = CGPoint(x: bounds.maxX - 1, y: bounds.midY)
        }
        CGWarpMouseCursorPosition(target)
        // Re-associate so the user's physical mouse keeps controlling the cursor.
        CGAssociateMouseAndMouseCursorPosition(boolean_t(1))
    }

    var anchorDisplay: DisplayInfo? {
        displays.first { $0.id == anchorDisplayID }
    }

    // MARK: Lifecycle

    private func apply() {
        isAccessibilityTrusted = AXIsProcessTrusted()

        if isEnabled && isAccessibilityTrusted {
            installTapIfNeeded()
        } else {
            removeTap()
        }
        recomputeZones()

        // If the user enabled the lock but we still lack permission, kick off the
        // prompt + polling so it activates as soon as access is granted.
        if isEnabled && !isAccessibilityTrusted {
            requestAccessibility()
        }
    }

    private func installTapIfNeeded() {
        guard eventTap == nil else { return }

        let mask: CGEventMask =
            (1 << CGEventType.mouseMoved.rawValue) |
            (1 << CGEventType.leftMouseDragged.rawValue) |
            (1 << CGEventType.rightMouseDragged.rawValue)

        let userInfo = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: dockLockEventCallback,
            userInfo: userInfo
        ) else {
            NSLog("⚠️ DockLock: failed to create event tap (Accessibility not granted?)")
            return
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        eventTap = tap
        runLoopSource = source

        dockWatcher.onDockChanged = { [weak self] in
            self?.recomputeZones()
        }
        dockWatcher.startWatching()

        NSLog("✓ DockLock: event tap installed")
    }

    private func removeTap() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
        dockWatcher.stopWatching()
    }

    func reEnableTap() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: true)
        }
    }

    // MARK: Trigger zones

    private func recomputeZones() {
        let active = isEnabled && isAccessibilityTrusted && eventTap != nil
        var zones: [TriggerZone] = []

        if active {
            let edge = currentDockEdge()
            let allBounds = displays.map { ($0.id, CGDisplayBounds($0.id)) }
            for (id, bounds) in allBounds where id != anchorDisplayID && !bounds.isNull {
                let others = allBounds.filter { $0.0 != id }.map { $0.1 }
                zones.append(contentsOf: triggerZones(for: bounds, edge: edge, others: others))
            }
        }

        let state = DockLockState.shared
        state.zones = zones
        state.active = active && !zones.isEmpty
    }

    /// Build trigger bands for a non-anchor display's Dock edge, but only for the
    /// segments of that edge that are *exposed* — i.e. not backed by an adjacent
    /// display. Clamping a shared edge would otherwise wall off the cursor from
    /// crossing between monitors.
    private func triggerZones(for bounds: CGRect, edge: DockEdge, others: [CGRect]) -> [TriggerZone] {
        let eps: CGFloat = 1.0
        let clamp: CGFloat
        let span: (CGFloat, CGFloat)
        let covered: [(CGFloat, CGFloat)]

        switch edge {
        case .bottom:
            clamp = bounds.maxY - bandHeight
            span = (bounds.minX, bounds.maxX)
            covered = others
                .filter { abs($0.minY - bounds.maxY) <= eps }
                .map { (max($0.minX, bounds.minX), min($0.maxX, bounds.maxX)) }
        case .left:
            clamp = bounds.minX + bandHeight
            span = (bounds.minY, bounds.maxY)
            covered = others
                .filter { abs($0.maxX - bounds.minX) <= eps }
                .map { (max($0.minY, bounds.minY), min($0.maxY, bounds.maxY)) }
        case .right:
            clamp = bounds.maxX - bandHeight
            span = (bounds.minY, bounds.maxY)
            covered = others
                .filter { abs($0.minX - bounds.maxX) <= eps }
                .map { (max($0.minY, bounds.minY), min($0.maxY, bounds.maxY)) }
        }

        return subtract(span: span, covered: covered)
            .filter { $0.1 - $0.0 > 1 }
            .map { TriggerZone(edge: edge, rangeMin: $0.0, rangeMax: $0.1, clamp: clamp) }
    }

    /// Subtract `covered` sub-intervals from `span`, returning the gaps.
    private func subtract(span: (CGFloat, CGFloat), covered: [(CGFloat, CGFloat)]) -> [(CGFloat, CGFloat)] {
        var result = [span]
        for cut in covered where cut.1 > cut.0 {
            var next: [(CGFloat, CGFloat)] = []
            for seg in result {
                if cut.1 <= seg.0 || cut.0 >= seg.1 {
                    next.append(seg)            // no overlap
                    continue
                }
                if cut.0 > seg.0 { next.append((seg.0, cut.0)) }   // remainder before cut
                if cut.1 < seg.1 { next.append((cut.1, seg.1)) }   // remainder after cut
            }
            result = next
        }
        return result
    }

    /// Reads the Dock's configured orientation from `com.apple.dock`, matching the
    /// CFPreferences approach used elsewhere for Dock state.
    private func currentDockEdge() -> DockEdge {
        // Flush cfprefsd's cache so we read the orientation written moments ago.
        CFPreferencesAppSynchronize("com.apple.dock" as CFString)
        let value = CFPreferencesCopyAppValue("orientation" as CFString, "com.apple.dock" as CFString) as? String
        switch value {
        case "left": return .left
        case "right": return .right
        default: return .bottom
        }
    }

    // MARK: Displays

    @objc private func screenParametersChanged() {
        refreshDisplays()
        // If the anchor display was disconnected, fall back to the main display.
        if !displays.contains(where: { $0.id == anchorDisplayID }) {
            anchorDisplayID = CGMainDisplayID()
        } else {
            recomputeZones()
        }
    }

    private func refreshDisplays() {
        let main = CGMainDisplayID()
        displays = NSScreen.screens.compactMap { screen in
            guard let id = screen.displayID else { return nil }
            return DisplayInfo(id: id, name: screen.localizedName, isMain: id == main)
        }
    }

    /// `CGDisplayBounds` returns top-left-origin global coordinates, matching the
    /// space used by `CGEvent.location`.
    private func displayBounds(_ id: CGDirectDisplayID) -> CGRect? {
        let bounds = CGDisplayBounds(id)
        return bounds.isNull ? nil : bounds
    }

    // MARK: Trust

    @objc private func appDidBecomeActive() {
        refreshTrust()
    }

    @objc private func accessibilityApiChanged() {
        // AXIsProcessTrusted() can briefly lag the notification; re-check after a beat.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            MainActor.assumeIsolated { self?.refreshTrust() }
        }
    }

    /// Re-read Accessibility trust and react to any change. Driven by the app
    /// returning to the foreground, the AX-API change notification, and the
    /// settings view appearing — no polling.
    func refreshTrust() {
        let trusted = AXIsProcessTrusted()
        NSLog("🔐 DockLock refreshTrust: AXIsProcessTrusted=\(trusted), previous=\(isAccessibilityTrusted)")
        guard trusted != isAccessibilityTrusted else { return }
        isAccessibilityTrusted = trusted
        // Install or tear down the tap now that the permission state changed.
        apply()
    }
}

// MARK: - NSScreen helper

private extension NSScreen {
    var displayID: CGDirectDisplayID? {
        (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
    }
}
