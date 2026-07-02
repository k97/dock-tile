import Testing
import Foundation
@testable import Dock_Tile

// MARK: - Smart Add Engine Tests
//
// Exercises the PURE ranking/grouping/mapping seams of SmartAddEngine — no NSWorkspace, Spotlight,
// or FileManager. Mirrors the regression-guard convention (like `resolveDockVisibility`): the
// regression-prone decisions live in `nonisolated static` functions taking plain values.

@Suite("Smart Add Engine — category identity")
struct SmartAddCategoryTests {

    @Test("LSApplicationCategoryType strings map to the expected clusters")
    func categoryMapping() {
        #expect(SmartAddCategory(lsCategory: "public.app-category.web-browsers") == .browsers)
        #expect(SmartAddCategory(lsCategory: "public.app-category.video") == .video)
        #expect(SmartAddCategory(lsCategory: "public.app-category.entertainment") == .video)
        #expect(SmartAddCategory(lsCategory: "public.app-category.developer-tools") == .developerTools)
        #expect(SmartAddCategory(lsCategory: "public.app-category.social-networking") == .social)
        #expect(SmartAddCategory(lsCategory: "public.app-category.productivity") == .productivity)
        #expect(SmartAddCategory(lsCategory: "public.app-category.business") == .productivity)
    }

    @Test("Unknown / nil categories do not map to a cluster")
    func unmappedCategories() {
        #expect(SmartAddCategory(lsCategory: nil) == nil)
        #expect(SmartAddCategory(lsCategory: "public.app-category.games") == nil)
        #expect(SmartAddCategory(lsCategory: "") == nil)
    }

    @Test("Each cluster maps to the design-handoff tile identity (name / symbol / tint)")
    func categoryIdentity() {
        #expect(SmartAddCategory.browsers.identity.name == "Browse")
        #expect(SmartAddCategory.browsers.identity.symbol == "globe")
        #expect(SmartAddCategory.browsers.identity.tint == .blue)

        #expect(SmartAddCategory.video.identity.name == "Watch")
        #expect(SmartAddCategory.video.identity.symbol == "play.fill")
        #expect(SmartAddCategory.video.identity.tint == .pink)

        #expect(SmartAddCategory.developerTools.identity.name == "Ship")
        #expect(SmartAddCategory.developerTools.identity.symbol == "chevron.left.forwardslash.chevron.right")
        #expect(SmartAddCategory.developerTools.identity.tint == .custom("#5E5CE6"))

        #expect(SmartAddCategory.social.identity.name == "Chat")
        #expect(SmartAddCategory.social.identity.symbol == "bubble.left.and.bubble.right")
        #expect(SmartAddCategory.social.identity.tint == .green)

        #expect(SmartAddCategory.productivity.identity.name == "Work")
        #expect(SmartAddCategory.productivity.identity.symbol == "folder")
        #expect(SmartAddCategory.productivity.identity.tint == .blue)
    }
}

@Suite("Smart Add Engine — ranking")
struct SmartAddRankingTests {

    /// Fixed reference "now" (no `Date.now` — deterministic scores).
    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    /// Build a record `daysAgo` days before `now`.
    private func app(_ id: String, category: String?, uses: Int, daysAgo: Double) -> AppUsageRecord {
        AppUsageRecord(
            bundleId: id,
            name: id,
            path: "/Applications/\(id).app",
            lsCategory: category,
            useCount: uses,
            lastUsed: now.addingTimeInterval(-daysAgo * 86_400)
        )
    }

    private let browsers = "public.app-category.web-browsers"
    private let video = "public.app-category.video"
    private let devtools = "public.app-category.developer-tools"

    @Test("Empty history yields no suggestions")
    func emptyHistory() {
        let result = SmartAddEngine.rankGroups(
            apps: [], coLaunch: [], excludedBundleIds: [], excludedPaths: [], now: now, limit: 3
        )
        #expect(result.isEmpty)
    }

