//
//  TilePalette.swift
//  DockTile
//
//  The single source of every tile colour. `ToneMap` fits a colour to a contrast floor while
//  holding its hue (OKLCH lightness bisection, chroma reduced to stay in sRGB gamut, the real
//  WCAG 2 ratio measured at every step — Adobe Leonardo's approach). `TilePalette` (below) maps a
//  tile's one stored colour to its role per background × style. Plain sRGB values only — no
//  AppKit/SwiftUI — so every rule is unit-testable. Renderers read it through the thin
//  `TintColor.colors/nsColors/badgeColors` adapters in IconStyleManager.swift.
//
//  Swift 6 - Strict Concurrency
//

import Foundation

/// A gamma-encoded sRGB colour, components 0…1.
struct SRGB: Hashable, Sendable {
    var r: Double
    var g: Double
    var b: Double

    nonisolated static let white = SRGB(r: 1, g: 1, b: 1)

    nonisolated init(r: Double, g: Double, b: Double) {
        self.r = r; self.g = g; self.b = b
    }

    /// `#RRGGBB` / `RRGGBB`; an 8-digit `RRGGBBAA` ignores alpha. Nil for anything else.
    nonisolated init?(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6 || s.count == 8, let v = UInt64(s, radix: 16) else { return nil }
        let rgb = s.count == 8 ? v >> 8 : v
        self.init(r: Double((rgb >> 16) & 0xFF) / 255,
                  g: Double((rgb >> 8) & 0xFF) / 255,
                  b: Double(rgb & 0xFF) / 255)
    }

    /// Blend toward black by `fraction` — a conservative approximation of `NSColor.darkened(by:)`
    /// (it darkens slightly MORE than AppKit's blend, so contrast checks built on it err safe).
    nonisolated func darkened(by fraction: Double) -> SRGB {
        SRGB(r: r * (1 - fraction), g: g * (1 - fraction), b: b * (1 - fraction))
    }

    /// HSB lighten: brightness + amount, saturation − amount × 0.3 (custom colours' lighter
    /// gradient stop).
    nonisolated func lighterShade(by amount: Double) -> SRGB {
        let (h, s, v) = hsv
        return SRGB.fromHSV(h: h, s: max(0, s - amount * 0.3), v: min(1, v + amount))
    }

    /// HSB brightness cap with hue and saturation held — pure mirror of
    /// `NSColor.darkenedForDarkMode(maxBrightness:)`. Scaling every channel keeps H and S.
    nonisolated func cappingBrightness(_ cap: Double) -> SRGB {
        let v = max(r, g, b)
        guard v > cap, v > 0 else { return self }
        let k = cap / v
        return SRGB(r: r * k, g: g * k, b: b * k)
    }

    private nonisolated var hsv: (h: Double, s: Double, v: Double) {
        let mx = max(r, g, b), mn = min(r, g, b), d = mx - mn
        let s = mx == 0 ? 0 : d / mx
        var h = 0.0
        if d > 0 {
            if mx == r { h = ((g - b) / d).truncatingRemainder(dividingBy: 6) }
            else if mx == g { h = (b - r) / d + 2 }
            else { h = (r - g) / d + 4 }
            h /= 6
            if h < 0 { h += 1 }
        }
        return (h, s, mx)
    }

    private nonisolated static func fromHSV(h: Double, s: Double, v: Double) -> SRGB {
        let i = floor(h * 6), f = h * 6 - i
        let p = v * (1 - s), q = v * (1 - f * s), t = v * (1 - (1 - f) * s)
        switch Int(i) % 6 {
        case 0: return SRGB(r: v, g: t, b: p)
        case 1: return SRGB(r: q, g: v, b: p)
        case 2: return SRGB(r: p, g: v, b: t)
        case 3: return SRGB(r: p, g: q, b: v)
        case 4: return SRGB(r: t, g: p, b: v)
        default: return SRGB(r: v, g: p, b: q)
        }
    }
}

/// Contrast measurement and hue-preserving lightness fitting.
enum ToneMap {
    enum Direction { case darker, lighter }

    /// The promise: symbol vs background ≥ 3:1 (WCAG 2.2 SC 1.4.11 non-text contrast). A Dock icon
    /// is compiled once and cannot react to Increase Contrast, so this is the only target.
    nonisolated static let floor = 3.0
    /// Search headroom so 8-bit quantisation and colour-space conversion never land a rendered
    /// pair below `floor`.
    nonisolated static let margin = 0.1
    nonisolated static var searchTarget: Double { floor + margin }

    nonisolated static func relativeLuminance(_ c: SRGB) -> Double {
        0.2126 * linear(c.r) + 0.7152 * linear(c.g) + 0.0722 * linear(c.b)
    }

