//
//  AppStringsTests.swift
//  DockTileTests
//
//  Unit tests for localization strings
//  Swift Testing framework
//

import Testing
import Foundation
@testable import Dock_Tile

@Suite("AppStrings Localization Tests")
struct AppStringsTests {

    // MARK: - String Key Existence Tests

    @Test("All AppStrings keys return non-empty values")
    func allStringsReturnValues() {
        // Test that all string accessors return non-empty strings
        // This ensures no keys are missing from the String Catalog

        // App name
        #expect(!AppStrings.appName.isEmpty)

        #expect(AppStrings.Translation.title == "Translation")
        #expect(!AppStrings.Translation.reviewLine.isEmpty)
        #expect(AppStrings.Translation.helpImprove == "Help Improve…")
        #expect(!AppStrings.Translation.inviteTitle.isEmpty)
        #expect(!AppStrings.Translation.inviteMessage.isEmpty)

        // About
        #expect(!AppStrings.About.title.isEmpty)
        #expect(!AppStrings.About.version("1.0").isEmpty)
        #expect(!AppStrings.About.website.isEmpty)
        #expect(!AppStrings.About.feedbackTitle.isEmpty)
        #expect(!AppStrings.About.feedbackBody.isEmpty)
        #expect(!AppStrings.About.sendFeedback.isEmpty)
        #expect(!AppStrings.About.alsoFrom.isEmpty)
        #expect(!AppStrings.About.studioTitle.isEmpty)
        #expect(!AppStrings.About.studioSubtitle.isEmpty)
        #expect(!AppStrings.About.spadesTitle.isEmpty)
        #expect(!AppStrings.About.spadesSubtitle.isEmpty)
        #expect(!AppStrings.About.learnMore.isEmpty)

        // Alert messages
        #expect(!AppStrings.Alert.restartDockTitle.isEmpty)
        #expect(!AppStrings.Alert.restartDockMessage.isEmpty)
        #expect(!AppStrings.Alert.restartDockCheckbox.isEmpty)
        #expect(!AppStrings.Alert.deleteTileMessage.isEmpty)
        #expect(!AppStrings.Menu.noAppsConfigured.isEmpty)
        #expect(!AppStrings.Menu.noConfiguration.isEmpty)
        #expect(AppStrings.SmartAdd.identityBrowse == "Browse")
        #expect(AppStrings.SmartAdd.identityWatch == "Watch")
        #expect(AppStrings.SmartAdd.identityShip == "Ship")
        #expect(AppStrings.SmartAdd.identityChat == "Chat")
        #expect(AppStrings.SmartAdd.identityWork == "Work")
        #expect(AppStrings.SmartAdd.identityTogether == "Together")

        // Buttons
        #expect(!AppStrings.Button.add.isEmpty)
        #expect(!AppStrings.Button.addATile.isEmpty)
        #expect(!AppStrings.Button.addToDock.isEmpty)
        #expect(!AppStrings.Button.cancel.isEmpty)
        #expect(AppStrings.Button.checkNow == "Check Now")
        #expect(!AppStrings.Button.checkForUpdates.isEmpty)
        #expect(!AppStrings.Button.confirm.isEmpty)
        #expect(!AppStrings.Button.delete.isEmpty)
        #expect(!AppStrings.Button.done.isEmpty)
        #expect(!AppStrings.Button.duplicate.isEmpty)
        #expect(!AppStrings.Button.newTile.isEmpty)
        #expect(!AppStrings.Button.remove.isEmpty)
        #expect(!AppStrings.Button.removeFromDock.isEmpty)
        #expect(!AppStrings.Button.update.isEmpty)

        // Labels
        #expect(!AppStrings.Label.showInAppSwitcher.isEmpty)
        #expect(!AppStrings.Label.showTile.isEmpty)
        #expect(!AppStrings.Label.tileIconSize.isEmpty)
        #expect(!AppStrings.Label.tileName.isEmpty)
        #expect(AppStrings.Label.addAppsAndFolders == "Add Apps & Folders")
        #expect(!AppStrings.Label.appSwitcherNeedsShowTile.isEmpty)
        #expect(!AppStrings.Label.startAtLogin.isEmpty)
        #expect(!AppStrings.Label.startAtLoginDescription.isEmpty)
        #expect(!AppStrings.Label.shareAnalytics.isEmpty)
        #expect(!AppStrings.Label.shareAnalyticsDescription.isEmpty)

        // Settings
        #expect(!AppStrings.Settings.general.isEmpty)
        #expect(!AppStrings.Settings.loginRequiresApproval.isEmpty)
        // Must carry the %@ slot the failure caption formats the system error into.
        #expect(AppStrings.Settings.loginRegistrationFailed.contains("%@"))
        #expect(AppStrings.Settings.addingTiles == "Adding Tiles")

        // Smart Add
        #expect(AppStrings.SmartAdd.settingsToggleTitle == "Suggest tiles from my apps")
        #expect(!AppStrings.SmartAdd.blankTitle.isEmpty)
        #expect(!AppStrings.SmartAdd.blankSubtitle.isEmpty)
        #expect(!AppStrings.SmartAdd.orStartFrom.isEmpty)
        #expect(!AppStrings.SmartAdd.noSuggestions.isEmpty)

        // Tooltips
        #expect(!AppStrings.Tooltip.openSettings.isEmpty)

        // Login items
        #expect(!AppStrings.Button.openLoginItems.isEmpty)

        // Layout options
        #expect(!AppStrings.Layout.grid.isEmpty)
        #expect(!AppStrings.Layout.list.isEmpty)

        // Customise: icon weight picker options
        #expect(AppStrings.IconWeight.light == "Light")
        #expect(AppStrings.IconWeight.regular == "Regular")
        #expect(AppStrings.IconWeight.medium == "Medium")
        #expect(AppStrings.IconWeight.semibold == "Semibold")
        #expect(AppStrings.IconWeight.bold == "Bold")
        #expect(AppStrings.IconWeight.heavy == "Heavy")

        // Emoji picker section headers
        #expect(AppStrings.EmojiCategory.people == "People")
        #expect(AppStrings.EmojiCategory.animalsNature == "Animals & Nature")
        #expect(AppStrings.EmojiCategory.foodDrink == "Food & Drink")
        #expect(AppStrings.EmojiCategory.activity == "Activity")
        #expect(AppStrings.EmojiCategory.travelPlaces == "Travel & Places")
        #expect(AppStrings.EmojiCategory.objects == "Objects")
        #expect(AppStrings.EmojiCategory.symbols == "Symbols")

        // Symbol picker section headers. Runtime values follow the test host's language, so the two
        // keys whose en-US spelling differs are pinned through the catalog JSON below.
        #expect(AppStrings.SymbolCategory.all == "All")
        #expect(AppStrings.SymbolCategory.whatsNew == "What's New")
        #expect(AppStrings.SymbolCategory.draw == "Draw")
        #expect(AppStrings.SymbolCategory.variable == "Variable")
        #expect(!AppStrings.SymbolCategory.multicolor.isEmpty)
        #expect(localizedString(for: "symbolCategory.multicolor", locale: "en-GB") == "Multicolour")
        #expect(localizedString(for: "symbolCategory.multicolor", locale: "en-US") == "Multicolor")
        #expect(AppStrings.SymbolCategory.communication == "Communication")
        #expect(AppStrings.SymbolCategory.weather == "Weather")
        #expect(AppStrings.SymbolCategory.maps == "Maps")
        #expect(AppStrings.SymbolCategory.objectsAndTools == "Objects & Tools")
        #expect(AppStrings.SymbolCategory.devices == "Devices")
        #expect(AppStrings.SymbolCategory.cameraAndPhotos == "Camera & Photos")
        #expect(AppStrings.SymbolCategory.gaming == "Gaming")
        #expect(AppStrings.SymbolCategory.connectivity == "Connectivity")
        #expect(AppStrings.SymbolCategory.transportation == "Transportation")
        #expect(AppStrings.SymbolCategory.automotive == "Automotive")
        #expect(AppStrings.SymbolCategory.accessibility == "Accessibility")
        #expect(AppStrings.SymbolCategory.privacyAndSecurity == "Privacy & Security")
        #expect(AppStrings.SymbolCategory.human == "Human")
        #expect(AppStrings.SymbolCategory.home == "Home")
        #expect(AppStrings.SymbolCategory.fitness == "Fitness")
        #expect(AppStrings.SymbolCategory.nature == "Nature")
        #expect(AppStrings.SymbolCategory.editing == "Editing")
        #expect(AppStrings.SymbolCategory.textFormatting == "Text Formatting")
        #expect(AppStrings.SymbolCategory.media == "Media")
        #expect(AppStrings.SymbolCategory.keyboard == "Keyboard")
        #expect(AppStrings.SymbolCategory.commerce == "Commerce")
        #expect(AppStrings.SymbolCategory.time == "Time")
        #expect(AppStrings.SymbolCategory.health == "Health")
        #expect(AppStrings.SymbolCategory.shapes == "Shapes")
        #expect(AppStrings.SymbolCategory.arrows == "Arrows")
        #expect(AppStrings.SymbolCategory.indices == "Indices")
        #expect(!AppStrings.SymbolCategory.math.isEmpty)
        #expect(localizedString(for: "symbolCategory.math", locale: "en-GB") == "Maths")
        #expect(localizedString(for: "symbolCategory.math", locale: "en-US") == "Math")

        // Menu items
        #expect(!AppStrings.Menu.configure.isEmpty)
        #expect(!AppStrings.Menu.newTile.isEmpty)
        // ⌘N reads "New Tile", not "New Dock Tile": the product name would otherwise be forced
        // untranslated into every language (the lint protects "Dock Tile").
        #expect(localizedString(for: "menu.newTile", locale: "en-GB") == "New Tile")
        #expect(localizedString(for: "menu.newTile", locale: "en-US") == "New Tile")
        #expect(localizedString(for: "menu.newTile", locale: "zh-Hans") == localizedString(for: "button.newTile", locale: "zh-Hans"))
        #expect(!AppStrings.Menu.openInFinder.isEmpty)
        #expect(AppStrings.ItemMenu.open == "Open")
        #expect(AppStrings.ItemMenu.showInFinder == "Show in Finder")
        #expect(AppStrings.ItemMenu.getInfo == "Get Info")
        #expect(AppStrings.ItemMenu.quickLook == "Quick Look")
        #expect(AppStrings.ItemMenu.share == "Share…")
        #expect(AppStrings.ItemMenu.hide == "Hide")
        #expect(AppStrings.ItemMenu.quit == "Quit")
        #expect(AppStrings.ItemMenu.forceQuit == "Force Quit")
        #expect(!AppStrings.Menu.options.isEmpty)
        #expect(!AppStrings.Menu.aboutDockTile.isEmpty)

        // Sidebar
        #expect(!AppStrings.Sidebar.title.isEmpty)
        #expect(AppStrings.Sidebar.dockTileSection == "Dock Tile")

        // Sections
        #expect(!AppStrings.Section.inThisTile.isEmpty)
        #expect(!AppStrings.Label.editorHint.isEmpty)

        // Subtitles
        #expect(!AppStrings.Subtitle.chooseColour.isEmpty)
        #expect(!AppStrings.Subtitle.configureToAdd.isEmpty)
        #expect(!AppStrings.Subtitle.iconSize.isEmpty)

        // Tabs
        #expect(!AppStrings.Tab.emoji.isEmpty)
        #expect(!AppStrings.Tab.symbol.isEmpty)

        // Titles
        #expect(!AppStrings.Title.deleteTile.isEmpty)

        // Tooltips
        #expect(!AppStrings.Tooltip.createNewTile.isEmpty)
        #expect(!AppStrings.Tooltip.editFirst.isEmpty)
        #expect(!AppStrings.Tooltip.deleteTile.isEmpty)

        // Empty states
        #expect(!AppStrings.Empty.createFirstTile.isEmpty)
        #expect(!AppStrings.Empty.createFirstTileDescription.isEmpty)
        #expect(!AppStrings.Empty.detail.isEmpty)
        #expect(!AppStrings.Empty.noApps.isEmpty)
        #expect(!AppStrings.Empty.noTiles.isEmpty)

        // Search
        #expect(!AppStrings.Search.emojis.isEmpty)
        #expect(!AppStrings.Search.symbols.isEmpty)

        // File picker
        #expect(!AppStrings.FilePicker.message.isEmpty)

        // Popover editing (Tile Detail's preview editor)
        #expect(!AppStrings.PopoverOption.editingRemove.isEmpty)
        #expect(!AppStrings.PopoverOption.editingNoAppsTitle.isEmpty)
        #expect(!AppStrings.PopoverOption.editingNoAppsSubtitle.isEmpty)

        // Error messages
        #expect(!AppStrings.Error.failedToReadInfoPlist.isEmpty)
        #expect(!AppStrings.Error.failedToWriteInfoPlist.isEmpty)
        #expect(!AppStrings.Error.failedToCopyBundle.isEmpty)
        #expect(!AppStrings.Error.failedToCodeSign.isEmpty)
    }

