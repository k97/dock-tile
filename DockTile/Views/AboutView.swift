//
//  AboutView.swift
//  DockTile
//
//  The About pane (v2): lives in the sidebar under "Dock Tile" — the only home of Software Update.
//  Swift 6 - Strict Concurrency
//

import SwiftUI

/// Links the pane opens. `feedback` comes from Info.plist `DTFeedbackEmail` (mailto:) when set,
/// otherwise the website — never a hard-coded address.
enum AboutLinks {
    /// Every human-facing link the app opens is tagged, so the sites can tell app traffic from
    /// search or social. Machine-read URLs (the Sparkle appcast) are never tagged.
    private static let campaign = "utm_source=docktile-mac"

    static let website = URL(string: "https://docktile.app/?\(campaign)")!
    static let studio  = URL(string: "https://happymachines.company/?\(campaign)")!
    static let spades  = URL(string: "https://spadesaudio.com/?\(campaign)")!
    /// What the rows show — the bare hosts, without the tracking query.
    static let websiteDisplay = "docktile.app"
    static let studioDisplay  = "happymachines.company"
    static var feedback: URL {
        guard let email = Bundle.main.object(forInfoDictionaryKey: "DTFeedbackEmail") as? String,
              !email.isEmpty else { return website }
        // Build through URLComponents rather than interpolating: the address comes from Info.plist,
        // and an unencoded subject or a stray character would silently yield a nil URL.
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = email
        components.queryItems = [URLQueryItem(name: "subject", value: "Dock Tile feedback")]
        return components.url ?? website
    }
}

struct AboutPaneView: View {
    @EnvironmentObject private var configManager: ConfigurationManager
    @EnvironmentObject private var updateController: UpdateController

    private var copyright: String {
        Bundle.main.object(forInfoDictionaryKey: "NSHumanReadableCopyright") as? String ?? ""
    }

