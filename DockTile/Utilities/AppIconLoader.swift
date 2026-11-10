//
//  AppIconLoader.swift
//  DockTile
//
//  Shared utility for loading app icons from AppItem models.
//  Handles Asset Catalog detection, icon style awareness, and fallback paths.
//  Swift 6 - Strict Concurrency
//

import AppKit

@MainActor
enum AppIconLoader {

    /// Load the appropriate icon for an AppItem.
    /// - Resolves through `NSWorkspace` so the icon matches what the Dock / Finder / Mission
    ///   Control show — including macOS Tahoe's system-applied dark / clear / tinted treatment.
    /// - Falls back to the last-known path, then common paths. There is no stored-icon fallback:
    ///   an app that resolves nowhere is "missing" and the UI draws a placeholder instead.
    static func icon(for item: AppItem) -> NSImage? {
        // For folders, get icon from folder path
        if item.isFolder, let folderPath = item.folderPath {
            return NSWorkspace.shared.icon(forFile: folderPath)
        }

        // Get from bundle identifier
        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: item.bundleIdentifier) {
            return iconFromAppURL(appURL)
        }

        // The app still exists at its last-known path even though Launch Services no longer
        // resolves the bundle ID (app moved, or LS not yet re-registered after an update). Load
        // the live icon from disk rather than falling through to a placeholder.
        if let lastKnownPath = item.lastKnownPath,
           FileManager.default.fileExists(atPath: lastKnownPath) {
            return iconFromAppURL(URL(fileURLWithPath: lastKnownPath))
        }

        // Try common paths for apps
        for path in AppInstallChecker.commonSearchPaths(forName: item.name) {
            if FileManager.default.fileExists(atPath: path) {
                return iconFromAppURL(URL(fileURLWithPath: path))
            }
        }

        return nil
    }

    // MARK: - Private Helpers

    /// Load an app's icon the same way the system surfaces it everywhere else.
    ///
    /// `NSWorkspace.icon(forFile:)` returns the icon IconServices renders for the Dock, Finder and
    /// Mission Control — which on macOS Tahoe includes the system-generated dark / clear / tinted
    /// treatment even for apps that ship only a single light `.icns` and no `Assets.car` (e.g. VS
    /// Code, most Electron apps). A previous version bypassed this for non-Assets.car apps and read
    /// the raw `.icns` directly to "avoid unwanted dark tinting" — but that suppressed the *correct*
    /// system treatment, so those apps were stuck showing their light icon while the Dock showed
    /// them dark. We now always go through `NSWorkspace`; the popover/list re-render on icon-style
    /// changes via their `.id(...)` composites, so the variant tracks live.
    ///
    /// NOTE: this only ever loads *third-party* app icons (the apps a user adds to a tile). It is
    /// never used for DockTile's own helper tile faces — those are generated with their own dark
    /// variant by `IconGenerator` / `IconStyleManager` — so there's no risk of double-treatment.
    ///
    /// The URL is resolved through symlinks first: on macOS 27 `/Applications/Safari.app` is a
    /// symlink, and `NSWorkspace.icon(forFile:)` on the symlink returned the icon with an alias-arrow
    /// badge.
    private static func iconFromAppURL(_ appURL: URL) -> NSImage {
        let bundleURL = appURL.resolvingSymlinksInPath()
        let workspaceIcon = NSWorkspace.shared.icon(forFile: bundleURL.path)
        if !workspaceIcon.representations.isEmpty {
            return workspaceIcon
        }
        // Defensive fallback: if NSWorkspace somehow returns an empty image, read the bundle's
        // declared `.icns` directly rather than handing back a blank icon.
        return loadIconDirectlyFromBundle(atPath: bundleURL.path) ?? workspaceIcon
    }

    /// Load icon directly from app bundle's .icns file (defensive fallback only)
    private static func loadIconDirectlyFromBundle(atPath path: String) -> NSImage? {
        let infoPlistURL = URL(fileURLWithPath: path)
            .appendingPathComponent("Contents/Info.plist")
        guard let infoPlist = NSDictionary(contentsOf: infoPlistURL) else {
            return nil
        }

        guard var iconName = infoPlist["CFBundleIconFile"] as? String
                ?? infoPlist["CFBundleIconName"] as? String else {
            return nil
        }

        if !iconName.hasSuffix(".icns") {
            iconName += ".icns"
        }

        let iconURL = URL(fileURLWithPath: path)
            .appendingPathComponent("Contents/Resources/\(iconName)")
        return NSImage(contentsOf: iconURL)
    }

    /// Modification time of the bundle at `path` (0 when absent) — part of the raster-cache key, so
    /// an updated app gets a fresh icon without restarting the tile.
    nonisolated static func modificationStamp(atPath path: String?) -> TimeInterval {
        guard let path,
              let date = try? FileManager.default.attributesOfItem(atPath: path)[.modificationDate] as? Date
        else { return 0 }
        return date.timeIntervalSince1970
    }
}