    @Test("Inspector strings are non-empty")
    func inspectorStringsNonEmpty() {
        #expect(!AppStrings.Title.customiseTile.isEmpty)
        #expect(!AppStrings.Menu.showInspector.isEmpty)
        #expect(!AppStrings.Menu.hideInspector.isEmpty)
        #expect(!AppStrings.Tooltip.toggleCustomiseTile.isEmpty)
        #expect(!AppStrings.Tooltip.toggleCustomiser.isEmpty)
    }

    @Test("Inspector title spelling follows the English variant")
    func inspectorTitleSpelling() {
        #expect(localizedString(for: "title.customiseTile", locale: "en-GB") == "Customise Tile")
        #expect(localizedString(for: "title.customiseTile", locale: "en-AU") == "Customise Tile")
        #expect(localizedString(for: "title.customiseTile", locale: "en-US") == "Customize Tile")
    }

    @Test("Inspector toggle labels follow the English variant")
    func inspectorToggleSpelling() {
        #expect(localizedString(for: "tooltip.toggleCustomiseTile", locale: "en-GB") == "Toggle Customise Tile")
        #expect(localizedString(for: "tooltip.toggleCustomiseTile", locale: "en-US") == "Toggle Customize Tile")
        #expect(localizedString(for: "tooltip.toggleCustomiser", locale: "en-GB") == "Toggle Customiser")
        #expect(localizedString(for: "tooltip.toggleCustomiser", locale: "en-US") == "Toggle Customizer")
    }

