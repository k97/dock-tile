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
            item.button?.image = Self.statusGlyph()
            item.button?.setAccessibilityLabel(Self.buildName)
            let menu = NSMenu()
            menu.delegate = self
            item.menu = menu
            statusItem = item
            DiagnosticsLog.shared.log("menu", "Status item added (glyph: \(item.button?.image != nil), visible: \(item.isVisible))")
        } else if !enabled, let item = statusItem {
            NSStatusBar.system.removeStatusItem(item)
            statusItem = nil
        }
    }

    /// "Dock Tile" in a release build, "Dock Tile Dev" in a dev build (the bundle's own name).
    private static let buildName = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? AppStrings.appName

    /// The brand glyph as an 18×18 template. A dev build adds a dot in the bottom-right corner, cut
    /// clear of the sun, so it reads apart from the release build's icon next to it.
    private static func statusGlyph() -> NSImage? {
        guard let glyph = SFSymbolCatalog.brandGlyph?.copy() as? NSImage else { return nil }
        glyph.size = NSSize(width: 18, height: 18)
        glyph.isTemplate = true
        guard AppEnvironment.isDev else { return glyph }
        let badged = NSImage(size: glyph.size, flipped: false) { rect in
            glyph.draw(in: rect)
            let dot = NSRect(x: rect.maxX - 7, y: rect.minY, width: 7, height: 7)
            NSColor.black.setFill()
            NSGraphicsContext.current?.compositingOperation = .destinationOut
            NSBezierPath(ovalIn: dot.insetBy(dx: -1.5, dy: -1.5)).fill()
            NSGraphicsContext.current?.compositingOperation = .sourceOver
            NSBezierPath(ovalIn: dot).fill()
            return true
        }
        badged.isTemplate = true
        return badged
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
        // The dev build names itself, so its menu can't be mistaken for the release build's beside it.
        menu.addItem(item(AppStrings.Menu.openDockTile.replacingOccurrences(of: AppStrings.appName, with: Self.buildName),
                          #selector(openDockTile)))
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
