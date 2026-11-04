//
//  IconStyleManager.swift
//  DockTile
//
//  Manages macOS Tahoe icon style observation (Default/Dark/Clear/Tinted)
//  This is SEPARATE from Appearance (Light/Dark) - Tahoe has two independent settings
//
//  ARCHITECTURE:
//  - Single source of truth for icon style across the app — detection lives ONLY here.
//    HelperAppDelegate used to run its own parallel detection; that is why two pollers existed.
//  - Views use @StateObject/@ObservedObject to react to changes
//  - Fully event-driven: NO timer. UserDefaults KVO is primary (the only documented cross-process
//    settings signal, and measured fastest); one distributed notification is the Light/Dark
//    secondary; wake and popover-show are reconciliation moments, not polls.
//  - Posts .iconStyleDidChange notification for non-SwiftUI components (HelperAppDelegate, which
//    rewrites the Dock icon)
//
//  Swift 6 - Strict Concurrency
//

import SwiftUI
import AppKit

/// Represents the macOS Tahoe icon style (System Settings → Appearance → Icon and widget style)
/// This is INDEPENDENT of the system appearance (Light/Dark mode)
enum IconStyle: String, CaseIterable, Sendable {
    case defaultStyle   // Default colorful icons (key not set)
    case dark           // Dark background with tint-colored symbols (RegularDark)
    case clear          // "Etched glass" look (value TBD)
    case tinted         // Wallpaper-tinted background (value TBD)

    /// The UserDefaults key for icon style
    static let userDefaultsKey = "AppleIconAppearanceTheme"

    /// The raw `AppleIconAppearanceTheme` value as stored, UNTYPED (nil = key genuinely not set).
    /// Read from global UserDefaults using CFPreferences for reliability. Kept untyped because
    /// `as? String` collapsed a present-but-non-string value (a future macOS, a stray
    /// `defaults write -int`) into "key absent" — a confident `.defaultStyle` instead of
    /// unresolved, which is the oscillation-amplifier bug through the type door.
    static var rawPreferencesObject: Any? {
        CFPreferencesCopyAppValue(
            userDefaultsKey as CFString,
            kCFPreferencesAnyApplication
        )
    }

    /// Returns the current icon style from system preferences
    static var current: IconStyle {
        resolve(preferencesObject: rawPreferencesObject, isDarkMode: systemAppearanceIsDark)
            ?? .defaultStyle
    }

    /// Returns the current icon style, or `nil` when the stored value is an UNRECOGNISED string
    /// or not a string at all. Use this wherever a read is compared against a cached style to
    /// detect a *change* — an unresolved read must not be mistaken for a switch to Default.
    static var currentResolved: IconStyle? {
        resolve(preferencesObject: rawPreferencesObject, isDarkMode: systemAppearanceIsDark)
    }

    /// Pure typing seam ahead of `resolve(preferencesValue:isDarkMode:)`: an ABSENT value (nil)
    /// is Default (documented Apple behaviour — the Default option deletes the key), but a
    /// present value of a non-string TYPE is UNRESOLVED (`nil`) — don't act, never Default.
    static func resolve(preferencesObject: Any?, isDarkMode: Bool) -> IconStyle? {
        guard let object = preferencesObject else {
            return .defaultStyle // Key not set = Default
        }
        guard let string = object as? String else {
            return nil // Present but not a string — unresolved, do not act
        }
        return resolve(preferencesValue: string, isDarkMode: isDarkMode)
    }

    // Known macOS Tahoe values (as of 2026-02; the observed set lives in IconStyleResolveTests):
    // - nil or not set = Default (colorful)
    // - "RegularAutomatic" = Automatic — follows system appearance (Dark → dark icons)
    // - "RegularDark" = Dark (explicit)
    // - "RegularLight" = Light/Default (explicit)
    // - "ClearAutomatic" = Clear
    // - "TintedAutomatic" = Tinted

    /// SEEDED mapping seam: like `resolve(preferencesValue:isDarkMode:)` but falls back to
    /// `.defaultStyle` for an unrecognised value. Correct only where an INITIAL style must be
    /// picked (launch, previews); a *change* detector must use `resolve` so an unrecognised read
    /// doesn't masquerade as a switch to Default.
    static func from(preferencesValue: String?, isDarkMode: Bool) -> IconStyle {
        resolve(preferencesValue: preferencesValue, isDarkMode: isDarkMode) ?? .defaultStyle
    }

