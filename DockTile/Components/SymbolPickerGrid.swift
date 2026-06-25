//
//  SymbolPickerGrid.swift
//  DockTile
//
//  SF Symbols grid picker that loads all available symbols from the system
//  CoreGlyphs bundle. Categories and search keywords are read at runtime,
//  so the picker always matches the user's macOS version.
//
//  Swift 6 - Strict Concurrency
//

import AppKit
import SwiftUI

struct SymbolPickerGrid: View {
    @Binding var selectedSymbol: String
    @Binding var searchText: String
    let iconWeight: IconWeight
    let onSelect: (String) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 7)
    private let symbolSize: CGFloat = 24

    /// Shared catalog loaded once from the system
    private var catalog: SFSymbolCatalog { SFSymbolCatalog.shared }

    /// Filtered symbols for a given category
    private func filteredSymbols(for category: SFSymbolCatalog.Category) -> [String] {
        let symbols = catalog.symbols(for: category.key)
        guard !searchText.isEmpty else { return symbols }
        let query = searchText.lowercased()
        return symbols.filter { symbol in
            symbol.lowercased().contains(query)
                || catalog.searchKeywords(for: symbol).contains(where: { $0.contains(query) })
        }
    }

    var body: some View {
        LazyVStack(alignment: .leading, spacing: 16) {
            ForEach(catalog.displayCategories, id: \.key) { category in
                let symbols = filteredSymbols(for: category)
                if !symbols.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(category.displayName)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)

                        LazyVGrid(columns: columns, spacing: 8) {
                            ForEach(symbols, id: \.self) { symbol in
                                SymbolButton(
                                    symbolName: symbol,
                                    isSelected: selectedSymbol == symbol,
                                    size: symbolSize,
                                    weight: iconWeight
                                ) {
                                    selectedSymbol = symbol
                                    onSelect(symbol)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Symbol Button

private struct SymbolButton: View {
    let symbolName: String
    let isSelected: Bool
    let size: CGFloat
    let weight: IconWeight
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            glyph
                .foregroundColor(isSelected ? .white : .primary)
                .frame(width: 40, height: 40)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(isSelected ? Color.accentColor : Color.clear)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(symbolName == SFSymbolCatalog.brandSymbolName ? "DockTile" : symbolName)
    }

    /// Renders the bundled DockTile logo for the brand symbol, otherwise the SF Symbol.
    @ViewBuilder
    private var glyph: some View {
        if symbolName == SFSymbolCatalog.brandSymbolName, let logo = SFSymbolCatalog.brandGlyph {
            Image(nsImage: logo)
                .resizable()
                .renderingMode(.template)
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
        } else {
            Image(systemName: symbolName)
                .font(.system(size: size, weight: weight.fontWeight))
        }
    }
}

// MARK: - SF Symbol Catalog (reads from system CoreGlyphs bundle)

final class SFSymbolCatalog: @unchecked Sendable {
    static let shared = SFSymbolCatalog()

    /// Sentinel `iconValue` for the bundled DockTile brand logo. Stored as an
    /// `.sfSymbol` icon type but rendered from the `DockTileGlyph` resource
    /// instead of the system symbol set (see `brandGlyph`).
    static let brandSymbolName = "docktile.logo"

    /// Synthetic category key that hosts the brand logo at the top of the picker.
    static let brandCategoryKey = "docktile"

    /// The bundled DockTile logo, loaded once as a tintable template image.
    static let brandGlyph: NSImage? = {
        guard let image = Bundle.main.image(forResource: NSImage.Name("DockTileGlyph")) else {
            return nil
        }
        image.isTemplate = true
        return image
    }()

    /// Size boost the brand logo gets over a same-scale SF Symbol, as an icon-size
    /// ratio. Small, so the default scale lands at a tasteful ~0.55 of the tile.
    static let brandSizeBoostRatio: CGFloat = 0.11

    /// Upper bound on the brand logo's size so the Icon Scale stepper can grow it
    /// but never push the ring past the tile's safe area. The brand uses its own
    /// (higher) ceiling than the 0.60 SF-Symbol cap because the thin ring fills
    /// more cleanly — but well short of the tile edge.
    static let brandMaxSafeRatio: CGFloat = 0.78

    /// Fill-of-tile ratio for the brand logo at a given Icon Scale value. Scales
    /// with the stepper (like SF Symbols) but on the brand curve, capped so it
    /// stays inside the safe area. Used by both the renderer and the live preview.
    static func brandRatio(forScale iconScale: Int) -> CGFloat {
        // Same 0.035/point slope as the SF-Symbol mapping.
        let base = 0.30 + (CGFloat(iconScale - 10) * 0.035)
        return min(base + brandSizeBoostRatio, brandMaxSafeRatio)
    }

    struct Category {
        let key: String
        let icon: String
        let displayName: String
    }

    /// Ordered list of categories to display (excludes meta categories)
    let displayCategories: [Category]

    /// symbol name → [category keys]
    private let symbolToCategories: [String: [String]]

    /// category key → [symbol names] (ordered)
    private let categorySymbols: [String: [String]]

    /// symbol name → [search keywords]
    private let symbolSearchKeywords: [String: [String]]

    private init() {
        let bundle = Bundle(path: "/System/Library/CoreServices/CoreGlyphs.bundle")

        // Load categories list
        var categories: [Category] = []
        if let url = bundle?.url(forResource: "categories", withExtension: "plist"),
           let data = try? Data(contentsOf: url),
           let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [[String: String]] {
            for entry in plist {
                guard let key = entry["key"], let icon = entry["icon"] else { continue }
                categories.append(Category(
                    key: key,
                    icon: icon,
                    displayName: SFSymbolCatalog.categoryDisplayName(for: key)
                ))
            }
        }

        // Load symbol → categories mapping
        var symCats: [String: [String]] = [:]
        if let url = bundle?.url(forResource: "symbol_categories", withExtension: "plist"),
           let data = try? Data(contentsOf: url),
           let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: [String]] {
            symCats = plist
        }

        // Load symbol ordering
        var symbolOrder: [String] = []
        if let url = bundle?.url(forResource: "symbol_order", withExtension: "plist"),
           let data = try? Data(contentsOf: url),
           let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String] {
            symbolOrder = plist
        }

        // Load search keywords
        var searchKw: [String: [String]] = [:]
        if let url = bundle?.url(forResource: "symbol_search", withExtension: "plist"),
           let data = try? Data(contentsOf: url),
           let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: [String]] {
            searchKw = plist
        }

        // Build category → ordered symbols mapping
        // Use symbol_order for consistent ordering, filter out locale variants and wide symbols
        let orderSet = Set(symbolOrder)
        var catSyms: [String: [String]] = [:]

        for symbol in symbolOrder {
            if SFSymbolCatalog.isLocaleVariant(symbol) { continue }
            if SFSymbolCatalog.isWideSymbol(symbol) { continue }

            guard let cats = symCats[symbol] else { continue }
            for cat in cats {
                catSyms[cat, default: []].append(symbol)
            }
        }

        // Also add symbols that are in symCats but not in symbolOrder
        for (symbol, cats) in symCats {
            if orderSet.contains(symbol) { continue }
            if SFSymbolCatalog.isLocaleVariant(symbol) { continue }
            if SFSymbolCatalog.isWideSymbol(symbol) { continue }
            for cat in cats {
                catSyms[cat, default: []].append(symbol)
            }
        }

        self.symbolToCategories = symCats
        self.categorySymbols = catSyms
        self.symbolSearchKeywords = searchKw

        // Filter out meta categories and categories that aren't useful for dock tile icons
        let excludedKeys: Set<String> = ["all", "whatsnew", "variable", "multicolor", "indices", "automotive"]
        // Pin the DockTile brand logo as the very first option in the picker.
        let brandCategory = Category(
            key: SFSymbolCatalog.brandCategoryKey,
            icon: "sun.horizon.fill",
            displayName: "DockTile"
        )
        self.displayCategories = [brandCategory] + categories.filter { !excludedKeys.contains($0.key) }
    }

    func symbols(for categoryKey: String) -> [String] {
        if categoryKey == SFSymbolCatalog.brandCategoryKey {
            return [SFSymbolCatalog.brandSymbolName]
        }
        return categorySymbols[categoryKey] ?? []
    }

    func searchKeywords(for symbol: String) -> [String] {
        if symbol == SFSymbolCatalog.brandSymbolName {
            return ["docktile", "dock", "tile", "logo", "brand", "sun", "sunrise", "sunset", "horizon"]
        }
        return symbolSearchKeywords[symbol] ?? []
    }

    // MARK: - Helpers

    /// Detect locale-specific symbol variants (e.g., ".ar", ".hi", ".th", ".zh", ".ja", ".ko", ".he")
    private static func isLocaleVariant(_ name: String) -> Bool {
        let localeSuffixes: Set<String> = [".ar", ".hi", ".th", ".zh", ".ja", ".ko", ".he", ".km", ".my", ".bn", ".gu", ".kn", ".ml", ".or", ".pa", ".si", ".ta", ".te"]
        return localeSuffixes.contains(where: { name.hasSuffix($0) })
    }

    /// Detect symbols that render too wide for a square grid cell (e.g., multi-person groups)
    private static func isWideSymbol(_ name: String) -> Bool {
        let widePatterns = [
            "person.2", "person.3",
            "figure.2.and.child",
            "person.and.arrow.left.and.arrow.right",
            "person.line.dotted.person",
            "figure.seated.side",
        ]
        return widePatterns.contains(where: { name.contains($0) })
    }

    /// Human-readable category names
    private static func categoryDisplayName(for key: String) -> String {
        switch key {
        case "all": return "All"
        case "whatsnew": return "What's New"
        case "draw": return "Draw"
        case "variable": return "Variable"
        case "multicolor": return "Multicolour"
        case "communication": return "Communication"
        case "weather": return "Weather"
        case "maps": return "Maps"
        case "objectsandtools": return "Objects & Tools"
        case "devices": return "Devices"
        case "cameraandphotos": return "Camera & Photos"
        case "gaming": return "Gaming"
        case "connectivity": return "Connectivity"
        case "transportation": return "Transportation"
        case "automotive": return "Automotive"
        case "accessibility": return "Accessibility"
        case "privacyandsecurity": return "Privacy & Security"
        case "human": return "Human"
        case "home": return "Home"
        case "fitness": return "Fitness"
        case "nature": return "Nature"
        case "editing": return "Editing"
        case "textformatting": return "Text Formatting"
        case "media": return "Media"
        case "keyboard": return "Keyboard"
        case "commerce": return "Commerce"
        case "time": return "Time"
        case "health": return "Health"
        case "shapes": return "Shapes"
        case "arrows": return "Arrows"
        case "indices": return "Indices"
        case "math": return "Maths"
        default: return key.capitalized
        }
    }
}

// MARK: - Preview

#Preview {
    ScrollView {
        SymbolPickerGrid(
            selectedSymbol: .constant("star.fill"),
            searchText: .constant(""),
            iconWeight: .medium,
            onSelect: { _ in }
        )
        .padding()
    }
    .frame(width: 400, height: 500)
    .background(Color(NSColor.windowBackgroundColor))
}
