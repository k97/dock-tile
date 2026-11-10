//
//  DockLockEdgePointTests.swift
//  DockTileTests
//
//  Where Dock Lock presses the pointer to call the Dock onto its display, across display layouts.
//  macOS brings the Dock onto a display only through a stretch of its Dock edge that no other
//  display touches; a fully covered edge can never host it, and with "Displays have separate
//  Spaces" off the Dock never leaves the main display. The first case is measured on the owner's
//  desk (2026-11-10): a laptop under the middle of an ultrawide, where pressing at the edge's
//  middle crossed onto the laptop and every move failed.
//

import CoreGraphics
import Testing
@testable import Dock_Tile

@Suite("Dock Lock move plan across layouts")
struct DockLockEdgePointTests {
    let ultrawide = CGRect(x: 0, y: 0, width: 3440, height: 1440)
    let laptop = CGRect(x: 895, y: 1440, width: 1512, height: 982)

    private func plan(_ anchor: CGRect, _ others: [CGRect], edge: DockEdge = .bottom,
                      main: Bool = false, spaces: Bool = true) -> DockLockManager.MovePlan {
        DockLockManager.movePlan(anchor: anchor, anchorIsMain: main, others: others,
                                 edge: edge, separateSpaces: spaces)
    }

    @Test("Laptop under the middle of an ultrawide: both side stretches, widest first")
    func laptopUnderTheMiddle() {
        let segments = DockLockManager.exposedSegments(of: ultrawide, edge: .bottom, others: [laptop])
        #expect(segments.map { [$0.0, $0.1] } == [[0, 895], [2407, 3440]])
        #expect(plan(ultrawide, [laptop]) == .push([CGPoint(x: 2923.5, y: 1439), CGPoint(x: 447.5, y: 1439)]))
    }

    @Test("Nothing below: the middle of the edge")
    func freeEdge() {
        #expect(plan(laptop, [ultrawide]) == .push([CGPoint(x: 1651, y: 2421)]))
    }

    @Test("Side by side: the bottom edge is free")
    func sideBySide() {
        let left = CGRect(x: 0, y: 0, width: 1920, height: 1080)
        let right = CGRect(x: 1920, y: 0, width: 2560, height: 1440)
        #expect(plan(left, [right]) == .push([CGPoint(x: 960, y: 1079)]))
    }

    @Test("Two equal displays stacked: the upper one's edge is covered")
    func stackedEqual() {
        let top = CGRect(x: 0, y: 0, width: 2560, height: 1440)
        let bottom = CGRect(x: 0, y: 1440, width: 2560, height: 1440)
        #expect(plan(top, [bottom]) == .edgeCovered)
        #expect(plan(bottom, [top]) == .push([CGPoint(x: 1280, y: 2879)]))
    }

    @Test("A wider display below covers the whole edge")
    func widerBelow() {
        let below = CGRect(x: -100, y: 1440, width: 4000, height: 1000)
        #expect(plan(ultrawide, [below]) == .edgeCovered)
    }

    @Test("Stacked, offset sideways: the stretch the offset leaves free")
    func stackedOffset() {
        let top = CGRect(x: 0, y: 0, width: 2560, height: 1440)
        let bottom = CGRect(x: 200, y: 1440, width: 2560, height: 1440)
        #expect(plan(top, [bottom]) == .push([CGPoint(x: 100, y: 1439)]))
    }

    @Test("Smaller display under one end: the rest of the edge")
    func smallerUnderOneEnd() {
        let below = CGRect(x: 0, y: 1440, width: 1512, height: 982)
        #expect(plan(ultrawide, [below]) == .push([CGPoint(x: 2476, y: 1439)]))
    }

    @Test("Three displays: a laptop under the seam of two monitors leaves each its outer stretch")
    func laptopUnderTheSeam() {
        let a = CGRect(x: 0, y: 0, width: 1920, height: 1080)
        let b = CGRect(x: 1920, y: 0, width: 1920, height: 1080)
        let seamLaptop = CGRect(x: 1164, y: 1080, width: 1512, height: 982)
        #expect(plan(a, [b, seamLaptop]) == .push([CGPoint(x: 582, y: 1079)]))
        #expect(plan(b, [a, seamLaptop]) == .push([CGPoint(x: 3258, y: 1079)]))
    }

    @Test("A display touching only at a corner covers nothing")
    func cornerOnly() {
        let corner = CGRect(x: 3440, y: 1440, width: 1512, height: 982)
        #expect(plan(ultrawide, [corner]) == .push([CGPoint(x: 1720, y: 1439)]))
    }

    @Test("A 2 pt sliver still counts; 1 pt does not")
    func slivers() {
        let leaves2 = CGRect(x: 2, y: 1440, width: 3438, height: 900)
        #expect(plan(ultrawide, [leaves2]) == .push([CGPoint(x: 1, y: 1439)]))
        let leaves1 = CGRect(x: 1, y: 1440, width: 3439, height: 900)
        #expect(plan(ultrawide, [leaves1]) == .edgeCovered)
    }

    @Test("Right-side Dock: a display beside the upper half leaves the lower half")
    func rightEdge() {
        let beside = CGRect(x: 3440, y: 0, width: 1920, height: 720)
        #expect(plan(ultrawide, [beside], edge: .right) == .push([CGPoint(x: 3439, y: 1080)]))
    }

    @Test("Left-side Dock: a display fully to the left covers it; that display's own left edge is free")
    func leftEdge() {
        let left = CGRect(x: -1920, y: 0, width: 1920, height: 1440)
        #expect(plan(ultrawide, [left], edge: .left) == .edgeCovered)
        #expect(plan(left, [ultrawide], edge: .left) == .push([CGPoint(x: -1919, y: 720)]))
    }

    @Test("Separate Spaces off: only the main display can host the Dock")
    func spacesOff() {
        #expect(plan(ultrawide, [laptop], main: false, spaces: false) == .spacesShared)
        #expect(plan(ultrawide, [laptop], main: true, spaces: false)
                == .push([CGPoint(x: 2923.5, y: 1439), CGPoint(x: 447.5, y: 1439)]))
    }
}