    /// Pure mapping seam: resolves the `AppleIconAppearanceTheme` string to an `IconStyle` with
    /// the system appearance INJECTED, so the Automatic-follows-appearance behaviour (the Tahoe
    /// default, and the most regression-prone case) is unit-testable without CFPreferences.
    /// The argument-less `systemAppearanceIsDark` is read only at the call sites above.
    ///
    /// - Returns: the mapped style; `.defaultStyle` when the key is genuinely ABSENT (documented
    ///   Apple behaviour: not set = Default); `nil` when the value is a string we do not
    ///   recognise. `nil` means UNRESOLVED — "don't act" — never "Default". Apple publishes no
    ///   list of valid values, so a value a future macOS adds lands here rather than being
    ///   reported as a real style change.
    static func resolve(preferencesValue: String?, isDarkMode: Bool) -> IconStyle? {
        guard let value = preferencesValue else {
            return .defaultStyle // Key not set = Default
        }

        switch value {
        // Automatic: the "Regular" (non-clear/tinted) style that follows the system
        // appearance — dark icons in Dark mode, colourful default in Light mode.
        // This is the Tahoe default, so it MUST be handled or dark mode never applies.
        case "RegularAutomatic", "Automatic":
            return isDarkMode ? .dark : .defaultStyle
        // Dark style (explicit)
        case "RegularDark", "Dark":
            return .dark
        // Light/Default style (explicit)
        case "RegularLight", "Light":
            return .defaultStyle
        // Clear style (semi-transparent gray). "ClearLight" and "ClearDark" are REAL values,
        // observed being written by macOS 26.6.2 on 2026-08-31 when the light/dark Clear options
        // are picked in System Settings — not the `*Automatic` ones. Both map to `.clear`: the
        // tile art is grayscale and macOS applies its own light/dark treatment on top.
        case "ClearAutomatic", "Clear", "RegularClear", "ClearLight", "ClearDark":
            return .clear
        // Tinted style (wallpaper-derived colors). "TintedDark" observed the same way;
        // "TintedLight" is included by symmetry — unobserved, but the alternative is silently
        // ignoring a real user selection, and `.tinted` is the only sane mapping for the name.
        case "TintedAutomatic", "Tinted", "RegularTinted", "TintedLight", "TintedDark":
            return .tinted
        default:
            return nil // Unresolved — caller decides whether to seed or ignore
        }
    }

    /// Whether the system is currently in Dark appearance.
    /// Read via CFPreferences (mirrors how the icon-style value is read) so it works in
    /// the main app and helper processes without depending on a live `NSApplication`.
    static var systemAppearanceIsDark: Bool {
        let style = CFPreferencesCopyAppValue(
            "AppleInterfaceStyle" as CFString,
            kCFPreferencesAnyApplication
        ) as? String
        return style == "Dark"
    }

    /// Display name for UI
    var displayName: String {
        switch self {
        case .defaultStyle: return "Default"
        case .dark: return "Dark"
        case .clear: return "Clear"
        case .tinted: return "Tinted"
        }
    }

    /// View-facing resolution: combines the published raw token (`IconStyleManager.rawStyle`)
    /// with the VIEW's OWN `colorScheme` environment value, so Light/Dark tracking is live and
    /// system-driven (SwiftUI delivers it), and only the explicit style choice comes from the
    /// token. Delegates to `resolve(preferencesValue:isDarkMode:)` — no second mapping table.
    /// `.unreadable` / an unrecognised value is the display-level no-op: keep showing `fallback`
    /// (the caller's last-known style) rather than guessing.
    static func forDisplay(raw: RawStyleToken, colorScheme: ColorScheme, fallback: IconStyle) -> IconStyle {
        switch raw {
        case .absent:
            return .defaultStyle
        case .unreadable:
            return fallback
        case .value(let string):
            return resolve(preferencesValue: string, isDarkMode: colorScheme == .dark) ?? fallback
        }
    }
}

/// Plain-value snapshot of the `AppleIconAppearanceTheme` UserDefaults key, ahead of any
/// style mapping. `.absent` (key genuinely not set), `.value` (a string, mapped by `resolve`),
/// or `.unreadable` (present but not a string — the same "don't act" case `resolve` treats as
/// unresolved). Equatable/Sendable and pure to construct so `forDisplay` above can be unit-tested
/// without CFPreferences.
enum RawStyleToken: Equatable, Sendable {
    case absent
    case value(String)
    case unreadable
}

