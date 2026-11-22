//
//  IconLiftTests.swift
//  DockTileTests
//
//  The App Store-style lift (rim + shadow) on every tile icon in the app scales with the icon's
//  size. The 122 pt row pins the hero tier (64 pt and up, e.g. the 163 pt Tile Detail hero): Dark as shipped (rim 1, shadow 8 / 4, 0.45), Light
//  matched to the App Store's measured edge (shadow 3 / 1.5 at 0.22, no hairline — 2026-10-21). The
//  old Light values (8 / 4 + a 0.5 hairline) fail it.
//

import Testing
import CoreGraphics
@testable import Dock_Tile

@Suite("Icon lift metrics")
struct IconLiftTests {

    @Test("Hero tier (122 pt): Dark as shipped, Light a tight App Store shadow with no hairline")
    func hero() {
        #expect(IconLift.metrics(size: 122) == IconLift.Metrics(rimWidth: 1, shadowRadius: 8, shadowY: 4,
                                                                 darkOpacity: 0.45, lightRadius: 3, lightY: 1.5,
                                                                 lightOpacity: 0.22, lightHairline: 0))
    }

    @Test("Small icons get a hairline rim and a scaled, fainter shadow", arguments: [
        (CGFloat(58), CGFloat(4), CGFloat(2)),
        (CGFloat(44), CGFloat(3), CGFloat(1.5)),
        (CGFloat(32), CGFloat(2), CGFloat(1)),
        (CGFloat(24), CGFloat(1.5), CGFloat(1))
    ])
    func small(size: CGFloat, radius: CGFloat, y: CGFloat) {
        #expect(IconLift.metrics(size: size) == IconLift.Metrics(rimWidth: 0.5, shadowRadius: radius, shadowY: y,
                                                                  darkOpacity: 0.32, lightRadius: radius, lightY: y,
                                                                  lightOpacity: 0.14, lightHairline: 0.5))
    }

    @Test("64 pt is the first size drawn like the hero")
    func threshold() {
        #expect(IconLift.metrics(size: 63).rimWidth == 0.5)
        #expect(IconLift.metrics(size: 64).rimWidth == 1)
        #expect(IconLift.metrics(size: 64).darkOpacity == 0.45)
    }
}
