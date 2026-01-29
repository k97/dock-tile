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
    @State private var showingFilePicker = false
    @State private var isProcessing = false
    @State private var errorMessage: String?
    @State private var showDeleteConfirmation = false

    init(config: DockTileConfiguration, onCustomise: @escaping () -> Void) {
        self.config = config
        self.onCustomise = onCustomise
        self._editedConfig = State(initialValue: config)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header with title and Done button
            headerSection

            Divider()

            // Main content
            ScrollView {
                VStack(spacing: 24) {
                    // Top row: Icon + Settings
                    topSettingsSection

                    Divider()

                    // Selected Apps table
                    appsTableSection

                    Divider()

                    // Delete section
                    deleteSection
                }
                .padding(24)
            }
        }
        .sheet(isPresented: $showingFilePicker) {
            AppPickerView(onSelect: { appURL in
                if let appItem = AppItem.from(appURL: appURL) {
                    editedConfig.appItems.append(appItem)
                }
                showingFilePicker = false
            })
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
            if let updatedConfig = newConfigs.first(where: { $0.id == config.id }) {
                // Only sync isVisibleInDock to avoid overwriting user's edits
                if editedConfig.isVisibleInDock != updatedConfig.isVisibleInDock {
                    editedConfig.isVisibleInDock = updatedConfig.isVisibleInDock
                }
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        HStack {
            Text("Dock Tile Configurator")
                .font(.headline)

            Spacer()

            if isProcessing {
                ProgressView()
                    .controlSize(.small)
                    .padding(.trailing, 8)
            }

            Button("Done") {
                handleDone()
            }
            .buttonStyle(.borderedProminent)
            .disabled(isProcessing)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }

    // MARK: - Top Settings Section

    private var topSettingsSection: some View {
        HStack(alignment: .top, spacing: 24) {
            // Icon preview with Customise button
            VStack(spacing: 12) {
                DockTileIconPreview(
                    tintColor: editedConfig.tintColor,
                    symbol: editedConfig.symbolEmoji,
                    size: 80
                )

                Button(action: onCustomise) {
                    Text("Customise")
                        .frame(width: 100)
                }
                .buttonStyle(.bordered)
            }

            // Settings fields
            VStack(alignment: .leading, spacing: 16) {
                // Tile Name
                HStack {
                    Text("Tile Name")
                        .frame(width: 80, alignment: .leading)
                    TextField("Tile Name", text: $editedConfig.name)
                        .textFieldStyle(.roundedBorder)
                }

                // Show Tile toggle
                HStack {
                    Text("Show Tile")
                        .frame(width: 80, alignment: .leading)
                    Toggle("", isOn: $editedConfig.isVisibleInDock)
                        .toggleStyle(.switch)
                        .labelsHidden()
                }

                // Layout picker
                HStack {
                    Text("Layout")
                        .frame(width: 80, alignment: .leading)
                    Picker("", selection: $editedConfig.layoutMode) {
                        Text("Grid").tag(LayoutMode.grid2x3)
                        Text("Horizontal").tag(LayoutMode.horizontal1x6)
                    }
                    .pickerStyle(.menu)
                    .frame(width: 120)
                }
            }

            Spacer()
        }
    }

    // MARK: - Apps Table Section

    @State private var selectedAppIDs: Set<AppItem.ID> = []

    private var appsTableSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Selected Apps")
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
                    Button(action: { showingFilePicker = true }) {
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
                    bundleIdentifier: config.bundleIdentifier  // Preserve original bundle ID
                )

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
            Text("No apps added yet")
                .foregroundStyle(.secondary)
            Text("Click + to add applications")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func itemKind(for item: AppItem) -> String {
        if item.bundleIdentifier.contains("folder") || item.name.lowercased().contains("folder") {
            return "Folder"
        }
        return "Application"
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
            Image(systemName: "app.fill")
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - App Picker View

struct AppPickerView: View {
    let onSelect: (URL) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            Text("Select an Application")
                .font(.title2)

            Button("Browse...") {
                selectApp()
            }
            .controlSize(.large)

            Button("Cancel") {
                dismiss()
            }
        }
        .padding(40)
        .frame(width: 400, height: 200)
    }

    private func selectApp() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false  // Only allow .app bundles
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.treatsFilePackagesAsDirectories = false  // Treat .app as single item

        if panel.runModal() == .OK, let url = panel.url {
            onSelect(url)
        }

        dismiss()
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