/// Manages icon style observation and provides style-aware rendering utilities
///
/// USAGE IN SWIFTUI VIEWS:
/// ```swift
/// struct MyView: View {
///     @ObservedObject private var iconStyleManager = IconStyleManager.shared
///     @Environment(\.colorScheme) private var colorScheme
///
///     var body: some View {
///         let style = IconStyle.forDisplay(
///             raw: iconStyleManager.rawStyle,
///             colorScheme: colorScheme,
///             fallback: .defaultStyle
///         )
///         // Use `style` for rendering.
///     }
/// }
/// ```
/// `currentStyle` (below) is legacy-detection-only (frozen, macOS 15 fallback) and does not
/// update on macOS 26 — views must resolve display style via `forDisplay` + `rawStyle` instead.
@MainActor
final class IconStyleManager: ObservableObject {

    static let shared = IconStyleManager()

    /// Current icon style - views observing this will automatically update.
    ///
    /// Deliberately has NO declared default. Swift's two-phase init then REQUIRES SOME assignment
    /// before `init()` may call any instance method (including `setupObservers()`) — so a naive
    /// edit that simply deletes the seed line below, or moves it after `setupObservers()`, fails
    /// the BUILD rather than silently leaving this at a stale/wrong value that a runtime test
    /// might not catch (a prior test here compared against `IconStyle.current`, which collapses
    /// to the same `.defaultStyle` as the removed-default's implicit value whenever the system
    /// icon style is Default — the common case — so it couldn't discriminate the regression it
    /// was meant to guard).
    ///
    /// **This guarantee is narrower than it looks**: definite-initialization only requires SOME
    /// assignment before first use of `self`, not the FINAL one. A two-step restructuring —
    /// assign a placeholder here, then assign the real `IconStyle.current` later inside a gated
    /// block of `setupObservers()` — would still compile and would silently reintroduce the bug
    /// the missing-default was meant to catch. The compiler catches the naive one-line
    /// reorder/delete; it does not catch a restructuring like that.
    /// (`HelperAppDelegate.currentIconStyle` carries the same shape of risk in weaker form: it
    /// has a declared default, `= .defaultStyle`, so it gets no compile-time protection at all —
    /// a stale seed there can only be caught by a runtime test.)
    ///
    /// `rawStyle` below carries the SAME structural guarantee, for the same reason: it too has
    /// no declared default, so both properties must be assigned before `setupObservers()` runs.
    @Published private(set) var currentStyle: IconStyle

    /// Published raw `AppleIconAppearanceTheme` token, ahead of any style mapping — the seam the
    /// view-facing `IconStyle.forDisplay` combines with a view's own `colorScheme` so Light/Dark
    /// tracking is live (SwiftUI-delivered) rather than a cached appearance read at some past
    /// moment. Seeded ONCE at init (see the structural note on `currentStyle` above — the same
    /// guarantee, extended to this property), then refreshed only through `refreshRawStyle()`:
    /// live via the main app's display observer (`startDisplayObservation()`) and on
    /// `didBecomeActiveNotification` as the missed-event recovery (both main-app only). Helpers
    /// never refresh it: a helper's popover content is rebuilt on every `show()`, so the launch
    /// seed is sufficient there.
    @Published private(set) var rawStyle: RawStyleToken

    /// KVO bridge for the two appearance keys (legacy DETECTION path only — never on Tahoe).
    private var defaultsObserver: DefaultsKeyObserver?

    /// Main-app-only DISPLAY observer (see `startDisplayObservation()`): keeps `rawStyle` live so
    /// the window's previews restyle while backgrounded, the way System Settings does. Read-only —
    /// it can never rewrite an icon or touch a bundle, so it is safe under the Tahoe quarantine.
    private var displayObserver: DefaultsKeyObserver?

    /// True once ANY event-based signal (KVO or distributed notification) has been received.
    /// If a reconcile keeps finding changes the events never announced, the event path is broken
    /// on this OS and we must say so rather than let detection degrade silently.
    private var signalReceived = false

    /// Set once we have complained about the event path, so we complain once per process.
    private var reportedSilentEventPath = false

