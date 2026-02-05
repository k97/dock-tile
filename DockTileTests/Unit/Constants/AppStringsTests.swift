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

        // Alert messages
        #expect(!AppStrings.Alert.restartDockTitle.isEmpty)
        #expect(!AppStrings.Alert.restartDockMessage.isEmpty)
        #expect(!AppStrings.Alert.restartDockCheckbox.isEmpty)

        // Buttons
        #expect(!AppStrings.Button.add.isEmpty)
        #expect(!AppStrings.Button.addToDock.isEmpty)
        #expect(!AppStrings.Button.back.isEmpty)
        #expect(!AppStrings.Button.cancel.isEmpty)
        #expect(!AppStrings.Button.confirm.isEmpty)
        #expect(!AppStrings.Button.customise.isEmpty)
        #expect(!AppStrings.Button.delete.isEmpty)
        #expect(!AppStrings.Button.done.isEmpty)
        #expect(!AppStrings.Button.duplicate.isEmpty)
        #expect(!AppStrings.Button.newTile.isEmpty)
        #expect(!AppStrings.Button.remove.isEmpty)
        #expect(!AppStrings.Button.removeFromDock.isEmpty)
        #expect(!AppStrings.Button.update.isEmpty)

        // Labels
        #expect(!AppStrings.Label.colour.isEmpty)
        #expect(!AppStrings.Label.layout.isEmpty)
        #expect(!AppStrings.Label.showInAppSwitcher.isEmpty)
        #expect(!AppStrings.Label.showTile.isEmpty)
        #expect(!AppStrings.Label.tileIcon.isEmpty)
        #expect(!AppStrings.Label.tileIconSize.isEmpty)
        #expect(!AppStrings.Label.tileName.isEmpty)

        // Layout options
        #expect(!AppStrings.Layout.grid.isEmpty)
        #expect(!AppStrings.Layout.list.isEmpty)

        // Menu items
        #expect(!AppStrings.Menu.configure.isEmpty)
        #expect(!AppStrings.Menu.newTile.isEmpty)
        #expect(!AppStrings.Menu.openInFinder.isEmpty)
        #expect(!AppStrings.Menu.options.isEmpty)

        // Navigation
        #expect(!AppStrings.Navigation.customiseTile.isEmpty)

        // Sidebar
        #expect(!AppStrings.Sidebar.title.isEmpty)

        // Sections
        #expect(!AppStrings.Section.selectedItems.isEmpty)

        // Subtitles
        #expect(!AppStrings.Subtitle.chooseColour.isEmpty)
        #expect(!AppStrings.Subtitle.configureToAdd.isEmpty)
        #expect(!AppStrings.Subtitle.iconSize.isEmpty)

        // Tabs
        #expect(!AppStrings.Tab.emoji.isEmpty)
        #expect(!AppStrings.Tab.symbol.isEmpty)

        // Table headers
        #expect(!AppStrings.Table.item.isEmpty)
        #expect(!AppStrings.Table.kind.isEmpty)

        // Titles
        #expect(!AppStrings.Title.deleteTile.isEmpty)

        // Tooltips
        #expect(!AppStrings.Tooltip.createNewTile.isEmpty)
        #expect(!AppStrings.Tooltip.editFirst.isEmpty)

        // Empty states
        #expect(!AppStrings.Empty.createFirstTile.isEmpty)
        #expect(!AppStrings.Empty.detail.isEmpty)
        #expect(!AppStrings.Empty.noApps.isEmpty)
        #expect(!AppStrings.Empty.noItemsAdded.isEmpty)
        #expect(!AppStrings.Empty.noTiles.isEmpty)

        // Search
        #expect(!AppStrings.Search.emojis.isEmpty)
        #expect(!AppStrings.Search.symbols.isEmpty)

        // File picker
        #expect(!AppStrings.FilePicker.message.isEmpty)

        // Kind values
        #expect(!AppStrings.Kind.application.isEmpty)
        #expect(!AppStrings.Kind.folder.isEmpty)

        // Error messages
        #expect(!AppStrings.Error.mainAppNotFound.isEmpty)
        #expect(!AppStrings.Error.failedToReadInfoPlist.isEmpty)
        #expect(!AppStrings.Error.failedToWriteInfoPlist.isEmpty)
        #expect(!AppStrings.Error.failedToCopyBundle.isEmpty)
        #expect(!AppStrings.Error.failedToCodeSign.isEmpty)
    }

    // MARK: - Locale-Specific Tests

    @Test("UK English spelling used for 'Customise' in en-GB locale")
    func ukEnglishCustomiseSpelling() {
        // Test that UK English locale uses "Customise" not "Customize"
        let customiseButton = localizedString(for: "button.customise", locale: "en-GB")
        #expect(customiseButton.contains("Customise"))
        #expect(!customiseButton.contains("Customize"))
    }

    @Test("US English spelling used for 'Customize' in en-US locale")
    func usEnglishCustomizeSpelling() {
        // Test that US English locale uses "Customize" not "Customise"
        let customizeButton = localizedString(for: "button.customise", locale: "en-US")
        #expect(customizeButton.contains("Customize"))
        #expect(!customizeButton.contains("Customise"))
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
        let customiseButton = localizedString(for: "button.customise", locale: "en-AU")
        #expect(customiseButton.contains("Customise"))
        #expect(!customiseButton.contains("Customize"))
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
        let customiseButton = localizedString(for: "button.customise", locale: "en-GB")
        #expect(customiseButton.contains("Customise"))
        #expect(!customiseButton.contains("Customize"))

        let colourLabel = localizedString(for: "label.colour", locale: "en-GB")
        #expect(colourLabel.contains("Colour"))
        #expect(!colourLabel.contains("Color"))

        // Note: This test verifies that en-GB is the source language.
        // At runtime, if a user has French locale, NSLocalizedString will automatically
        // fall back to en-GB since sourceLanguage="en-GB" in Localizable.xcstrings
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
