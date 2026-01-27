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
        // Standard macOS icon sizes for .icns
        let sizes: [CGFloat] = [16, 32, 64, 128, 256, 512, 1024]

        // Create iconset directory
        let iconsetURL = outputURL.deletingPathExtension().appendingPathExtension("iconset")
        try? FileManager.default.removeItem(at: iconsetURL)
        try FileManager.default.createDirectory(at: iconsetURL, withIntermediateDirectories: true)

        // Generate all sizes
        for size in sizes {
            let image1x = generateIcon(
                tintColor: tintColor,
                symbol: symbol,
                size: CGSize(width: size, height: size)
            )

            let image2x = generateIcon(
                tintColor: tintColor,
                symbol: symbol,
                size: CGSize(width: size * 2, height: size * 2)
            )

            // Save 1x
            let filename1x = size == 16 || size == 32 || size == 128 || size == 256 || size == 512
                ? "icon_\(Int(size))x\(Int(size)).png"
                : "icon_\(Int(size/2))x\(Int(size/2))@2x.png"

            try saveAsPNG(image: image1x, url: iconsetURL.appendingPathComponent(filename1x))

            // Save 2x (retina)
            if size <= 512 {
                let filename2x = "icon_\(Int(size))x\(Int(size))@2x.png"
                try saveAsPNG(image: image2x, url: iconsetURL.appendingPathComponent(filename2x))
            }
        }

        // Convert iconset to icns using iconutil
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
        process.arguments = ["-c", "icns", iconsetURL.path, "-o", outputURL.path]

        try process.run()
        process.waitUntilExit()

        // Clean up iconset directory
        try? FileManager.default.removeItem(at: iconsetURL)

        guard process.terminationStatus == 0 else {
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
