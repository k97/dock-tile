//
//  NativePopoverViews.swift
//  DockTile
//
//  Native macOS Dock-style popover views with vibrancy
//  Mimics the native Dock folder Stack and List views
//  Swift 6 - Strict Concurrency
//

import AppKit
import SwiftUI

// MARK: - Arrow Direction Enum

enum ArrowDirection {
    case up, down, left, right
}

// MARK: - Keyboard Navigation Handler

/// NSViewRepresentable that captures keyboard events for popover navigation.
///
/// **Why NSView instead of SwiftUI `.onKeyPress`?**
/// The popover is hosted inside an NSPopover which manages its own key window status.
/// SwiftUI's `.onKeyPress` doesn't reliably receive events when the popover's NSWindow
/// isn't the key window. Using an NSView subclass as first responder ensures we capture
/// keyboard events regardless of window focus state - critical for Dock popover interaction.
struct KeyboardNavigationHandler: NSViewRepresentable {
    let enabled: Bool
    let onArrowKey: (ArrowDirection) -> Void
    let onEnter: () -> Void
    let onEscape: () -> Void

    func makeNSView(context: Context) -> KeyboardCaptureView {
        let view = KeyboardCaptureView()
        view.onArrowKey = onArrowKey
        view.onEnter = onEnter
        view.onEscape = onEscape
        return view
    }

    func updateNSView(_ nsView: KeyboardCaptureView, context: Context) {
        nsView.onArrowKey = onArrowKey
        nsView.onEnter = onEnter
        nsView.onEscape = onEscape

        if enabled {
            // Make key window and first responder
            DispatchQueue.main.async {
                nsView.window?.makeFirstResponder(nsView)
            }
        }
    }
}

/// Custom NSView that captures keyboard events
final class KeyboardCaptureView: NSView {
    var onArrowKey: ((ArrowDirection) -> Void)?
    var onEnter: (() -> Void)?
    var onEscape: (() -> Void)?

    override var acceptsFirstResponder: Bool { true }

    /// Key codes from Carbon.HIToolbox (kVK_* constants)
    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 126: onArrowKey?(.up)      // kVK_UpArrow
        case 125: onArrowKey?(.down)    // kVK_DownArrow
        case 123: onArrowKey?(.left)    // kVK_LeftArrow
        case 124: onArrowKey?(.right)   // kVK_RightArrow
        case 36, 76: onEnter?()         // kVK_Return, kVK_ANSI_KeypadEnter
        case 53: onEscape?()            // kVK_Escape
        default: super.keyDown(with: event)
        }
    }
}

// MARK: - Visual Effect View (NSVisualEffectView Wrapper for Liquid Glass)

/// NSViewRepresentable wrapper for NSVisualEffectView
/// Configured for the macOS "Liquid Glass" aesthetic with proper vibrancy
struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    let state: NSVisualEffectView.State
    let isEmphasized: Bool

    /// Creates a Liquid Glass visual effect view
    /// - Parameters:
    ///   - material: The material type (.popover or .menu for maximum translucency)
    ///   - blendingMode: Must be .behindWindow for Dock/wallpaper bleed-through
    ///   - state: Must be .active to maintain vibrancy when clicking away
    ///   - isEmphasized: Whether the view should appear emphasized (brighter)
    init(
        material: NSVisualEffectView.Material = .popover,
        blendingMode: NSVisualEffectView.BlendingMode = .behindWindow,
        state: NSVisualEffectView.State = .active,
        isEmphasized: Bool = false
    ) {
        self.material = material
        self.blendingMode = blendingMode
        self.state = state
        self.isEmphasized = isEmphasized
    }

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        configureView(view)
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        configureView(nsView)
    }

    private func configureView(_ view: NSVisualEffectView) {
        view.material = material
        view.blendingMode = blendingMode
        // CRITICAL: state must be .active to maintain "liquid" effect when app loses focus
        // Otherwise it turns flat gray
        view.state = state
        view.isEmphasized = isEmphasized
        view.wantsLayer = true
        // Ensure the view doesn't add its own shadow (let NSPopover handle it)
        view.shadow = nil
    }
}

/// Convenience initializer for common Liquid Glass configurations
extension VisualEffectView {
    /// Standard Liquid Glass popover background
    static var liquidGlass: VisualEffectView {
        VisualEffectView(
            material: .popover,
            blendingMode: .behindWindow,
            state: .active
        )
    }

    /// Menu-style Liquid Glass (slightly more translucent)
    static var liquidGlassMenu: VisualEffectView {
        VisualEffectView(
            material: .menu,
            blendingMode: .behindWindow,
            state: .active
        )
    }

    /// Same `.popover` Liquid Glass material as the real popover, but blended `.withinWindow` so it
    /// stays vibrant when embedded INSIDE a window (e.g. the Settings → Popover live preview, where
    /// `.behindWindow` would flatten to grey). Use to reproduce the popover surface in-app.
    static var popoverSurfaceInWindow: VisualEffectView {
        VisualEffectView(
            material: .popover,
            blendingMode: .withinWindow,
            state: .active
        )
    }
}

