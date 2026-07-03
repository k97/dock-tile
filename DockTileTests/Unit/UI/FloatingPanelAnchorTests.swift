//
//  FloatingPanelAnchorTests.swift
//  DockTileTests
//
//  Guards the popover anchoring rules behind every helper tile's Dock popover — the source
//  of the "popover overlaps the magnified Dock icon" regression. Two pure seams:
//
//  1. `FloatingPanel.resolveAnchor` — where the popover pins, given plain screen/pref values.
//     The critical rows: magnification lifts the anchor to the `largesize + 25` envelope
//     (AX/CGWindow/CoreDock all report only the RESTING layout while icons are magnified,
//     so the worst-case envelope is the only reliable clearance — and the clicked icon is
//     under the cursor, so it IS at full largesize); an auto-hidden Dock reserves zero
//     visibleFrame, so clearance must fall back to the tilesize pref, never the raw edge.
//  2. `DockPrefs.resolve` — the defaults/clamping parser for another app's domain. Absent
//     keys get macOS defaults (bottom / 48 / 128 / off); `defaults write` garbage
//     (largesize 9999) must clamp before it reaches geometry.
//
//  Baseline values mirror the machine the bug was reproduced on: 1352×878 screen,
//  64pt Dock gap (tilesize 44), magnification to 71.
//

import AppKit
import Testing
@testable import Dock_Tile

@Suite("Popover anchor resolution")
struct FloatingPanelAnchorTests {

    // MARK: - Baseline geometry (bottom Dock, magnification repro machine)

    private let screen = CGRect(x: 0, y: 0, width: 1352, height: 878)
    private let visible = CGRect(x: 0, y: 64, width: 1352, height: 784)
    private let mouse = CGPoint(x: 654, y: 840)

    private func prefs(
        orientation: DockEdge = .bottom,
        magnification: Bool = false,
        tile: CGFloat = 44,
        large: CGFloat = 71,
        autohide: Bool = false
    ) -> DockPrefs {
        DockPrefs(
            orientation: orientation,
            magnificationEnabled: magnification,
            tileSize: tile,
            largeSize: large,
            autohide: autohide
        )
    }

    // MARK: - resolveAnchor: magnification (bottom Dock)

    @Test("Magnification off → anchor exactly at the measured Dock gap")
    func magnificationOffUsesMeasuredGap() {
        let anchor = FloatingPanel.resolveAnchor(
            screenFrame: screen, visibleFrame: visible, mouse: mouse,
            prefs: prefs(magnification: false)
        )
        #expect(anchor.point == CGPoint(x: 654, y: 64))
        #expect(anchor.edge == .minY)
    }

    @Test("Magnification on → anchor lifts to the largesize + 25 envelope")
    func magnificationLiftsToLargesizeEnvelope() {
        let anchor = FloatingPanel.resolveAnchor(
            screenFrame: screen, visibleFrame: visible, mouse: mouse,
            prefs: prefs(magnification: true)
        )
        // 71 (largesize) + 25 (padding) = 96 > 64 (measured gap)
        #expect(anchor.point == CGPoint(x: 654, y: 96))
        #expect(anchor.edge == .minY)
    }

    @Test("Magnification with largesize ≤ tilesize is a no-op (icons don't grow)")
    func magnificationSmallerThanTileDoesNotLift() {
        let anchor = FloatingPanel.resolveAnchor(
            screenFrame: screen, visibleFrame: visible, mouse: mouse,
            prefs: prefs(magnification: true, tile: 44, large: 40)
        )
        #expect(anchor.point == CGPoint(x: 654, y: 64))
    }

    @Test("Measured gap larger than the magnified envelope wins (crowded-Dock self-correction)")
    func largerMeasuredGapWins() {
        let tallDock = CGRect(x: 0, y: 130, width: 1352, height: 718)
        let anchor = FloatingPanel.resolveAnchor(
            screenFrame: screen, visibleFrame: tallDock, mouse: mouse,
            prefs: prefs(magnification: true)
        )
        // measured 130 > 71 + 25 = 96
        #expect(anchor.point == CGPoint(x: 654, y: 130))
    }

    @Test("Garbage largesize is capped to a fraction of the screen")
    func insaneLargesizeIsCapped() {
        let anchor = FloatingPanel.resolveAnchor(
            screenFrame: screen, visibleFrame: visible, mouse: mouse,
            prefs: prefs(magnification: true, large: 512)
        )
        // 512 + 25 = 537 caps at 878 × 0.4
        #expect(anchor.point.y == 878 * 0.4)
    }

    // MARK: - resolveAnchor: autohide (visibleFrame reserves nothing)

    @Test("Autohidden Dock → clearance derives from the tilesize pref, not the zero gap")
    func autohideFallsBackToTileSize() {
        let noGap = CGRect(x: 0, y: 0, width: 1352, height: 848) // only the menu bar reserved
        let anchor = FloatingPanel.resolveAnchor(
            screenFrame: screen, visibleFrame: noGap, mouse: mouse,
            prefs: prefs(autohide: true)
        )
        // 44 (tilesize) + 25 (padding) = 69
        #expect(anchor.point == CGPoint(x: 654, y: 69))
        #expect(anchor.edge == .minY)
    }

    @Test("Autohidden Dock with magnification → still the largesize envelope")
    func autohideWithMagnificationUsesEnvelope() {
        let noGap = CGRect(x: 0, y: 0, width: 1352, height: 848)
        let anchor = FloatingPanel.resolveAnchor(
            screenFrame: screen, visibleFrame: noGap, mouse: mouse,
            prefs: prefs(magnification: true, autohide: true)
        )
        #expect(anchor.point == CGPoint(x: 654, y: 96))
    }

