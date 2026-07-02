//
//  AppRelocation.swift
//  DockTile
//
//  Detects when the app is running from a location it cannot safely copy itself from, and
//  nudges the user to move it to /Applications.
//
//  WHY THIS EXISTS: helper tiles are created by copying the *running* main-app bundle as a
//  template (`HelperBundleManager.generateHelperBundle`). When the app is launched from
//  ~/Downloads while still quarantined, macOS Gatekeeper **App Translocation** runs it from a
//  randomized, read-only shadow mount. Copying that bundle then fails with
//  NSFileReadNoSuchFileError (Cocoa 260 / POSIX 2) — which is exactly the non-fatal we saw in
//  Crashlytics from a user running `~/Downloads/Dock Tile.app`. Every helper op (add / update /
//  "apply popover appearance to running tiles" / migration) is exposed to this. The fix is to
//  keep the app OUT of that state: detect the location and guide the user to /Applications.
//
//  The regression-prone DECISION (is this location safe? does it need relocating?) is a pure,
//  value-in/value-out seam (`AppRelocation`) unit-tested without Security.framework / FileManager,
//  per the regression-guard convention. The @MainActor `AppRelocationManager` wraps the runtime
//  bits (SecTranslocate, the move, the NSAlert).
//
//  Swift 6 - Strict Concurrency
//

import Foundation
import AppKit

// The SecTranslocate* C functions are public (Security.framework, macOS 10.12+) but are NOT
// surfaced by Swift's `Security` module overlay, so they can't be called directly. Resolve them at
// runtime via dlsym against the already-loaded Security framework (RTLD_DEFAULT searches all loaded
// images). Absent symbols degrade gracefully to "not translocated".
private typealias SecTranslocateIsTranslocatedURLFn =
    @convention(c) (CFURL, UnsafeMutablePointer<DarwinBoolean>, UnsafeMutablePointer<Unmanaged<CFError>?>?) -> Bool
private typealias SecTranslocateCreateOriginalPathForURLFn =
    @convention(c) (CFURL, UnsafeMutablePointer<Unmanaged<CFError>?>?) -> Unmanaged<CFURL>?

private func loadSecTranslocateSymbol<T>(_ name: String, as type: T.Type) -> T? {
    // RTLD_DEFAULT is (void *)-2 on Darwin — search every loaded image for the symbol.
    guard let symbol = dlsym(UnsafeMutableRawPointer(bitPattern: -2), name) else { return nil }
    return unsafeBitCast(symbol, to: T.self)
}

// MARK: - Pure decision seam (regression-guarded)

/// Where the running app lives, from the perspective of "can it safely copy itself as a helper
/// template and stay put across relaunches?".
enum AppRelocation {

    enum Location: Equatable {
        /// Inside a system or user Applications folder — stable and writable. All good.
        case applications
        /// Running from a randomized read-only App Translocation mount (quarantined + launched
        /// from e.g. ~/Downloads). Copying the bundle fails — this is the confirmed crash source.
        case translocated
        /// A normal but non-Applications location (Downloads, Desktop, a mounted DMG, …). Helper
        /// generation may still work, but the app is one quarantine away from translocation and
        /// should be moved.
        case elsewhere

        /// Stable, lowercase token for analytics/breadcrumbs.
        var analyticsValue: String {
            switch self {
            case .applications: return "applications"
            case .translocated: return "translocated"
            case .elsewhere: return "elsewhere"
            }
        }
    }

    /// Classify a bundle path. `isTranslocated` is the runtime SecTranslocate result;
    /// `applicationsDirectories` are the absolute paths treated as "installed" (/Applications and
    /// ~/Applications). Pure — no filesystem access — so it is fully unit-testable.
    static func classify(
        bundlePath: String,
        isTranslocated: Bool,
        applicationsDirectories: [String]
    ) -> Location {
        if isTranslocated { return .translocated }

        let normalized = normalize(bundlePath)
        for dir in applicationsDirectories {
            let prefix = normalize(dir) + "/"
            if normalized.hasPrefix(prefix) { return .applications }
        }
        return .elsewhere
    }

