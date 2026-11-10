//
//  AppIconStyleRendererTests.swift
//  DockTileTests
//
//  Guards `AppIconStyleRenderer`: an App Grid bake renders each app in a NAMED icon style
//  (Default / Dark / Clear Dark) through IconServices, independent of the style the system is in.
//  The runtime tests fail — they do not skip — on macOS 26+ when a render comes back nil: the
//  macos-26 CI leg is the only check that the private API still behaves there.
//

import AppKit
import Testing
@testable import Dock_Tile

@Suite("App icon style renderer")
@MainActor
struct AppIconStyleRendererTests {
    private static let textEdit = URL(fileURLWithPath: "/System/Applications/TextEdit.app")

    @Test("Each render style maps to IconServices' appearance and appearance variant")
    func descriptorValues() {
        #expect(AppIconStyleRenderer.descriptorValues(for: .standard) == (appearance: 0, appearanceVariant: 0))
        #expect(AppIconStyleRenderer.descriptorValues(for: .dark) == (appearance: 1, appearanceVariant: 0))
        #expect(AppIconStyleRenderer.descriptorValues(for: .clearDark) == (appearance: 1, appearanceVariant: 3))
    }

    @Test("Default and Clear Dark renders of TextEdit really differ (white page vs dark clear plate)")
    func stylesReallyDiffer() throws {
        guard #available(macOS 26.0, *) else { return }   // no icon styles before Tahoe
        let standard = try #require(AppIconStyleRenderer.render(appAt: Self.textEdit, pixelSize: 64, style: .standard))
        let clear = try #require(AppIconStyleRenderer.render(appAt: Self.textEdit, pixelSize: 64, style: .clearDark))
        // IconServices may hand back a larger backing (e.g. 2×); the bake draws into a box, so the
        // contract is square and at least the requested size.
        #expect(standard.width == standard.height && standard.width >= 64, "\(standard.width)×\(standard.height)")
        #expect(clear.width == clear.height && clear.width >= 64, "\(clear.width)×\(clear.height)")
        let gap = Self.meanLuminance(standard) - Self.meanLuminance(clear)
        #expect(gap >= 0.3, "Default \(Self.meanLuminance(standard)) vs Clear Dark \(Self.meanLuminance(clear))")
    }

