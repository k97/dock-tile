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
import PostHog

/// Firebase event names. Raw values must be Firebase-safe: snake_case, <= 40 chars,
/// and must not use a reserved prefix (`firebase_`, `google_`, `ga_`). These are log-like
/// identifiers and are intentionally NOT localized.
enum AnalyticsEvent: String, CaseIterable {
    case appLaunched = "app_launched"
    case tileCreated = "tile_created"
    case tileAddedToDock = "tile_added_to_dock"
    case tileUpdated = "tile_updated"
    case tileRemoved = "tile_removed"
    case tileHidden = "tile_hidden"
    case tileReverted = "tile_reverted"
    case iconStyleChanged = "icon_style_changed"
    case popoverOpened = "popover_opened"
    case appLaunchedFromTile = "app_launched_from_tile"
    case popoverItemAction = "popover_item_action"
    case configureGearTapped = "configure_gear_tapped"
    case settingChanged = "setting_changed"
    case helperMigrationRun = "helper_migration_run"
    case helperSelfHeal = "helper_self_heal"
    case dockLockMoveStarted = "dock_lock_move_started"
    case dockLockMoveSucceeded = "dock_lock_move_succeeded"
    case dockLockMoveFailed = "dock_lock_move_failed"
    case relocationPrompted = "relocation_prompted"
    case relocationMoveStarted = "relocation_move_started"
    case relocationMoveSucceeded = "relocation_move_succeeded"
    case relocationMoveFailed = "relocation_move_failed"
    case translationInviteShown = "translation_invite_shown"
    case translationHelpTapped = "translation_help_tapped"
    case updateCheck = "update_check"
    case updateChoice = "update_choice"
    case updateInstalling = "update_installing"
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

    /// True once the shared PostHog client is configured for this process.
    private var isPostHogConfigured = false

    /// Helpers only: the `consentDidChange` observer, kept for the process's lifetime.
    private var consentObserver: NSObjectProtocol?

    private init() {}

    // MARK: - Consent

    /// Opt-out: defaults to ON when the key has never been set. Synchronize-first: another process
    /// (the main app) writes this key, and a cfprefsd cache split once made a cross-process read stale.
    var consentGranted: Bool {
        CFPreferencesAppSynchronize(UserDefaultsKeys.sharedSuiteName as CFString)
        return Self.resolveConsent(storedValue: sharedDefaults?.object(forKey: UserDefaultsKeys.analyticsEnabled) as? Bool)
    }

    /// Posted by the main app when the user changes consent, so running helpers re-apply it at once.
    /// Any local process can post it; the worst it does is make a helper re-read the real setting.
    nonisolated static let consentDidChange = Notification.Name("com.docktile.analyticsConsentChanged")

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

    /// Configure analytics clients once per process launch from `main.swift` (both main and helper
    /// branches). Firebase remains optional when its plist is not bundled.
    func configure() {
        configurePostHog()

        // Our own flag, not `FirebaseApp.app()`: asking Firebase before configure logs I-COR000003.
        guard !isConfigured else { return } // already configured

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

        // A helper applies consent at launch only; without this, one started at login kept
        // collecting after the user opted out, until it was rebuilt (2026-11-04 audit).
        if AppEnvironment.isHelper {
            consentObserver = DistributedNotificationCenter.default().addObserver(
                forName: Self.consentDidChange, object: nil, queue: .main
            ) { _ in
                MainActor.assumeIsolated {
                    AnalyticsService.shared.applyCollectionState()
                    DiagnosticsLog.shared.log("analytics", "consent re-applied (consent=\(AnalyticsService.shared.consentGranted))")
                }
            }
        }
    }

    /// No-ops when the build carries no token or host (every local/Debug build), like Firebase
    /// without its plist. Never trap here: `main.swift` calls this before anything else, so a
    /// trap killed the dev app, its helpers and the test host at launch.
    private func configurePostHog() {
        guard !isPostHogConfigured,
              let projectToken = Bundle.main.object(forInfoDictionaryKey: "PostHogProjectToken") as? String,
              !projectToken.isEmpty, !projectToken.hasPrefix("$("),
              let host = Bundle.main.object(forInfoDictionaryKey: "PostHogHost") as? String,
              !host.isEmpty, !host.hasPrefix("$(") else { return }

        let config = PostHogConfig(projectToken: projectToken, host: host)
        config.personProfiles = .never
        // Crashlytics owns crash reporting: two crash reporters both claim the same signal and
        // Mach exception handlers, and one can swallow the other's report.
        config.errorTrackingConfig.autoCapture = false
        // Only the allowlisted product events below; no Application Opened/Backgrounded per helper.
        config.captureApplicationLifecycleEvents = false
        // Start opted out unless consent holds: setup() runs before applyCollectionState().
        config.optOut = !Self.shouldCollect(isRelease: environmentAllowsCollection, consentGranted: consentGranted)
        config.getAnonymousId = Self.alwaysReturning(sharedAnonymousId())
        config.logs.serviceName = "docktile-macos"
        config.logs.environment = AppEnvironment.current
        config.logs.serviceVersion = AppEnvironment.appVersion
        PostHogSDK.shared.setup(config)
        isPostHogConfigured = true
        applyCollectionState()
        capturePostHogLog("log_capture_configured", attributes: ["app_role": AppEnvironment.appRole])
    }

