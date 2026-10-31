//
//  TileRebuildBar.swift
//  DockTile
//
//  The progress bar a tile shows on its own Dock icon while the main app rebuilds it (2.6.3).
//  The main app posts stage signals (`TileRebuildSignal`); the running helper draws a darkened
//  icon with a bar filling along its bottom and ignores clicks while it shows. A Ghost helper is
//  switched to `.regular` for those seconds: as `.accessory` its NSDockTile never reaches the
//  pinned icon (measured on macOS 15, 26 and 27, docs/superpowers/specs/
//  2026-10-30-tile-rebuild-progress-design.md). The decisions live in the pure seams below.
//  Swift 6 - Strict Concurrency
//

import AppKit

/// One step of a staged rebuild, posted by the main app in this order (`cancelled` on failure).
enum TileRebuildStage: String, Sendable {
    case begin, copied, iconsBuilt, signed, ready, cancelled
}

/// The main app → helper protocol: a distributed notification whose object is the tile's bundle id,
/// so dev and release tiles (different id prefixes) never hear each other. Any local process can
/// post it; the worst it can do is freeze a tile's clicks for `RebuildBarState.timeout`.
enum TileRebuildSignal {
    static let name = Notification.Name("com.docktile.tileRebuild")
    static let stageKey = "stage"

    /// How full the bar is once a stage is reached; `nil` clears it.
    static func fraction(for stage: TileRebuildStage) -> Double? {
        switch stage {
        case .begin: 0.05
        case .copied: 0.30
        case .iconsBuilt: 0.65
        case .signed: 0.90
        case .ready: 1.0
        case .cancelled: nil
        }
    }

    static func userInfo(_ stage: TileRebuildStage) -> [String: String] {
        [stageKey: stage.rawValue]
    }

    static func stage(from userInfo: [AnyHashable: Any]?) -> TileRebuildStage? {
        (userInfo?[stageKey] as? String).flatMap(TileRebuildStage.init(rawValue:))
    }
}

/// What the helper shows. Pure, so the rules that matter are tested: the bar never moves back, a
/// silent main app (crashed, force-quit) releases the tile after `timeout`, and easing lands.
struct RebuildBarState: Equatable, Sendable {
    static let idle = RebuildBarState(target: nil, lastSignalAt: 0)
    /// Longer than any one stage takes; a stage that runs longer only blinks the bar.
    static let timeout: CFAbsoluteTime = 30

    var target: Double?
    var lastSignalAt: CFAbsoluteTime

    var isShowing: Bool { target != nil }
    /// Clicks, ⌘Tab activation and the custom Dock menu are ignored while the bar shows.
    var ignoresInteraction: Bool { isShowing }

    func applying(_ stage: TileRebuildStage, now: CFAbsoluteTime) -> RebuildBarState {
        guard let fraction = TileRebuildSignal.fraction(for: stage) else { return .idle }
        return RebuildBarState(target: max(target ?? 0, fraction), lastSignalAt: now)
    }

    func isExpired(now: CFAbsoluteTime) -> Bool {
        isShowing && now - lastSignalAt > Self.timeout
    }

    /// One animation tick toward `target`. Snaps the last few thousandths: an exponential approach
    /// alone never lands in floating point, which would keep the animation timer alive.
    static func eased(from current: Double, to target: Double, dt: Double, reduceMotion: Bool) -> Double {
        guard !reduceMotion else { return target }
        let next = current + (target - current) * min(1, dt / 0.12)
        if abs(target - next) < 0.005 { return target }
        return target >= current ? min(next, target) : max(next, target)
    }
}

/// The tile while it rebuilds (style C, picked by the owner): the icon at full bounds (it already
/// carries the icon-grid margin, so it is never inset again), the icon shape darkened, and a white
/// bar filling along the shape's bottom.
final class RebuildTileView: NSView {
    private let icon: NSImage
    var progress: Double = 0