    // MARK: - resolveAnchor: left/right Docks (axes rotate)

    @Test("Left Dock → clearance on X, mouse drives Y, arrow points left")
    func leftDockRotatesAxes() {
        let leftVisible = CGRect(x: 64, y: 0, width: 1288, height: 848)
        let anchor = FloatingPanel.resolveAnchor(
            screenFrame: screen, visibleFrame: leftVisible, mouse: CGPoint(x: 10, y: 400),
            prefs: prefs(orientation: .left)
        )
        #expect(anchor.point == CGPoint(x: 64, y: 400))
        #expect(anchor.edge == .minX)
    }

    @Test("Left Dock magnified → X lifts to the envelope")
    func leftDockMagnifiedLiftsX() {
        let leftVisible = CGRect(x: 64, y: 0, width: 1288, height: 848)
        let anchor = FloatingPanel.resolveAnchor(
            screenFrame: screen, visibleFrame: leftVisible, mouse: CGPoint(x: 10, y: 400),
            prefs: prefs(orientation: .left, magnification: true)
        )
        #expect(anchor.point == CGPoint(x: 96, y: 400))
    }

    @Test("Right Dock magnified → anchor insets from maxX, arrow points right")
    func rightDockInsetsFromMaxX() {
        let rightVisible = CGRect(x: 0, y: 0, width: 1288, height: 848)
        let anchor = FloatingPanel.resolveAnchor(
            screenFrame: screen, visibleFrame: rightVisible, mouse: CGPoint(x: 1340, y: 400),
            prefs: prefs(orientation: .right, magnification: true)
        )
        // 1352 − (71 + 25) = 1256
        #expect(anchor.point == CGPoint(x: 1256, y: 400))
        #expect(anchor.edge == .maxX)
    }

    @Test("Autohidden left Dock → tilesize fallback on the X axis")
    func autohiddenLeftDockFallsBackOnX() {
        let noGap = CGRect(x: 0, y: 0, width: 1352, height: 848)
        let anchor = FloatingPanel.resolveAnchor(
            screenFrame: screen, visibleFrame: noGap, mouse: CGPoint(x: 10, y: 400),
            prefs: prefs(orientation: .left, autohide: true)
        )
        #expect(anchor.point == CGPoint(x: 69, y: 400))
    }

    // MARK: - resolveAnchor: mouse clamping

    @Test("Mouse beyond the left screen edge clamps to minX")
    func mouseClampsToScreenMin() {
        let anchor = FloatingPanel.resolveAnchor(
            screenFrame: screen, visibleFrame: visible, mouse: CGPoint(x: -50, y: 840),
            prefs: prefs()
        )
        #expect(anchor.point == CGPoint(x: 0, y: 64))
    }

    @Test("Mouse beyond the right screen edge clamps to maxX")
    func mouseClampsToScreenMax() {
        let anchor = FloatingPanel.resolveAnchor(
            screenFrame: screen, visibleFrame: visible, mouse: CGPoint(x: 2000, y: 840),
            prefs: prefs()
        )
        #expect(anchor.point == CGPoint(x: 1352, y: 64))
    }

    // MARK: - DockPrefs.resolve: defaults and clamping

    @Test("Absent keys resolve to macOS defaults (bottom / 48 / 128 / off / off)")
    func absentKeysResolveToDefaults() {
        let resolved = DockPrefs.resolve(
            orientation: nil, magnification: nil, tileSize: nil, largeSize: nil, autohide: nil
        )
        #expect(resolved == DockPrefs(
            orientation: .bottom,
            magnificationEnabled: false,
            tileSize: 48,
            largeSize: 128,
            autohide: false
        ))
    }

    @Test("Orientation strings map exactly; garbage falls back to bottom")
    func orientationStringMapping() {
        #expect(DockPrefs.resolve(orientation: "left", magnification: nil, tileSize: nil, largeSize: nil, autohide: nil).orientation == .left)
        #expect(DockPrefs.resolve(orientation: "right", magnification: nil, tileSize: nil, largeSize: nil, autohide: nil).orientation == .right)
        #expect(DockPrefs.resolve(orientation: "bottom", magnification: nil, tileSize: nil, largeSize: nil, autohide: nil).orientation == .bottom)
        #expect(DockPrefs.resolve(orientation: "top", magnification: nil, tileSize: nil, largeSize: nil, autohide: nil).orientation == .bottom)
    }

    @Test("Out-of-range sizes clamp to the ranges macOS accepts")
    func sizesClampToAcceptedRanges() {
        let low = DockPrefs.resolve(orientation: nil, magnification: nil, tileSize: 4, largeSize: 4, autohide: nil)
        #expect(low.tileSize == 16)
        #expect(low.largeSize == 16)

        let high = DockPrefs.resolve(orientation: nil, magnification: nil, tileSize: 300, largeSize: 9999, autohide: nil)
        #expect(high.tileSize == 128)   // GUI slider ceiling
        #expect(high.largeSize == 512)  // defaults-write ceiling
    }

    @Test("Set values pass through untouched")
    func setValuesPassThrough() {
        let resolved = DockPrefs.resolve(
            orientation: "right", magnification: true, tileSize: 44, largeSize: 71, autohide: true
        )
        #expect(resolved == DockPrefs(
            orientation: .right,
            magnificationEnabled: true,
            tileSize: 44,
            largeSize: 71,
            autohide: true
        ))
    }
}
