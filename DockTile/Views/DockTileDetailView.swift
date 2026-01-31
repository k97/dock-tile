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
    @State private var tileName: String  // Separate state for TextField to avoid struct churn
    @State private var isProcessing = false
    @State private var errorMessage: String?
    @State private var showDeleteConfirmation = false
    @State private var hasAppearedOnce = false  // Track if view has fully loaded
    @FocusState private var isNameFieldFocused: Bool  // Track focus for commit-on-blur

    init(config: DockTileConfiguration, onCustomise: @escaping () -> Void) {
        self.config = config
        self.onCustomise = onCustomise
        self._editedConfig = State(initialValue: config)
        self._tileName = State(initialValue: config.name)
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
        // Toolbar with Add to Dock button
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Add to Dock") {
                    handleAddToDock()
                }
                .buttonStyle(.bordered)
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
                hasAppearedOnce = false  // Reset so we don't trigger on initial sync
                editedConfig = newConfig
                tileName = newConfig.name  // Sync the separate text field state
                // Re-enable after a short delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    hasAppearedOnce = true
                }
            }
        }
        .onChange(of: editedConfig) { _, _ in
            // Mark as edited immediately when any field changes (enables + button)
            // Skip the initial load to avoid immediately marking new tiles as edited
            guard hasAppearedOnce else { return }
            configManager.markSelectedConfigAsEdited()
        }
        // Mark as edited when typing (for + button), but don't sync to editedConfig yet
        .onChange(of: tileName) { _, _ in
            guard hasAppearedOnce else { return }
            configManager.markSelectedConfigAsEdited()
        }
        // Debounced auto-save using task(id:) - cancels previous task when editedConfig changes
        .task(id: editedConfig) {
            guard hasAppearedOnce else { return }

            // Wait 300ms before saving (debounce)
            try? await Task.sleep(nanoseconds: 300_000_000)

            // Save the edited config to persist changes (draft mode)
            let configToSave = DockTileConfiguration(
                id: config.id,
                name: editedConfig.name,
                tintColor: editedConfig.tintColor,
                symbolEmoji: editedConfig.symbolEmoji,
                iconType: editedConfig.iconType,
                iconValue: editedConfig.iconValue,
                layoutMode: editedConfig.layoutMode,
                appItems: editedConfig.appItems,
                isVisibleInDock: editedConfig.isVisibleInDock,
                showInAppSwitcher: editedConfig.showInAppSwitcher,
                bundleIdentifier: config.bundleIdentifier
            )
            configManager.updateConfiguration(configToSave)
        }
        .onAppear {
            // Delay setting hasAppearedOnce to skip initial onChange triggers
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                hasAppearedOnce = true
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

    // MARK: - Hero Section (Figma Spec)

    private var heroSection: some View {
        HStack(alignment: .center, spacing: 16) {
            // Left column: Icon preview with Customise button
            VStack(alignment: .center, spacing: 12) {
                // Icon container: 118×118pt with cornerRadius(24)
                ZStack {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [editedConfig.tintColor.colorTop, editedConfig.tintColor.colorBottom],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                    // Beveled glass effect (inner stroke)
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.5), lineWidth: 0.5)

                    // Icon content
                    iconContent
                }
                .frame(width: 118, height: 118)
                .shadow(
                    color: Color.black.opacity(0.2),
                    radius: 8,
                    x: 0,
                    y: 4
                )

                SubtleButton(title: "Customise", width: 118, action: onCustomise)
            }

            // Right column: Custom Form Group
            VStack(spacing: 0) {
                // Row 1: Tile Name
                formRow(isLast: false) {
                    Text("Tile Name")
                    Spacer()
                    TextField("", text: $tileName)
                        .textFieldStyle(.plain)
                        .multilineTextAlignment(.trailing)
                        .focused($isNameFieldFocused)
                        .onSubmit {
                            // Sync to editedConfig on Enter key
                            if editedConfig.name != tileName {
                                editedConfig.name = tileName
                            }
                        }
                        .onChange(of: isNameFieldFocused) { _, isFocused in
                            // Sync to editedConfig when field loses focus
                            if !isFocused && editedConfig.name != tileName {
                                editedConfig.name = tileName
                            }
                        }
                }

                // Row 2: Show Tile
                formRow(isLast: false) {
                    Text("Show Tile")
                    Spacer()
                    Toggle("", isOn: $editedConfig.isVisibleInDock)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }

                // Row 3: Layout
                formRow(isLast: false) {
                    Text("Layout")
                    Spacer()
                    Picker("", selection: $editedConfig.layoutMode) {
                        ForEach([LayoutMode.grid2x3, LayoutMode.horizontal1x6], id: \.self) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                    .labelsHidden()
                }

                // Row 4: Show in App Switcher (last row, no separator)
                formRow(isLast: true) {
                    Text("Show in App Switcher")
                    Spacer()
                    Toggle("", isOn: $editedConfig.showInAppSwitcher)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }
            }
            .padding(.horizontal, 10)
            .background(FormGroupBackground())
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Form Row Helper

    @ViewBuilder
    private func formRow<Content: View>(isLast: Bool, @ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                content()
            }
            .frame(height: 40)

            if !isLast {
                Rectangle()
                    .fill(Color(nsColor: .quinaryLabel))
                    .frame(height: 1)
            }
        }
    }

    // MARK: - Icon Content

    @ViewBuilder
    private var iconContent: some View {
        switch editedConfig.iconType {
        case .sfSymbol:
            Image(systemName: editedConfig.iconValue)
                .font(.system(size: 38, weight: .medium))
                .foregroundColor(.white)
                .shadow(color: Color.black.opacity(0.2), radius: 1, x: 0, y: 1)

        case .emoji:
            Text(editedConfig.iconValue)
                .font(.system(size: 38))
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
                // Table content (grows naturally with items)
                NativeAppsTableView(
                    items: $editedConfig.appItems,
                    selection: $selectedAppIDs
                )

                // Separator between table and toolbar
                Rectangle()
                    .fill(Color(nsColor: .separatorColor))
                    .frame(height: 1)

                // Bottom toolbar with +/- buttons (same bg as header/even rows)
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
                .background(Color(nsColor: NSColor.alternatingContentBackgroundColors[1]))
            }
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

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
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Remove from Dock")
                        .font(.system(size: 13))
                        .foregroundColor(.primary)

                    Text("This removes the tile only, and your apps or folders stay intact")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }

                Spacer()

                SubtleButton(
                    title: "Remove",
                    textColor: .red,
                    action: { showDeleteConfirmation = true }
                )
            }
            .frame(height: 42)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 0)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(FormGroupBackground())
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - Actions

    private func handleAddToDock() {
        isProcessing = true
        errorMessage = nil

        Task {
            do {
                // Create config with original ID but edited values
                // Use tileName directly in case there's a pending debounce sync
                let configToSave = DockTileConfiguration(
                    id: config.id,  // Preserve original ID
                    name: tileName,  // Use tileName directly for immediate save
                    tintColor: editedConfig.tintColor,
                    symbolEmoji: editedConfig.symbolEmoji,
                    iconType: editedConfig.iconType,
                    iconValue: editedConfig.iconValue,
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
                tileName = configToSave.name
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

    private let rowHeight: CGFloat = 28

    // Table row colors - using quaternarySystemFill for odd rows (matches form group)
    private var oddRowColor: Color {
        Color(nsColor: .quaternarySystemFill)
    }

    private var evenRowColor: Color {
        Color(nsColor: NSColor.alternatingContentBackgroundColors[1])
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header row - uses same color as even rows (slightly darker)
            HStack(spacing: 0) {
                Text("Item")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text("Kind")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                    .frame(width: 100, alignment: .leading)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(evenRowColor)

            Rectangle()
                .fill(Color(nsColor: .separatorColor))
                .frame(height: 1)

            if items.isEmpty {
                emptyState
            } else {
                // Item rows - grows naturally with content
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    VStack(spacing: 0) {
                        HStack(spacing: 0) {
                            // Item column
                            HStack(spacing: 8) {
                                AppIconView(item: item)
                                    .frame(width: 16, height: 16)

                                Text(item.name)
                                    .lineLimit(1)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)

                            // Kind column
                            Text(itemKind(for: item))
                                .foregroundStyle(.secondary)
                                .frame(width: 100, alignment: .leading)
                        }
                        .padding(.horizontal, 10)
                        .frame(height: rowHeight)
                        .background(
                            selection.contains(item.id)
                                ? Color.accentColor.opacity(0.2)
                                : (index % 2 == 0 ? oddRowColor : evenRowColor)
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if selection.contains(item.id) {
                                selection.remove(item.id)
                            } else {
                                selection = [item.id]
                            }
                        }
                    }
                }
            }
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
        .frame(maxWidth: .infinity)
        .frame(height: 80)
        .background(oddRowColor)
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

// MARK: - Subtle Button Component

/// A reusable button with subtle 5% black background overlay
/// Used for secondary actions like "Customise" and "Remove"
private struct SubtleButton: View {
    let title: String
    var textColor: Color = .primary
    var width: CGFloat? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12))
                .multilineTextAlignment(.center)
                .foregroundColor(textColor)
        }
        .buttonStyle(.plain)
        .frame(width: width, height: 24)
        .frame(maxWidth: width == nil ? nil : .none)
        .padding(.horizontal, width == nil ? 12 : 0)
        .background(Color.black.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}

// MARK: - Form Group Background (NSViewRepresentable for reliable AppKit color)

private struct FormGroupBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        view.wantsLayer = true
        // Using quaternarySystemFill for opaque quaternary fill (matches Figma FillsOpaqueQuaternary)
        view.layer?.backgroundColor = NSColor.quaternarySystemFill.cgColor
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        nsView.layer?.backgroundColor = NSColor.quaternarySystemFill.cgColor
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
