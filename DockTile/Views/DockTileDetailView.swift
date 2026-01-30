//
//  DockTileDetailView.swift
//  DockTile
//
//  Detail panel showing configuration settings (Screen 3 right panel)
//  Redesigned to match new UI with Done button triggering installation
//  Swift 6 - Strict Concurrency
//

import SwiftUI
import AppKit

struct DockTileDetailView: View {
    @EnvironmentObject private var configManager: ConfigurationManager
    let config: DockTileConfiguration
    let onCustomise: () -> Void

    @State private var editedConfig: DockTileConfiguration
    @State private var isProcessing = false
    @State private var errorMessage: String?
    @State private var showDeleteConfirmation = false

    init(config: DockTileConfiguration, onCustomise: @escaping () -> Void) {
        self.config = config
        self.onCustomise = onCustomise
        self._editedConfig = State(initialValue: config)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Hero section: Icon + Grouped Controls
                heroSection

                // Selected Apps table
                appsTableSection

                // Delete section
                deleteSection
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(nsColor: .windowBackgroundColor))
        // Toolbar with Done button (macOS Contacts style)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    handleDone()
                }
                .buttonStyle(.borderedProminent)
                .disabled(isProcessing)
            }

            if isProcessing {
                ToolbarItem(placement: .automatic) {
                    ProgressView()
                        .controlSize(.small)
                }
            }
        }
        .alert("Delete Tile", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                deleteTile()
            }
        } message: {
            Text("This will permanently delete the tile and remove it from the dock.")
        }
        .onChange(of: config.id) { _, newId in
            // Sync editedConfig when switching to a different configuration
            if let newConfig = configManager.configuration(for: newId) {
                editedConfig = newConfig
            }
        }
        .onChange(of: configManager.configurations) { _, newConfigs in
            // Sync editedConfig when underlying configuration changes (e.g., dock visibility sync)
            // NOTE: We intentionally do NOT sync isVisibleInDock here because:
            // 1. User might be in the middle of editing and toggled "Show Tile" ON
            // 2. Dock watcher might fire and think the tile should be OFF
            // 3. This would reset the user's toggle before they can click "Done"
            // The correct state will be set when user clicks "Done" and we install/uninstall
            if let updatedConfig = newConfigs.first(where: { $0.id == config.id }) {
                // Only sync showInAppSwitcher if it was changed externally
                if editedConfig.showInAppSwitcher != updatedConfig.showInAppSwitcher {
                    editedConfig.showInAppSwitcher = updatedConfig.showInAppSwitcher
                }
            }
        }
    }

    // MARK: - Hero Section (System Settings Style)

    private var heroSection: some View {
        HStack(alignment: .top, spacing: 20) {
            // Left column: Icon preview with Customise button
            VStack(spacing: 12) {
                DockTileIconPreview(
                    tintColor: editedConfig.tintColor,
                    symbol: editedConfig.symbolEmoji,
                    size: 96
                )

                Button(action: onCustomise) {
                    Text("Customise")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(.top, 8)

            // Right column: Native Inset Grouped Form
            Form {
                Section {
                    TextField("Tile Name", text: $editedConfig.name)

                    Toggle("Show Tile", isOn: $editedConfig.isVisibleInDock)

                    Picker("Layout", selection: $editedConfig.layoutMode) {
                        ForEach([LayoutMode.grid2x3, LayoutMode.horizontal1x6], id: \.self) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }

                    Toggle("Show in App Switcher", isOn: $editedConfig.showInAppSwitcher)
                }
            }
            .formStyle(.grouped)
            .scrollDisabled(true)
            .scrollContentBackground(.hidden)
            .frame(minHeight: 180)
        }
    }

    // MARK: - Items Table Section

    @State private var selectedAppIDs: Set<AppItem.ID> = []

    private var appsTableSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Selected Items")
                .font(.headline)
                .padding(.bottom, 12)

            // Native-style table container
            VStack(spacing: 0) {
                // Table with border
                NativeAppsTableView(
                    items: $editedConfig.appItems,
                    selection: $selectedAppIDs
                )
                .frame(minHeight: 180, maxHeight: 240)

                // Bottom toolbar with +/- buttons
                HStack(spacing: 0) {
                    Button(action: addItem) {
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .regular))
                            .frame(width: 24, height: 20)
                    }
                    .buttonStyle(.borderless)

                    Divider()
                        .frame(height: 16)

                    Button(action: removeSelectedApp) {
                        Image(systemName: "minus")
                            .font(.system(size: 12, weight: .regular))
                            .frame(width: 24, height: 20)
                    }
                    .buttonStyle(.borderless)
                    .disabled(selectedAppIDs.isEmpty && editedConfig.appItems.isEmpty)

                    Spacer()
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 4)
                .background(Color(nsColor: .windowBackgroundColor).opacity(0.5))
            }
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
            )

            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.top, 8)
            }
        }
    }

    // MARK: - Delete Section

    private var deleteSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Delete Tile Instance")
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text("This will permanently delete the tile and removed from the dock")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button("Delete") {
                showDeleteConfirmation = true
            }
            .buttonStyle(.bordered)
            .tint(.red)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.red.opacity(0.05))
        )
    }

    // MARK: - Actions

    private func handleDone() {
        isProcessing = true
        errorMessage = nil

        Task {
            do {
                // Create config with original ID but edited values
                let configToSave = DockTileConfiguration(
                    id: config.id,  // Preserve original ID
                    name: editedConfig.name,
                    tintColor: editedConfig.tintColor,
                    symbolEmoji: editedConfig.symbolEmoji,
                    layoutMode: editedConfig.layoutMode,
                    appItems: editedConfig.appItems,
                    isVisibleInDock: editedConfig.isVisibleInDock,
                    showInAppSwitcher: editedConfig.showInAppSwitcher,
                    bundleIdentifier: config.bundleIdentifier  // Preserve original bundle ID
                )

                // Check if showInAppSwitcher changed (requires helper restart)
                let appSwitcherChanged = config.showInAppSwitcher != editedConfig.showInAppSwitcher

                // Save configuration changes first
                configManager.updateConfiguration(configToSave)

                // Install or uninstall based on Show Tile toggle
                if configToSave.isVisibleInDock {
                    try await HelperBundleManager.shared.installHelper(for: configToSave)
                    print("✅ Helper installed: \(configToSave.name)")
                    print("   User can open it from: ~/Library/Application Support/DockTile/")
                } else {
                    // If toggle is off, uninstall if previously installed
                    if HelperBundleManager.shared.helperExists(for: configToSave) {
                        try HelperBundleManager.shared.uninstallHelper(for: configToSave)
                        print("Tile removed from Dock: \(configToSave.name)")
                    }
                }

                // If only showInAppSwitcher changed but tile was already visible,
                // we need to restart the helper to pick up the new activation policy
                if appSwitcherChanged && config.isVisibleInDock && configToSave.isVisibleInDock {
                    print("🔄 App Switcher setting changed - helper was restarted")
                }

                // Update local state to match saved config
                editedConfig = configToSave
            } catch {
                errorMessage = error.localizedDescription
                print("Done action failed: \(error)")
            }
            isProcessing = false
        }
    }

    private func deleteTile() {
        // Delete will handle uninstalling helper if needed
        configManager.deleteConfiguration(config.id)
    }

    private func removeSelectedApp() {
        // Remove selected apps, or last app if none selected
        if !selectedAppIDs.isEmpty {
            editedConfig.appItems.removeAll { selectedAppIDs.contains($0.id) }
            selectedAppIDs.removeAll()
        } else if !editedConfig.appItems.isEmpty {
            editedConfig.appItems.removeLast()
        }
    }

    private func addItem() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.application, .folder]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.treatsFilePackagesAsDirectories = false
        panel.prompt = "Add"
        panel.message = "Select an application or folder to add"

        if panel.runModal() == .OK, let url = panel.url {
            var isDirectory: ObjCBool = false
            FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)

            if isDirectory.boolValue && !url.pathExtension.lowercased().contains("app") {
                // It's a folder (not an .app bundle)
                let folderPath = url.path
                if editedConfig.appItems.contains(where: { $0.folderPath == folderPath }) {
                    NSSound.beep()
                    return
                }
                if let folderItem = AppItem.from(folderURL: url) {
                    editedConfig.appItems.append(folderItem)
                }
            } else {
                // It's an application
                if let bundle = Bundle(url: url),
                   let bundleId = bundle.bundleIdentifier,
                   editedConfig.appItems.contains(where: { $0.bundleIdentifier == bundleId }) {
                    NSSound.beep()
                    return
                }
                if let appItem = AppItem.from(appURL: url) {
                    editedConfig.appItems.append(appItem)
                }
            }
        }
    }
}

