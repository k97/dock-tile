//
//  AnalyticsService.swift
//  DockTile
//
//  The single choke point for Firebase Analytics + Crashlytics. No other file should
//  import Firebase directly — call through `AnalyticsService.shared` instead. This keeps
//  Firebase symbols isolated and lets us gate all collection behind one consent + build check.
//
//  Behaviour:
//   - Collection is ON only when this is a RELEASE build AND the user has not opted out.
//     Debug/Dev builds never send data (mirrors the dev/prod data-path separation).
//   - Consent lives in a SHARED UserDefaults suite so helper bundles (separate bundle IDs,
//     separate default domains) honour the same toggle as the main app.
//   - Runs in both the main app and every helper bundle (popover usage lives only in helpers),
//     distinguished by the `app_role` user property / Crashlytics key.
//
//  Swift 6 - Strict Concurrency
//

import Foundation
import FirebaseCore
import FirebaseAnalytics
import FirebaseCrashlytics

/// Firebase event names. Raw values must be Firebase-safe: snake_case, <= 40 chars,
/// and must not use a reserved prefix (`firebase_`, `google_`, `ga_`). These are log-like
/// identifiers and are intentionally NOT localized.
enum AnalyticsEvent: String, CaseIterable {
    case appLaunched = "app_launched"
    case tileCreated = "tile_created"
    case tileAddedToDock = "tile_added_to_dock"
    case tileUpdated = "tile_updated"
    case tileRemoved = "tile_removed"
    case tileShown = "tile_shown"
    case tileHidden = "tile_hidden"
    case iconStyleChanged = "icon_style_changed"
    case tintColorChanged = "tint_color_changed"
    case layoutModeChanged = "layout_mode_changed"
    case popoverOpened = "popover_opened"
    case appLaunchedFromTile = "app_launched_from_tile"
    case configureGearTapped = "configure_gear_tapped"
    case settingChanged = "setting_changed"
    case helperMigrationRun = "helper_migration_run"
    case dockLockMoveStarted = "dock_lock_move_started"
    case dockLockMoveSucceeded = "dock_lock_move_succeeded"
    case dockLockMoveFailed = "dock_lock_move_failed"
    case relocationPrompted = "relocation_prompted"
    case relocationMoveStarted = "relocation_move_started"
    case relocationMoveSucceeded = "relocation_move_succeeded"
    case relocationMoveFailed = "relocation_move_failed"
}

@MainActor
final class AnalyticsService {
    static let shared = AnalyticsService()

    /// Cross-process suite shared by the main app and all helpers.
    private let sharedDefaults = UserDefaults(suiteName: UserDefaultsKeys.sharedSuiteName)

    /// True once `FirebaseApp.configure()` has succeeded (i.e. a GoogleService-Info.plist was present).
    private(set) var isConfigured = false

    /// Whether data is actually being collected right now.
    private(set) var collectionEnabled = false

    private init() {}

    // MARK: - Consent

    /// Opt-out: defaults to ON when the key has never been set.
    var consentGranted: Bool {
        Self.resolveConsent(storedValue: sharedDefaults?.object(forKey: UserDefaultsKeys.analyticsEnabled) as? Bool)
    }

    /// Whether the build/environment is allowed to collect at all (Release only).
    private var environmentAllowsCollection: Bool { AppEnvironment.isRelease }

    // MARK: - Pure gating seams (regression-guarded)
    //
    // The two privacy-critical decisions — opt-out consent resolution and the Release-only AND
    // consent gate — are pure `nonisolated static` functions so they are unit-testable without
    // Firebase, UserDefaults, or the build environment (mirrors `resolveDockVisibility`).

    /// Resolve opt-out consent from the stored value. Absent (never set) → granted (ON by default).
    nonisolated static func resolveConsent(storedValue: Bool?) -> Bool {
        storedValue ?? true
    }

    /// Collection is allowed ONLY in a Release build AND with consent granted. Debug/Dev never send.
    nonisolated static func shouldCollect(isRelease: Bool, consentGranted: Bool) -> Bool {
        isRelease && consentGranted
    }

    // MARK: - Lifecycle

    /// Configure Firebase and apply the current collection state. Safe to call once per process
    /// launch from `main.swift` (both main and helper branches). No-ops gracefully if the
    /// GoogleService-Info.plist is not bundled (e.g. during early development).
    func configure() {
        guard FirebaseApp.app() == nil else { return } // already configured

        guard Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil else {
            print("ℹ️ Firebase not configured: GoogleService-Info.plist missing (analytics disabled).")
            return
        }

        FirebaseApp.configure()
        isConfigured = true

        // Baseline context for every event / crash report.
        Crashlytics.crashlytics().setCustomValue(AppEnvironment.appRole, forKey: "app_role")
        Crashlytics.crashlytics().setCustomValue(AppEnvironment.mainAppBundleId, forKey: "bundle_id")
        Crashlytics.crashlytics().setCustomValue(AppEnvironment.appVersion, forKey: "app_version")
        Crashlytics.crashlytics().setCustomValue(AppEnvironment.current, forKey: "environment")
        Analytics.setUserProperty(AppEnvironment.appRole, forName: "app_role")

        applyCollectionState()
    }

    /// Persist a new consent value and apply it live.
    func setConsent(_ enabled: Bool) {
        sharedDefaults?.set(enabled, forKey: UserDefaultsKeys.analyticsEnabled)
        applyCollectionState()
    }

    private func applyCollectionState() {
        let enabled = Self.shouldCollect(isRelease: environmentAllowsCollection, consentGranted: consentGranted)
        collectionEnabled = enabled
        guard isConfigured else { return }
        Analytics.setAnalyticsCollectionEnabled(enabled)
        Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(enabled)
        print("ℹ️ Analytics collection \(enabled ? "ENABLED" : "disabled") (role=\(AppEnvironment.appRole), env=\(AppEnvironment.current))")
    }

    // MARK: - Events

    /// Log an analytics event. Firebase itself no-ops when collection is disabled, so callers
    /// don't need to guard.
    func log(_ event: AnalyticsEvent, _ parameters: [String: Any] = [:]) {
        guard isConfigured else { return }
        Analytics.logEvent(event.rawValue, parameters: parameters.isEmpty ? nil : parameters)
    }

    // MARK: - Crashlytics

    /// Set a Crashlytics breadcrumb (custom key) — e.g. the current step of a multi-stage flow.
    func setBreadcrumb(_ value: String, for key: String) {
        guard isConfigured else { return }
        Crashlytics.crashlytics().setCustomValue(value, forKey: key)
    }

    /// Record a non-fatal error with optional custom keys. Always prints, preserving existing logging.
    ///
    /// The context + keys are attached via `record(error:userInfo:)` so they are scoped to THIS
    /// event. They must NOT go through `setCustomValue`, which mutates the global Crashlytics key
    /// set — under concurrent non-fatals those keys bleed across issues (and onto the next crash),
    /// misattributing debugging context.
    func record(_ error: Error, context: String, keys: [String: String] = [:]) {
        print("❌ [\(context)] \(error.localizedDescription)")
        guard isConfigured else { return }
        var userInfo: [String: Any] = keys
        userInfo["error_context"] = context
        Crashlytics.crashlytics().record(error: error, userInfo: userInfo)
    }
}