    init(icon: NSImage) {
        self.icon = icon
        super.init(frame: NSRect(x: 0, y: 0, width: 128, height: 128))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    /// The icon shape inside the full tile: the icon grid's content inset on each side.
    nonisolated static func shapeRect(in bounds: NSRect) -> NSRect {
        bounds.insetBy(dx: bounds.width * IconDepthMetrics.contentInsetRatio,
                       dy: bounds.height * IconDepthMetrics.contentInsetRatio)
    }

    /// The bar's track: inset 14% from the shape's sides, 9% of its height, 12% above its bottom.
    nonisolated static func barRect(in bounds: NSRect) -> NSRect {
        let shape = shapeRect(in: bounds)
        let inset = shape.width * 0.14
        return NSRect(x: shape.minX + inset, y: shape.minY + shape.height * 0.12,
                      width: shape.width - 2 * inset, height: shape.height * 0.09)
    }

    override func draw(_ dirtyRect: NSRect) {
        icon.draw(in: bounds)

        let shape = Self.shapeRect(in: bounds)
        let radius = shape.width * 0.225
        NSColor.black.withAlphaComponent(0.45).setFill()
        NSBezierPath(roundedRect: shape, xRadius: radius, yRadius: radius).fill()

        let track = Self.barRect(in: bounds)
        let capsule = track.height / 2
        NSColor.black.withAlphaComponent(0.35).setFill()
        NSBezierPath(roundedRect: track, xRadius: capsule, yRadius: capsule).fill()

        var fill = track
        fill.size.width = max(track.height, track.width * min(max(progress, 0), 1))
        NSColor.white.setFill()
        NSBezierPath(roundedRect: fill, xRadius: capsule, yRadius: capsule).fill()
    }
}

/// Runs the bar inside a helper. No timer exists while no bar shows: the observer is event-driven,
/// the animation timer runs only while the drawn value moves, and expiry is one work item
/// rescheduled per signal.
@MainActor
final class TileRebuildPresenter {
    private let bundleId: String
    private let hidePopover: @MainActor () -> Void
    private var state = RebuildBarState.idle
    private var displayed: Double = 0
    private var view: RebuildTileView?
    private var policyBeforeBar: NSApplication.ActivationPolicy?
    private var animationTimer: Timer?
    private var expiry: DispatchWorkItem?
    private var observer: NSObjectProtocol?

    private static let frameInterval: TimeInterval = 1.0 / 20

    init(bundleId: String, hidePopover: @escaping @MainActor () -> Void) {
        self.bundleId = bundleId
        self.hidePopover = hidePopover
    }

    var ignoresInteraction: Bool { state.ignoresInteraction }

    func start() {
        observer = DistributedNotificationCenter.default().addObserver(
            forName: TileRebuildSignal.name, object: bundleId, queue: .main
        ) { [weak self] notification in
            // Parse here (nonisolated, value in hand); never send the Notification across.
            guard let stage = TileRebuildSignal.stage(from: notification.userInfo) else { return }
            MainActor.assumeIsolated { self?.receive(stage) }
        }
    }

    private func receive(_ stage: TileRebuildStage) {
        DiagnosticsLog.shared.log("helper", "Rebuild stage: \(stage.rawValue)", verbose: true)
        let wasShowing = state.isShowing
        state = state.applying(stage, now: CFAbsoluteTimeGetCurrent())
        guard state.isShowing else {
            if wasShowing { clear(reason: "cancelled") }
            return
        }
        if !wasShowing { show() }
        scheduleExpiry()
        if animationTimer == nil { startAnimating() }
    }

    private func show() {
        hidePopover()
        let policy = NSApp.activationPolicy()
        policyBeforeBar = policy
        if policy == .accessory { NSApp.setActivationPolicy(.regular) }
        let view = RebuildTileView(icon: NSApp.applicationIconImage)
        displayed = 0
        view.progress = 0
        self.view = view
        NSApp.dockTile.contentView = view
        NSApp.dockTile.display()
    }

    private func startAnimating() {
        animationTimer = Timer.scheduledTimer(withTimeInterval: Self.frameInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
    }

    private func tick() {
        guard let target = state.target, let view else { stopAnimating(); return }
        displayed = RebuildBarState.eased(
            from: displayed, to: target, dt: Self.frameInterval,
            reduceMotion: NSWorkspace.shared.accessibilityDisplayShouldReduceMotion)
        view.progress = displayed
        view.needsDisplay = true
        NSApp.dockTile.display()
        if displayed == target { stopAnimating() }
    }

    private func stopAnimating() {
        animationTimer?.invalidate()
        animationTimer = nil
    }

    private func scheduleExpiry() {
        expiry?.cancel()
        let item = DispatchWorkItem { [weak self] in
            MainActor.assumeIsolated {
                guard let self, self.state.isExpired(now: CFAbsoluteTimeGetCurrent()) else { return }
                self.state = .idle
                self.clear(reason: "timed out")
            }
        }
        expiry = item
        DispatchQueue.main.asyncAfter(deadline: .now() + RebuildBarState.timeout + 0.5, execute: item)
    }

    private func clear(reason: String) {
        stopAnimating()
        expiry?.cancel()
        expiry = nil
        view = nil
        NSApp.dockTile.contentView = nil
        NSApp.dockTile.display()
        if let policy = policyBeforeBar, policy != NSApp.activationPolicy() {
            NSApp.setActivationPolicy(policy)
        }
        policyBeforeBar = nil
        DiagnosticsLog.shared.log("helper", "Rebuild bar cleared (\(reason))")
    }
}
