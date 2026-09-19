import AppKit
import Testing
@testable import Dock_Tile

/// Guards the popover's icon cache. The regression it exists to prevent: every popover open
/// re-asked IconServices for every icon over synchronous XPC (~3.5 ms each, main thread).
/// Failing values: a second lookup that rasterises again; a bitmap served for the wrong
/// appearance, size or app version.
@MainActor
@Suite("Tile icon raster cache")
struct TileIconRasterCacheTests {

    private func onePixel() -> CGImage {
        let ctx = CGContext(data: nil, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                            space: CGColorSpaceCreateDeviceRGB(),
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        return ctx.makeImage()!
    }

    private let app = AppItem(bundleIdentifier: "com.example.one", name: "One")

    @Test("A second lookup for the same key does not rasterise again")
    func secondLookupHits() {
        let cache = TileIconRasterCache { _, _ in self.onePixel() }
        _ = cache.image(for: app, pointSize: 56, scale: 2, appearanceToken: "default-light", contentStamp: 100)
        _ = cache.image(for: app, pointSize: 56, scale: 2, appearanceToken: "default-light", contentStamp: 100)
        #expect(cache.rasteriseCount == 1)
    }

    @Test("A different pixel size, app version or item is a miss")
    func differentKeysMiss() {
        let cache = TileIconRasterCache { _, _ in self.onePixel() }
        _ = cache.image(for: app, pointSize: 56, scale: 2, appearanceToken: "t", contentStamp: 100)
        _ = cache.image(for: app, pointSize: 72, scale: 2, appearanceToken: "t", contentStamp: 100)   // size
        _ = cache.image(for: app, pointSize: 56, scale: 2, appearanceToken: "t", contentStamp: 200)   // app updated
        let other = AppItem(bundleIdentifier: "com.example.two", name: "Two")
        _ = cache.image(for: other, pointSize: 56, scale: 2, appearanceToken: "t", contentStamp: 100) // item
        #expect(cache.rasteriseCount == 4)
    }

    @Test("An appearance change empties the cache, so nothing is served for the old look")
    func appearanceChangeClears() {
        let cache = TileIconRasterCache { _, _ in self.onePixel() }
        _ = cache.image(for: app, pointSize: 56, scale: 2, appearanceToken: "default-light", contentStamp: 100)
        _ = cache.image(for: app, pointSize: 56, scale: 2, appearanceToken: "dark-dark", contentStamp: 100)
        _ = cache.image(for: app, pointSize: 56, scale: 2, appearanceToken: "default-light", contentStamp: 100)
        #expect(cache.rasteriseCount == 3)
    }

    @Test("A failed rasterisation is not cached")
    func failuresAreRetried() {
        let cache = TileIconRasterCache { _, _ in nil }
        #expect(cache.image(for: app, pointSize: 56, scale: 2, appearanceToken: "t", contentStamp: 1) == nil)
        #expect(cache.image(for: app, pointSize: 56, scale: 2, appearanceToken: "t", contentStamp: 1) == nil)
        #expect(cache.rasteriseCount == 2)
    }

    /// The item must resolve to something REAL on disk, or this test cannot fail. With only fixture
    /// apps (`com.example.one` resolves nowhere) every stamp was `0` on the prewarm side and `0` on
    /// the lookup side, so a prewarm that keyed its entries differently from the cells still
    /// produced a hit and this test still passed — while the real cache wasted every prewarmed
    /// entry. That exact prewarm/cell key disagreement was a live defect earlier in this branch.
    ///
    /// A folder stamps from `folderPath`, so a temporary directory gives a non-zero stamp without
    /// depending on any installed app. Failing value: a prewarm that stamps `0` where the cell
    /// stamps the directory's mtime — the lookups miss and `rasteriseCount` reaches 6, not 4.
    @Test("Prewarm fills the cache so the later lookup is a hit, on a key that is not zero")
    func prewarmFills() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("prewarm-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let folder = try #require(AppItem.from(folderURL: dir))
        #expect(TileIconRasterCache.contentStamp(for: folder, resolvedPath: nil) != 0)

        let cache = TileIconRasterCache { _, _ in self.onePixel() }
        let items = [folder, AppItem(bundleIdentifier: "com.example.two", name: "Two")]
        await cache.prewarm(items: items, pointSize: 56, scales: [1, 2], appearanceToken: "t")
        #expect(cache.rasteriseCount == 4)   // two items × two display scales

        // The cell derives its stamp through the SAME function prewarm used.
        let stamp = TileIconRasterCache.contentStamp(
            for: folder, resolvedPath: AppInstallChecker.resolve(folder).resolvedPath)
        _ = cache.image(for: folder, pointSize: 56, scale: 2, appearanceToken: "t", contentStamp: stamp)
        _ = cache.image(for: folder, pointSize: 56, scale: 1, appearanceToken: "t", contentStamp: stamp)
        #expect(cache.rasteriseCount == 4)
    }

    @Test("A folder stamps from its folder path, an app from its resolved path")
    func contentStampSources() {
        let folder = AppItem(bundleIdentifier: "folder.1", name: "Tmp", isFolder: true, folderPath: NSTemporaryDirectory())
        #expect(TileIconRasterCache.contentStamp(for: folder, resolvedPath: nil) == AppIconLoader.modificationStamp(atPath: NSTemporaryDirectory()))
        #expect(TileIconRasterCache.contentStamp(for: app, resolvedPath: "/System/Applications/Calculator.app") == AppIconLoader.modificationStamp(atPath: "/System/Applications/Calculator.app"))
        #expect(TileIconRasterCache.contentStamp(for: app, resolvedPath: nil) == 0)
    }

    @Test("Pixel size rounds up and never drops below 1x")
    func pixelSizes() {
        #expect(TileIconRasterCache.pixelSize(pointSize: 56, scale: 2) == 112)
        #expect(TileIconRasterCache.pixelSize(pointSize: 44, scale: 1) == 44)
        #expect(TileIconRasterCache.pixelSize(pointSize: 24, scale: 2) == 48)
        #expect(TileIconRasterCache.pixelSize(pointSize: 18, scale: 1.5) == 27)
        #expect(TileIconRasterCache.pixelSize(pointSize: 56, scale: 0) == 56)
    }

    /// THE regression this guard exists for: a HELPER on macOS 26 seeds `IconStyleManager.rawStyle`
    /// once in `init()` and never refreshes it — Tahoe quarantines legacy detection
    /// (`shouldRunDetection`) and `refreshRawStyle()` is main-app only. An icon-style change moves
    /// neither the app bundle's mtime nor the pixel size, so nothing else in the cache key moves.
    /// A token built from that frozen snapshot therefore froze every bitmap the helper served for
    /// its whole process life. The token must come from the preference as read AT THIS MOMENT.
    ///
    /// Failing value: two equal tokens across a style change (a token computed from a launch-time
    /// constant), and hence `rasteriseCount == 1` where 2 is required.
    @Test("The appearance token tracks the live style read, so a style change flushes the cache")
    func tokenTracksTheLiveStyleRead() {
        // Exact tokens for the values macOS actually stores in AppleIconAppearanceTheme.
        #expect(TileIconRasterCache.appearanceToken(rawStyleObject: nil, isDark: false) == "defaultStyle-light")
        #expect(TileIconRasterCache.appearanceToken(rawStyleObject: "TintedAutomatic", isDark: false) == "tinted-light")
        #expect(TileIconRasterCache.appearanceToken(rawStyleObject: "ClearDark", isDark: true) == "clear-dark")
        #expect(TileIconRasterCache.appearanceToken(rawStyleObject: "RegularDark", isDark: false) == "dark-light")
        // Automatic follows the colour scheme, so the same stored value yields two tokens.
        #expect(TileIconRasterCache.appearanceToken(rawStyleObject: "RegularAutomatic", isDark: false) == "defaultStyle-light")
        #expect(TileIconRasterCache.appearanceToken(rawStyleObject: "RegularAutomatic", isDark: true) == "dark-dark")
        // A present-but-unreadable value is the documented "don't act" case: keep the fallback.
        #expect(TileIconRasterCache.appearanceToken(rawStyleObject: 42, isDark: false) == "defaultStyle-light")

        // End-to-end through the real cache: ONE process, two popover opens, the preference changed
        // in between. The second open must rasterise again rather than serve the old appearance.
        var storedPreference: Any? = nil
        let cache = TileIconRasterCache { _, _ in self.onePixel() }
        func openPopover() {
            _ = cache.image(for: app, pointSize: 56, scale: 2,
                            appearanceToken: TileIconRasterCache.appearanceToken(
                                rawStyleObject: storedPreference, isDark: false),
                            contentStamp: 100)
        }
        openPopover()
        openPopover()
        #expect(cache.rasteriseCount == 1)   // nothing changed — the cache is doing its job
        storedPreference = "TintedAutomatic" // System Settings → Icon and widget style → Tinted
        openPopover()
        #expect(cache.rasteriseCount == 2)   // the new appearance was rasterised, not served stale
    }

    @Test("A missing path stamps as zero")
    func missingPathStamp() {
        #expect(AppIconLoader.modificationStamp(atPath: nil) == 0)
        #expect(AppIconLoader.modificationStamp(atPath: "/nonexistent/\(UUID().uuidString).app") == 0)
    }
}