    private init() {
        // Seeded ONCE at process launch — a passive read, not a live subscription. Under the
        // declarative pipeline every re-check is quarantined too (`reconcile(reason:)`, including
        // the popover-show reconcile), so this value is never refreshed again for the life of the
        // process. That's sufficient: popover views key third-party app icon views on
        // `IconStyle.forDisplay(rawStyle, colorScheme)` only as a re-render TRIGGER
        // (`.id("\(app.id)-\(style)")`), and the popover content is rebuilt on every `show()`, so
        // what's drawn stays current even though `currentStyle` itself doesn't change mid-process.
        //
        // The PIXELS must not be keyed off this value (critical): they now come from
        // `TileIconRasterCache`, which caches for the process lifetime, so a token built from this
        // frozen snapshot froze every bitmap a helper served. That is why the cache takes its
        // appearance token from `TileIconRasterCache.liveAppearanceToken(isDark:)` — a fresh
        // preference read per popover build — and never from `rawStyle`.
        currentStyle = IconStyle.current
        rawStyle = Self.token(from: IconStyle.rawPreferencesObject)
        print("[IconStyleManager] Initialized with style: \(currentStyle.rawValue)")

        setupObservers()
    }

    /// Pure classification of the raw `AppleIconAppearanceTheme` preferences object into a
    /// `RawStyleToken` — `nil` (absent), a `String` (the value to map), or anything else
    /// (unreadable, same "don't act" case `IconStyle.resolve` treats as unresolved).
    nonisolated static func token(from object: Any?) -> RawStyleToken {
        guard let object else { return .absent }
        guard let string = object as? String else { return .unreadable }
        return .value(string)
    }

    /// Pure decision behind `refreshRawStyle()`: adopt the freshly read token only when it
    /// differs from the current one, so a foreground activation that finds nothing changed
    /// doesn't publish (and fire a spurious `objectWillChange` for) an identical value.
    nonisolated static func shouldAdopt(newToken: RawStyleToken, current: RawStyleToken) -> Bool {
        newToken != current
    }

    /// Re-reads `AppleIconAppearanceTheme` and publishes `rawStyle` when it changed. This is the
    /// ONLY place `rawStyle` is refreshed after the launch seed above. Two main-app triggers, both
    /// wired from `AppDelegate.configureAsMainApp`: the live display observer
    /// (`startDisplayObservation()`) and `NSApplication.didBecomeActiveNotification` as recovery
    /// for an event missed while asleep. Helpers never call this, matching the doc on `rawStyle`.
    func refreshRawStyle() {
        // Synchronize first: another process (System Settings) wrote the key, and an un-synced
        // read can return this process's cached copy (issue #22). Display path only — the frozen
        // legacy detection reads are deliberately left as they are.
        CFPreferencesAppSynchronize(kCFPreferencesAnyApplication)
        let newToken = Self.token(from: IconStyle.rawPreferencesObject)
        guard Self.shouldAdopt(newToken: newToken, current: rawStyle) else { return }
        DiagnosticsLog.shared.log("icon-style", "Display style \(rawStyle) → \(newToken)", verbose: true)
        rawStyle = newToken
    }

    // MARK: - Display poll (main app, while visible)

    /// What the display poll should do for a visibility change.
    enum DisplayPollAction: Equatable { case start, stop, none }

    /// How often the main app re-reads the icon style while a window is visible.
    static let displayPollInterval: TimeInterval = 2.0

    /// Pure seam: poll only while the app is visible on screen (`NSApp.occlusionState`), never
    /// restart a running poll, never stop an idle one. Guarded by `IconStyleDisplayPollTests`.
    nonisolated static func displayPollAction(appVisible: Bool, polling: Bool) -> DisplayPollAction {
        switch (appVisible, polling) {
        case (true, false): return .start
        case (false, true): return .stop
        default: return .none
        }
    }

    private var displayPollTimer: Timer?

    /// Starts or stops the display poll to match the app's current visibility.
    private func updateDisplayPoll() {
        switch Self.displayPollAction(appVisible: NSApp.occlusionState.contains(.visible),
                                      polling: displayPollTimer != nil) {
        case .start:
            let timer = Timer(timeInterval: Self.displayPollInterval, repeats: true) { _ in
                Task { @MainActor in IconStyleManager.shared.refreshRawStyle() }
            }
            timer.tolerance = 0.5
            RunLoop.main.add(timer, forMode: .common)
            displayPollTimer = timer
        case .stop:
            displayPollTimer?.invalidate()
            displayPollTimer = nil
        case .none:
            break
        }
    }

