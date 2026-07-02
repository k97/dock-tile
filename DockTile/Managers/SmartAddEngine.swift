//
//  SmartAddEngine.swift
//  DockTile
//
//  On-device "Smart Add" suggestion engine. Builds ready-made tile suggestions by clustering the
//  user's recent app usage — entirely on this Mac. There is NO Siri, no network, and no public
//  Apple API for app-usage frequency, so Dock Tile assembles its own signal from three sources:
//
//    1. Launch/activation history — observed via `NSWorkspace.shared.notificationCenter` and
//       persisted as a rolling JSON log beside the config file (same prefs-dir pattern).
//    2. Spotlight metadata — `kMDItemUseCount` / `kMDItemLastUsedDate` via `NSMetadataQuery`.
//    3. Category — `LSApplicationCategoryType` from each app bundle's Info.plist.
//
//  All computation stays on device and never leaves it — this is INDEPENDENT of the analytics
//  consent toggle (Smart Add data is not analytics; it is never transmitted).
//
//  The regression-prone decisions (grouping, scoring, de-dup, category→identity mapping) are
//  extracted into pure `nonisolated static` seams so they are unit-testable without touching
//  NSWorkspace / Spotlight / FileManager (mirrors the `resolveDockVisibility` convention).
//
//  Swift 6 - Strict Concurrency
//

import AppKit
import Foundation

// MARK: - Public suggestion model

/// A ready-made tile the engine proposes on the Smart Add sheet. Purely a value type describing
/// what a tile *would* be — nothing is persisted or docked until the user picks it.
struct TileSuggestion: Identifiable {
    let id = UUID()
    /// Seed tile name (e.g. "Browse"). Re-uniquified against existing tiles at creation time.
    let name: String
    /// How this group was formed — drives the reason chip and the prominent/tinted styling.
    let strategy: Strategy
    /// Localized reason chip text ("By category" / "Most used this week" / "Opened together").
    let reason: String
    /// Tile background tint, from the group's dominant category identity.
    let tint: TintColor
    /// White SF Symbol drawn on the tile face, from the category identity.
    let symbol: String
    /// The apps this tile would contain (best-scored first). Icons resolve live via `AppIconLoader`.
    let appItems: [AppItem]

    enum Strategy: String {
        case category    // grouped by LSApplicationCategoryType
        case coLaunch    // apps repeatedly opened in the same session
        case recency     // the single most-used cluster this week (the top pick)

        var reason: String {
            switch self {
            case .category: return AppStrings.SmartAdd.reasonByCategory
            case .coLaunch: return AppStrings.SmartAdd.reasonOpenedTogether
            case .recency:  return AppStrings.SmartAdd.reasonMostUsed
            }
        }
    }
}

// MARK: - Category → tile identity

/// The categories Smart Add clusters around, and the tile identity each one maps to
/// (name / symbol / tint) per the design handoff. Pure — unit-tested.
enum SmartAddCategory: String, CaseIterable {
    case browsers
    case video
    case developerTools
    case social
    case productivity

    /// Map an `LSApplicationCategoryType` string to one of our clusters. `nil` for anything we
    /// don't group on (the app is still a valid Dock target, just not a cluster seed).
    init?(lsCategory: String?) {
        switch lsCategory {
        case "public.app-category.web-browsers":
            self = .browsers
        case "public.app-category.video", "public.app-category.entertainment":
            self = .video
        case "public.app-category.developer-tools":
            self = .developerTools
        case "public.app-category.social-networking":
            self = .social
        case "public.app-category.productivity", "public.app-category.business":
            self = .productivity
        default:
            return nil
        }
    }

    struct Identity: Equatable {
        let name: String
        let symbol: String
        let tint: TintColor
    }

    /// The tile identity for this category. Indigo has no preset, so it uses the system-indigo hex.
    var identity: Identity {
        switch self {
        case .browsers:
            return Identity(name: "Browse", symbol: "globe", tint: .blue)
        case .video:
            return Identity(name: "Watch", symbol: "play.fill", tint: .pink)
        case .developerTools:
            return Identity(name: "Ship",
                            symbol: "chevron.left.forwardslash.chevron.right",
                            tint: .custom("#5E5CE6"))
        case .social:
            return Identity(name: "Chat", symbol: "bubble.left.and.bubble.right", tint: .green)
        case .productivity:
            return Identity(name: "Work", symbol: "folder", tint: .blue)
        }
    }
}