    nonisolated static func contrastRatio(_ a: SRGB, _ b: SRGB) -> Double {
        let la = relativeLuminance(a), lb = relativeLuminance(b)
        return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
    }

    /// The colour closest to `colour` (same OKLCH hue) that satisfies `passes`, moving lightness
    /// in `direction`. Returns `colour` unchanged when it already passes. `passes` tests the pair
    /// the renderer really draws (e.g. a shaded glyph bottom), which is why it is a predicate.
    nonisolated static func fit(_ colour: SRGB, direction: Direction, passes: (SRGB) -> Bool) -> SRGB {
        if passes(colour) { return colour }
        let start = OKLCH(colour)
        let endL = direction == .darker ? 0.0 : 1.0
        let end = start.withL(endL).inGamut()
        guard passes(end) else { return end }   // unreachable for a 3:1 target; never loops
        var failing = start.L, passing = endL
        for _ in 0..<24 {
            let mid = (failing + passing) / 2
            if passes(start.withL(mid).inGamut()) { passing = mid } else { failing = mid }
        }
        return start.withL(passing).inGamut()
    }

    /// The same hue and chroma with OKLCH lightness moved by `delta` (clamped to 0…1).
    nonisolated static func shiftingLightness(_ colour: SRGB, by delta: Double) -> SRGB {
        let c = OKLCH(colour)
        return c.withL(min(max(c.L + delta, 0), 1)).inGamut()
    }

    /// OKLCH hue in degrees, or nil for a near-grey (hue undefined below chroma 0.02).
    nonisolated static func hueDegrees(_ c: SRGB) -> Double? {
        let o = OKLCH(c)
        guard o.C >= 0.02 else { return nil }
        let d = o.h * 180 / .pi
        return d < 0 ? d + 360 : d
    }

    // MARK: sRGB transfer

    nonisolated static func linear(_ c: Double) -> Double {
        c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
    }

    nonisolated static func encoded(_ c: Double) -> Double {
        c <= 0.0031308 ? 12.92 * c : 1.055 * pow(c, 1 / 2.4) - 0.055
    }
}

/// OKLab in polar form (Björn Ottosson's matrices).
private struct OKLCH {
    var L: Double
    var C: Double
    var h: Double   // radians

    nonisolated init(L: Double, C: Double, h: Double) { self.L = L; self.C = C; self.h = h }

    nonisolated init(_ c: SRGB) {
        let r = ToneMap.linear(c.r), g = ToneMap.linear(c.g), b = ToneMap.linear(c.b)
        let l = cbrt(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b)
        let m = cbrt(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b)
        let s = cbrt(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b)
        let L = 0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s
        let A = 1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s
        let B = 0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s
        self.init(L: L, C: (A * A + B * B).squareRoot(), h: atan2(B, A))
    }

    nonisolated func withL(_ newL: Double) -> OKLCH { OKLCH(L: newL, C: C, h: h) }

    /// Linear-light RGB, unclamped.
    nonisolated func linearRGB(chroma: Double) -> (Double, Double, Double) {
        let A = chroma * cos(h), B = chroma * sin(h)
        let l = pow(L + 0.3963377774 * A + 0.2158037573 * B, 3)
        let m = pow(L - 0.1055613458 * A - 0.0638541728 * B, 3)
        let s = pow(L - 0.0894841775 * A - 1.2914855480 * B, 3)
        return (4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
                -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
                -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s)
    }

    /// The sRGB colour at this L and h, with chroma reduced (bisected) until it is in gamut.
    nonisolated func inGamut() -> SRGB {
        func fits(_ c: Double) -> Bool {
            let (r, g, b) = linearRGB(chroma: c)
            let e = 1e-6
            return [r, g, b].allSatisfy { $0 >= -e && $0 <= 1 + e }
        }
        var chroma = C
        if !fits(chroma) {
            var lo = 0.0, hi = C
            for _ in 0..<24 {
                let mid = (lo + hi) / 2
                if fits(mid) { lo = mid } else { hi = mid }
            }
            chroma = lo
        }
        let (r, g, b) = linearRGB(chroma: chroma)
        func enc(_ v: Double) -> Double { ToneMap.encoded(min(max(v, 0), 1)) }
        return SRGB(r: enc(r), g: enc(g), b: enc(b))
    }
}

// MARK: - Tint inputs

extension TintColor {
    /// The saturated base (preset bottom stop / custom hex). A malformed custom hex falls back to
    /// the grey preset — never black (an old hand-edited config must not bake a black tile).
    nonisolated var baseRGB: SRGB {
        switch self {
        case .preset(let p): return SRGB(hex: p.baseHex)!
        case .custom(let hex): return SRGB(hex: hex) ?? SRGB(hex: PresetColor.gray.baseHex)!
        }
    }

