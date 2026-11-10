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

extension Notification.Name {
    /// Posted (main thread) after the app restarts the Dock for a tile operation, so Dock Lock can
    /// re-assert the anchor if the relaunched Dock came back on the wrong display.
    static let dockDidRestart = Notification.Name("com.docktile.dockDidRestart")
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
            if !isEnabled {
                // Hard off-switch: abort any in-flight relocation and clear status *before*
                // apply() tears the tap down, so nothing about Dock Lock keeps running. apply()
                // then removes the event tap + dock watcher and clears all clamp zones, handing
                // the Dock fully back to macOS. The Dock is left where it is — not moved back.
                moveTask?.cancel()
                moveState = .idle
            }
            apply()
        }
    }

    /// The display the Dock is pinned to. `0` is the sentinel for **Default** — no anchor, so
    /// the Dock follows macOS's normal behaviour. Driven by `selectAnchor(_:)` (user picks in
    /// the settings picker) and `resolveAnchorFromPersisted()` (display connect/disconnect);
    /// never written directly so persistence and the live value can't drift.
    @Published private(set) var anchorDisplayID: CGDirectDisplayID = 0

    @Published private(set) var isAccessibilityTrusted: Bool = false
    @Published private(set) var displays: [DisplayInfo] = []

    /// Progress of an in-flight (or last) attempt to relocate the Dock onto the anchor. Drives
    /// the loader / status message in the settings UI.
    enum MoveState: Equatable {
        case idle
        case moving(displayName: String)
        case succeeded(displayName: String)
        case failed(displayName: String)
        /// Another display touches the anchor's whole Dock edge; no retry can help.
        case edgeCovered(displayName: String)
        /// "Displays have separate Spaces" is off, so the Dock can't leave the main display.
        case spacesShared(displayName: String)
    }
    @Published private(set) var moveState: MoveState = .idle

    /// Dock Lock is only meaningful with more than one screen. On a single display (e.g. the
    /// MacBook with no external monitor) the engine stays completely inert so it never interferes
    /// with where macOS puts the built-in Dock.
    var isMultiDisplay: Bool { displays.count > 1 }

    /// The pointer is held this many points clear of each non-anchor display's
    /// bottom edge. Small enough to stay out of the way, large enough that the
    /// Dock-relocation trigger never fires.
    private let bandHeight: CGFloat = 4

    /// In-flight Dock relocation, cancelled when a newer request supersedes it.
    private var moveTask: Task<Void, Never>?

    /// The pending re-check after a display change (`scheduleMoveAfterDisplayChange`).
    private var displayChangeTask: Task<Void, Never>?

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    /// Watches `com.apple.dock.plist` so a Dock orientation change (bottom↔left↔right)
    /// recomputes trigger bands instantly, without waiting for a toggle.
    private let dockWatcher = DockPlistWatcher()

    // MARK: Init

    private init() {
        let defaults = UserDefaults.standard
        self.isEnabled = defaults.bool(forKey: UserDefaultsKeys.dockLockEnabled)
        self.isAccessibilityTrusted = AXIsProcessTrusted()

        refreshDisplays()
        migrateLegacyAnchorIfNeeded()
        // The current display setup's anchor as a live display ID (0 = nothing to hold).
        self.anchorDisplayID = persistedAnchorID() ?? 0

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

        // The Dock can drift to another display across sleep/wake. Re-assert the anchor on wake
        // so it self-heals without waiting for the next relaunch. Posted on the workspace centre.
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(systemDidWake),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )

        // A tile show/hide/install restarts the Dock, which can relaunch on a different display.
        // Re-assert the anchor afterwards.
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(dockDidRestart),
            name: .dockDidRestart,
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

    /// User picked an anchor in the settings picker. `id == 0` means **Default** (no anchor):
    /// the clamp is dropped and the Dock is left wherever macOS wants it. Picking a concrete
    /// display persists the choice (by UUID) and kicks off a verified relocation.
    func selectAnchor(_ id: CGDirectDisplayID) {
        guard id != anchorDisplayID else { return }
        anchorDisplayID = id
        persistAnchor()
        recomputeZones()
        if id == 0 {
            moveTask?.cancel()
            moveState = .idle
            return
        }
        requestDockMove(reason: "user_selected")
    }

    /// True when a concrete display (not "Default") is the anchor.
    var isAnchored: Bool { anchorDisplayID != 0 }

    /// Manually retry the relocation (wired to the "Try Again" button after a failure).
    func retryMove() {
        requestDockMove(reason: "manual_retry")
    }

    var anchorDisplay: DisplayInfo? {
        displays.first { $0.id == anchorDisplayID }
    }

    // MARK: Dock relocation (verified)

    /// Start a verified relocation of the Dock onto the anchor display, superseding any in-flight
    /// attempt. No-ops (and clears any stale status) when the preconditions aren't met — notably
    /// on a single-display Mac, where Dock Lock must not touch the Dock at all.
    private func requestDockMove(reason: String) {
        guard isEnabled, isAccessibilityTrusted, anchorDisplayID != 0, isMultiDisplay else {
            moveTask?.cancel()
            moveState = .idle
            return
        }
        moveTask?.cancel()
        moveTask = Task { [weak self] in await self?.performMove(reason: reason) }
    }

    /// Warp-and-hold the cursor against the anchor's Dock edge, polling until macOS actually
    /// relocates the Dock there (or a timeout). Every stage is mirrored into NSLog + the
    /// analytics/Crashlytics diagnostics so a failed move is observable after the fact.
    private func performMove(reason: String) async {
        guard let bounds = displayBounds(anchorDisplayID), let target = anchorDisplay else {
            moveState = .idle
            return
        }
        let name = target.name
        let edge = currentDockEdge()

        // Already home — confirm without warping the cursor.
        if currentDockDisplayID() == anchorDisplayID {
            moveState = .succeeded(displayName: name)
            AnalyticsService.shared.setBreadcrumb("already_on_anchor", for: "dock_lock_move")
            // A display-change re-check runs on every screen change; finding the Dock home is no event.
            if reason != "displays_changed" {
                AnalyticsService.shared.log(.dockLockMoveSucceeded, ["reason": reason, "already": true])
            }
            NSLog("✓ DockLock move: Dock already on anchor \"\(name)\" (reason=\(reason))")
            return
        }

        // A layout macOS cannot move the Dock into: say why, and never warp the pointer for nothing.
        let others = displays.filter { $0.id != anchorDisplayID }.map { CGDisplayBounds($0.id) }
        let edgePoints: [CGPoint]
        switch Self.movePlan(anchor: bounds, anchorIsMain: target.isMain, others: others,
                             edge: edge, separateSpaces: NSScreen.screensHaveSeparateSpaces) {
        case .push(let points):
            edgePoints = points
        case .edgeCovered:
            moveState = .edgeCovered(displayName: name)
            DiagnosticsLog.shared.log("docklock", "Can't move Dock onto '\(name)': another display covers its whole \(edge) edge (reason: \(reason))")
            return
        case .spacesShared:
            moveState = .spacesShared(displayName: name)
            DiagnosticsLog.shared.log("docklock", "Can't move Dock onto '\(name)': Displays have separate Spaces is off (reason: \(reason))")
            return
        }

        moveState = .moving(displayName: name)
        AnalyticsService.shared.setBreadcrumb("moving", for: "dock_lock_move")
        AnalyticsService.shared.log(.dockLockMoveStarted, ["reason": reason, "edge": "\(edge)"])
        NSLog("→ DockLock move: relocating Dock onto \"\(name)\" (reason=\(reason), edge=\(edge))")
        // Yield once so SwiftUI paints the "Moving…" spinner before we monopolise the main
        // thread warping the cursor.
        try? await Task.sleep(nanoseconds: 50_000_000)

        let origin = CGEvent(source: nil)?.location

        // Suspend our own clamp tap for the duration: it sits at the head of the session tap and
        // would otherwise inspect (and potentially perturb) the very motion we're synthesising.
        // Restored when we leave this function. NOTE: we keep the hardware mouse *associated* —
        // disassociating it makes posted mouseMoved events stop registering as real pointer
        // motion, so the Dock never relocates.
        if let tap = eventTap { CGEvent.tapEnable(tap: tap, enable: false) }
        defer {
            if let tap = eventTap { CGEvent.tapEnable(tap: tap, enable: true) }
        }

        let push = edgePushDelta(edge)
        // ~6 s on a single free stretch; ~3 s each when there are several, so a stretch macOS
        // ignores (a sliver, an odd corner) doesn't end the move before the next one is tried.
        let holdTicks = edgePoints.count == 1 ? 75 : 40

        var moved = false
        for edgePoint in edgePoints where !moved {
            // Glide IN from just inside the display down onto the edge first. macOS triggers the
            // relocation off continuous inbound motion that overshoots the edge — teleporting straight
            // onto the edge is unreliable (works ~1-in-3), which is why a first attempt often failed
            // and only "Try Again" took. The glide makes the first attempt land.
            let approach = approachStart(from: edgePoint, edge: edge, inset: 80)
            CGWarpMouseCursorPosition(approach)
            for step in 1...8 {
                if Task.isCancelled { return }
                let t = CGFloat(step) / 8
                let p = CGPoint(x: approach.x + (edgePoint.x - approach.x) * t,
                                y: approach.y + (edgePoint.y - approach.y) * t)
                postEdgePush(to: p, push: push)
                try? await Task.sleep(nanoseconds: 16_000_000)
            }

            // Then hold against the edge with sustained pressure, polling until the Dock lands.
            // Each tick re-warps to the edge (so a stray hardware nudge self-corrects) and posts a
            // real HID mouseMoved carrying a delta shoving toward the edge, jittered 1pt along it so
            // no two events are identical.
            for tick in 0..<holdTicks {
                if Task.isCancelled { return }
                postEdgePush(to: jittered(edgePoint, edge: edge, even: tick % 2 == 0), push: push)
                try? await Task.sleep(nanoseconds: 80_000_000) // 0.08s
                if currentDockDisplayID() == anchorDisplayID { moved = true; break }
            }
        }

        // The Dock animates in; give it a beat then re-check, so a relocation that lands right at
        // the timeout isn't misreported as a failure.
        if !moved {
            try? await Task.sleep(nanoseconds: 300_000_000)
            moved = currentDockDisplayID() == anchorDisplayID
        }

        if Task.isCancelled { return }

        // Return the pointer to where the user left it, with one posted move away from the edge: a
        // bare warp sends no event, so the Dock never sees the pointer leave and can stay magnified
        // (and a zero-delta event is ignored, see `jittered`).
        if let origin { postEdgePush(to: origin, push: (-push.dx, -push.dy)) }

        if moved {
            moveState = .succeeded(displayName: name)
            AnalyticsService.shared.setBreadcrumb("succeeded", for: "dock_lock_move")
            AnalyticsService.shared.log(.dockLockMoveSucceeded, ["reason": reason, "already": false])
            NSLog("✓ DockLock move: Dock now on \"\(name)\"")
            DiagnosticsLog.shared.log("docklock", "Relocated Dock onto '\(name)' (reason: \(reason))")
        } else {
            moveState = .failed(displayName: name)
            AnalyticsService.shared.setBreadcrumb("failed", for: "dock_lock_move")
            AnalyticsService.shared.log(.dockLockMoveFailed, ["reason": reason, "edge": "\(edge)"])
            NSLog("⚠️ DockLock move: Dock did not relocate onto \"\(name)\" within timeout")
            DiagnosticsLog.shared.log("docklock", "FAILED to relocate Dock onto '\(name)' within timeout (reason: \(reason), edge: \(edge))")
        }
    }

    /// What a move onto the anchor can do, decided from the layout alone.
    enum MovePlan: Equatable {
        /// Press at these points in turn (CG global, flush against the Dock edge), widest free stretch first.
        case push([CGPoint])
        /// Another display touches the whole Dock edge: macOS cannot bring the Dock there.
        case edgeCovered
        /// "Displays have separate Spaces" is off: the Dock stays on the main display.
        case spacesShared
    }

    /// The pointer only calls up the Dock where the edge leads off every screen, so the plan presses
    /// at the middle of each such stretch. The edge's own middle failed every time with a laptop
    /// under the middle of an ultrawide (2026-11-10): the pointer crossed onto the laptop.
    nonisolated static func movePlan(anchor: CGRect, anchorIsMain: Bool, others: [CGRect],
                                     edge: DockEdge, separateSpaces: Bool) -> MovePlan {
        if !separateSpaces && !anchorIsMain { return .spacesShared }
        let stretches = exposedSegments(of: anchor, edge: edge, others: others)
            .sorted { $0.1 - $0.0 > $1.1 - $1.0 }
        guard !stretches.isEmpty else { return .edgeCovered }
        return .push(stretches.map { stretch in
            let along = (stretch.0 + stretch.1) / 2
            switch edge {
            case .bottom: return CGPoint(x: along, y: anchor.maxY - 1)
            case .left:   return CGPoint(x: anchor.minX + 1, y: along)
            case .right:  return CGPoint(x: anchor.maxX - 1, y: along)
            }
        })
    }

    /// A mouse delta that shoves *toward* the Dock edge — the sustained pressure macOS reads as
    /// "the user is pushing the pointer past this screen's edge", which triggers the relocation.
    private func edgePushDelta(_ edge: DockEdge) -> (dx: Int, dy: Int) {
        switch edge {
        case .bottom: return (0, 18)   // push downward
        case .left:   return (-18, 0)  // push left
        case .right:  return (18, 0)   // push right
        }
    }

    /// A point `inset` points *inside* the display from the edge point, to glide in from.
    private func approachStart(from edgePoint: CGPoint, edge: DockEdge, inset: CGFloat) -> CGPoint {
        switch edge {
        case .bottom: return CGPoint(x: edgePoint.x, y: edgePoint.y - inset)
        case .left:   return CGPoint(x: edgePoint.x + inset, y: edgePoint.y)
        case .right:  return CGPoint(x: edgePoint.x - inset, y: edgePoint.y)
        }
    }

    /// Warp the cursor to `point` and post a real HID `mouseMoved` there carrying the edge-push
    /// delta — the WindowServer/Dock treat it as genuine hardware motion into the screen edge.
    private func postEdgePush(to point: CGPoint, push: (dx: Int, dy: Int)) {
        CGWarpMouseCursorPosition(point)
        guard let event = CGEvent(
            mouseEventSource: nil,
            mouseType: .mouseMoved,
            mouseCursorPosition: point,
            mouseButton: .left
        ) else { return }
        event.setIntegerValueField(.mouseEventDeltaX, value: Int64(push.dx))
        event.setIntegerValueField(.mouseEventDeltaY, value: Int64(push.dy))
        event.post(tap: .cghidEventTap)
    }

    /// Nudge the hold-point 1pt *along* the Dock edge (never off it) so consecutive posted
    /// moves carry a non-zero delta — the WindowServer ignores zero-movement events.
    private func jittered(_ point: CGPoint, edge: DockEdge, even: Bool) -> CGPoint {
        let d: CGFloat = even ? 0 : 1
        switch edge {
        case .bottom:        return CGPoint(x: point.x + d, y: point.y)
        case .left, .right:  return CGPoint(x: point.x, y: point.y + d)
        }
    }

    /// Which display the Dock is currently on. Tries the cheap public-API signal first
    /// (`NSScreen.visibleFrame` inset on the Dock edge — the Dock reserves space only on its own
    /// screen), then falls back to locating the Dock's own window when that signal is absent —
    /// notably an **auto-hidden Dock**, which reserves no space, so the inset method alone would
    /// report a successful move as a failure.
    private func currentDockDisplayID() -> CGDirectDisplayID? {
        dockDisplayViaVisibleFrame() ?? dockDisplayViaDockWindow()
    }

    /// Detect the Dock's display from the screen-space it reserves. nil when the Dock is hidden
    /// (no meaningful inset) or no screen qualifies. `visibleFrame` is Cocoa (bottom-left origin),
    /// kept separate from the top-left CG space used for warping.
    private func dockDisplayViaVisibleFrame() -> CGDirectDisplayID? {
        let edge = currentDockEdge()
        let minimumInset: CGFloat = 20 // Dock is far taller; filters menu-bar / safe-area insets.
        var best: (id: CGDirectDisplayID, inset: CGFloat)?
        for screen in NSScreen.screens {
            guard let id = screen.displayID else { continue }
            let f = screen.frame, v = screen.visibleFrame
            let inset: CGFloat
            switch edge {
            case .bottom: inset = v.minY - f.minY
            case .left:   inset = v.minX - f.minX
            case .right:  inset = f.maxX - v.maxX
            }
            if inset > (best?.inset ?? 0) { best = (id, inset) }
        }
        guard let best, best.inset >= minimumInset else { return nil }
        return best.id
    }

    /// Fallback detector for an auto-hidden Dock: find the Dock process's own window and map it to
    /// the display whose bounds it sits in (or nearest, since a hidden Dock parks just off the
    /// screen edge). Reading window owner/bounds needs no Screen Recording permission.
    private func dockDisplayViaDockWindow() -> CGDirectDisplayID? {
        // `[]` == kCGWindowListOptionAll: include off-screen windows (a hidden Dock is off-screen).
        guard let windows = CGWindowListCopyWindowInfo([], kCGNullWindowID) as? [[String: Any]] else {
            return nil
        }
        // The Dock owns several windows; its actual dock surface is the largest-area one.
        var best: (rect: CGRect, area: CGFloat)?
        for window in windows {
            guard window[kCGWindowOwnerName as String] as? String == "Dock",
                  let boundsDict = window[kCGWindowBounds as String] as? NSDictionary,
                  let rect = CGRect(dictionaryRepresentation: boundsDict) else { continue }
            let area = rect.width * rect.height
            if area > (best?.area ?? 0) { best = (rect, area) }
        }
        guard let rect = best?.rect else { return nil }

        let center = CGPoint(x: rect.midX, y: rect.midY)
        let candidates = displays.map { ($0.id, CGDisplayBounds($0.id)) }
        // Prefer the display that contains the Dock window's center…
        if let hit = candidates.first(where: { $0.1.contains(center) }) { return hit.0 }
        // …otherwise the nearest one (a hidden Dock's window parks just outside the bounds).
        return candidates.min { distance($0.1, to: center) < distance($1.1, to: center) }?.0
    }

    /// Shortest distance from a point to a rectangle (0 when inside).
    private func distance(_ rect: CGRect, to p: CGPoint) -> CGFloat {
        let dx = max(rect.minX - p.x, 0, p.x - rect.maxX)
        let dy = max(rect.minY - p.y, 0, p.y - rect.maxY)
        return (dx * dx + dy * dy).squareRoot()
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

        // Re-assert the Dock onto the anchor: covers enabling the lock, granting permission,
        // and relaunch (where the Dock may have drifted). `requestDockMove` is a no-op for
        // Default / single-display, and skips warping when the Dock is already home.
        requestDockMove(reason: "apply")

        // NOTE: we deliberately do NOT prompt for Accessibility here. The system permission
        // dialog must only ever appear from an explicit user action (the permission primer's
        // "Continue" button), never automatically on launch or when re-applying state.
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
            DiagnosticsLog.shared.log("docklock", "FAILED to create event tap (Accessibility not granted?)")
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
        DiagnosticsLog.shared.log("docklock", "Event tap installed (Dock Lock active)")
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
        // No clamping when: Default (anchor 0), or only one screen is connected — on a
        // single-display Mac Dock Lock must never reserve edge pixels or fight the system Dock.
        let active = isEnabled && isAccessibilityTrusted && eventTap != nil
            && anchorDisplayID != 0 && isMultiDisplay
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
        let clamp: CGFloat
        switch edge {
        case .bottom: clamp = bounds.maxY - bandHeight
        case .left:   clamp = bounds.minX + bandHeight
        case .right:  clamp = bounds.maxX - bandHeight
        }
        return Self.exposedSegments(of: bounds, edge: edge, others: others)
            .map { TriggerZone(edge: edge, rangeMin: $0.0, rangeMax: $0.1, clamp: clamp) }
    }

    /// The stretches of `bounds`' Dock edge that no other display touches, as ranges along the edge
    /// (x for a bottom Dock, y for a side Dock). Only there can the pointer press past the edge and
    /// call up the Dock; elsewhere it just crosses onto the neighbouring display.
    nonisolated static func exposedSegments(of bounds: CGRect, edge: DockEdge,
                                            others: [CGRect]) -> [(CGFloat, CGFloat)] {
        let eps: CGFloat = 1.0
        let span: (CGFloat, CGFloat)
        let covered: [(CGFloat, CGFloat)]

        switch edge {
        case .bottom:
            span = (bounds.minX, bounds.maxX)
            covered = others
                .filter { abs($0.minY - bounds.maxY) <= eps }
                .map { (max($0.minX, bounds.minX), min($0.maxX, bounds.maxX)) }
        case .left:
            span = (bounds.minY, bounds.maxY)
            covered = others
                .filter { abs($0.maxX - bounds.minX) <= eps }
                .map { (max($0.minY, bounds.minY), min($0.maxY, bounds.maxY)) }
        case .right:
            span = (bounds.minY, bounds.maxY)
            covered = others
                .filter { abs($0.minX - bounds.maxX) <= eps }
                .map { (max($0.minY, bounds.minY), min($0.maxY, bounds.maxY)) }
        }

        return subtract(span: span, covered: covered).filter { $0.1 - $0.0 > 1 }
    }

    /// Subtract `covered` sub-intervals from `span`, returning the gaps.
    nonisolated private static func subtract(span: (CGFloat, CGFloat), covered: [(CGFloat, CGFloat)]) -> [(CGFloat, CGFloat)] {
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

    /// Reads the Dock's configured orientation from `com.apple.dock` via the shared
    /// `DockPrefs` snapshot (synchronize-first), the same source the popover anchoring uses.
    private func currentDockEdge() -> DockEdge {
        DockPrefs.read().orientation
    }

    // MARK: Displays

    @objc private func screenParametersChanged() {
        refreshDisplays()
        resolveAnchorFromPersisted()
    }

    /// Re-derive the live anchor after a display reconfig: the anchor the CURRENT set of displays
    /// remembers (#37). Stored choices are never touched here. The live ID and the clamp zones change
    /// at once; the Dock moves once, after the burst settles (a dock adds displays one at a time, and
    /// each in-between set is its own setup).
    private func resolveAnchorFromPersisted() {
        let resolved = persistedAnchorID() ?? 0
        if resolved != anchorDisplayID {
            // A move toward the old anchor (or none) no longer applies; the settled move below, if any,
            // takes the new one.
            moveTask?.cancel()
            moveState = .idle
            anchorDisplayID = resolved
            DiagnosticsLog.shared.log("docklock",
                "Setup of \(displays.count) displays → anchor \(anchorDisplay?.name ?? "none")")
        }
        recomputeZones()
        // Also when the anchor stayed (a MacBook anchored to its own screen, docked to a monitor set
        // as main): macOS may have moved the Dock.
        scheduleMoveAfterDisplayChange()
    }

    /// One move per burst of display changes (plugging in posts several), after the same settle the
    /// wake path uses. Only when an anchor is connected beside another display; `requestDockMove`
    /// re-checks that when it fires and skips the warp when the Dock is already home.
    private func scheduleMoveAfterDisplayChange() {
        displayChangeTask?.cancel()
        guard isEnabled, anchorDisplayID != 0, isMultiDisplay else { return }
        displayChangeTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            guard !Task.isCancelled else { return }
            self?.requestDockMove(reason: "displays_changed")
        }
    }

    // MARK: Is there anything to hold? (shared with the login spawner)

    /// A display setup's identity: exactly the displays connected, in any order (#37).
    nonisolated static func setupKey(_ connected: [String]) -> String {
        connected.sorted().joined(separator: ",")
    }

    /// The anchor UUID Dock Lock holds for the connected displays, or nil = leave the Dock alone
    /// (`DockLockSetupTests`). Nothing to hold on one display. A setup with its own entry uses it
    /// (`""` = Default). A setup without one falls back to the pre-#37 single anchor when that
    /// display is connected, else it is unknown → nil (owner, 2026-11-08). The login spawner uses
    /// the same rule, so nothing starts for Dock Lock on a setup that has nothing to hold.
    nonisolated static func resolveAnchor(connected: [String], remembered: [String: String],
                                          legacy: String?) -> String? {
        guard connected.count > 1 else { return nil }
        let anchor = remembered[setupKey(connected)] ?? legacy
        guard let anchor, connected.contains(anchor) else { return nil }
        return anchor
    }

    /// `remembered` after the user picks `anchor` (nil = Default) on the connected setup. Only that
    /// setup's entry changes; Default is stored as `""` so the pre-#37 anchor can't re-apply there.
    nonisolated static func remembered(_ remembered: [String: String], picking anchor: String?,
                                       connected: [String]) -> [String: String] {
        var result = remembered
        result[setupKey(connected)] = anchor ?? ""
        return result
    }

    /// `resolveAnchor` over what is stored: the one reader for the engine and the login spawner.
    nonisolated static func storedAnchor(_ defaults: UserDefaults, connected: [String]) -> String? {
        resolveAnchor(connected: connected, remembered: setupAnchors(defaults),
                      legacy: defaults.string(forKey: UserDefaultsKeys.dockLockAnchorUUID))
    }

    nonisolated private static func setupAnchors(_ defaults: UserDefaults) -> [String: String] {
        defaults.dictionary(forKey: UserDefaultsKeys.dockLockSetupAnchors) as? [String: String] ?? [:]
    }

    /// UUIDs of the displays in use, read from CoreGraphics so it works before an `NSApplication`
    /// exists (the login spawner). A display mirroring another is one surface, as `refreshDisplays`
    /// counts it.
    nonisolated static func connectedDisplayUUIDs() -> [String] {
        var count: UInt32 = 0
        guard CGGetActiveDisplayList(0, nil, &count) == .success, count > 0 else { return [] }
        var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
        guard CGGetActiveDisplayList(count, &ids, &count) == .success else { return [] }
        return ids.prefix(Int(count))
            .filter { CGDisplayMirrorsDisplay($0) == kCGNullDirectDisplay }
            .compactMap(displayUUID)
    }

    // MARK: Anchor persistence (stable across reboots/reconnects)

    /// The current setup's anchor resolved to a live display ID, or nil = leave the Dock alone.
    private func persistedAnchorID() -> CGDirectDisplayID? {
        guard let uuid = Self.storedAnchor(.standard, connected: Self.connectedDisplayUUIDs()) else { return nil }
        return displayID(forUUID: uuid)
    }

    /// Save the current anchor (or Default) for the current setup only.
    private func persistAnchor() {
        let defaults = UserDefaults.standard
        let uuid = anchorDisplayID == 0 ? nil : Self.displayUUID(anchorDisplayID)
        defaults.set(Self.remembered(Self.setupAnchors(defaults), picking: uuid, connected: Self.connectedDisplayUUIDs()),
                     forKey: UserDefaultsKeys.dockLockSetupAnchors)
    }

    /// One-time migration from the legacy raw-display-ID key to UUID-based storage.
    private func migrateLegacyAnchorIfNeeded() {
        let defaults = UserDefaults.standard
        guard defaults.string(forKey: UserDefaultsKeys.dockLockAnchorUUID) == nil else { return }
        let legacy = defaults.integer(forKey: UserDefaultsKeys.dockLockAnchorDisplay)
        defaults.removeObject(forKey: UserDefaultsKeys.dockLockAnchorDisplay)
        // Only carry the choice forward if that exact display is still connected; otherwise the
        // raw ID is meaningless and we start from "Default".
        guard legacy > 0,
              displays.contains(where: { $0.id == CGDirectDisplayID(legacy) }),
              let uuid = Self.displayUUID(CGDirectDisplayID(legacy)) else { return }
        defaults.set(uuid, forKey: UserDefaultsKeys.dockLockAnchorUUID)
    }

    /// Stable UUID string for a display, via `CGDisplayCreateUUIDFromDisplayID`.
    nonisolated private static func displayUUID(_ id: CGDirectDisplayID) -> String? {
        guard let cf = CGDisplayCreateUUIDFromDisplayID(id)?.takeRetainedValue() else { return nil }
        return CFUUIDCreateString(nil, cf) as String?
    }

    /// Resolve a stored UUID back to a live display ID by scanning online displays.
    private func displayID(forUUID uuid: String) -> CGDirectDisplayID? {
        guard let target = CFUUIDCreateFromString(nil, uuid as CFString) else { return nil }
        var count: UInt32 = 0
        guard CGGetOnlineDisplayList(0, nil, &count) == .success, count > 0 else { return nil }
        var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
        guard CGGetOnlineDisplayList(count, &ids, &count) == .success else { return nil }
        for id in ids {
            guard let cf = CGDisplayCreateUUIDFromDisplayID(id)?.takeRetainedValue() else { continue }
            if CFEqual(cf, target) { return id }
        }
        return nil
    }

    private func refreshDisplays() {
        let main = CGMainDisplayID()
        displays = NSScreen.screens.compactMap { screen in
            guard let id = screen.displayID else { return nil }
            // Skip a display that is *mirroring* another: a mirror set shows one identical image,
            // so it's effectively a single surface. Excluding the secondaries means the picker
            // never lists a duplicate anchor, `isMultiDisplay` doesn't count phantom screens, and
            // a fully-mirrored setup correctly reads as single-display (Dock Lock stays inert).
            // The primary of each set reports `kCGNullDirectDisplay` here and is kept.
            guard CGDisplayMirrorsDisplay(id) == kCGNullDirectDisplay else { return nil }
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

    @objc private func systemDidWake() {
        // Re-assert the Dock onto the anchor — no-op when Default, single-display, or already home.
        // Small delay: displays/Dock settle a moment after wake before the relocation will take.
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            self?.requestDockMove(reason: "system_wake")
        }
    }

    @objc private func dockDidRestart() {
        // The relaunched Dock can reappear on a different display. Re-assert once it has settled.
        // `requestDockMove` skips the warp entirely when the Dock is already on the anchor, so a
        // routine tile toggle that left the Dock in place costs nothing.
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            self?.requestDockMove(reason: "dock_restart")
        }
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