// MARK: - Pure usage record

/// One installed app's usage signal, merged from Spotlight + the launch log. Pure value type so the
/// ranking seam can be tested with hand-built fixtures (no NSWorkspace / Spotlight needed).
struct AppUsageRecord: Equatable {
    let bundleId: String
    let name: String
    /// On-disk `.app` path — the durable identity (browser PWAs share bundle IDs; see `AppItem`).
    let path: String
    let lsCategory: String?
    let useCount: Int
    let lastUsed: Date?
}

// MARK: - Engine

@MainActor
final class SmartAddEngine: ObservableObject {
    static let shared = SmartAddEngine()

    // MARK: Launch log

    /// One observed app launch/activation. Persisted to disk as a rolling log.
    private struct LaunchEvent: Codable {
        let bundleId: String
        let date: Date
    }

    /// In-memory rolling launch log (most-recent-last). Capped on write.
    private var launchLog: [LaunchEvent] = []

    /// Keep the log bounded — enough history for co-launch/recency signal without unbounded growth.
    private static let maxLogEntries = 800
    private static let logRetention: TimeInterval = 60 * 24 * 60 * 60  // 60 days

    /// Rolling launch log lives beside the config JSON in ~/Library/Preferences (dev/release split
    /// via the environment-specific name), mirroring `ConfigurationManager` storage.
    private static var logURL: URL {
        let dir = AppEnvironment.preferencesURL.deletingLastPathComponent()
        let name = AppEnvironment.isDev ? "com.docktile.dev.smartadd.json"
                                        : "com.docktile.smartadd.json"
        return dir.appendingPathComponent(name)
    }

    // MARK: Spotlight cache

    /// Cached per-app usage harvested by the Spotlight query. Keyed by on-disk path. Refreshed on
    /// `warmUp()` so `computeSuggestions()` stays cheap and synchronous.
    private var spotlightApps: [AppUsageRecord] = []

    private let spotlightQuery = NSMetadataQuery()
    private var spotlightObserver: NSObjectProtocol?

