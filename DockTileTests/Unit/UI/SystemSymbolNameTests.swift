//
//  SystemSymbolNameTests.swift
//  DockTileTests
//
//  An unknown SF Symbol name is a SILENT failure: `Image(systemName:)` draws nothing at all — no
//  warning, no placeholder, no crash — so the affordance simply isn't there. `app.badge.plus`
//  shipped that way in the popover's empty state and was only noticed once the panel was widened
//  enough to show the hole. This sweeps every symbol literal in the app sources and requires the
//  system to resolve it.
//
//  **Known blind spot — do not trust this alone for a NEW symbol.** `NSImage(systemSymbolName:)`
//  resolves against the OS the tests run on, which is newer than the app's macOS 15 deployment
//  floor. A symbol introduced in macOS 26 passes here and draws nothing for a macOS 15 user. Every
//  name currently swept predates 15 by years, so there is no live exposure; when adding one, check
//  its availability in the SF Symbols app first — this test cannot.
//

import AppKit
import Foundation
import Testing
@testable import Dock_Tile

@Suite("SF Symbol names resolve")
struct SystemSymbolNameTests {

    /// Names that are deliberately not system symbols.
    private static let sentinels: Set<String> = [
        // The brand glyph: stored like a symbol but drawn from a bundled template image.
        SFSymbolCatalog.brandSymbolName
    ]

    /// `Image(systemName: "…")` / `NSImage(systemSymbolName: "…")` literals, file by file.
    private static func symbolLiterals() throws -> [(file: String, name: String)] {
        let sources = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // UI
            .deletingLastPathComponent()   // Unit
            .deletingLastPathComponent()   // DockTileTests
            .deletingLastPathComponent()   // repo root
            .appendingPathComponent("DockTile")

        let pattern = try NSRegularExpression(
            pattern: #"system(?:Name|SymbolName):\s*"([^"\\]+)""#
        )

        var found: [(String, String)] = []
        let files = FileManager.default.enumerator(at: sources, includingPropertiesForKeys: nil)
        while let url = files?.nextObject() as? URL {
            guard url.pathExtension == "swift" else { continue }
            let text = try String(contentsOf: url, encoding: .utf8)
            let range = NSRange(text.startIndex..., in: text)
            for match in pattern.matches(in: text, range: range) {
                guard let r = Range(match.range(at: 1), in: text) else { continue }
                found.append((url.lastPathComponent, String(text[r])))
            }
        }
        return found
    }

    @Test("Every symbol literal in the app sources resolves on this OS")
    func everySymbolResolves() throws {
        let literals = try Self.symbolLiterals()
        // Guard the scan itself: a broken regex or path would otherwise pass vacuously.
        #expect(literals.count > 20)

        let unresolved = literals
            .filter { !Self.sentinels.contains($0.name) }
            .filter { NSImage(systemSymbolName: $0.name, accessibilityDescription: nil) == nil }
            .map { "\($0.file): \($0.name)" }

        #expect(unresolved == [])
    }
}
