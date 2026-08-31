import Testing
import Foundation
@testable import Dock_Tile

// MARK: - Helper icon/style agreement
//
// Guards `HelperBundleManager.iconMatchesStyle`, the launch-time self-heal check.
//
// The regression it exists to catch: a helper seeds its cached icon style at launch but nothing
// verified what was actually on disk, so a tile whose `AppIcon.icns` disagreed with the resolved
// style stayed wrong until the style next *changed* — potentially days. Getting this predicate
// backwards is silent in both directions: return `true` wrongly and stale icons never heal;
// return `false` wrongly and every helper rewrites and re-signs its bundle on every launch.

@Suite("Helper icon matches style")
struct HelperIconMatchTests {

    /// Builds a throwaway `.app` skeleton and returns its URL.
    private func makeBundle(
        live: Data?,
        variants: [IconStyle: Data]
    ) throws -> URL {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("iconmatch-\(UUID().uuidString)")
        let resources = root.appendingPathComponent("Tile.app/Contents/Resources")
        try FileManager.default.createDirectory(at: resources, withIntermediateDirectories: true)

        if let live {
            try live.write(to: resources.appendingPathComponent("AppIcon.icns"))
        }
        for (style, data) in variants {
            let name: String
            switch style {
            case .defaultStyle: name = "AppIcon-default.icns"
            case .dark:         name = "AppIcon-dark.icns"
            case .clear:        name = "AppIcon-clear.icns"
            case .tinted:       name = "AppIcon-tinted.icns"
            }
            try data.write(to: resources.appendingPathComponent(name))
        }
        return root.appendingPathComponent("Tile.app")
    }

    private let alpha = Data("ICNS-ALPHA-CONTENT".utf8)
    private let beta = Data("ICNS-BETA-CONTENT".utf8)

    @Test("Live icon identical to the style's variant reports a match")
    func identicalMatches() throws {
        let bundle = try makeBundle(live: alpha, variants: [.dark: alpha, .defaultStyle: beta])
        #expect(HelperBundleManager.iconMatchesStyle(bundlePath: bundle, style: .dark) == true)
    }

    @Test("Live icon differing from the style's variant reports a mismatch")
    func differentMismatches() throws {
        let bundle = try makeBundle(live: alpha, variants: [.dark: alpha, .defaultStyle: beta])
        #expect(HelperBundleManager.iconMatchesStyle(bundlePath: bundle, style: .defaultStyle) == false)
    }

    @Test("Every style compares against its OWN variant, not a fixed one")
    func eachStyleUsesItsOwnVariant() throws {
        let distinct: [IconStyle: Data] = [
            .defaultStyle: Data("D".utf8),
            .dark: Data("K".utf8),
            .clear: Data("C".utf8),
            .tinted: Data("T".utf8)
        ]
        // Live icon is the CLEAR variant.
        let bundle = try makeBundle(live: distinct[.clear], variants: distinct)

        #expect(HelperBundleManager.iconMatchesStyle(bundlePath: bundle, style: .clear) == true)
        #expect(HelperBundleManager.iconMatchesStyle(bundlePath: bundle, style: .dark) == false)
        #expect(HelperBundleManager.iconMatchesStyle(bundlePath: bundle, style: .tinted) == false)
        #expect(HelperBundleManager.iconMatchesStyle(bundlePath: bundle, style: .defaultStyle) == false)
    }

    @Test("A missing live icon reports a match, so an unanswerable check never forces a rewrite")
    func missingLiveIconIsNotAMismatch() throws {
        let bundle = try makeBundle(live: nil, variants: [.dark: alpha])
        #expect(HelperBundleManager.iconMatchesStyle(bundlePath: bundle, style: .dark) == true)
    }

    @Test("A missing variant reports a match, for the same reason")
    func missingVariantIsNotAMismatch() throws {
        let bundle = try makeBundle(live: alpha, variants: [:])
        #expect(HelperBundleManager.iconMatchesStyle(bundlePath: bundle, style: .tinted) == true)
    }
}
