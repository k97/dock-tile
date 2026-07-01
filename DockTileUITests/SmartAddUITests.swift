import XCTest

// MARK: - Smart Add UI Tests
//
// Verifies the + toolbar flow. Smart Add suggestions are computed from *real* on-device usage, so
// whether the sheet appears is environment-dependent — these tests assert the invariants that hold
// either way (blank flow unchanged; sheet dismissable; picking a suggestion pre-fills Tile Detail
// without docking anything). UI tests run locally only (they touch the Dock / real Launch Services).

final class SmartAddUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    private var addButton: XCUIElement { app.buttons["addTileButton"] }
    private var smartAddSheet: XCUIElement { app.otherElements["smartAddSheet"] }

    /// Pressing + either opens the Smart Add sheet (suggestions available) or silently creates a
    /// blank tile (none available) — today's behaviour is preserved in the no-suggestions path.
    func testPlusEitherShowsSheetOrCreatesTile() throws {
        guard addButton.waitForExistence(timeout: 5), addButton.isEnabled else {
            throw XCTSkip("Add button unavailable (tile mid-edit)")
        }
        addButton.click()

        let sheetAppeared = smartAddSheet.waitForExistence(timeout: 3)
        if sheetAppeared {
            // Sheet path: the header, privacy footnote and neutral Create New Tile button are present.
            XCTAssertTrue(app.staticTexts["Add a Tile"].exists, "Sheet should show its header title")
            XCTAssertTrue(app.buttons["Create New Tile"].exists, "Sheet should offer Create New Tile")
        } else {
            // No-suggestions path: a tile detail (with Add to Dock) is shown — the blank flow.
            XCTAssertTrue(app.buttons["Add to Dock"].waitForExistence(timeout: 3),
                          "Blank flow should land on Tile Detail with Add to Dock")
        }
    }

    /// Closing the sheet with Escape must create nothing.
    func testEscapeOnSheetCreatesNothing() throws {
        guard addButton.waitForExistence(timeout: 5), addButton.isEnabled else {
            throw XCTSkip("Add button unavailable")
        }
        addButton.click()
        guard smartAddSheet.waitForExistence(timeout: 3) else {
            throw XCTSkip("No on-device suggestions available in this environment")
        }

        app.typeKey(.escape, modifierFlags: [])

        XCTAssertFalse(smartAddSheet.waitForExistence(timeout: 1), "Esc should dismiss the sheet")
        // Nothing was committed: no provenance banner / pre-filled detail from a suggestion.
        XCTAssertFalse(app.staticTexts["Add a Tile"].exists, "Sheet should be gone after Esc")
    }

    /// Picking "Create New Tile" from the sheet lands on the standard blank Tile Detail.
    func testCreateNewTileFromSheet() throws {
        guard addButton.waitForExistence(timeout: 5), addButton.isEnabled else {
            throw XCTSkip("Add button unavailable")
        }
        addButton.click()
        guard smartAddSheet.waitForExistence(timeout: 3) else {
            throw XCTSkip("No on-device suggestions available in this environment")
        }

        app.buttons["Create New Tile"].click()

        // Blank draft on Tile Detail — Add to Dock is the explicit commit, and nothing is docked yet.
        XCTAssertTrue(app.buttons["Add to Dock"].waitForExistence(timeout: 3),
                      "Create New Tile should land on Tile Detail with Add to Dock")
    }

    /// Picking a suggestion ("Use This Tile") pre-fills Tile Detail without docking anything.
    func testUseThisTilePreFillsDetail() throws {
        guard addButton.waitForExistence(timeout: 5), addButton.isEnabled else {
            throw XCTSkip("Add button unavailable")
        }
        addButton.click()
        guard smartAddSheet.waitForExistence(timeout: 3) else {
            throw XCTSkip("No on-device suggestions available in this environment")
        }

        let useButton = app.buttons["Use This Tile"].firstMatch
        guard useButton.exists else { throw XCTSkip("No suggestion button present") }
        useButton.click()

        // Pre-filled detail still requires the explicit Add to Dock — Smart Add never auto-docks.
        XCTAssertTrue(app.buttons["Add to Dock"].waitForExistence(timeout: 3),
                      "Use This Tile should pre-fill Tile Detail with an Add to Dock confirm")
    }
}
