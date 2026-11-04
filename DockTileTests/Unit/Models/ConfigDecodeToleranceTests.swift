import Foundation
import Testing
@testable import Dock_Tile

/// One tile this build cannot read must not empty the tile list. The whole-array decode this replaced
/// returned nothing for a file with one bad tile, and the next save wrote that empty list over every
/// tile. Failing value: 0 tiles where the two readable ones should load.
///
/// Fixtures must REALLY fail to decode: `LayoutMode`, `TileBackground`, `IconFace` and
/// `AppsGridBackground` map unknown values to a default, so they cannot make a tile unreadable.
/// `IconType` and the required v1 keys (`id`, `name`, …) can.
@Suite("Config decode tolerance")
struct ConfigDecodeToleranceTests {

    private static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601  // matches ConfigurationManager
        return decoder
    }

    /// A real encoded tile as a JSON object, so a test can damage one key.
    private static func tileObject(named name: String) throws -> [String: Any] {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(DockTileConfiguration(name: name))
        return try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    private static func file(_ tiles: [[String: Any]]) throws -> Data {
        try JSONSerialization.data(withJSONObject: tiles)
    }

    @Test("A file of readable tiles loads every tile")
    func allReadable() throws {
        let data = try Self.file([Self.tileObject(named: "A"), Self.tileObject(named: "B"), Self.tileObject(named: "C")])
        let result = DockTileConfiguration.decodeTolerantly(data, using: Self.decoder())
        #expect(result.tiles.map(\.name) == ["A", "B", "C"])
        #expect(result.skipped == 0)
        #expect(result.firstError == nil)
        #expect(result.wholeFileUnreadable == false)
    }

    @Test("A tile missing a required key is skipped; the others load in order")
    func missingRequiredKeyIsSkipped() throws {
        var bad = try Self.tileObject(named: "Bad")
        bad.removeValue(forKey: "id")
        let data = try Self.file([Self.tileObject(named: "A"), bad, Self.tileObject(named: "C")])
        let result = DockTileConfiguration.decodeTolerantly(data, using: Self.decoder())
        #expect(result.tiles.map(\.name) == ["A", "C"])
        #expect(result.skipped == 1)
        #expect(result.firstError != nil)
        #expect(result.wholeFileUnreadable == false)
    }

    @Test("A tile with an enum value this build does not know is skipped")
    func unknownEnumValueIsSkipped() throws {
        var newer = try Self.tileObject(named: "Newer")
        newer["iconType"] = "widget"
        let data = try Self.file([Self.tileObject(named: "A"), newer, Self.tileObject(named: "C")])
        let result = DockTileConfiguration.decodeTolerantly(data, using: Self.decoder())
        #expect(result.tiles.map(\.name) == ["A", "C"])
        #expect(result.skipped == 1)
    }

    /// `symbolEmoji` stays a required v1 key (`missingRequiredFieldThrows`): without it and `iconValue`
    /// a tile would load as an SF Symbol named "⭐" and draw nothing. Now it costs that one tile only.
    @Test("A tile without the legacy symbolEmoji key is skipped; the others load")
    func missingSymbolEmojiSkipsThatTileOnly() throws {
        var legacy = try Self.tileObject(named: "NoLegacy")
        legacy.removeValue(forKey: "symbolEmoji")
        let data = try Self.file([Self.tileObject(named: "A"), legacy])
        let result = DockTileConfiguration.decodeTolerantly(data, using: Self.decoder())
        #expect(result.tiles.map(\.name) == ["A"])
        #expect(result.skipped == 1)
    }

    @Test("A file that is not a tile array is unreadable as a whole", arguments: [
        #"{"not": "an array"}"#,
        #"[{"id": "#,  // truncated mid-write
    ])
    func wholeFileUnreadable(_ text: String) {
        let result = DockTileConfiguration.decodeTolerantly(Data(text.utf8), using: Self.decoder())
        #expect(result.tiles.isEmpty)
        #expect(result.skipped == 0)
        #expect(result.wholeFileUnreadable == true)
        #expect(result.firstError != nil)
    }
}