    @Test("A category needs at least three apps to form a group")
    func requiresThreeApps() {
        let apps = [
            app("b1", category: browsers, uses: 10, daysAgo: 1),
            app("b2", category: browsers, uses: 10, daysAgo: 1)
        ]
        let result = SmartAddEngine.rankGroups(
            apps: apps, coLaunch: [], excludedBundleIds: [], excludedPaths: [], now: now, limit: 3
        )
        #expect(result.isEmpty)
    }

    @Test("A three-app category forms exactly one group with the right identity")
    func singleCategoryGroup() {
        let apps = [
            app("b1", category: browsers, uses: 10, daysAgo: 1),
            app("b2", category: browsers, uses: 8, daysAgo: 2),
            app("b3", category: browsers, uses: 6, daysAgo: 3)
        ]
        let result = SmartAddEngine.rankGroups(
            apps: apps, coLaunch: [], excludedBundleIds: [], excludedPaths: [], now: now, limit: 3
        )
        #expect(result.count == 1)
        let group = try! #require(result.first)
        #expect(group.category == .browsers)
        #expect(group.records.count == 3)
        // Ordered best-first: b1 (10 uses, 1 day) leads.
        #expect(group.records.first?.bundleId == "b1")
    }

    @Test("Apps already in existing tiles are excluded — dropping a group below three drops it")
    func excludesAppsInExistingTiles() {
        let apps = [
            app("b1", category: browsers, uses: 10, daysAgo: 1),
            app("b2", category: browsers, uses: 8, daysAgo: 2),
            app("b3", category: browsers, uses: 6, daysAgo: 3)
        ]
        // Exclude one by path → only two remain → no group.
        let result = SmartAddEngine.rankGroups(
            apps: apps, coLaunch: [],
            excludedBundleIds: [], excludedPaths: ["/Applications/b3.app"],
            now: now, limit: 3
        )
        #expect(result.isEmpty)
    }

    @Test("Exclusion by bundle id also removes the app from candidates")
    func excludesByBundleId() {
        let apps = [
            app("b1", category: browsers, uses: 10, daysAgo: 1),
            app("b2", category: browsers, uses: 8, daysAgo: 2),
            app("b3", category: browsers, uses: 6, daysAgo: 3),
            app("b4", category: browsers, uses: 4, daysAgo: 4)
        ]
        let result = SmartAddEngine.rankGroups(
            apps: apps, coLaunch: [],
            excludedBundleIds: ["b1"], excludedPaths: [], now: now, limit: 3
        )
        let group = try! #require(result.first)
        #expect(group.records.count == 3)
        #expect(!group.records.contains { $0.bundleId == "b1" })
    }

    @Test("Higher-scored group ranks first and is relabeled Most Used (recency)")
    func scoringOrderAndTopPick() {
        // Video: very recent + frequent → highest score. Browsers: older/rarer.
        let apps = [
            app("v1", category: video, uses: 50, daysAgo: 0),
            app("v2", category: video, uses: 40, daysAgo: 1),
            app("v3", category: video, uses: 30, daysAgo: 1),
            app("b1", category: browsers, uses: 3, daysAgo: 20),
            app("b2", category: browsers, uses: 2, daysAgo: 25),
            app("b3", category: browsers, uses: 1, daysAgo: 30)
        ]
        let result = SmartAddEngine.rankGroups(
            apps: apps, coLaunch: [], excludedBundleIds: [], excludedPaths: [], now: now, limit: 3
        )
        #expect(result.count == 2)
        // Best-first: video leads.
        #expect(result[0].category == .video)
        #expect(result[1].category == .browsers)
        // The top surviving group is surfaced as the "Most used this week" pick.
        #expect(result[0].strategy == .recency)
        // Lower groups keep their formation strategy.
        #expect(result[1].strategy == .category)
        // Scores strictly decrease.
        #expect(result[0].score > result[1].score)
    }

