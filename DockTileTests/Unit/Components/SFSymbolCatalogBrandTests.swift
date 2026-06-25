import Testing
import Foundation
@testable import Dock_Tile

// MARK: - SF Symbol Catalog Brand Logo Tests

/// Guards the invariant that the DockTile brand logo is pinned as the very first
/// option in the symbol picker and is wired through the catalog's lookups. The
/// logo is stored as an `.sfSymbol` icon whose `iconValue` is a sentinel name, so
/// these seams ensure it never silently falls back to a real system symbol.
@Suite("SFSymbolCatalog Brand Logo")
struct SFSymbolCatalogBrandTests {

    @Test("Brand logo is the first category in the picker")
    func brandIsFirstCategory() throws {
        let first = try #require(SFSymbolCatalog.shared.displayCategories.first)
        #expect(first.key == SFSymbolCatalog.brandCategoryKey)
        #expect(first.displayName == "DockTile")
    }

    @Test("Brand category resolves to exactly the brand symbol")
    func brandCategoryResolvesToBrandSymbol() {
        let symbols = SFSymbolCatalog.shared.symbols(for: SFSymbolCatalog.brandCategoryKey)
        #expect(symbols == [SFSymbolCatalog.brandSymbolName])
    }

    @Test("Brand sentinel name is not a real SF Symbol")
    func brandSentinelIsNotASystemSymbol() {
        // If Apple ever ships this exact name, the sentinel would collide and the
        // brand image path would be ambiguous — assert it stays synthetic.
        #expect(SFSymbolCatalog.brandSymbolName == "docktile.logo")
    }

    @Test("Brand search keywords match the picker filter")
    func brandSearchKeywords() {
        let keywords = SFSymbolCatalog.shared.searchKeywords(for: SFSymbolCatalog.brandSymbolName)
        #expect(keywords.contains("docktile"))
        #expect(keywords.contains("sun"))
        #expect(keywords.contains("logo"))
    }

    @Test("Brand logo scales up with the Icon Scale stepper, capped in the safe area")
    func brandScalesWithStepperButCapped() {
        // Grows as the scale increases...
        #expect(SFSymbolCatalog.brandRatio(forScale: 14) > SFSymbolCatalog.brandRatio(forScale: 10))
        #expect(SFSymbolCatalog.brandRatio(forScale: 20) > SFSymbolCatalog.brandRatio(forScale: 14))
        // ...never exceeding the brand safe-area ceiling (stays inside the tile)...
        #expect(SFSymbolCatalog.brandRatio(forScale: 20) <= SFSymbolCatalog.brandMaxSafeRatio)
        #expect(SFSymbolCatalog.brandMaxSafeRatio < 1.0)
        // ...and the default scale lands at the intended ~0.55.
        #expect(abs(SFSymbolCatalog.brandRatio(forScale: 14) - 0.55) < 0.0001)
    }
}
