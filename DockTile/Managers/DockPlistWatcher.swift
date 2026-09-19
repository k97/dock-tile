//
//  DockPlistWatcher.swift
//  DockTile
//
//  Watches the Dock plist file for changes to detect when tiles are removed from Dock
//  Uses DispatchSource for efficient file monitoring
//  Swift 6 - Strict Concurrency
//

import Foundation

@MainActor
final class DockPlistWatcher {

    // MARK: - Properties

    private var fileDescriptor: Int32 = -1
    private var dispatchSource: DispatchSourceFileSystemObject?
    private lazy var debouncer = Debouncer(interval: debounceInterval)

    /// Callback when Dock plist changes
    var onDockChanged: (() -> Void)?

    /// Path to the Dock plist
    private let dockPlistPath: String

    /// Debounce interval (Dock can write multiple times quickly)
    private let debounceInterval: TimeInterval

    // MARK: - Initialization

    init(path: String? = nil, debounceInterval: TimeInterval = 0.5) {
        self.debounceInterval = debounceInterval
        dockPlistPath = path ?? FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Preferences/com.apple.dock.plist")
            .path

        print("👀 DockPlistWatcher initialized")
        print("   Watching: \(dockPlistPath)")
    }

    deinit {
        // Note: stopWatching() is called from MainActor context
        // For deinit, we do minimal cleanup
        if fileDescriptor != -1 {
            close(fileDescriptor)
        }
    }

    // MARK: - Public API

    /// Start watching the Dock plist for changes
    func startWatching() {
        // Don't start if already watching
        guard dispatchSource == nil else {
            print("   Already watching Dock plist")
            return
        }

        // Open file descriptor for the plist
        fileDescriptor = open(dockPlistPath, O_EVTONLY)

        guard fileDescriptor != -1 else {
            print("   ⚠️ Failed to open Dock plist for watching")
            return
        }

        // Create dispatch source to monitor file changes. `fd` is captured so THIS source closes
        // THIS descriptor, whatever `self.fileDescriptor` has become by the time it is cancelled.
        let fd = fileDescriptor
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .delete, .rename, .attrib],
            queue: .main
        )

        source.setEventHandler { [weak self, weak source] in
            guard let self else { return }
            let flags = source?.data ?? []
            self.handleFileChange()
            // cfprefsd rewrites the plist by ATOMIC REPLACE: this descriptor now refers to an
            // unlinked inode and every later write goes to a file we are not watching. Re-arm on
            // the path. Clearing `fileDescriptor` first lets `startWatching()` open a fresh one.
            if !flags.isDisjoint(with: [.rename, .delete]) {
                source?.cancel()
                self.dispatchSource = nil
                self.fileDescriptor = -1
                self.startWatching()
            }
        }

        source.setCancelHandler { [weak self] in
            close(fd)
            if self?.fileDescriptor == fd { self?.fileDescriptor = -1 }
        }

        dispatchSource = source
        source.resume()

        print("   ✓ Started watching Dock plist")
    }

    /// Stop watching the Dock plist
    func stopWatching() {
        debouncer.cancel()

        dispatchSource?.cancel()
        dispatchSource = nil

        print("   ✓ Stopped watching Dock plist")
    }

    // MARK: - Private Methods

    private func handleFileChange() {
        // The Dock can write its plist several times in quick succession; coalesce those into a
        // single sync so we don't fire `onDockChanged` repeatedly (and restart-loop the Dock).
        debouncer.call { [weak self] in
            guard let self = self else { return }
            print("🔄 Dock plist changed - triggering sync")
            self.onDockChanged?()
        }
    }
}

// MARK: - Debouncer

/// Coalesces rapid calls into a single trailing invocation: each `call` cancels the previous
/// pending work, so only the last call within `interval` actually runs. Extracted so the
/// coalescing behaviour is unit-testable (it previously lived inline and had no real test).
@MainActor
final class Debouncer {
    private let interval: TimeInterval
    private var workItem: DispatchWorkItem?

    init(interval: TimeInterval) {
        self.interval = interval
    }

    /// Schedule `action` after `interval`, cancelling any still-pending call first.
    func call(_ action: @escaping () -> Void) {
        workItem?.cancel()
        let item = DispatchWorkItem(block: action)
        workItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + interval, execute: item)
    }

    /// Cancel any pending call without firing it.
    func cancel() {
        workItem?.cancel()
        workItem = nil
    }
}

// MARK: - SaveDebounce

/// The wait half of a `.task(id:)` debounce. `try? await Task.sleep` cannot be used for this: it
/// swallows `CancellationError`, so a debounce superseded by a newer edit falls straight through to
/// its save — every keystroke, stepper tick and colour-drag tick then writes the whole config.
enum SaveDebounce {
    /// Sleeps for `nanoseconds`. Returns `false` when the task was cancelled while waiting — the
    /// caller must NOT save from the debounce in that case: either a newer edit owns the save, or
    /// the view is going away and its `onDisappear` flush owns it.
    static func waitedFullInterval(nanoseconds: UInt64) async -> Bool {
        do {
            try await Task.sleep(nanoseconds: nanoseconds)
            return true
        } catch {
            return false
        }
    }
}