// MARK: - Tile Icon Raster Cache

/// Process-lifetime cache of RASTERISED app icons for the popover.
///
/// WHY: an `NSImage` from `NSWorkspace.icon(forFile:)` is an IconServices proxy. When SwiftUI draws
/// it, the proxy renders the bitmap over a SYNCHRONOUS XPC call to `iconservicesagent` (~3.5 ms per
/// icon, main thread). The agent caches renders for only a few minutes, and the popover used to
/// rebuild every `NSImage` per open, so the first open after idle paid the whole bill: 201 ms on a
/// 10-app Release tile, ~470 ms on a 102-app tile. A plain `CGImage` has no proxy behind it, so
/// holding the bitmaps here removes the XPC from the click path.
///
/// Main-actor only on purpose — no assumption is made about NSWorkspace/NSImage thread-safety. The
/// cost is moved ahead of the click by `prewarm`, one icon per run-loop turn.
@MainActor
final class TileIconRasterCache {
    // A closure literal, NOT `rasterise: TileIconRasterCache.systemRasterise`: the method inherits
    // @MainActor from this class, and Swift 6 refuses to convert that to the plain function type
    // ("loses global actor 'MainActor'").
    static let shared = TileIconRasterCache { item, size in TileIconRasterCache.systemRasterise(item, size) }

    struct Key: Hashable {
        let itemKey: String
        let pixelSize: Int
        let contentStamp: TimeInterval
    }

    private let rasterise: (AppItem, Int) -> CGImage?
    private var images: [Key: CGImage] = [:]
    private var token = ""
    /// How many times the rasteriser actually ran — the tests' observability hook.
    private(set) var rasteriseCount = 0

    init(rasterise: @escaping (AppItem, Int) -> CGImage?) {
        self.rasterise = rasterise
    }

    nonisolated static func pixelSize(pointSize: CGFloat, scale: CGFloat) -> Int {
        Int((pointSize * max(scale, 1)).rounded(.up))
    }

    /// A rasterised bitmap bakes in Light/Dark and the Tahoe icon style, so both are in the token.
    ///
    /// `private` ON PURPOSE (critical): a token is only ever correct if its style half came from a
    /// LIVE read of `AppleIconAppearanceTheme`. A HELPER on macOS 26 seeds `IconStyleManager
    /// .rawStyle` once in `init()` and never refreshes it — detection is quarantined on Tahoe
    /// (`shouldRunDetection`) and `refreshRawStyle()` is main-app only — and an icon-style change
    /// moves neither the app bundle's mtime nor the requested pixel size, so nothing else in the
    /// cache key moves either. Feeding that frozen value in here made the helper serve bitmaps in
    /// the launch-time appearance for its entire process lifetime. Keeping this overload private
    /// means a call site cannot reach it with a stale snapshot: the only ways in are
    /// `appearanceToken(rawStyleObject:isDark:)` and `liveAppearanceToken(isDark:)`.
    private nonisolated static func appearanceToken(style: IconStyle, isDark: Bool, raw: RawStyleToken) -> String {
        let stored: String
        switch raw {
        case .absent: stored = "absent"
        case .unreadable: stored = "unreadable"
        case .value(let value): stored = value
        }
        return "\(style.rawValue)-\(isDark ? "dark" : "light")-\(stored)"
    }

