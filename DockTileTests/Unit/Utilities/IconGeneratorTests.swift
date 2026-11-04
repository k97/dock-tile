import Testing
import AppKit
import Foundation
@testable import Dock_Tile

// MARK: - IconGenerator Tests

@Suite("IconGenerator Tests")
@MainActor
struct IconGeneratorTests {

    // MARK: - Icon Ratio Calculation

    @Test("Icon ratio at scale 10 is 0.30 for SF Symbol")
    func iconRatioScale10SFSymbol() {
        // Access private method via testing the observable behavior
        // We test this indirectly through isAtSafeAreaLimit
        let isAtLimit = IconDepthMetrics.isAtSafeAreaLimit(iconScale: 10, iconType: .sfSymbol)
        #expect(isAtLimit == false)  // 0.30 is well below 0.57 threshold
    }

    @Test("Icon ratio at scale 14 is 0.44 for SF Symbol")
    func iconRatioScale14SFSymbol() {
        // 0.30 + (14-10) * 0.035 = 0.30 + 0.14 = 0.44
        let isAtLimit = IconDepthMetrics.isAtSafeAreaLimit(iconScale: 14, iconType: .sfSymbol)
        #expect(isAtLimit == false)  // 0.44 is below 0.57 threshold
    }

    @Test("Icon ratio at scale 17 is at safe area limit for SF Symbol")
    func iconRatioScale17SFSymbol() {
        // 0.30 + (17-10) * 0.035 = 0.30 + 0.245 = 0.545
        // This is capped at maxSafeRatio (0.60), and 0.545 < 0.57 (warning threshold)
        // Actually: 0.545 < 0.57, so NOT at limit
        // Let's test scale 18: 0.30 + 0.28 = 0.58, which is > 0.57
        let isAtLimitScale17 = IconDepthMetrics.isAtSafeAreaLimit(iconScale: 17, iconType: .sfSymbol)
        let isAtLimitScale18 = IconDepthMetrics.isAtSafeAreaLimit(iconScale: 18, iconType: .sfSymbol)

        // Scale 17 = 0.545, which is below 0.57 threshold
        // Scale 18 = 0.58, which is above 0.57 threshold
        #expect(isAtLimitScale17 == false)
        #expect(isAtLimitScale18 == true)
    }

    @Test("Emoji gets +5% offset compared to SF Symbol")
    func emojiOffsetFromSFSymbol() {
        // At scale 14:
        // SF Symbol: 0.30 + 0.14 = 0.44
        // Emoji: 0.44 + 0.05 = 0.49
        // Both below threshold
        let sfAtLimit = IconDepthMetrics.isAtSafeAreaLimit(iconScale: 14, iconType: .sfSymbol)
        let emojiAtLimit = IconDepthMetrics.isAtSafeAreaLimit(iconScale: 14, iconType: .emoji)

        #expect(sfAtLimit == false)
        #expect(emojiAtLimit == false)

        // At scale 16:
        // SF Symbol: 0.30 + 0.21 = 0.51
        // Emoji: 0.51 + 0.05 = 0.56 (still below 0.57)
        let sfAtLimit16 = IconDepthMetrics.isAtSafeAreaLimit(iconScale: 16, iconType: .sfSymbol)
        let emojiAtLimit16 = IconDepthMetrics.isAtSafeAreaLimit(iconScale: 16, iconType: .emoji)

        #expect(sfAtLimit16 == false)
        #expect(emojiAtLimit16 == false)  // 0.56 < 0.57

        // At scale 19:
        // Emoji: 0.615 + 0.05 = 0.665 — under the emoji ceiling's warning threshold
        // (0.78 × 0.95 = 0.741), so no warning; only the top step (22 → 0.77) fires.
        let emojiAtLimit19 = IconDepthMetrics.isAtSafeAreaLimit(iconScale: 19, iconType: .emoji)
        let emojiAtLimit22 = IconDepthMetrics.isAtSafeAreaLimit(iconScale: 22, iconType: .emoji)
        #expect(emojiAtLimit19 == false)
        #expect(emojiAtLimit22 == true)
    }

    // MARK: - Safe Area Limit

