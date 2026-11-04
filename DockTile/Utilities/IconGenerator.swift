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
import CoreImage
import SwiftUI

@MainActor
struct IconGenerator {

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
        background: TileBackground,
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

        let rect = CGRect(origin: .zero, size: size)
        // The margin must stay transparent, so clear before drawing anything.
        context.clear(rect)

        // Icon-grid margin from the shared seam, exactly as the Tahoe fallback `.icns` bakes it.
        // The Dock scales every icon to one tile size, so a full-bleed shape drew ~24 % larger
        // than every neighbouring icon on macOS 15 (feedback 2026-09-30). The glyph below stays
        // measured against the FULL canvas, matching the fallback and the layer PNGs.
        // Guarded by `LegacyIcnsMarginTests`.
        let inset = size.width * IconDepthMetrics.contentInsetRatio
        let shapeRect = rect.insetBy(dx: inset, dy: inset)

        // Corner radius is 22.5% of the SHAPE (matches DockTileIconPreview's cornerRadius)
        let cornerRadius = shapeRect.width * 0.225

        // Create squircle path (continuous corners matching Tahoe guidelines)
        let squirclePath = createSquirclePath(in: shapeRect, cornerRadius: cornerRadius)

        // Get appearance-aware colors. Colours come from `TilePalette` by background × style × icon
        // type (Colour emoji keeps its darkened own tint in Dark; Mono uses the neutral near-black).
        let colors = tintColor.nsColors(for: iconStyle, iconType: iconType, background: background)

        // Draw gradient background (appearance-aware)
        drawGradient(
            context: context,
            path: squirclePath,
            topColor: colors.backgroundTop,
            bottomColor: colors.backgroundBottom,
            rect: shapeRect
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
            rect: shapeRect,
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

    /// Draw the beveled glass INNER stroke effect matching DockTileIconPreview's `strokeBorder`.
    /// White stroke with configurable opacity, width from the shared seam.
    ///
    /// Clipping to the squircle and stroking at DOUBLE width is the inner-stroke equivalence:
    /// CoreGraphics centres a stroke on the path, so the previous unclipped single-width stroke
    /// painted half its width OUTSIDE the shape (a ~1.6px half-opacity white halo tracing the
    /// tile at the 1024px bake) and left only half of it visible inside — half the width the
    /// preview draws. Guarded by `IconStrokeGeometryTests`.
    private static func drawBeveledStroke(
        context: CGContext,
        path: CGPath,
        size: CGSize,
        strokeOpacity: CGFloat = 0.5
    ) {
        context.saveGState()

        // Scale line width proportionally (shared seam — matches the live preview).
        let lineWidth = IconDepthMetrics.strokeLineWidth(nominalSize: size.width)

        // Clip to the shape so the outer half of the stroke is discarded…
        context.addPath(path)
        context.clip()

        // …and stroke at 2× width so the surviving inner half is the full seam width.
        context.addPath(path)
        context.setStrokeColor(NSColor.white.withAlphaComponent(strokeOpacity).cgColor)
        context.setLineWidth(lineWidth * 2)
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
            // Fallback to a default symbol if the requested one doesn't exist. This silently
            // changes what the tile looks like, so it must be loud (see fallbackReason).
            reportIconFallback(fallbackReason(forUnresolvedSymbol: symbolName), iconValue: symbolName)
            drawFallbackSymbol(rect: rect, fontSize: fontSize, weight: weight, color: color, shadow: shadow, bottomDarken: bottomDarken, sheen: sheen)
            return
        }

        drawGlyphMask(symbolImage, rect: rect, color: color, shadow: shadow, bottomDarken: bottomDarken, sheen: sheen)
    }

    /// Which fallback error applies when a glyph name fails to resolve to an `NSImage`. Pure so
    /// the brand-sentinel-vs-ordinary-symbol distinction is unit-tested without NSImage/AppKit —
    /// they are different failures (a missing bundled resource vs. a bad/unsupported symbol
    /// name) and must not share a message.
    nonisolated static func fallbackReason(forUnresolvedSymbol symbolName: String) -> IconGeneratorError {
        symbolName == SFSymbolCatalog.brandSymbolName ? .brandGlyphMissing : .symbolUnresolvable(name: symbolName)
    }

