import Testing
@testable import Dock_Tile

/// `popover.animates` was hardcoded `true`, so Animation = None and system Reduce Motion both still
/// got AppKit's ~0.5 s appearance animation. Failing value: `true` for either of those inputs.
@Suite("Popover appearance animation")
struct FloatingPanelAnimationTests {

    @Test("Reduce Motion always wins")
    func reduceMotionDisablesAnimation() {
        #expect(FloatingPanel.shouldAnimate(tier: .default, reduceMotion: true) == false)
        #expect(FloatingPanel.shouldAnimate(tier: .fast, reduceMotion: true) == false)
        #expect(FloatingPanel.shouldAnimate(tier: .none, reduceMotion: true) == false)
    }

    @Test("The None tier disables animation; Default and Fast keep it")
    func tierControlsAnimation() {
        #expect(FloatingPanel.shouldAnimate(tier: .none, reduceMotion: false) == false)
        #expect(FloatingPanel.shouldAnimate(tier: .default, reduceMotion: false) == true)
        #expect(FloatingPanel.shouldAnimate(tier: .fast, reduceMotion: false) == true)
    }
}