    /// Resolve the token from the UNTYPED `AppleIconAppearanceTheme` object as just read. Pure —
    /// this is the seam `TileIconRasterCacheTests.tokenTracksTheLiveStyleRead` drives with values
    /// it supplies, so a token that ignores the read (the frozen-at-launch regression) fails.
    /// The stored value itself is part of the token: `IconStyle` folds Tinted Light and Tinted Dark
    /// (and Clear Light/Dark) into one case, but macOS draws app icons differently for each, so a
    /// switch between them must re-rasterise (issue #22).
    nonisolated static func appearanceToken(rawStyleObject: Any?, isDark: Bool) -> String {
        let raw = IconStyleManager.token(from: rawStyleObject)
        return appearanceToken(
            style: IconStyle.forDisplay(raw: raw, colorScheme: isDark ? .dark : .light, fallback: .defaultStyle),
            isDark: isDark, raw: raw)
    }

    /// The token for a popover being built RIGHT NOW: reads the preference on every call. The
    /// popover content is rebuilt on every `show()`, so this re-reads per open — a
    /// `CFPreferencesCopyAppValue` against an in-process cache, orders of magnitude cheaper than the
    /// per-icon synchronous IconServices XPC the cells paid before this cache existed.
    nonisolated static func liveAppearanceToken(isDark: Bool) -> String {
        appearanceToken(rawStyleObject: IconStyle.rawPreferencesObject, isDark: isDark)
    }

    nonisolated static func itemKey(for item: AppItem) -> String {
        item.isFolder ? "folder:\(item.folderPath ?? item.name)" : "app:\(item.bundleIdentifier)"
    }

    func image(for item: AppItem, pointSize: CGFloat, scale: CGFloat,
               appearanceToken: String, contentStamp: TimeInterval) -> CGImage? {
        if appearanceToken != token {
            images.removeAll()
            token = appearanceToken
        }
        let key = Key(itemKey: Self.itemKey(for: item),
                      pixelSize: Self.pixelSize(pointSize: pointSize, scale: scale),
                      contentStamp: contentStamp)
        if let hit = images[key] { return hit }
        rasteriseCount += 1
        guard let image = rasterise(item, key.pixelSize) else { return nil }
        images[key] = image
        return image
    }

    /// The ONE derivation of the key's content stamp — cells and prewarm both call it, so a
    /// prewarmed entry can never miss because the two sides looked at different paths.
    nonisolated static func contentStamp(for item: AppItem, resolvedPath: String?) -> TimeInterval {
        AppIconLoader.modificationStamp(atPath: item.isFolder ? item.folderPath : resolvedPath)
    }

    /// Fill the cache ahead of the first click, yielding between icons so no single run-loop turn
    /// carries more than one IconServices round trip. `scales`: every connected display's backing
    /// scale, so the popover hits whichever screen the Dock is on.
    func prewarm(items: [AppItem], pointSize: CGFloat, scales: [CGFloat], appearanceToken: String) async {
        for item in items {
            let stamp = Self.contentStamp(for: item, resolvedPath: AppInstallChecker.resolve(item).resolvedPath)
            for scale in scales {
                _ = image(for: item, pointSize: pointSize, scale: scale, appearanceToken: appearanceToken, contentStamp: stamp)
            }
            await Task.yield()
        }
    }

    private static func systemRasterise(_ item: AppItem, _ pixelSize: Int) -> CGImage? {
        guard let nsImage = AppIconLoader.icon(for: item) else { return nil }
        var rect = CGRect(x: 0, y: 0, width: pixelSize, height: pixelSize)
        var result: CGImage?
        // Rasterise under the app's effective appearance so the bitmap matches what SwiftUI would
        // have drawn for the same colour scheme.
        NSApp.effectiveAppearance.performAsCurrentDrawingAppearance {
            result = nsImage.cgImage(forProposedRect: &rect, context: nil, hints: nil)
        }
        return result
    }
}

// MARK: - App Install Checker

/// Whether the app/folder an `AppItem` points to is still present on this Mac.
enum AppInstallStatus: Equatable {
    /// Resolved on disk (live bundle, last-known path, or a common search path).
    case installed
    /// Not resolvable — flag it in the UI and offer to remove it. NOT shown with the stale icon.
    case missing
}

/// Determines whether the app behind an `AppItem` is still installed.
///
/// Detection is deliberately cheap — Launch Services bundle-ID lookups plus `stat()` calls, no
/// icon rasterisation — so a full sweep across every tile costs a few milliseconds. The actual
/// decision is the pure `classifyInstallStatus(...)` seam below so it can be unit-tested without
/// touching CFPreferences / FileManager (mirrors `classifyForMigration`, `resolveDockVisibility`).
@MainActor
enum AppInstallChecker {

