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

    // MARK: - About

    enum About {
        static let title = NSLocalizedString("about.title", value: "About", comment: "About pane title")
        static func version(_ v: String) -> String { String(format: NSLocalizedString("about.version", value: "Version %@", comment: "About: version line"), v) }
        static let website = NSLocalizedString("about.website", value: "Website", comment: "About: website row label")
        static let feedbackTitle = NSLocalizedString("about.feedbackTitle", value: "Found a bug or have an idea?", comment: "About: feedback card title")
        static let feedbackBody = NSLocalizedString("about.feedbackBody", value: "Feedback goes straight to the developer. Diagnostics attach a log of what the app and its tiles did — nothing personal.", comment: "About: feedback card body")
        static let sendFeedback = NSLocalizedString("about.sendFeedback", value: "Send Feedback…", comment: "About: opens the feedback email")
        static let feedbackRowBody = NSLocalizedString("about.feedbackRowBody", value: "Feedback goes straight to the developer.", comment: "About: Send Feedback row description.")
        static let diagnosticsTitle = NSLocalizedString("about.diagnosticsTitle", value: "Diagnostics", comment: "About: Copy Diagnostics row label.")
        static let diagnosticsBody = NSLocalizedString("about.diagnosticsBody", value: "A log of what the app and its tiles did. Attach it to an email when something looks wrong — it contains nothing personal.", comment: "About: Copy Diagnostics row description.")
        static let alsoFrom = NSLocalizedString("about.alsoFrom", value: "Also from Happy Machines", comment: "About: studio section header")
        static let studioTitle = NSLocalizedString("about.studioTitle", value: "Made by Happy Machines Company", comment: "About: studio row title")
        static let studioSubtitle = NSLocalizedString("about.studioSubtitle", value: "A tiny product studio building nifty Mac apps that each fix one thing well.", comment: "About: studio row subtitle")
        static let spadesTitle = NSLocalizedString("about.spadesTitle", value: "Spades Audio", comment: "About: sibling product row title")
        static let spadesSubtitle = NSLocalizedString("about.spadesSubtitle", value: "Per-app volume, EQ and output control for your Mac, from the menu bar.", comment: "About: sibling product subtitle")
        static let learnMore = NSLocalizedString("about.learnMore", value: "Learn More…", comment: "About: opens spadesaudio.com")
    }

    // MARK: - Alert Messages

    enum Alert {
        static let configUnreadableTitle = NSLocalizedString(
            "alert.configUnreadable.title",
            value: "Dock Tile Can't Read Your Tiles",
            comment: "Launch alert title: the tile settings file exists but could not be opened; the app quits after it"
        )
        static func configUnreadableMessage(_ path: String) -> String {
            String(format: NSLocalizedString(
                "alert.configUnreadable.message",
                value: "Your tiles haven't been changed. Dock Tile couldn't open its settings file and will quit. Check that you can open %@, then open Dock Tile again.",
                comment: "Launch alert message when the tile settings file can't be read; %@ = the file's full path. The app quits when the alert closes."
            ), path)
        }
        static let configUnreadableQuit = NSLocalizedString(
            "alert.configUnreadable.quit",
            value: "Quit",
            comment: "Only button of the can't-read-tiles launch alert; quits Dock Tile"
        )
        static let deleteTileMessage = NSLocalizedString(
            "alert.deleteTile.message",
            value: "This will permanently delete the tile and remove it from the dock.",
            comment: "Delete-tile confirmation message"
        )
        static let revertToDockMessage = NSLocalizedString(
            "alert.revertToDock.message",
            value: "Your changes will be replaced by the version in the Dock.",
            comment: "Revert to Dock Version confirmation message: the tile's unapplied edits are discarded and the version its Dock icon was built from comes back"
        )
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

        static let applyPopoverTitle = NSLocalizedString(
            "alert.applyPopover.title",
            value: "Apply to your Dock tiles?",
            comment: "Confirmation title before rebuilding tiles to apply popover appearance settings"
        )

        static let applyPopoverMessage = NSLocalizedString(
            "alert.applyPopover.message",
            value: "Dock Tile will rebuild your pinned tiles with the new popover look and briefly restart the Dock. Your other Dock items won't be affected.",
            comment: "Confirmation message warning the Dock will restart when applying popover settings"
        )

        static let missingAppsTitle = NSLocalizedString(
            "alert.missingApps.title",
            value: "Some apps are no longer installed",
            comment: "Alert title when apps referenced by tiles can't be found on disk"
        )

        static let missingAppsMessage = NSLocalizedString(
            "alert.missingApps.message",
            value: "Some apps in your tiles can't be found on this Mac. Remove them from your tiles?",
            comment: "Alert message offering to remove uninstalled apps from tiles"
        )

        static let missingAppsScanFoundMessage = NSLocalizedString(
            "alert.missingAppsScan.foundMessage",
            value: "These apps can't be found on this Mac:",
            comment: "Intro line of the manual scan results dialog; a list of tiles/apps follows"
        )

        static let missingAppsNoneTitle = NSLocalizedString(
            "alert.missingAppsScan.noneTitle",
            value: "No Missing Apps",
            comment: "Title of the manual scan dialog when every tile app is installed"
        )

        static let missingAppsNoneMessage = NSLocalizedString(
            "alert.missingAppsScan.noneMessage",
            value: "Every app in your tiles is currently installed.",
            comment: "Message of the manual scan dialog when nothing is missing"
        )

        static let relocateTitle = NSLocalizedString(
            "alert.relocate.title",
            value: "Move Dock Tile to Applications?",
            comment: "Title of the prompt asking the user to move the app into the Applications folder"
        )

        static let relocateMessage = NSLocalizedString(
            "alert.relocate.message",
            value: "Dock Tile is running from outside your Applications folder. macOS may run it from a temporary, read-only location, which can stop new tiles from being created. Move it to Applications to make sure everything works.",
            comment: "Message of the launch-time nudge to move the app to Applications"
        )

        static let relocateBlockingMessage = NSLocalizedString(
            "alert.relocate.blockingMessage",
            value: "Dock Tile can't create or update this tile because it's running from a temporary, read-only location. This happens when the app is launched from Downloads. Move Dock Tile to your Applications folder and try again.",
            comment: "Message shown when a tile action is blocked because the app is translocated"
        )

        static let relocateCheckbox = NSLocalizedString(
            "alert.relocate.checkbox",
            value: "Don't ask again",
            comment: "Checkbox to suppress future move-to-Applications nudges"
        )
    }

    // MARK: - Buttons

    enum Button {
        static let add = NSLocalizedString(
            "button.add",
            value: "Add",
            comment: "Add button label in file picker"
        )

        static let addATile = NSLocalizedString("button.addATile", value: "Add a Tile…", comment: "Sidebar + / empty state: opens the Add a Tile dialog")

        static let copy = NSLocalizedString("button.copy", value: "Copy", comment: "Generic Copy button label.")

        static let addToDock = NSLocalizedString(
            "button.addToDock",
            value: "Add to Dock",
            comment: "Button to add tile to Dock"
        )

        static let resetToDefaults = NSLocalizedString(
            "button.resetToDefaults",
            value: "Reset to Defaults",
            comment: "Button that restores popover appearance settings to their defaults"
        )

        static let save = NSLocalizedString(
            "button.save",
            value: "Save",
            comment: "Primary toolbar button that commits the popover appearance settings"
        )

        static let saving = NSLocalizedString(
            "button.saving",
            value: "Applying…",
            comment: "Loading label on the Save button while applying settings to Dock tiles"
        )

        static let applyToTiles = NSLocalizedString(
            "button.applyToTiles",
            value: "Apply",
            comment: "Confirm button that rebuilds tiles to apply popover settings"
        )

        static let openAccessibilitySettings = NSLocalizedString(
            "button.openAccessibilitySettings",
            value: "Open Accessibility Settings…",
            comment: "Button that opens the Accessibility pane in System Settings (Reduce Motion)"
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

        static let moveToApplications = NSLocalizedString(
            "button.moveToApplications",
            value: "Move to Applications",
            comment: "Button that moves the app into the Applications folder"
        )

        static let notNow = NSLocalizedString(
            "button.notNow",
            value: "Not Now",
            comment: "Dismiss button for the non-blocking move-to-Applications nudge"
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

        static let keep = NSLocalizedString(
            "button.keep",
            value: "Keep",
            comment: "Button to keep uninstalled apps in tiles (dismiss the removal prompt)"
        )

        static let scanForMissingApps = NSLocalizedString(
            "button.scanForMissingApps",
            value: "Scan",
            comment: "Settings button that scans tiles for moved/uninstalled apps"
        )

        static let reviewInTiles = NSLocalizedString(
            "button.reviewInTiles",
            value: "Review in Tiles",
            comment: "Button that navigates to the first tile containing a missing app"
        )

        static let removeAll = NSLocalizedString(
            "button.removeAll",
            value: "Remove All",
            comment: "Button to remove all missing apps from tiles at once"
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

        static let revert = NSLocalizedString(
            "button.revert",
            value: "Revert",
            comment: "Confirm button of the Revert to Dock Version alert"
        )

        static let openLoginItems = NSLocalizedString(
            "button.openLoginItems",
            value: "Open Login Items Settings…",
            comment: "Button that opens System Settings Login Items for approval"
        )

        static let checkForUpdates = NSLocalizedString(
            "button.checkForUpdates",
            value: "Check for Updates…",
            comment: "Button that triggers a manual Sparkle update check"
        )

        static let checkNow = NSLocalizedString(
            "button.checkNow",
            value: "Check Now",
            comment: "Settings → Software Update: button that triggers a manual Sparkle update check"
        )

        static let useThisTile = NSLocalizedString(
            "button.useThisTile",
            value: "Use This Tile",
            comment: "Smart Add sheet — button that creates a pre-filled tile from a suggestion"
        )

        static let createNewTile = NSLocalizedString(
            "button.createNewTile",
            value: "Create New Tile",
            comment: "Smart Add sheet — neutral button that starts a blank tile instead of a suggestion"
        )
    }

    // MARK: - Labels

    enum Label {
        // MARK: Tile background (Colour / Mono)
        static let background = NSLocalizedString(
            "label.background",
            value: "Background",
            comment: "Customise Tile: background row label"
        )
        static let backgroundColour = NSLocalizedString(
            "label.background.colour",
            value: "Colour",
            comment: "Customise Tile: Colour background chip"
        )
        static let backgroundMono = NSLocalizedString(
            "label.background.mono",
            value: "Mono",
            comment: "Customise Tile: Mono background chip"
        )
        static let backgroundHintColour = NSLocalizedString(
            "label.background.hint.colour",
            value: "Filled with your colour",
            comment: "Customise Tile: hint under Background when Colour"
        )
        static let backgroundHintMono = NSLocalizedString(
            "label.background.hint.mono",
            value: "White in Light Mode, black in Dark Mode",
            comment: "Customise Tile: hint under Background when Mono"
        )
        static let backgroundHintMonoStatic = NSLocalizedString(
            "label.background.hint.mono.static",
            value: "White tile with a coloured symbol",
            comment: "Customise Tile: hint under Background when Mono on macOS 15 (static white tile)"
        )
        static let backgroundColourAccessibility = NSLocalizedString(
            "label.background.colour.accessibility",
            value: "Colour, filled with your colour",
            comment: "VoiceOver label for the Colour chip"
        )
        static let backgroundMonoAccessibility = NSLocalizedString(
            "label.background.mono.accessibility",
            value: "Mono, white in Light Mode and black in Dark Mode",
            comment: "VoiceOver label for the Mono chip"
        )
        static let backgroundMonoStaticAccessibility = NSLocalizedString(
            "label.background.mono.static.accessibility",
            value: "Mono, a white tile with a coloured symbol",
            comment: "VoiceOver label for the Mono chip on macOS 15"
        )
        static let symbolColour = NSLocalizedString(
            "label.symbolColour",
            value: "Symbol Colour",
            comment: "Customise Tile: colour row label for a Mono tile"
        )
        static let colourHintFills = NSLocalizedString(
            "label.colour.hint.fills",
            value: "Fills the tile",
            comment: "Customise Tile: colour hint, Colour tile"
        )
        static let colourHintDeepened = NSLocalizedString(
            "label.colour.hint.deepened",
            value: "Deepened slightly so the symbol stays clear",
            comment: "Customise Tile: colour hint when the fill was darkened for contrast"
        )
        static let tileColour = NSLocalizedString(
            "label.tileColour",
            value: "Tile Colour",
            comment: "Customise Tile: Colour card header for a Colour tile"
        )
        static let colourHintTints = NSLocalizedString(
            "label.colour.hint.tints",
            value: "Tints the symbol",
            comment: "Customise Tile: Colour card caption for a Mono tile"
        )
        static let backgroundHintEmojiColours = NSLocalizedString(
            "label.background.hint.emojiColours",
            value: "Emoji keep their own colours.",
            comment: "Customise Tile: appended to the Background caption for an Emoji tile"
        )

        // MARK: Customise Tile — Style picker and the Apps face

        static let styleAppPreview = NSLocalizedString(
            "label.style.appPreview",
            value: "App Grid",
            comment: "Customise Tile: Style picker card for the Apps face"
        )
        static let appsBackground = NSLocalizedString(
            "label.appsBackground",
            value: "Dock Icon Background",
            comment: "App Grid inspector section for per-tile plate settings"
        )
        static let appsBackgroundAutomatic = NSLocalizedString(
            "label.appsBackground.automatic",
            value: "Follow System",
            comment: "App Grid background follows the macOS icon appearance"
        )
        static let appsBackgroundCharcoal = NSLocalizedString(
            "label.appsBackground.charcoal",
            value: "Dark Grey",
            comment: "Fixed dark background for an App Grid icon"
        )
        static let appsBackgroundLight = NSLocalizedString(
            "label.appsBackground.light",
            value: "Light",
            comment: "Fixed light background for an App Grid icon"
        )
        static let appsBackgroundCustom = NSLocalizedString(
            "label.appsBackground.custom",
            value: "Custom Colour",
            comment: "Native colour picker for an App Grid icon background"
        )
        static let appsBackgroundHint = NSLocalizedString(
            "label.appsBackground.hint",
            value: "Applies to this tile only.",
            comment: "Caption under the App Grid background menu: the choice affects only this tile"
        )
        static let appsHeader = NSLocalizedString(
            "label.apps.header",
            value: "Apps",
            comment: "Customise Tile: group header above the Apps card"
        )
        static let appsShown = NSLocalizedString(
            "label.apps.shown",
            value: "Shown",
            comment: "Customise Tile: Apps card row — how many apps the face shows"
        )
        static func appsShownValue(_ shown: Int, _ total: Int) -> String {
            String(format: NSLocalizedString(
                "label.apps.shownValue",
                value: "%1$lld of %2$lld",
                comment: "Customise Tile: Apps card Shown value, e.g. 9 of 12; %1$lld = shown, %2$lld = total (positional so a language may reorder them)"
            ), shown, total)
        }
        static let appsArrangement = NSLocalizedString(
            "label.apps.arrangement",
            value: "Arrangement",
            comment: "Customise Tile: Apps card row — the grid the face uses"
        )
        static let appsArrangementTwoByTwo = NSLocalizedString(
            "label.apps.arrangement.twoByTwo",
            value: "2 × 2",
            comment: "Customise Tile: Arrangement value for 2–4 apps"
        )
        static let appsArrangementThreeByThree = NSLocalizedString(
            "label.apps.arrangement.threeByThree",
            value: "3 × 3",
            comment: "Customise Tile: Arrangement value for 5 or more apps"
        )
        static let appsNoteOne = NSLocalizedString(
            "label.apps.note.one",
            value: "Shows the only app in this tile.",
            comment: "Customise Tile: Apps caption, one app"
        )
        static func appsNoteAll(_ count: Int) -> String {
            String(format: NSLocalizedString(
                "label.apps.note.all",
                value: "Shows all %lld apps, in tile order.",
                comment: "Customise Tile: Apps caption, 2–9 apps; %lld = app count"
            ), count)
        }
        static func appsNoteFirstNine(_ count: Int) -> String {
            String(format: NSLocalizedString(
                "label.apps.note.firstNine",
                value: "Shows the first 9 of %lld apps, in tile order.",
                comment: "Customise Tile: Apps caption, more than nine apps; %lld = app count"
            ), count)
        }
        static let appsNoteNone = NSLocalizedString(
            "label.apps.note.none",
            value: "No apps yet — use Add under In This Tile.",
            comment: "Customise Tile: Apps caption when the tile has no apps (builder copy, not in the handoff)"
        )
        static let appsGlass = NSLocalizedString(
            "label.apps.glass",
            value: "A glass folder that follows Light and Dark Mode.",
            comment: "Customise Tile: fixed sentence after the Apps caption (decided 2026-10-19: the dark appearance is system-dark)"
        )
        static func appsFaceAccessibility(_ count: Int) -> String {
            String(format: NSLocalizedString(
                "label.appsFace.accessibility",
                value: "Apps face: showing %lld of this tile's apps",
                comment: "VoiceOver label for a tile preview showing the Apps face; %lld = number of app icons shown"
            ), count)
        }

        // MARK: Popover Appearance controls

        static let popoverSize = NSLocalizedString(
            "label.popover.size",
            value: "Popover Size",
            comment: "Label for the popover size segmented control"
        )

        static let tileSizeInPopover = NSLocalizedString(
            "label.popover.tileSize",
            value: "Tile Size",
            comment: "Label for the icon/cell size control inside the popover"
        )

        static let popoverAnimation = NSLocalizedString(
            "label.popover.animation",
            value: "Animation",
            comment: "Label for the popover animation segmented control"
        )

        static let popoverSpacing = NSLocalizedString(
            "label.popover.spacing",
            value: "Spacing",
            comment: "Label for the popover item spacing segmented control"
        )

        static let showLabels = NSLocalizedString(
            "label.popover.showLabels",
            value: "Show Labels",
            comment: "Toggle label — show app names under grid icons"
        )

        static let highlightOnHover = NSLocalizedString(
            "label.popover.highlightOnHover",
            value: "Highlight on Hover",
            comment: "Toggle label — show a background fill on the hovered item"
        )

        static let listAlwaysLabelled = NSLocalizedString(
            "label.popover.listAlwaysLabelled",
            value: "List view always shows labels",
            comment: "Hint shown beside the disabled Show Labels control when previewing List"
        )

        static let notInstalled = NSLocalizedString(
            "label.notInstalled",
            value: "Not installed",
            comment: "Badge/kind text shown for an app whose bundle is no longer on disk"
        )

        static let editorHint = NSLocalizedString(
            "label.editorHint",
            value: "Hover to remove · Drag to reorder",
            comment: "Tile Detail: apps section caption"
        )

        static let addAppsTooltip = NSLocalizedString(
            "label.addAppsTooltip",
            value: "Add apps or folders to this tile",
            comment: "Tooltip on the + Add button above the tile editor's popover preview."
        )

        static let missingAppsScan = NSLocalizedString(
            "label.missingAppsScan",
            value: "Missing Apps",
            comment: "Settings row title for the missing-app scan"
        )

        static let missingAppsScanDescription = NSLocalizedString(
            "label.missingAppsScanDescription",
            value: "Check your tiles for apps that have been moved or uninstalled.",
            comment: "Settings row description for the missing-app scan"
        )

        static let addAppsAndFolders = NSLocalizedString(
            "label.addAppsAndFolders",
            value: "Add Apps & Folders",
            comment: "Tooltip on the Add button in Tile Detail's In This Tile section"
        )

        static let appSwitcherNeedsShowTile = NSLocalizedString(
            "label.appSwitcherNeedsShowTile",
            value: "Turn on Show Tile first — this only applies while the tile is in the Dock.",
            comment: "Tooltip on the disabled Show in App Switcher toggle when the tile is hidden"
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

        static let tileIconSize = NSLocalizedString(
            "label.tileIconSize",
            value: "Tile Icon Size",
            comment: "Label for tile icon size"
        )

        static let iconSize = NSLocalizedString(
            "label.iconSize",
            value: "Icon Size",
            comment: "Compact label for the icon size stepper (side-by-side with icon weight)"
        )

        static let iconWeight = NSLocalizedString(
            "label.iconWeight",
            value: "Icon Weight",
            comment: "Label for the SF Symbol weight picker"
        )

        static let tileName = NSLocalizedString(
            "label.tileName",
            value: "Tile Name",
            comment: "Label for tile name field"
        )

        static let softwareUpdate = NSLocalizedString(
            "label.softwareUpdate",
            value: "Software Update",
            comment: "Title of the software-update row in General settings"
        )

        /// Format string; `%@` is the current app version. Mirrors Apple's update-pane phrasing.
        static let softwareUpdateDescriptionFormat = NSLocalizedString(
            "label.softwareUpdateDescription",
            value: "You’re using version %@. Dock Tile checks for updates automatically.",
            comment: "Description under the software-update row; %@ is the current version"
        )

        static func softwareUpdateDescription(_ version: String) -> String {
            String(format: softwareUpdateDescriptionFormat, version)
        }

        static let startAtLogin = NSLocalizedString(
            "label.startAtLogin",
            value: "Start tiles at login",
            comment: "Label for the start-at-login toggle in Settings"
        )

        static let startAtLoginDescription = NSLocalizedString(
            "label.startAtLoginDescription",
            value: "Keep your tiles ready in the Dock so they respond instantly after you restart your Mac.",
            comment: "Explanation under the start-at-login toggle"
        )

        static let shareAnalytics = NSLocalizedString(
            "label.shareAnalytics",
            value: "Share anonymous usage data",
            comment: "Label for the analytics opt-out toggle in Settings"
        )

        static let shareAnalyticsDescription = NSLocalizedString(
            "label.shareAnalyticsDescription",
            value: "Help improve Dock Tile by sending anonymous usage and crash reports. No personal data is collected.",
            comment: "Explanation under the analytics toggle"
        )
    }

    // MARK: - Settings

    enum Settings {
        static let general = NSLocalizedString(
            "settings.general",
            value: "General",
            comment: "Title of the General settings pane"
        )

        static let loginRequiresApproval = NSLocalizedString(
            "settings.login.requiresApproval",
            value: "Approve Dock Tile in Login Items to finish enabling this.",
            comment: "Shown when macOS is holding the login item for user approval"
        )

        static let loginRegistrationFailed = NSLocalizedString(
            "settings.login.registrationFailed",
            value: "Couldn\u{2019}t turn this on \u{2014} macOS refused the registration. %@",
            comment: "Shown under the Start tiles at login toggle when SMAppService registration failed; %@ is the system error"
        )

        static let addingTiles = NSLocalizedString(
            "settings.addingTiles",
            value: "Adding Tiles",
            comment: "General: section holding the Smart Add toggle and the Add a Tile row"
        )

        static let menuBar = NSLocalizedString(
            "settings.menuBar",
            value: "Menu Bar",
            comment: "General: section holding the menu bar icon toggle"
        )

        static let menuBarToggle = NSLocalizedString(
            "settings.menuBar.toggle",
            value: "Show Dock Tile in the menu bar",
            comment: "General: toggle that adds Dock Tile's icon to the menu bar, listing the tiles and their apps"
        )

        static let menuBarToggleDescription = NSLocalizedString(
            "settings.menuBar.toggleDescription",
            value: "Lists the tiles in your Dock and their apps. Dock Tile keeps running in the background while this is on.",
            comment: "General: caption under the menu bar icon toggle"
        )

        static let dockLock = NSLocalizedString(
            "settings.dockLock",
            value: "Dock Lock",
            comment: "Section header for the Dock Lock feature in Settings"
        )

        static let dockLockToggle = NSLocalizedString(
            "settings.dockLock.toggle",
            value: "Lock Dock to one display",
            comment: "Label for the Dock Lock enable toggle"
        )

        static let dockLockDescription = NSLocalizedString(
            "settings.dockLock.description",
            value: "Stop the Dock from jumping between screens on multi-display setups. It stays on the display you choose.",
            comment: "Explanation under the Dock Lock toggle"
        )

        static let dockLockAnchor = NSLocalizedString(
            "settings.dockLock.anchor",
            value: "Keep Dock on",
            comment: "Label for the anchor display picker"
        )

        static let dockLockMainDisplay = NSLocalizedString(
            "settings.dockLock.mainDisplay",
            value: "Main",
            comment: "Suffix marking the main display in the anchor picker"
        )

        static let dockLockDefaultDisplay = NSLocalizedString(
            "settings.dockLock.defaultDisplay",
            value: "Default (follow macOS)",
            comment: "First option in the anchor picker — no lock, macOS default behaviour"
        )

        /// Format string; `%@` is the display name. Confirms which screen the Dock is pinned to.
        static let dockLockLockedToFormat = NSLocalizedString(
            "settings.dockLock.lockedTo",
            value: "Dock is locked to %@",
            comment: "Indicator confirming the display the Dock is pinned to"
        )

        static func dockLockLockedTo(_ name: String) -> String {
            String(format: dockLockLockedToFormat, name)
        }

        /// Format string; `%@` is the display name. Shown with a spinner while relocating.
        static let dockLockMovingFormat = NSLocalizedString(
            "settings.dockLock.moving",
            value: "Moving Dock to %@…",
            comment: "Progress message shown while the Dock is being relocated"
        )

        static func dockLockMoving(_ name: String) -> String {
            String(format: dockLockMovingFormat, name)
        }

        /// Format string; `%@` is the display name. Shown when the relocation didn't take.
        static let dockLockMoveFailedFormat = NSLocalizedString(
            "settings.dockLock.moveFailed",
            value: "Couldn't move the Dock to %@. Make sure that display isn't mirrored, then try again.",
            comment: "Error shown when the Dock could not be relocated"
        )

        static func dockLockMoveFailed(_ name: String) -> String {
            String(format: dockLockMoveFailedFormat, name)
        }

        static let dockLockRetry = NSLocalizedString(
            "settings.dockLock.retry",
            value: "Try Again",
            comment: "Button to retry a failed Dock relocation"
        )

        static let dockLockSingleDisplay = NSLocalizedString(
            "settings.dockLock.singleDisplay",
            value: "Connect a second display to use Dock Lock. With one screen the Dock stays exactly where macOS puts it.",
            comment: "Note shown when only one display is connected"
        )

        static let dockLockPrimerTitle = NSLocalizedString(
            "settings.dockLock.primer.title",
            value: "Allow Accessibility Access",
            comment: "Title of the permission primer shown before requesting Accessibility"
        )

        static let dockLockPrimerBody = NSLocalizedString(
            "settings.dockLock.primer.body",
            value: "Dock Lock keeps the Dock on the display you choose. To do that, Dock Tile needs Accessibility access so it can stop macOS from moving the Dock to your other screens.",
            comment: "Explanation in the permission primer"
        )

        static let dockLockPrimerReassurance = NSLocalizedString(
            "settings.dockLock.primer.reassurance",
            value: "Next, macOS will ask you to turn on Dock Tile in System Settings. You can turn this off any time.",
            comment: "Reassurance line in the permission primer about what happens next"
        )

        static let dockLockPrimerContinue = NSLocalizedString(
            "settings.dockLock.primer.continue",
            value: "Continue",
            comment: "Primary button in the permission primer that triggers the macOS dialog"
        )

        static let dockLockPrimerNotNow = NSLocalizedString(
            "settings.dockLock.primer.notNow",
            value: "Not Now",
            comment: "Secondary button in the permission primer that cancels enabling Dock Lock"
        )

        static let dockLockAccessibilityNeeded = NSLocalizedString(
            "settings.dockLock.accessibilityNeeded",
            value: "Accessibility access required",
            comment: "Status shown when Accessibility permission is missing"
        )

        static let dockLockAccessibilityNeededDetail = NSLocalizedString(
            "settings.dockLock.accessibilityNeededDetail",
            value: "Dock Tile needs Accessibility access to keep the Dock in place. Turn on Dock Tile in System Settings.",
            comment: "Explanation of why Accessibility access is needed"
        )

        static let dockLockOpenSettings = NSLocalizedString(
            "settings.dockLock.openSettings",
            value: "Open System Settings…",
            comment: "Button that opens the Accessibility pane in System Settings"
        )

        static let dockLockPerSetupNote = NSLocalizedString(
            "settings.dockLock.perSetupNote",
            value: "Each set of connected displays remembers its own choice.",
            comment: "Footnote under the Dock Lock display picker: the chosen display is remembered separately for each combination of connected displays (home, work…)"
        )

        static let dockLockNote = NSLocalizedString(
            "settings.dockLock.note",
            value: "Works with the Dock at the bottom, left, or right. Keeping it on a screen reserves a few pixels at that edge on your other displays.",
            comment: "Footnote describing Dock Lock behaviour and trade-off"
        )

        // MARK: Popover Appearance

        static let popover = NSLocalizedString(
            "settings.popover",
            value: "Popover",
            comment: "Section header and pane title for popover appearance settings"
        )

        static let popoverSectionTiles = NSLocalizedString(
            "settings.popover.section.tiles",
            value: "Tiles",
            comment: "Section header for the per-item controls inside the popover settings"
        )

        static let popoverConfigure = NSLocalizedString(
            "settings.popover.configure",
            value: "Configure",
            comment: "Label for the Grid/List panel switcher in popover settings"
        )

        static let popoverConfigureSubtitle = NSLocalizedString(
            "settings.popover.configure.subtitle",
            value: "Each layout's settings are saved independently",
            comment: "Subtitle explaining that Grid and List popover settings are stored separately"
        )

        static let popoverFooter = NSLocalizedString(
            "settings.popover.footer",
            value: "These settings apply to every tile's popover. List view always shows labels. Animation follows your system Reduce Motion setting.",
            comment: "Explanatory footer under the popover settings form"
        )

        static let popoverReduceMotionNote = NSLocalizedString(
            "settings.popover.reduceMotion",
            value: "Animation is off because Reduce Motion is on in System Settings.",
            comment: "Caption shown under Animation when the system Reduce Motion setting forces it off"
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

    // MARK: - Icon Weight Options

    enum IconWeight {
        static let light = NSLocalizedString(
            "iconWeight.light", value: "Light", comment: "Customise: icon weight picker option")
        static let regular = NSLocalizedString(
            "iconWeight.regular", value: "Regular", comment: "Customise: icon weight picker option")
        static let medium = NSLocalizedString(
            "iconWeight.medium", value: "Medium", comment: "Customise: icon weight picker option")
        static let semibold = NSLocalizedString(
            "iconWeight.semibold", value: "Semibold", comment: "Customise: icon weight picker option")
        static let bold = NSLocalizedString(
            "iconWeight.bold", value: "Bold", comment: "Customise: icon weight picker option")
        static let heavy = NSLocalizedString(
            "iconWeight.heavy", value: "Heavy", comment: "Customise: icon weight picker option")
    }

    // MARK: - Emoji Picker Categories

    enum EmojiCategory {
        static let people = NSLocalizedString(
            "emojiCategory.people", value: "People", comment: "Emoji picker: section header")
        static let animalsNature = NSLocalizedString(
            "emojiCategory.animalsNature", value: "Animals & Nature", comment: "Emoji picker: section header")
        static let foodDrink = NSLocalizedString(
            "emojiCategory.foodDrink", value: "Food & Drink", comment: "Emoji picker: section header")
        static let activity = NSLocalizedString(
            "emojiCategory.activity", value: "Activity", comment: "Emoji picker: section header")
        static let travelPlaces = NSLocalizedString(
            "emojiCategory.travelPlaces", value: "Travel & Places", comment: "Emoji picker: section header")
        static let objects = NSLocalizedString(
            "emojiCategory.objects", value: "Objects", comment: "Emoji picker: section header")
        static let symbols = NSLocalizedString(
            "emojiCategory.symbols", value: "Symbols", comment: "Emoji picker: section header")
    }

    // MARK: - Symbol Picker Categories

    enum SymbolCategory {
        static let all = NSLocalizedString(
            "symbolCategory.all", value: "All", comment: "Symbol picker: section header (SF Symbols category)")
        static let whatsNew = NSLocalizedString(
            "symbolCategory.whatsnew", value: "What's New", comment: "Symbol picker: section header (SF Symbols category)")
        static let draw = NSLocalizedString(
            "symbolCategory.draw", value: "Draw", comment: "Symbol picker: section header (SF Symbols category)")
        static let variable = NSLocalizedString(
            "symbolCategory.variable", value: "Variable", comment: "Symbol picker: section header (SF Symbols category)")
        static let multicolor = NSLocalizedString(
            "symbolCategory.multicolor", value: "Multicolour", comment: "Symbol picker: section header (SF Symbols category)")
        static let communication = NSLocalizedString(
            "symbolCategory.communication", value: "Communication", comment: "Symbol picker: section header (SF Symbols category)")
        static let weather = NSLocalizedString(
            "symbolCategory.weather", value: "Weather", comment: "Symbol picker: section header (SF Symbols category)")
        static let maps = NSLocalizedString(
            "symbolCategory.maps", value: "Maps", comment: "Symbol picker: section header (SF Symbols category)")
        static let objectsAndTools = NSLocalizedString(
            "symbolCategory.objectsandtools", value: "Objects & Tools", comment: "Symbol picker: section header (SF Symbols category)")
        static let devices = NSLocalizedString(
            "symbolCategory.devices", value: "Devices", comment: "Symbol picker: section header (SF Symbols category)")
        static let cameraAndPhotos = NSLocalizedString(
            "symbolCategory.cameraandphotos", value: "Camera & Photos", comment: "Symbol picker: section header (SF Symbols category)")
        static let gaming = NSLocalizedString(
            "symbolCategory.gaming", value: "Gaming", comment: "Symbol picker: section header (SF Symbols category)")
        static let connectivity = NSLocalizedString(
            "symbolCategory.connectivity", value: "Connectivity", comment: "Symbol picker: section header (SF Symbols category)")
        static let transportation = NSLocalizedString(
            "symbolCategory.transportation", value: "Transportation", comment: "Symbol picker: section header (SF Symbols category)")
        static let automotive = NSLocalizedString(
            "symbolCategory.automotive", value: "Automotive", comment: "Symbol picker: section header (SF Symbols category)")
        static let accessibility = NSLocalizedString(
            "symbolCategory.accessibility", value: "Accessibility", comment: "Symbol picker: section header (SF Symbols category)")
        static let privacyAndSecurity = NSLocalizedString(
            "symbolCategory.privacyandsecurity", value: "Privacy & Security", comment: "Symbol picker: section header (SF Symbols category)")
        static let human = NSLocalizedString(
            "symbolCategory.human", value: "Human", comment: "Symbol picker: section header (SF Symbols category)")
        static let home = NSLocalizedString(
            "symbolCategory.home", value: "Home", comment: "Symbol picker: section header (SF Symbols category)")
        static let fitness = NSLocalizedString(
            "symbolCategory.fitness", value: "Fitness", comment: "Symbol picker: section header (SF Symbols category)")
        static let nature = NSLocalizedString(
            "symbolCategory.nature", value: "Nature", comment: "Symbol picker: section header (SF Symbols category)")
        static let editing = NSLocalizedString(
            "symbolCategory.editing", value: "Editing", comment: "Symbol picker: section header (SF Symbols category)")
        static let textFormatting = NSLocalizedString(
            "symbolCategory.textformatting", value: "Text Formatting", comment: "Symbol picker: section header (SF Symbols category)")
        static let media = NSLocalizedString(
            "symbolCategory.media", value: "Media", comment: "Symbol picker: section header (SF Symbols category)")
        static let keyboard = NSLocalizedString(
            "symbolCategory.keyboard", value: "Keyboard", comment: "Symbol picker: section header (SF Symbols category)")
        static let commerce = NSLocalizedString(
            "symbolCategory.commerce", value: "Commerce", comment: "Symbol picker: section header (SF Symbols category)")
        static let time = NSLocalizedString(
            "symbolCategory.time", value: "Time", comment: "Symbol picker: section header (SF Symbols category)")
        static let health = NSLocalizedString(
            "symbolCategory.health", value: "Health", comment: "Symbol picker: section header (SF Symbols category)")
        static let shapes = NSLocalizedString(
            "symbolCategory.shapes", value: "Shapes", comment: "Symbol picker: section header (SF Symbols category)")
        static let arrows = NSLocalizedString(
            "symbolCategory.arrows", value: "Arrows", comment: "Symbol picker: section header (SF Symbols category)")
        static let indices = NSLocalizedString(
            "symbolCategory.indices", value: "Indices", comment: "Symbol picker: section header (SF Symbols category)")
        static let math = NSLocalizedString(
            "symbolCategory.math", value: "Maths", comment: "Symbol picker: section header (SF Symbols category)")
    }

    // MARK: - Popover Appearance Options

    /// Segmented-control option labels for the popover appearance pickers.
    enum PopoverOption {
        static let small = NSLocalizedString(
            "popover.option.small", value: "Small", comment: "Size tier — small")
        static let medium = NSLocalizedString(
            "popover.option.medium", value: "Medium", comment: "Size tier — medium")
        static let large = NSLocalizedString(
            "popover.option.large", value: "Large", comment: "Size tier — large")

        static let animationNone = NSLocalizedString(
            "popover.option.animation.none", value: "None", comment: "Animation tier — none")
        static let animationDefault = NSLocalizedString(
            "popover.option.animation.default", value: "Default", comment: "Animation tier — default")
        static let animationFast = NSLocalizedString(
            "popover.option.animation.fast", value: "Fast", comment: "Animation tier — fast")

        static let compact = NSLocalizedString(
            "popover.option.compact", value: "Compact", comment: "Spacing tier — compact")
        static let comfortable = NSLocalizedString(
            "popover.option.comfortable", value: "Comfortable", comment: "Spacing tier — comfortable")
        static let spacious = NSLocalizedString(
            "popover.option.spacious", value: "Spacious", comment: "Spacing tier — spacious")

        static func size(_ tier: PopoverSizeTier) -> String {
            switch tier {
            case .small: return small
            case .medium: return medium
            case .large: return large
            }
        }

        static func animation(_ tier: PopoverAnimationTier) -> String {
            switch tier {
            case .none: return animationNone
            case .default: return animationDefault
            case .fast: return animationFast
            }
        }

        static func spacing(_ tier: PopoverSpacingTier) -> String {
            switch tier {
            case .compact: return compact
            case .comfortable: return comfortable
            case .spacious: return spacious
            }
        }

        static let editingRemove = NSLocalizedString(
            "popover.editing.remove",
            value: "Remove",
            comment: "Context menu / remove badge in the tile editor"
        )
        /// Split into title + subtitle so the editor's empty panel reads as two short lines
        /// instead of one sentence wrapping four times in a narrow column.
        static let editingNoAppsTitle = NSLocalizedString(
            "popover.editing.noAppsTitle",
            value: "No apps yet",
            comment: "Tile editor: empty popover preview, title line."
        )
        static let editingNoAppsSubtitle = NSLocalizedString(
            "popover.editing.noAppsSubtitle",
            value: "Use Add to choose what opens from this tile.",
            comment: "Tile editor: empty popover preview, subtitle line."
        )
    }

    // MARK: - Menu Items

    enum Menu {
        static let noAppsConfigured = NSLocalizedString(
            "menu.noAppsConfigured",
            value: "No apps configured",
            comment: "Dock menu: disabled row when the tile has no apps"
        )
        static let noConfiguration = NSLocalizedString(
            "menu.noConfiguration",
            value: "No configuration",
            comment: "Dock menu: disabled row when the tile's config cannot be found"
        )
        static let configure = NSLocalizedString(
            "menu.configure",
            value: "Configure...",
            comment: "Menu item to configure tile (opens main app)"
        )
        static let showInspector = NSLocalizedString(
            "menu.showInspector",
            value: "Show Inspector",
            comment: "View menu item (Show Inspector, ⌥⌘I) that opens the Customise Tile inspector"
        )
        static let hideInspector = NSLocalizedString(
            "menu.hideInspector",
            value: "Hide Inspector",
            comment: "View menu item (Hide Inspector, ⌥⌘I) that closes the Customise Tile inspector"
        )

        static let settings = NSLocalizedString(
            "menu.settings",
            value: "Settings…",
            comment: "App menu item that opens the inline Settings pane (⌘,)"
        )

        static let newTile = NSLocalizedString(
            "menu.newTile",
            value: "New Tile",
            comment: "Menu item to create a new tile"
        )

        static let copyDiagnostics = NSLocalizedString(
            "menu.copyDiagnostics",
            value: "Copy Diagnostics",
            comment: "File menu item that copies recent diagnostic logs to the clipboard"
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

        static let configureTile = NSLocalizedString(
            "menu.configureTile",
            value: "Configure Tile",
            comment: "Tooltip for gear icon in popover"
        )

        static let configureTileItem = NSLocalizedString(
            "menu.configureTileItem",
            value: "Configure Tile…",
            comment: "Tile submenu item in the menu bar and Dock menus: opens that tile in Dock Tile's window"
        )

        static let openDockTile = NSLocalizedString(
            "menu.openDockTile",
            value: "Open Dock Tile…",
            comment: "Menu bar and Dock menu item that opens Dock Tile's main window"
        )

        static let quitDockTile = NSLocalizedString(
            "menu.quitDockTile",
            value: "Quit Dock Tile",
            comment: "Menu bar icon's menu: quits Dock Tile (tiles already in the Dock keep working)"
        )

        static let aboutDockTile = NSLocalizedString(
            "menu.aboutDockTile",
            value: "About Dock Tile",
            comment: "App menu"
        )
    }

    // MARK: - Popover Item Menu (right-click on an app/folder in a tile's popover)

    enum ItemMenu {
        static let open = NSLocalizedString("itemMenu.open", value: "Open",
            comment: "Popover item context menu: open the app or folder")
        static let showInFinder = NSLocalizedString("itemMenu.showInFinder", value: "Show in Finder",
            comment: "Popover item context menu: reveal the item in Finder")
        static let getInfo = NSLocalizedString("itemMenu.getInfo", value: "Get Info",
            comment: "Popover item context menu: open Finder's Get Info window")
        static let quickLook = NSLocalizedString("itemMenu.quickLook", value: "Quick Look",
            comment: "Popover item context menu: preview the item with Quick Look")
        static let share = NSLocalizedString("itemMenu.share", value: "Share…",
            comment: "Popover item context menu: open the share sheet for a folder")
        static let hide = NSLocalizedString("itemMenu.hide", value: "Hide",
            comment: "Popover item context menu: hide the running app")
        static let quit = NSLocalizedString("itemMenu.quit", value: "Quit",
            comment: "Popover item context menu: quit the running app")
        static let forceQuit = NSLocalizedString("itemMenu.forceQuit", value: "Force Quit",
            comment: "Popover item context menu: force quit (shown while Option is held)")
    }

    // MARK: - Sidebar

    enum Sidebar {
        static let title = NSLocalizedString(
            "sidebar.title",
            value: "Dock Tile",
            comment: "Navigation title for sidebar"
        )

        static let tilesSection = NSLocalizedString(
            "sidebar.section.tiles",
            value: "Tiles",
            comment: "Sidebar section header for the list of dock tiles"
        )

        static let settingsSection = NSLocalizedString(
            "sidebar.section.settings",
            value: "Settings",
            comment: "Sidebar section header for the inline app settings panes"
        )

        static let dockTileSection = NSLocalizedString(
            "sidebar.dockTileSection",
            value: "Dock Tile",
            comment: "Sidebar section holding About"
        )
    }

    // MARK: - Sections

    enum Section {
        static let inThisTile = NSLocalizedString(
            "section.inThisTile",
            value: "In This Tile",
            comment: "Tile Detail: apps section header"
        )
    }

    // MARK: - Smart Add

    /// Strings for the "Smart Add" sheet and its provenance banner. Grouped app usage is computed
    /// entirely on-device (see `SmartAddEngine`); the privacy footnote states this explicitly.
    enum SmartAdd {
        // Suggested tile names. They become the Dock tile's label, so they are localized.
        static let identityBrowse = NSLocalizedString("smartAdd.identity.browse", value: "Browse", comment: "Smart Add: suggested tile name for browsers")
        static let identityWatch = NSLocalizedString("smartAdd.identity.watch", value: "Watch", comment: "Smart Add: suggested tile name for video apps")
        static let identityShip = NSLocalizedString("smartAdd.identity.ship", value: "Ship", comment: "Smart Add: suggested tile name for developer tools")
        static let identityChat = NSLocalizedString("smartAdd.identity.chat", value: "Chat", comment: "Smart Add: suggested tile name for social apps")
        static let identityWork = NSLocalizedString("smartAdd.identity.work", value: "Work", comment: "Smart Add: suggested tile name for productivity apps")
        static let identityTogether = NSLocalizedString("smartAdd.identity.together", value: "Together", comment: "Smart Add: suggested tile name for apps opened together")
        static let title = NSLocalizedString(
            "smartAdd.title",
            value: "Add a Tile",
            comment: "Header title of the Smart Add suggestion sheet"
        )

        static let blankTitle = NSLocalizedString(
            "smartAdd.blankTitle",
            value: "Create a blank tile",
            comment: "Add a Tile: blank row title"
        )

        static let blankSubtitle = NSLocalizedString(
            "smartAdd.blankSubtitle",
            value: "Name it, pick an icon and add apps yourself.",
            comment: "Add a Tile: blank row subtitle"
        )

        static let orStartFrom = NSLocalizedString(
            "smartAdd.orStartFrom",
            value: "or start from what you use",
            comment: "Add a Tile: rule between blank row and suggestions"
        )

        static let noSuggestions = NSLocalizedString(
            "smartAdd.noSuggestions",
            value: "No suggestions yet — Dock Tile learns from the apps you open. You can turn this off in General.",
            comment: "Add a Tile: empty suggestions note"
        )

        static let privacyFootnote = NSLocalizedString(
            "smartAdd.privacyFootnote",
            value: "Learned on your Mac. Never leaves your device.",
            comment: "Footer note stating Smart Add suggestions are computed on-device only"
        )

        static let settingsToggleTitle = NSLocalizedString(
            "smartAdd.settings.toggleTitle",
            value: "Suggest tiles from my apps",
            comment: "Title of the Smart Add on/off toggle in General settings"
        )

        static let settingsToggleDescription = NSLocalizedString(
            "smartAdd.settings.toggleDescription",
            value: "Learned on your Mac. Never leaves your device.",
            comment: "Description under the Smart Add toggle in General settings"
        )

        static let reasonByCategory = NSLocalizedString(
            "smartAdd.reason.byCategory",
            value: "By category",
            comment: "Reason chip — apps grouped by their app category"
        )

        static let reasonMostUsed = NSLocalizedString(
            "smartAdd.reason.mostUsed",
            value: "Most used this week",
            comment: "Reason chip — the most-used cluster this week"
        )

        static let reasonOpenedTogether = NSLocalizedString(
            "smartAdd.reason.openedTogether",
            value: "Opened together",
            comment: "Reason chip — apps repeatedly opened in the same session"
        )

        static let provenanceBanner = NSLocalizedString(
            "smartAdd.provenanceBanner",
            value: "Created by Smart Add from your recent apps. Rename it, restyle it or edit the apps — then add it to your Dock.",
            comment: "Banner shown atop Tile Detail when a tile was just created by Smart Add"
        )
    }

    // MARK: - Translation (review invitation)

    enum Translation {
        static let title = NSLocalizedString(
            "translation.title",
            value: "Translation",
            comment: "About: translation row label (shown only when the UI runs in a non-English language)"
        )
        static let reviewLine = NSLocalizedString(
            "translation.reviewLine",
            value: "Machine translated. Not yet checked by a native speaker.",
            comment: "About: translation row description. Reviewers replace this in their language with who reviewed it, e.g. 'Reviewed by @handle'."
        )
        static let helpImprove = NSLocalizedString(
            "translation.helpImprove",
            value: "Help Improve…",
            comment: "Button: opens the language's review sheet on GitHub"
        )
        static let inviteTitle = NSLocalizedString(
            "translation.invite.title",
            value: "Dock Tile now speaks your language",
            comment: "One-time alert title on first launch in a machine-translated language"
        )
        static let inviteMessage = NSLocalizedString(
            "translation.invite.message",
            value: "This translation was made by a machine and has not yet been checked by a native speaker. If something reads wrong, you can fix it on GitHub — no coding needed.",
            comment: "One-time alert message inviting translation review"
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

    // MARK: - Titles

    enum Title {
        static let deleteTile = NSLocalizedString(
            "title.deleteTile",
            value: "Delete Tile",
            comment: "Alert title for delete confirmation"
        )
        static let revertToDock = NSLocalizedString(
            "title.revertToDock",
            value: "Revert to Dock Version?",
            comment: "Alert title: discard the tile's unapplied edits and go back to the version in the Dock"
        )
        static let customiseTile = NSLocalizedString(
            "title.customiseTile",
            value: "Customise Tile",
            comment: "Title of the Customise Tile inspector beside Tile Detail"
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

        static let openSettings = NSLocalizedString(
            "tooltip.openSettings",
            value: "Settings",
            comment: "Tooltip for the settings toolbar button"
        )

        static let deleteTile = NSLocalizedString(
            "tooltip.deleteTile",
            value: "Delete Tile",
            comment: "Tile Detail: trash button tooltip"
        )

        static let revertToDock = NSLocalizedString(
            "tooltip.revertToDock",
            value: "Revert to Dock Version",
            comment: "Tile Detail: revert button tooltip and accessibility label, and the File menu item — discards unapplied edits, restoring the version the tile's Dock icon was built from"
        )

        static let toggleCustomiseTile = NSLocalizedString(
            "tooltip.toggleCustomiseTile",
            value: "Toggle Customise Tile",
            comment: "Tooltip and accessibility label of the toolbar button that opens or closes the Customise Tile inspector"
        )

        static let toggleCustomiser = NSLocalizedString(
            "tooltip.toggleCustomiser",
            value: "Toggle Customiser",
            comment: "Tooltip and accessibility label of the Tile Detail icon, which opens or closes the Customise Tile inspector when clicked"
        )
    }

    // MARK: - Empty States

    enum Empty {
        static let createFirstTile = NSLocalizedString(
            "empty.createFirstTile",
            value: "Create Your First Tile",
            comment: "Header text for empty state"
        )

        static let createFirstTileDescription = NSLocalizedString(
            "empty.createFirstTileDescription",
            value: "Group apps and folders behind one Dock icon. Start blank, or from a tile suggested from the apps you use.",
            comment: "Zero-tiles description"
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
            value: "Select one or more applications or folders to add",
            comment: "Message in file picker dialog"
        )
    }

    // MARK: - Error Messages

    /// Error messages shown to users (not debug logs)
    enum Error {
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

        static let appTranslocated = NSLocalizedString(
            "error.appTranslocated",
            value: "Dock Tile is running from a temporary, read-only location and can't create tiles. Move it to your Applications folder and try again.",
            comment: "Error when the app is translocated and cannot generate helper bundles"
        )

        static let bundleBuildInProgress = NSLocalizedString(
            "error.bundleBuildInProgress",
            value: "This tile is already being rebuilt. Wait for that to finish, then try again.",
            comment: "Error when a second build is requested for a tile whose helper bundle is already being built"
        )

        static let dockChangeNotKept = NSLocalizedString(
            "error.dockChangeNotKept",
            value: "The Dock didn't keep this change. Try again.",
            comment: "Error when Dock Tile wrote a change to the Dock (add, update or hide a tile) but the Dock did not keep it, even after one retry"
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
