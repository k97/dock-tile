import Foundation
import Testing
@testable import Dock_Tile

/// `iconData` used to embed every app's whole `.icns` in the config JSON (release config 10 MB,
/// dev 130 MB), making every save, copy and equality check scale with icon bytes.
/// Failing values: an encoded item that still contains an "iconData" key; a legacy config that no
/// longer decodes.
@Suite("AppItem no longer persists icon blobs")
struct AppItemIconDataRemovalTests {

    private let legacyJSON = """
    {
      "id": "11111111-2222-3333-4444-555555555555",
      "bundleIdentifier": "com.example.app",
      "name": "Example",
      "iconData": "aGVsbG8gaWNvbg==",
      "isFolder": false,
      "lastKnownPath": "/Applications/Example.app"
    }
    """

    @Test("A legacy item that carries iconData still decodes, with every other field intact")
    func legacyItemDecodes() throws {
        let item = try JSONDecoder().decode(AppItem.self, from: Data(legacyJSON.utf8))
        #expect(item.id == UUID(uuidString: "11111111-2222-3333-4444-555555555555"))
        #expect(item.bundleIdentifier == "com.example.app")
        #expect(item.name == "Example")
        #expect(item.isFolder == false)
        #expect(item.lastKnownPath == "/Applications/Example.app")
    }

    @Test("Re-encoding a legacy item drops the blob")
    func reencodingDropsTheBlob() throws {
        let item = try JSONDecoder().decode(AppItem.self, from: Data(legacyJSON.utf8))
        let encoded = try #require(String(data: JSONEncoder().encode(item), encoding: .utf8))
        #expect(encoded.contains("iconData") == false)
        #expect(encoded.contains("aGVsbG8gaWNvbg==") == false)
    }

    @Test("An item built from a real app bundle encodes to well under 1 KB")
    func newItemIsSmall() throws {
        let item = try #require(AppItem.from(appURL: URL(fileURLWithPath: "/System/Applications/Calculator.app")))
        let bytes = try JSONEncoder().encode(item).count
        #expect(bytes < 1024)
    }
}