    /// Helper-bundle generation copies the running app as a template. That is only guaranteed to
    /// fail from a translocated mount (the source path is not a real, copyable bundle). Used as the
    /// hard pre-flight guard that turns the silent copy failure into an actionable error.
    static func blocksBundleGeneration(_ location: Location) -> Bool {
        location == .translocated
    }

    /// Whether the user should be nudged to move the app to /Applications. Anything but a real
    /// Applications install qualifies — translocated (broken now) and elsewhere (about to break).
    static func requiresRelocation(_ location: Location) -> Bool {
        location != .applications
    }

    private static func normalize(_ path: String) -> String {
        var p = path
        while p.count > 1 && p.hasSuffix("/") { p.removeLast() }
        return p
    }
}

// MARK: - Runtime manager

/// Owns the runtime side of relocation: the SecTranslocate probe, the launch-time nudge, the
/// blocking prompt shown when a helper op is refused, and the actual move-to-/Applications.
/// Main-app only — helpers never relocate themselves.
@MainActor
final class AppRelocationManager: ObservableObject {
    static let shared = AppRelocationManager()
    private init() {}

    // MARK: Runtime location

    /// True when the running bundle is served from an App Translocation mount.
    var isTranslocated: Bool { Self.resolveIsTranslocated(Bundle.main.bundleURL) }

    /// The current app location, resolved live.
    var currentLocation: AppRelocation.Location {
        AppRelocation.classify(
            bundlePath: Bundle.main.bundleURL.path,
            isTranslocated: isTranslocated,
            applicationsDirectories: Self.applicationsDirectories()
        )
    }

    /// Whether helper bundles can be safely generated from the current location.
    var canGenerateBundles: Bool { !AppRelocation.blocksBundleGeneration(currentLocation) }

    // MARK: Launch nudge

    /// Called once from `AppDelegate.configureAsMainApp`. Prompts to move the app to /Applications
    /// when it is translocated or sitting outside an Applications folder — unless the user has
    /// suppressed the nudge. Non-blocking (a "Not Now" is offered).
    func checkOnLaunch() {
        guard !AppEnvironment.isHelper else { return }
        // Dev builds run from DerivedData (…/Build/Products/Debug/) by design — that is NOT an
        // Applications install, but moving it would break the dev/release data separation. The
        // translocation problem only affects distributed Release builds, so only they get nudged.
        guard AppEnvironment.isRelease else { return }
        let location = currentLocation
        guard AppRelocation.requiresRelocation(location) else { return }
        guard !UserDefaults.standard.bool(forKey: UserDefaultsKeys.relocationPromptSuppressed) else { return }
        DiagnosticsLog.shared.log("relocation", "App running from \(location.analyticsValue) — nudging to relocate")
        presentRelocationPrompt(blocking: false, location: location)
    }

    /// Called from a helper op that was refused because the app can't copy itself. Blocking (there
    /// is no "Not Now" — the action cannot proceed), and never suppressible.
    func presentBlockingPrompt() {
        presentRelocationPrompt(blocking: true, location: currentLocation)
    }

    // MARK: - Prompt

    private func presentRelocationPrompt(blocking: Bool, location: AppRelocation.Location) {
        let alert = NSAlert()
        alert.messageText = AppStrings.Alert.relocateTitle
        alert.informativeText = blocking
            ? AppStrings.Alert.relocateBlockingMessage
            : AppStrings.Alert.relocateMessage
        alert.alertStyle = .warning
        alert.addButton(withTitle: AppStrings.Button.moveToApplications)
        alert.addButton(withTitle: blocking ? AppStrings.Button.cancel : AppStrings.Button.notNow)

        // Only the non-blocking launch nudge is dismissible-forever; a blocked action must keep
        // asking until the app is actually somewhere it can work from.
        var suppressCheckbox: NSButton?
        if !blocking {
            let checkbox = NSButton(checkboxWithTitle: AppStrings.Alert.relocateCheckbox, target: nil, action: nil)
            checkbox.state = .off
            alert.accessoryView = checkbox
            suppressCheckbox = checkbox
        }

        AnalyticsService.shared.log(.relocationPrompted,
                                    ["location": location.analyticsValue, "blocking": String(blocking)])

        // App-modal (not a window sheet): the launch nudge can fire before any window exists, and
        // the blocking prompt interrupts an in-flight helper op — both want a synchronous answer.
        let response = alert.runModal()

        if response == .alertFirstButtonReturn {
            moveToApplicationsAndRelaunch()
        } else if suppressCheckbox?.state == .on {
            UserDefaults.standard.set(true, forKey: UserDefaultsKeys.relocationPromptSuppressed)
            DiagnosticsLog.shared.log("relocation", "User suppressed relocation nudge")
        }
    }