    /// Records that a tile's requested glyph could not be resolved and the placeholder star icon
    /// was baked instead — silent wrong icons are against this codebase's loud-failure posture.
    private static func reportIconFallback(_ error: IconGeneratorError, iconValue: String) {
        DiagnosticsLog.shared.log("icon", "\(error.errorDescription ?? "Icon glyph unresolved") — fell back to star.fill for '\(iconValue)'")
        AnalyticsService.shared.record(error, context: "IconGenerator.drawSFSymbol", keys: ["icon_value": iconValue])
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
        background: TileBackground,
        outputURL: URL,
        iconStyle: IconStyle = IconStyle.current
    ) throws {
        try buildIcns(outputURL: outputURL) { size in
            generateIcon(
                tintColor: tintColor,
                iconType: iconType,
                iconValue: iconValue,
                iconScale: iconScale,
                iconWeight: iconWeight,
                background: background,
                size: size,
                iconStyle: iconStyle
            )
        }
    }

    /// Render every standard `.icns` rendition with `render` and pack them with `iconutil`.
    /// Shared by the legacy 4-variant bake and the declarative fallback so the two cannot drift
    /// on rendition set or on scratch handling.
    private static func buildIcns(outputURL: URL, render: (CGSize) -> NSImage) throws {
        // Standard macOS icon sizes for .icns (base sizes)
        // Each needs 1x and @2x versions
        let baseSizes: [Int] = [16, 32, 128, 256, 512]

        // Create iconset scratch OUTSIDE the destination (which is typically a helper bundle's
        // Resources/): building it beside outputURL meant any thrown save or a killed process
        // left a stray `.iconset` inside the bundle — the exact killed-mid-generation damage
        // `helperIconsComplete` exists to detect. Temp dir + defer keeps failures clean.
        let iconsetURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("docktile-iconset-\(UUID().uuidString).iconset")
        try FileManager.default.createDirectory(at: iconsetURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: iconsetURL) }

        // Generate all sizes (1x and @2x for each base size)
        for baseSize in baseSizes {
            // 1x version
            let image1x = render(CGSize(width: baseSize, height: baseSize))
            let filename1x = "icon_\(baseSize)x\(baseSize).png"
            try saveAsPNG(image: image1x, url: iconsetURL.appendingPathComponent(filename1x))

            // @2x version (retina) - actual pixels are 2x the base size
            let image2x = render(CGSize(width: baseSize * 2, height: baseSize * 2))
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
}

// MARK: - Lean Glyph Layer (declarative .icon pipeline)

extension IconGenerator {

