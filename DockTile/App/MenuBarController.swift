//
//  MenuBarController.swift
//  DockTile
//
//  The optional menu bar icon (issue #13): every tile shown in the Dock with a submenu of its
//  apps, then Open Dock Tile… and Quit. Main app only; owns the one NSStatusItem. While it is on,
//  Dock Tile stays running with its window closed and drops its own Dock icon (AppDelegate).
//
//  Swift 6 - Strict Concurrency
//

import AppKit

@MainActor
final class MenuBarController: NSObject, NSMenuDelegate {
    static let shared = MenuBarController()

    /// The main app's manager, handed over by `DockTileApp.init()` (not the window's `onAppear`, so
    /// the menu has tiles even before a window exists).
    var configManager: ConfigurationManager?

    private var statusItem: NSStatusItem?

    // MARK: - Pure seams (MenuBarDefaultTests)

    /// The value written the first time a build with this feature runs: ON for a new install,
    /// OFF for an existing user, who never asked for a new menu bar icon (owner, 2026-11-05).
    nonisolated static func initialEnabled(hasLaunchedBefore: Bool) -> Bool {
        !hasLaunchedBefore
    }

    /// The stored setting; absent reads OFF.
    static var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: UserDefaultsKeys.menuBarEnabled)
    }

    // MARK: - Status item

    /// Adds or removes the icon. Idempotent.
    func apply(enabled: Bool) {
        if enabled, statusItem == nil {
            let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
            if let glyph = SFSymbolCatalog.brandGlyph?.copy() as? NSImage {
                glyph.size = NSSize(width: 18, height: 18)
                glyph.isTemplate = true
                item.button?.image = glyph
            }
            item.button?.setAccessibilityLabel(AppStrings.appName)
            let menu = NSMenu()
            menu.delegate = self
            item.menu = menu
            statusItem = item
            DiagnosticsLog.shared.log("menu", "Status item added (glyph: \(item.button?.image != nil), visible: \(item.isVisible))")        } else if !enabled, let item = statusItem {
            NSStatusBar.system.removeStatusItem(item)
            statusItem = nil
        }
    }

    /// Rebuilt on every open, so tiles, install status and icons are always current.
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let configs = configManager?.configurations ?? []
        if configs.isEmpty {
            menu.addItem(item(AppStrings.Button.addATile, #selector(addTile)))
        } else {
            let tiles = DiagnosticsLog.shared.measure("Build menu bar menu", category: "menu") {
                TileMenu.tileItems(for: configs, target: self,
                                   launch: #selector(launchApp(_:)), configure: #selector(configureTile(_:)))
            }
            tiles.forEach(menu.addItem)
        }
        if !menu.items.isEmpty { menu.addItem(.separator()) }
        menu.addItem(item(AppStrings.Menu.openDockTile, #selector(openDockTile)))
        menu.addItem(item(AppStrings.Menu.quitDockTile, #selector(quit), key: "q"))
    }

    private func item(_ title: String, _ action: Selector, key: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        return item
    }

    // MARK: - Actions

    @objc private func launchApp(_ sender: NSMenuItem) {
        guard let appItem = sender.representedObject as? AppItem else { return }
        DiagnosticsLog.shared.ui("Menu bar → launch '\(appItem.name)'")
        AppLauncher.launch(appItem, source: "menu_bar")
    }

    @objc private func configureTile(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? UUID else { return }
        DiagnosticsLog.shared.ui("Menu bar → Configure Tile…")
        AppDelegate.instance?.revealTile(id: id)
    }

    @objc private func openDockTile() {
        DiagnosticsLog.shared.ui("Menu bar → Open Dock Tile…")
        AppDelegate.instance?.showConfigurationWindow()
    }

    /// Zero tiles: the same Add flow as the sidebar +, on the next turn so a just-recreated window's
    /// view is subscribed (as `openSettingsPane` does).
    @objc private func addTile() {
        DiagnosticsLog.shared.ui("Menu bar → Add a Tile…")
        AppDelegate.instance?.showConfigurationWindow()
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .openAddTile, object: nil)
        }
    }

    @objc private func quit() {
        DiagnosticsLog.shared.ui("Menu bar → Quit Dock Tile")
        NSApp.terminate(nil)
    }
}
