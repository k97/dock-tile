//
//  IconGenerator.swift
//  DockTile
//
//  Generate app icons (.icns) from tint color + symbol (SF Symbol or emoji)
//  Supports both SF Symbols and emojis for icon generation
//  Uses macOS Tahoe-style continuous corners (superellipse/squircle)
//  Swift 6 - Strict Concurrency
//

import AppKit
import SwiftUI

@MainActor
struct IconGenerator {

    // MARK: - Icon Scale Helper

    /// Calculate icon ratio from scale value (10-20 range)
    /// - Parameter iconScale: Scale value (10-20), default 14
    /// - Parameter iconType: Type of icon (SF Symbol or Emoji)
    /// - Returns: Ratio to multiply by icon size (0.30-0.70 range)
    private static func iconRatio(for iconScale: Int, iconType: IconType) -> CGFloat {
        // Base ratio: maps iconScale 10-20 to approximately 0.30-0.65
        let baseRatio = 0.30 + (CGFloat(iconScale - 10) * 0.035)

        // Emoji gets +5% offset for visual weight
        let ratio = iconType == .emoji ? baseRatio + 0.05 : baseRatio

        return ratio
    }

    // MARK: - Squircle Path Generation

    /// Create a continuous corner (superellipse/squircle) path matching SwiftUI's .continuous style
    /// This matches Apple's Tahoe icon design guidelines
    private static func createSquirclePath(in rect: CGRect, cornerRadius: CGFloat) -> CGPath {
        // Use SwiftUI's RoundedRectangle with .continuous style to get the exact path
        // We create a SwiftUI shape and extract the CGPath
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        let path = shape.path(in: rect)
        return path.cgPath
    }

    // MARK: - Icon Generation

    /// Generate an icon image with gradient background and symbol/emoji
    /// Uses Tahoe-style continuous corners (squircle) and beveled glass effect
    static func generateIcon(
        tintColor: TintColor,
        iconType: IconType,
        iconValue: String,
        iconScale: Int = ConfigurationDefaults.iconScale,
        size: CGSize
    ) -> NSImage {
        let image = NSImage(size: size)

        image.lockFocus()

        // Create drawing context
        guard let context = NSGraphicsContext.current?.cgContext else {
            image.unlockFocus()
            return image
        }

        // Calculate corner radius based on size (proportional to icon size)
        // 22.5% matches SwiftUI's DockTileIconPreview cornerRadius calculation
        let cornerRadius = size.width * 0.225

        // Create squircle path (continuous corners matching Tahoe guidelines)
        let rect = CGRect(origin: .zero, size: size)
        let squirclePath = createSquirclePath(in: rect, cornerRadius: cornerRadius)

        // Draw gradient background
        drawGradient(context: context, path: squirclePath, tintColor: tintColor, rect: rect)

        // Draw beveled glass effect (inner stroke) - matches DockTileIconPreview
        drawBeveledStroke(context: context, path: squirclePath, size: size)

        // Calculate font size based on icon scale
        let fontSize = size.width * iconRatio(for: iconScale, iconType: iconType)

        // Draw icon (SF Symbol or emoji)
        switch iconType {
        case .sfSymbol:
            drawSFSymbol(symbolName: iconValue, rect: rect, fontSize: fontSize)
        case .emoji:
            drawEmoji(emoji: iconValue, rect: rect, fontSize: fontSize)
        }

        image.unlockFocus()

        return image
    }

    /// Legacy method for backward compatibility (assumes emoji)
    static func generateIcon(
        tintColor: TintColor,
        symbol: String,
        size: CGSize
    ) -> NSImage {
        return generateIcon(
            tintColor: tintColor,
            iconType: .emoji,
            iconValue: symbol,
            iconScale: ConfigurationDefaults.iconScale,
            size: size
        )
    }

    // MARK: - Gradient Drawing