    /// Result of resolving an `AppItem` against the live filesystem.
    struct Resolution: Equatable {
        let status: AppInstallStatus
        /// The current on-disk path when `installed` — used to heal a stale `lastKnownPath`.
        let resolvedPath: String?
    }

    /// The Apps face's one install rule: what the tile preview draws, what the Customise Apps card
    /// counts and what the helper bake shows.
    static func isInstalled(_ item: AppItem) -> Bool {
        resolve(item).status == .installed
    }

    /// Resolve an item's install status against the live system.
    static func resolve(_ item: AppItem) -> Resolution {
        // Folders are validated purely by their stored path.
        if item.isFolder {
            if let path = item.folderPath, FileManager.default.fileExists(atPath: path), !isTrashed(path) {
                return Resolution(status: .installed, resolvedPath: path)
            }
            return Resolution(status: .missing, resolvedPath: nil)
        }

        // Launch Services resolves BY bundle identifier, so a hit is the right app by construction —
        // but a registration outlives the bundle it points at, and a bundle dragged to the Trash is
        // still on disk and still registered. So the path it hands back must itself be a live
        // install location; merely getting a URL back proves nothing.
        let launchServicesPath: String? = {
            guard let path = NSWorkspace.shared
                .urlForApplication(withBundleIdentifier: item.bundleIdentifier)?.path else { return nil }
            return FileManager.default.fileExists(atPath: path) && !isTrashed(path) ? path : nil
        }()

        // Path probes must confirm the bundle's IDENTITY, not just that something is there: two
        // different apps can share a display name, and `lastKnownPath` may be stale.
        //
        // Only worth doing when Launch Services came up empty: reading a candidate's Info.plist
        // costs ~59x a `stat` (58.7us vs 1.0us, measured), and `resolve` runs synchronously in the
        // popover's view body for every app on every render. When LS already answered, this probe
        // can change neither the status nor the resolved path.
        let onDiskPath: String? = launchServicesPath != nil ? nil : {
            let candidates = [item.lastKnownPath].compactMap { $0 } + commonSearchPaths(forName: item.name)
            return candidates.first { path in
                acceptsProbedPath(
                    exists: FileManager.default.fileExists(atPath: path),
                    isTrashed: isTrashed(path),
                    foundBundleId: bundleIdentifier(atPath: path),
                    expected: item.bundleIdentifier
                )
            }
        }()

        let status = classifyInstallStatus(
            bundleResolves: launchServicesPath != nil,
            onDiskPathExists: onDiskPath != nil
        )

        return Resolution(status: status, resolvedPath: launchServicesPath ?? onDiskPath)
    }

    /// Pure: is this path inside a Trash directory? Dragging an app to the Trash is how most people
    /// uninstall — the bundle and its Launch Services registration both survive there, so a bare
    /// existence check would keep calling it installed. Keys on the directory, not the word, so an
    /// app legitimately named "Trash Cleaner" is unaffected.
    nonisolated static func isTrashed(_ path: String) -> Bool {
        path.contains("/.Trash/") || path.contains("/.Trashes/")
    }

    /// Pure: is a probed path acceptable evidence that `expected` is installed? It must exist, be
    /// outside the Trash, AND actually host that bundle identifier.
    ///
    /// The identity check is what stops a same-named *different* app from vouching for a deleted
    /// one — the production report where a Chrome web-app shim called "Claude" stayed "installed"
    /// because `/Applications/Claude.app` (the unrelated native app) satisfied the name probe. The
    /// tile kept showing the survivor's icon and Settings → Scan reported all-clear. Worse, the
    /// scan writes the resolved path back into `lastKnownPath`, so an unverified match would poison
    /// the item into confirming itself installed on every later scan.
    nonisolated static func acceptsProbedPath(
        exists: Bool,
        isTrashed: Bool,
        foundBundleId: String?,
        expected: String
    ) -> Bool {
        exists && !isTrashed && foundBundleId == expected
    }

