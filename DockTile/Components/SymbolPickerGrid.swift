//
//  SymbolPickerGrid.swift
//  DockTile
//
//  Categorized SF Symbols grid picker for tile icon customization
//  Swift 6 - Strict Concurrency
//

import SwiftUI

struct SymbolPickerGrid: View {
    @Binding var selectedSymbol: String
    let onSelect: (String) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 7)
    private let symbolSize: CGFloat = 24

    var body: some View {
        LazyVStack(alignment: .leading, spacing: 16) {
            ForEach(SymbolCategory.allCases, id: \.self) { category in
                VStack(alignment: .leading, spacing: 8) {
                    Text(category.displayName)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)

                    LazyVGrid(columns: columns, spacing: 8) {
                        ForEach(category.symbols, id: \.self) { symbol in
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

// MARK: - Symbol Categories

enum SymbolCategory: CaseIterable {
    case people
    case animalsNature
    case foodDrink
    case activity
    case travelPlaces
    case objects
    case symbols

    var displayName: String {
        switch self {
        case .people: return "People"
        case .animalsNature: return "Animals & Nature"
        case .foodDrink: return "Food & Drink"
        case .activity: return "Activity"
        case .travelPlaces: return "Travel & Places"
        case .objects: return "Objects"
        case .symbols: return "Symbols"
        }
    }

    var symbols: [String] {
        switch self {
        case .people:
            return [
                "person.fill",
                "person.2.fill",
                "person.3.fill",
                "figure.stand",
                "figure.walk",
                "figure.run",
                "figure.wave",
                "person.crop.circle.fill",
                "person.crop.square.fill",
                "person.badge.plus",
                "person.badge.minus",
                "person.badge.clock.fill",
                "eye.fill",
                "eye.slash.fill",
                "mouth.fill",
                "nose.fill",
                "ear.fill",
                "hand.raised.fill",
                "hand.thumbsup.fill",
                "hand.thumbsdown.fill",
                "hands.clap.fill",
                "hand.wave.fill",
                "brain.head.profile",
                "face.smiling.fill",
                "face.dashed.fill"
            ]

        case .animalsNature:
            return [
                "pawprint.fill",
                "dog.fill",
                "cat.fill",
                "bird.fill",
                "fish.fill",
                "tortoise.fill",
                "hare.fill",
                "ant.fill",
                "ladybug.fill",
                "leaf.fill",
                "leaf.arrow.triangle.circlepath",
                "tree.fill",
                "mountain.2.fill",
                "water.waves",
                "flame.fill",
                "drop.fill",
                "snowflake",
                "cloud.fill",
                "sun.max.fill",
                "moon.fill",
                "moon.stars.fill",
                "sparkles",
                "star.fill",
                "globe.americas.fill",
                "globe.europe.africa.fill"
            ]

        case .foodDrink:
            return [
                "cup.and.saucer.fill",
                "mug.fill",
                "wineglass.fill",
                "birthday.cake.fill",
                "carrot.fill",
                "fork.knife",
                "takeoutbag.and.cup.and.straw.fill"
            ]

        case .activity:
            return [
                "sportscourt.fill",
                "figure.run",
                "figure.walk",
                "figure.hiking",
                "figure.yoga",
                "figure.dance",
                "figure.boxing",
                "figure.golf",
                "figure.tennis",
                "figure.basketball",
                "figure.soccer",
                "dumbbell.fill",
                "medal.fill",
                "trophy.fill",
                "gamecontroller.fill",
                "paintpalette.fill",
                "theatermasks.fill",
                "music.note",
                "music.mic",
                "guitars.fill",
                "pianokeys",
                "film.fill",
                "camera.fill",
                "video.fill"
            ]

        case .travelPlaces:
            return [
                "airplane",
                "car.fill",
                "bus.fill",
                "tram.fill",
                "ferry.fill",
                "bicycle",
                "scooter",
                "fuelpump.fill",
                "map.fill",
                "mappin.and.ellipse",
                "location.fill",
                "building.fill",
                "building.2.fill",
                "house.fill",
                "tent.fill",
                "beach.umbrella.fill",
                "mountain.2.fill",
                "globe",
                "suitcase.fill",
                "bed.double.fill"
            ]

        case .objects:
            return [
                "desktopcomputer",
                "laptopcomputer",
                "iphone",
                "ipad",
                "applewatch",
                "airpods",
                "headphones",
                "tv.fill",
                "display",
                "keyboard.fill",
                "computermouse.fill",
                "printer.fill",
                "scanner.fill",
                "externaldrive.fill",
                "memorychip.fill",
                "cpu.fill",
                "wifi",
                "antenna.radiowaves.left.and.right",
                "lightbulb.fill",
                "lamp.desk.fill",
                "flashlight.on.fill",
                "battery.100",
                "bolt.fill",
                "wrench.fill",
                "hammer.fill",
                "screwdriver.fill",
                "scissors",
                "pencil",
                "paintbrush.fill",
                "folder.fill",
                "doc.fill",
                "book.fill",
                "bookmark.fill",
                "paperclip",
                "link",
                "lock.fill",
                "key.fill",
                "creditcard.fill",
                "bag.fill",
                "cart.fill",
                "gift.fill",
                "shippingbox.fill"
            ]

        case .symbols:
            return [
                "checkmark.circle.fill",
                "xmark.circle.fill",
                "exclamationmark.triangle.fill",
                "info.circle.fill",
                "questionmark.circle.fill",
                "plus.circle.fill",
                "minus.circle.fill",
                "arrow.up.circle.fill",
                "arrow.down.circle.fill",
                "arrow.left.circle.fill",
                "arrow.right.circle.fill",
                "arrow.clockwise.circle.fill",
                "heart.fill",
                "star.fill",
                "flag.fill",
                "bell.fill",
                "tag.fill",
                "bolt.fill",
                "magnifyingglass",
                "gearshape.fill",
                "slider.horizontal.3",
                "chart.bar.fill",
                "chart.pie.fill",
                "chart.line.uptrend.xyaxis",
                "percent",
                "number",
                "at",
                "dollarsign.circle.fill",
                "eurosign.circle.fill",
                "command",
                "option",
                "shield.fill",
                "checkmark.shield.fill",
                "person.badge.shield.checkmark.fill"
            ]
        }
    }
}

// MARK: - Preview

#Preview {
    ScrollView {
        SymbolPickerGrid(
            selectedSymbol: .constant("star.fill"),
            onSelect: { _ in }
        )
        .padding()
    }
    .frame(width: 400, height: 500)
    .background(Color(NSColor.windowBackgroundColor))
}