// MARK: - Native Apps Table View

struct NativeAppsTableView: View {
    @Binding var items: [AppItem]
    @Binding var selection: Set<AppItem.ID>

    var body: some View {
        if items.isEmpty {
            emptyState
        } else {
            Table(items, selection: $selection) {
                TableColumn("Item") { item in
                    HStack(spacing: 8) {
                        AppIconView(item: item)
                            .frame(width: 16, height: 16)

                        Text(item.name)
                            .lineLimit(1)
                    }
                }
                .width(min: 150, ideal: 300)

                TableColumn("Kind") { item in
                    Text(itemKind(for: item))
                        .foregroundStyle(.secondary)
                }
                .width(min: 80, ideal: 100)
            }
            .tableStyle(.inset(alternatesRowBackgrounds: true))
            .scrollContentBackground(.hidden)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Text("No items added yet")
                .foregroundStyle(.secondary)
            Text("Click + to add applications or folders")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func itemKind(for item: AppItem) -> String {
        item.isFolder ? "Folder" : "Application"
    }
}

// MARK: - App Icon View

struct AppIconView: View {
    let item: AppItem

    private var appIcon: NSImage? {
        // Try to get from stored data
        if let iconData = item.iconData,
           let image = NSImage(data: iconData) {
            return image
        }

        // For folders, get icon from folder path
        if item.isFolder, let folderPath = item.folderPath {
            return NSWorkspace.shared.icon(forFile: folderPath)
        }

        // Try to get from bundle identifier
        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: item.bundleIdentifier) {
            return NSWorkspace.shared.icon(forFile: appURL.path)
        }

        return nil
    }

    var body: some View {
        if let icon = appIcon {
            Image(nsImage: icon)
                .resizable()
                .interpolation(.high)
        } else {
            Image(systemName: item.isFolder ? "folder.fill" : "app.fill")
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Preview

#Preview {
    DockTileDetailView(
        config: DockTileConfiguration(
            name: "AI Tile",
            tintColor: .green,
            symbolEmoji: "✨",
            appItems: [
                AppItem(bundleIdentifier: "com.openai.chatgpt", name: "Chat GPT"),
                AppItem(bundleIdentifier: "com.google.gemini", name: "Google Gemini"),
                AppItem(bundleIdentifier: "com.anthropic.claude", name: "Claude AI")
            ]
        ),
        onCustomise: {}
    )
    .environmentObject(ConfigurationManager())
    .frame(width: 600, height: 700)
}
