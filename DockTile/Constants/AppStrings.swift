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

        static let keep = NSLocalizedString(
            "button.keep",
            value: "Keep",
            comment: "Button to keep uninstalled apps in tiles (dismiss the removal prompt)"
        )

        static let scanForMissingApps = NSLocalizedString(
            "button.scanForMissingApps",
            value: "Scan…",
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
    }

    // MARK: - Labels

    enum Label {
        static let colour = NSLocalizedString(
            "label.colour",
            value: "Tile Colour",
            comment: "Label for colour picker section"
        )

        // MARK: Popover Appearance controls

        static let popoverLayout = NSLocalizedString(
            "label.popover.layout",
            value: "Layout",
            comment: "Label for the Grid/List preview toggle in popover settings"
        )

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

        static let iconWeightInfo = NSLocalizedString(
            "label.iconWeightInfo",
            value: "Weight applies to symbols only. Emoji aren’t affected.",
            comment: "Popover/help note explaining that the icon weight setting affects symbols but not emoji"
        )

        static let iconWeightInfoAccessibility = NSLocalizedString(
            "label.iconWeightInfo.accessibility",
            value: "About Icon Weight",
            comment: "VoiceOver label for the icon weight info button"
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

        static let dockLockAccessibilityGranted = NSLocalizedString(
            "settings.dockLock.accessibilityGranted",
            value: "Accessibility access granted",
            comment: "Status shown when Accessibility permission is granted"
        )

        static let dockLockOpenSettings = NSLocalizedString(
            "settings.dockLock.openSettings",
            value: "Open System Settings…",
            comment: "Button that opens the Accessibility pane in System Settings"
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

        static let popoverAppearance = NSLocalizedString(
            "settings.popover.appearance",
            value: "Appearance",
            comment: "Title of the drill-down row in General that opens popover settings"
        )

        static let popoverAppearanceSubtitle = NSLocalizedString(
            "settings.popover.appearance.subtitle",
            value: "Layout, size, spacing and labels for every tile's popover",
            comment: "Subtitle under the Popover Appearance drill-down row"
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
    }

    // MARK: - Menu Items

    enum Menu {
        static let configure = NSLocalizedString(
            "menu.configure",
            value: "Configure...",
            comment: "Menu item to configure tile (opens main app)"
        )

        static let settings = NSLocalizedString(
            "menu.settings",
            value: "Settings…",
            comment: "App menu item that opens the inline Settings pane (⌘,)"
        )

        static let newTile = NSLocalizedString(
            "menu.newTile",
            value: "New Dock Tile",
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

        static let openSettings = NSLocalizedString(
            "tooltip.openSettings",
            value: "Settings",
            comment: "Tooltip for the settings toolbar button"
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
