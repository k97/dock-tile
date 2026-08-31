# Analytics & Crashlytics

Firebase **Analytics** + **Crashlytics** via SPM (`firebase-ios-sdk`, pinned 11.15.0). See
[[project_firebase_spm]] memory for the binary-artifact resolution gotcha.

## Single choke point

All Firebase access goes through `AnalyticsService.shared` ([Managers/AnalyticsService.swift](../../DockTile/Managers/AnalyticsService.swift)).
No other file imports Firebase. Configure it once per process from both branches of
[App/main.swift](../../DockTile/App/main.swift) (main app **and** every helper bundle —
popover usage only happens in helpers).

- `configure()` — `FirebaseApp.configure()`, sets `app_role` (main/helper), bundle_id, version,
  then applies collection state. No-ops if `GoogleService-Info.plist` is absent.
- `log(_:_:)`, `record(_:context:keys:)`, `setBreadcrumb(_:for:)`, `setConsent(_:)`.
- Event names: `AnalyticsEvent` enum (snake_case, ≤40 chars, no reserved prefix). Not localized.

## Collection gating

Collection is ON only when **Release build AND user consent**:
- Release-only via `AppEnvironment.isRelease` — Debug/Dev builds never send (matches dev/prod data separation).
- Consent is **opt-out, default ON**, key `UserDefaultsKeys.analyticsEnabled` stored in the
  **shared suite** `com.docktile.shared` (NOT the per-app domain) so helpers honour the main
  app's toggle. UI: the "Share anonymous usage data" toggle in [GeneralSettingsView](../../DockTile/Views/GeneralSettingsView.swift).
- **Pure gating seams** (regression-guarded, `AnalyticsServiceTests`): `AnalyticsService.resolveConsent(storedValue:)`
  (opt-out default) and `.shouldCollect(isRelease:consentGranted:)` drive `applyCollectionState`.
  `AnalyticsEvent` is `CaseIterable` and a test asserts every name stays Firebase-safe (lowercase
  snake_case, ≤40 chars, no reserved prefix, unique) so a new event can't silently break in prod.

## Helper bundles

Firebase links statically into the binary, so the helper copy carries it automatically.
`GoogleService-Info.plist` is a normal bundle resource → copied into helpers; **do not** strip it
in `HelperBundleManager` (unlike Sparkle keys). `FirebaseAppDelegateProxyEnabled = NO` in Info.plist
(AppKit, manual configure).

## dSYMs / Crashlytics symbolication

Release already builds `dwarf-with-dsym`. `release.yml` has an **Upload Crashlytics dSYMs** step
(`continue-on-error`, skips if the plist is missing) that runs `upload-symbols -gsp <plist> -p mac <dSYM>`.
Auth comes from the Google App ID inside the plist — no extra GitHub secret.

## Setup the maintainer must do once

1. Register the macOS app in the Firebase console under bundle id **`com.docktile.app`**.
2. Add the downloaded `GoogleService-Info.plist` to `DockTile/Resources/` and into the DockTile
   target (Xcode: drag in, "Copy items if needed", target = DockTile). Commit it (client config, not secret).

## Reading the data back (GA4)

- Property **542196919** (account 102059710), provisioned via Firebase project `dock-tile`. The app
  stream has NO `G-` measurement ID (app streams never do — the committed `GOOGLE_APP_ID` is its
  identity); the marketing site's `G-PP04F8Z0EP` is a different stream entirely.
- **Unregistered event parameters are DISCARDED from all GA4 reports** — every param we send
  (`source`, `app_count`, `layout`, `setting`, `style`, …) and the `app_role` user property are
  invisible until registered as custom definitions in the GA4 console. Registering is forward-only.
- API reads need the `ga4-fetch@dock-tile.iam.gserviceaccount.com` service account
  (`gcloud auth print-access-token --account=… --scopes=…analytics.readonly`); user-credential ADC
  is blocked by Google for the analytics scope. Property ID is recoverable without analytics scope
  via `firebase.googleapis.com/v1beta1/projects/dock-tile/analyticsDetails` (+ `x-goog-user-project`).
