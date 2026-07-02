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
    /// Monotonic counter incremented on each config edit. Used as the `.task(id:)` identity
    /// instead of the full `editedConfig` struct, which avoids O(n * icon_data_size) deep equality
    /// checks on every keystroke. The task cancels/restarts on each increment, providing debounce.
    @State private var saveGeneration: Int = 0

    /// Fingerprint of the config content as of the last completed toolbar action (or view load).
    /// Drives the dirty state that gates the hidden-tile "Done" button. Seeded in `init` so a
    /// freshly opened tile starts clean (its edits were already persisted by the auto-save).
    @State private var appliedContentSignature: Int

    // MARK: - Action Resolution (pure seams, regression-guarded by DockActionResolutionTests)

    /// The concrete operation the toolbar action button performs. `saveOnly` is the critical
    /// case: a hidden, not-pinned tile has NO Dock work to do — acting on it must never reach
    /// HelperBundleManager (the "Dock restarts on every Done" regression).
    enum DockAction: Equatable {
        case install    // visible — add to Dock, or full helper re-render + restart if already pinned
        case remove     // hidden but still pinned — unpin (restarts the Dock)
        case saveOnly   // hidden and not pinned — persist edits only, never touch the Dock
    }

    nonisolated static func resolveDockAction(isVisibleInDock: Bool, isCurrentlyInDock: Bool) -> DockAction {
        if isVisibleInDock { return .install }
        return isCurrentlyInDock ? .remove : .saveOnly
    }

    /// Dock-touching actions stay enabled regardless of dirty state — the pending Dock op IS the
    /// change (and Update deliberately re-renders the helper on demand). Only the no-op-prone
    /// saveOnly "Done" requires new edits, so it can't be spammed into pointless work.
    nonisolated static func dockActionIsEnabled(action: DockAction, isDirty: Bool, isProcessing: Bool) -> Bool {
        guard !isProcessing else { return false }
        switch action {
        case .install, .remove: return true
        case .saveOnly: return isDirty
        }
    }

    /// Cheap fingerprint of the user-editable content. Deliberately EXCLUDES bookkeeping that
    /// `performDockAction` writes back after a successful action (`lastDockIndex`,
    /// `helperAppVersion`) — including those would immediately re-dirty the button — and
    /// `isVisibleInDock` (visibility selects WHICH action shows, it isn't content). App items are
    /// identified by `id` (items are added/removed, never edited in place), which keeps this free
    /// of the O(n × icon_data_size) full-struct equality the view avoids elsewhere.
    nonisolated static func contentSignature(of config: DockTileConfiguration) -> Int {
        var hasher = Hasher()
        hasher.combine(config.name)
        hasher.combine(config.tintColor)
        hasher.combine(config.symbolEmoji)
        hasher.combine(config.iconType)
        hasher.combine(config.iconValue)
        hasher.combine(config.iconScale)
        hasher.combine(config.iconWeight)
        hasher.combine(config.layoutMode)
        hasher.combine(config.showInAppSwitcher)
        for item in config.appItems {
            hasher.combine(item.id)
        }
        return hasher.finalize()
    }

    private var currentDockAction: DockAction {
        Self.resolveDockAction(
            isVisibleInDock: editedConfig.isVisibleInDock,
            isCurrentlyInDock: isCurrentlyInDock
        )
    }

    private var isDirty: Bool {
        Self.contentSignature(of: editedConfig) != appliedContentSignature
    }

    /// Dynamic button text based on toggle state and actual Dock presence
    private var actionButtonText: String {
        switch currentDockAction {
        case .install:
            return isCurrentlyInDock ? AppStrings.Button.update : AppStrings.Button.addToDock
        case .remove:
            return AppStrings.Button.removeFromDock
        case .saveOnly:
            return AppStrings.Button.done
        }
    }

    init(config: DockTileConfiguration, onCustomise: @escaping () -> Void) {
        self.config = config
        self.onCustomise = onCustomise
        self._editedConfig = State(initialValue: config)
        self._tileName = State(initialValue: config.name)
        self._appliedContentSignature = State(initialValue: Self.contentSignature(of: config))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Provenance banner — only for tiles just created by Smart Add (transient flag).
                if configManager.smartAddProvenanceIDs.contains(editedConfig.id) {
                    smartAddBanner
                }

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
                Button(action: handleDockAction) {
                    if isProcessing {
                        // Busy state INSIDE the button (same pattern as the Popover Appearance
                        // Save button): spinner + label, button disabled. Keeps the toolbar
                        // stable — no external spinner popping in and shoving the button around.
                        HStack(spacing: 6) {
                            ProgressView()
                                .controlSize(.small)
                            Text(actionButtonText)
                        }
                    } else {
                        Text(actionButtonText)
                    }
                }
                .buttonStyle(.bordered)
                .disabled(!Self.dockActionIsEnabled(
                    action: currentDockAction,
                    isDirty: isDirty,
                    isProcessing: isProcessing
                ))
            }
        }
        .alert(AppStrings.Title.deleteTile, isPresented: $showDeleteConfirmation) {
            Button(AppStrings.Button.cancel, role: .cancel) {
                DiagnosticsLog.shared.ui("Delete confirmation → Cancel '\(editedConfig.name)'")
            }
            Button(AppStrings.Button.delete, role: .destructive) {
                DiagnosticsLog.shared.ui("Delete confirmation → Delete '\(editedConfig.name)'")
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
            guard hasAppearedOnce else { return }
            DispatchQueue.main.async {
                configManager.markSelectedConfigAsEdited()
                saveGeneration += 1
            }
        }
        // NOTE: tileName onChange removed - tileName now syncs to editedConfig.name
        // on every keystroke (see TextField onChange), which triggers this onChange
        // Debounced auto-save using counter - avoids deep struct equality on every keystroke
        .task(id: saveGeneration) {
            guard hasAppearedOnce, saveGeneration > 0 else { return }

            try? await Task.sleep(nanoseconds: 300_000_000)

            // Visibility is owned EXCLUSIVELY by performDockAction (gated on the Dock op
            // actually completing). The debounced auto-save persists edits to name, layout,
            // icon, app list, etc. — but must NOT commit the Show Tile toggle's transient
            // isVisibleInDock. Otherwise a hide whose un-pin never runs (dropped/interrupted
            // action, busy main thread at login) leaves a permanent "hidden in config but
            // still pinned in the Dock" desync. Preserve the stored visibility here.
            var toSave = editedConfig
            if let stored = configManager.configuration(for: editedConfig.id) {
                toSave.isVisibleInDock = stored.isVisibleInDock
                toSave.lastDockIndex = stored.lastDockIndex
            }
            configManager.updateConfiguration(toSave)
        }
        .onAppear {
            // Check actual Dock state on appear
            updateDockState()

            // Delay setting hasAppearedOnce to skip initial onChange triggers
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                hasAppearedOnce = true
            }
        }
        .onChange(of: editedConfig.isVisibleInDock) { _, newValue in
            // Update button text when toggle changes
            updateDockState()
            // The actual Dock add/remove is logged in performDockAction; this records the
            // user's toggle intent (verbose — the outcome is what matters in prod reports).
            if hasAppearedOnce {
                DiagnosticsLog.shared.log("tile", "Show Tile toggled \(newValue ? "ON" : "OFF") for '\(editedConfig.name)' (applies on action)", verbose: true)
            }
        }
        .onChange(of: editedConfig.layoutMode) { _, newValue in
            guard hasAppearedOnce else { return }
            DiagnosticsLog.shared.log("tile", "Layout changed to \(newValue.rawValue) for '\(editedConfig.name)'")
        }
        .onChange(of: editedConfig.showInAppSwitcher) { _, newValue in
            guard hasAppearedOnce else { return }
            DiagnosticsLog.shared.log("tile", "Mode changed to \(newValue ? "App" : "Ghost") for '\(editedConfig.name)'")
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

    // MARK: - Smart Add Provenance Banner

    /// Subtle accent-tinted banner shown atop Tile Detail for a tile just created by Smart Add.
    /// Explains the tile is a starting point and can be dismissed; it never persists across
    /// relaunch (the flag is runtime-only in `ConfigurationManager`).
    private var smartAddBanner: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "sparkles")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .accessibilityHidden(true)

            Text(AppStrings.SmartAdd.provenanceBanner)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 8)

            Button {
                configManager.clearSmartAddProvenance(editedConfig.id)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(AppStrings.Button.done)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.accentColor.opacity(0.12),
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.accentColor.opacity(0.25), lineWidth: 1)
        )
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
                    iconWeight: editedConfig.iconWeight,
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
                    DiagnosticsLog.shared.ui("Tile Detail → Customise (icon tapped) '\(editedConfig.name)'")
                    onCustomise()
                }

                SubtleButton(title: AppStrings.Button.customise, width: 118, action: {
                    DiagnosticsLog.shared.ui("Tile Detail → Customise button '\(editedConfig.name)'")
                    onCustomise()
                })
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
            .background(NSColorBackgroundView.formGroup)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Form Row Helper

    /// Renders a single row in a form group with optional bottom separator.
    /// - Parameter isLast: When `true`, omits the bottom separator (last row in group).
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
                    selection: $selectedAppIDs,
                    missingAppIDs: configManager.missingAppIDs
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
                    action: {
                        DiagnosticsLog.shared.ui("Tile Detail → Remove tile pressed '\(editedConfig.name)' (shows delete confirmation)")
                        showDeleteConfirmation = true
                    }
                )
            }
            .frame(height: 42)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 0)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(NSColorBackgroundView.formGroup)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - Actions

    /// Check if tile is currently in Dock and update state
    private func updateDockState() {
        isCurrentlyInDock = HelperBundleManager.shared.findInDock(bundleId: editedConfig.bundleIdentifier) != nil
    }

    /// Pure consent decision: the one-time Dock-restart dialog shows only until the user has
    /// acknowledged it. Extracted so the rule is testable without UserDefaults or the view layer.
    nonisolated static func shouldShowDockRestartConsent(hasAcknowledged: Bool) -> Bool {
        !hasAcknowledged
    }

    private func handleDockAction() {
        DiagnosticsLog.shared.ui("Tile Detail → '\(actionButtonText)' pressed for '\(editedConfig.name)' (action=\(currentDockAction), visible=\(editedConfig.isVisibleInDock), pinned=\(isCurrentlyInDock))")

        // Saving a hidden, not-pinned tile never touches the Dock — no restart happens, so the
        // Dock-restart consent dialog must not appear for it.
        if currentDockAction == .saveOnly {
            performDockAction()
            return
        }

        // Check if user has already acknowledged Dock restart
        let hasAcknowledged = UserDefaults.standard.bool(forKey: UserDefaultsKeys.hasAcknowledgedDockRestart)

        if Self.shouldShowDockRestartConsent(hasAcknowledged: hasAcknowledged) {
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

                // Resolve the action from the toggle + actual Dock presence. The saveOnly case
                // (hidden AND not pinned) must never reach HelperBundleManager — there is no
                // Dock work to do, and reaching it was the "Dock restarts on every Done" bug.
                switch Self.resolveDockAction(isVisibleInDock: configToSave.isVisibleInDock,
                                              isCurrentlyInDock: isCurrentlyInDock) {
                case .install:
                    // User wants tile in Dock - install/update (full helper re-render)
                    // Clear lastDockIndex after successful install (position is now live in Dock)
                    let wasInDock = isCurrentlyInDock
                    try await DiagnosticsLog.shared.measure("\(wasInDock ? "Update" : "Install") helper '\(configToSave.name)'") {
                        try await HelperBundleManager.shared.installHelper(for: configToSave)
                    }
                    configToSave.lastDockIndex = nil  // Clear saved position
                    configToSave.helperAppVersion = HelperBundleManager.currentAppVersion

                    AnalyticsService.shared.log(wasInDock ? .tileUpdated : .tileAddedToDock, [
                        "layout": configToSave.layoutMode.rawValue,
                        "app_count": configToSave.appItems.count,
                        "show_in_app_switcher": configToSave.showInAppSwitcher
                    ])
                    print("✅ Helper installed: \(configToSave.name)")
                    print("   User can open it from: ~/Library/Application Support/DockTile/")
                    DiagnosticsLog.shared.log("dock", "\(wasInDock ? "Updated" : "Added") tile '\(configToSave.name)' in Dock")

                case .remove:
                    // User wants tile removed - save position before removal
                    print("🗑️ Removing tile from Dock: \(configToSave.name)")
                    let savedPosition = try await DiagnosticsLog.shared.measure("Remove helper '\(configToSave.name)' from Dock") {
                        try await HelperBundleManager.shared.removeFromDock(for: configToSave)
                    }
                    if let position = savedPosition {
                        configToSave.lastDockIndex = position
                        print("   📍 Saved Dock position: \(position) for later restoration")
                    }
                    AnalyticsService.shared.log(.tileHidden, ["app_count": configToSave.appItems.count])
                    print("✅ Tile removed from Dock: \(configToSave.name)")
                    DiagnosticsLog.shared.log("dock", "Removed tile '\(configToSave.name)' from Dock (savedIndex=\(savedPosition.map(String.init) ?? "nil"))")

                case .saveOnly:
                    // Hidden tile with nothing pinned: persist edits only. No Dock op, no restart.
                    print("💾 Saving hidden tile without touching the Dock: \(configToSave.name)")
                    DiagnosticsLog.shared.log("dock", "Saved hidden tile '\(configToSave.name)' — no Dock op, Dock NOT restarted")
                }

                // Save configuration changes (including lastDockIndex)
                configManager.updateConfiguration(configToSave)

                // The user has acted on this tile (added/updated/removed) — retire the one-time
                // Smart Add provenance banner.
                configManager.clearSmartAddProvenance(configToSave.id)

                // If only showInAppSwitcher changed but tile was already visible,
                // we need to restart the helper to pick up the new activation policy
                if appSwitcherChanged && isCurrentlyInDock && configToSave.isVisibleInDock {
                    print("🔄 App Switcher setting changed - helper was restarted")
                }

                // Update local state to match saved config
                editedConfig = configToSave
                tileName = configToSave.name

                // The action applied/saved everything — mark content clean so the saveOnly
                // "Done" button disables until the user edits again. Signature-based (not the
                // generation counter) so the bookkeeping writes above don't re-dirty it.
                appliedContentSignature = Self.contentSignature(of: configToSave)

                // Refresh dock state after action
                updateDockState()
            } catch let error as HelperBundleError where error == .appTranslocated {
                // The app is translocated (running from a quarantined ~/Downloads copy) so it can't
                // build the helper. Don't just show the raw error — offer the actionable fix.
                errorMessage = error.localizedDescription
                DiagnosticsLog.shared.log("dock", "Dock action blocked for '\(editedConfig.name)': app is translocated")
                AppRelocationManager.shared.presentBlockingPrompt()
            } catch {
                errorMessage = error.localizedDescription
                DiagnosticsLog.shared.log("dock", "Dock action FAILED for '\(editedConfig.name)' (visible=\(editedConfig.isVisibleInDock)): \(error.localizedDescription)")
                AnalyticsService.shared.record(error, context: "performDockAction",
                                               keys: ["bundle_id": editedConfig.bundleIdentifier,
                                                      "visible": String(editedConfig.isVisibleInDock)])
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

        // Handle the user's response (shared by both the sheet and modal paths).
        let handleResponse: (NSApplication.ModalResponse) -> Void = { response in
            // Reset state
            showDockRestartConsent = false

            if response == .alertFirstButtonReturn {
                // User clicked "Confirm"
                // Check if "Don't show this again" was checked
                if checkbox.state == .on {
                    UserDefaults.standard.set(true, forKey: UserDefaultsKeys.hasAcknowledgedDockRestart)
                }
                // Proceed with dock action
                performDockAction()
            }
            // If user clicked "Cancel", do nothing
        }

        // Anchor the alert to the app window as a sheet so it appears centred on the
        // window instead of detached in the middle of the screen. Fall back to a modal
        // alert if no window is available (e.g. all windows closed but app still resident).
        if let window = NSApp.keyWindow ?? NSApp.mainWindow ?? NSApp.windows.first(where: { $0.isVisible }) {
            alert.beginSheetModal(for: window, completionHandler: handleResponse)
        } else {
            handleResponse(alert.runModal())
        }
    }

    private func deleteTile() {
        // Delete will handle uninstalling helper if needed
        // Use editedConfig.id to ensure we delete the correct tile
        configManager.deleteConfiguration(editedConfig.id)
    }

    private func removeSelectedApp() {
        // Remove all selected apps
        guard !selectedAppIDs.isEmpty else { return }
        let removedNames = editedConfig.appItems.filter { selectedAppIDs.contains($0.id) }.map(\.name)
        editedConfig.appItems.removeAll { selectedAppIDs.contains($0.id) }
        selectedAppIDs.removeAll()
        DiagnosticsLog.shared.log("tile", "Removed \(removedNames.count) item(s) from '\(editedConfig.name)': \(removedNames.joined(separator: ", "))")
    }

    private func addItem() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = true
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.application, .folder]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.treatsFilePackagesAsDirectories = false
        panel.prompt = AppStrings.Button.add
        panel.message = AppStrings.FilePicker.message

        DiagnosticsLog.shared.ui("Tile Detail → + (add app/folder) opened file picker for '\(editedConfig.name)'")
        guard panel.runModal() == .OK else {
            DiagnosticsLog.shared.ui("Tile Detail → add app/folder picker cancelled")
            return
        }

        // Batch-add every selected URL. Newly built items accumulate here so the
        // debounced auto-save fires once, and so duplicates within the same
        // selection are caught against items added earlier in this batch.
        var newItems: [AppItem] = []
        var skipped = 0

        for url in panel.urls {
            var isDirectory: ObjCBool = false
            FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)

            if isDirectory.boolValue && !url.pathExtension.lowercased().contains("app") {
                // It's a folder (not an .app bundle)
                let folderPath = url.path
                let isDuplicate = editedConfig.appItems.contains { $0.folderPath == folderPath }
                    || newItems.contains { $0.folderPath == folderPath }
                if isDuplicate {
                    skipped += 1
                    continue
                }
                if let folderItem = AppItem.from(folderURL: url) {
                    newItems.append(folderItem)
                }
            } else {
                // It's an application. Dedup on the on-disk path (unique per .app bundle) rather
                // than the bundle id: browser PWAs reuse one identifier across separate installs, so
                // two genuinely different tiles (e.g. multi-account inboxes) can legitimately share it.
                let appPath = url.path
                let bundleId = Bundle(url: url)?.bundleIdentifier
                let isDuplicate = editedConfig.appItems.contains { $0.matchesApp(path: appPath, bundleId: bundleId) }
                    || newItems.contains { $0.matchesApp(path: appPath, bundleId: bundleId) }
                if isDuplicate {
                    skipped += 1
                    continue
                }
                if let appItem = AppItem.from(appURL: url) {
                    newItems.append(appItem)
                }
            }
        }

        if newItems.isEmpty {
            // Nothing added (all duplicates or unreadable) — signal per HIG.
            NSSound.beep()
        } else {
            editedConfig.appItems.append(contentsOf: newItems)
        }

        let names = newItems.map(\.name).joined(separator: ", ")
        DiagnosticsLog.shared.log("tile", "Added \(newItems.count) item(s) to '\(editedConfig.name)', skipped \(skipped) duplicate(s) (\(editedConfig.appItems.count) total)\(names.isEmpty ? "" : ": \(names)")")
    }
}