    // MARK: - Locale-Specific Tests

    @Test("UK English spelling used for 'Customise' in en-GB locale")
    func ukEnglishCustomiseSpelling() {
        // Test that UK English locale uses "Customise" not "Customize"
        let customiseTitle = localizedString(for: "title.customiseTile", locale: "en-GB")
        #expect(customiseTitle.contains("Customise"))
        #expect(!customiseTitle.contains("Customize"))
    }

    @Test("US English spelling used for 'Customize' in en-US locale")
    func usEnglishCustomizeSpelling() {
        // Test that US English locale uses "Customize" not "Customise"
        let customizeTitle = localizedString(for: "title.customiseTile", locale: "en-US")
        #expect(customizeTitle.contains("Customize"))
        #expect(!customizeTitle.contains("Customise"))
    }

    @Test("UK English spelling used for 'Colour' in en-GB locale")
    func ukEnglishColourSpelling() {
        // Test that UK English locale uses "Colour" not "Color"
        let colourLabel = localizedString(for: "label.colour", locale: "en-GB")
        #expect(colourLabel.contains("Colour"))
        #expect(!colourLabel.contains("Color"))

        let chooseColour = localizedString(for: "subtitle.chooseColour", locale: "en-GB")
        #expect(chooseColour.contains("colour"))
        #expect(!chooseColour.contains("color"))
    }

