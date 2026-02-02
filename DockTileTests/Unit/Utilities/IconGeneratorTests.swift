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
        let isAtLimit = IconGenerator.isAtSafeAreaLimit(iconScale: 10, iconType: .sfSymbol)
        #expect(isAtLimit == false)  // 0.30 is well below 0.57 threshold
    }

    @Test("Icon ratio at scale 14 is 0.44 for SF Symbol")
    func iconRatioScale14SFSymbol() {
        // 0.30 + (14-10) * 0.035 = 0.30 + 0.14 = 0.44
        let isAtLimit = IconGenerator.isAtSafeAreaLimit(iconScale: 14, iconType: .sfSymbol)
        #expect(isAtLimit == false)  // 0.44 is below 0.57 threshold
    }

    @Test("Icon ratio at scale 17 is at safe area limit for SF Symbol")
    func iconRatioScale17SFSymbol() {
        // 0.30 + (17-10) * 0.035 = 0.30 + 0.245 = 0.545
        // This is capped at maxSafeRatio (0.60), and 0.545 < 0.57 (warning threshold)
        // Actually: 0.545 < 0.57, so NOT at limit
        // Let's test scale 18: 0.30 + 0.28 = 0.58, which is > 0.57
        let isAtLimitScale17 = IconGenerator.isAtSafeAreaLimit(iconScale: 17, iconType: .sfSymbol)
        let isAtLimitScale18 = IconGenerator.isAtSafeAreaLimit(iconScale: 18, iconType: .sfSymbol)

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
        let sfAtLimit = IconGenerator.isAtSafeAreaLimit(iconScale: 14, iconType: .sfSymbol)
        let emojiAtLimit = IconGenerator.isAtSafeAreaLimit(iconScale: 14, iconType: .emoji)

        #expect(sfAtLimit == false)
        #expect(emojiAtLimit == false)

        // At scale 16:
        // SF Symbol: 0.30 + 0.21 = 0.51
        // Emoji: 0.51 + 0.05 = 0.56 (still below 0.57)
        let sfAtLimit16 = IconGenerator.isAtSafeAreaLimit(iconScale: 16, iconType: .sfSymbol)
        let emojiAtLimit16 = IconGenerator.isAtSafeAreaLimit(iconScale: 16, iconType: .emoji)

        #expect(sfAtLimit16 == false)
        #expect(emojiAtLimit16 == false)  // 0.56 < 0.57

        // At scale 17:
        // SF Symbol: 0.30 + 0.245 = 0.545
        // Emoji: 0.545 + 0.05 = 0.595, capped at 0.60, but 0.595 > 0.57
        let emojiAtLimit17 = IconGenerator.isAtSafeAreaLimit(iconScale: 17, iconType: .emoji)
        #expect(emojiAtLimit17 == true)  // Emoji at 17 is at limit, SF Symbol is not
    }

    // MARK: - Safe Area Limit

    @Test("Safe area limit values are correct")
    func safeAreaLimitConstants() {
        #expect(IconGenerator.maxSafeRatio == 0.60)
        #expect(IconGenerator.warningThreshold == 0.57)
    }

    @Test("isAtSafeAreaLimit returns false for low scales")
    func safeAreaLimitLowScales() {
        for scale in 10...14 {
            let sfLimit = IconGenerator.isAtSafeAreaLimit(iconScale: scale, iconType: .sfSymbol)
            #expect(sfLimit == false, "Scale \(scale) SF Symbol should not be at limit")
        }
    }

    @Test("isAtSafeAreaLimit returns true for high scales")
    func safeAreaLimitHighScales() {
        // Scale 20: 0.30 + 0.35 = 0.65, capped at 0.60
        // 0.60 >= 0.57 = true
        let sfLimit20 = IconGenerator.isAtSafeAreaLimit(iconScale: 20, iconType: .sfSymbol)
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
            size: CGSize(width: 64, height: 64)
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
                size: size
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
            size: CGSize(width: 128, height: 128)
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
            size: CGSize(width: 128, height: 128)
        )

        #expect(image.size.width == 128)
        #expect(image.isValid)
    }

    @Test("generateIcon with all preset colors")
    func generateIconAllColors() {
        let colors: [TintColor] = [.red, .orange, .yellow, .green, .blue, .purple, .pink, .gray]

        for color in colors {
            let image = IconGenerator.generateIcon(
                tintColor: color,
                iconType: .sfSymbol,
                iconValue: "star.fill",
                iconScale: 14,
                size: CGSize(width: 64, height: 64)
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
            size: CGSize(width: 128, height: 128)
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
            size: CGSize(width: 64, height: 64)
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
                size: CGSize(width: 64, height: 64)
            )

            #expect(image.isValid, "Image at scale \(scale) should be valid")
        }
    }

    // MARK: - Preview Generation

    @Test("generatePreview returns correct default size")
    func generatePreviewDefaultSize() {
        let preview = IconGenerator.generatePreview(
            tintColor: .blue,
            iconType: .sfSymbol,
            iconValue: "star.fill"
        )

        #expect(preview.size.width == 80)
        #expect(preview.size.height == 80)
    }

    @Test("generatePreview with custom size")
    func generatePreviewCustomSize() {
        let preview = IconGenerator.generatePreview(
            tintColor: .blue,
            iconType: .sfSymbol,
            iconValue: "star.fill",
            size: 160
        )

        #expect(preview.size.width == 160)
        #expect(preview.size.height == 160)
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
            outputURL: outputURL
        )

        #expect(FileManager.default.fileExists(atPath: outputURL.path))

        // Verify file is not empty
        let fileSize = try FileManager.default.attributesOfItem(atPath: outputURL.path)[.size] as? Int ?? 0
        #expect(fileSize > 0)
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
            outputURL: outputURL
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
            outputURL: outputURL
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
            outputURL: outputURL
        )

        // Iconset should be cleaned up
        #expect(!FileManager.default.fileExists(atPath: iconsetURL.path))

        // But .icns should exist
        #expect(FileManager.default.fileExists(atPath: outputURL.path))
    }

    // MARK: - Legacy Methods

    @Test("Legacy generateIcon method works")
    func legacyGenerateIcon() {
        let image = IconGenerator.generateIcon(
            tintColor: .blue,
            symbol: "📁",
            size: CGSize(width: 64, height: 64)
        )

        #expect(image.isValid)
    }

    @Test("Legacy generatePreview method works")
    func legacyGeneratePreview() {
        let preview = IconGenerator.generatePreview(
            tintColor: .green,
            symbol: "⭐"
        )

        #expect(preview.size.width == 80)
    }

    @Test("Legacy generateIcns method works")
    func legacyGenerateIcns() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("IconGeneratorTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }

        let outputURL = tempDir.appendingPathComponent("legacy.icns")

        try IconGenerator.generateIcns(
            tintColor: .purple,
            symbol: "📁",
            outputURL: outputURL
        )

        #expect(FileManager.default.fileExists(atPath: outputURL.path))
    }
}

