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

import SwiftUI

struct SymbolPickerGrid: View {
    @Binding var selectedSymbol: String
    @Binding var searchText: String
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
                                    size: symbolSize
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
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Image(systemName: symbolName)
                .font(.system(size: size))
                .foregroundColor(isSelected ? .white : .primary)
                .frame(width: 40, height: 40)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(isSelected ? Color.accentColor : Color.clear)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(symbolName)
    }
}

// MARK: - SF Symbol Catalog (reads from system CoreGlyphs bundle)

final class SFSymbolCatalog: @unchecked Sendable {
    static let shared = SFSymbolCatalog()

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
        self.displayCategories = categories.filter { !excludedKeys.contains($0.key) }
    }

    func symbols(for categoryKey: String) -> [String] {
        categorySymbols[categoryKey] ?? []
    }

    func searchKeywords(for symbol: String) -> [String] {
        symbolSearchKeywords[symbol] ?? []
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
            onSelect: { _ in }
        )
        .padding()
    }
    .frame(width: 400, height: 500)
    .background(Color(NSColor.windowBackgroundColor))
}
