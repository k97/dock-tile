//  PopoverPreviewCanvasTests.swift — guards the hero zoom rule: fit the worst-case panel with a
//  margin, boost 10%, never exceed the flush fit or 1.04 (so the panel can't clip or zoom in).
import Testing
import Foundation
@testable import Dock_Tile

@Suite("PopoverPreviewCanvas fit scale")
struct PopoverPreviewCanvasTests {
    @Test("Roomy hero: boosted fit wins, capped at 1.04")
    func roomyCapsAtMaxZoom() {
        let s = PopoverPreviewCanvas.fitScale(available: CGSize(width: 1000, height: 1000), worst: CGSize(width: 200, height: 100))
        #expect(s == 1.04)
    }
    @Test("Tight hero: the flush fit clamps the boosted fit")
    func tightClampsToRawFit() {
        let s = PopoverPreviewCanvas.fitScale(available: CGSize(width: 300, height: 300), worst: CGSize(width: 292, height: 100))
        // rawFit = (300-8)/292 = 1.0 ; fit = (300-56)/292 = 0.8356 → ×1.10 = 0.919 → min = 0.919
        #expect(abs(s - 0.9191) < 0.001)
    }
    @Test("Height-bound hero uses the height axis")
    func heightBound() {
        let s = PopoverPreviewCanvas.fitScale(available: CGSize(width: 1000, height: 144), worst: CGSize(width: 100, height: 100))
        // fit = (144-44)/100 = 1.0 → 1.1 ; rawFit = (144-8)/100 = 1.36 ; cap 1.04 → 1.04
        #expect(s == 1.04)
    }

    // MARK: - `.natural` fit (Tile Detail editor) — must never overflow the fixed-width window

    @Test("Default grid, 6 apps: intrinsic size mirrors the real panel's own frame maths")
    func naturalGridPanelSize() {
        let size = PopoverPreviewCanvas.naturalPanelSize(
            layout: .grid, appCount: 6, settings: .default, isEditing: true)
        // 5 cols x 82pt cell + 4 x 14pt gap + 32pt padding = 498 ; 36 header + 2 x 78 + 14 + 32 = 238
        #expect(size == CGSize(width: 498, height: 238))
    }

    @Test("Default list, 6 apps in the editor: no utility rows in the height")
    func naturalListPanelSize() {
        let size = PopoverPreviewCanvas.naturalPanelSize(
            layout: .list, appCount: 6, settings: .default, isEditing: true)
        // 32 header + 6 x 36 row + 16 vertical padding = 264
        #expect(size == CGSize(width: 240, height: 264))
    }

    @Test("A one-app grid is widened so its title fits on one line")
    func naturalGridPanelSizeSingleApp() {
        let size = PopoverPreviewCanvas.naturalPanelSize(
            layout: .grid, appCount: 1, settings: .default, isEditing: true)
        // Raw width is one 82pt cell + 32pt padding = 114, of which the header's two 28pt gutters
        // leave ~26pt for the tile name — enough to wrap "New Tile" onto a second line. Floored at
        // 180. Height is unchanged: 36 header + one 78pt row + 32 padding.
        #expect(size == CGSize(width: 180, height: 146))
    }

    @Test("Two apps already clear the floor, so their width is untouched")
    func naturalGridPanelSizeTwoApps() {
        let size = PopoverPreviewCanvas.naturalPanelSize(
            layout: .grid, appCount: 2, settings: .default, isEditing: true)
        // 2 cols x 82 + 1 x 14 gap + 32 padding = 210, above the 180 floor.
        #expect(size == CGSize(width: 210, height: 146))
    }

    @Test("Empty grid gets a readable width, not a one-column sliver")
    func naturalGridPanelSizeEmpty() {
        let size = PopoverPreviewCanvas.naturalPanelSize(
            layout: .grid, appCount: 0, settings: .default, isEditing: true)
        // Columns are capped at the app count, so the raw width would be one 82pt cell + 32pt
        // padding = 114 — narrow enough to shred the empty state's two lines. Floored at 260.
        #expect(size == CGSize(width: 260, height: 180))
    }

    @Test("Empty list in the editor: sized for the edit-mode empty state, not a phantom row")
    func naturalListPanelSizeEmpty() {
        let size = PopoverPreviewCanvas.naturalPanelSize(
            layout: .list, appCount: 0, settings: .default, isEditing: true)
        // 32 header + 32 empty-state vertical padding + 48 title/subtitle + 16 outer padding = 128
        #expect(size == CGSize(width: 240, height: 128))
    }

    @Test("The shipped list adds its utility rows and a one-line empty state")
    func listPanelSizeShippedMode() {
        // `isEditing` is the panel's whole mode: the editor drops the trailing Configure /
        // Open in Finder rows and shows a two-line empty state; the shipped popover does the
        // reverse. Both facts move together, so they are pinned together.
        let metrics = PopoverMetrics.list(popoverSize: .medium, tileSize: .medium, spacing: .comfortable)
        let populated = PopoverPanelLayout.listPanelSize(
            metrics: metrics, appCount: 6, isEditing: false, hasHeader: true)
        // The editor's 264 + the 57pt utility block.
        #expect(populated == CGSize(width: 240, height: 321))

        let empty = PopoverPanelLayout.listPanelSize(
            metrics: metrics, appCount: 0, isEditing: false, hasHeader: true)
        // 32 header + 32 empty-state padding + 16 one-line title + 16 outer padding = 96.
        #expect(empty == CGSize(width: 240, height: 96))
    }

    @Test("A cleared tile name drops the title row from the estimate, not just from the panel")
    func naturalListPanelSizeWithoutHeader() {
        // `ListPopoverView` renders its title row only `if !tileName.isEmpty`. Billing for a row the
        // panel never draws leaves a gap under it inside the canvas.
        let named = PopoverPreviewCanvas.naturalPanelSize(
            layout: .list, appCount: 6, settings: .default, isEditing: true,
            hasHeader: true)
        let unnamed = PopoverPreviewCanvas.naturalPanelSize(
            layout: .list, appCount: 6, settings: .default, isEditing: true,
            hasHeader: false)
        #expect(named == CGSize(width: 240, height: 264))
        // 264 - the 32pt header row.
        #expect(unnamed == CGSize(width: 240, height: 232))
    }

    @Test("An unnamed empty list loses the header row too")
    func naturalListPanelSizeEmptyWithoutHeader() {
        let size = PopoverPreviewCanvas.naturalPanelSize(
            layout: .list, appCount: 0, settings: .default, isEditing: true,
            hasHeader: false)
        // 128 - the 32pt header row.
        #expect(size == CGSize(width: 240, height: 96))
    }

    @Test("A panel wider than the detail column scales DOWN to fit flush")
    func naturalScaleShrinksOverflowingPanel() {
        let s = PopoverPreviewCanvas.naturalScale(availableWidth: 488, panelWidth: 498)
        // (488 - 2 x 22 inset) / 498
        #expect(abs(s - 0.891566) < 0.0001)
    }

    @Test("A panel that already fits renders 1:1 — never blown up")
    func naturalScaleNeverUpscales() {
        #expect(PopoverPreviewCanvas.naturalScale(availableWidth: 488, panelWidth: 210) == 1)
    }

    @Test("Before the first layout pass (no proposal yet) the fit falls back to 1:1")
    func naturalScaleWithoutProposal() {
        #expect(PopoverPreviewCanvas.naturalScale(availableWidth: 0, panelWidth: 498) == 1)
    }
}