    @Test("De-dup: no app appears in two suggestions; a co-launch group cannibalised below three is dropped")
    func greedyDeDuplication() {
        // One strong video category group; a co-launch cluster reusing two of its apps + one other.
        let apps = [
            app("v1", category: video, uses: 50, daysAgo: 0),
            app("v2", category: video, uses: 40, daysAgo: 0),
            app("v3", category: video, uses: 30, daysAgo: 0),
            app("x1", category: nil, uses: 5, daysAgo: 2)
        ]
        // Co-launch cluster shares v1,v2 with the category group + x1. After the category group
        // claims v1,v2,v3, only x1 is fresh → below three → dropped.
        let result = SmartAddEngine.rankGroups(
            apps: apps, coLaunch: [["v1", "v2", "x1"]],
            excludedBundleIds: [], excludedPaths: [], now: now, limit: 3
        )
        #expect(result.count == 1)
        #expect(result[0].category == .video)
        // Every returned app is unique across suggestions.
        let allIds = result.flatMap { $0.records.map(\.bundleId) }
        #expect(Set(allIds).count == allIds.count)
    }

    @Test("limit caps the number of suggestions returned")
    func respectsLimit() {
        let apps = [
            app("v1", category: video, uses: 9, daysAgo: 0),
            app("v2", category: video, uses: 9, daysAgo: 0),
            app("v3", category: video, uses: 9, daysAgo: 0),
            app("b1", category: browsers, uses: 9, daysAgo: 0),
            app("b2", category: browsers, uses: 9, daysAgo: 0),
            app("b3", category: browsers, uses: 9, daysAgo: 0),
            app("d1", category: devtools, uses: 9, daysAgo: 0),
            app("d2", category: devtools, uses: 9, daysAgo: 0),
            app("d3", category: devtools, uses: 9, daysAgo: 0)
        ]
        let result = SmartAddEngine.rankGroups(
            apps: apps, coLaunch: [], excludedBundleIds: [], excludedPaths: [], now: now, limit: 2
        )
        #expect(result.count == 2)
    }

    @Test("A single group is capped at maxAppsPerGroup apps")
    func capsAppsPerGroup() {
        let apps = (1...10).map { app("v\($0)", category: video, uses: 20 - $0, daysAgo: 0) }
        let result = SmartAddEngine.rankGroups(
            apps: apps, coLaunch: [], excludedBundleIds: [], excludedPaths: [], now: now, limit: 3
        )
        let group = try! #require(result.first)
        #expect(group.records.count == SmartAddEngine.maxAppsPerGroup)
    }
}

@Suite("Smart Add Engine — scoring & co-launch")
struct SmartAddScoringTests {

    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    @Test("Recent + frequent scores strictly higher than old + rare")
    func scoreOrdering() {
        let hot = AppUsageRecord(bundleId: "hot", name: "hot", path: "/a", lsCategory: nil,
                                 useCount: 100, lastUsed: now)
        let cold = AppUsageRecord(bundleId: "cold", name: "cold", path: "/b", lsCategory: nil,
                                  useCount: 1, lastUsed: now.addingTimeInterval(-60 * 86_400))
        #expect(SmartAddEngine.score(for: hot, now: now) > SmartAddEngine.score(for: cold, now: now))
    }

    @Test("A never-dated app still gets a positive floor score")
    func undatedFloor() {
        let record = AppUsageRecord(bundleId: "x", name: "x", path: "/x", lsCategory: nil,
                                    useCount: 0, lastUsed: nil)
        #expect(SmartAddEngine.score(for: record, now: now) > 0)
    }

    @Test("Recency decays: same frequency, older last-used scores lower")
    func recencyDecay() {
        let recent = AppUsageRecord(bundleId: "r", name: "r", path: "/r", lsCategory: nil,
                                    useCount: 10, lastUsed: now)
        let stale = AppUsageRecord(bundleId: "s", name: "s", path: "/s", lsCategory: nil,
                                   useCount: 10, lastUsed: now.addingTimeInterval(-14 * 86_400))
        #expect(SmartAddEngine.score(for: recent, now: now) > SmartAddEngine.score(for: stale, now: now))
    }