// MARK: - Native Apps Table View

struct NativeAppsTableView: View {
    @Binding var items: [AppItem]
    @Binding var selection: Set<AppItem.ID>
    /// IDs of apps the install scan flagged as uninstalled — rendered dimmed with a placeholder.
    var missingAppIDs: Set<UUID> = []

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
                    let isMissing = missingAppIDs.contains(item.id)
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
                                AppIconView(item: item, isMissing: isMissing)
                                    .frame(width: 16, height: 16)

                                Text(item.name)
                                    .lineLimit(1)
                                    .foregroundStyle(isMissing ? .secondary : .primary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)

                            // Kind column — surfaces the uninstalled state inline
                            Text(isMissing ? AppStrings.Label.notInstalled : itemKind(for: item))
                                .foregroundStyle(.secondary)
                                .frame(width: 100, alignment: .leading)
                        }
                        .opacity(isMissing ? 0.7 : 1.0)
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
    /// When the underlying app/folder is no longer installed, show a distinct "missing"
    /// placeholder instead of the stale cached icon (matches the Dock's "?" for deleted apps).
    var isMissing: Bool = false

    // Observe IconStyleManager for icon style changes
    @ObservedObject private var iconStyleManager = IconStyleManager.shared

    var body: some View {
        let _ = iconStyleManager.currentStyle

        if isMissing {
            Image(systemName: "questionmark.app.dashed")
                .resizable()
                .foregroundStyle(.secondary)
        } else if let icon = AppIconLoader.icon(for: item) {
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

// FormGroupBackground replaced by shared NSColorBackgroundView.formGroup

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
