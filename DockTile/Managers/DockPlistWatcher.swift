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
    private var debounceWorkItem: DispatchWorkItem?

    /// Callback when Dock plist changes
    var onDockChanged: (() -> Void)?

    /// Path to the Dock plist
    private let dockPlistPath: String

    /// Debounce interval (Dock can write multiple times quickly)
    private let debounceInterval: TimeInterval = 0.5

    // MARK: - Initialization

    init() {
        dockPlistPath = FileManager.default.homeDirectoryForCurrentUser
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

        // Create dispatch source to monitor file changes
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: [.write, .delete, .rename, .attrib],
            queue: .main
        )

        source.setEventHandler { [weak self] in
            self?.handleFileChange()
        }

        source.setCancelHandler { [weak self] in
            if let fd = self?.fileDescriptor, fd != -1 {
                close(fd)
                self?.fileDescriptor = -1
            }
        }

        dispatchSource = source
        source.resume()

        print("   ✓ Started watching Dock plist")
    }

    /// Stop watching the Dock plist
    func stopWatching() {
        debounceWorkItem?.cancel()
        debounceWorkItem = nil

        dispatchSource?.cancel()
        dispatchSource = nil

        print("   ✓ Stopped watching Dock plist")
    }

    // MARK: - Private Methods

    private func handleFileChange() {
        // Cancel any pending debounced call
        debounceWorkItem?.cancel()

        // Create new debounced work item
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            print("🔄 Dock plist changed - triggering sync")
            self.onDockChanged?()
        }

        debounceWorkItem = workItem

        // Schedule after debounce interval
        DispatchQueue.main.asyncAfter(deadline: .now() + debounceInterval, execute: workItem)
    }
}
