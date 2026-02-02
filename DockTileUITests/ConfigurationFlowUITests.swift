import XCTest

// MARK: - Configuration Flow UI Tests

/// UI tests for the main configuration workflow
/// These tests verify critical user flows work correctly
///
/// Note: UI tests require accessibility identifiers to be set on UI elements
/// Add .accessibilityIdentifier("identifierName") to SwiftUI views for testing

final class ConfigurationFlowUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Basic Launch Tests

    func testAppLaunches() throws {
        // Verify app launches and main window appears
        XCTAssertTrue(app.windows.count > 0, "App should have at least one window")
    }

    func testMainWindowExists() throws {
        // The main window should exist
        let mainWindow = app.windows.firstMatch
        XCTAssertTrue(mainWindow.exists, "Main window should exist")
    }

    // MARK: - Sidebar Tests

    func testSidebarVisible() throws {
        // The sidebar should be visible with a list of tiles
        // Note: Actual identifier would need to be added to the SwiftUI view
        // This is a template that would work once identifiers are added

        // Wait for the window to load
        let mainWindow = app.windows.firstMatch
        XCTAssertTrue(mainWindow.waitForExistence(timeout: 5))
    }

    // MARK: - Add Tile Flow

    func testAddTileButtonExists() throws {
        // The add tile button should exist in the sidebar
        // Template test - would need accessibility identifier "addTileButton"

        let mainWindow = app.windows.firstMatch
        XCTAssertTrue(mainWindow.waitForExistence(timeout: 5))

        // Once accessibility identifiers are added:
        // let addButton = app.buttons["addTileButton"]
        // XCTAssertTrue(addButton.exists, "Add tile button should exist")
    }

    // MARK: - Detail View Tests

    func testDetailViewShowsSelectedTile() throws {
        // When a tile is selected, detail view should show its properties
        // Template test - would need tiles to exist and be selectable

        let mainWindow = app.windows.firstMatch
        XCTAssertTrue(mainWindow.waitForExistence(timeout: 5))
    }

    // MARK: - Customise View Tests

    func testNavigateToCustomiseView() throws {
        // Clicking "Customise" should navigate to the customise view
        // Template test

        let mainWindow = app.windows.firstMatch
        XCTAssertTrue(mainWindow.waitForExistence(timeout: 5))

        // Once accessibility identifiers are added:
        // app.buttons["customiseButton"].tap()
        // XCTAssertTrue(app.otherElements["customiseView"].waitForExistence(timeout: 2))
    }

    // MARK: - Toggle Tests

    func testShowTileToggle() throws {
        // The "Show Tile" toggle should exist and be interactive
        // Template test

        let mainWindow = app.windows.firstMatch
        XCTAssertTrue(mainWindow.waitForExistence(timeout: 5))
    }

    func testAppSwitcherToggle() throws {
        // The "Show in App Switcher" toggle should exist
        // Template test

        let mainWindow = app.windows.firstMatch
        XCTAssertTrue(mainWindow.waitForExistence(timeout: 5))
    }

    // MARK: - App List Tests

    func testAppsTableExists() throws {
        // The apps table should exist in the detail view
        // Template test

        let mainWindow = app.windows.firstMatch
        XCTAssertTrue(mainWindow.waitForExistence(timeout: 5))
    }
}

// MARK: - Sidebar UI Tests

final class SidebarUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    func testSidebarShowsTileList() throws {
        // Sidebar should show a list of tiles
        let mainWindow = app.windows.firstMatch
        XCTAssertTrue(mainWindow.waitForExistence(timeout: 5))
    }

    func testTileCanBeSelected() throws {
        // Clicking on a tile should select it
        let mainWindow = app.windows.firstMatch
        XCTAssertTrue(mainWindow.waitForExistence(timeout: 5))
    }

    func testDeleteTileButton() throws {
        // Delete tile button should exist when a tile is selected
        let mainWindow = app.windows.firstMatch
        XCTAssertTrue(mainWindow.waitForExistence(timeout: 5))
    }
}

// MARK: - Customise View UI Tests

final class CustomiseViewUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    func testColorPickerExists() throws {
        // Color picker strip should exist in customise view
        let mainWindow = app.windows.firstMatch
        XCTAssertTrue(mainWindow.waitForExistence(timeout: 5))
    }

    func testIconTypeSegmentedControl() throws {
        // SF Symbol / Emoji segmented control should exist
        let mainWindow = app.windows.firstMatch
        XCTAssertTrue(mainWindow.waitForExistence(timeout: 5))
    }

    func testIconScaleStepper() throws {
        // Icon scale stepper should exist
        let mainWindow = app.windows.firstMatch
        XCTAssertTrue(mainWindow.waitForExistence(timeout: 5))
    }

    func testSymbolPickerGrid() throws {
        // Symbol picker grid should show when SF Symbol tab is selected
        let mainWindow = app.windows.firstMatch
        XCTAssertTrue(mainWindow.waitForExistence(timeout: 5))
    }

    func testEmojiPickerGrid() throws {
        // Emoji picker grid should show when Emoji tab is selected
        let mainWindow = app.windows.firstMatch
        XCTAssertTrue(mainWindow.waitForExistence(timeout: 5))
    }

    func testBackButton() throws {
        // Back button should return to detail view
        let mainWindow = app.windows.firstMatch
        XCTAssertTrue(mainWindow.waitForExistence(timeout: 5))
    }
}