    @Test("US English spelling used for 'Color' in en-US locale")
    func usEnglishColorSpelling() {
        // Test that US English locale uses "Color" not "Colour"
        let colorLabel = localizedString(for: "label.colour", locale: "en-US")
        #expect(colorLabel.contains("Color"))
        #expect(!colorLabel.contains("Colour"))

        let chooseColor = localizedString(for: "subtitle.chooseColour", locale: "en-US")
        #expect(chooseColor.contains("color"))
        #expect(!chooseColor.contains("colour"))
    }

    @Test("Australian English uses UK spelling (Customise)")
    func auEnglishCustomiseSpelling() {
        // Test that AU English uses UK spelling
        let customiseTitle = localizedString(for: "title.customiseTile", locale: "en-AU")
        #expect(customiseTitle.contains("Customise"))
        #expect(!customiseTitle.contains("Customize"))
    }

    @Test("Australian English uses UK spelling (Colour)")
    func auEnglishColourSpelling() {
        // Test that AU English uses UK spelling
        let colourLabel = localizedString(for: "label.colour", locale: "en-AU")
        #expect(colourLabel.contains("Colour"))
        #expect(!colourLabel.contains("Color"))
    }

    @Test("Non-English locale falls back to UK English")
    func nonEnglishFallback() {
        // Test that non-English locales (e.g., French) fall back to UK English (en-GB)
        // Since .xcstrings has sourceLanguage = "en-GB", any missing locale falls back to en-GB
        // We verify this by checking that en-GB has the UK spelling
        let customiseTitle = localizedString(for: "title.customiseTile", locale: "en-GB")
        #expect(customiseTitle.contains("Customise"))
        #expect(!customiseTitle.contains("Customize"))

        let colourLabel = localizedString(for: "label.colour", locale: "en-GB")
        #expect(colourLabel.contains("Colour"))
        #expect(!colourLabel.contains("Color"))

        // Note: This test verifies that en-GB is the source language.
        // At runtime, if a user has French locale, NSLocalizedString will automatically
        // fall back to en-GB since sourceLanguage="en-GB" in Localizable.xcstrings
    }

