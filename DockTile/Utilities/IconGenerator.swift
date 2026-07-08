//
//  IconGenerator.swift
//  DockTile
//
//  Generate app icons (.icns) from tint color + symbol (SF Symbol or emoji)
//  Supports both SF Symbols and emojis for icon generation
//  Uses macOS Tahoe-style continuous corners (superellipse/squircle)
//  Supports appearance-aware rendering (light/dark mode)
//  Swift 6 - Strict Concurrency
//

import AppKit
import SwiftUI

@MainActor
struct IconGenerator {

    // MARK: - Icon Scale Helper

    /// Maximum safe ratio - matches the outer guide circle (~60% of icon bounds).
    /// Forwarded from the shared `IconDepthMetrics` seam so the baked renderer and the live
    /// preview read the same value (kept here for existing callers/tests).
    static let maxSafeRatio: CGFloat = IconDepthMetrics.maxSafeRatio

    /// Threshold for showing warning (95% of max safe ratio). Forwarded from the seam.
    static let warningThreshold: CGFloat = IconDepthMetrics.warningThreshold

    /// Check if the icon scale is at or near the safe area limit.
    /// Used by CustomiseTileView to show a visual warning. Delegates to the shared seam.
    static func isAtSafeAreaLimit(iconScale: Int, iconType: IconType) -> Bool {
        IconDepthMetrics.isAtSafeAreaLimit(iconScale: iconScale, iconType: iconType)
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
    /// Supports icon style-aware rendering for Default/Dark/Clear/Tinted modes
    static func generateIcon(
        tintColor: TintColor,
        iconType: IconType,
        iconValue: String,
        iconScale: Int = ConfigurationDefaults.iconScale,
        iconWeight: IconWeight = ConfigurationDefaults.iconWeight,
        size: CGSize,
        iconStyle: IconStyle = IconStyle.current
    ) -> NSImage {
        // Create an NSImage with explicit 1x scale (1 pixel per point)
        // This ensures 16pt = 16px for .icns generation, regardless of display scale
        let pixelWidth = Int(size.width)
        let pixelHeight = Int(size.height)

        // Create bitmap representation with exact pixel dimensions
        guard let bitmapRep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: pixelWidth,
            pixelsHigh: pixelHeight,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            return NSImage(size: size)
        }

        // Set the size in points to match pixels (1:1 scale)
        bitmapRep.size = size

        // Create graphics context from bitmap
        guard let graphicsContext = NSGraphicsContext(bitmapImageRep: bitmapRep) else {
            return NSImage(size: size)
        }

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = graphicsContext

        let context = graphicsContext.cgContext

        // Calculate corner radius based on size (proportional to icon size)
        // 22.5% matches SwiftUI's DockTileIconPreview cornerRadius calculation
        let cornerRadius = size.width * 0.225

        // Create squircle path (continuous corners matching Tahoe guidelines)
        let rect = CGRect(origin: .zero, size: size)
        let squirclePath = createSquirclePath(in: rect, cornerRadius: cornerRadius)

        // Get appearance-aware colors. Dark style diverges by icon type (SF Symbol → tinted
        // glyph on neutral near-black; emoji → darkened-own-tint), so thread the type through.
        let colors = tintColor.nsColors(for: iconStyle, iconType: iconType)

        // Draw gradient background (appearance-aware)
        drawGradient(
            context: context,
            path: squirclePath,
            topColor: colors.backgroundTop,
            bottomColor: colors.backgroundBottom,
            rect: rect
        )

        // Draw beveled glass effect (inner stroke). Opacity + width come from the shared seam.
        drawBeveledStroke(
            context: context,
            path: squirclePath,
            size: size,
            strokeOpacity: IconDepthMetrics.strokeOpacity(style: iconStyle)
        )

        // Liquid-Glass surface sheen: a soft top specular gloss over the tile face, so the
        // squircle reads as a lit glass surface. Suppressed at tiny sizes by the seam.
        drawSurfaceSheen(
            context: context,
            path: squirclePath,
            rect: rect,
            alpha: IconDepthMetrics.surfaceSheenAlpha(style: iconStyle, nominalSize: size.width)
        )

        // Calculate font size based on icon scale (shared seam handles the brand curve and the
        // SF-Symbol safe-area cap, so this matches the live preview exactly).
        let sizeRatio = IconDepthMetrics.glyphSizeRatio(
            iconScale: iconScale,
            iconType: iconType,
            iconValue: iconValue
        )
        let fontSize = size.width * sizeRatio

        // Depth treatment for the glyph itself (raised-on-glass): a soft contact shadow, plus
        // a top→bottom shading gradient for SF Symbols / the brand glyph (emoji stay full-colour).
        let glyphShadow = IconDepthMetrics.glyphShadow(
            style: iconStyle, iconType: iconType, nominalSize: size.width
        )
        let bottomDarken = IconDepthMetrics.glyphBottomDarken(
            style: iconStyle, iconType: iconType, nominalSize: size.width
        )
        // Liquid-Glass specular sheen clipped to the glyph top (SF Symbols / brand only).
        let glyphSheen = IconDepthMetrics.glyphSheen(
            style: iconStyle, iconType: iconType, nominalSize: size.width
        )

        // Draw icon (SF Symbol or emoji) with appearance-aware colors
        switch iconType {
        case .sfSymbol:
            drawSFSymbol(
                symbolName: iconValue,
                rect: rect,
                fontSize: fontSize,
                weight: iconWeight.nsFontWeight,
                color: colors.foreground,
                shadow: glyphShadow,
                bottomDarken: bottomDarken,
                sheen: glyphSheen
            )
        case .emoji:
            // Emojis: "Sticker on Glass" metaphor - keep full color, with a subtle contact
            // shadow (now in every style, not just Dark) to lift them off the surface, plus a
            // gentle glossy-sticker specular sheen.
            drawEmoji(
                emoji: iconValue,
                rect: rect,
                fontSize: fontSize,
                shadow: glyphShadow,
                sheen: glyphSheen
            )
        }

        NSGraphicsContext.restoreGraphicsState()

        // Create NSImage from the bitmap representation
        let image = NSImage(size: size)
        image.addRepresentation(bitmapRep)

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
            size: size,
            iconStyle: IconStyle.current
        )
    }

    // MARK: - Gradient Drawing

    private static func drawGradient(
        context: CGContext,
        path: CGPath,
        topColor: NSColor,
        bottomColor: NSColor,
        rect: CGRect
    ) {
        // Save context state before clipping
        context.saveGState()

        // Clip to squircle path
        context.addPath(path)
        context.clip()

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
    /// White stroke with configurable opacity, 0.5pt line width (scaled proportionally)
    private static func drawBeveledStroke(
        context: CGContext,
        path: CGPath,
        size: CGSize,
        strokeOpacity: CGFloat = 0.5
    ) {
        context.saveGState()

        // Scale line width proportionally (shared seam — matches the live preview).
        let lineWidth = IconDepthMetrics.strokeLineWidth(nominalSize: size.width)

        // Set stroke properties
        context.addPath(path)
        context.setStrokeColor(NSColor.white.withAlphaComponent(strokeOpacity).cgColor)
        context.setLineWidth(lineWidth)

        // Stroke the path
        context.strokePath()

        context.restoreGState()
    }

    // MARK: - Surface Sheen (Liquid Glass gloss)

    /// Draw a soft top→transparent white gradient over the tile face, clipped to the squircle,
    /// to fake the specular gloss of a lit glass surface. No-op when `alpha` is 0.
    private static func drawSurfaceSheen(
        context: CGContext,
        path: CGPath,
        rect: CGRect,
        alpha: CGFloat
    ) {
        guard alpha > 0 else { return }

        context.saveGState()
        context.addPath(path)
        context.clip()

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let colors = [
            NSColor.white.withAlphaComponent(alpha).cgColor,
            NSColor.white.withAlphaComponent(0).cgColor
        ] as CFArray

        if let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: [0.0, 1.0]) {
            // Fade from the top edge down over the seam's height fraction.
            let startPoint = CGPoint(x: rect.midX, y: rect.maxY)
            let endPoint = CGPoint(
                x: rect.midX,
                y: rect.maxY - rect.height * IconDepthMetrics.surfaceSheenHeightFraction
            )
            context.drawLinearGradient(gradient, start: startPoint, end: endPoint, options: [])
        }

        context.restoreGState()
    }

    // MARK: - SF Symbol Drawing

    private static func drawSFSymbol(
        symbolName: String,
        rect: CGRect,
        fontSize: CGFloat,
        weight: NSFont.Weight = .medium,
        color: NSColor = .white,
        shadow: IconDepthMetrics.GlyphShadow? = nil,
        bottomDarken: CGFloat? = nil,
        sheen: IconDepthMetrics.GlyphSheen? = nil
    ) {
        // The DockTile brand logo lives alongside SF Symbols but is rendered
        // from a bundled template image rather than a system symbol. The brand
        // glyph is a fixed-weight raster, so symbol weight does not apply to it.
        if symbolName == SFSymbolCatalog.brandSymbolName, let glyph = SFSymbolCatalog.brandGlyph {
            drawBrandGlyph(glyph, rect: rect, fontSize: fontSize, color: color, shadow: shadow, bottomDarken: bottomDarken, sheen: sheen)
            return
        }

        // Create SF Symbol configuration
        let config = NSImage.SymbolConfiguration(pointSize: fontSize, weight: weight)

        // Get the SF Symbol image
        guard let symbolImage = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)?
            .withSymbolConfiguration(config) else {
            // Fallback to a default symbol if the requested one doesn't exist
            drawFallbackSymbol(rect: rect, fontSize: fontSize, weight: weight, color: color, shadow: shadow, bottomDarken: bottomDarken, sheen: sheen)
            return
        }

        drawGlyphMask(symbolImage, rect: rect, color: color, shadow: shadow, bottomDarken: bottomDarken, sheen: sheen)
    }

    private static func drawFallbackSymbol(
        rect: CGRect,
        fontSize: CGFloat,
        weight: NSFont.Weight = .medium,
        color: NSColor = .white,
        shadow: IconDepthMetrics.GlyphShadow? = nil,
        bottomDarken: CGFloat? = nil,
        sheen: IconDepthMetrics.GlyphSheen? = nil
    ) {
        // Draw a star as fallback
        let config = NSImage.SymbolConfiguration(pointSize: fontSize, weight: weight)
        guard let fallbackImage = NSImage(systemSymbolName: "star.fill", accessibilityDescription: nil)?
            .withSymbolConfiguration(config) else {
            return
        }
        drawGlyphMask(fallbackImage, rect: rect, color: color, shadow: shadow, bottomDarken: bottomDarken, sheen: sheen)
    }

    /// Draw the bundled DockTile logo, tinted to the appearance-aware foreground.
    /// The logo renders larger than a same-scale SF Symbol (boost) and is allowed
    /// to exceed the standard safe-area cap, since the thin-stroke ring can fill
    /// more of the tile without crowding. This is the brand logo only.
    private static func drawBrandGlyph(
        _ glyph: NSImage,
        rect: CGRect,
        fontSize: CGFloat,
        color: NSColor,
        shadow: IconDepthMetrics.GlyphShadow? = nil,
        bottomDarken: CGFloat? = nil,
        sheen: IconDepthMetrics.GlyphSheen? = nil
    ) {
        // `fontSize` already encodes the brand size ratio for the current Icon
        // Scale (see generateIcon), so draw the logo as a square of that side.
        let side = fontSize
        let drawRect = CGRect(
            x: (rect.width - side) / 2,
            y: (rect.height - side) / 2,
            width: side,
            height: side
        )
        drawGlyph(glyph, in: drawRect, color: color, shadow: shadow, bottomDarken: bottomDarken, sheen: sheen)
    }

    // MARK: - Glyph Compositing (shading + contact shadow)

    /// Centre a template glyph image at its natural size within `rect`, then draw it with the
    /// depth treatment. Used for SF Symbols and the fallback symbol.
    private static func drawGlyphMask(
        _ image: NSImage,
        rect: CGRect,
        color: NSColor,
        shadow: IconDepthMetrics.GlyphShadow?,
        bottomDarken: CGFloat?,
        sheen: IconDepthMetrics.GlyphSheen? = nil
    ) {
        let glyphSize = image.size
        let drawRect = CGRect(
            x: (rect.width - glyphSize.width) / 2,
            y: (rect.height - glyphSize.height) / 2,
            width: glyphSize.width,
            height: glyphSize.height
        )
        drawGlyph(image, in: drawRect, color: color, shadow: shadow, bottomDarken: bottomDarken, sheen: sheen)
    }

    /// Draw a template glyph filled with either a flat tint or a top→bottom shading gradient
    /// (top = `color`, bottom = `color` darkened by `bottomDarken`), casting a soft contact
    /// shadow when one is supplied. The shadow is derived from the composited glyph's alpha,
    /// so it hugs the glyph outline.
    private static func drawGlyph(
        _ image: NSImage,
        in drawRect: CGRect,
        color: NSColor,
        shadow: IconDepthMetrics.GlyphShadow?,
        bottomDarken: CGFloat?,
        sheen: IconDepthMetrics.GlyphSheen? = nil
    ) {
        // Build the filled glyph: a vertical shading gradient when requested, else a flat tint.
        let filled: NSImage
        if let darken = bottomDarken, darken > 0,
           let gradientImage = gradientFilledGlyph(image, topColor: color, bottomColor: color.darkened(by: darken)) {
            filled = gradientImage
        } else {
            filled = image.tinted(with: color)
        }

        guard let context = NSGraphicsContext.current?.cgContext else {
            filled.draw(in: drawRect)
            return
        }

        context.saveGState()
        if let shadow {
            // Negative height = visually downward in this bottom-left-origin context.
            context.setShadow(
                offset: CGSize(width: 0, height: -shadow.offset),
                blur: shadow.blur,
                color: NSColor.black.withAlphaComponent(shadow.blackAlpha).cgColor
            )
        }
        filled.draw(in: drawRect)
        context.restoreGState()

        // Liquid-Glass specular sheen: a white→transparent gloss clipped to the glyph's own alpha,
        // concentrated in the top `heightFraction`. Built as an NSImage the same way as
        // `gradientFilledGlyph` (proven orientation) and drawn back over the filled glyph, rather
        // than clipping the main context with a raw CGImage (which would flip vertically).
        if let sheen, sheen.alpha > 0,
           let sheenImage = sheenGlyph(image, alpha: sheen.alpha, heightFraction: sheen.heightFraction) {
            sheenImage.draw(in: drawRect)
        }
    }

    /// Produce a copy of a template glyph filled with a top→transparent white gloss (the specular
    /// sheen), clipped to the glyph's own alpha and confined to the top `heightFraction`. Mirrors
    /// `gradientFilledGlyph`'s construction so orientation matches the filled glyph exactly.
    private static func sheenGlyph(
        _ image: NSImage,
        alpha: CGFloat,
        heightFraction: CGFloat
    ) -> NSImage? {
        let size = image.size
        let pixelW = Int(size.width.rounded())
        let pixelH = Int(size.height.rounded())
        guard pixelW > 0, pixelH > 0,
              let maskCG = image.cgImage(forProposedRect: nil, context: nil, hints: nil),
              let rep = NSBitmapImageRep(
                bitmapDataPlanes: nil,
                pixelsWide: pixelW,
                pixelsHigh: pixelH,
                bitsPerSample: 8,
                samplesPerPixel: 4,
                hasAlpha: true,
                isPlanar: false,
                colorSpaceName: .deviceRGB,
                bytesPerRow: 0,
                bitsPerPixel: 0
              ),
              let gctx = NSGraphicsContext(bitmapImageRep: rep) else {
            return nil
        }
        rep.size = size

        let cg = gctx.cgContext
        let bounds = CGRect(origin: .zero, size: size)
        // Clip to the glyph shape, then paint the top-down gloss through it.
        cg.clip(to: bounds, mask: maskCG)

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let gradient = CGGradient(
            colorsSpace: colorSpace,
            colors: [
                NSColor.white.withAlphaComponent(alpha).cgColor,
                NSColor.white.withAlphaComponent(0).cgColor
            ] as CFArray,
            locations: [0.0, 1.0]
        ) else {
            return nil
        }
        // Top of the glyph (maxY) → down over `heightFraction` of its height, then clear.
        cg.drawLinearGradient(
            gradient,
            start: CGPoint(x: bounds.midX, y: bounds.maxY),
            end: CGPoint(x: bounds.midX, y: bounds.maxY - bounds.height * heightFraction),
            options: []
        )

        let output = NSImage(size: size)
        output.addRepresentation(rep)
        return output
    }

    /// Produce a copy of a template glyph filled with a vertical top→bottom gradient, clipped to
    /// the glyph's own shape (its alpha). Returns nil if the glyph can't be rasterised, so the
    /// caller falls back to a flat tint.
    private static func gradientFilledGlyph(
        _ image: NSImage,
        topColor: NSColor,
        bottomColor: NSColor
    ) -> NSImage? {
        let size = image.size
        let pixelW = Int(size.width.rounded())
        let pixelH = Int(size.height.rounded())
        guard pixelW > 0, pixelH > 0,
              let maskCG = image.cgImage(forProposedRect: nil, context: nil, hints: nil),
              let rep = NSBitmapImageRep(
                bitmapDataPlanes: nil,
                pixelsWide: pixelW,
                pixelsHigh: pixelH,
                bitsPerSample: 8,
                samplesPerPixel: 4,
                hasAlpha: true,
                isPlanar: false,
                colorSpaceName: .deviceRGB,
                bytesPerRow: 0,
                bitsPerPixel: 0
              ),
              let gctx = NSGraphicsContext(bitmapImageRep: rep) else {
            return nil
        }
        rep.size = size

        let cg = gctx.cgContext
        let bounds = CGRect(origin: .zero, size: size)
        // Clip subsequent drawing to the glyph's alpha, then paint the gradient through it.
        cg.clip(to: bounds, mask: maskCG)

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let gradient = CGGradient(
            colorsSpace: colorSpace,
            colors: [topColor.cgColor, bottomColor.cgColor] as CFArray,
            locations: [0.0, 1.0]
        ) else {
            return nil
        }
        cg.drawLinearGradient(
            gradient,
            start: CGPoint(x: bounds.midX, y: bounds.maxY),
            end: CGPoint(x: bounds.midX, y: bounds.minY),
            options: []
        )

        let output = NSImage(size: size)
        output.addRepresentation(rep)
        return output
    }

    // MARK: - Emoji Ink Measurement

    /// Tight artwork bounds of an emoji, measured from RENDERED PIXELS — font metrics can't
    /// provide this: Apple Color Emoji reports the same em-square glyph bounds for every
    /// emoji (`.usesDeviceMetrics` returns the bitmap cell, not the artwork), while the real
    /// art fills anywhere from ~65% (🧊) to ~100% (🟥) of that cell. Values are normalised
    /// to a 1pt font, in the unflipped (y-up) string-drawing space, relative to the
    /// `draw(at:)` point.
    struct EmojiInkMetrics: Equatable {
        var ink: CGRect
        var typographicSize: CGSize
    }

    private static var emojiInkCache: [String: EmojiInkMetrics] = [:]

    /// Rasterises the emoji once at a reference size and alpha-scans the tight ink rect.
    /// Cached per emoji for the process lifetime. Returns nil if the glyph renders no ink
    /// (callers fall back to legacy em-box sizing).
    static func emojiInkMetrics(for emoji: String) -> EmojiInkMetrics? {
        if let cached = emojiInkCache[emoji] { return cached }

        let ref: CGFloat = 100
        let attr = NSAttributedString(string: emoji, attributes: [.font: NSFont.systemFont(ofSize: ref)])
        let typo = attr.size()
        // Margin catches artwork that overflows the typographic box in any direction.
        let margin = ref * 0.5
        let pixelW = Int((typo.width + margin * 2).rounded())
        let pixelH = Int((typo.height + margin * 2).rounded())
        guard pixelW > 0, pixelH > 0,
              let rep = NSBitmapImageRep(
                bitmapDataPlanes: nil,
                pixelsWide: pixelW,
                pixelsHigh: pixelH,
                bitsPerSample: 8,
                samplesPerPixel: 4,
                hasAlpha: true,
                isPlanar: false,
                colorSpaceName: .deviceRGB,
                bytesPerRow: 0,
                bitsPerPixel: 0
              ),
              let gctx = NSGraphicsContext(bitmapImageRep: rep) else {
            return nil
        }
        rep.size = CGSize(width: CGFloat(pixelW), height: CGFloat(pixelH))

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = gctx
        attr.draw(at: CGPoint(x: margin, y: margin))
        NSGraphicsContext.restoreGraphicsState()

        guard let data = rep.bitmapData else { return nil }
        let rowBytes = rep.bytesPerRow
        var minX = pixelW, minRow = pixelH, maxX = -1, maxRow = -1
        for row in 0..<pixelH {
            for x in 0..<pixelW {
                if data[row * rowBytes + x * 4 + 3] > 8 {
                    if x < minX { minX = x }
                    if x > maxX { maxX = x }
                    if row < minRow { minRow = row }
                    if row > maxRow { maxRow = row }
                }
            }
        }
        guard maxX >= 0 else { return nil }

        // Bitmap rows are top-down; convert to the y-up drawing space and make the rect
        // relative to the draw point (margin, margin), then normalise per 1pt of font.
        let metrics = EmojiInkMetrics(
            ink: CGRect(
                x: (CGFloat(minX) - margin) / ref,
                y: (CGFloat(pixelH - 1 - maxRow) - margin) / ref,
                width: CGFloat(maxX - minX + 1) / ref,
                height: CGFloat(maxRow - minRow + 1) / ref
            ),
            typographicSize: CGSize(width: typo.width / ref, height: typo.height / ref)
        )
        emojiInkCache[emoji] = metrics
        return metrics
    }

    // MARK: - Emoji Drawing

    /// `fontSize` arrives as the seam's target side (glyph ratio × tile) — the emoji is then
    /// ink-normalised so its measured ARTWORK fills that target, optically centred (see
    /// `IconDepthMetrics.emojiInkFit`). Internal (not private) so EmojiInkFitTests can scan
    /// the real drawing path's pixels.
    static func drawEmoji(
        emoji: String,
        rect: CGRect,
        fontSize: CGFloat,
        shadow: IconDepthMetrics.GlyphShadow? = nil,
        sheen: IconDepthMetrics.GlyphSheen? = nil
    ) {
        // Emojis keep their full color ("Sticker on Glass" metaphor)
        // No foregroundColor applied - let the emoji render naturally

        let font: NSFont
        let inkCenterOffset: CGPoint
        if let metrics = emojiInkMetrics(for: emoji) {
            let fit = IconDepthMetrics.emojiInkFit(
                tileSize: rect.width,
                targetRatio: fontSize / rect.width,
                inkPerPoint: metrics.ink,
                typographicSizePerPoint: metrics.typographicSize
            )
            font = NSFont.systemFont(ofSize: fit.fontSize)
            inkCenterOffset = fit.inkCenterOffset
        } else {
            // No measurable ink — legacy em-box sizing.
            font = NSFont.systemFont(ofSize: fontSize)
            inkCenterOffset = .zero
        }

        // Create attributed string without foreground color (keeps emoji colors)
        var attributes: [NSAttributedString.Key: Any] = [
            .font: font
        ]

        // Soft contact shadow to lift the emoji off the surface (seam-driven, every style).
        if let shadow {
            let nsShadow = NSShadow()
            nsShadow.shadowColor = NSColor.black.withAlphaComponent(shadow.blackAlpha)
            nsShadow.shadowOffset = NSSize(width: 0, height: -shadow.offset)
            nsShadow.shadowBlurRadius = shadow.blur
            attributes[.shadow] = nsShadow
        }

        let attributedString = NSAttributedString(string: emoji, attributes: attributes)
        let stringSize = attributedString.size()

        // Centre the ARTWORK: typographic centring shifted by the measured ink offset.
        let x = (rect.width - stringSize.width) / 2 - inkCenterOffset.x
        let y = (rect.height - stringSize.height) / 2 - inkCenterOffset.y
        let drawPoint = CGPoint(x: x, y: y)

        attributedString.draw(at: drawPoint)

        // Glossy-sticker specular sheen, confined to the emoji's own silhouette.
        if let sheen, sheen.alpha > 0,
           let gloss = emojiSheenImage(emoji: emoji, font: font, size: stringSize,
                                       alpha: sheen.alpha, heightFraction: sheen.heightFraction) {
            gloss.draw(at: drawPoint, from: .zero, operation: .sourceOver, fraction: 1.0)
        }
    }

    /// Build a top→transparent white gloss confined to an emoji's silhouette. Because an emoji is
    /// full-colour, a luminance clip would key off its colours instead of its shape — so the
    /// silhouette is isolated by drawing the emoji FIRST and then painting the gloss through its
    /// alpha with `.sourceIn`. The order matters: gradient drawing is plain Core Graphics and
    /// honours the context blend mode, whereas CoreText colour-glyph drawing does NOT — the old
    /// gloss-first `.destinationIn` arrangement produced the INVERSE mask (gloss across the whole
    /// typographic box with the emoji punched out), baking a visible "plate"/bevel behind every
    /// emoji tile. Internal (not private) so EmojiSheenMaskTests can guard the mask directly.
    static func emojiSheenImage(
        emoji: String,
        font: NSFont,
        size: CGSize,
        alpha: CGFloat,
        heightFraction: CGFloat
    ) -> NSImage? {
        let pixelW = Int(size.width.rounded())
        let pixelH = Int(size.height.rounded())
        guard pixelW > 0, pixelH > 0,
              let rep = NSBitmapImageRep(
                bitmapDataPlanes: nil,
                pixelsWide: pixelW,
                pixelsHigh: pixelH,
                bitsPerSample: 8,
                samplesPerPixel: 4,
                hasAlpha: true,
                isPlanar: false,
                colorSpaceName: .deviceRGB,
                bytesPerRow: 0,
                bitsPerPixel: 0
              ),
              let gctx = NSGraphicsContext(bitmapImageRep: rep) else {
            return nil
        }
        rep.size = size
        let bounds = CGRect(origin: .zero, size: size)

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = gctx
        let cg = gctx.cgContext

        // 1. Draw the emoji itself (plain sourceOver — always honoured), establishing the
        //    silhouette's alpha in the bitmap.
        NSAttributedString(string: emoji, attributes: [.font: font]).draw(at: .zero)

        // 2. Replace it with the top-down gloss, kept only where the emoji is opaque:
        //    `.sourceIn` multiplies the gradient by the destination (emoji) alpha. See the
        //    doc comment for why the emoji must be the destination, never the blended source.
        //    `.drawsAfterEndLocation` extends the transparent end colour to the bottom edge so
        //    the emoji pixels below the gloss band are erased too — the returned image must be
        //    ONLY the gloss, never a second emoji copy.
        cg.setBlendMode(.sourceIn)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        if let gradient = CGGradient(
            colorsSpace: colorSpace,
            colors: [
                NSColor.white.withAlphaComponent(alpha).cgColor,
                NSColor.white.withAlphaComponent(0).cgColor
            ] as CFArray,
            locations: [0.0, 1.0]
        ) {
            cg.drawLinearGradient(
                gradient,
                start: CGPoint(x: bounds.midX, y: bounds.maxY),
                end: CGPoint(x: bounds.midX, y: bounds.maxY - bounds.height * heightFraction),
                options: [.drawsAfterEndLocation]
            )
        }

        NSGraphicsContext.restoreGraphicsState()

        let output = NSImage(size: size)
        output.addRepresentation(rep)
        return output
    }

    // MARK: - ICNS Generation

    /// Generate a complete .icns file with all standard resolutions
    /// Supports icon style-aware rendering for Default/Dark/Clear/Tinted modes
    static func generateIcns(
        tintColor: TintColor,
        iconType: IconType,
        iconValue: String,
        iconScale: Int = ConfigurationDefaults.iconScale,
        iconWeight: IconWeight = ConfigurationDefaults.iconWeight,
        outputURL: URL,
        iconStyle: IconStyle = IconStyle.current
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
                iconWeight: iconWeight,
                size: CGSize(width: baseSize, height: baseSize),
                iconStyle: iconStyle
            )
            let filename1x = "icon_\(baseSize)x\(baseSize).png"
            try saveAsPNG(image: image1x, url: iconsetURL.appendingPathComponent(filename1x))

            // @2x version (retina) - actual pixels are 2x the base size
            let image2x = generateIcon(
                tintColor: tintColor,
                iconType: iconType,
                iconValue: iconValue,
                iconScale: iconScale,
                iconWeight: iconWeight,
                size: CGSize(width: baseSize * 2, height: baseSize * 2),
                iconStyle: iconStyle
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
            outputURL: outputURL,
            iconStyle: IconStyle.current
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
    /// Supports icon style-aware rendering for Default/Dark/Clear/Tinted modes
    static func generatePreview(
        tintColor: TintColor,
        iconType: IconType,
        iconValue: String,
        iconScale: Int = ConfigurationDefaults.iconScale,
        iconWeight: IconWeight = ConfigurationDefaults.iconWeight,
        size: CGFloat = 80,
        iconStyle: IconStyle = IconStyle.current
    ) -> NSImage {
        return generateIcon(
            tintColor: tintColor,
            iconType: iconType,
            iconValue: iconValue,
            iconScale: iconScale,
            iconWeight: iconWeight,
            size: CGSize(width: size, height: size),
            iconStyle: iconStyle
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
            size: CGSize(width: size, height: size),
            iconStyle: IconStyle.current
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