    // MARK: - Move

    /// Move the (un-translocated) app bundle into /Applications, clear its quarantine so macOS
    /// won't translocate the copy, and relaunch from there. Falls back to revealing the original in
    /// Finder if the move can't be completed (e.g. /Applications isn't writable without admin).
    private func moveToApplicationsAndRelaunch() {
        AnalyticsService.shared.log(.relocationMoveStarted, [:])
        DiagnosticsLog.shared.log("relocation", "Attempting move to /Applications")

        guard let source = resolveOriginalURL() else {
            reportMoveFailure("could not resolve original bundle path")
            revealInFinder(nil)
            return
        }

        let fm = FileManager.default
        let destination = URL(fileURLWithPath: "/Applications", isDirectory: true)
            .appendingPathComponent(source.lastPathComponent)

        do {
            // Replace any stale copy already sitting at the destination.
            if fm.fileExists(atPath: destination.path) {
                try fm.trashItem(at: destination, resultingItemURL: nil)
            }
            do {
                try fm.moveItem(at: source, to: destination)
            } catch {
                // Cross-volume or permission hiccup on move — retry as copy + best-effort cleanup.
                try fm.copyItem(at: source, to: destination)
                try? fm.removeItem(at: source)
            }
        } catch {
            reportMoveFailure(error.localizedDescription)
            revealInFinder(source)
            return
        }

        clearQuarantine(at: destination)
        AnalyticsService.shared.log(.relocationMoveSucceeded, [:])
        DiagnosticsLog.shared.log("relocation", "Moved to \(destination.path) — relaunching")
        relaunch(at: destination)
    }

    /// The real, on-disk bundle path — un-translocated. Under translocation `Bundle.main.bundleURL`
    /// points at the read-only shadow mount, so we ask SecTranslocate for the original.
    private func resolveOriginalURL() -> URL? {
        let current = Bundle.main.bundleURL
        guard isTranslocated else { return current }
        guard let originalPath = loadSecTranslocateSymbol(
            "SecTranslocateCreateOriginalPathForURL",
            as: SecTranslocateCreateOriginalPathForURLFn.self
        ) else { return nil }
        guard let original = originalPath(current as CFURL, nil) else { return nil }
        return original.takeRetainedValue() as URL
    }

    private func clearQuarantine(at url: URL) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/xattr")
        task.arguments = ["-dr", "com.apple.quarantine", url.path]
        try? task.run()
        task.waitUntilExit()
    }

    private func relaunch(at url: URL) {
        let config = NSWorkspace.OpenConfiguration()
        config.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: url, configuration: config) { _, _ in
            DispatchQueue.main.async { NSApp.terminate(nil) }
        }
    }

    private func revealInFinder(_ url: URL?) {
        let target = url ?? Bundle.main.bundleURL
        NSWorkspace.shared.activateFileViewerSelecting([target])
    }

    private func reportMoveFailure(_ reason: String) {
        DiagnosticsLog.shared.log("relocation", "Move to /Applications FAILED: \(reason)")
        AnalyticsService.shared.log(.relocationMoveFailed, ["reason": reason])
    }

    // MARK: - Static runtime probes (thin wrappers over the OS; the decision lives in the seam)

    /// Absolute Applications directories considered "installed": the system /Applications plus the
    /// user's ~/Applications.
    static func applicationsDirectories() -> [String] {
        var dirs = ["/Applications"]
        let userApps = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Applications").path
        dirs.append(userApps)
        return dirs
    }

    static func resolveIsTranslocated(_ url: URL) -> Bool {
        guard let isTranslocated = loadSecTranslocateSymbol(
            "SecTranslocateIsTranslocatedURL",
            as: SecTranslocateIsTranslocatedURLFn.self
        ) else { return false }
        var translocated: DarwinBoolean = false
        let ok = isTranslocated(url as CFURL, &translocated, nil)
        return ok && translocated.boolValue
    }
}