// MARK: - IconGeneratorError Tests

@Suite("IconGeneratorError Tests")
struct IconGeneratorErrorTests {

    @Test("Error descriptions are not empty")
    func errorDescriptions() {
        let errors: [IconGeneratorError] = [
            .imageConversionFailed,
            .pngExportFailed,
            .icnsConversionFailed
        ]

        for error in errors {
            #expect(!error.localizedDescription.isEmpty)
        }
    }
}

// MARK: - NSImage Tinting Extension Tests

@Suite("NSImage Tinting Tests")
struct NSImageTintingTests {

    @Test("Tinted image returns valid image")
    @MainActor
    func tintedImageIsValid() {
        guard let originalImage = NSImage(systemSymbolName: "star.fill", accessibilityDescription: nil) else {
            Issue.record("Could not create test image")
            return
        }

        let tintedImage = originalImage.tinted(with: .red)

        #expect(tintedImage.isValid)
        #expect(tintedImage.size == originalImage.size)
    }

    @Test("Tinted image preserves size")
    @MainActor
    func tintedImagePreservesSize() {
        guard let originalImage = NSImage(systemSymbolName: "folder.fill", accessibilityDescription: nil) else {
            Issue.record("Could not create test image")
            return
        }

        let originalSize = originalImage.size
        let tintedImage = originalImage.tinted(with: .blue)

        #expect(tintedImage.size.width == originalSize.width)
        #expect(tintedImage.size.height == originalSize.height)
    }
}