    private var isObserving = false

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private init() {
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    // MARK: - Lifecycle

    /// Begin observing launch/activation notifications and warm the Spotlight cache. Main-app only —
    /// helper processes must not build usage state (they only render popovers). Idempotent.
    func startObserving() {
        guard !AppEnvironment.isHelper, !isObserving else { return }
        isObserving = true

        loadLog()

        let center = NSWorkspace.shared.notificationCenter
        center.addObserver(self, selector: #selector(appDidLaunch(_:)),
                           name: NSWorkspace.didLaunchApplicationNotification, object: nil)
        center.addObserver(self, selector: #selector(appDidActivate(_:)),
                           name: NSWorkspace.didActivateApplicationNotification, object: nil)

        warmUp()
    }

    /// Kick off (or refresh) the Spotlight usage query. Cheap to call on window-appear; results land
    /// asynchronously into `spotlightApps` so the next `computeSuggestions()` reflects them.
    func warmUp() {
        guard !AppEnvironment.isHelper else { return }
        startSpotlightQuery()
    }

    // MARK: - Notification handlers

    @objc private func appDidLaunch(_ note: Notification) {
        recordLaunch(from: note)
    }

    @objc private func appDidActivate(_ note: Notification) {
        recordLaunch(from: note)
    }

    private func recordLaunch(from note: Notification) {
        guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              let bundleId = app.bundleIdentifier,
              // Ignore our own main app + helper bundles so tiles don't suggest Dock Tile itself.
              !bundleId.hasPrefix("com.docktile") else { return }

        launchLog.append(LaunchEvent(bundleId: bundleId, date: Date()))
        pruneLog()
        saveLog()
    }

    // MARK: - Suggestions

    /// Produce up to `limit` ready-made tile suggestions from on-device usage. Excludes apps already
    /// covered by existing tiles, requires ≥3 apps per group, scores by recency × frequency, de-dups
    /// overlapping groups, and returns best-first. Cheap & synchronous (reads cached signals only).
    func computeSuggestions(existing: [DockTileConfiguration], limit: Int = 3) -> [TileSuggestion] {
        let records = mergedUsageRecords()

        // Exclude everything already docked/configured — by path (durable) and bundle id.
        var excludedPaths = Set<String>()
        var excludedBundleIds = Set<String>()
        for config in existing {
            for item in config.appItems where !item.isFolder {
                if let path = item.lastKnownPath { excludedPaths.insert(path) }
                excludedBundleIds.insert(item.bundleIdentifier)
            }
        }

        let clusters = Self.coLaunchClusters(log: launchLog.map { ($0.bundleId, $0.date) })

        let ranked = Self.rankGroups(
            apps: records,
            coLaunch: clusters,
            excludedBundleIds: excludedBundleIds,
            excludedPaths: excludedPaths,
            now: Date(),
            limit: limit
        )

        return ranked.map { group in
            let identity = group.category.identity
            let appItems = group.records.map { record in
                AppItem(bundleIdentifier: record.bundleId,
                        name: record.name,
                        lastKnownPath: record.path)
            }
            return TileSuggestion(
                name: identity.name,
                strategy: group.strategy,
                reason: group.strategy.reason,
                tint: identity.tint,
                symbol: identity.symbol,
                appItems: appItems
            )
        }
    }

    /// Merge Spotlight usage with launch-log frequency/recency into one candidate list.
    private func mergedUsageRecords() -> [AppUsageRecord] {
        // Launch-log tallies: count + most recent date per bundle id.
        var logCount: [String: Int] = [:]
        var logLast: [String: Date] = [:]
        for event in launchLog {
            logCount[event.bundleId, default: 0] += 1
            if let existing = logLast[event.bundleId] {
                logLast[event.bundleId] = max(existing, event.date)
            } else {
                logLast[event.bundleId] = event.date
            }
        }

        return spotlightApps.map { record in
            let extraCount = logCount[record.bundleId] ?? 0
            let mergedLast: Date?
            switch (record.lastUsed, logLast[record.bundleId]) {
            case let (a?, b?): mergedLast = max(a, b)
            case let (a?, nil): mergedLast = a
            case let (nil, b?): mergedLast = b
            default: mergedLast = nil
            }
            return AppUsageRecord(
                bundleId: record.bundleId,
                name: record.name,
                path: record.path,
                lsCategory: record.lsCategory,
                useCount: record.useCount + extraCount,
                lastUsed: mergedLast
            )
        }
    }

    // MARK: - Pure ranking seam

    /// A cluster of apps that would become one suggested tile. Pure data.
    struct RankedGroup: Equatable {
        let category: SmartAddCategory
        let strategy: TileSuggestion.Strategy
        let records: [AppUsageRecord]  // best-scored first
        let score: Double
    }

    /// Cap on apps seeded into a single suggested tile (keeps the tile focused; the icon row shows
    /// the first few and a "+N"). `nonisolated` so the pure ranking seam can read it.
    nonisolated static let maxAppsPerGroup = 6

    /// Score one app by recency × frequency. Recent + frequent ranks highest; a never-dated app gets
    /// a small floor so launch-log-only apps still participate. Pure.
    nonisolated static func score(for record: AppUsageRecord, now: Date) -> Double {
        let frequency = Double(max(record.useCount, 0)) + 1.0  // +1 so recency alone still scores
        let recency: Double
        if let last = record.lastUsed {
            let days = max(0, now.timeIntervalSince(last) / 86_400)
            recency = 1.0 / (1.0 + days / 7.0)   // 1.0 today → 0.5 at one week → decays
        } else {
            recency = 0.2
        }
        return frequency * recency
    }

    /// The heart of Smart Add: turn scored usage records into ranked, de-duplicated tile groups.
    ///
    /// - Groups installed candidates by category (each with ≥3 members) and adds any cross-category
    ///   co-launch clusters.
    /// - Scores every group (sum of member scores) and sorts best-first.
    /// - Greedily de-dups so no app appears in two suggestions; a later group survives only if it
    ///   still has ≥3 unused apps.
    /// - Relabels the single best group `.recency` ("Most used this week") — the prominent top pick.
    ///
    /// Pure & `nonisolated` so it is unit-testable without any I/O.
    nonisolated static func rankGroups(
        apps: [AppUsageRecord],
        coLaunch: [[String]],
        excludedBundleIds: Set<String>,
        excludedPaths: Set<String>,
        now: Date,
        limit: Int
    ) -> [RankedGroup] {
        guard limit > 0 else { return [] }

        let available = apps.filter {
            !excludedBundleIds.contains($0.bundleId) && !excludedPaths.contains($0.path)
        }
        guard !available.isEmpty else { return [] }

        let scores = Dictionary(available.map { ($0.bundleId, score(for: $0, now: now)) },
                                uniquingKeysWith: { a, _ in a })
        let byId = Dictionary(available.map { ($0.bundleId, $0) }, uniquingKeysWith: { a, _ in a })

        func order(_ records: [AppUsageRecord]) -> [AppUsageRecord] {
            records.sorted { lhs, rhs in
                let l = scores[lhs.bundleId] ?? 0
                let r = scores[rhs.bundleId] ?? 0
                return l != r ? l > r : lhs.bundleId < rhs.bundleId  // stable tie-break
            }
        }
        func total(_ records: [AppUsageRecord]) -> Double {
            records.reduce(0) { $0 + (scores[$1.bundleId] ?? 0) }
        }

        var candidates: [RankedGroup] = []

        // Category clusters.
        let grouped = Dictionary(grouping: available) { SmartAddCategory(lsCategory: $0.lsCategory) }
        for (category, members) in grouped {
            guard let category, members.count >= 3 else { continue }
            let ordered = order(members)
            candidates.append(RankedGroup(category: category, strategy: .category,
                                          records: ordered, score: total(ordered)))
        }

        // Co-launch clusters (cross-category). Small boost — deliberate pairing beats mere category.
        for cluster in coLaunch {
            let members = cluster.compactMap { byId[$0] }
            guard members.count >= 3 else { continue }
            let ordered = order(members)
            candidates.append(RankedGroup(category: dominantCategory(ordered), strategy: .coLaunch,
                                          records: ordered, score: total(ordered) * 1.05))
        }

        // Best-first; deterministic tie-break by identity name.
        candidates.sort { lhs, rhs in
            lhs.score != rhs.score ? lhs.score > rhs.score
                                   : lhs.category.identity.name < rhs.category.identity.name
        }

        // Greedy de-dup: no app in two suggestions; the top surviving group becomes the recency pick.
        var used = Set<String>()
        var result: [RankedGroup] = []
        for group in candidates {
            let fresh = Array(group.records.filter { !used.contains($0.bundleId) }.prefix(maxAppsPerGroup))
            guard fresh.count >= 3 else { continue }
            let strategy: TileSuggestion.Strategy = result.isEmpty ? .recency : group.strategy
            result.append(RankedGroup(category: group.category, strategy: strategy,
                                      records: fresh, score: group.score))
            fresh.forEach { used.insert($0.bundleId) }
            if result.count >= limit { break }
        }
        return result
    }

    /// The category most members share, falling back to `.productivity` when a cluster spans
    /// categories or carries no category signal. Pure.
    nonisolated static func dominantCategory(_ records: [AppUsageRecord]) -> SmartAddCategory {
        var tally: [SmartAddCategory: Int] = [:]
        for record in records {
            if let category = SmartAddCategory(lsCategory: record.lsCategory) {
                tally[category, default: 0] += 1
            }
        }
        return tally.max { lhs, rhs in
            lhs.value != rhs.value ? lhs.value < rhs.value
                                   : lhs.key.identity.name > rhs.key.identity.name  // stable
        }?.key ?? .productivity
    }

    /// Detect apps repeatedly opened in the same session. Sessionizes the launch log on a time gap,
    /// counts pairwise co-occurrence, and returns connected components (≥3 apps) of app pairs that
    /// co-occurred in ≥`minSessions` sessions. Pure.
    nonisolated static func coLaunchClusters(
        log: [(bundleId: String, date: Date)],
        windowSeconds: TimeInterval = 30 * 60,
        minSessions: Int = 2
    ) -> [[String]] {
        guard !log.isEmpty else { return [] }

        // Build sessions: a gap longer than the window starts a new session.
        let sorted = log.sorted { $0.date < $1.date }
        var sessions: [Set<String>] = []
        var current: Set<String> = []
        var lastDate: Date?
        for event in sorted {
            if let last = lastDate, event.date.timeIntervalSince(last) > windowSeconds {
                if current.count >= 2 { sessions.append(current) }
                current = []
            }
            current.insert(event.bundleId)
            lastDate = event.date
        }
        if current.count >= 2 { sessions.append(current) }

        // Count unordered-pair co-occurrence across sessions.
        var pairCount: [String: Int] = [:]
        for session in sessions {
            let ids = session.sorted()
            for i in 0..<ids.count {
                for j in (i + 1)..<ids.count {
                    pairCount["\(ids[i])|\(ids[j])", default: 0] += 1
                }
            }
        }

        // Build adjacency from strong pairs, then extract connected components.
        var adjacency: [String: Set<String>] = [:]
        for (key, count) in pairCount where count >= minSessions {
            let parts = key.split(separator: "|", maxSplits: 1).map(String.init)
            guard parts.count == 2 else { continue }
            adjacency[parts[0], default: []].insert(parts[1])
            adjacency[parts[1], default: []].insert(parts[0])
        }

        var visited = Set<String>()
        var clusters: [[String]] = []
        for node in adjacency.keys.sorted() where !visited.contains(node) {
            var component: [String] = []
            var stack = [node]
            while let current = stack.popLast() {
                guard !visited.contains(current) else { continue }
                visited.insert(current)
                component.append(current)
                for neighbour in (adjacency[current] ?? []).sorted() where !visited.contains(neighbour) {
                    stack.append(neighbour)
                }
            }
            if component.count >= 3 { clusters.append(component.sorted()) }
        }
        return clusters
    }

    // MARK: - Spotlight

    private func startSpotlightQuery() {
        if spotlightQuery.isStarted {
            spotlightQuery.stop()
        }
        if spotlightObserver == nil {
            spotlightObserver = NotificationCenter.default.addObserver(
                forName: .NSMetadataQueryDidFinishGathering,
                object: spotlightQuery,
                queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.harvestSpotlightResults()
                }
            }
        }

        spotlightQuery.searchScopes = [
            "/Applications",
            "/System/Applications",
            "\(NSHomeDirectory())/Applications"
        ]
        spotlightQuery.predicate = NSPredicate(
            format: "kMDItemContentTypeTree == 'com.apple.application-bundle'"
        )
        spotlightQuery.start()
    }