// MARK: - Editing mode (Tile Detail's preview editor; nil in helpers)

/// Handlers the main app supplies to turn the panel into the tile's app editor. `nil` (helpers,
/// Settings preview) leaves the panel exactly as it ships. Editing implies preview: no launches.
struct PopoverEditing {
    let onRemove: (AppItem) -> Void
    let onMove: (_ dragged: AppItem, _ target: AppItem) -> Void
    /// Opens the app picker. Drives the empty panel's glyph, which is the obvious thing to click
    /// when the tile has nothing in it yet. Optional so an editor that only reorders can omit it.
    var onAdd: (() -> Void)? = nil
}

/// The empty panel's glyph. A button that opens the app picker when the panel is being edited, an
/// inert image otherwise — so the shipped popover's empty state stays exactly as it was.
struct EmptyStateGlyph: View {
    let onAdd: (() -> Void)?
    @State private var isHovering = false

    private var glyph: some View {
        Image(systemName: "plus.app")
            .font(.system(size: 32))
            .foregroundStyle(.secondary)
    }

    var body: some View {
        if let onAdd {
            Button(action: onAdd) {
                glyph
                    .opacity(isHovering ? 1 : 0.85)
                    .scaleEffect(isHovering ? 1.06 : 1)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .onHover { isHovering = $0 }
            .animation(.easeOut(duration: 0.12), value: isHovering)
            .help(AppStrings.Label.addAppsTooltip)
            .accessibilityLabel(AppStrings.Label.addAppsTooltip)
        } else {
            glyph
        }
    }
}

/// Drag-to-reorder inside the panel; copied from DockTileDetailView's table (the original is
/// removed in Task 9).
struct PopoverItemDropDelegate: DropDelegate {
    let target: AppItem
    let dragged: () -> AppItem?
    let onMove: (AppItem, AppItem) -> Void
    let onFinish: () -> Void

    func dropEntered(info: DropInfo) {
        guard let dragged = dragged(), dragged.id != target.id else { return }
        withAnimation(.easeInOut(duration: 0.2)) { onMove(dragged, target) }
    }
    func dropUpdated(info: DropInfo) -> DropProposal? { DropProposal(operation: .move) }
    func performDrop(info: DropInfo) -> Bool { onFinish(); return true }
}

extension View {
    /// Attaches editing-only modifiers ONLY when editing is on, so `editing == nil` leaves the
    /// shipped view tree untouched.
    @ViewBuilder func editingOnly<Content: View>(
        _ editing: PopoverEditing?, _ transform: (Self) -> Content
    ) -> some View {
        if editing != nil { transform(self) } else { self }
    }

    /// The remove affordances shared by grid cells and list rows — context menu, Delete key and the
    /// VoiceOver action. Absent from the shipped popover entirely. (The hover × badge is not here:
    /// its placement is layout-specific, so each cell keeps its own.)
    @ViewBuilder func removeAffordances(_ editing: PopoverEditing?, for app: AppItem) -> some View {
        if let editing {
            self
                .contextMenu {
                    Button(AppStrings.PopoverOption.editingRemove, role: .destructive) {
                        editing.onRemove(app)
                    }
                }
                .focusable()
                .onDeleteCommand { editing.onRemove(app) }
                .accessibilityElement(children: .combine)
                .accessibilityAction(named: Text(AppStrings.PopoverOption.editingRemove)) {
                    editing.onRemove(app)
                }
        } else {
            self
        }
    }