    // One grouped Form (a Form is List-backed and will not size itself inside a ScrollView): the hero
    // rides as a full-bleed, clear-background first row.
    var body: some View {
        Form {
                    Section {
                        hero
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                    }
                    Section {
                        LabeledContent {
                            Button(AppStrings.Button.checkForUpdates) {
                                DiagnosticsLog.shared.ui("About → Check for Updates")
                                updateController.checkForUpdates()
                            }
                            .disabled(!updateController.canCheckForUpdates)
                        } label: {
                            Text(AppStrings.appName)
                            Text(AppStrings.About.version(AppEnvironment.appVersion))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        LabeledContent(AppStrings.About.website) {
                            Link(AboutLinks.websiteDisplay, destination: AboutLinks.website)
                        }
                    }
                    // Support actions as ordinary settings rows — label and description leading, a
                    // single button trailing — so they read like the Check for Updates row above
                    // rather than a card with two stretched buttons under it.
                    Section {
                        LabeledContent {
                            Button(AppStrings.About.sendFeedback) {
                                DiagnosticsLog.shared.ui("About → Send Feedback")
                                NSWorkspace.shared.open(AboutLinks.feedback)
                            }
                        } label: {
                            Text(AppStrings.About.feedbackTitle)
                            Text(AppStrings.About.feedbackRowBody)
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        LabeledContent {
                            // "Copy", not "Copy Diagnostics" — the row label already says which.
                            Button(AppStrings.Button.copy) {
                                DiagnosticsLog.shared.ui("About → Copy Diagnostics")
                                DiagnosticsLog.shared.copyToPasteboard()
                            }
                            .accessibilityLabel(AppStrings.Menu.copyDiagnostics)
                        } label: {
                            Text(AppStrings.About.diagnosticsTitle)
                            Text(AppStrings.About.diagnosticsBody)
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Section {
                        studioRow(icon: { HappyMachinesMark() },
                                  title: AppStrings.About.studioTitle,
                                  subtitle: AppStrings.About.studioSubtitle) {
                            Link(AboutLinks.studioDisplay, destination: AboutLinks.studio)
                        }
                        studioRow(icon: { SpadesMark() },
                                  title: AppStrings.About.spadesTitle,
                                  subtitle: AppStrings.About.spadesSubtitle) {
                            Button(AppStrings.About.learnMore) { NSWorkspace.shared.open(AboutLinks.spades) }
                        }
                    } header: {
                        Text(AppStrings.About.alsoFrom)
                    } footer: {
                        Text(copyright)
                            .font(.caption).foregroundStyle(.tertiary)
                            .frame(maxWidth: .infinity)
                    }
        }
        .formStyle(.grouped)
        .paneTitleBand(AppStrings.About.title)
    }

    /// The product in context: the user's first three tiles (or the defaults) on a Dock strip.
    private var hero: some View {
        let tiles = Array(configManager.configurations.prefix(3))
        return HStack(spacing: 10) {
            if tiles.isEmpty {
                ForEach([TintColor.blue, .purple, .pink], id: \.self) { tint in
                    DockTileIconPreview(tintColor: tint, iconType: .sfSymbol, iconValue: "folder.fill",
                                        iconScale: ConfigurationDefaults.iconScale,
                                        iconWeight: ConfigurationDefaults.iconWeight, size: 48)
                }
            } else {
                ForEach(tiles) { DockTileIconPreview.fromConfig($0, size: 48) }
            }
            Divider().frame(height: 40)
            Image(nsImage: VendorMark.folderIcon).resizable().frame(width: 48, height: 48)
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(StudioCanvasBackgroundView())
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(AppStrings.appName)
    }

    private func studioRow<Trailing: View, Icon: View>(@ViewBuilder icon: () -> Icon,
                                                       title: String, subtitle: String,
                                                       @ViewBuilder trailing: () -> Trailing) -> some View {
        LabeledContent {
            trailing()
        } label: {
            HStack(spacing: 12) {
                icon().frame(width: 28, height: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                    Text(subtitle).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }
}

// MARK: - Vendor marks

/// The real Happy Machines and Spades marks, bundled as loose resources (this project has no asset
/// catalog — see `DockTileGlyph.png` for the same pattern).
///
/// Each falls back to an SF Symbol if its file is missing or fails to decode: a bundled image that
/// doesn't load renders as **nothing at all**, and an empty gap beside a product name reads as a
/// layout bug rather than a missing asset.
enum VendorMark {

    /// Decoded once each, not per body evaluation — a SwiftUI view's `body` runs on every render,
    /// and these were re-reading and re-decoding their files each time.
    ///
    /// Happy Machines: a single monochrome stroke, so it ships as ONE vector and is drawn as a
    /// template tinted to the current foreground — no light/dark pair to keep in sync.
    static let happyMachines: NSImage? = {
        guard let url = Bundle.main.url(forResource: "HappyMachinesLogo", withExtension: "svg"),
              let image = NSImage(contentsOf: url) else { return nil }
        image.isTemplate = true
        return image
    }()

    /// Spades ships a full-colour app icon, so it can't be tinted — it takes the light or dark
    /// rendition the way the Dock would. Both are held; the pane switches between them on theme.
    private static let spadesLight = load("SpadesIconLight")
    private static let spadesDark = load("SpadesIconDark")

    static func spades(dark: Bool) -> NSImage? { dark ? spadesDark : spadesLight }

    private static func load(_ name: String) -> NSImage? {
        Bundle.main.url(forResource: name, withExtension: "png").flatMap(NSImage.init(contentsOf:))
    }

    /// The system folder icon in the About hero — resolved once for the same reason.
    static let folderIcon: NSImage = NSWorkspace.shared.icon(for: .folder)
}

/// Happy Machines' mark, tinted to the foreground; the smiling-face symbol if the asset is absent.
private struct HappyMachinesMark: View {
    var body: some View {
        if let mark = VendorMark.happyMachines {
            Image(nsImage: mark)
                .resizable()
                .renderingMode(.template)
                .aspectRatio(contentMode: .fit)
                .foregroundStyle(.primary)
                .padding(1)
        } else {
            SettingsBadgeIcon(systemName: "face.smiling", tint: .orange, size: 28)
        }
    }
}

/// Spades' app icon at its natural corner radius; the spade symbol if the asset is absent.
private struct SpadesMark: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        if let mark = VendorMark.spades(dark: colorScheme == .dark) {
            Image(nsImage: mark)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        } else {
            SettingsBadgeIcon(systemName: "suit.spade.fill", tint: .black, size: 28)
        }
    }
}