    /// The bundle identifier declared by the app bundle at `path`, if it is readable.
    private static func bundleIdentifier(atPath path: String) -> String? {
        NSDictionary(contentsOfFile: path + "/Contents/Info.plist")?["CFBundleIdentifier"] as? String
    }

    /// Pure decision seam — given installation signals, classify the item. No I/O.
    ///
    /// An item is `installed` when Launch Services resolves its bundle ID OR an app bundle exists
    /// on disk (last-known path or a common install dir); otherwise it is `missing`.
    ///
    /// DockTile's own cached snapshot of an icon would NOT count as an installation signal (and no
    /// such snapshot is stored any more — see AppItem) — only the live system does,
    /// not evidence the app is on disk. An earlier version treated "no live bundle + no path + has
    /// cached icon" as an `unknown` legacy-safety case and left it unflagged. But every pre-v8
    /// entry (added before `lastKnownPath` existed) carries a cached icon and no path, so any app
    /// uninstalled *before* upgrading was permanently exempted — it kept showing its stale icon and
    /// never appeared in the removal prompt. Detection is non-destructive (a dimmed badge + a
    /// dismissible Remove/Keep prompt), so the right call is to flag it; a rare transient miss
    /// self-heals on the next scan once Launch Services re-resolves the bundle.
    nonisolated static func classifyInstallStatus(
        bundleResolves: Bool,
        onDiskPathExists: Bool
    ) -> AppInstallStatus {
        (bundleResolves || onDiskPathExists) ? .installed : .missing
    }

    /// Common locations to probe for an app bundle by display name.
    nonisolated static func commonSearchPaths(forName name: String) -> [String] {
        [
            "/Applications/\(name).app",
            "/System/Applications/\(name).app",
            "/Applications/Utilities/\(name).app",
            "\(NSHomeDirectory())/Applications/\(name).app"
        ]
    }
}

// MARK: - App Icon Style Renderer

/// The icon styles an App Grid bake renders each app in — one per `.icon` appearance slot.
/// Clear Light / Clear Dark / Tinted Light / Tinted Dark all draw from the tinted slot (measured
/// with Apple's `ictool`), and of the candidates a Clear DARK render there comes closest to the
/// apps' own icons across those four styles.
enum AppIconRenderStyle: CaseIterable {
    case standard, dark, clearDark
}

/// Renders an app's icon in a NAMED icon style, whatever style the system is in right now.
///
/// WHY PRIVATE API: `NSWorkspace.icon(forFile:)` only ever returns the CURRENT system style (under
/// Clear Dark, drawing it as `.aqua` and as `.darkAqua` both give Clear Dark), so a tile baked while
/// the user is in one style froze every mini in that style, and the system's clear filter over a
/// colour mini turned e.g. VS Code's white plate into a bright square. IconServices'
/// `ISImageDescriptor` takes the style explicitly. Everything is resolved at runtime and guarded:
/// any missing class or selector, or a nil image, returns nil and the caller falls back to the
/// public loader — a future macOS can make this render nothing, never crash.
@MainActor
enum AppIconStyleRenderer {
    /// IconServices' `appearance` (0 light, 1 dark) and `appearanceVariant` (0 normal, 2 tinted,
    /// 3 clear) for each style. Measured on macOS 27; tinted is unused (it needs the system's tint
    /// colour, which nothing exposes).
    nonisolated static func descriptorValues(for style: AppIconRenderStyle) -> (appearance: Int, appearanceVariant: Int) {
        switch style {
        case .standard: return (0, 0)
        case .dark: return (1, 0)
        case .clearDark: return (1, 3)
        }
    }

    // Ownership, because Swift cannot see ObjC's method families through these casts: `alloc`
    // returns +1 and `init…` CONSUMES its receiver and returns +1 (so both are taken retained,
    // the receiver passed unretained); `CGImageForImageDescriptor:` is not a create/copy method,
    // so its image is +0.
    private typealias InitWithURLFn = @convention(c) (AnyObject, Selector, AnyObject) -> Unmanaged<AnyObject>?
    private typealias InitWithSizeFn = @convention(c) (AnyObject, Selector, CGSize, CGFloat) -> Unmanaged<AnyObject>?
    private typealias SetIntFn = @convention(c) (AnyObject, Selector, Int) -> Void
    private typealias PrepareFn = @convention(c) (AnyObject, Selector, AnyObject) -> Void
    private typealias ImageFn = @convention(c) (AnyObject, Selector, AnyObject) -> Unmanaged<CGImage>?

