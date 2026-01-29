//
//  IconGenerator.swift
//  DockTile
//
//  Generate app icons (.icns) from tint color + symbol emoji
//  Swift 6 - Strict Concurrency
//

import AppKit
import SwiftUI

@MainActor
struct IconGenerator {

    // MARK: - Icon Generation

    /// Generate an icon image with gradient background and symbol
    static func generateIcon(
        tintColor: TintColor,
        symbol: String,
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
        let cornerRadius = size.width * 0.225  // 22.5% of width (standard macOS icon rounding)

        // Create rounded rect path
        let rect = CGRect(origin: .zero, size: size)
        let path = NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius)

        // Draw gradient background
        drawGradient(context: context, path: path, tintColor: tintColor, rect: rect)

        // Draw symbol emoji
        drawSymbol(symbol: symbol, rect: rect, fontSize: size.width * 0.5)

        image.unlockFocus()

        return image
    }

    // MARK: - Gradient Drawing

    private static func drawGradient(
        context: CGContext,
        path: NSBezierPath,
        tintColor: TintColor,
        rect: CGRect
    ) {
        // Clip to rounded rect
        path.addClip()

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
        ) else { return }

        // Draw gradient from top to bottom
        let startPoint = CGPoint(x: rect.midX, y: rect.maxY)
        let endPoint = CGPoint(x: rect.midX, y: rect.minY)

        context.drawLinearGradient(
            gradient,
            start: startPoint,
            end: endPoint,
            options: []
        )
    }

    // MARK: - Symbol Drawing

    private static func drawSymbol(symbol: String, rect: CGRect, fontSize: CGFloat) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: fontSize),
            .foregroundColor: NSColor.white
        ]

        let attributedString = NSAttributedString(string: symbol, attributes: attributes)
        let stringSize = attributedString.size()

        // Center the symbol
        let x = (rect.width - stringSize.width) / 2
        let y = (rect.height - stringSize.height) / 2
        let drawPoint = CGPoint(x: x, y: y)

        attributedString.draw(at: drawPoint)
    }

    // MARK: - ICNS Generation

    /// Generate a complete .icns file with all standard resolutions
    static func generateIcns(
        tintColor: TintColor,
        symbol: String,
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
                symbol: symbol,
                size: CGSize(width: baseSize, height: baseSize)
            )
            let filename1x = "icon_\(baseSize)x\(baseSize).png"
            try saveAsPNG(image: image1x, url: iconsetURL.appendingPathComponent(filename1x))

            // @2x version (retina) - actual pixels are 2x the base size
            let image2x = generateIcon(
                tintColor: tintColor,
                symbol: symbol,
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
        symbol: String,
        size: CGFloat = 80
    ) -> NSImage {
        return generateIcon(
            tintColor: tintColor,
            symbol: symbol,
            size: CGSize(width: size, height: size)
        )
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