    /// A single transparent-background layer PNG for an Icon Composer `.icon` document:
    /// **the glyph and nothing else**.
    ///
    /// WHY THIS IS NOT `generateIcon`: a legacy `.icns` gets no system treatment, so
    /// `generateIcon` bakes the whole tile — squircle, gradient background, glass stroke,
    /// surface sheen, glyph sheen. A COMPILED icon is different: macOS applies its own Liquid
    /// Glass pass at render time (that is how the Clear appearance exists at all) and the
    /// background comes from the document's JSON fill gradient, not from pixels. Baking our
    /// emulated effects under the system's real ones doubles them. So this path KEEPS only the
    /// glyph-intrinsic depth — the shading gradient and the contact shadow — and DROPS the
    /// shape, the background, the stroke and both sheens. Everything outside the glyph stays
    /// fully transparent.
    ///
    /// Appearance is a LAYER SWAP (the document hides/shows whole layers; a layer `fill` does
    /// not recolour a glyph), so the colour is baked here: `.light` and `.tinted` → the
    /// palette's light glyph (white for Colour, the fitted tone for Mono — the two-layer document
    /// shows the light layer for tinted; macOS derives the tinted/clear relief from alpha),
    /// `.dark` → the palette's dark glyph. All come from `TintColor.nsColors(for:iconType:background:)`
    /// — the contrast fit is not re-derived. **Emoji ignore appearance entirely**: they are colour glyphs that cannot be
    /// recoloured, so one full-colour layer serves every appearance (verified 2026-09-01 —
    /// the system's tinted pass renders emoji as a legible monochrome relief, even for flat
    /// single-colour artwork). The brand glyph is a tintable raster and routes as a symbol.
    ///
    /// Geometry is the existing `IconDepthMetrics` ratio applied to the new canvas — same
    /// ratios, larger canvas — so the declarative tile matches the legacy bake and the preview.
    ///
    /// `iconScale` and `iconWeight` are deliberately **without defaults**. Defaulting them to
    /// `ConfigurationDefaults` would let a call site omit the user's actual size or weight and
    /// silently bake the wrong tile — a defect no test could catch, since the only production
    /// caller sits inside a private method of this `@MainActor`, filesystem-bound pipeline.
    /// Omission is a compile error instead. (`canvas` keeps its default: it is a real knob with
    /// one correct value, not a per-tile setting.)
    static func generateGlyphLayerPNG(
        appearance: IconAppearance,
        tintColor: TintColor,
        background: TileBackground,
        iconType: IconType,
        iconValue: String,
        iconScale: Int,
        iconWeight: IconWeight,
        canvas: Int = 1024
    ) throws -> Data {
        let side = CGFloat(canvas)
        let size = CGSize(width: side, height: side)

        // Explicit pixel dimensions (never `lockFocus`, which builds a Retina-scaled backing
        // store and yields the wrong pixel count).
        guard let bitmapRep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: canvas,
            pixelsHigh: canvas,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ), let graphicsContext = NSGraphicsContext(bitmapImageRep: bitmapRep) else {
            throw IconGeneratorError.imageConversionFailed
        }
        bitmapRep.size = size

        let rect = CGRect(origin: .zero, size: size)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = graphicsContext
        // A freshly allocated bitmap's contents are undefined — and unlike `generateIcon`
        // nothing paints an opaque background here, so clear it explicitly. This transparency
        // IS the contract: no baked squircle, no plate behind the glyph.
        graphicsContext.cgContext.clear(rect)

        // Emoji ride ONE shared layer, so their depth must not vary by appearance either.
        let style = depthStyle(for: appearance, iconType: iconType)
        let colors = tintColor.nsColors(for: style, iconType: iconType, background: background)
        let fontSize = side * IconDepthMetrics.glyphSizeRatio(
            iconScale: iconScale, iconType: iconType, iconValue: iconValue
        )
        let shadow = IconDepthMetrics.glyphShadow(
            style: style, iconType: iconType, nominalSize: side
        )
        let bottomDarken = IconDepthMetrics.glyphBottomDarken(
            style: style, iconType: iconType, nominalSize: side
        )

        switch iconType {
        case .sfSymbol:
            // `sheen: nil` — the specular gloss is the system's job on a compiled icon.
            drawSFSymbol(
                symbolName: iconValue,
                rect: rect,
                fontSize: fontSize,
                weight: iconWeight.nsFontWeight,
                color: colors.foreground,
                shadow: shadow,
                bottomDarken: bottomDarken,
                sheen: nil
            )
        case .emoji:
            drawEmoji(emoji: iconValue, rect: rect, fontSize: fontSize, shadow: shadow, sheen: nil)
        }

        NSGraphicsContext.restoreGraphicsState()