    /// One anonymous ID for the main app and every tile. Each helper has its own bundle ID, and
    /// PostHog stores its ID per bundle, so without this every tile counted as a separate user.
    /// The SDK asks only while its own storage holds no ID, i.e. once per process bundle.
    private func sharedAnonymousId() -> UUID {
        CFPreferencesAppSynchronize(UserDefaultsKeys.sharedSuiteName as CFString)
        if let id = sharedDefaults?.string(forKey: UserDefaultsKeys.postHogAnonymousId).flatMap(UUID.init(uuidString:)) {
            return id
        }
        // shortcut: two processes that both start before any has written the ID (and in the same
        // instant) keep separate IDs; the main app normally starts first after an update. Add a
        // lock if PostHog's user count runs well above GA4's.
        let id = UUID()
        sharedDefaults?.set(id.uuidString, forKey: UserDefaultsKeys.postHogAnonymousId)
        return id
    }

    /// Built outside the main actor: the SDK may call it from its storage lock on any thread,
    /// and a closure formed in this `@MainActor` class would carry a main-actor check.
    nonisolated private static func alwaysReturning(_ id: UUID) -> (UUID) -> UUID { { _ in id } }

    /// Persist a new consent value, apply it live, and tell running helpers to re-apply it.
    func setConsent(_ enabled: Bool) {
        sharedDefaults?.set(enabled, forKey: UserDefaultsKeys.analyticsEnabled)
        // Flush before telling helpers, or one can re-read the OLD value and keep collecting.
        CFPreferencesAppSynchronize(UserDefaultsKeys.sharedSuiteName as CFString)
        applyCollectionState()
        DistributedNotificationCenter.default().postNotificationName(
            Self.consentDidChange, object: nil, userInfo: nil, deliverImmediately: true)
    }

    private func applyCollectionState() {
        let enabled = Self.shouldCollect(isRelease: environmentAllowsCollection, consentGranted: consentGranted)
        collectionEnabled = enabled

        if isPostHogConfigured {
            if enabled {
                PostHogSDK.shared.optIn()
            } else {
                PostHogSDK.shared.optOut()
            }
        }

        guard isConfigured else { return }
        Analytics.setAnalyticsCollectionEnabled(enabled)
        Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(enabled)
        print("ℹ️ Analytics collection \(enabled ? "ENABLED" : "disabled") (role=\(AppEnvironment.appRole), env=\(AppEnvironment.current))")
    }

    // MARK: - Events

    /// Logs a completed product action to the configured analytics clients. PostHog events remain
    /// anonymous because DockTile has no account identity; all properties are non-identifying.
    func log(_ event: AnalyticsEvent, _ parameters: [String: Any] = [:]) {
        if isConfigured {
            Analytics.logEvent(event.rawValue, parameters: parameters.isEmpty ? nil : parameters)
        }

        guard isPostHogConfigured, collectionEnabled, shouldCaptureWithPostHog(event) else { return }
        PostHogSDK.shared.capture(event.rawValue, properties: parameters.isEmpty ? nil : parameters)
        capturePostHogLog("product_action_captured", attributes: ["analytics_event": event.rawValue])
    }

    /// Dedicated PostHog logger. Existing `print`, `Logger`, and `DiagnosticsLog` output remains
    /// local; only purpose-built operational lines supplied here are exported.
    private func capturePostHogLog(_ message: String, attributes: [String: Any]) {
        guard isPostHogConfigured, collectionEnabled else { return }
        PostHogSDK.shared.logger?.info(message, attributes: attributes)
    }

    /// Keep PostHog focused on user-initiated actions and their outcomes, rather than lifecycle
    /// and maintenance noise. The existing call sites provide the real-action timing.
    private func shouldCaptureWithPostHog(_ event: AnalyticsEvent) -> Bool {
        switch event {
        case .tileCreated, .tileAddedToDock, .tileUpdated, .tileRemoved, .tileHidden, .tileReverted,
             .popoverOpened, .appLaunchedFromTile, .popoverItemAction, .configureGearTapped,
             .settingChanged, .relocationMoveStarted, .relocationMoveSucceeded, .relocationMoveFailed,
             .translationHelpTapped, .updateCheck, .updateChoice, .updateInstalling:
            return true
        default:
            return false
        }
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
