//
//  TileMenu.swift
//  DockTile
//
//  The tile menu shared by the menu bar icon, Dock Tile's own Dock menu, and (its app rows only)
//  an App-mode tile's Dock menu (issue #13). One builder, so the three can't drift.
//
//  Swift 6 - Strict Concurrency
//

import AppKit
import SwiftUI

@MainActor
enum TileMenu {

    // MARK: - Pure seam (TileMenuTests)

    struct AppRow: Equatable {
        let item: AppItem
        let enabled: Bool
    }

    /// The tiles a menu lists: those shown in the Dock, in the order given (the sidebar's). A tile with
    /// Show Tile off is hidden from the menus too (owner, 2026-11-05).
    nonisolated static func menuTiles(_ configs: [DockTileConfiguration]) -> [DockTileConfiguration] {
        configs.filter(\.isVisibleInDock)
    }

    /// A tile's apps and folders in tile order. A missing one stays listed but disabled, like the
    /// popover's "Not installed" row.
    nonisolated static func rows(for config: DockTileConfiguration, isInstalled: (AppItem) -> Bool) -> [AppRow] {
        config.appItems.map { AppRow(item: $0, enabled: isInstalled($0)) }
    }

    // MARK: - Menu items

    static let iconSize = NSSize(width: 16, height: 16)

    /// One item per app or folder (`representedObject` = the `AppItem`), or one disabled
    /// "No apps configured" row for an empty tile.
    static func appItems(for config: DockTileConfiguration, target: AnyObject, action: Selector) -> [NSMenuItem] {
        let rows = Self.rows(for: config, isInstalled: AppInstallChecker.isInstalled)
        guard !rows.isEmpty else {
            let empty = NSMenuItem(title: AppStrings.Menu.noAppsConfigured, action: nil, keyEquivalent: "")
            empty.isEnabled = false
            return [empty]
        }
        return rows.map { row in
            let item = NSMenuItem(title: row.item.name, action: row.enabled ? action : nil, keyEquivalent: "")
            item.target = target
            item.representedObject = row.item
            item.isEnabled = row.enabled
            // Copy before sizing: the loader's image may be shared, and resizing it in place would
            // shrink it everywhere else it is drawn.
            if let icon = AppIconLoader.icon(for: row.item)?.copy() as? NSImage {
                icon.size = iconSize
                item.image = icon
            }
            return item
        }
    }

    /// One item per tile shown in the Dock (`menuTiles`), with its icon and a submenu of its apps
    /// followed by "Configure Tile…" (whose `representedObject` is the tile's `UUID`). The submenu
    /// is filled when it opens: building every tile's app icons up front took 183 ms with a
    /// 96-app tile (Debug, 2026-11-05).
    static func tileItems(for configs: [DockTileConfiguration], target: AnyObject,
                          launch: Selector, configure: Selector) -> [NSMenuItem] {
        let scheme: ColorScheme = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? .dark : .light
        return menuTiles(configs).map { config in
            let item = NSMenuItem(title: config.name, action: nil, keyEquivalent: "")
            item.image = tileIcon(for: config, colorScheme: scheme)
            item.submenu = TileSubmenu(config: config, target: target, launch: launch, configure: configure)
            return item
        }
    }

    /// A tile's app submenu, filled each time it opens. Its own delegate, so the parent
    /// item's `submenu` keeps it alive (`NSMenu.delegate` is weak).
    private final class TileSubmenu: NSMenu, NSMenuDelegate {
        private let config: DockTileConfiguration
        private weak var target: AnyObject?
        private let launch: Selector
        private let configure: Selector

        init(config: DockTileConfiguration, target: AnyObject, launch: Selector, configure: Selector) {
            self.config = config
            self.target = target
            self.launch = launch
            self.configure = configure
            super.init(title: config.name)
            delegate = self
            // One placeholder so the parent row draws its submenu arrow before the first open.
            addItem(NSMenuItem(title: "", action: nil, keyEquivalent: ""))
        }

        required init(coder: NSCoder) { fatalError("not used") }

        func menuNeedsUpdate(_ menu: NSMenu) {
            guard let target else { return }
            removeAllItems()
            TileMenu.appItems(for: config, target: target, action: launch).forEach(addItem)
            addItem(.separator())
            let configureItem = NSMenuItem(title: AppStrings.Menu.configureTileItem, action: configure, keyEquivalent: "")
            configureItem.target = target
            configureItem.representedObject = config.id
            addItem(configureItem)
        }
    }

    /// The tile's face as the sidebar draws it, rendered at menu size.
    private static func tileIcon(for config: DockTileConfiguration, colorScheme: ColorScheme) -> NSImage? {
        let renderer = ImageRenderer(content:
            TileFace(config: config, size: iconSize.width).environment(\.colorScheme, colorScheme)
        )
        renderer.scale = NSScreen.main?.backingScaleFactor ?? 2
        return renderer.nsImage
    }
}