        guard let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
            throw IconGeneratorError.pngExportFailed
        }
        return pngData
    }

    /// The declarative pipeline's fallback `.icns` — ONE file, not four style variants.
    ///
    /// macOS renders every appearance from the per-tile `Assets.car`; this exists only for the
    /// contexts that read `CFBundleIconFile` instead. It is the LIGHT composition at the same
    /// margined geometry as the compiled icon: the tint gradient inside the inset squircle plus
    /// the lean glyph — deliberately no glass stroke and no sheen, matching the layer PNGs,
    /// because those are effects the system supplies for the real icon.
    static func generateFallbackIcns(
        tintColor: TintColor,
        background: TileBackground,
        iconType: IconType,
        iconValue: String,
        iconScale: Int,
        iconWeight: IconWeight,
        outputURL: URL
    ) throws {
        try buildIcns(outputURL: outputURL) { size in
            fallbackIcon(
                tintColor: tintColor,
                background: background,
                iconType: iconType,
                iconValue: iconValue,
                iconScale: iconScale,
                iconWeight: iconWeight,
                size: size
            )
        }
    }

    /// One rendition of the fallback icon: margined gradient squircle + the light lean glyph.
    private static func fallbackIcon(
        tintColor: TintColor,
        background: TileBackground,
        iconType: IconType,
        iconValue: String,
        iconScale: Int,
        iconWeight: IconWeight,
        size: CGSize
    ) -> NSImage {
        guard let bitmapRep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(size.width),
            pixelsHigh: Int(size.height),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ), let graphicsContext = NSGraphicsContext(bitmapImageRep: bitmapRep) else {
            return NSImage(size: size)
        }
        bitmapRep.size = size

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = graphicsContext
        let context = graphicsContext.cgContext

        let rect = CGRect(origin: .zero, size: size)
        // The margin must stay transparent, so clear before drawing anything.
        context.clear(rect)

        // Icon-grid margin from the shared seam — the live preview draws the same inset.
        let inset = size.width * IconDepthMetrics.contentInsetRatio
        let contentRect = rect.insetBy(dx: inset, dy: inset)
        let squirclePath = createSquirclePath(
            in: contentRect, cornerRadius: contentRect.width * 0.225
        )

        // Light appearance = the Default style's colours, from the shared seam.
        let colors = tintColor.nsColors(for: .defaultStyle, iconType: iconType, background: background)
        drawGradient(
            context: context,
            path: squirclePath,
            topColor: colors.backgroundTop,
            bottomColor: colors.backgroundBottom,
            rect: contentRect
        )

        // Glyph geometry is measured against the FULL canvas, exactly as the layer PNGs are, so
        // the fallback and the compiled icon place the glyph identically.
        let fontSize = size.width * IconDepthMetrics.glyphSizeRatio(
            iconScale: iconScale, iconType: iconType, iconValue: iconValue
        )
        let shadow = IconDepthMetrics.glyphShadow(
            style: .defaultStyle, iconType: iconType, nominalSize: size.width
        )
        let bottomDarken = IconDepthMetrics.glyphBottomDarken(
            style: .defaultStyle, iconType: iconType, nominalSize: size.width
        )

        switch iconType {
        case .sfSymbol:
            drawSFSymbol(
                symbolName: iconValue,
                rect: rect,
                fontSize: fontSize,
                weight: iconWeight.nsFontWeight,
                color: colors.foreground,
                shadow: shadow,
                bottomDarken: bottomDarken,
                sheen: nil
            )
        case .emoji:
            drawEmoji(emoji: iconValue, rect: rect, fontSize: fontSize, shadow: shadow, sheen: nil)
        }

        NSGraphicsContext.restoreGraphicsState()

        let image = NSImage(size: size)
        image.addRepresentation(bitmapRep)
        return image
    }

    /// Which style's depth magnitudes the layer borrows from the seam.
    ///
    /// `.tinted` deliberately resolves to the SAME treatment as `.light`: the tinted glyph is
    /// the light glyph (mono, system-tinted), so the two layers are byte-identical and the
    /// document can reuse one PNG for both. Emoji pin to `.defaultStyle` regardless of
    /// appearance — one shared layer cannot carry per-appearance depth.
    private static func depthStyle(for appearance: IconAppearance, iconType: IconType) -> IconStyle {
        guard iconType != .emoji else { return .defaultStyle }
        switch appearance {
        case .light, .tinted: return .defaultStyle
        case .dark:           return .dark
        }
    }
}

// MARK: - Apps face

extension IconGenerator {

    /// One mini in the Apps face: an app icon (or a folder glyph) already resolved to an image.
    struct AppsFaceMini {
        let image: NSImage
        let isFolder: Bool
    }

