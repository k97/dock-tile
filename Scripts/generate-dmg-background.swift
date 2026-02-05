#!/usr/bin/env swift
//
// generate-dmg-background.swift
// Generates the DMG installer background image
//
// Usage: swift Scripts/generate-dmg-background.swift
//

import Cocoa
import CoreGraphics

// Configuration
// Generate at 2x resolution for Retina displays (1600x800 @ 144 DPI)
// This prevents pixelation on modern Macs
let width: CGFloat = 1600
let height: CGFloat = 800
let outputPath = "DockTile/Resources/dmg-background.png"

// Colors
let gradientTopColor = NSColor(red: 0.96, green: 0.96, blue: 0.97, alpha: 1.0)  // #F5F5F7
let gradientBottomColor = NSColor(red: 0.91, green: 0.91, blue: 0.93, alpha: 1.0)  // #E8E8ED
let textColor = NSColor(red: 0.55, green: 0.55, blue: 0.58, alpha: 1.0)  // #8C8C94
let arrowColor = NSColor(red: 0.65, green: 0.65, blue: 0.68, alpha: 1.0)  // #A6A6AE

// Create bitmap context
let bitmapRep = NSBitmapImageRep(
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
)!

guard let context = NSGraphicsContext(bitmapImageRep: bitmapRep) else {
    print("Failed to create graphics context")
    exit(1)
}

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = context

let cgContext = context.cgContext

// Draw gradient background
let colorSpace = CGColorSpaceCreateDeviceRGB()
let colors = [gradientTopColor.cgColor, gradientBottomColor.cgColor] as CFArray
let locations: [CGFloat] = [0.0, 1.0]

if let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: locations) {
    cgContext.drawLinearGradient(
        gradient,
        start: CGPoint(x: 0, y: height),
        end: CGPoint(x: 0, y: 0),
        options: []
    )
}

// Draw arrow (scaled 2x for Retina)
let arrowY = height / 2 + 20  // Slightly above center (scaled 2x)
let arrowStartX: CGFloat = 640  // 320 * 2
let arrowEndX: CGFloat = 960    // 480 * 2
let arrowHeadSize: CGFloat = 24  // 12 * 2

cgContext.setStrokeColor(arrowColor.cgColor)
cgContext.setLineWidth(5.0)  // 2.5 * 2
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

// Draw text (scaled 2x for Retina)
let text = "Drag to Applications"
let font = NSFont.systemFont(ofSize: 28, weight: .medium)  // 14 * 2
let attributes: [NSAttributedString.Key: Any] = [
    .font: font,
    .foregroundColor: textColor
]

let textSize = text.size(withAttributes: attributes)
let textX = (width - textSize.width) / 2
let textY: CGFloat = 170  // 85 * 2 - Position from bottom

// Flip context for text drawing (CoreGraphics is bottom-up)
cgContext.saveGState()
cgContext.translateBy(x: 0, y: height)
cgContext.scaleBy(x: 1, y: -1)

let textRect = CGRect(x: textX, y: height - textY - textSize.height, width: textSize.width, height: textSize.height)
text.draw(in: textRect, withAttributes: attributes)

cgContext.restoreGState()

NSGraphicsContext.restoreGraphicsState()

// Note: PNG DPI is set via sips command after creation
// The bitmap is created at 2x resolution (1600x800) for Retina displays
// This will be displayed at 800x400 points on screen (144 DPI equivalent)

// Save as PNG
guard let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
    print("Failed to create PNG data")
    exit(1)
}

let fileManager = FileManager.default
let currentDirectory = fileManager.currentDirectoryPath
let fullPath = (currentDirectory as NSString).appendingPathComponent(outputPath)

// Create directory if needed
let directory = (fullPath as NSString).deletingLastPathComponent
try? fileManager.createDirectory(atPath: directory, withIntermediateDirectories: true)

do {
    try pngData.write(to: URL(fileURLWithPath: fullPath))
    print("Retina DMG background created successfully!")
    print("  Path: \(fullPath)")
    print("  Size: \(Int(width))x\(Int(height)) pixels (@2x)")
    print("  Display size: 800x400 points")
    print("  DPI: 144x144 (Retina)")
} catch {
    print("Failed to write file: \(error)")
    exit(1)
}