    private static let frameworkLoaded: Bool =
        dlopen("/System/Library/PrivateFrameworks/IconServices.framework/IconServices", RTLD_NOW) != nil

    /// The app bundle at `url` in `style`: a square image of at least `pixelSize` (IconServices may
    /// return a larger backing, e.g. 2×), carrying the icon-grid margin like the public render.
    /// Nil when the URL is not an app bundle or any part of the private API is unavailable.
    static func render(appAt url: URL, pixelSize: Int, style: AppIconRenderStyle) -> CGImage? {
        guard frameworkLoaded, pixelSize > 0,
              url.pathExtension == "app", Bundle(url: url) != nil,
              let icon = makeBundleIcon(url),
              let descriptor = makeDescriptor(pixelSize: pixelSize, style: style)
        else { return nil }

        let prepare = NSSelectorFromString("prepareImageForDescriptor:")
        let imageSel = NSSelectorFromString("CGImageForImageDescriptor:")
        guard icon.responds(to: prepare), icon.responds(to: imageSel) else { return nil }
        // Without the prepare, a style IconServices has not rendered yet comes back as a dashed
        // placeholder rather than nil.
        unsafeBitCast(icon.method(for: prepare), to: PrepareFn.self)(icon, prepare, descriptor)
        let imageFn = unsafeBitCast(icon.method(for: imageSel), to: ImageFn.self)
        return imageFn(icon, imageSel, descriptor)?.takeUnretainedValue()
    }

    /// Finder stores a pasted ("Get Info") icon for a bundle in an `Icon\r` file at its top level.
    /// `URLResourceKey.customIconKey` reads nil for such a bundle (measured 2026-11-10), so the
    /// file is the signal. A file left behind with the custom-icon flag cleared is harmless: the
    /// caller then uses the public icon, which honours the flag.
    nonisolated static func hasFinderCustomIcon(_ bundleURL: URL) -> Bool {
        FileManager.default.fileExists(atPath: bundleURL.appendingPathComponent("Icon\r").path)
    }

    private static func makeBundleIcon(_ url: URL) -> NSObject? {
        let initSel = NSSelectorFromString("initWithBundleURL:")
        guard let raw = allocate("ISBundleIcon"), raw.responds(to: initSel) else { return nil }
        let initFn = unsafeBitCast(raw.method(for: initSel), to: InitWithURLFn.self)
        return initFn(raw, initSel, url as NSURL)?.takeRetainedValue() as? NSObject
    }

    /// `+alloc` for a class looked up by name. The +1 it returns is handed to `init…`, which
    /// consumes it — so the caller must call an `init…` on the result exactly once.
    private static func allocate(_ className: String) -> NSObject? {
        guard let cls = NSClassFromString(className) as? NSObject.Type,
              cls.responds(to: NSSelectorFromString("alloc"))
        else { return nil }
        return cls.perform(NSSelectorFromString("alloc"))?.takeUnretainedValue() as? NSObject
    }

    private static func makeDescriptor(pixelSize: Int, style: AppIconRenderStyle) -> NSObject? {
        let initSel = NSSelectorFromString("initWithSize:scale:")
        let setAppearance = NSSelectorFromString("setAppearance:")
        let setVariant = NSSelectorFromString("setAppearanceVariant:")
        guard let raw = allocate("ISImageDescriptor"), raw.responds(to: initSel) else { return nil }
        let initFn = unsafeBitCast(raw.method(for: initSel), to: InitWithSizeFn.self)
        guard let descriptor = initFn(raw, initSel, CGSize(width: pixelSize, height: pixelSize), 1)?
                .takeRetainedValue() as? NSObject,
              descriptor.responds(to: setAppearance), descriptor.responds(to: setVariant)
        else { return nil }
        let values = descriptorValues(for: style)
        unsafeBitCast(descriptor.method(for: setAppearance), to: SetIntFn.self)(descriptor, setAppearance, values.appearance)
        unsafeBitCast(descriptor.method(for: setVariant), to: SetIntFn.self)(descriptor, setVariant, values.appearanceVariant)
        return descriptor
    }
}