    /// The Apps face's single composite layer: a grid of mini app icons on a transparent canvas.
    ///
    /// No squircle, stroke or sheen: the system draws the tile shape and the glass, and flat
    /// minis are what iOS folders show. Each mini does carry a soft CONTACT shadow, because a
    /// light icon would otherwise vanish on near-white glass. An empty `minis` draws the empty
    /// 2x2's slots, toned for `onDarkGlass` (the appearance slot this layer is for).
    static func generateAppsLayerPNG(minis: [AppsFaceMini], canvas: Int = 1024, onDarkGlass: Bool = false) throws -> Data {
        let side = CGFloat(canvas)
        let size = CGSize(width: side, height: side)

        guard let bitmapRep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: canvas,
            pixelsHigh: canvas,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ), let graphicsContext = NSGraphicsContext(bitmapImageRep: bitmapRep) else {
            throw IconGeneratorError.imageConversionFailed
        }
        bitmapRep.size = size

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = graphicsContext
        graphicsContext.cgContext.clear(CGRect(origin: .zero, size: size))

        // The whole canvas is the tile: in an Icon Composer document the system adds the
        // icon-grid margin itself when it renders, so this layer must NOT inset by
        // `contentInsetRatio` (that shrank every mini by 0.805 in the Dock). Flat bakes
        // (`appsIcon`) still inset — a flat icon carries its own margin.
        let shape = CGRect(origin: .zero, size: size)
        drawAppsGrid(minis: minis, shape: shape, nominalSize: side, desaturate: false,
                     onDarkGlass: onDarkGlass, in: graphicsContext.cgContext)

        NSGraphicsContext.restoreGraphicsState()

