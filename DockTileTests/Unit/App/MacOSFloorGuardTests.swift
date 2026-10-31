//
//  MacOSFloorGuardTests.swift
//  DockTileTests
//
//  One number — MACOSX_DEPLOYMENT_TARGET in Base.xcconfig — decides what the app supports, and
//  three other places must agree with it or users are misled: the Sparkle appcast floor (which
//  copies are offered the update), the CI matrix (macOS 15 is the only host where the legacy icon
//  path runs, and no dev Mac is on it), and the website's stated requirement. The site said
//  "macOS 26 or later" for months while the binary and appcast said 15.0 — macOS 15 users ran a
//  build the site said they could not, on a code path nothing tested, and the 2.0.2 oversized-tile
//  report came from exactly there. Each test here fails on the specific drift it names.
//
//  When the floor rises past 26, `legacyLegFollowsTheFloor` flips: it then demands the macOS 15
//  leg is GONE, which is the named deletion trigger for the frozen legacy icon path too
//  (see .claude/rules/icon-style-detection.md).
//

import Testing
import Foundation

@Suite("macOS floor: deployment target ↔ appcast ↔ CI ↔ website")
struct MacOSFloorGuardTests {

    /// Repo root, from this file's location (DockTileTests/Unit/App/…).
    private static let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent()

    private static func text(_ path: String) throws -> String {
        try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
    }

    /// `MACOSX_DEPLOYMENT_TARGET = 15.0` → ("15.0", 15).
    private static func deploymentTarget() throws -> (version: String, major: Int) {
        let xcconfig = try text("DockTile/Config/Base.xcconfig")
        let match = try #require(
            xcconfig.firstMatch(of: /MACOSX_DEPLOYMENT_TARGET\s*=\s*([0-9]+(?:\.[0-9]+)?)/))
        let version = String(match.1)
        return (version, try #require(Int(version.split(separator: ".")[0])))
    }

    @Test("The Sparkle appcast floor is the deployment target, so every supported copy is offered the update")
    func appcastFloorMatchesDeploymentTarget() throws {
        let target = try Self.deploymentTarget()
        let script = try Self.text("Scripts/generate-appcast-entry.sh")
        let minOS = try #require(script.firstMatch(of: /MIN_OS="([0-9.]+)"/)).1
        #expect(String(minOS) == target.version, "appcast MIN_OS \(minOS) vs deployment target \(target.version)")
    }

    @Test("The macOS 15 CI leg exists exactly while the floor is below 26")
    func legacyLegFollowsTheFloor() throws {
        let target = try Self.deploymentTarget()
        let ci = try Self.text(".github/workflows/ci.yml")
        let hasLeg = ci.contains("runs-on: macos-15") && ci.contains("test-without-building")
            && ci.contains("test-macos-15:")
        if target.major < 26 {
            #expect(hasLeg, "deployment target \(target.version) still supports macOS 15, but ci.yml has no `test-macos-15` job running `test-without-building` on `macos-15` — the only host where the legacy icon path is tested")
        } else {
            #expect(!ci.contains("macos-15"), "deployment target is \(target.version): delete the macOS 15 CI leg, and with it the frozen legacy icon path (IconStyleManager detection, the 4-variant bake, switchIcon) — the named deletion trigger")
        }
    }

    /// Every REQUIREMENT the website states — "Requires macOS N …", "For macOS N …",
    /// "runs on macOS N …", "macOS N.0 or later" (schema.org), "macOS N+" (badges) — must be the
    /// deployment target's. A feature note such as "On macOS 26 (Tahoe) and later, tile icons …"
    /// is not a requirement and is left alone. `home-sections.tsx` left the list on 2026-10-31: the
    /// closing banner that held its "macOS 15+" was removed (79f00bf); the hero, the requirements
    /// line, the FAQ and schema.org still state the floor.
    @Test("The website states the real floor everywhere it names one", arguments: [
        "website/lib/i18n.ts",
        "website/lib/schema.ts",
        "website/lib/config.ts",
        "website/components/hero.tsx",
    ])
    func websiteStatesTheRealFloor(_ path: String) throws {
        let target = try Self.deploymentTarget()
        let source = try Self.text(path)
        let claims = source.matches(of: /(?i)(?:requires |for |runs on )macOS (\d+)/).map { Int($0.1) ?? -1 }
            + source.matches(of: /macOS (\d+)\.0 or later/).map { Int($0.1) ?? -1 }
            + source.matches(of: /macOS (\d+)\+/).map { Int($0.1) ?? -1 }
        let stated = claims
        #expect(!stated.isEmpty, "\(path) names no macOS version at all; expected at least one mention of the \(target.major) floor")
        for version in stated where version != target.major {
            Issue.record("\(path) claims macOS \(version) where the deployment target is \(target.version)")
        }
    }
}