    /// The lighter stop, used only by the Colour + Dark + emoji darkened-own-tint background.
    nonisolated var lightRGB: SRGB {
        switch self {
        case .preset(let p): return SRGB(hex: p.lightHex)!
        case .custom: return baseRGB.lighterShade(by: 0.15)
        }
    }
}

// MARK: - TilePalette

/// Every tile colour, per background × style × icon type. See the spec's role table:
/// docs/superpowers/specs/2026-10-13-mono-tile-background-design.md
enum TilePalette {
    struct Roles: Equatable, Sendable {
        let top: SRGB
        let bottom: SRGB
        let glyph: SRGB
    }

    nonisolated static let lightTop = SRGB(hex: "#FFFFFF")!
    nonisolated static let lightBottom = SRGB(hex: "#EFEFF1")!
    nonisolated static let darkTop = SRGB(hex: TintColor.darkNeutralTopHex)!
    nonisolated static let darkBottom = SRGB(hex: TintColor.darkNeutralBottomHex)!
    private nonisolated static let clear = Roles(top: SRGB(hex: "#F0F0F2")!, bottom: SRGB(hex: "#E0E0E4")!, glyph: SRGB(hex: "#6E6E73")!)
    private nonisolated static let tinted = Roles(top: SRGB(hex: "#8E8E93")!, bottom: SRGB(hex: "#636366")!, glyph: .white)
    /// OKLCH lightness step from a Colour fill's top stop to its bottom stop.
    nonisolated static let colourFillBottomStep = -0.06

    nonisolated static func resolve(
        tint: TintColor, background: TileBackground, style: IconStyle, iconType: IconType
    ) -> Roles {
        resolve(base: tint.baseRGB, light: tint.lightRGB, background: background, style: style, iconType: iconType)
    }

    /// Raw-colour form (sidebar Settings badges carry a `Color`, not a `TintColor`).
    nonisolated static func resolve(
        base: SRGB, light: SRGB, background: TileBackground, style: IconStyle, iconType: IconType
    ) -> Roles {
        switch style {
        case .clear:
            return clear
        case .tinted:
            return tinted
        case .defaultStyle:
            switch background {
            case .colour:
                let top = colourFill(base)
                return Roles(top: top, bottom: ToneMap.shiftingLightness(top, by: colourFillBottomStep), glyph: .white)
            case .mono:
                return Roles(top: lightTop, bottom: lightBottom, glyph: monoLightGlyph(base))
            }
        case .dark:
            if background == .colour && iconType == .emoji {
                // An emoji can't be recoloured, so a Colour emoji tile keeps its own hue, darkened.
                return Roles(top: light.cappingBrightness(0.22), bottom: base.cappingBrightness(0.13), glyph: .white)
            }
            return Roles(top: darkTop, bottom: darkBottom, glyph: darkGlyph(base))
        }
    }

    /// Whether a Colour tile's fill had to move to clear the floor (drives the "Deepened" hint).
    nonisolated static func fillWasDeepened(tint: TintColor) -> Bool {
        colourFill(tint.baseRGB) != tint.baseRGB
    }

    // MARK: Fits — each tests the weakest pair the renderer actually draws

    /// White symbol against the fill's LIGHTER (top) stop, AND the symbol's SHADED bottom
    /// against the fill's darker (bottom) stop.
    private nonisolated static func colourFill(_ base: SRGB) -> SRGB {
        let shade = Double(IconDepthMetrics.glyphBottomDarken(style: .defaultStyle, iconType: .sfSymbol, nominalSize: 1024) ?? 0)
        let shadedWhite = SRGB.white.darkened(by: shade)
        return ToneMap.fit(base, direction: .darker) { top in
            let bottom = ToneMap.shiftingLightness(top, by: colourFillBottomStep)
            return ToneMap.contrastRatio(.white, top) >= ToneMap.searchTarget
                && ToneMap.contrastRatio(shadedWhite, bottom) >= ToneMap.searchTarget
        }
    }

    /// Unshaded symbol top against the tile's DARKER (bottom) stop.
    private nonisolated static func monoLightGlyph(_ base: SRGB) -> SRGB {
        ToneMap.fit(base, direction: .darker) { ToneMap.contrastRatio($0, lightBottom) >= ToneMap.searchTarget }
    }

    /// The symbol's SHADED bottom against the tile's LIGHTER (top) stop.
    private nonisolated static func darkGlyph(_ base: SRGB) -> SRGB {
        let shade = Double(IconDepthMetrics.glyphBottomDarken(style: .dark, iconType: .sfSymbol, nominalSize: 1024) ?? 0)
        return ToneMap.fit(base, direction: .lighter) {
            ToneMap.contrastRatio($0.darkened(by: shade), darkTop) >= ToneMap.searchTarget
        }
    }
}