    /// MAIN-APP ONLY: subscribe `rawStyle` to live `AppleIconAppearanceTheme` changes so the
    /// window's previews restyle immediately (System Settings reacts instantly; activation-only
    /// refresh made Dock Tile lag until the next foreground — reported 2026-09-02).
    ///
    /// This is DISPLAY, not detection: the callback only re-reads the key and republishes
    /// `rawStyle` — no icon rewrite, no bundle touch, no `.iconStyleDidChange` post — so the
    /// Tahoe quarantine on the detection lifecycle is untouched. On the LEGACY pipeline the
    /// detection observer is already registered on this same key and `defaultsKeyChanged()`
    /// refreshes the display token too, so this registers nothing there (no double-fire).
    /// Helpers must never call this (their popover rebuilds on every `show()`).
    func startDisplayObservation() {
        guard displayObserver == nil, defaultsObserver == nil else { return }
        displayObserver = DefaultsKeyObserver(
            keys: [IconStyle.userDefaultsKey],
            manager: self,
            mode: .display
        )

        // KVO alone is not enough on macOS 27: no notification is posted for an Icon & widget
        // style change, and the KVO reached this app 1.4 s to 8 min late, or not at all (measured
        // 2026-10-15, issue #22). So while a window is visible, also re-read every
        // `displayPollInterval`; the poll stops whenever the app is hidden or fully covered.
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeOcclusionStateNotification,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in IconStyleManager.shared.updateDisplayPoll() }
        }
        updateDisplayPoll()
    }

    /// Pure gate for the whole detection lifecycle (observer registration, reconciles). The
    /// declarative pipeline (macOS 26) has macOS render every appearance itself — nothing to
    /// detect, nothing to swap — so this is `!isDeclarative`. Deliberately trivial: the seam
    /// exists so the decision is greppable and testable, not because the rule is complex.
    nonisolated static func shouldRunDetection(isDeclarative: Bool) -> Bool {
        !isDeclarative
    }

    private func setupObservers() {
        guard Self.shouldRunDetection(isDeclarative: IconPipeline.isDeclarative) else {
            print("[IconStyleManager] Declarative pipeline — detection quarantined (no observers registered)")
            return
        }

        // PRIMARY: KVO on UserDefaults. This is the only DOCUMENTED cross-process settings signal
        // ("Key-value observing reports all updates to setting values, regardless of which process
        // made the change"). Apple documents it for an app's own domain and says nothing about
        // NSGlobalDomain fall-through keys, so it was verified empirically on 2026-08-31: it fires
        // for AppleInterfaceStyle inside a windowless .accessory process, AHEAD of every other
        // channel including the distributed notification. See
        // docs/macos-appearance-detection-research.md §E.
        defaultsObserver = DefaultsKeyObserver(
            keys: [IconStyle.userDefaultsKey, "AppleInterfaceStyle"],
            manager: self,
            mode: .detection
        )

        // SECONDARY: the one distributed name that still exists on macOS 26. The other two we used
        // to observe ("AppleIconAppearanceThemeChangedNotification", "com.apple.desktop.
        // darkModeChanged") do NOT exist on this OS and were inert registrations — removed.
        // Registered .deliverImmediately: AppKit is documented to suspend delivery while an app is
        // inactive, and a Ghost helper is never active. (Measured delivery was immediate even under
        // the Coalesce default, so this is defensive rather than a fix.)
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(systemAppearanceNotification),
            name: NSNotification.Name("AppleInterfaceThemeChangedNotification"),
            object: nil,
            suspensionBehavior: .deliverImmediately
        )

        // RECOVERY: there is no timer. Apple guarantees delivery on no transport, so instead of
        // polling we re-check at moments where a missed event would otherwise become visible.
        // Wake is the one path events genuinely may not survive: a change made while the machine
        // slept has no observer running to hear it. `reconcile(reason:)` is also called when a
        // tile's popover is shown (see HelperAppDelegate).
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(systemDidWake),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )

        print("[IconStyleManager] Observers set up (KVO + distributed notification + wake reconcile; no timer)")
    }

    /// Re-resolve the style at a moment where a missed event would otherwise show as a wrong icon.
    ///
    /// Not a poll: these are discrete, event-driven moments (wake, popover shown). Measured on
    /// 2026-08-31, KVO was first or tied on 13/13 transitions and the 1s poll never once caught
    /// something the events missed — so the recovery path exists for the case the measurement
    /// could NOT cover (a change made while asleep), not as a routine safety net.
    func reconcile(reason: String) {
        guard Self.shouldRunDetection(isDeclarative: IconPipeline.isDeclarative) else { return }
        checkAndUpdateStyle(source: "reconcile:\(reason)")
    }

    @objc private func systemDidWake() {
        reconcile(reason: "wake")
    }

    /// Distributed-notification entry point. `@objc` so it can be registered with an explicit
    /// suspension behaviour, which the block-based `addObserver(forName:...)` cannot express.
    @objc private func systemAppearanceNotification() {
        signalReceived = true
        checkAndUpdateStyle(source: "notification")
    }

    /// KVO entry point, called on the main actor by `DefaultsKeyObserver` (detection mode).
    fileprivate func defaultsKeyChanged() {
        signalReceived = true
        checkAndUpdateStyle(source: "kvo")
        // Legacy pipeline: the detection observer doubles as the display trigger, so the
        // main-app previews stay live there too (startDisplayObservation registers nothing).
        refreshRawStyle()
    }

    /// Check for style change and update if needed.
    /// Called by every trigger (KVO, distributed notification, wake/popover reconcile).
    ///
    /// An UNRESOLVED read (unrecognised `AppleIconAppearanceTheme` value) must change nothing —
    /// it used to fall back to `.defaultStyle`, which this comparison then read as a real
    /// transition, republishing `currentStyle` and posting `.iconStyleDidChange` twice (out and
    /// back) for a single anomalous read. Mirrors the guard in `HelperAppDelegate`.
    private func checkAndUpdateStyle(source: String) {
        guard let newStyle = IconStyle.currentResolved else {
            DiagnosticsLog.shared.log(
                "icon-style",
                "Unresolved \(IconStyle.userDefaultsKey) value '\(IconStyle.rawPreferencesObject.map(String.init(describing:)) ?? "nil")' (\(source)) — keeping \(currentStyle.rawValue)"
            )
            return
        }
        guard newStyle != currentStyle else { return }

        // Self-test: a change first noticed by a RECONCILE, when no event has ever been received,
        // means every event transport is silent on this system — the failure mode that would
        // otherwise be invisible, because the icon would still (eventually) be right and nobody
        // would know detection had degraded. Report once per process.
        if source.hasPrefix("reconcile") && !signalReceived && !reportedSilentEventPath {
            reportedSilentEventPath = true
            DiagnosticsLog.shared.log(
                "icon-style",
                "⚠︎ Style change found by \(source) with no event ever received — "
                + "KVO and the distributed notification are both silent for appearance on this system"
            )
        }

        print("[IconStyleManager] Style changed (\(source)): \(currentStyle.rawValue) → \(newStyle.rawValue)")
        DiagnosticsLog.shared.log("icon-style", "Style \(currentStyle.rawValue) → \(newStyle.rawValue) (\(source))")
        currentStyle = newStyle

        // Post notification for non-SwiftUI components (HelperAppDelegate switches the Dock icon).
        NotificationCenter.default.post(name: .iconStyleDidChange, object: newStyle)
    }

    /// Clean up observers (called on app termination)
    func cleanup() {
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        defaultsObserver?.invalidate()
        defaultsObserver = nil
        displayObserver?.invalidate()
        displayObserver = nil
        displayPollTimer?.invalidate()
        displayPollTimer = nil
        DistributedNotificationCenter.default().removeObserver(self)
        print("[IconStyleManager] Cleaned up observers")
    }
}

