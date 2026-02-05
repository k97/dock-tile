//
//  AppStrings.swift
//  Dock Tile
//
//  Centralized app strings for easy maintenance and localization.
//  All user-visible strings should be defined here.
//
//  Localization Strategy:
//  - Base language: en-GB (UK English) - fallback for all non-English languages
//  - Variants: en-US (US English), en-AU (Australian English)
//  - Key differences: US vs UK/AU spelling (Customize → Customise, Color → Colour)
//

import Foundation

/// Centralized app strings for localization.
/// Usage: `AppStrings.appName` or `AppStrings.Menu.newTile`
enum AppStrings {
    /// The display name of the app
    static let appName = NSLocalizedString(
        "app.name",
        value: "Dock Tile",
        comment: "App display name"
    )

    // MARK: - Alert Messages

    enum Alert {
        static let restartDockTitle = NSLocalizedString(
            "alert.restartDock.title",
            value: "Dock Restart Required",
            comment: "Alert title when Dock restart is required"
        )

        static let restartDockMessage = NSLocalizedString(
            "alert.restartDock.message",
            value: "Dock Tile restarts the Dock to apply changes. This happens whenever you add, update, or remove tiles. Your current Dock items won't be affected.",
            comment: "Alert message explaining Dock restart"
        )

        static let restartDockCheckbox = NSLocalizedString(
            "alert.restartDock.checkbox",
            value: "Don't show this again",
            comment: "Checkbox label to suppress future Dock restart alerts"
        )
    }

    // MARK: - Buttons

    enum Button {
        static let add = NSLocalizedString(
            "button.add",
            value: "Add",
            comment: "Add button label in file picker"
        )

        static let addToDock = NSLocalizedString(
            "button.addToDock",
            value: "Add to Dock",
            comment: "Button to add tile to Dock"
        )

        static let back = NSLocalizedString(
            "button.back",
            value: "Back",
            comment: "Back button label"
        )

        static let cancel = NSLocalizedString(
            "button.cancel",
            value: "Cancel",
            comment: "Cancel button in alerts"
        )

        static let confirm = NSLocalizedString(
            "button.confirm",
            value: "Confirm",
            comment: "Confirm button for alert dialogs"
        )

        static let customise = NSLocalizedString(
            "button.customise",
            value: "Customise",
            comment: "Button to open customization view"
        )

        static let delete = NSLocalizedString(
            "button.delete",
            value: "Delete",
            comment: "Delete button"
        )

        static let done = NSLocalizedString(
            "button.done",
            value: "Done",
            comment: "Done button"
        )

        static let duplicate = NSLocalizedString(
            "button.duplicate",
            value: "Duplicate",
            comment: "Duplicate button in context menu"
        )

        static let newTile = NSLocalizedString(
            "button.newTile",
            value: "New Tile",
            comment: "Button to create first tile on empty state"
        )

        static let remove = NSLocalizedString(
            "button.remove",
            value: "Remove",
            comment: "Remove button"
        )

        static let removeFromDock = NSLocalizedString(
            "button.removeFromDock",
            value: "Remove from Dock",
            comment: "Button to remove tile from Dock"
        )

        static let update = NSLocalizedString(
            "button.update",
            value: "Update",
            comment: "Update button when tile is already in Dock"
        )
    }

    // MARK: - Labels

    enum Label {
        static let colour = NSLocalizedString(
            "label.colour",
            value: "Colour",
            comment: "Label for colour picker section"
        )

        static let layout = NSLocalizedString(
            "label.layout",
            value: "Layout",
            comment: "Label for layout picker"
        )

        static let showInAppSwitcher = NSLocalizedString(
            "label.showInAppSwitcher",
            value: "Show in App Switcher",
            comment: "Label for app switcher toggle"
        )

        static let showTile = NSLocalizedString(
            "label.showTile",
            value: "Show Tile",
            comment: "Label for show tile toggle"
        )

        static let tileIcon = NSLocalizedString(
            "label.tileIcon",
            value: "Tile Icon",
            comment: "Label for tile icon section"
        )

        static let tileIconSize = NSLocalizedString(
            "label.tileIconSize",
            value: "Tile Icon Size",
            comment: "Label for tile icon size"
        )

        static let tileName = NSLocalizedString(
            "label.tileName",
            value: "Tile Name",
            comment: "Label for tile name field"
        )
    }

    // MARK: - Layout Options

    enum Layout {
        static let grid = NSLocalizedString(
            "layout.grid",
            value: "Grid",
            comment: "Grid layout option"
        )

        static let list = NSLocalizedString(
            "layout.list",
            value: "List",
            comment: "List layout option"
        )
    }

    // MARK: - Menu Items

    enum Menu {
        static let configure = NSLocalizedString(
            "menu.configure",
            value: "Configure...",
            comment: "Menu item to configure tile (opens main app)"
        )

        static let newTile = NSLocalizedString(
            "menu.newTile",
            value: "New Dock Tile",
            comment: "Menu item to create a new tile"
        )

        static let openInFinder = NSLocalizedString(
            "menu.openInFinder",
            value: "Open in Finder",
            comment: "Menu item to open in Finder"
        )

        static let options = NSLocalizedString(
            "menu.options",
            value: "Options",
            comment: "Section divider in menu"
        )
    }

    // MARK: - Navigation