    /// Drag-to-reorder shared by grid cells and list rows — the shipped popover is neither a drag
    /// source nor a drop target.
    @ViewBuilder func reorderable(
        _ editing: PopoverEditing?, app: AppItem, dragged: Binding<AppItem?>
    ) -> some View {
        if let editing {
            self
                .onDrag {
                    dragged.wrappedValue = app
                    return NSItemProvider(object: app.id.uuidString as NSString)
                }
                // Only `performDrop` clears `dragged`, so a drag abandoned outside any cell leaves
                // it set. That is deliberate rather than leaked state: drop callbacks fire only
                // during an active drag session, and `onDrag` above reassigns `dragged` before the
                // next session can deliver one — so a stale value is never read. Clearing it would
                // need a container-level drop target that could swallow drops meant for a cell.
                .onDrop(of: [.text], delegate: PopoverItemDropDelegate(
                    target: app,
                    dragged: { dragged.wrappedValue },
                    onMove: { d, t in editing.onMove(d, t) },
                    onFinish: { dragged.wrappedValue = nil }
                ))
        } else {
            self
        }
    }
}

// MARK: - Stack (Grid) Popover View

/// Native macOS Dock folder "Stack" view with large icons in a grid
/// Matches the native Applications Dock folder popover:
/// - Fixed/anchored title at top (doesn't scroll)
/// - Vertically scrolling grid below
/// - Scrollbar only appears in grid area
/// - Liquid Glass effect across entire background
struct StackPopoverView: View {
    let configuration: DockTileConfiguration?
    let onLaunch: () -> Void
    /// When false, the view skips its own Liquid Glass background — the host supplies the surface
    /// (used by the Settings preview, which wraps it in popover chrome). Real popover keeps it ON.
    var showsBackground: Bool = true
    /// When true (Settings preview), the panel stays interactive for hover but performs NO actions —
    /// clicks never launch apps or open the configurator. The real popover leaves this false.
    var isPreview: Bool = false
    /// When set (Settings preview), the panel renders these *draft* settings instead of reading the
    /// shared suite — so the live preview reflects unsaved edits without persisting them. nil in the
    /// real popover, which always loads the saved values.
    var settingsOverride: PopoverSettings? = nil
    /// When set (Tile Detail), the panel IS the tile's app editor: cells gain a remove badge, a
    /// context menu, Delete-key support and drag-to-reorder. nil in helpers and the Settings
    /// preview, which then render exactly as they ship.
    var editing: PopoverEditing? = nil

    @State private var selectedIndex: Int? = nil
    @State private var keyboardNavigationEnabled = false
    @State private var draggedItem: AppItem? = nil

    // Observe IconStyleManager for icon style changes
    // Used to force view recreation via .id() modifier
    @ObservedObject private var iconStyleManager = IconStyleManager.shared

    /// Editing implies preview: an editor click must never launch an app or open the configurator.
    private var actionsDisabled: Bool { isPreview || editing != nil }

    /// Saved **Grid** popover-appearance values, read once from the shared suite when this popover is
    /// built. Helpers render the popover, so this picks up the main app's Settings → Popover (Grid
    /// panel) values on the next open (matches the icon-style propagation model). The preview
    /// overrides it with a draft.
    private let loadedSettings = PopoverSettings.load(layout: .grid)

    /// Draft override (preview) wins over the saved values; nil → the real loaded settings.
    private var settings: PopoverSettings { settingsOverride ?? loadedSettings }

    private var metrics: PopoverGridMetrics {
        PopoverMetrics.grid(
            popoverSize: settings.popoverSize,
            tileSize: settings.tileSize,
            spacing: settings.spacing,
            showLabels: settings.showLabels
        )
    }

    private var apps: [AppItem] {
        configuration?.appItems ?? []
    }

    private var tileName: String {
        configuration?.name ?? AppStrings.appName
    }

    // MARK: - Dynamic Grid Configuration

    /// Column count from the global Popover Size (Small 4 / Medium 5 / Large 6), capped at the app
    /// count so a tile with few apps stays tight rather than padding out empty trailing columns.
    private var columnCount: Int {
        PopoverPanelLayout.columnCount(metricsColumns: metrics.columns, appCount: apps.count)
    }

    /// Grid columns sized by Tile Size; spacing by Spacing.
    private var columns: [GridItem] {
        Array(repeating: GridItem(.fixed(metrics.cellWidth), spacing: metrics.gap), count: columnCount)
    }

    /// Popover width from cell width × columns.
    private var popoverWidth: CGFloat {
        PopoverPanelLayout.gridPanelSize(metrics: metrics, appCount: apps.count,
                                         showLabels: settings.showLabels).width
    }

    // Layout constants — the panel's chrome geometry lives in `PopoverPanelLayout` so the editor
    // canvas, which frames and clips this panel, can never size it from a stale second copy.
    private let headerHeight = PopoverPanelLayout.gridHeaderHeight
    private let gridTopPadding = PopoverPanelLayout.gridPadding
    private let gridBottomPadding = PopoverPanelLayout.gridPadding
    private let gridHorizontalPadding = PopoverPanelLayout.gridPadding