// MARK: - UserDefaults KVO bridge

/// Bridges classic key-path KVO to `IconStyleManager`.
///
/// Exists because KVO requires an `NSObject` observer and `IconStyleManager` is a plain
/// `ObservableObject`, and because `UserDefaults`'s block-based `observe(_:)` needs a declared
/// Swift key path — unavailable for system keys like `AppleInterfaceStyle` that we reach through
/// the `NSGlobalDomain` fall-through.
private final class DefaultsKeyObserver: NSObject {

    /// What a fired observation feeds: `.detection` runs the legacy style-change pipeline
    /// (compare, log, post `.iconStyleDidChange`); `.display` only republishes the raw display
    /// token via `refreshRawStyle()` — the Tahoe-safe read-only path.
    enum Mode { case detection, display }

    private let keys: [String]
    private weak var manager: IconStyleManager?
    private let mode: Mode

    init(keys: [String], manager: IconStyleManager, mode: Mode) {
        self.keys = keys
        self.manager = manager
        self.mode = mode
        super.init()
        for key in keys {
            UserDefaults.standard.addObserver(self, forKeyPath: key, options: [.new], context: nil)
        }
    }

    override func observeValue(forKeyPath keyPath: String?, of object: Any?,
                               change: [NSKeyValueChangeKey: Any]?,
                               context: UnsafeMutableRawPointer?) {
        // KVO for a cross-process defaults change is not documented to arrive on any particular
        // thread, so hop to the main actor rather than assuming.
        let mode = self.mode
        Task { @MainActor [weak manager] in
            switch mode {
            case .detection: manager?.defaultsKeyChanged()
            case .display: manager?.refreshRawStyle()
            }
        }
    }