        guard let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
            throw IconGeneratorError.pngExportFailed
        }
        return pngData
    }

    /// Draws up to `AppsFaceGrid.maxItems` minis into their cells. `desaturate` greys each mini
    /// first (Clear/Tinted keep the legacy path's grayscale promise). No minis: the empty 2x2's
    /// slots (`AppsFaceGrid.emptySlotFill`), toned for `onDarkGlass`.
    private static func drawAppsGrid(
        minis: [AppsFaceMini],
        shape: CGRect,
        nominalSize: CGFloat,
        desaturate: Bool,
        onDarkGlass: Bool,
        in context: CGContext
    ) {
        if minis.isEmpty {
            let fill = AppsFaceGrid.emptySlotFill(onDarkGlass: onDarkGlass)
            context.setFillColor(NSColor(white: fill.white, alpha: fill.alpha).cgColor)
            for cell in AppsFaceGrid.cells(count: AppsFaceGrid.emptySlotCount) {
                let box = AppsFaceGrid.rect(cell, in: shape, yUp: true)
                context.addPath(createSquirclePath(in: box, cornerRadius: box.width * AppsFaceGrid.slotCornerRatio))
                context.fillPath()
            }
            return
        }
        let shown = Array(minis.prefix(AppsFaceGrid.maxItems))
        let cells = AppsFaceGrid.cells(count: shown.count)
        let shadow = AppsFaceGrid.miniShadow(nominalSize: nominalSize)

        for (mini, cell) in zip(shown, cells) {
            let box = AppsFaceGrid.rect(
                AppsFaceGrid.drawBox(for: cell, isFolder: mini.isFolder), in: shape, yUp: true
            )
            context.saveGState()
            if let shadow {
                context.setShadow(
                    offset: CGSize(width: 0, height: -shadow.offset),
                    blur: shadow.blur,
                    color: NSColor.black.withAlphaComponent(shadow.blackAlpha).cgColor
                )
            }
            // Copy so resizing never mutates the caller's image; `size` makes draw(in:) scale
            // the whole bitmap into the box.
            let source = desaturate ? desaturated(mini.image, pixelSize: box.size) : mini.image
            let image = (source.copy() as? NSImage) ?? source
            image.size = box.size
            image.draw(in: box, from: .zero, operation: .sourceOver, fraction: 1,
                       respectFlipped: true, hints: [.interpolation: NSImageInterpolation.high])
            context.restoreGState()
        }
    }

    /// The Apps face baked as a flat bitmap: the icon-grid-inset squircle filled top-to-bottom
    /// with the tile's plate (`AppsFaceGrid.fillColors`), the mini grid on top. No stroke and no
    /// sheen, like the compiled icon. Under Follow System the plate is the vendored compiler's
    /// resolution of `system-light` / `system-dark` (`AppsFaceGrid.fillGrays`), so the bake, the
    /// preview and the compiled icon agree. Clear/Tinted minis are desaturated to keep the legacy path's grayscale promise.
    static func appsIcon(minis: [AppsFaceMini], size: CGSize, iconStyle: IconStyle,
                         background: AppsGridBackground,
                         customHex: String) -> NSImage {
        guard let bitmapRep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(size.width),
            pixelsHigh: Int(size.height),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ), let graphicsContext = NSGraphicsContext(bitmapImageRep: bitmapRep) else {
            return NSImage(size: size)
        }
        bitmapRep.size = size

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = graphicsContext
        let context = graphicsContext.cgContext
        let rect = CGRect(origin: .zero, size: size)
        context.clear(rect)

        let inset = size.width * IconDepthMetrics.contentInsetRatio
        let shape = rect.insetBy(dx: inset, dy: inset)
        let path = createSquirclePath(in: shape, cornerRadius: shape.width * 0.225)
        let colors = AppsFaceGrid.fillColors(background: background, customHex: customHex, style: iconStyle)
        drawGradient(
            context: context,
            path: path,
            topColor: NSColor(srgbRed: colors.top.r, green: colors.top.g, blue: colors.top.b, alpha: 1),
            bottomColor: NSColor(srgbRed: colors.bottom.r, green: colors.bottom.g, blue: colors.bottom.b, alpha: 1),
            rect: shape
        )
        drawAppsGrid(minis: minis, shape: shape, nominalSize: size.width,
                     desaturate: AppsFaceGrid.desaturatesMinis(style: iconStyle),
                     onDarkGlass: AppsFaceGrid.usesDarkPlate(background: background, customHex: customHex, style: iconStyle), in: context)
        NSGraphicsContext.restoreGraphicsState()

        let image = NSImage(size: size)
        image.addRepresentation(bitmapRep)
        return image
    }

    /// The Apps face as the macOS 26 fallback `.icns` (light composition).
    static func generateAppsFallbackIcns(minis: [AppsFaceMini], outputURL: URL,
                                         background: AppsGridBackground,
                                         customHex: String) throws {
        try buildIcns(outputURL: outputURL) { appsIcon(minis: minis, size: $0, iconStyle: .defaultStyle, background: background, customHex: customHex) }
    }

    /// One Apps-face style variant `.icns` for the macOS 15 four-variant bake.
    static func generateAppsIcns(minis: [AppsFaceMini], outputURL: URL, iconStyle: IconStyle,
                                 background: AppsGridBackground,
                                 customHex: String) throws {
        try buildIcns(outputURL: outputURL) { appsIcon(minis: minis, size: $0, iconStyle: iconStyle, background: background, customHex: customHex) }
    }

    /// Grayscale copy via `CIColorControls` (saturation 0), rendered into an explicit-pixel
    /// bitmap. Rasterised for `pixelSize` (the destination box), not the image's point size:
    /// IconServices icons are ~32 pt with many reps, and a point-size raster would pick a
    /// small one and be stretched blurry. Returns `image` untouched if any step fails.
    private static func desaturated(_ image: NSImage, pixelSize: CGSize) -> NSImage {
        var proposed = CGRect(origin: .zero, size: pixelSize)
        guard let cg = image.cgImage(forProposedRect: &proposed, context: nil, hints: nil),
              let gray = desaturated(cg) else { return image }
        let result = NSImage(size: NSSize(width: gray.width, height: gray.height))
        result.addRepresentation(NSBitmapImageRep(cgImage: gray))
        return result
    }

    /// The bitmap form, shared by the bake and the in-app preview so both drain a mini the same
    /// way. The preview used SwiftUI's `.saturation(0)` filter, which the CI runner's renderer did
    /// not apply (minis stayed coloured under Clear/Tinted, 2026-10-20); a drained bitmap does not
    /// depend on the renderer. Nil if any step fails.
    static func desaturated(_ cg: CGImage) -> CGImage? {
        guard let filter = CIFilter(name: "CIColorControls") else { return nil }
        filter.setValue(CIImage(cgImage: cg), forKey: kCIInputImageKey)
        filter.setValue(0, forKey: kCIInputSaturationKey)
        guard let output = filter.outputImage,
              let rep = NSBitmapImageRep(
                bitmapDataPlanes: nil,
                pixelsWide: cg.width,
                pixelsHigh: cg.height,
                bitsPerSample: 8,
                samplesPerPixel: 4,
                hasAlpha: true,
                isPlanar: false,
                colorSpaceName: .deviceRGB,
                bytesPerRow: 0,
                bitsPerPixel: 0
              ),
              let ctx = NSGraphicsContext(bitmapImageRep: rep) else { return nil }
        let extent = CGRect(x: 0, y: 0, width: cg.width, height: cg.height)
        CIContext(cgContext: ctx.cgContext, options: nil).draw(output, in: extent, from: output.extent)
        return rep.cgImage
    }
}

