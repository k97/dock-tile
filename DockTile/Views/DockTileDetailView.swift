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
import Carbon.HIToolbox  // For kVK_Escape key code

struct DockTileDetailView: View {
    @EnvironmentObject private var configManager: ConfigurationManager
    let config: DockTileConfiguration
    let onCustomise: () -> Void

    @State private var editedConfig: DockTileConfiguration
    @State private var tileName: String  // Separate state for TextField to avoid struct churn
    @State private var isProcessing = false
    @State private var errorMessage: String?
    @State private var showDeleteConfirmation = false
    @State private var showDockRestartConsent = false  // Show consent dialog for Dock restart
    @State private var hasAppearedOnce = false  // Track if view has fully loaded
    @State private var isCurrentlyInDock = false  // Track actual Dock state
    @FocusState private var isNameFieldFocused: Bool  // Track focus for commit-on-blur

    /// Dynamic button text based on toggle state and actual Dock presence
    private var actionButtonText: String {
        if editedConfig.isVisibleInDock {
            // User wants tile in Dock
            return isCurrentlyInDock ? AppStrings.Button.update : AppStrings.Button.addToDock
        } else {
            // User wants tile removed from Dock
            return isCurrentlyInDock ? AppStrings.Button.removeFromDock : AppStrings.Button.done
        }
    }

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
        // Toolbar with dynamic action button
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(actionButtonText) {
                    handleDockAction()
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
        .alert(AppStrings.Title.deleteTile, isPresented: $showDeleteConfirmation) {
            Button(AppStrings.Button.cancel, role: .cancel) {}
            Button(AppStrings.Button.delete, role: .destructive) {
                deleteTile()
            }
        } message: {
            Text("This will permanently delete the tile and remove it from the dock.")
        }
        .onChange(of: showDockRestartConsent) { _, newValue in
            if newValue {
                // Defer alert presentation to avoid SwiftUI transaction warning
                DispatchQueue.main.async {
                    showDockRestartConsentAlert()
                }
            }
        }
        // NOTE: .onChange(of: config.id) removed - parent view uses .id(selectedConfig.id)
        // to force complete view recreation when switching configs, making sync unnecessary
        .onChange(of: editedConfig) { _, _ in
            // Mark as edited immediately when any field changes (enables + button)
            // Skip the initial load to avoid immediately marking new tiles as edited
            guard hasAppearedOnce else { return }
            // Defer to avoid "Publishing changes from within view updates" warning
            DispatchQueue.main.async {
                configManager.markSelectedConfigAsEdited()
            }
        }
        // NOTE: tileName onChange removed - tileName now syncs to editedConfig.name
        // on every keystroke (see TextField onChange), which triggers this onChange
        // Debounced auto-save using task(id:) - cancels previous task when editedConfig changes
        .task(id: editedConfig) {
            guard hasAppearedOnce else { return }

            // Wait 300ms before saving (debounce)
            try? await Task.sleep(nanoseconds: 300_000_000)

            // Save editedConfig directly - it already has the correct ID and bundleIdentifier
            // NOTE: We must NOT use config.id or config.bundleIdentifier here because
            // when switching between tiles, `config` may be stale while `editedConfig`
            // has already been updated by the .onChange(of: config.id) handler
            configManager.updateConfiguration(editedConfig)
        }
        .onAppear {
            // Check actual Dock state on appear
            updateDockState()

            // Delay setting hasAppearedOnce to skip initial onChange triggers
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                hasAppearedOnce = true
            }
        }
        .onChange(of: editedConfig.isVisibleInDock) { _, _ in
            // Update button text when toggle changes
            updateDockState()
        }
        .onChange(of: configManager.configurations) { _, newConfigs in
            // Sync editedConfig when underlying configuration changes (e.g., from CustomiseTileView)
            // NOTE: We intentionally do NOT sync isVisibleInDock here because:
            // 1. User might be in the middle of editing and toggled "Show Tile" ON
            // 2. Dock watcher might fire and think the tile should be OFF
            // 3. This would reset the user's toggle before they can click "Done"
            // The correct state will be set when user clicks "Done" and we install/uninstall
            if let updatedConfig = newConfigs.first(where: { $0.id == editedConfig.id }) {
                // Defer state updates to avoid "Publishing changes from within view updates" warning
                // This is necessary because .onChange fires during the view update cycle
                DispatchQueue.main.async {
                    // Sync icon-related properties (may be changed in CustomiseTileView)
                    if editedConfig.iconType != updatedConfig.iconType {
                        editedConfig.iconType = updatedConfig.iconType
                    }
                    if editedConfig.iconValue != updatedConfig.iconValue {
                        editedConfig.iconValue = updatedConfig.iconValue
                    }
                    if editedConfig.iconScale != updatedConfig.iconScale {
                        editedConfig.iconScale = updatedConfig.iconScale
                    }
                    if editedConfig.tintColor != updatedConfig.tintColor {
                        editedConfig.tintColor = updatedConfig.tintColor
                    }
                    if editedConfig.symbolEmoji != updatedConfig.symbolEmoji {
                        editedConfig.symbolEmoji = updatedConfig.symbolEmoji
                    }
                    // Sync showInAppSwitcher if it was changed externally
                    if editedConfig.showInAppSwitcher != updatedConfig.showInAppSwitcher {
                        editedConfig.showInAppSwitcher = updatedConfig.showInAppSwitcher
                    }
                }
            }
        }
    }

    // MARK: - Hero Section (Figma Spec)

    private var heroSection: some View {
        HStack(alignment: .center, spacing: 16) {
            // Left column: Icon preview with Customise button
            VStack(alignment: .center, spacing: 12) {
                // Icon container: 118×118pt
                // Uses DockTileIconPreview which is appearance-aware (light/dark mode)
                // Tappable to open customise view
                DockTileIconPreview(
                    tintColor: editedConfig.tintColor,
                    iconType: editedConfig.iconType,
                    iconValue: editedConfig.iconValue,
                    iconScale: editedConfig.iconScale,
                    size: 118
                )
                .contentShape(RoundedRectangle(cornerRadius: 118 * 0.225, style: .continuous))
                .onHover { hovering in
                    if hovering {
                        NSCursor.pointingHand.push()
                    } else {
                        NSCursor.pop()
                    }
                }
                .onTapGesture {
                    onCustomise()
                }

                SubtleButton(title: AppStrings.Button.customise, width: 118, action: onCustomise)
            }

            // Right column: Custom Form Group
            VStack(spacing: 0) {
                // Row 1: Tile Name
                formRow(isLast: false) {
                    Text(AppStrings.Label.tileName)
                    Spacer()
                    TextField("", text: $tileName)
                        .textFieldStyle(.plain)
                        .multilineTextAlignment(.trailing)
                        .focused($isNameFieldFocused)
                        .onChange(of: tileName) { _, newName in
                            // Sync to editedConfig on every keystroke
                            // This triggers the debounced auto-save and updates sidebar
                            guard hasAppearedOnce else { return }
                            if editedConfig.name != newName {
                                editedConfig.name = newName
                            }
                        }
                }

                // Row 2: Show Tile
                formRow(isLast: false) {
                    Text(AppStrings.Label.showTile)
                    Spacer()
                    Toggle("", isOn: $editedConfig.isVisibleInDock)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }

                // Row 3: Layout
                formRow(isLast: false) {
                    Text(AppStrings.Label.layout)
                    Spacer()
                    Picker("", selection: $editedConfig.layoutMode) {
                        Text(AppStrings.Layout.grid).tag(LayoutMode.grid)
                        Text(AppStrings.Layout.list).tag(LayoutMode.list)
                    }
                    .labelsHidden()
                }

                // Row 4: Show in App Switcher (last row, no separator)
                formRow(isLast: true) {
                    Text(AppStrings.Label.showInAppSwitcher)
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

    // MARK: - Items Table Section

    @State private var selectedAppIDs: Set<AppItem.ID> = []

    private var appsTableSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(AppStrings.Section.selectedItems)
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
                    .disabled(selectedAppIDs.isEmpty)

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
                    Text(AppStrings.Button.removeFromDock)
                        .font(.system(size: 13))
                        .foregroundColor(.primary)

                    Text("This removes the tile only, and your apps or folders stay intact")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }

                Spacer()

                SubtleButton(
                    title: AppStrings.Button.remove,
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

    /// Check if tile is currently in Dock and update state
    private func updateDockState() {
        isCurrentlyInDock = HelperBundleManager.shared.findInDock(bundleId: editedConfig.bundleIdentifier) != nil
    }

    private func handleDockAction() {
        // Check if user has already acknowledged Dock restart
        let hasAcknowledged = UserDefaults.standard.bool(forKey: "hasAcknowledgedDockRestart")

        if !hasAcknowledged {
            // Show consent dialog
            showDockRestartConsent = true
        } else {
            // Proceed directly
            performDockAction()
        }
    }

    private func performDockAction() {
        isProcessing = true
        errorMessage = nil

        Task {
            do {
                // editedConfig.name is already synced with tileName on every keystroke
                var configToSave = editedConfig

                // Check if showInAppSwitcher changed (requires helper restart)
                // Compare against the stored config in manager, not the stale `config` property
                let originalConfig = configManager.configuration(for: editedConfig.id)
                let appSwitcherChanged = originalConfig?.showInAppSwitcher != configToSave.showInAppSwitcher

                // Install or uninstall based on Show Tile toggle
                if configToSave.isVisibleInDock {
                    // User wants tile in Dock - install/update
                    // Clear lastDockIndex after successful install (position is now live in Dock)
                    try await HelperBundleManager.shared.installHelper(for: configToSave)
                    configToSave.lastDockIndex = nil  // Clear saved position
                    print("✅ Helper installed: \(configToSave.name)")
                    print("   User can open it from: ~/Library/Application Support/DockTile/")
                } else {
                    // User wants tile removed - save position before removal
                    // Remove from Dock plist regardless of whether bundle exists
                    print("🗑️ Removing tile from Dock: \(configToSave.name)")
                    let savedPosition = try await HelperBundleManager.shared.removeFromDock(for: configToSave)
                    if let position = savedPosition {
                        configToSave.lastDockIndex = position
                        print("   📍 Saved Dock position: \(position) for later restoration")
                    }
                    print("✅ Tile removed from Dock: \(configToSave.name)")
                }

                // Save configuration changes (including lastDockIndex)
                configManager.updateConfiguration(configToSave)

                // If only showInAppSwitcher changed but tile was already visible,
                // we need to restart the helper to pick up the new activation policy
                if appSwitcherChanged && isCurrentlyInDock && configToSave.isVisibleInDock {
                    print("🔄 App Switcher setting changed - helper was restarted")
                }

                // Update local state to match saved config
                editedConfig = configToSave
                tileName = configToSave.name

                // Refresh dock state after action
                updateDockState()
            } catch {
                errorMessage = error.localizedDescription
                print("Dock action failed: \(error)")
            }
            isProcessing = false
        }
    }

    private func showDockRestartConsentAlert() {
        // Create native NSAlert with checkbox
        let alert = NSAlert()
        alert.messageText = AppStrings.Alert.restartDockTitle
        alert.informativeText = AppStrings.Alert.restartDockMessage
        alert.alertStyle = .warning
        alert.addButton(withTitle: AppStrings.Button.confirm)
        alert.addButton(withTitle: AppStrings.Button.cancel)

        // Add "Don't show this again" checkbox (left-aligned, macOS default)
        let checkbox = NSButton(checkboxWithTitle: AppStrings.Alert.restartDockCheckbox, target: nil, action: nil)
        checkbox.state = .off  // Default unchecked

        alert.accessoryView = checkbox

        // Show alert modally
        let response = alert.runModal()

        // Reset state
        showDockRestartConsent = false

        // Handle response
        if response == .alertFirstButtonReturn {
            // User clicked "Confirm"
            // Check if "Don't show this again" was checked
            if checkbox.state == .on {
                UserDefaults.standard.set(true, forKey: "hasAcknowledgedDockRestart")
            }
            // Proceed with dock action
            performDockAction()
        }
        // If user clicked "Cancel", do nothing
    }

    private func deleteTile() {
        // Delete will handle uninstalling helper if needed
        // Use editedConfig.id to ensure we delete the correct tile
        configManager.deleteConfiguration(editedConfig.id)
    }

    private func removeSelectedApp() {
        // Remove all selected apps
        guard !selectedAppIDs.isEmpty else { return }
        editedConfig.appItems.removeAll { selectedAppIDs.contains($0.id) }
        selectedAppIDs.removeAll()
    }

    private func addItem() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.application, .folder]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.treatsFilePackagesAsDirectories = false
        panel.prompt = AppStrings.Button.add
        panel.message = AppStrings.FilePicker.message

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

    // Track last clicked index for Shift+Click range selection
    @State private var lastClickedIndex: Int? = nil

    // Track the item being dragged for reordering
    @State private var draggedItem: AppItem? = nil

    // Event monitor for Escape key (to clear multi-selection)
    @State private var eventMonitor: Any? = nil

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
                Text(AppStrings.Table.item)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(AppStrings.Table.kind)
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
                            // Drag handle (grip lines)
                            Image(systemName: "line.3.horizontal")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.tertiary)
                                .frame(width: 16)
                                .onHover { hovering in
                                    if hovering {
                                        NSCursor.openHand.push()
                                    } else {
                                        NSCursor.pop()
                                    }
                                }

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
                            handleRowTap(index: index, item: item)
                        }
                        // Drag and drop for reordering
                        .onDrag {
                            draggedItem = item
                            return NSItemProvider(object: item.id.uuidString as NSString)
                        }
                        .onDrop(of: [.text], delegate: AppItemDropDelegate(
                            item: item,
                            items: $items,
                            draggedItem: $draggedItem
                        ))
                    }
                }
            }
        }
        // Set up Escape key monitor to clear multi-selection
        .onAppear {
            setupEscapeKeyMonitor()
        }
        .onDisappear {
            removeEscapeKeyMonitor()
        }
    }

    // MARK: - Escape Key Monitor (NSEvent Local Monitor)

    private func setupEscapeKeyMonitor() {
        // Only set up if not already monitoring
        guard eventMonitor == nil else { return }

        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if Int(event.keyCode) == kVK_Escape && selection.count > 1 {
                // Clear selection when Escape pressed with multiple items selected
                DispatchQueue.main.async {
                    selection.removeAll()
                }
                return nil  // Consume the event (prevents system beep)
            }
            return event  // Pass through other key events
        }
    }

    private func removeEscapeKeyMonitor() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }

    // MARK: - Row Tap Handler (Multi-select)

    private func handleRowTap(index: Int, item: AppItem) {
        let modifiers = NSEvent.modifierFlags

        if modifiers.contains(.command) {
            // Cmd+Click: Toggle individual selection
            if selection.contains(item.id) {
                selection.remove(item.id)
            } else {
                selection.insert(item.id)
            }
            lastClickedIndex = index
        } else if modifiers.contains(.shift), let lastIndex = lastClickedIndex {
            // Shift+Click: Range selection from last clicked to current
            let range = min(lastIndex, index)...max(lastIndex, index)
            for i in range {
                if i < items.count {
                    selection.insert(items[i].id)
                }
            }
        } else {
            // Regular click: Single selection (replaces previous selection)
            selection = [item.id]
            lastClickedIndex = index
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Text(AppStrings.Empty.noItemsAdded)
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
        item.isFolder ? AppStrings.Kind.folder : AppStrings.Kind.application
    }
}