    private var invalidated = false

    /// Idempotent: `cleanup()` calls this explicitly and then releases the observer, whose
    /// `deinit` calls it again — a second `removeObserver` for the same key paths raises
    /// NSRangeException (a crash-at-exit on every clean helper termination).
    func invalidate() {
        guard !invalidated else { return }
        invalidated = true
        for key in keys {
            UserDefaults.standard.removeObserver(self, forKeyPath: key)
        }
    }

    deinit { invalidate() }
}

// MARK: - Notification Name

extension Notification.Name {
    /// Posted when icon style changes (for non-SwiftUI components)
    /// SwiftUI views should use @ObservedObject instead
    static let iconStyleDidChange = Notification.Name("IconStyleDidChange")
}

// MARK: - Icon Style Color Generation

// MARK: - TilePalette -> framework colours

extension SRGB {
    var color: Color { Color(.sRGB, red: r, green: g, blue: b, opacity: 1) }
    var nsColor: NSColor { NSColor(srgbRed: r, green: g, blue: b, alpha: 1) }
}

extension TintColor {

    /// Neutral near-black background gradient for Dark-style tiles (the pre-tint
    /// `#2C2C2E → #1C1C1E` values), so the tinted glyph reads against a monochrome surface.
    static let darkNeutralTopHex = "#2C2C2E"
    static let darkNeutralBottomHex = "#1C1C1E"

    /// Returns colors appropriate for the given icon style and tile background.
    /// Thin adapter over `TilePalette.resolve` — no colour logic here.
    /// `background` is REQUIRED: omitting it must be a compile error, never a silent Colour tile.
    func colors(for style: IconStyle, iconType: IconType = .sfSymbol, background: TileBackground)
        -> (backgroundTop: Color, backgroundBottom: Color, foreground: Color) {
        let r = TilePalette.resolve(tint: self, background: background, style: style, iconType: iconType)
        return (r.top.color, r.bottom.color, r.glyph.color)
    }

    /// Style mapping for NON-TILE squircles that carry a raw `Color` tint (the sidebar Settings/
    /// About badges — `SettingsBadgeIcon`). Thin adapter over `TilePalette.resolve` (Colour
    /// background, SF Symbol branch — badges are always coloured symbols).
    static func badgeColors(for style: IconStyle, tint: Color) -> (top: Color, bottom: Color, foreground: Color) {
        let base: SRGB
        if let ns = NSColor(tint).usingColorSpace(.sRGB) {
            base = SRGB(r: ns.redComponent, g: ns.greenComponent, b: ns.blueComponent)
        } else {
            base = TintColor.gray.baseRGB
        }
        let r = TilePalette.resolve(base: base, light: base, background: .colour, style: style, iconType: .sfSymbol)
        return (r.top.color, r.bottom.color, r.glyph.color)
    }

    /// Returns NSColors appropriate for the given icon style and tile background (for
    /// IconGenerator). Thin adapter over `TilePalette.resolve` — no colour logic here.
    func nsColors(for style: IconStyle, iconType: IconType = .sfSymbol, background: TileBackground)
        -> (backgroundTop: NSColor, backgroundBottom: NSColor, foreground: NSColor) {
        let r = TilePalette.resolve(tint: self, background: background, style: style, iconType: iconType)
        return (r.top.nsColor, r.bottom.nsColor, r.glyph.nsColor)
    }
}
