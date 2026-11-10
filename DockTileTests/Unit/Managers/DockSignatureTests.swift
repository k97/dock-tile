import Foundation
import Testing
@testable import Dock_Tile

/// Guards "a bright Update means the Dock is behind". A helper shows the copy sealed with its build
/// (`dockVersion`), so the Dock shows a tile as of its last build; the build stamps `dockSignature` into the helper and
/// Tile Detail paints Update prominent only while the tile differs from that stamp. Failing values:
/// an edit the helper shows (name, layout, app list, mode, icon) that leaves the signature alone, so
/// Update stays quiet with the Dock out of date; bookkeeping that moves it, so Update lights up after
/// every action; and the old rule (every install action prominent).
@Suite("Dock signature (Update prominence)")
struct DockSignatureTests {

    private let one = AppItem(bundleIdentifier: "com.example.one", name: "One")
    private let two = AppItem(bundleIdentifier: "com.example.two", name: "Two")

    private func base() -> DockTileConfiguration {
        DockTileConfiguration(name: "Media", tintColor: .preset(.blue), iconFace: .glyph,
                              layoutMode: .grid, appItems: [one, two], showInAppSwitcher: false)
    }

    // MARK: - dockSignature

    @Test("Every edit a helper shows moves the signature")
    func everyShownFieldCounts() {
        let b = base()
        var variants: [DockTileConfiguration] = []
        var v = b; v.name = "Movies"; variants.append(v)
        v = b; v.layoutMode = .list; variants.append(v)
        v = b; v.showInAppSwitcher = true; variants.append(v)
        v = b; v.appItems = [two, one]; variants.append(v)
        v = b; v.appItems = [one]; variants.append(v)
        v = b; v.tintColor = .preset(.red); variants.append(v)
        v = b; v.iconFace = .apps; variants.append(v)
        for variant in variants {
            #expect(variant.dockSignature != b.dockSignature)
        }
        #expect(Set(variants.map(\.dockSignature)).count == variants.count)
    }

    @Test("Bookkeeping an action writes back leaves the signature alone")
    func bookkeepingIgnored() {
        let b = base()
        var other = b
        other.isVisibleInDock = false
        other.lastDockIndex = 4
        other.helperAppVersion = "9.9.9"
        #expect(other.dockSignature == b.dockSignature)
    }

    @Test("The signature is a stable string built from the icon signature and the shown fields")
    func stableString() {
        let b = base()
        let ids = [one.id.uuidString, two.id.uuidString].joined(separator: ",")
        #expect(b.dockSignature == [b.iconSignature, "Media", "grid", "false", ids].joined(separator: "\u{1F}"))
    }

    @Test("The helper's Info.plist records the Dock signature under DTDockSignature")
    func stampedIntoInfoPlist() {
        let out = HelperBundleManager.helperInfoPlist(
            from: ["CFBundleIdentifier": "com.docktile.app"], bundleId: "com.docktile.helper.x",
            appName: "Media", showInAppSwitcher: false, declarative: true,
            iconSignature: "icon-1", dockSignature: "dock-1")
        #expect(out[HelperBundleManager.dockSignatureKey] as? String == "dock-1")
        #expect(out[HelperBundleManager.iconSignatureKey] as? String == "icon-1")
        #expect(HelperBundleManager.dockSignatureKey == "DTDockSignature")
    }

    // MARK: - actionIsProminent

    @Test("Update is prominent only while the Dock is behind the tile")
    func updateProminence() {
        let current = "sig-now"
        #expect(DockTileDetailView.actionIsProminent(action: .install, isCurrentlyInDock: true,
                                                     builtDockSignature: current, dockSignature: current, appIconsChanged: false) == false)
        #expect(DockTileDetailView.actionIsProminent(action: .install, isCurrentlyInDock: true,
                                                     builtDockSignature: "sig-old", dockSignature: current, appIconsChanged: false) == true)
        // Built before the stamp existed: unknown, so it reads as pending.
        #expect(DockTileDetailView.actionIsProminent(action: .install, isCurrentlyInDock: true,
                                                     builtDockSignature: nil, dockSignature: current, appIconsChanged: false) == true)
    }

    @Test("Add to Dock is always prominent; Remove and Done never are")
    func otherActions() {
        #expect(DockTileDetailView.actionIsProminent(action: .install, isCurrentlyInDock: false,
                                                     builtDockSignature: "s", dockSignature: "s", appIconsChanged: false) == true)
        #expect(DockTileDetailView.actionIsProminent(action: .remove, isCurrentlyInDock: true,
                                                     builtDockSignature: "old", dockSignature: "new", appIconsChanged: false) == false)
        #expect(DockTileDetailView.actionIsProminent(action: .saveOnly, isCurrentlyInDock: false,
                                                     builtDockSignature: nil, dockSignature: "new", appIconsChanged: false) == false)
    }

    @Test("A quiet Update stays enabled — it is also the manual rebuild")
    func quietUpdateStaysEnabled() {
        #expect(DockTileDetailView.dockActionIsEnabled(action: .install, isDirty: false, isProcessing: false) == true)
    }
}
