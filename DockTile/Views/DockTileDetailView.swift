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

    private var appsTableSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Selected Apps")
                    .font(.headline)

                Spacer()

                Text("Total Apps (\(editedConfig.appItems.count))")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            // Table header
            HStack {
                Text("Item")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text("Kind")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 120, alignment: .leading)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)

            // Table content
            if editedConfig.appItems.isEmpty {
                emptyAppsPlaceholder
            } else {
                VStack(spacing: 0) {
                    ForEach(editedConfig.appItems) { item in
                        AppTableRow(item: item)

                        if item.id != editedConfig.appItems.last?.id {
                            Divider()
                                .padding(.leading, 12)
                        }
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color(nsColor: .controlBackgroundColor))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
                )
            }

            // Add/Remove buttons
            HStack(spacing: 4) {
                Button(action: { showingFilePicker = true }) {
                    Image(systemName: "plus")
                }
                .buttonStyle(.borderless)

                Button(action: removeSelectedApp) {
                    Image(systemName: "minus")
                }
                .buttonStyle(.borderless)
                .disabled(editedConfig.appItems.isEmpty)

                Spacer()
            }

            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
    }

    private var emptyAppsPlaceholder: some View {
        VStack(spacing: 8) {
            Text("No apps added yet")
                .foregroundColor(.secondary)
            Text("Click + to add applications")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
        )
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
        // Remove last app (simple implementation)
        if !editedConfig.appItems.isEmpty {
            editedConfig.appItems.removeLast()
        }
    }
}

// MARK: - App Table Row

struct AppTableRow: View {
    let item: AppItem

    private var itemKind: String {
        // Determine kind based on bundle identifier or name
        if item.bundleIdentifier.contains("folder") || item.name.lowercased().contains("folder") {
            return "Folder"
        }
        return "Application"
    }

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
        HStack(spacing: 8) {
            // App icon
            if let icon = appIcon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 20, height: 20)
            } else {
                Image(systemName: "app")
                    .frame(width: 20, height: 20)
            }

            // App name
            Text(item.name)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Kind
            Text(itemKind)
                .foregroundColor(.secondary)
                .frame(width: 120, alignment: .leading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
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
