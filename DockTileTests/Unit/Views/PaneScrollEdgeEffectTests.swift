import Testing
import CoreGraphics
@testable import Dock_Tile

/// The title band has no toolbar surface (v2 chrome), so scrolled content collides with it.
/// `PaneScrollEdgeEffect` fades a material scrim in behind the band as content scrolls under —
/// the Apple Notes treatment. The ramp is the regression-prone decision: it must be OFF at rest
/// (the band stays chromeless, the v2 look), fully on once content is genuinely underneath,
/// and never triggered by rubber-band overscroll above the top.
struct PaneScrollEdgeEffectTests {

    @Test("At rest the scrim is fully off — the band stays chromeless")
    func offAtRest() {
        #expect(PaneScrollEdgeEffect.opacity(forOffset: 0) == 0)
    }

    @Test("Rubber-band overscroll above the top never shows the scrim")
    func offDuringOverscroll() {
        #expect(PaneScrollEdgeEffect.opacity(forOffset: -80) == 0)
    }

    @Test("Halfway through the ramp the scrim is at half strength — the fade is continuous, not a pop")
    func linearMidRamp() {
        #expect(PaneScrollEdgeEffect.opacity(forOffset: 12, ramp: 24) == 0.5)
    }

    @Test("At the ramp distance the scrim is fully on")
    func fullAtRamp() {
        #expect(PaneScrollEdgeEffect.opacity(forOffset: 24, ramp: 24) == 1)
    }

    @Test("Deep scroll stays clamped at full strength")
    func clampedBeyondRamp() {
        #expect(PaneScrollEdgeEffect.opacity(forOffset: 5000) == 1)
    }
}