    var body: some View {
        VStack(spacing: 0) {
            // MARK: Anchored Header (Fixed - doesn't scroll)
            HStack {
                // Invisible spacer to balance the gear icon and keep title centered
                Color.clear
                    .frame(width: 28, height: 28)

                Spacer()

                // ALWAYS one line. The header reserves a 28pt gutter on each side (the gear and its
                // balancing spacer), so a narrow panel — a one-app tile is a single column — left so
                // little room that "New Tile" wrapped to two lines and pushed the grid down.
                // `PopoverPanelLayout.gridMinWidth` keeps normal names from truncating; this is the
                // guarantee for the ones that still don't fit.
                Text(tileName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .help(tileName)

                Spacer()

                // Settings gear icon — opens main app to configure this tile. In edit mode the host
                // IS the configurator, so the gear gives way to a spacer that keeps the title centred.
                if editing == nil {
                    Button(action: openConfigurator) {
                        Image(systemName: "gearshape")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                            .frame(width: 28, height: 28)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help(AppStrings.Menu.configureTile)
                    .onHover { hovering in
                        if hovering {
                            NSCursor.pointingHand.push()
                        } else {
                            NSCursor.pop()
                        }
                    }
                } else {
                    Color.clear
                        .frame(width: 28, height: 28)
                }
            }
            .padding(.horizontal, 8)
            .frame(height: headerHeight)

            // MARK: Scrollable Grid Content
            if apps.isEmpty {
                emptyStateView
            } else if editing != nil {
                // No nested scrolling in edit mode: the editor is hosted inside Tile Detail's own
                // ScrollView, and an inner one would trap the wheel. The grid renders in full.
                gridContent
            } else {
                ScrollView(.vertical, showsIndicators: true) {
                    gridContent
                }
            }
        }
        .frame(width: popoverWidth, height: calculateHeight())
        // LIQUID GLASS: Single translucent surface for header + grid (host-supplied in previews).
        .background(Color.clear)
        .background {
            if showsBackground { VisualEffectView.liquidGlass }
        }
        .onReceive(NotificationCenter.default.publisher(for: .enableKeyboardNavigation)) { _ in
            keyboardNavigationEnabled = true
            selectedIndex = apps.isEmpty ? nil : 0
        }
        .background(KeyboardNavigationHandler(
            enabled: keyboardNavigationEnabled,
            onArrowKey: handleArrowKey,
            onEnter: handleEnter,
            onEscape: handleEscape
        ))
    }

    /// The grid itself, without a scroll container — shared by the shipped scrolling panel and the
    /// unscrolled edit-mode panel so the two can never drift.
    private var gridContent: some View {
        LazyVGrid(columns: columns, spacing: metrics.gap) {
            ForEach(Array(apps.enumerated()), id: \.element.id) { index, app in
                StackAppItem(
                    app: app,
                    isSelected: selectedIndex == index,
                    iconSize: metrics.iconSize,
                    cellWidth: metrics.cellWidth,
                    showLabel: settings.showLabels,
                    highlightOnHover: settings.highlightOnHover,
                    editing: editing,
                    onLaunch: onLaunch
                )
                // Composite ID forces SwiftUI to destroy/recreate the view when icon style
                // changes, which clears NSWorkspace's cached icon and re-fetches the
                // correct variant (Default/Dark/Clear/Tinted) from the app bundle.
                .id("\(app.id)-\(iconStyleManager.currentStyle.rawValue)")
                .onTapGesture {
                    launchAppAt(index: index)
                }
                .reorderable(editing, app: app, dragged: $draggedItem)
            }
        }
        .padding(.top, gridTopPadding)
        .padding(.bottom, gridBottomPadding)
        .padding(.horizontal, gridHorizontalPadding)
    }

    private var emptyStateView: some View {
        VStack(spacing: 8) {
            // `plus.app`, NOT `app.badge.plus` — the latter is not a real SF Symbol, so it rendered
            // as nothing at all. Silent: an unknown symbol name draws empty with no warning.
            //
            // In the editor the glyph IS the add button — it is the obvious thing to click in an
            // empty tile, and it runs the same `addItem` as the "+ Add" control above the canvas.
            // In the shipped popover `editing` is nil, so it stays a plain, inert image.
            EmptyStateGlyph(onAdd: editing?.onAdd)
            if editing != nil {
                // Same two-line shape as the shipped state below — one title, one supporting line.
                Text(AppStrings.PopoverOption.editingNoAppsTitle)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                Text(AppStrings.PopoverOption.editingNoAppsSubtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 230)
            } else {
                Text(AppStrings.Empty.noApps)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                Text(AppStrings.Subtitle.configureToAdd)
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Does any cell draw the editor-only "Not installed" caption? That caption makes its row
    /// taller, and this view pins its own height — an unbilled row is clipped. Resolved only in
    /// edit mode, so the shipped popover never pays for the probe.
    private var showsMissingCaption: Bool {
        guard editing != nil else { return false }
        return apps.contains { AppInstallChecker.resolve($0).status == .missing }
    }

    private func calculateHeight() -> CGFloat {
        // Header + rows + padding, from the shared seam. Edit mode has no inner ScrollView, so it
        // reports its full height and lets Tile Detail's own scroll view do the scrolling.
        let totalHeight = PopoverPanelLayout.gridPanelSize(
            metrics: metrics, appCount: apps.count, showLabels: settings.showLabels,
            includesMissingCaption: showsMissingCaption
        ).height
        return editing != nil ? totalHeight : min(totalHeight, PopoverPanelLayout.gridScrollCap)
    }

    // MARK: - Keyboard Navigation

    private func handleArrowKey(_ direction: ArrowDirection) {
        guard !apps.isEmpty else { return }

        let current = selectedIndex ?? 0
        var newIndex = current

        switch direction {
        case .up:
            newIndex = max(0, current - columnCount)
        case .down:
            newIndex = min(apps.count - 1, current + columnCount)
        case .left:
            newIndex = max(0, current - 1)
        case .right:
            newIndex = min(apps.count - 1, current + 1)
        }

        selectedIndex = newIndex
    }

    private func handleEnter() {
        if let index = selectedIndex, index < apps.count {
            launchAppAt(index: index)
        }
    }

    private func handleEscape() {
        NotificationCenter.default.post(name: .dismissLauncher, object: nil)
    }

    private func launchAppAt(index: Int) {
        guard !actionsDisabled, index < apps.count else { return }
        AppLauncher.launch(apps[index])
        onLaunch()
    }

    private func openConfigurator() {
        guard !actionsDisabled else { return }
        NotificationCenter.default.post(name: .openConfigurator, object: nil)
        onLaunch()
    }
}

// MARK: - Stack App Item (Large Icon + Label)

struct StackAppItem: View {
    let app: AppItem
    let isSelected: Bool  // Keyboard navigation selection
    let iconSize: CGFloat
    let cellWidth: CGFloat
    let showLabel: Bool
    let highlightOnHover: Bool
    /// Editing handlers from Tile Detail; nil (helpers, Settings preview) means no edit affordances.
    var editing: PopoverEditing? = nil
    let onLaunch: () -> Void

    @State private var isHovered = false
    /// Hover over the remove badge itself. Tracked separately because the badge sits on top of the
    /// cell: on macOS a child control with its own tracking region can end the parent's hover, and
    /// with a single flag that ended the badge's own reason to exist mid-reach.
    @State private var isHoveringRemove = false

    /// Is the pointer anywhere on this cell, badge included? Drives BOTH the hover highlight and the
    /// badge, so neither can flicker out while the user is reaching for the other.
    private var isPointerInside: Bool { isHovered || isHoveringRemove }

    // Observe IconStyleManager for icon style changes
    // This triggers view refresh when system icon style changes
    @ObservedObject private var iconStyleManager = IconStyleManager.shared

    /// Mouse hover uses the subtle Liquid-Glass fill (`.quaternary`) like typical Mac apps; the
    /// stronger accent is reserved for keyboard-focus selection (accessibility). Hover honours the
    /// Breathing room each side of the app name, taken out of the cell's own width rather than
    /// added to it — so the label ellipsises inside the tile and the panel's size is untouched.
    private static let labelInset: CGFloat = 4

    /// Diameter of the editor's hover remove badge.
    private static let removeBadgeSize: CGFloat = 18
    /// Nudge in from the cell's top-right corner: 0.5pt down, 0.5pt in — one physical pixel on a
    /// Retina display.
    ///
    /// The badge must stay **entirely inside the cell** (critical). `isHovered` belongs to the cell,
    /// and an `.overlay` that hangs past the cell's bounds is outside the cell's tracking area — so
    /// reaching for a badge that overhangs the corner ends the hover and unmounts the badge under
    /// the cursor, leaving it impossible to click. A positive inset keeps the whole badge within the
    /// region that keeps it on screen.
    private static let removeBadgeCornerInset: CGFloat = 0.5

    /// global "Highlight on Hover" toggle.
    private var highlightStyle: AnyShapeStyle {
        if isSelected { return AnyShapeStyle(Color(nsColor: .selectedContentBackgroundColor)) }
        if highlightOnHover && isPointerInside { return AnyShapeStyle(.quaternary) }
        return AnyShapeStyle(Color.clear)
    }

    var body: some View {
        // Reference iconStyleManager.currentStyle to trigger re-render when icon style changes
        let _ = iconStyleManager.currentStyle

        // Resolved ONCE per cell: the probe hits Launch Services + stat() and is uncached, and the
        // icon and the "Not installed" caption both need the answer. Computed exactly where the
        // icon's own (unconditional, both-modes) probe already was, so helpers do no extra work.
        let isMissing = AppInstallChecker.resolve(app).status == .missing

        VStack(spacing: 4) {
            // App icon, sized by the global Tile Size setting.
            appIconView(isMissing: isMissing)
                .frame(width: iconSize, height: iconSize)

            if showLabel {
                // App name — one line, ellipsised in the middle so both ends stay readable
                // ("GitHub…esktop" beats "GitHub Des…").
                //
                // The padding sits INSIDE the fixed width on purpose: the cell still occupies its
                // full `cellWidth` column, but the name truncates a little earlier, so a long one
                // ends with a margin inside the selection instead of running to its very edge.
                Text(app.name)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .padding(.horizontal, Self.labelInset)
                    .frame(width: cellWidth)
            }

            // The editor names the "app is gone" state outright; the shipped popover keeps to the
            // dimmed placeholder icon.
            if editing != nil, isMissing {
                Text(AppStrings.Label.notInstalled)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
        }
        // Keep the interactive cell ≥44pt even when the glyph is smaller (HIG hit target).
        .frame(minWidth: 44, minHeight: 44)
        .padding(2)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(highlightStyle)
        )
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .editingOnly(editing) { cell in
            // Remove badge in the cell's TOP-RIGHT corner — the same side the list layout removes
            // from. Inset rather than overhanging, for the tracking-area reason on
            // `removeBadgeCornerInset`.
            //
            // **Mounted for as long as the editor is open, never conditionally (critical).** Only
            // its opacity and hit testing follow the pointer. Adding and removing a view UNDER the
            // cursor makes AppKit rebuild the tracking areas beneath it, and the resulting spurious
            // exit dropped `isHovered` — which unmounted the badge mid-reach, taking the hover
            // highlight with it and swallowing the click. Cross-fading a mounted view has no such
            // effect.
            cell.overlay(alignment: .topTrailing) {
                if let editing {
                    Button { editing.onRemove(app) } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 8, weight: .heavy))
                            .foregroundStyle(.white)
                            .frame(width: Self.removeBadgeSize, height: Self.removeBadgeSize)
                            .background(Color(nsColor: .tertiaryLabelColor), in: Circle())
                            .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
                    }
                    .buttonStyle(.plain)
                    .help(AppStrings.PopoverOption.editingRemove)
                    .accessibilityLabel(AppStrings.PopoverOption.editingRemove)
                    .offset(x: -Self.removeBadgeCornerInset, y: Self.removeBadgeCornerInset)
                    .onHover { isHoveringRemove = $0 }
                    .opacity(isPointerInside ? 1 : 0)
                    // Hit testing is NOT gated on the hover state (critical). Gating it deadlocks:
                    // the pointer moving onto the badge ends the CELL's hover, which would switch
                    // hit testing off, so the badge could never receive the `onHover` above that
                    // brings it back — it vanished under the cursor and stayed gone. Reaching the
                    // badge requires moving the pointer onto it, which reveals it, so an invisible
                    // badge is not something a user can click by accident.
                    .accessibilityHidden(!isPointerInside)
                    .animation(.easeOut(duration: 0.12), value: isPointerInside)
                }
            }
        }
        .removeAffordances(editing, for: app)
    }

    @ViewBuilder
    private func appIconView(isMissing: Bool) -> some View {
        // Resolved synchronously (no @State/onAppear) so a deleted app never flashes its stale
        // cached icon before the placeholder appears.
        if isMissing {
            Image(systemName: "questionmark.app.dashed")
                .font(.system(size: iconSize * 0.5))
                .foregroundStyle(.secondary)
        } else if let nsImage = AppIconLoader.icon(for: app) {
            Image(nsImage: nsImage)
                .resizable()
                .interpolation(.high)
        } else {
            Image(systemName: "app")
                .font(.system(size: iconSize * 0.5))
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - List Popover View (Context Menu Style)

/// Native macOS Dock folder "List" view with small icons in vertical rows
/// Matches the native Dock context menu appearance
struct ListPopoverView: View {
    let configuration: DockTileConfiguration?
    let onLaunch: () -> Void
    /// When false, the view skips its own Liquid Glass background (host supplies the surface).
    var showsBackground: Bool = true
    /// When true (Settings preview), the panel stays interactive for hover but performs no actions.
    var isPreview: Bool = false
    /// When set (Settings preview), renders these *draft* settings instead of the shared suite, so
    /// the live preview reflects unsaved edits without persisting them. nil in the real popover.
    var settingsOverride: PopoverSettings? = nil
    /// When set (Tile Detail), the panel IS the tile's app editor: rows gain a remove button, a
    /// context menu, Delete-key support and drag-to-reorder, and the utility rows step aside.
    /// nil in helpers and the Settings preview, which then render exactly as they ship.
    var editing: PopoverEditing? = nil

    @State private var selectedIndex: Int? = nil
    @State private var keyboardNavigationEnabled = false
    @State private var draggedItem: AppItem? = nil

    // Observe IconStyleManager for icon style changes
    // Used to force view recreation via .id() modifier
    @ObservedObject private var iconStyleManager = IconStyleManager.shared

    /// Editing implies preview: an editor click must never launch an app or open the configurator.
    private var actionsDisabled: Bool { isPreview || editing != nil }

    /// Saved **List** popover-appearance values, read once when the popover is built (see
    /// StackPopoverView). List has no Show Labels setting — it always labels its rows.
    private let loadedSettings = PopoverSettings.load(layout: .list)

    /// Draft override (preview) wins over the saved values; nil → the real loaded settings.
    private var settings: PopoverSettings { settingsOverride ?? loadedSettings }

    private var metrics: PopoverListMetrics {
        PopoverMetrics.list(
            popoverSize: settings.popoverSize,
            tileSize: settings.tileSize,
            spacing: settings.spacing
        )
    }

    private var apps: [AppItem] {
        configuration?.appItems ?? []
    }

    private var tileName: String {
        configuration?.name ?? AppStrings.appName
    }

    var body: some View {
        VStack(spacing: 0) {
            // Title header (like native folder name)
            // Use hierarchical style for vibrancy
            if !tileName.isEmpty {
                Text(tileName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)
                    // One line here too — `listHeaderHeight` bills for exactly one, so a wrap would
                    // also push the panel past the height the canvas frames it to.
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    // Changing this changes `PopoverPanelLayout.listHeaderHeight` — the canvas
                    // clips this panel to a height it computes from that constant.
                    .padding(.vertical, PopoverPanelLayout.listHeaderVerticalPadding)
            }

            // App list
            if apps.isEmpty {
                emptyStateView
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(apps.enumerated()), id: \.element.id) { index, app in
                        ListAppRow(
                            app: app,
                            isSelected: selectedIndex == index,
                            metrics: metrics,
                            highlightOnHover: settings.highlightOnHover,
                            editing: editing,
                            onLaunch: onLaunch
                        )
                        // Force view recreation when icon style changes
                        // This clears NSWorkspace icon cache for this view
                        .id("\(app.id)-\(iconStyleManager.currentStyle.rawValue)")
                        .onTapGesture {
                            launchAppAt(index: index)
                        }
                        .reorderable(editing, app: app, dragged: $draggedItem)
                    }
                }
            }

            // Utility items — the editor drops them: Tile Detail already IS the configurator.
            if editing == nil {
                // Separator - use hierarchical opacity for vibrancy
                Divider()
                    .padding(.vertical, 4)

                ListMenuRow(
                    icon: "gearshape",
                    title: AppStrings.Menu.configure,
                    hasSubmenu: false,
                    action: openConfigurator
                )

                ListMenuRow(
                    icon: "folder",
                    title: AppStrings.Menu.openInFinder,
                    hasSubmenu: false,
                    action: openInFinder
                )
            }
        }
        // This panel pins only its WIDTH and takes an intrinsic height, so every vertical term here
        // is mirrored in `PopoverPanelLayout.listPanelSize` for the canvas that frames it.
        .padding(.vertical, PopoverPanelLayout.listOuterVerticalPadding)
        .frame(width: metrics.width)
        // LIQUID GLASS: Transparent SwiftUI background to allow NSVisualEffectView through
        .background(Color.clear)
        .background {
            if showsBackground { VisualEffectView.liquidGlassMenu }
        }
        .onReceive(NotificationCenter.default.publisher(for: .enableKeyboardNavigation)) { _ in
            keyboardNavigationEnabled = true
            selectedIndex = apps.isEmpty ? nil : 0
        }
        .background(KeyboardNavigationHandler(
            enabled: keyboardNavigationEnabled,
            onArrowKey: handleArrowKey,
            onEnter: handleEnter,
            onEscape: handleEscape
        ))
    }

    private var emptyStateView: some View {
        VStack(spacing: 4) {
            Text(editing != nil ? AppStrings.PopoverOption.editingNoAppsTitle : AppStrings.Empty.noApps)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
            if editing != nil {
                Text(AppStrings.PopoverOption.editingNoAppsSubtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 12)
            }
        }
        .frame(maxWidth: .infinity)
        // Every vertical term here is mirrored in `PopoverPanelLayout.listPanelSize`.
        .padding(.vertical, PopoverPanelLayout.listEmptyStatePadding)
    }

    // MARK: - Keyboard Navigation

    private func handleArrowKey(_ direction: ArrowDirection) {
        guard !apps.isEmpty else { return }

        let current = selectedIndex ?? 0
        var newIndex = current

        switch direction {
        case .up:
            newIndex = max(0, current - 1)
        case .down:
            newIndex = min(apps.count - 1, current + 1)
        case .left, .right:
            // No horizontal navigation in list view
            break
        }

        selectedIndex = newIndex
    }

    private func handleEnter() {
        if let index = selectedIndex, index < apps.count {
            launchAppAt(index: index)
        }
    }

    private func handleEscape() {
        NotificationCenter.default.post(name: .dismissLauncher, object: nil)
    }

    private func launchAppAt(index: Int) {
        guard !actionsDisabled, index < apps.count else { return }
        AppLauncher.launch(apps[index])
        onLaunch()
    }

    private func openConfigurator() {
        guard !actionsDisabled else { return }
        NotificationCenter.default.post(name: .openConfigurator, object: nil)
        onLaunch()
    }

    private func openInFinder() {
        guard !actionsDisabled else { return }
        DiagnosticsLog.shared.ui("Popover (list) → Open in Finder")
        // Open the Applications folder or configured folder
        NSWorkspace.shared.open(URL(fileURLWithPath: "/Applications"))
        onLaunch()
    }
}

// MARK: - List App Row (Small Icon + Name)

struct ListAppRow: View {
    let app: AppItem
    let isSelected: Bool
    let metrics: PopoverListMetrics
    let highlightOnHover: Bool
    /// Editing handlers from Tile Detail; nil (helpers, Settings preview) means no edit affordances.
    var editing: PopoverEditing? = nil
    let onLaunch: () -> Void

    @State private var isHovered = false

    // Observe IconStyleManager for icon style changes
    // This triggers view refresh when system icon style changes
    @ObservedObject private var iconStyleManager = IconStyleManager.shared

    /// Mouse hover uses the subtle Liquid-Glass fill (`.quaternary`); the stronger accent is kept for
    /// keyboard-focus selection. Hover honours the global "Highlight on Hover" toggle.
    private var highlightStyle: AnyShapeStyle {
        if isSelected { return AnyShapeStyle(Color(nsColor: .selectedContentBackgroundColor)) }
        if highlightOnHover && isHovered { return AnyShapeStyle(.quaternary) }
        return AnyShapeStyle(Color.clear)
    }

    var body: some View {
        // Reference iconStyleManager.currentStyle to trigger re-render when icon style changes
        let _ = iconStyleManager.currentStyle

        // Resolved ONCE per row — see StackAppItem: the probe is uncached (Launch Services +
        // stat()) and both the icon and the "Not installed" caption need it.
        let isMissing = AppInstallChecker.resolve(app).status == .missing

        HStack(spacing: metrics.rowSpacing) {
            // Icon, sized by the global Tile Size setting.
            appIconView(isMissing: isMissing)
                .frame(width: metrics.iconSize, height: metrics.iconSize)

            // White text on the accent keyboard-selection; normal text on the subtle hover fill.
            Text(app.name)
                .font(.system(size: metrics.fontSize))
                .foregroundStyle(isSelected ? Color.white : Color.primary)
                .lineLimit(1)

            Spacer()

            // The editor names the "app is gone" state outright; the shipped popover keeps to the
            // dimmed placeholder icon.
            if editing != nil, isMissing {
                Text(AppStrings.Label.notInstalled)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }

            if let editing, isHovered {
                Button { editing.onRemove(app) } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(AppStrings.PopoverOption.editingRemove)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, metrics.rowVerticalPadding)
        // Keep the row hit target ≥44pt wide even at the smallest tile/spacing tier.
        .frame(minHeight: 28)
        .background(
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(highlightStyle)
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovered = hovering
        }
        .removeAffordances(editing, for: app)
    }

    @ViewBuilder
    private func appIconView(isMissing: Bool) -> some View {
        // Resolved synchronously so a deleted app shows the placeholder, not its stale icon.
        if isMissing {
            Image(systemName: "questionmark.app.dashed")
                .font(.system(size: metrics.iconSize * 0.75))
                .foregroundStyle(.secondary)
        } else if let nsImage = AppIconLoader.icon(for: app) {
            Image(nsImage: nsImage)
                .resizable()
                .interpolation(.high)
        } else {
            Image(systemName: "app.fill")
                .font(.system(size: metrics.iconSize * 0.75))
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - List Menu Row (Utility Items)

struct ListMenuRow: View {
    let icon: String
    let title: String
    let hasSubmenu: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundStyle(.primary)
                    .frame(width: 16)

                Text(title)
                    .font(.system(size: 13))
                    .foregroundStyle(.primary)

                Spacer()

                if hasSubmenu {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(
                // Subtle Liquid-Glass hover fill (matches the app rows), not the bold accent.
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(isHovered ? AnyShapeStyle(.quaternary) : AnyShapeStyle(Color.clear))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - Previews

#Preview("Stack View") {
    StackPopoverView(
        configuration: DockTileConfiguration(
            name: "mac-ai-shortcuts",
            tintColor: .blue,
            symbolEmoji: "🤖",
            appItems: [
                AppItem(bundleIdentifier: "com.google.gemini", name: "Google Gemini"),
                AppItem(bundleIdentifier: "com.google.notebooklm", name: "NotebookLM"),
                AppItem(bundleIdentifier: "com.openai.chatgpt", name: "ChatGPT"),
                AppItem(bundleIdentifier: "com.anthropic.claude", name: "Claude")
            ]
        ),
        onLaunch: {}
    )
    .frame(width: 340, height: 280)
}

#Preview("List View") {
    ListPopoverView(
        configuration: DockTileConfiguration(
            name: "mac-ai-shortcuts",
            tintColor: .blue,
            symbolEmoji: "🤖",
            appItems: [
                AppItem(bundleIdentifier: "com.google.gemini", name: "Google Gemini"),
                AppItem(bundleIdentifier: "com.google.notebooklm", name: "NotebookLM"),
                AppItem(bundleIdentifier: "com.openai.chatgpt", name: "ChatGPT"),
                AppItem(bundleIdentifier: "com.anthropic.claude", name: "Claude")
            ]
        ),
        onLaunch: {}
    )
}
