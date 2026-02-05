#!/usr/bin/env swift
//
// generate-dmg-background.swift
// Generates the DMG installer background image with Retina support
//
// Usage: swift Scripts/generate-dmg-background.swift
//

import Cocoa
import CoreGraphics

// Configuration
let width1x: CGFloat = 800
let height1x: CGFloat = 400
let width2x: CGFloat = 1600
let height2x: CGFloat = 800
let outputPath1x = "DockTile/Resources/dmg-background.png"
let outputPath2x = "DockTile/Resources/dmg-background@2x.png"
let outputPathTiff = "DockTile/Resources/dmg-background.tiff"

// Colors
let gradientTopColor = NSColor(red: 0.98, green: 0.98, blue: 0.99, alpha: 1.0)
let gradientBottomColor = NSColor(red: 0.94, green: 0.94, blue: 0.96, alpha: 1.0)
let textColor = NSColor(red: 0.40, green: 0.40, blue: 0.42, alpha: 1.0)
let arrowColor = NSColor(red: 0.50, green: 0.50, blue: 0.52, alpha: 1.0)

func generateBackground(width: CGFloat, height: CGFloat) -> NSBitmapImageRep? {
    // Create NSBitmapImageRep at exact pixel dimensions
    guard let bitmapRep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: Int(width),
        pixelsHigh: Int(height),
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        return nil
    }

    // Create graphics context from the bitmap
    guard let context = NSGraphicsContext(bitmapImageRep: bitmapRep) else {
        return nil
    }

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context

    let cgContext = context.cgContext

    // Calculate scale factor (2x for retina)
    let scale = width / width1x

    // Draw gradient background
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let colors = [gradientTopColor.cgColor, gradientBottomColor.cgColor] as CFArray
    let locations: [CGFloat] = [0.0, 1.0]

    if let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: locations) {
        cgContext.drawLinearGradient(
            gradient,
            start: CGPoint(x: 0, y: 0),
            end: CGPoint(x: 0, y: height),
            options: []
        )
    }

    // Draw arrow (scaled)
    let arrowY = height / 2 + (10 * scale)
    let arrowStartX: CGFloat = 320 * scale
    let arrowEndX: CGFloat = 480 * scale
    let arrowHeadSize: CGFloat = 12 * scale

    cgContext.setStrokeColor(arrowColor.cgColor)
    cgContext.setLineWidth(2.5 * scale)
    cgContext.setLineCap(.round)
    cgContext.setLineJoin(.round)

    // Arrow line
    cgContext.move(to: CGPoint(x: arrowStartX, y: arrowY))
    cgContext.addLine(to: CGPoint(x: arrowEndX, y: arrowY))

    // Arrow head
    cgContext.move(to: CGPoint(x: arrowEndX - arrowHeadSize, y: arrowY - arrowHeadSize))
    cgContext.addLine(to: CGPoint(x: arrowEndX, y: arrowY))
    cgContext.addLine(to: CGPoint(x: arrowEndX - arrowHeadSize, y: arrowY + arrowHeadSize))

    cgContext.strokePath()

    // Draw text (scaled)
    let text = "Drag to Applications"
    let font = NSFont.systemFont(ofSize: 14 * scale, weight: .medium)
    let attributes: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: textColor
    ]

    let textSize = text.size(withAttributes: attributes)
    let textX = (width - textSize.width) / 2
    let textY: CGFloat = height - (85 * scale)

    let textRect = CGRect(x: textX, y: textY, width: textSize.width, height: textSize.height)
    text.draw(in: textRect, withAttributes: attributes)

    NSGraphicsContext.restoreGraphicsState()

    return bitmapRep
}

// Generate 1x version
guard let bitmapRep1x = generateBackground(width: width1x, height: height1x) else {
    print("Failed to generate 1x background")
    exit(1)
}

// Generate 2x version
guard let bitmapRep2x = generateBackground(width: width2x, height: height2x) else {
    print("Failed to generate 2x background")
    exit(1)
}

// Save both PNG files
let fileManager = FileManager.default
let currentDirectory = fileManager.currentDirectoryPath

// Save 1x
guard let pngData1x = bitmapRep1x.representation(using: .png, properties: [:]) else {
    print("Failed to create 1x PNG data")
    exit(1)
}

let fullPath1x = (currentDirectory as NSString).appendingPathComponent(outputPath1x)
let directory = (fullPath1x as NSString).deletingLastPathComponent
try? fileManager.createDirectory(atPath: directory, withIntermediateDirectories: true)

do {
    try pngData1x.write(to: URL(fileURLWithPath: fullPath1x))
    print("✓ Generated 1x: \(outputPath1x) (\(Int(width1x))x\(Int(height1x)))")
} catch {
    print("Failed to write 1x file: \(error)")
    exit(1)
}

// Save 2x
guard let pngData2x = bitmapRep2x.representation(using: .png, properties: [:]) else {
    print("Failed to create 2x PNG data")
    exit(1)
}

let fullPath2x = (currentDirectory as NSString).appendingPathComponent(outputPath2x)

do {
    try pngData2x.write(to: URL(fileURLWithPath: fullPath2x))
    print("✓ Generated 2x: \(outputPath2x) (\(Int(width2x))x\(Int(height2x)))")
} catch {
    print("Failed to write 2x file: \(error)")
    exit(1)
}

print("\n✓ DMG backgrounds created successfully!")
print("  Next: Run this command to create TIFF bundle:")
print("  tiffutil -cathidpicheck \(outputPath1x) \(outputPath2x) -out \(outputPathTiff)")
