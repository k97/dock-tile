//
//  AppStringsTests.swift
//  DockTileTests
//
//  Unit tests for localization strings
//  Swift Testing framework
//

import Testing
import Foundation
@testable import DockTile

@Suite("AppStrings Localization Tests")
struct AppStringsTests {

    // MARK: - String Key Existence Tests

    @Test("All AppStrings keys return non-empty values")
    func allStringsReturnValues() {
        // Test that all string accessors return non-empty strings
        // This ensures no keys are missing from the String Catalog

        // App name
        #expect(!AppStrings.appName.isEmpty)

        // Buttons
        #expect(!AppStrings.Button.add.isEmpty)
        #expect(!AppStrings.Button.addToDock.isEmpty)
        #expect(!AppStrings.Button.back.isEmpty)
        #expect(!AppStrings.Button.cancel.isEmpty)
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
        withLocale("en-GB") {
            let customiseButton = AppStrings.Button.customise
            #expect(customiseButton.contains("Customise"))
            #expect(!customiseButton.contains("Customize"))
        }
    }

    @Test("US English spelling used for 'Customize' in en-US locale")
    func usEnglishCustomizeSpelling() {
        // Test that US English locale uses "Customize" not "Customise"
        withLocale("en-US") {
            let customizeButton = AppStrings.Button.customise
            #expect(customizeButton.contains("Customize"))
            #expect(!customizeButton.contains("Customise"))
        }
    }

    @Test("UK English spelling used for 'Colour' in en-GB locale")
    func ukEnglishColourSpelling() {
        // Test that UK English locale uses "Colour" not "Color"
        withLocale("en-GB") {
            let colourLabel = AppStrings.Label.colour
            #expect(colourLabel.contains("Colour"))
            #expect(!colourLabel.contains("Color"))

            let chooseColour = AppStrings.Subtitle.chooseColour
            #expect(chooseColour.contains("colour"))
            #expect(!chooseColour.contains("color"))
        }
    }

    @Test("US English spelling used for 'Color' in en-US locale")
    func usEnglishColorSpelling() {
        // Test that US English locale uses "Color" not "Colour"
        withLocale("en-US") {
            let colorLabel = AppStrings.Label.colour
            #expect(colorLabel.contains("Color"))
            #expect(!colorLabel.contains("Colour"))

            let chooseColor = AppStrings.Subtitle.chooseColour
            #expect(chooseColor.contains("color"))
            #expect(!chooseColor.contains("colour"))
        }
    }

    @Test("Australian English uses UK spelling (Customise)")
    func auEnglishCustomiseSpelling() {
        // Test that AU English uses UK spelling
        withLocale("en-AU") {
            let customiseButton = AppStrings.Button.customise
            #expect(customiseButton.contains("Customise"))
            #expect(!customiseButton.contains("Customize"))
        }
    }

    @Test("Australian English uses UK spelling (Colour)")
    func auEnglishColourSpelling() {
        // Test that AU English uses UK spelling
        withLocale("en-AU") {
            let colourLabel = AppStrings.Label.colour
            #expect(colourLabel.contains("Colour"))
            #expect(!colourLabel.contains("Color"))
        }
    }

    @Test("Non-English locale falls back to UK English")
    func nonEnglishFallback() {
        // Test that non-English locales (e.g., French) fall back to UK English
        withLocale("fr-FR") {
            // Should fallback to en-GB (UK English)
            let customiseButton = AppStrings.Button.customise
            #expect(customiseButton.contains("Customise"))

            let colourLabel = AppStrings.Label.colour
            #expect(colourLabel.contains("Colour"))
        }
    }

    // MARK: - Helper Functions

    /// Temporarily switch to a different locale for testing
    /// - Parameters:
    ///   - localeIdentifier: The locale to switch to (e.g., "en-US", "en-GB")
    ///   - block: The test code to run with this locale
    private func withLocale(_ localeIdentifier: String, _ block: () -> Void) {
        // Save current locale
        let savedLanguages = UserDefaults.standard.object(forKey: "AppleLanguages") as? [String]

        // Set test locale
        UserDefaults.standard.set([localeIdentifier], forKey: "AppleLanguages")
        UserDefaults.standard.synchronize()

        // Run test block
        block()

        // Restore original locale
        if let saved = savedLanguages {
            UserDefaults.standard.set(saved, forKey: "AppleLanguages")
        } else {
            UserDefaults.standard.removeObject(forKey: "AppleLanguages")
        }
        UserDefaults.standard.synchronize()
    }
}
