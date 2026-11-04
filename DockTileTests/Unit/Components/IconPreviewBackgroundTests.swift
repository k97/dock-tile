import Testing
import SwiftUI
@testable import Dock_Tile

@Suite("Preview background threading")
@MainActor
struct IconPreviewBackgroundTests {
    @Test("fromConfig carries the tile's background (sidebar rows show Mono tiles as Mono)")
    func fromConfigCarriesBackground() {
        let config = DockTileConfiguration(name: "Media", background: .mono)
        #expect(DockTileIconPreview.fromConfig(config, size: 24).tileBackground == .mono)
    }

    @Test("A forced style wins over a fixed system icon style (canonical Light/Dark previews)")
    func forcedStyleWins() {
        // ClearAutomatic would render Clear in both schemes — the forced pair must still differ.
        let raw = RawStyleToken.value("ClearAutomatic")
        #expect(DockTileIconPreview.displayStyle(forced: .defaultStyle, raw: raw, colorScheme: .dark) == .defaultStyle)
        #expect(DockTileIconPreview.displayStyle(forced: .dark, raw: raw, colorScheme: .light) == .dark)
        #expect(DockTileIconPreview.displayStyle(forced: nil, raw: raw, colorScheme: .light) == .clear)
    }
}