    private func harvestSpotlightResults() {
        spotlightQuery.disableUpdates()
        defer { spotlightQuery.enableUpdates() }

        var records: [AppUsageRecord] = []
        for index in 0..<spotlightQuery.resultCount {
            guard let item = spotlightQuery.result(at: index) as? NSMetadataItem,
                  let path = item.value(forAttribute: NSMetadataItemPathKey) as? String,
                  // Skip our own bundles.
                  !path.contains("Dock Tile"), !path.contains("DockTile") else { continue }

            // Spotlight attribute names as string literals (avoids importing the Metadata framework
            // just for the `kMDItem…` CFString constants).
            let useCount = (item.value(forAttribute: "kMDItemUseCount") as? Int) ?? 0
            let lastUsed = item.value(forAttribute: "kMDItemLastUsedDate") as? Date

            guard let (bundleId, name, category) = bundleInfo(atPath: path),
                  !bundleId.hasPrefix("com.docktile") else { continue }

            records.append(AppUsageRecord(
                bundleId: bundleId,
                name: name,
                path: path,
                lsCategory: category,
                useCount: useCount,
                lastUsed: lastUsed
            ))
        }
        spotlightApps = records
    }

    /// Read (bundleId, display name, LSApplicationCategoryType) from an app bundle's Info.plist.
    private func bundleInfo(atPath path: String) -> (String, String, String?)? {
        guard let bundle = Bundle(path: path), let bundleId = bundle.bundleIdentifier else {
            return nil
        }
        let name = (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
            ?? (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String)
            ?? URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent
        let category = bundle.object(forInfoDictionaryKey: "LSApplicationCategoryType") as? String
        return (bundleId, name, category)
    }

    // MARK: - Launch-log persistence

    private func loadLog() {
        guard let data = try? Data(contentsOf: Self.logURL) else { return }
        launchLog = (try? decoder.decode([LaunchEvent].self, from: data)) ?? []
        pruneLog()
    }

    private func saveLog() {
        guard let data = try? encoder.encode(launchLog) else { return }
        try? data.write(to: Self.logURL, options: [.atomic])
    }

    /// Drop events older than the retention window, then cap the total count (keeping newest).
    private func pruneLog() {
        let cutoff = Date().addingTimeInterval(-Self.logRetention)
        launchLog.removeAll { $0.date < cutoff }
        if launchLog.count > Self.maxLogEntries {
            launchLog.removeFirst(launchLog.count - Self.maxLogEntries)
        }
    }
}