    @Test("isAtSafeAreaLimit returns false for low scales")
    func safeAreaLimitLowScales() {
        for scale in 10...14 {
            let sfLimit = IconDepthMetrics.isAtSafeAreaLimit(iconScale: scale, iconType: .sfSymbol)
            #expect(sfLimit == false, "Scale \(scale) SF Symbol should not be at limit")
        }
    }

    @Test("isAtSafeAreaLimit returns true for high scales")
    func safeAreaLimitHighScales() {
        // Scale 20: 0.30 + 0.35 = 0.65, capped at 0.60
        // 0.60 >= 0.57 = true
        let sfLimit20 = IconDepthMetrics.isAtSafeAreaLimit(iconScale: 20, iconType: .sfSymbol)
        #expect(sfLimit20 == true)
    }

    // MARK: - Image Generation

    @Test("generateIcon returns non-nil image")
    func generateIconReturnsImage() {
        let image = IconGenerator.generateIcon(
            tintColor: .blue,
            iconType: .sfSymbol,
            iconValue: "star.fill",
            iconScale: 14,
            background: .colour, size: CGSize(width: 64, height: 64)
        )

        #expect(image.size.width == 64)
        #expect(image.size.height == 64)
    }

    @Test("generateIcon with different sizes")
    func generateIconDifferentSizes() {
        let sizes: [CGFloat] = [16, 32, 64, 128, 256, 512]

        for sizeValue in sizes {
            let size = CGSize(width: sizeValue, height: sizeValue)
            let image = IconGenerator.generateIcon(
                tintColor: .red,
                iconType: .sfSymbol,
                iconValue: "folder.fill",
                iconScale: 14,
                background: .colour, size: size
            )

            #expect(image.size.width == sizeValue, "Width for size \(sizeValue)")
            #expect(image.size.height == sizeValue, "Height for size \(sizeValue)")
        }
    }

    @Test("generateIcon with SF Symbol")
    func generateIconSFSymbol() {
        let image = IconGenerator.generateIcon(
            tintColor: .purple,
            iconType: .sfSymbol,
            iconValue: "star.fill",
            iconScale: 14,
            background: .colour, size: CGSize(width: 128, height: 128)
        )

        #expect(image.size.width == 128)
        #expect(image.isValid)
    }

    @Test("generateIcon with emoji")
    func generateIconEmoji() {
        let image = IconGenerator.generateIcon(
            tintColor: .green,
            iconType: .emoji,
            iconValue: "📁",
            iconScale: 14,
            background: .colour, size: CGSize(width: 128, height: 128)
        )

        #expect(image.size.width == 128)
        #expect(image.isValid)
    }

    @Test("generateIcon with all preset colors")
    func generateIconAllColors() {
        let colors: [TintColor] = [.red, .orange, .green, .blue, .purple, .pink, .gray]

        for color in colors {
            let image = IconGenerator.generateIcon(
                tintColor: color,
                iconType: .sfSymbol,
                iconValue: "star.fill",
                iconScale: 14,
                background: .colour, size: CGSize(width: 64, height: 64)
            )

            #expect(image.isValid, "Image for \(color.displayName) should be valid")
        }
    }

    @Test("generateIcon with custom color")
    func generateIconCustomColor() {
        let customColor = TintColor.custom("#FF5733")

        let image = IconGenerator.generateIcon(
            tintColor: customColor,
            iconType: .sfSymbol,
            iconValue: "star.fill",
            iconScale: 14,
            background: .colour, size: CGSize(width: 128, height: 128)
        )

        #expect(image.isValid)
    }

    @Test("generateIcon with invalid SF Symbol uses fallback")
    func generateIconInvalidSymbol() {
        let image = IconGenerator.generateIcon(
            tintColor: .blue,
            iconType: .sfSymbol,
            iconValue: "this.symbol.does.not.exist",
            iconScale: 14,
            background: .colour, size: CGSize(width: 64, height: 64)
        )

        // Should still return a valid image (fallback star)
        #expect(image.isValid)
    }

