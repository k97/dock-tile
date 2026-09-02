//
//  AppListEditorTests.swift
//  DockTileTests
//
//  The preview editor's reorder/remove reducer (pure arrays in/out).
//

import Testing
import Foundation
@testable import Dock_Tile

@Suite("AppListEditor")
struct AppListEditorTests {
    private func items(_ names: String...) -> [AppItem] {
        names.map { AppItem(bundleIdentifier: "com.test.\($0)", name: $0) }
    }

    @Test("removing drops exactly the matching item")
    func removing() {
        let list = items("A", "B", "C")
        let out = AppListEditor.removing(list[1].id, from: list)
        #expect(out.map(\.name) == ["A", "C"])
    }

    @Test("removing an unknown id is a no-op")
    func removingUnknown() {
        let list = items("A", "B")
        #expect(AppListEditor.removing(UUID(), from: list).map(\.name) == ["A", "B"])
    }

    @Test("moving forward lands after the target; backward lands before it")
    func moving() {
        let list = items("A", "B", "C", "D")
        #expect(AppListEditor.moving(list[0].id, onto: list[2].id, in: list).map(\.name) == ["B", "C", "A", "D"])
        #expect(AppListEditor.moving(list[3].id, onto: list[1].id, in: list).map(\.name) == ["A", "D", "B", "C"])
    }

    @Test("moving onto itself or an unknown target changes nothing")
    func movingNoop() {
        let list = items("A", "B")
        #expect(AppListEditor.moving(list[0].id, onto: list[0].id, in: list).map(\.name) == ["A", "B"])
        #expect(AppListEditor.moving(list[0].id, onto: UUID(), in: list).map(\.name) == ["A", "B"])
    }
}