// MARK: - NSImage Extension for Tinting

extension NSImage {
    /// A copy of this image flat-filled with `color`, preserving its alpha.
    ///
    /// Rendered into an explicit-pixel `NSBitmapImageRep` — never `lockFocus`, which builds a
    /// Retina-scaled backing store and yields the wrong pixel count (the rule this file's own
    /// `generateIcon` header states). Mirrors `gradientFilledGlyph` / `sheenGlyph`, which
    /// already build their glyph copies this way. Returns `self` if a context can't be made,
    /// which is the same "draw it untinted" degradation the caller already tolerates.
    func tinted(with color: NSColor) -> NSImage {
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
              let graphicsContext = NSGraphicsContext(bitmapImageRep: rep) else {
            return self
        }
        rep.size = size

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = graphicsContext
        let bounds = NSRect(origin: .zero, size: size)
        draw(in: bounds)
        color.set()
        bounds.fill(using: .sourceAtop)
        NSGraphicsContext.restoreGraphicsState()

        let output = NSImage(size: size)
        output.addRepresentation(rep)
        return output
    }
}

// MARK: - Errors

enum IconGeneratorError: Error, LocalizedError, Equatable {
    case imageConversionFailed
    case pngExportFailed
    case icnsConversionFailed
    /// A tile colour could not be converted to the colour space a renderer needs. Thrown rather
    /// than substituted: a silent fallback colour would bake a wrong-coloured tile with nothing
    /// anywhere to say so.
    case colorConversionFailed
    /// The requested SF Symbol name doesn't resolve on this OS (typo, renamed, or a symbol not
    /// available at the deployment target) — not thrown, just recorded, since the tile still
    /// gets a placeholder star icon rather than failing generation outright.
    case symbolUnresolvable(name: String)
    /// The bundled DockTile brand glyph resource (`DockTileGlyph.png`) failed to load — a missing
    /// bundle resource, distinct from an unresolvable symbol name. Also not thrown; recorded so
    /// the silent star-icon substitution isn't invisible.
    case brandGlyphMissing

    /// Conforming to `LocalizedError` is what makes this message actually surface: a generic
    /// `catch { error.localizedDescription }` on the `any Error` existential resolves through
    /// the NSError bridge, which only reads a real message when the type conforms here. Without
    /// this, every case read as the generic "The operation couldn't be completed."
    var errorDescription: String? {
        switch self {
        case .imageConversionFailed:
            return "Failed to convert NSImage to CGImage"
        case .pngExportFailed:
            return "Failed to export PNG data"
        case .icnsConversionFailed:
            return "Failed to convert iconset to .icns file"
        case .colorConversionFailed:
            return "Failed to convert a tile colour to the required colour space"
        case .symbolUnresolvable(let name):
            return "SF Symbol '\(name)' could not be found — used a placeholder star icon instead. Choose a different symbol in Customise Tile."
        case .brandGlyphMissing:
            return "The DockTile brand glyph resource is missing from the app bundle — used a placeholder star icon instead. Reinstalling Dock Tile should restore it."
        }
    }
}