    @Test("The IconServices render carries the same icon-grid margin as the public render")
    func sameMarginAsWorkspace() throws {
        guard #available(macOS 26.0, *) else { return }
        let ours = try #require(AppIconStyleRenderer.render(appAt: Self.textEdit, pixelSize: 256, style: .standard))
        var rect = CGRect(x: 0, y: 0, width: 256, height: 256)
        let workspace = try #require(NSWorkspace.shared.icon(forFile: Self.textEdit.path)
            .cgImage(forProposedRect: &rect, context: nil, hints: nil))
        // Compared as a fraction of each image's width: the two may come back at different scales.
        let a = Double(Self.opaqueExtent(ours)) / Double(ours.width)
        let b = Double(Self.opaqueExtent(workspace)) / Double(workspace.width)
        #expect(abs(a - b) <= 0.01, "IconServices \(a) vs NSWorkspace \(b) of the width")
        #expect(abs(a - AppsFaceGrid.appIconContentRatio) <= 0.01,
                "a render filling \(a) of its width breaks AppsFaceGrid.drawBox's ÷0.805")
    }

    @Test("A path that is not an app bundle renders nothing rather than a generic icon")
    func nonBundleIsNil() {
        #expect(AppIconStyleRenderer.render(appAt: URL(fileURLWithPath: "/no/such/App.app"), pixelSize: 64, style: .standard) == nil)
    }

    @Test("A bake slot restyles apps through IconServices and keeps folders' public image")
    func styledMinisRestyleAppsOnly() throws {
        guard #available(macOS 26.0, *) else { return }
        let placeholder = NSImage(size: NSSize(width: 8, height: 8))
        let app = AppItem(bundleIdentifier: "com.apple.TextEdit", name: "TextEdit", lastKnownPath: Self.textEdit.path)
        let folder = AppItem(bundleIdentifier: "folder.1", name: "Tmp", isFolder: true, folderPath: NSTemporaryDirectory())
        let entries = [HelperBundleManager.AppsFaceEntry(item: app, image: placeholder),
                       HelperBundleManager.AppsFaceEntry(item: folder, image: placeholder)]
        let styled = HelperBundleManager.styledAppsFaceMinis(entries, style: .clearDark)
        #expect(styled.fallbacks == 0)
        #expect(styled.minis.count == 2)
        #expect(styled.minis[0].image !== placeholder && !styled.minis[0].isFolder)   // re-rendered
        #expect(styled.minis[1].image === placeholder && styled.minis[1].isFolder)    // folder kept
        // Two items → a 2×2 cell; the render is at least the app draw box on the 1024 canvas.
        let box = AppsFaceGrid.drawBox(for: AppsFaceGrid.cells(count: 2)[0], isFolder: false).width * 1024
        #expect(styled.minis[0].image.size.width == box.rounded(.up))
    }

    @Test("An app with a Finder custom icon keeps its public image (the styled render draws the bundle's own icon)")
    func finderCustomIconKeepsPublicImage() throws {
        guard #available(macOS 26.0, *) else { return }
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("CustomIcon-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        let app = root.appendingPathComponent("Custom.app")
        try FileManager.default.createDirectory(at: app.appendingPathComponent("Contents"), withIntermediateDirectories: true)
        let bundleID = "com.docktile.tests.customicon"
        let plist: [String: Any] = ["CFBundleIdentifier": bundleID, "CFBundlePackageType": "APPL", "CFBundleName": "Custom"]
        try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
            .write(to: app.appendingPathComponent("Contents/Info.plist"))
        let placeholder = NSImage(size: NSSize(width: 8, height: 8))
        let entries = [HelperBundleManager.AppsFaceEntry(
            item: AppItem(bundleIdentifier: bundleID, name: "Custom", lastKnownPath: app.path), image: placeholder)]

        // Control: without Finder's file the app is re-rendered, so the check below can fail.
        let plain = HelperBundleManager.styledAppsFaceMinis(entries, style: .standard)
        #expect(plain.minis[0].image !== placeholder)

        #expect(FileManager.default.createFile(atPath: app.appendingPathComponent("Icon\r").path, contents: Data()))
        let custom = HelperBundleManager.styledAppsFaceMinis(entries, style: .standard)
        #expect(custom.minis[0].image === placeholder)
        #expect(custom.fallbacks == 0)
    }

    // MARK: - Pixel helpers

    private static func bitmap(_ image: CGImage) -> NSBitmapImageRep {
        let rep = NSBitmapImageRep(cgImage: image)
        return rep.converting(to: .sRGB, renderingIntent: .default) ?? rep
    }

    private static func meanLuminance(_ image: CGImage) -> Double {
        let rep = bitmap(image)
        var sum = 0.0, count = 0.0
        for y in 0..<rep.pixelsHigh {
            for x in 0..<rep.pixelsWide {
                guard let c = rep.colorAt(x: x, y: y), c.alphaComponent >= 0.5 else { continue }
                sum += 0.2126 * c.redComponent + 0.7152 * c.greenComponent + 0.0722 * c.blueComponent
                count += 1
            }
        }
        return count == 0 ? 0 : sum / count
    }

    private static func opaqueExtent(_ image: CGImage) -> Int {
        let rep = bitmap(image)
        let y = rep.pixelsHigh / 2
        let xs = (0..<rep.pixelsWide).filter { (rep.colorAt(x: $0, y: y)?.alphaComponent ?? 0) > 0.5 }
        guard let lo = xs.first, let hi = xs.last else { return 0 }
        return hi - lo + 1
    }
}
