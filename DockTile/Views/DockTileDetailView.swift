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
    @State private var showDockRestartConsent = false  // Show consent dialog for Dock restart
    @State private var hasAppearedOnce = false  // Track if view has fully loaded
    @State private var isCurrentlyInDock = false  // Track actual Dock state
    @FocusState private var isNameFieldFocused: Bool  // Track focus for commit-on-blur
    /// The embedded popover panel renders per icon style — observe so it re-renders on a switch.
    @ObservedObject private var iconStyleManager = IconStyleManager.shared
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

                // The tile's apps, edited directly in the live popover preview
                inThisTileSection
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(nsColor: .windowBackgroundColor))
        // Delete + the dynamic action button trail the title band via PaneTitleBand's own flexible
        // spacer (single `.toolbar {}` call — see PaneTitleBand in DockTileConfigurationView.swift).
        // The band shows the COMMITTED name — typing re-titles the preview below, not the chrome.
        .paneTitleBand(configManager.displayName(for: editedConfig.id)) {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    DiagnosticsLog.shared.ui("Tile Detail → Delete tile pressed '\(editedConfig.name)' (shows delete confirmation)")
                    showDeleteConfirmation = true
                } label: {
                    Image(systemName: "trash")
                }
                // `.bordered`, not `.borderless`: the destructive action needs the same rounded
                // surface as the action button beside it, or it reads as a bare glyph floating in
                // the band.
                .buttonStyle(.bordered)
                .help(AppStrings.Tooltip.deleteTile)
                .accessibilityLabel(AppStrings.Title.deleteTile)

                actionButton
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
                DiagnosticsLog.shared.log("tile", "Show Tile toggled \(newValue ? "ON" : "OFF") for \(editedConfig.diagnosticName) (applies on action)", verbose: true)
            }
        }
        .onChange(of: editedConfig.layoutMode) { _, newValue in
            guard hasAppearedOnce else { return }
            DiagnosticsLog.shared.log("tile", "Layout changed to \(newValue.rawValue) for \(editedConfig.diagnosticName)")
        }
        .onChange(of: editedConfig.showInAppSwitcher) { _, newValue in
            guard hasAppearedOnce else { return }
            DiagnosticsLog.shared.log("tile", "Mode changed to \(newValue ? "App" : "Ghost") for \(editedConfig.diagnosticName)")
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

    // MARK: - Band Action Button

    /// Prominent for Dock-adding actions, plain otherwise; spinner INSIDE while processing (same
    /// pattern as the Popover Appearance Save button) so the band stays stable — no external
    /// spinner popping in and shoving the button around.
    @ViewBuilder private var actionButton: some View {
        let button = Button(action: handleDockAction) {
            HStack(spacing: 6) {
                if isProcessing { ProgressView().controlSize(.small) }
                else if currentDockAction == .install {
                    Image(systemName: isCurrentlyInDock ? "arrow.clockwise" : "plus")
                }
                Text(actionButtonText)
            }
        }
        .disabled(!Self.dockActionIsEnabled(action: currentDockAction, isDirty: isDirty, isProcessing: isProcessing))
        if currentDockAction == .install {
            button.buttonStyle(.borderedProminent).foregroundStyle(.white)
        } else {
            button.buttonStyle(.bordered)
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
                // Icon container: 96×96pt
                // Uses DockTileIconPreview which is appearance-aware (light/dark mode)
                // Tappable to open customise view
                DockTileIconPreview(
                    tintColor: editedConfig.tintColor,
                    iconType: editedConfig.iconType,
                    iconValue: editedConfig.iconValue,
                    iconScale: editedConfig.iconScale,
                    iconWeight: editedConfig.iconWeight,
                    size: 96
                )
                .contentShape(RoundedRectangle(cornerRadius: 96 * 0.225, style: .continuous))
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

                SubtleButton(title: AppStrings.Button.customise, width: 96, action: {
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
                        .tileSwitch()
                }

                // Row 3: Show in App Switcher (last row, no separator)
                // Layout moved to the "In This Tile" section, beside the live preview it drives.
                formRow(isLast: true) {
                    Text(AppStrings.Label.showInAppSwitcher)
                    Spacer()
                    Toggle("", isOn: $editedConfig.showInAppSwitcher)
                        .tileSwitch()
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

    // MARK: - In This Tile Section

    /// Re-render key for the embedded panel: the panel reads settings/icons itself, so it must be
    /// rebuilt when the layout or the icon style changes.
    ///
    /// The **app list is deliberately excluded**. `configuration` is a value type, so adding,
    /// removing or reordering items already re-renders the panel without a new view identity — while
    /// keying on it would destroy and rebuild the panel mid-edit, resetting its `@State`: an
    /// in-flight drag loses `draggedItem` after the first hop (every later `dropEntered` early-returns,
    /// so the item lands one cell over instead of where it was released), and a Delete-key removal
    /// drops keyboard focus. `missingAppIDs` is excluded for the same reason, plus a `Set`'s
    /// iteration order is not stable — each cell resolves its own install status in its body.
    private var previewSignature: String {
        [editedConfig.layoutMode.rawValue, iconStyleManager.currentStyle.rawValue].joined(separator: "-")
    }

    /// The tile's apps, shown as the REAL popover panel (WYSIWYG — `settings: nil` makes it load the
    /// saved shared-suite appearance) turned into an editor: hover × removes, drag reorders.
    private var inThisTileSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 10) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(AppStrings.Section.inThisTile).font(.system(size: 13, weight: .semibold))
                    Text(AppStrings.Label.editorHint).font(.system(size: 11)).foregroundStyle(.tertiary)
                }
                Spacer()
                Picker("", selection: $editedConfig.layoutMode) {
                    Text(AppStrings.Layout.grid).tag(LayoutMode.grid)
                    Text(AppStrings.Layout.list).tag(LayoutMode.list)
                }
                .pickerStyle(.segmented).labelsHidden().fixedSize()
                Button(action: addItem) { Label(AppStrings.Button.add, systemImage: "plus") }
                    .help(AppStrings.Label.addAppsTooltip)
            }
            .padding(.horizontal, 4)

            PopoverPreviewCanvas(
                configuration: editedConfig,
                layout: editedConfig.layoutMode,
                fit: .natural,
                signature: previewSignature,
                editing: PopoverEditing(
                    onRemove: { app in
                        editedConfig.appItems = AppListEditor.removing(app.id, from: editedConfig.appItems)
                        DiagnosticsLog.shared.log("tile", "Removed 1 item(s) from \(editedConfig.diagnosticName): \(app.name)")
                    },
                    onMove: { dragged, target in
                        editedConfig.appItems = AppListEditor.moving(dragged.id, onto: target.id, in: editedConfig.appItems)
                    },
                    // The empty panel's glyph opens the same picker as the "+ Add" control above.
                    onAdd: {
                        DiagnosticsLog.shared.ui("Tile editor → empty-state glyph pressed (app picker)")
                        addItem()
                    }))

            if let error = errorMessage {
                Text(error).font(.caption).foregroundColor(.red).padding(.top, 4)
            }
        }
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
                    DiagnosticsLog.shared.log("dock", "\(wasInDock ? "Updated" : "Added") tile \(configToSave.diagnosticName) in Dock")

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
                    DiagnosticsLog.shared.log("dock", "Removed tile \(configToSave.diagnosticName) from Dock (savedIndex=\(savedPosition.map(String.init) ?? "nil"))")

                case .saveOnly:
                    // Hidden tile with nothing pinned: persist edits only. No Dock op, no restart.
                    print("💾 Saving hidden tile without touching the Dock: \(configToSave.name)")
                    DiagnosticsLog.shared.log("dock", "Saved hidden tile \(configToSave.diagnosticName) — no Dock op, Dock NOT restarted")
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

                // THIS is the moment the sidebar row and title band adopt a rename — see
                // ConfigurationManager.committedNames.
                configManager.commitDisplayName(for: configToSave.id)

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
                DiagnosticsLog.shared.log("dock", "Dock action blocked for \(editedConfig.diagnosticName): app is translocated")
                AppRelocationManager.shared.presentBlockingPrompt()
            } catch {
                errorMessage = error.localizedDescription
                DiagnosticsLog.shared.log("dock", "Dock action FAILED for \(editedConfig.diagnosticName) (visible=\(editedConfig.isVisibleInDock)): \(error.localizedDescription)")
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
        DiagnosticsLog.shared.log("tile", "Added \(newItems.count) item(s) to \(editedConfig.diagnosticName), skipped \(skipped) duplicate(s) (\(editedConfig.appItems.count) total)\(names.isEmpty ? "" : ": \(names)")")
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