    enum Navigation {
        static let customiseTile = NSLocalizedString(
            "navigation.customiseTile",
            value: "Customise Tile",
            comment: "Navigation title for customise tile view"
        )
    }

    // MARK: - Sidebar

    enum Sidebar {
        static let title = NSLocalizedString(
            "sidebar.title",
            value: "Dock Tile",
            comment: "Navigation title for sidebar"
        )
    }

    // MARK: - Sections

    enum Section {
        static let selectedItems = NSLocalizedString(
            "section.selectedItems",
            value: "Selected Items",
            comment: "Section header for selected items"
        )
    }

    // MARK: - Subtitles

    enum Subtitle {
        static let chooseColour = NSLocalizedString(
            "subtitle.chooseColour",
            value: "Choose a background colour for your tile",
            comment: "Subtitle for colour picker section"
        )

        static let configureToAdd = NSLocalizedString(
            "subtitle.configureToAdd",
            value: "Configure to add apps",
            comment: "Subtitle in empty state (grid view only)"
        )

        static let iconSize = NSLocalizedString(
            "subtitle.iconSize",
            value: "Adjust the size of your icon within the tile",
            comment: "Subtitle for icon size section"
        )
    }

    // MARK: - Tabs

    enum Tab {
        static let emoji = NSLocalizedString(
            "tab.emoji",
            value: "Emoji",
            comment: "Emoji tab label"
        )

        static let symbol = NSLocalizedString(
            "tab.symbol",
            value: "Symbol",
            comment: "Symbol tab label"
        )
    }

    // MARK: - Table Headers

    enum Table {
        static let item = NSLocalizedString(
            "table.item",
            value: "Item",
            comment: "Table column header for item"
        )

        static let kind = NSLocalizedString(
            "table.kind",
            value: "Kind",
            comment: "Table column header for kind"
        )
    }

    // MARK: - Titles

    enum Title {
        static let deleteTile = NSLocalizedString(
            "title.deleteTile",
            value: "Delete Tile",
            comment: "Alert title for delete confirmation"
        )
    }

    // MARK: - Tooltips

    enum Tooltip {
        static let createNewTile = NSLocalizedString(
            "tooltip.createNewTile",
            value: "Create new tile",
            comment: "Tooltip when add button is enabled"
        )

        static let editFirst = NSLocalizedString(
            "tooltip.editFirst",
            value: "Edit current tile before creating another",
            comment: "Tooltip when add button is disabled"
        )
    }

    // MARK: - Empty States

    enum Empty {
        static let createFirstTile = NSLocalizedString(
            "empty.createFirstTile",
            value: "Create Your First Tile",
            comment: "Header text for empty state"
        )

        static let detail = NSLocalizedString(
            "empty.detail",
            value: "Detail",
            comment: "Placeholder text in detail view"
        )

        static let noApps = NSLocalizedString(
            "empty.noApps",
            value: "No apps configured",
            comment: "Empty state text when no apps configured"
        )

        static let noItemsAdded = NSLocalizedString(
            "empty.noItemsAdded",
            value: "No items added yet",
            comment: "Empty state text in apps table"
        )

        static let noTiles = NSLocalizedString(
            "empty.noTiles",
            value: "No Tiles",
            comment: "Empty state text in sidebar"
        )
    }

    // MARK: - Search

    enum Search {
        static let emojis = NSLocalizedString(
            "search.emojis",
            value: "Search emojis",
            comment: "Search placeholder for emojis"
        )

        static let symbols = NSLocalizedString(
            "search.symbols",
            value: "Search symbols",
            comment: "Search placeholder for symbols"
        )
    }

    // MARK: - File Picker

    enum FilePicker {
        static let message = NSLocalizedString(
            "filePicker.message",
            value: "Select an application or folder to add",
            comment: "Message in file picker dialog"
        )
    }

    // MARK: - Kind Values

    enum Kind {
        static let application = NSLocalizedString(
            "kind.application",
            value: "Application",
            comment: "Kind value for applications"
        )

        static let folder = NSLocalizedString(
            "kind.folder",
            value: "Folder",
            comment: "Kind value for folders"
        )
    }

    // MARK: - Error Messages

    /// Error messages shown to users (not debug logs)
    enum Error {
        static let mainAppNotFound = NSLocalizedString(
            "error.mainAppNotFound",
            value: "Main Dock Tile.app not found",
            comment: "Error when main app bundle cannot be found"
        )

        static let failedToReadInfoPlist = NSLocalizedString(
            "error.failedToReadInfoPlist",
            value: "Failed to read Info.plist",
            comment: "Error when Info.plist cannot be read"
        )

        static let failedToWriteInfoPlist = NSLocalizedString(
            "error.failedToWriteInfoPlist",
            value: "Failed to write Info.plist",
            comment: "Error when Info.plist cannot be written"
        )

        static let failedToCopyBundle = NSLocalizedString(
            "error.failedToCopyBundle",
            value: "Failed to copy bundle",
            comment: "Error when bundle copy fails"
        )

        static let failedToCodeSign = NSLocalizedString(
            "error.failedToCodeSign",
            value: "Failed to code sign helper bundle",
            comment: "Error when code signing fails"
        )
    }

    // MARK: - Log Messages

    /// Log messages (not localized - kept in English for developer logs)
    enum Log {
        static let launching = "🚀 Dock Tile launching..."
        static let ready = "✓ Dock Tile ready"
        static let terminating = "👋 Dock Tile terminating..."
    }
}