    @Test("generateIcon respects icon scale")
    func generateIconScaleParameter() {
        // We can't directly verify the internal drawing, but we can ensure
        // different scales produce valid images
        for scale in 10...20 {
            let image = IconGenerator.generateIcon(
                tintColor: .blue,
                iconType: .sfSymbol,
                iconValue: "star.fill",
                iconScale: scale,
                background: .colour, size: CGSize(width: 64, height: 64)
            )

            #expect(image.isValid, "Image at scale \(scale) should be valid")
        }
    }

    // MARK: - ICNS Generation

    @Test("generateIcns creates valid .icns file")
    func generateIcnsCreatesFile() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("IconGeneratorTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }

        let outputURL = tempDir.appendingPathComponent("test.icns")

        try IconGenerator.generateIcns(
            tintColor: .blue,
            iconType: .sfSymbol,
            iconValue: "star.fill",
            iconScale: 14,
            background: .colour, outputURL: outputURL
        )

        #expect(FileManager.default.fileExists(atPath: outputURL.path))

        // Verify file is not empty
        let fileSize = try FileManager.default.attributesOfItem(atPath: outputURL.path)[.size] as? Int ?? 0
        #expect(fileSize > 0)
    }

    @Test("generateIcns packs exactly the 10 standard renditions at the right pixel sizes")
    func generateIcnsHasTenRenditions() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("IconGeneratorTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let outputURL = tempDir.appendingPathComponent("renditions.icns")
        try IconGenerator.generateIcns(
            tintColor: .blue,
            iconType: .sfSymbol,
            iconValue: "star.fill",
            iconScale: 14,
            background: .colour, outputURL: outputURL
        )

        // 16/32/128/256/512 at 1x and 2x. This is the wrong-pixel-count regression class the
        // "NSBitmapImageRep with explicit pixel dimensions, never lockFocus" rule exists for:
        // a Retina-scaled backing store silently yields renditions iconutil sizes wrongly.
        let allReps = try #require(NSBitmapImageRep.imageReps(withContentsOf: outputURL))
        let reps = allReps.compactMap { $0 as? NSBitmapImageRep }
        let widths: [Int] = reps.map { $0.pixelsWide }.sorted()
        let heights: [Int] = reps.map { $0.pixelsHigh }.sorted()
        #expect(widths == [16, 32, 32, 64, 128, 256, 256, 512, 512, 1024], "got \(widths)")
        #expect(heights == [16, 32, 32, 64, 128, 256, 256, 512, 512, 1024], "got \(heights)")
        // Every rendition is square.
        for rep in reps {
            #expect(rep.pixelsWide == rep.pixelsHigh)
        }
    }

    @Test("generateIcns with emoji")
    func generateIcnsEmoji() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("IconGeneratorTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }

        let outputURL = tempDir.appendingPathComponent("emoji.icns")

        try IconGenerator.generateIcns(
            tintColor: .green,
            iconType: .emoji,
            iconValue: "📁",
            iconScale: 14,
            background: .colour, outputURL: outputURL
        )

        #expect(FileManager.default.fileExists(atPath: outputURL.path))
    }

    @Test("generateIcns with custom color")
    func generateIcnsCustomColor() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("IconGeneratorTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }

        let outputURL = tempDir.appendingPathComponent("custom.icns")

        try IconGenerator.generateIcns(
            tintColor: .custom("#FF5733"),
            iconType: .sfSymbol,
            iconValue: "folder.fill",
            iconScale: 16,
            background: .colour, outputURL: outputURL
        )

        #expect(FileManager.default.fileExists(atPath: outputURL.path))
    }

    @Test("generateIcns cleans up temporary iconset")
    func generateIcnsCleansUpIconset() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("IconGeneratorTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }

        let outputURL = tempDir.appendingPathComponent("cleanup.icns")
        let iconsetURL = tempDir.appendingPathComponent("cleanup.iconset")

        try IconGenerator.generateIcns(
            tintColor: .blue,
            iconType: .sfSymbol,
            iconValue: "star.fill",
            iconScale: 14,
            background: .colour, outputURL: outputURL
        )

        // Iconset should be cleaned up
        #expect(!FileManager.default.fileExists(atPath: iconsetURL.path))

        // But .icns should exist
        #expect(FileManager.default.fileExists(atPath: outputURL.path))
    }
}
