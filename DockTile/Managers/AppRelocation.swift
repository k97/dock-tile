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

    /// What "Move to Applications" should actually do, decided from plain facts about the source
    /// bundle and the destination path. Pure, so the regression is unit-testable.
    ///
    /// WHY THIS EXISTS: the move used to call `FileManager.moveItem`, which across volumes copies
    /// the bundle and then deletes the source. From a read-only DMG that delete fails (Cocoa 642)
    /// with the complete copy already sitting in /Applications, so the `copyItem` fallback then hit
    /// 516 "already exists" — every DMG user was told the move failed, and every retry trashed the
    /// good copy first. GA4 for 2.0.1: 11 of 11 attempts failed. The field (LetsMove, Electron)
    /// never moves: it copies, removes the source best-effort, and ejects a disk image afterwards.
    enum InstallPlan: Equatable {
        /// An installed copy already exists and must be kept: activate/launch it and quit. Used
        /// when it is running (never trash a running app) or when the source is gone (the
        /// ejected-DMG retry — that copy is the only good one).
        case handOff
        /// Copy source → destination. `trashDestinationFirst` replaces a stale, not-running copy;
        /// `removeSourceAfter` is skipped on a read-only volume (it could only fail);
        /// `detachSourceImage` ejects the DMG once the old process has exited.
        case copy(trashDestinationFirst: Bool, removeSourceAfter: Bool, detachSourceImage: Bool)
    }

    static func installPlan(
        sourceExists: Bool,
        sourceOnReadOnlyVolume: Bool,
        sourceIsDiskImage: Bool,
        destinationExists: Bool,
        destinationIsRunning: Bool
    ) -> InstallPlan {
        if destinationExists && (destinationIsRunning || !sourceExists) {
            return .handOff
        }
        return .copy(
            trashDestinationFirst: destinationExists,
            removeSourceAfter: !sourceOnReadOnlyVolume,
            detachSourceImage: sourceIsDiskImage
        )
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

    /// Install the (un-translocated) app bundle into /Applications, clear its quarantine so macOS
    /// won't translocate the copy, and relaunch from there. Falls back to revealing the original in
    /// Finder if the copy can't be completed (e.g. /Applications isn't writable without admin).
    ///
    /// COPY, NEVER `FileManager.moveItem` — see `AppRelocation.installPlan` for why. What happens
    /// around the copy is that pure seam's decision; this method only executes it.
    private func moveToApplicationsAndRelaunch() {
        AnalyticsService.shared.log(.relocationMoveStarted, [:])
        DiagnosticsLog.shared.log("relocation", "Attempting move to /Applications")

        let fm = FileManager.default
        // Every probe runs on the resolved ORIGINAL bundle, never `Bundle.main.bundleURL`: under
        // translocation the running URL is itself a read-only shadow mount no disk image owns.
        let source = resolveOriginalURL()
        let bundleName = (source ?? Bundle.main.bundleURL).lastPathComponent
        let destination = URL(fileURLWithPath: "/Applications", isDirectory: true)
            .appendingPathComponent(bundleName)
        let imageMountPoint = source.flatMap { Self.diskImageMountPoint(containing: $0) }

        let plan = AppRelocation.installPlan(
            sourceExists: source.map { fm.fileExists(atPath: $0.path) } ?? false,
            sourceOnReadOnlyVolume: source.map { Self.isOnReadOnlyVolume($0) } ?? false,
            sourceIsDiskImage: imageMountPoint != nil,
            destinationExists: fm.fileExists(atPath: destination.path),
            destinationIsRunning: Self.runningApplication(bundleAt: destination) != nil
        )

        switch plan {
        case .handOff:
            DiagnosticsLog.shared.log("relocation", "Installed copy already at \(destination.path) — handing off")
            AnalyticsService.shared.log(.relocationMoveSucceeded, ["reason": "handoff"])
            handOff(to: destination)

        case let .copy(trashDestinationFirst, removeSourceAfter, detachSourceImage):
            guard let source else {
                reportMoveFailure("could not resolve original bundle path")
                revealInFinder(nil)
                return
            }
            do {
                // Both can throw when /Applications isn't user-writable; one catch reports either.
                if trashDestinationFirst {
                    try fm.trashItem(at: destination, resultingItemURL: nil)
                }
                try fm.copyItem(at: source, to: destination)
            } catch {
                reportMoveFailure(error.localizedDescription)
                revealInFinder(source)
                return
            }

            clearQuarantine(at: destination)
            // Best-effort: a complete copy is success whatever happens to the source.
            if removeSourceAfter { try? fm.removeItem(at: source) }
            AnalyticsService.shared.log(.relocationMoveSucceeded, ["reason": "copied"])
            DiagnosticsLog.shared.log("relocation", "Copied to \(destination.path) — relaunching")
            if detachSourceImage, let imageMountPoint { detachLater(mountPoint: imageMountPoint) }
            relaunch(at: destination)
        }
    }

    /// Switch to the copy already installed at `url`. A running instance is activated — never a
    /// second `Dock Tile` process (both would watch and write the Dock plist); a not-running one is
    /// launched with `relaunch(at:)`, whose new-instance flag is what stops Launch Services from
    /// merely re-activating *this* process (same bundle identifier, different path).
    private func handOff(to url: URL) {
        if let running = Self.runningApplication(bundleAt: url) {
            running.activate()
            NSApp.terminate(nil)
        } else {
            relaunch(at: url)
        }
    }

    /// Eject the source disk image once this process is gone. The mount point travels as a
    /// positional shell argument, never interpolated — DMG mount points contain spaces
    /// ("/Volumes/Dock Tile …"). Best-effort: if the old process is still alive at 5 s, `detach`
    /// fails and the image simply stays mounted.
    private func detachLater(mountPoint: String) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/sh")
        task.arguments = ["-c", "sleep 5; /usr/bin/hdiutil detach \"$0\"", mountPoint]
        task.standardOutput = FileHandle.nullDevice
        task.standardError = FileHandle.nullDevice
        try? task.run()
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

    /// The other running instance of THIS app whose bundle sits at `url`, if any — never the
    /// current process, even when it runs from that very path.
    private static func runningApplication(bundleAt url: URL) -> NSRunningApplication? {
        guard let bundleId = Bundle.main.bundleIdentifier else { return nil }
        let me = ProcessInfo.processInfo.processIdentifier
        let target = url.standardizedFileURL.path
        return NSRunningApplication.runningApplications(withBundleIdentifier: bundleId)
            .first { $0.processIdentifier != me && $0.bundleURL?.standardizedFileURL.path == target }
    }

    /// Sparkle's check (`SUHost isRunningOnReadOnlyVolume`): the volume's `MNT_RDONLY` flag.
    private static func isOnReadOnlyVolume(_ url: URL) -> Bool {
        var stat = statfs()
        guard statfs(url.path, &stat) == 0 else { return false }
        return (stat.f_flags & UInt32(MNT_RDONLY)) != 0
    }

    /// LetsMove's check (`ContainingDiskImageDevice`): the volume's device must be one that
    /// `hdiutil info` lists as backing a mounted image — so a read-only USB stick is never ejected.
    /// Returns the mount point to hand to `hdiutil detach`.
    private static func diskImageMountPoint(containing url: URL) -> String? {
        var stat = statfs()
        guard statfs(url.path, &stat) == 0, (stat.f_flags & UInt32(MNT_ROOTFS)) == 0 else { return nil }
        let device = withUnsafePointer(to: &stat.f_mntfromname) {
            String(cString: UnsafeRawPointer($0).assumingMemoryBound(to: CChar.self))
        }
        let mountPoint = withUnsafePointer(to: &stat.f_mntonname) {
            String(cString: UnsafeRawPointer($0).assumingMemoryBound(to: CChar.self))
        }
        guard diskImageDevices().contains(device) else { return nil }
        return mountPoint
    }

    /// Every `dev-entry` under `images[].system-entities[]` in `hdiutil info -plist`.
    private static func diskImageDevices() -> Set<String> {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
        task.arguments = ["info", "-plist"]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice
        do { try task.run() } catch { return [] }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        task.waitUntilExit()

        guard let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              let images = plist["images"] as? [[String: Any]] else { return [] }
        var devices = Set<String>()
        for image in images {
            for entity in image["system-entities"] as? [[String: Any]] ?? [] {
                if let dev = entity["dev-entry"] as? String { devices.insert(dev) }
            }
        }
        return devices
    }
}