    private static func drawGradient(
        context: CGContext,
        path: CGPath,
        tintColor: TintColor,
        rect: CGRect
    ) {
        // Save context state before clipping
        context.saveGState()

        // Clip to squircle path
        context.addPath(path)
        context.clip()

        // Get gradient colors
        let topColor = NSColor(tintColor.colorTop)
        let bottomColor = NSColor(tintColor.colorBottom)

        // Create gradient
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let colors = [topColor.cgColor, bottomColor.cgColor] as CFArray
        let locations: [CGFloat] = [0.0, 1.0]

        guard let gradient = CGGradient(
            colorsSpace: colorSpace,
            colors: colors,
            locations: locations
        ) else {
            context.restoreGState()
            return
        }

        // Draw gradient from top to bottom
        let startPoint = CGPoint(x: rect.midX, y: rect.maxY)
        let endPoint = CGPoint(x: rect.midX, y: rect.minY)

        context.drawLinearGradient(
            gradient,
            start: startPoint,
            end: endPoint,
            options: []
        )

        // Restore context state (removes clip)
        context.restoreGState()
    }

    // MARK: - Beveled Glass Effect

    /// Draw the beveled glass inner stroke effect matching DockTileIconPreview
    /// White stroke at 50% opacity, 0.5pt line width (scaled proportionally)
    private static func drawBeveledStroke(
        context: CGContext,
        path: CGPath,
        size: CGSize
    ) {
        context.saveGState()

        // Scale line width proportionally (0.5pt at 160pt = ~0.3% of size)
        // Minimum 0.5pt for small icons to remain visible
        let lineWidth = max(0.5, size.width * 0.003125)

        // Set stroke properties
        context.addPath(path)
        context.setStrokeColor(NSColor.white.withAlphaComponent(0.5).cgColor)
        context.setLineWidth(lineWidth)

        // Stroke the path
        context.strokePath()

        context.restoreGState()
    }

    // MARK: - SF Symbol Drawing

    private static func drawSFSymbol(symbolName: String, rect: CGRect, fontSize: CGFloat) {
        // Create SF Symbol configuration
        let config = NSImage.SymbolConfiguration(pointSize: fontSize, weight: .medium)

        // Get the SF Symbol image
        guard let symbolImage = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)?
            .withSymbolConfiguration(config) else {
            // Fallback to a default symbol if the requested one doesn't exist
            drawFallbackSymbol(rect: rect, fontSize: fontSize)
            return
        }

        // Calculate centered position
        let symbolSize = symbolImage.size
        let x = (rect.width - symbolSize.width) / 2
        let y = (rect.height - symbolSize.height) / 2
        let drawRect = CGRect(x: x, y: y, width: symbolSize.width, height: symbolSize.height)