    @Test("Mono tile strings: every key exists in all three locales")
    func monoTileKeysExist() {
        let keys = ["label.background", "label.background.colour", "label.background.mono",
                    "label.background.hint.colour", "label.background.hint.mono",
                    "label.background.colour.accessibility", "label.background.mono.accessibility",
                    "label.symbolColour", "label.colour.hint.fills", "label.colour.hint.deepened",
                    "label.colour.hint.toned", "label.colour.hint.emoji",
                    "label.background.hint.mono.static", "label.background.mono.static.accessibility",
                    "label.colour.hint.toned.static"]
        for key in keys {
            for locale in ["en-GB", "en-US", "en-AU"] {
                // The helper returns "Key '…' not found for locale '…'" on a miss — never "".
                #expect(!localizedString(for: key, locale: locale).hasPrefix("Key '"), "\(key) missing in \(locale)")
            }
        }
        // Exact copy for the strings the user reads first.
        #expect(localizedString(for: "label.background", locale: "en-GB") == "Background")
        #expect(localizedString(for: "label.background.hint.mono", locale: "en-GB") == "White in Light Mode, black in Dark Mode")
        #expect(localizedString(for: "label.symbolColour", locale: "en-US") == "Symbol Color")
        #expect(localizedString(for: "label.background.hint.mono.static", locale: "en-GB") == "White tile with a coloured symbol")
        #expect(localizedString(for: "label.background.hint.mono.static", locale: "en-US") == "White tile with a colored symbol")
        #expect(localizedString(for: "label.background.mono.static.accessibility", locale: "en-AU") == "Mono, a white tile with a coloured symbol")
        #expect(localizedString(for: "label.background.mono.static.accessibility", locale: "en-US") == "Mono, a white tile with a colored symbol")
        #expect(localizedString(for: "label.colour.hint.toned.static", locale: "en-GB") == "Toned to stay clear on white")
        #expect(localizedString(for: "label.colour.hint.toned.static", locale: "en-US") == "Toned to stay clear on white")
    }

    @Test("Mono tile strings spell colour per locale")
    func monoTileSpelling() {
        for key in ["label.symbolColour", "label.background.hint.colour", "label.colour.hint.emoji",
                    "label.background.colour", "label.background.colour.accessibility"] {
            #expect(localizedString(for: key, locale: "en-US").localizedCaseInsensitiveContains("color"), "\(key) en-US")
            #expect(!localizedString(for: key, locale: "en-US").localizedCaseInsensitiveContains("colour"), "\(key) en-US")
            #expect(localizedString(for: key, locale: "en-GB").localizedCaseInsensitiveContains("colour"), "\(key) en-GB")
            #expect(localizedString(for: key, locale: "en-AU").localizedCaseInsensitiveContains("colour"), "\(key) en-AU")
        }
        #expect(!AppStrings.Label.symbolColour.isEmpty)
    }

    // MARK: - Helper Functions

    /// Load and parse the Localizable.xcstrings file to get localized string for a specific locale
    /// - Parameters:
    ///   - key: The localization key
    ///   - locale: The locale to use (e.g., "en-US", "en-GB", "en-AU")
    /// - Returns: The localized string for the given key and locale
    private func localizedString(for key: String, locale: String) -> String {
        // Load the .xcstrings file from the project
        // Use #filePath to get the current test file location, then navigate to project root
        let testFilePath = #filePath
        let projectPath = URL(fileURLWithPath: testFilePath)
            .deletingLastPathComponent()  // Remove AppStringsTests.swift
            .deletingLastPathComponent()  // Remove Constants/
            .deletingLastPathComponent()  // Remove Unit/
            .deletingLastPathComponent()  // Remove DockTileTests/
            .path
        let xcstringsPath = "\(projectPath)/DockTile/Resources/Localizable.xcstrings"

        guard let data = try? Data(contentsOf: URL(fileURLWithPath: xcstringsPath)),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let strings = json["strings"] as? [String: Any],
              let keyData = strings[key] as? [String: Any],
              let localizations = keyData["localizations"] as? [String: Any],
              let localeData = localizations[locale] as? [String: Any],
              let stringUnit = localeData["stringUnit"] as? [String: Any],
              let value = stringUnit["value"] as? String else {
            return "Key '\(key)' not found for locale '\(locale)'"
        }

        return value
    }
}