// MARK: - Drop Delegate for Reordering

struct AppItemDropDelegate: DropDelegate {
    let item: AppItem
    @Binding var items: [AppItem]
    @Binding var draggedItem: AppItem?

    func performDrop(info: DropInfo) -> Bool {
        draggedItem = nil
        return true
    }

    func dropEntered(info: DropInfo) {
        guard let draggedItem = draggedItem,
              draggedItem.id != item.id,
              let fromIndex = items.firstIndex(where: { $0.id == draggedItem.id }),
              let toIndex = items.firstIndex(where: { $0.id == item.id }) else {
            return
        }

        withAnimation(.easeInOut(duration: 0.2)) {
            items.move(fromOffsets: IndexSet(integer: fromIndex), toOffset: toIndex > fromIndex ? toIndex + 1 : toIndex)
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        return DropProposal(operation: .move)
    }
}

// MARK: - App Icon View

struct AppIconView: View {
    let item: AppItem

    // Observe IconStyleManager for icon style changes
    // This triggers view refresh when system icon style changes
    @ObservedObject private var iconStyleManager = IconStyleManager.shared

    private func getAppIcon() -> NSImage? {
        // For folders, get icon from folder path
        if item.isFolder, let folderPath = item.folderPath {
            return NSWorkspace.shared.icon(forFile: folderPath)
        }

        // Get from bundle identifier - returns style-aware icon from macOS
        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: item.bundleIdentifier) {
            return NSWorkspace.shared.icon(forFile: appURL.path)
        }

        // Try common paths for apps
        let searchPaths = [
            "/Applications/\(item.name).app",
            "/System/Applications/\(item.name).app",
            "/Applications/Utilities/\(item.name).app",
            "\(NSHomeDirectory())/Applications/\(item.name).app"
        ]

        for path in searchPaths {
            if FileManager.default.fileExists(atPath: path) {
                return NSWorkspace.shared.icon(forFile: path)
            }
        }

        // Fallback to stored icon data if fresh fetch fails
        if let iconData = item.iconData,
           let nsImage = NSImage(data: iconData) {
            return nsImage
        }

        return nil
    }

    var body: some View {
        // Reference iconStyleManager.currentStyle to trigger re-render when icon style changes
        // This ensures NSWorkspace returns the correct style-aware icon
        let _ = iconStyleManager.currentStyle

        if let icon = getAppIcon() {
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
        .onHover { hovering in
            if hovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
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