        // Draw with white color
        let tintedImage = symbolImage.tinted(with: .white)
        tintedImage.draw(in: drawRect)
    }

    private static func drawFallbackSymbol(rect: CGRect, fontSize: CGFloat) {
        // Draw a star as fallback
        let config = NSImage.SymbolConfiguration(pointSize: fontSize, weight: .medium)
        guard let fallbackImage = NSImage(systemSymbolName: "star.fill", accessibilityDescription: nil)?
            .withSymbolConfiguration(config) else {
            return
        }

        let symbolSize = fallbackImage.size
        let x = (rect.width - symbolSize.width) / 2
        let y = (rect.height - symbolSize.height) / 2
        let drawRect = CGRect(x: x, y: y, width: symbolSize.width, height: symbolSize.height)

        let tintedImage = fallbackImage.tinted(with: .white)
        tintedImage.draw(in: drawRect)
    }

    // MARK: - Emoji Drawing

    private static func drawEmoji(emoji: String, rect: CGRect, fontSize: CGFloat) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: fontSize),
            .foregroundColor: NSColor.white
        ]

        let attributedString = NSAttributedString(string: emoji, attributes: attributes)
        let stringSize = attributedString.size()

        // Center the emoji
        let x = (rect.width - stringSize.width) / 2
        let y = (rect.height - stringSize.height) / 2
        let drawPoint = CGPoint(x: x, y: y)

        attributedString.draw(at: drawPoint)
    }

    // MARK: - ICNS Generation

    /// Generate a complete .icns file with all standard resolutions
    static func generateIcns(
        tintColor: TintColor,
        iconType: IconType,
        iconValue: String,
        iconScale: Int = ConfigurationDefaults.iconScale,
        outputURL: URL
    ) throws {
        // Standard macOS icon sizes for .icns (base sizes)
        // Each needs 1x and @2x versions
        let baseSizes: [Int] = [16, 32, 128, 256, 512]

        // Create iconset directory
        let iconsetURL = outputURL.deletingPathExtension().appendingPathExtension("iconset")
        try? FileManager.default.removeItem(at: iconsetURL)
        try FileManager.default.createDirectory(at: iconsetURL, withIntermediateDirectories: true)

        // Generate all sizes (1x and @2x for each base size)
        for baseSize in baseSizes {
            // 1x version
            let image1x = generateIcon(
                tintColor: tintColor,
                iconType: iconType,
                iconValue: iconValue,
                iconScale: iconScale,
                size: CGSize(width: baseSize, height: baseSize)
            )
            let filename1x = "icon_\(baseSize)x\(baseSize).png"
            try saveAsPNG(image: image1x, url: iconsetURL.appendingPathComponent(filename1x))

            // @2x version (retina) - actual pixels are 2x the base size
            let image2x = generateIcon(
                tintColor: tintColor,
                iconType: iconType,
                iconValue: iconValue,
                iconScale: iconScale,
                size: CGSize(width: baseSize * 2, height: baseSize * 2)
            )
            let filename2x = "icon_\(baseSize)x\(baseSize)@2x.png"
            try saveAsPNG(image: image2x, url: iconsetURL.appendingPathComponent(filename2x))
        }

        // Convert iconset to icns using iconutil
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
        process.arguments = ["-c", "icns", iconsetURL.path, "-o", outputURL.path]

        let pipe = Pipe()
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        // Clean up iconset directory
        try? FileManager.default.removeItem(at: iconsetURL)

        guard process.terminationStatus == 0 else {
            let errorData = pipe.fileHandleForReading.readDataToEndOfFile()
            let errorMessage = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            print("iconutil error: \(errorMessage)")
            throw IconGeneratorError.icnsConversionFailed
        }
    }

    /// Legacy method for backward compatibility
    static func generateIcns(
        tintColor: TintColor,
        symbol: String,
        outputURL: URL
    ) throws {
        try generateIcns(
            tintColor: tintColor,
            iconType: .emoji,
            iconValue: symbol,
            iconScale: ConfigurationDefaults.iconScale,
            outputURL: outputURL
        )
    }

    // MARK: - PNG Export

    private static func saveAsPNG(image: NSImage, url: URL) throws {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw IconGeneratorError.imageConversionFailed
        }

        let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
        bitmapRep.size = image.size

        guard let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
            throw IconGeneratorError.pngExportFailed
        }

        try pngData.write(to: url)
    }

    // MARK: - Quick Preview Generation

    /// Generate a preview image for UI display (faster, single size)
    static func generatePreview(
        tintColor: TintColor,
        iconType: IconType,
        iconValue: String,
        iconScale: Int = ConfigurationDefaults.iconScale,
        size: CGFloat = 80
    ) -> NSImage {
        return generateIcon(
            tintColor: tintColor,
            iconType: iconType,
            iconValue: iconValue,
            iconScale: iconScale,
            size: CGSize(width: size, height: size)
        )
    }

    /// Legacy method for backward compatibility
    static func generatePreview(
        tintColor: TintColor,
        symbol: String,
        size: CGFloat = 80
    ) -> NSImage {
        return generateIcon(
            tintColor: tintColor,
            iconType: .emoji,
            iconValue: symbol,
            iconScale: ConfigurationDefaults.iconScale,
            size: CGSize(width: size, height: size)
        )
    }
}

// MARK: - NSImage Extension for Tinting

extension NSImage {
    func tinted(with color: NSColor) -> NSImage {
        let image = self.copy() as! NSImage
        image.lockFocus()

        color.set()

        let imageRect = NSRect(origin: .zero, size: image.size)
        imageRect.fill(using: .sourceAtop)

        image.unlockFocus()
        return image
    }
}

// MARK: - Errors

enum IconGeneratorError: Error {
    case imageConversionFailed
    case pngExportFailed
    case icnsConversionFailed

    var localizedDescription: String {
        switch self {
        case .imageConversionFailed:
            return "Failed to convert NSImage to CGImage"
        case .pngExportFailed:
            return "Failed to export PNG data"
        case .icnsConversionFailed:
            return "Failed to convert iconset to .icns file"
        }
    }
}
