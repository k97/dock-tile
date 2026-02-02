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
let width: CGFloat = 800
let height: CGFloat = 400
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

// Draw arrow
let arrowY = height / 2 + 10  // Slightly above center
let arrowStartX: CGFloat = 320
let arrowEndX: CGFloat = 480
let arrowHeadSize: CGFloat = 12

cgContext.setStrokeColor(arrowColor.cgColor)
cgContext.setLineWidth(2.5)
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

// Draw text
let text = "Drag to Applications"
let font = NSFont.systemFont(ofSize: 14, weight: .medium)
let attributes: [NSAttributedString.Key: Any] = [
    .font: font,
    .foregroundColor: textColor
]

let textSize = text.size(withAttributes: attributes)
let textX = (width - textSize.width) / 2
let textY: CGFloat = 85  // Position from bottom

// Flip context for text drawing (CoreGraphics is bottom-up)
cgContext.saveGState()
cgContext.translateBy(x: 0, y: height)
cgContext.scaleBy(x: 1, y: -1)

let textRect = CGRect(x: textX, y: height - textY - textSize.height, width: textSize.width, height: textSize.height)
text.draw(in: textRect, withAttributes: attributes)

cgContext.restoreGState()

NSGraphicsContext.restoreGraphicsState()

// Note: PNG DPI is set via sips command after creation
// The bitmap is created at 1:1 pixel ratio which is correct for 72 DPI

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
    print("Background image created successfully!")
    print("  Path: \(fullPath)")
    print("  Size: \(Int(width))x\(Int(height)) pixels")
    print("  DPI: 72x72")
} catch {
    print("Failed to write file: \(error)")
    exit(1)
}
