import AppKit
import Testing
@testable import Dock_Tile

/// The 2.6.3 rebuild bar: the main app signals stages, the running helper draws a darkened tile with
/// a bar filling along its bottom and ignores clicks while it shows. Failing values: a bar that moves
/// backwards on a late signal, one that never clears when the main app dies (no expiry), an easing
/// that never lands (keeps the animation timer alive), and a double icon-grid inset (the icon's own
/// margin inset a second time).
@Suite("Tile rebuild bar")
struct TileRebuildBarTests {

    @Test("Stages fill the bar in order; cancelled has no fraction")
    func fractionsRiseThroughTheStages() {
        let stages: [TileRebuildStage] = [.begin, .copied, .iconsBuilt, .signed, .ready]
        #expect(stages.map { TileRebuildSignal.fraction(for: $0) } == [0.05, 0.30, 0.65, 0.90, 1.0])
        #expect(TileRebuildSignal.fraction(for: .cancelled) == nil)
    }

    @Test("A stage survives the notification's userInfo; junk reads as no stage")
    func signalRoundTrips() {
        #expect(TileRebuildSignal.stage(from: TileRebuildSignal.userInfo(.signed)) == .signed)
        #expect(TileRebuildSignal.stage(from: nil) == nil)
        #expect(TileRebuildSignal.stage(from: ["stage": "bogus"]) == nil)
    }

    @Test("A late, lower stage never moves the bar back, but still counts as a sign of life")
    func barNeverMovesBackwards() {
        let state = RebuildBarState.idle.applying(.signed, now: 1).applying(.copied, now: 2)
        #expect(state.target == 0.90)
        #expect(state.lastSignalAt == 2)
    }

    @Test("Cancelled clears the bar from any stage")
    func cancelledClearsTheBar() {
        for stage in [TileRebuildStage.begin, .iconsBuilt, .ready] {
            let cleared = RebuildBarState.idle.applying(stage, now: 5).applying(.cancelled, now: 6)
            #expect(cleared == .idle)
            #expect(cleared.isShowing == false)
            #expect(cleared.ignoresInteraction == false)
        }
    }

    @Test("While the bar shows, clicks are ignored")
    func showingIgnoresInteraction() {
        #expect(RebuildBarState.idle.ignoresInteraction == false)
        #expect(RebuildBarState.idle.applying(.begin, now: 0).ignoresInteraction == true)
    }

    @Test("Thirty seconds without a signal expires the bar; an idle bar never expires")
    func expiresAfterThirtySecondsOfSilence() {
        let showing = RebuildBarState.idle.applying(.copied, now: 100)
        #expect(showing.isExpired(now: 129.9) == false)
        #expect(showing.isExpired(now: 130.1) == true)
        #expect(RebuildBarState.idle.isExpired(now: 1e9) == false)
    }

    @Test("Easing lands exactly on the target, never past it; Reduce Motion jumps")
    func easingReachesTheTargetExactly() {
        var value = 0.05
        var landedAt: Int?
        for step in 1...20 {
            value = RebuildBarState.eased(from: value, to: 0.30, dt: 1.0 / 20, reduceMotion: false)
            #expect(value <= 0.30)
            if value == 0.30 { landedAt = step; break }
        }
        #expect(landedAt != nil)
        #expect(RebuildBarState.eased(from: 0.05, to: 0.30, dt: 1.0 / 20, reduceMotion: true) == 0.30)
    }

    @Test("The view darkens only the icon shape and fills the bar to its progress")
    @MainActor
    func viewDrawsTheBarToItsProgress() throws {
        let size = NSSize(width: 128, height: 128)
        let icon = NSImage(size: size, flipped: false) { rect in
            NSColor(srgbRed: 0, green: 1, blue: 0, alpha: 1).setFill()
            rect.fill()
            NSColor(srgbRed: 1, green: 0, blue: 0, alpha: 1).setFill()
            rect.insetBy(dx: 3, dy: 3).fill()
            return true
        }
        let view = RebuildTileView(icon: icon)
        view.frame = NSRect(origin: .zero, size: size)
        view.progress = 0.5
        let rep = try #require(view.bitmapImageRepForCachingDisplay(in: view.bounds))
        view.cacheDisplay(in: view.bounds, to: rep)

        // Points in view coordinates; NSBitmapImageRep.colorAt is top-left origin, in pixels.
        func color(_ p: NSPoint) throws -> NSColor {
            let sx = CGFloat(rep.pixelsWide) / size.width, sy = CGFloat(rep.pixelsHigh) / size.height
            let c = try #require(rep.colorAt(x: Int(p.x * sx), y: Int((size.height - p.y) * sy)))
            return try #require(c.usingColorSpace(.sRGB))
        }
        let bar = RebuildTileView.barRect(in: view.bounds)
        let shape = RebuildTileView.shapeRect(in: view.bounds)

        let filled = try color(NSPoint(x: bar.minX + bar.width * 0.3, y: bar.midY))
        #expect(filled.redComponent > 0.9 && filled.greenComponent > 0.9 && filled.blueComponent > 0.9)
        let empty = try color(NSPoint(x: bar.minX + bar.width * 0.8, y: bar.midY))
        #expect(empty.greenComponent < 0.5)
        let centre = try color(NSPoint(x: shape.midX, y: shape.midY))
        #expect(centre.redComponent < 0.7)
        // The icon is drawn at full bounds (it already carries the icon-grid margin): its outer
        // green border survives, undarkened, outside the shape.
        let edge = try color(NSPoint(x: 1, y: 64))
        #expect(edge.greenComponent > 0.8)
    }
}