    @Test("Co-launch clusters surface apps repeatedly opened in the same session")
    func coLaunchClustering() {
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        // Two sessions, a day apart, each opening the same three apps within minutes.
        var log: [(bundleId: String, date: Date)] = []
        for session in 0..<2 {
            let start = base.addingTimeInterval(Double(session) * 86_400)
            log.append(("com.a", start))
            log.append(("com.b", start.addingTimeInterval(60)))
            log.append(("com.c", start.addingTimeInterval(120)))
        }
        let clusters = SmartAddEngine.coLaunchClusters(log: log)
        #expect(clusters.count == 1)
        #expect(Set(clusters[0]) == ["com.a", "com.b", "com.c"])
    }

    @Test("Apps only ever opened in separate sessions do not form a co-launch cluster")
    func noCoLaunchAcrossSessions() {
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        // Each app opened alone, hours apart → distinct single-app sessions → no pairs.
        let log: [(bundleId: String, date: Date)] = [
            ("com.a", base),
            ("com.b", base.addingTimeInterval(3 * 3600)),
            ("com.c", base.addingTimeInterval(6 * 3600))
        ]
        #expect(SmartAddEngine.coLaunchClusters(log: log).isEmpty)
    }

    @Test("An empty launch log has no co-launch clusters")
    func emptyLogNoClusters() {
        #expect(SmartAddEngine.coLaunchClusters(log: []).isEmpty)
    }
}

// MARK: - createConfiguration(from:)

/// Serialized — touches a real `ConfigurationManager` (shared prefs file). Each test cleans up the
/// tile it creates so it doesn't leak into the developer's/CI's config.
@Suite("Smart Add — createConfiguration(from:)", .serialized)
@MainActor
struct SmartAddCreateConfigurationTests {

    private func suggestion() -> TileSuggestion {
        TileSuggestion(
            name: "Browse",
            strategy: .category,
            reason: "By category",
            tint: .blue,
            symbol: "globe",
            appItems: [
                AppItem(bundleIdentifier: "com.apple.Safari", name: "Safari", lastKnownPath: "/Applications/Safari.app"),
                AppItem(bundleIdentifier: "com.google.Chrome", name: "Chrome"),
                AppItem(bundleIdentifier: "org.mozilla.firefox", name: "Firefox")
            ]
        )
    }

    @Test("Seeds name, tint, symbol and apps; Show Tile reads on but nothing is docked yet")
    func seedsFieldsAndShowsTile() {
        let manager = ConfigurationManager()
        let created = manager.createConfiguration(from: suggestion())
        defer { manager.deleteConfiguration(created.id) }

        // Name seeded from the suggestion (uniquified — may gain a numeric suffix).
        #expect(created.name.hasPrefix("Browse"))
        #expect(created.tintColor == .blue)
        #expect(created.iconType == .sfSymbol)
        #expect(created.iconValue == "globe")

        // Apps carried over verbatim, in order.
        #expect(created.appItems.count == 3)
        #expect(created.appItems.map(\.bundleIdentifier) == ["com.apple.Safari", "com.google.Chrome", "org.mozilla.firefox"])

        // Show Tile reads ON while reviewing (matches a blank new tile's default). This does NOT
        // pin anything — the user still confirms with Add to Dock — but the stored intent is visible.
        #expect(created.isVisibleInDock == true)

        // Selected and flagged for the provenance banner.
        #expect(manager.selectedConfigId == created.id)
        #expect(manager.smartAddProvenanceIDs.contains(created.id))
    }

    @Test("Dismissing provenance clears only that tile's banner flag")
    func clearProvenance() {
        let manager = ConfigurationManager()
        let created = manager.createConfiguration(from: suggestion())
        defer { manager.deleteConfiguration(created.id) }

        #expect(manager.smartAddProvenanceIDs.contains(created.id))
        manager.clearSmartAddProvenance(created.id)
        #expect(!manager.smartAddProvenanceIDs.contains(created.id))
    }
}
