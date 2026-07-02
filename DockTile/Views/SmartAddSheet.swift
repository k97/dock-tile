//
//  SmartAddSheet.swift
//  DockTile
//
//  The "Smart Add" sheet (design frame 1a): shown when the user presses + and the on-device
//  engine can suggest ready-made tiles from recent app usage. Native recreation of the handoff —
//  system materials, SF Pro, continuous-corner squircles, translucent card over the dimmed window.
//
//  Button hierarchy (Apple HIG — deliberate): exactly ONE prominent button (the top pick, the
//  Return-key default); the other suggestions are accent-tinted; "Create New Tile" is a neutral
//  bordered button (blue is reserved for the smart suggestions so the manual path stays distinct).
//  Nothing here touches the Dock — picking a tile only pre-fills Tile Detail; the explicit
//  "Add to Dock" confirm still lives there.
//
//  Swift 6 - Strict Concurrency
//

import SwiftUI

struct SmartAddSheet: View {
    let suggestions: [TileSuggestion]
    let onUse: (TileSuggestion) -> Void
    let onCreateNew: () -> Void
    let onClose: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            cardsRow
            Divider()
            footer
        }
        .frame(width: 624)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityIdentifier("smartAddSheet")
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            sparkleBadge

            VStack(alignment: .leading, spacing: 3) {
                Text(AppStrings.SmartAdd.title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.primary)

                Text(AppStrings.SmartAdd.subtitle)
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            closeButton
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
    }

    /// 30×30 gradient sparkle badge with a white SF Symbol (matches the handoff blue gradient).
    private var sparkleBadge: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [Color(hex: "#7AA7FF"), Color(hex: "#3B6BFF")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: 30, height: 30)
            .overlay(
                Image(systemName: "sparkles")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
            )
            .accessibilityHidden(true)
    }

    private var closeButton: some View {
        Button(action: onClose) {
            Image(systemName: "xmark")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.secondary)
                .frame(width: 22, height: 22)
                .background(Color(nsColor: .quaternaryLabelColor), in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .keyboardShortcut(.cancelAction)          // Esc closes and creates nothing
        .accessibilityLabel(AppStrings.Button.cancel)
    }

    // MARK: - Cards

    private var cardsRow: some View {
        HStack(alignment: .top, spacing: 12) {
            ForEach(suggestions) { suggestion in
                SuggestionCard(
                    suggestion: suggestion,
                    reduceMotion: reduceMotion,
                    action: { onUse(suggestion) }
                )
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 8) {
            Image(systemName: "lock.fill")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)

            Text(AppStrings.SmartAdd.privacyFootnote)
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)

            Spacer(minLength: 12)

            Button(action: onCreateNew) {
                Label(AppStrings.Button.createNewTile, systemImage: "plus")
                    .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(.borderedProminent)    // the single filled button — also the Return default
            .tint(.accentColor)
            .controlSize(.regular)
            .keyboardShortcut(.defaultAction)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 11)
    }
}

// MARK: - Suggestion Card

private struct SuggestionCard: View {
    let suggestion: TileSuggestion
    let reduceMotion: Bool
    let action: () -> Void

    @State private var isHovering = false

    /// Up to four member-app icons are shown; the rest are summarised as "+N".
    private var visibleApps: [AppItem] { Array(suggestion.appItems.prefix(4)) }
    private var overflowCount: Int { max(0, suggestion.appItems.count - visibleApps.count) }

    var body: some View {
        VStack(spacing: 9) {
            DockTileIconPreview(
                tintColor: suggestion.tint,
                iconType: .sfSymbol,
                iconValue: suggestion.symbol,
                iconScale: ConfigurationDefaults.iconScale,
                iconWeight: ConfigurationDefaults.iconWeight,
                size: 58
            )
            .shadow(color: suggestion.tint.color.opacity(0.35), radius: 6, y: 3)

            Text(suggestion.name)
                .font(.system(size: 13.5, weight: .semibold))
                .foregroundStyle(.primary)

            reasonChip

            memberRow

            actionButton
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity)
        .background(cardBackground)
        .overlay(cardBorder)
        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
        .onHover { hovering in
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.12)) {
                isHovering = hovering
            }
        }
    }

    private var reasonChip: some View {
        HStack(spacing: 4) {
            Image(systemName: reasonGlyph)
                .font(.system(size: 9, weight: .semibold))
            Text(suggestion.reason)
                .font(.system(size: 10.5, weight: .medium))
        }
        .foregroundStyle(.secondary)
        .padding(.vertical, 2)
        .padding(.horizontal, 8)
        .background(Color(nsColor: .quaternaryLabelColor).opacity(0.5),
                    in: RoundedRectangle(cornerRadius: 9, style: .continuous))
    }

    private var reasonGlyph: String {
        switch suggestion.strategy {
        case .category: return "square.grid.2x2"
        case .recency:  return "clock"
        case .coLaunch: return "link"
        }
    }

    private var memberRow: some View {
        HStack(spacing: 4) {
            ForEach(visibleApps) { app in
                AppIconView(item: app)
                    .frame(width: 22, height: 22)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
            if overflowCount > 0 {
                Text("+\(overflowCount)")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 22, height: 22)
                    .background(Color(nsColor: .quaternaryLabelColor).opacity(0.5),
                                in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
        }
        .frame(height: 22)
    }

    /// Every suggestion uses the same accent-tinted button (blue label on a light-blue fill) — the
    /// prominent filled button in this sheet is "Create New Tile" (see the footer).
    private var actionButton: some View {
        Button(action: action) {
            Text(AppStrings.Button.useThisTile)
                .font(.system(size: 12, weight: .medium))
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .tint(.accentColor)
        .controlSize(.regular)
    }

    // MARK: Card chrome

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 11, style: .continuous)
            .fill(isHovering ? Color.accentColor.opacity(0.06) : Color.clear)
    }

    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: 11, style: .continuous)
            .strokeBorder(
                isHovering ? Color.accentColor.opacity(0.55)
                           : Color(nsColor: .separatorColor),
                lineWidth: 1
            )
    }
}

// MARK: - Preview

#Preview {
    SmartAddSheet(
        suggestions: [
            TileSuggestion(name: "Watch", strategy: .recency, reason: "Most used this week",
                           tint: .pink, symbol: "play.fill",
                           appItems: [
                               AppItem(bundleIdentifier: "com.apple.TV", name: "TV"),
                               AppItem(bundleIdentifier: "com.netflix.Netflix", name: "Netflix"),
                               AppItem(bundleIdentifier: "com.spotify.client", name: "Spotify")
                           ]),
            TileSuggestion(name: "Browse", strategy: .category, reason: "By category",
                           tint: .blue, symbol: "globe",
                           appItems: [
                               AppItem(bundleIdentifier: "com.apple.Safari", name: "Safari"),
                               AppItem(bundleIdentifier: "com.google.Chrome", name: "Chrome"),
                               AppItem(bundleIdentifier: "org.mozilla.firefox", name: "Firefox")
                           ]),
            TileSuggestion(name: "Chat", strategy: .coLaunch, reason: "Opened together",
                           tint: .green, symbol: "bubble.left.and.bubble.right",
                           appItems: [
                               AppItem(bundleIdentifier: "com.tinyspeck.slackmacgap", name: "Slack"),
                               AppItem(bundleIdentifier: "com.hnc.Discord", name: "Discord"),
                               AppItem(bundleIdentifier: "net.whatsapp.WhatsApp", name: "WhatsApp")
                           ])
        ],
        onUse: { _ in },
        onCreateNew: {},
        onClose: {}
    )
    .padding(40)
    .frame(width: 768, height: 420)
}
