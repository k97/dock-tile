//
//  EmojiPickerGrid.swift
//  DockTile
//
//  Categorized emoji grid picker for tile icon customization
//  Swift 6 - Strict Concurrency
//

import SwiftUI

struct EmojiPickerGrid: View {
    @Binding var selectedEmoji: String
    @Binding var searchText: String
    let onSelect: (String) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
    private let emojiSize: CGFloat = 28

    /// Filter emojis based on search text using keywords
    private func filteredEmojis(for category: EmojiCategory) -> [String] {
        guard !searchText.isEmpty else { return category.emojis }
        let query = searchText.lowercased()
        return category.emojis.filter { emoji in
            // Check if any keyword for this emoji matches the search
            if let keywords = EmojiKeywords.keywords[emoji] {
                return keywords.contains { $0.contains(query) }
            }
            return false
        }
    }

    /// Check if category has any matching emojis
    private func categoryHasMatches(_ category: EmojiCategory) -> Bool {
        !filteredEmojis(for: category).isEmpty
    }

    var body: some View {
        // Emoji grid only - search field is managed by parent
        LazyVStack(alignment: .leading, spacing: 16) {
            ForEach(EmojiCategory.allCases, id: \.self) { category in
                if categoryHasMatches(category) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(category.displayName)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)

                        LazyVGrid(columns: columns, spacing: 4) {
                            ForEach(filteredEmojis(for: category), id: \.self) { emoji in
                                EmojiButton(
                                    emoji: emoji,
                                    isSelected: selectedEmoji == emoji,
                                    size: emojiSize
                                ) {
                                    selectedEmoji = emoji
                                    onSelect(emoji)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Emoji Button

private struct EmojiButton: View {
    let emoji: String
    let isSelected: Bool
    let size: CGFloat
    let onTap: () -> Void

    /// Subtle contact shadow so picker emoji share the tiles' raised-on-glass feel.
    private var glyphShadow: IconDepthMetrics.GlyphShadow? {
        IconDepthMetrics.glyphShadow(style: .defaultStyle, iconType: .emoji, nominalSize: size)
    }

    var body: some View {
        Button(action: onTap) {
            Text(emoji)
                .font(.system(size: size))
                .shadow(
                    color: glyphShadow.map { Color.black.opacity($0.blackAlpha) } ?? .clear,
                    radius: glyphShadow?.blur ?? 0,
                    y: glyphShadow?.offset ?? 0
                )
                .frame(width: 40, height: 40)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
                        )
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Emoji Categories

enum EmojiCategory: CaseIterable {
    case people
    case animalsNature
    case foodDrink
    case activity
    case travelPlaces
    case objects
    case symbols

    var displayName: String {
        switch self {
        case .people: return "People"
        case .animalsNature: return "Animals & Nature"
        case .foodDrink: return "Food & Drink"
        case .activity: return "Activity"
        case .travelPlaces: return "Travel & Places"
        case .objects: return "Objects"
        case .symbols: return "Symbols"
        }
    }

    var emojis: [String] {
        switch self {
        case .people:
            return [
                "😀", "😃", "😄", "😁", "😆", "😅", "🤣",
                "😂", "🙂", "🙃", "😉", "😊", "😇", "🥰",
                "😍", "🤩", "😘", "😗", "😚", "😙", "🥲",
                "😋", "😛", "😜", "🤪", "😝", "🤑", "🤗",
                "🤭", "🤫", "🤔", "🤐", "🤨", "😐", "😑",
                "😶", "😏", "😒", "🙄", "😬", "🤥", "😌",
                "😔", "😪", "🤤", "😴", "😷", "🤒", "🤕",
                "🤢", "🤮", "🤧", "🥵", "🥶", "🥴", "😵",
                "🤯", "🤠", "🥳", "🥸", "😎", "🤓", "🧐",
                "👶", "👧", "🧒", "👦", "👩", "🧑", "👨",
                "👩‍🦱", "🧑‍🦱", "👨‍🦱", "👩‍🦰", "🧑‍🦰", "👨‍🦰", "👱‍♀️",
                "👱", "👱‍♂️", "👩‍🦳", "🧑‍🦳", "👨‍🦳", "👩‍🦲", "🧑‍🦲",
                "👴", "👵", "🧓", "👮", "👷", "💂", "🕵️",
                "👩‍⚕️", "👩‍🎓", "👩‍🏫", "👩‍⚖️", "👩‍🌾", "👩‍🍳", "👩‍🔧",
                "👩‍🏭", "👩‍💼", "👩‍🔬", "👩‍💻", "👩‍🎤", "👩‍🎨", "👩‍✈️",
                "👩‍🚀", "👩‍🚒", "🧙", "🧚", "🧛", "🧜", "🧝"
            ]

        case .animalsNature:
            return [
                "🐶", "🐱", "🐭", "🐹", "🐰", "🦊", "🐻",
                "🐼", "🐻‍❄️", "🐨", "🐯", "🦁", "🐮", "🐷",
                "🐽", "🐸", "🐵", "🙈", "🙉", "🙊", "🐒",
                "🐔", "🐧", "🐦", "🐤", "🐣", "🐥", "🦆",
                "🦅", "🦉", "🦇", "🐺", "🐗", "🐴", "🦄",
                "🐝", "🐛", "🦋", "🐌", "🐞", "🐜", "🦟",
                "🦗", "🕷️", "🦂", "🐢", "🐍", "🦎", "🦖",
                "🦕", "🐙", "🦑", "🦐", "🦞", "🦀", "🐡",
                "🐠", "🐟", "🐬", "🐳", "🐋", "🦈", "🐊",
                "🐅", "🐆", "🦓", "🦍", "🦧", "🦣", "🐘",
                "🦛", "🦏", "🐪", "🐫", "🦒", "🦘", "🦬",
                "🐃", "🐂", "🐄", "🐎", "🐖", "🐏", "🐑",
                "🦙", "🐐", "🦌", "🐕", "🐩", "🦮", "🐕‍🦺",
                "🐈", "🐈‍⬛", "🪶", "🐓", "🦃", "🦤", "🦚",
                "🦜", "🦢", "🦩", "🕊️", "🐇", "🦝", "🦨",
                "🦡", "🦫", "🦦", "🦥", "🐁", "🐀", "🐿️",
                "🦔", "🌵", "🎄", "🌲", "🌳", "🌴", "🪵",
                "🌱", "🌿", "☘️", "🍀", "🎍", "🪴", "🎋",
                "🍃", "🍂", "🍁", "🪺", "🪹", "🍄", "🐚",
                "🪸", "🪨", "🌾", "💐", "🌷", "🌹", "🥀",
                "🪻", "🌺", "🌸", "🌼", "🌻", "🌞", "🌝",
                "🌛", "🌜", "🌚", "🌕", "🌖", "🌗", "🌘",
                "🌑", "🌒", "🌓", "🌔", "🌙", "🌎", "🌍",
                "🌏", "🪐", "💫", "⭐", "🌟", "✨", "⚡",
                "☄️", "💥", "🔥", "🌪️", "🌈", "☀️", "🌤️",
                "⛅", "🌥️", "☁️", "🌦️", "🌧️", "⛈️", "🌩️",
                "🌨️", "❄️", "☃️", "⛄", "🌬️", "💨", "💧",
                "💦", "🫧", "☔", "☂️", "🌊", "🌫️"
            ]

        case .foodDrink:
            return [
                "🍏", "🍎", "🍐", "🍊", "🍋", "🍌", "🍉",
                "🍇", "🍓", "🫐", "🍈", "🍒", "🍑", "🥭",
                "🍍", "🥥", "🥝", "🍅", "🍆", "🥑", "🥦",
                "🥬", "🥒", "🌶️", "🫑", "🌽", "🥕", "🫒",
                "🧄", "🧅", "🥔", "🍠", "🥐", "🥯", "🍞",
                "🥖", "🥨", "🧀", "🥚", "🍳", "🧈", "🥞",
                "🧇", "🥓", "🥩", "🍗", "🍖", "🦴", "🌭",
                "🍔", "🍟", "🍕", "🫓", "🥪", "🥙", "🧆",
                "🌮", "🌯", "🫔", "🥗", "🥘", "🫕", "🥫",
                "🍝", "🍜", "🍲", "🍛", "🍣", "🍱", "🥟",
                "🦪", "🍤", "🍙", "🍚", "🍘", "🍥", "🥠",
                "🥮", "🍢", "🍡", "🍧", "🍨", "🍦", "🥧",
                "🧁", "🍰", "🎂", "🍮", "🍭", "🍬", "🍫",
                "🍿", "🍩", "🍪", "🌰", "🥜", "🍯", "🥛",
                "🍼", "🫖", "☕", "🍵", "🧃", "🥤", "🧋",
                "🍶", "🍺", "🍻", "🥂", "🍷", "🥃", "🍸",
                "🍹", "🧊", "🫗", "🥄", "🍴", "🍽️", "🥣",
                "🥡", "🥢", "🧂"
            ]

        case .activity:
            return [
                "⚽", "🏀", "🏈", "⚾", "🥎", "🎾", "🏐",
                "🏉", "🥏", "🎱", "🪀", "🏓", "🏸", "🏒",
                "🏑", "🥍", "🏏", "🪃", "🥅", "⛳", "🪁",
                "🏹", "🎣", "🤿", "🥊", "🥋", "🎽", "🛹",
                "🛼", "🛷", "⛸️", "🥌", "🎿", "⛷️", "🏂",
                "🪂", "🏋️", "🤼", "🤸", "🤺", "⛹️", "🏌️",
                "🏇", "🧘", "🏄", "🏊", "🤽", "🚣", "🧗",
                "🚵", "🚴", "🏆", "🥇", "🥈", "🥉", "🏅",
                "🎖️", "🏵️", "🎗️", "🎫", "🎟️", "🎪", "🎭",
                "🩰", "🎨", "🎬", "🎤", "🎧", "🎼", "🎹",
                "🥁", "🪘", "🎷", "🎺", "🪗", "🎸", "🪕",
                "🎻", "🪈", "🎲", "♟️", "🎯", "🎳", "🎮",
                "🎰", "🧩"
            ]

        case .travelPlaces:
            return [
                "🚗", "🚕", "🚙", "🚌", "🚎", "🏎️", "🚓",
                "🚑", "🚒", "🚐", "🛻", "🚚", "🚛", "🚜",
                "🦯", "🦽", "🦼", "🛴", "🚲", "🛵", "🏍️",
                "🛺", "🚨", "🚔", "🚍", "🚘", "🚖", "🚡",
                "🚠", "🚟", "🚃", "🚋", "🚞", "🚝", "🚄",
                "🚅", "🚈", "🚂", "🚆", "🚇", "🚊", "🚉",
                "✈️", "🛫", "🛬", "🛩️", "💺", "🛰️", "🚀",
                "🛸", "🚁", "🛶", "⛵", "🚤", "🛥️", "🛳️",
                "⛴️", "🚢", "⚓", "🪝", "⛽", "🚧", "🚦",
                "🚥", "🚏", "🗺️", "🗿", "🗽", "🗼", "🏰",
                "🏯", "🏟️", "🎡", "🎢", "🎠", "⛲", "⛱️",
                "🏖️", "🏝️", "🏜️", "🌋", "⛰️", "🏔️", "🗻",
                "🏕️", "⛺", "🛖", "🏠", "🏡", "🏘️", "🏚️",
                "🏗️", "🏭", "🏢", "🏬", "🏣", "🏤", "🏥",
                "🏦", "🏨", "🏪", "🏫", "🏩", "💒", "🏛️",
                "⛪", "🕌", "🕍", "🛕", "🕋", "⛩️", "🛤️",
                "🛣️", "🗾", "🎑", "🏞️", "🌅", "🌄", "🌠",
                "🎇", "🎆", "🌇", "🌆", "🏙️", "🌃", "🌌",
                "🌉", "🌁"
            ]

        case .objects:
            return [
                "⌚", "📱", "📲", "💻", "⌨️", "🖥️", "🖨️",
                "🖱️", "🖲️", "🕹️", "🗜️", "💽", "💾", "💿",
                "📀", "📼", "📷", "📸", "📹", "🎥", "📽️",
                "🎞️", "📞", "☎️", "📟", "📠", "📺", "📻",
                "🎙️", "🎚️", "🎛️", "🧭", "⏱️", "⏲️", "⏰",
                "🕰️", "⌛", "⏳", "📡", "🔋", "🪫", "🔌",
                "💡", "🔦", "🕯️", "🪔", "🧯", "🛢️", "💸",
                "💵", "💴", "💶", "💷", "🪙", "💰", "💳",
                "💎", "⚖️", "🪜", "🧰", "🪛", "🔧", "🔨",
                "⚒️", "🛠️", "⛏️", "🪚", "🔩", "⚙️", "🪤",
                "🧱", "⛓️", "🧲", "🔫", "💣", "🧨", "🪓",
                "🔪", "🗡️", "⚔️", "🛡️", "🚬", "⚰️", "🪦",
                "⚱️", "🏺", "🔮", "📿", "🧿", "🪬", "💈",
                "⚗️", "🔭", "🔬", "🕳️", "🩹", "🩺", "🩻",
                "🩼", "💊", "💉", "🩸", "🧬", "🦠", "🧫",
                "🧪", "🌡️", "🧹", "🪠", "🧺", "🧻", "🚽",
                "🚰", "🚿", "🛁", "🛀", "🧼", "🪥", "🪒",
                "🧽", "🪣", "🧴", "🛎️", "🔑", "🗝️", "🚪",
                "🪑", "🛋️", "🛏️", "🛌", "🧸", "🪆", "🖼️",
                "🪞", "🪟", "🛍️", "🛒", "🎁", "🎈", "🎏",
                "🎀", "🪄", "🪅", "🎊", "🎉", "🎎", "🏮",
                "🎐", "🧧", "✉️", "📩", "📨", "📧", "💌",
                "📥", "📤", "📦", "🏷️", "🪧", "📪", "📫",
                "📬", "📭", "📮", "📯", "📜", "📃", "📄",
                "📑", "🧾", "📊", "📈", "📉", "🗒️", "🗓️",
                "📆", "📅", "🗑️", "📇", "🗃️", "🗳️", "🗄️",
                "📋", "📁", "📂", "🗂️", "🗞️", "📰", "📓",
                "📔", "📒", "📕", "📗", "📘", "📙", "📚",
                "📖", "🔖", "🧷", "🔗", "📎", "🖇️", "📐",
                "📏", "🧮", "📌", "📍", "✂️", "🖊️", "🖋️",
                "✒️", "🖌️", "🖍️", "📝", "✏️", "🔍", "🔎",
                "🔏", "🔐", "🔒", "🔓"
            ]

        case .symbols:
            return [
                "❤️", "🧡", "💛", "💚", "💙", "💜", "🖤",
                "🤍", "🤎", "💔", "❤️‍🔥", "❤️‍🩹", "❣️", "💕",
                "💞", "💓", "💗", "💖", "💘", "💝", "💟",
                "☮️", "✝️", "☪️", "🕉️", "☸️", "✡️", "🔯",
                "🕎", "☯️", "☦️", "🛐", "⛎", "♈", "♉",
                "♊", "♋", "♌", "♍", "♎", "♏", "♐",
                "♑", "♒", "♓", "🆔", "⚛️", "🉑", "☢️",
                "☣️", "📴", "📳", "🈶", "🈚", "🈸", "🈺",
                "🈷️", "✴️", "🆚", "💮", "🉐", "㊙️", "㊗️",
                "🈴", "🈵", "🈹", "🈲", "🅰️", "🅱️", "🆎",
                "🆑", "🅾️", "🆘", "❌", "⭕", "🛑", "⛔",
                "📛", "🚫", "💯", "💢", "♨️", "🚷", "🚯",
                "🚳", "🚱", "🔞", "📵", "🚭", "❗", "❕",
                "❓", "❔", "‼️", "⁉️", "🔅", "🔆", "〽️",
                "⚠️", "🚸", "🔱", "⚜️", "🔰", "♻️", "✅",
                "🈯", "💹", "❇️", "✳️", "❎", "🌐", "💠",
                "Ⓜ️", "🌀", "💤", "🏧", "🚾", "♿", "🅿️",
                "🛗", "🈳", "🈂️", "🛂", "🛃", "🛄", "🛅",
                "🚹", "🚺", "🚼", "⚧️", "🚻", "🚮", "🎦",
                "📶", "🈁", "🔣", "ℹ️", "🔤", "🔡", "🔠",
                "🆖", "🆗", "🆙", "🆒", "🆕", "🆓", "0️⃣",
                "1️⃣", "2️⃣", "3️⃣", "4️⃣", "5️⃣", "6️⃣", "7️⃣",
                "8️⃣", "9️⃣", "🔟", "🔢", "#️⃣", "*️⃣", "⏏️",
                "▶️", "⏸️", "⏯️", "⏹️", "⏺️", "⏭️", "⏮️",
                "⏩", "⏪", "⏫", "⏬", "◀️", "🔼", "🔽",
                "➡️", "⬅️", "⬆️", "⬇️", "↗️", "↘️", "↙️",
                "↖️", "↕️", "↔️", "↪️", "↩️", "⤴️", "⤵️",
                "🔀", "🔁", "🔂", "🔄", "🔃", "🎵", "🎶",
                "➕", "➖", "➗", "✖️", "🟰", "♾️", "💲",
                "💱", "™️", "©️", "®️", "〰️", "➰", "➿",
                "🔚", "🔙", "🔛", "🔝", "🔜", "✔️", "☑️",
                "🔘", "🔴", "🟠", "🟡", "🟢", "🔵", "🟣",
                "⚫", "⚪", "🟤", "🔺", "🔻", "🔸", "🔹",
                "🔶", "🔷", "🔳", "🔲", "▪️", "▫️", "◾",
                "◽", "◼️", "◻️", "🟥", "🟧", "🟨", "🟩",
                "🟦", "🟪", "⬛", "⬜", "🟫", "🔈", "🔇",
                "🔉", "🔊", "🔔", "🔕", "📣", "📢", "👁️‍🗨️",
                "💬", "💭", "🗯️", "♠️", "♣️", "♥️", "♦️",
                "🃏", "🎴", "🀄", "🕐", "🕑", "🕒", "🕓",
                "🕔", "🕕", "🕖", "🕗", "🕘", "🕙", "🕚",
                "🕛", "🕜", "🕝", "🕞", "🕟", "🕠", "🕡",
                "🕢", "🕣", "🕤", "🕥", "🕦", "🕧"
            ]
        }
    }
}

// MARK: - Emoji Keywords for Search

/// Maps emojis to searchable keywords
enum EmojiKeywords {
    static let keywords: [String: [String]] = [
        // People - Faces
        "😀": ["smile", "happy", "grin", "face"],
        "😃": ["smile", "happy", "grin", "face", "open"],
        "😄": ["smile", "happy", "grin", "face", "eyes"],
        "😁": ["smile", "happy", "grin", "teeth"],
        "😆": ["laugh", "happy", "xd", "face"],
        "😅": ["sweat", "smile", "nervous", "relief"],
        "🤣": ["rofl", "laugh", "rolling", "floor"],
        "😂": ["joy", "laugh", "tears", "lol"],
        "🙂": ["smile", "face", "slight"],
        "🙃": ["upside", "down", "silly", "face"],
        "😉": ["wink", "face", "flirt"],
        "😊": ["blush", "smile", "happy", "shy"],
        "😇": ["angel", "halo", "innocent", "blessed"],
        "🥰": ["love", "hearts", "face", "adore"],
        "😍": ["love", "eyes", "heart", "crush"],
        "🤩": ["star", "eyes", "excited", "starstruck"],
        "😘": ["kiss", "love", "heart", "wink"],
        "😎": ["cool", "sunglasses", "confident"],
        "🤓": ["nerd", "glasses", "geek", "smart"],
        "🥳": ["party", "celebrate", "birthday", "hat"],
        "😴": ["sleep", "tired", "zzz", "snore"],
        "🤔": ["think", "hmm", "wonder", "consider"],
        "🤗": ["hug", "hands", "open", "embrace"],
        "🤫": ["quiet", "shush", "secret", "whisper"],
        "🤭": ["giggle", "oops", "hand", "mouth"],
        "😏": ["smirk", "sly", "suggestive"],
        "😒": ["unamused", "meh", "annoyed"],
        "🙄": ["eyeroll", "whatever", "annoyed"],
        "😬": ["grimace", "awkward", "teeth"],
        "😷": ["mask", "sick", "medical", "covid"],
        "🤒": ["sick", "thermometer", "fever", "ill"],
        "🤕": ["hurt", "bandage", "injured"],
        "🤢": ["sick", "nauseous", "green"],
        "🤮": ["vomit", "sick", "throw up"],
        "🥵": ["hot", "sweating", "heat"],
        "🥶": ["cold", "freezing", "frozen"],
        "🤯": ["mindblown", "exploding", "shocked"],
        "🤠": ["cowboy", "hat", "yeehaw"],
        "🥸": ["disguise", "glasses", "mustache"],

        // Animals
        "🐶": ["dog", "puppy", "pet", "animal"],
        "🐱": ["cat", "kitten", "pet", "animal"],
        "🐭": ["mouse", "rodent", "animal"],
        "🐹": ["hamster", "pet", "rodent"],
        "🐰": ["rabbit", "bunny", "pet"],
        "🦊": ["fox", "animal", "orange"],
        "🐻": ["bear", "animal", "teddy"],
        "🐼": ["panda", "bear", "animal", "bamboo"],
        "🐨": ["koala", "animal", "australia"],
        "🐯": ["tiger", "animal", "cat"],
        "🦁": ["lion", "animal", "king", "cat"],
        "🐮": ["cow", "animal", "farm"],
        "🐷": ["pig", "animal", "farm"],
        "🐸": ["frog", "animal", "green"],
        "🐵": ["monkey", "animal", "ape"],
        "🐔": ["chicken", "bird", "farm"],
        "🐧": ["penguin", "bird", "animal"],
        "🐦": ["bird", "animal", "tweet"],
        "🦆": ["duck", "bird", "animal"],
        "🦅": ["eagle", "bird", "america"],
        "🦉": ["owl", "bird", "night", "wise"],
        "🦇": ["bat", "animal", "night", "vampire"],
        "🐺": ["wolf", "animal", "howl"],
        "🐴": ["horse", "animal", "ride"],
        "🦄": ["unicorn", "horse", "magic", "rainbow"],
        "🐝": ["bee", "insect", "honey", "buzz"],
        "🦋": ["butterfly", "insect", "pretty"],
        "🐌": ["snail", "slow", "shell"],
        "🐞": ["ladybug", "insect", "luck"],
        "🐢": ["turtle", "slow", "shell"],
        "🐍": ["snake", "reptile", "slither"],
        "🐙": ["octopus", "sea", "tentacles"],
        "🦑": ["squid", "sea", "tentacles"],
        "🦐": ["shrimp", "seafood", "prawn"],
        "🦀": ["crab", "seafood", "beach"],
        "🐠": ["fish", "tropical", "sea"],
        "🐟": ["fish", "sea", "animal"],
        "🐬": ["dolphin", "sea", "smart"],
        "🐳": ["whale", "sea", "spout"],
        "🐋": ["whale", "sea", "big"],
        "🦈": ["shark", "sea", "jaws"],
        "🐊": ["crocodile", "alligator", "reptile"],
        "🐘": ["elephant", "animal", "big", "trunk"],
        "🦛": ["hippo", "animal", "water"],
        "🦏": ["rhino", "animal", "horn"],
        "🐪": ["camel", "desert", "hump"],
        "🦒": ["giraffe", "tall", "africa"],

        // Nature
        "🌵": ["cactus", "desert", "plant"],
        "🎄": ["christmas", "tree", "holiday"],
        "🌲": ["tree", "evergreen", "pine"],
        "🌳": ["tree", "nature", "green"],
        "🌴": ["palm", "tree", "tropical", "beach"],
        "🌱": ["plant", "seedling", "grow", "sprout"],
        "🌿": ["herb", "plant", "green", "leaf"],
        "🍀": ["clover", "luck", "four", "irish"],
        "🍃": ["leaf", "wind", "nature", "green"],
        "🍂": ["leaf", "fall", "autumn"],
        "🍁": ["maple", "leaf", "fall", "canada"],
        "🍄": ["mushroom", "fungus", "toadstool"],
        "💐": ["flowers", "bouquet", "gift"],
        "🌷": ["tulip", "flower", "spring"],
        "🌹": ["rose", "flower", "love", "red"],
        "🌺": ["flower", "hibiscus", "tropical"],
        "🌸": ["cherry", "blossom", "flower", "sakura"],
        "🌼": ["flower", "daisy", "yellow"],
        "🌻": ["sunflower", "flower", "sun", "yellow"],
        "🌞": ["sun", "face", "sunny", "happy"],
        "🌝": ["moon", "face", "full"],
        "🌛": ["moon", "face", "crescent"],
        "🌙": ["moon", "crescent", "night"],
        "🌎": ["earth", "world", "globe", "americas"],
        "🌍": ["earth", "world", "globe", "africa", "europe"],
        "🌏": ["earth", "world", "globe", "asia"],
        "🪐": ["saturn", "planet", "ring", "space"],
        "💫": ["star", "dizzy", "sparkle"],
        "⭐": ["star", "favorite", "yellow"],
        "🌟": ["star", "glow", "sparkle", "shine"],
        "✨": ["sparkles", "magic", "shine", "clean"],
        "⚡": ["lightning", "bolt", "electric", "power"],
        "🔥": ["fire", "hot", "flame", "lit"],
        "🌪️": ["tornado", "storm", "wind"],
        "🌈": ["rainbow", "colors", "pride", "gay"],
        "☀️": ["sun", "sunny", "bright", "weather"],
        "☁️": ["cloud", "weather", "sky"],
        "🌧️": ["rain", "cloud", "weather"],
        "❄️": ["snowflake", "cold", "winter", "frozen"],
        "☃️": ["snowman", "winter", "cold", "snow"],
        "💧": ["water", "drop", "tear", "sweat"],
        "🌊": ["wave", "ocean", "sea", "water"],

        // Food
        "🍏": ["apple", "green", "fruit"],
        "🍎": ["apple", "red", "fruit"],
        "🍐": ["pear", "fruit", "green"],
        "🍊": ["orange", "fruit", "citrus"],
        "🍋": ["lemon", "citrus", "yellow", "sour"],
        "🍌": ["banana", "fruit", "yellow"],
        "🍉": ["watermelon", "fruit", "summer"],
        "🍇": ["grapes", "fruit", "wine", "purple"],
        "🍓": ["strawberry", "fruit", "red", "berry"],
        "🍒": ["cherries", "fruit", "red"],
        "🍑": ["peach", "fruit", "emoji"],
        "🥭": ["mango", "fruit", "tropical"],
        "🍍": ["pineapple", "fruit", "tropical"],
        "🥥": ["coconut", "tropical", "fruit"],
        "🥝": ["kiwi", "fruit", "green"],
        "🍅": ["tomato", "vegetable", "red"],
        "🥑": ["avocado", "guac", "green"],
        "🥦": ["broccoli", "vegetable", "green"],
        "🥒": ["cucumber", "vegetable", "green"],
        "🌶️": ["pepper", "chili", "hot", "spicy"],
        "🌽": ["corn", "vegetable", "maize"],
        "🥕": ["carrot", "vegetable", "orange"],
        "🥔": ["potato", "vegetable", "fry"],
        "🍞": ["bread", "loaf", "toast"],
        "🧀": ["cheese", "dairy", "yellow"],
        "🥚": ["egg", "breakfast", "food"],
        "🍳": ["egg", "frying", "breakfast", "cook"],
        "🥞": ["pancakes", "breakfast", "stack"],
        "🥓": ["bacon", "meat", "breakfast"],
        "🥩": ["steak", "meat", "beef"],
        "🍗": ["chicken", "leg", "drumstick", "meat"],
        "🍖": ["meat", "bone", "food"],
        "🌭": ["hotdog", "sausage", "food"],
        "🍔": ["burger", "hamburger", "food", "fast"],
        "🍟": ["fries", "french", "food", "fast"],
        "🍕": ["pizza", "food", "slice"],
        "🥪": ["sandwich", "food", "lunch"],
        "🌮": ["taco", "mexican", "food"],
        "🌯": ["burrito", "wrap", "mexican", "food"],
        "🥗": ["salad", "healthy", "vegetable"],
        "🍝": ["spaghetti", "pasta", "italian", "noodles"],
        "🍜": ["noodles", "ramen", "soup", "asian"],
        "🍲": ["stew", "pot", "food", "soup"],
        "🍣": ["sushi", "japanese", "fish", "food"],
        "🍱": ["bento", "box", "japanese", "food"],
        "🍦": ["ice cream", "dessert", "cone", "soft serve"],
        "🍨": ["ice cream", "sundae", "dessert"],
        "🍧": ["shaved ice", "dessert", "cold"],
        "🎂": ["cake", "birthday", "dessert"],
        "🍰": ["cake", "slice", "dessert", "shortcake"],
        "🧁": ["cupcake", "dessert", "sweet"],
        "🍭": ["lollipop", "candy", "sweet"],
        "🍬": ["candy", "sweet", "wrapped"],
        "🍫": ["chocolate", "bar", "sweet"],
        "🍿": ["popcorn", "movie", "snack"],
        "🍩": ["donut", "doughnut", "sweet"],
        "🍪": ["cookie", "sweet", "biscuit"],
        "☕": ["coffee", "drink", "hot", "cafe"],
        "🍵": ["tea", "drink", "hot", "green"],
        "🥤": ["cup", "drink", "soda", "straw"],
        "🍺": ["beer", "drink", "alcohol", "mug"],
        "🍻": ["cheers", "beer", "drink", "toast"],
        "🍷": ["wine", "drink", "alcohol", "glass"],
        "🍸": ["martini", "cocktail", "drink", "alcohol"],
        "🍹": ["tropical", "drink", "cocktail"],

        // Activity & Sports
        "⚽": ["soccer", "football", "ball", "sport"],
        "🏀": ["basketball", "ball", "sport", "nba"],
        "🏈": ["football", "american", "ball", "sport", "nfl"],
        "⚾": ["baseball", "ball", "sport", "mlb"],
        "🎾": ["tennis", "ball", "sport"],
        "🏐": ["volleyball", "ball", "sport"],
        "🏉": ["rugby", "ball", "sport"],
        "🎱": ["pool", "billiards", "8ball", "sport"],
        "🏓": ["ping pong", "table tennis", "paddle"],
        "🏸": ["badminton", "shuttlecock", "sport"],
        "🏒": ["hockey", "ice", "sport", "stick"],
        "🏏": ["cricket", "bat", "sport"],
        "⛳": ["golf", "hole", "sport", "flag"],
        "🏹": ["archery", "bow", "arrow"],
        "🎣": ["fishing", "rod", "fish"],
        "🥊": ["boxing", "gloves", "fight", "sport"],
        "🥋": ["martial arts", "karate", "judo"],
        "🎽": ["running", "shirt", "sport"],
        "🛹": ["skateboard", "skate", "sport"],
        "⛸️": ["ice skating", "skate", "sport"],
        "🎿": ["skiing", "ski", "snow", "winter"],
        "🏂": ["snowboard", "snow", "winter", "sport"],
        "🏋️": ["weightlifting", "gym", "workout", "exercise"],
        "🧘": ["yoga", "meditation", "zen", "relax"],
        "🏄": ["surfing", "surf", "wave", "beach"],
        "🏊": ["swimming", "swim", "pool", "water"],
        "🚴": ["cycling", "bike", "bicycle", "sport"],
        "🏆": ["trophy", "winner", "champion", "award"],
        "🥇": ["gold", "medal", "first", "winner"],
        "🥈": ["silver", "medal", "second"],
        "🥉": ["bronze", "medal", "third"],
        "🏅": ["medal", "award", "sports"],
        "🎭": ["theater", "drama", "masks", "performing"],
        "🎨": ["art", "palette", "paint", "artist"],
        "🎬": ["movie", "film", "clapper", "cinema"],
        "🎤": ["microphone", "karaoke", "sing", "music"],
        "🎧": ["headphones", "music", "audio", "listen"],
        "🎼": ["music", "notes", "score", "sheet"],
        "🎹": ["piano", "keyboard", "music", "keys"],
        "🥁": ["drum", "music", "beat", "percussion"],
        "🎷": ["saxophone", "jazz", "music"],
        "🎺": ["trumpet", "brass", "music", "horn"],
        "🎸": ["guitar", "music", "rock", "electric"],
        "🎻": ["violin", "music", "strings", "classical"],
        "🎲": ["dice", "game", "random", "chance"],
        "🎯": ["target", "dart", "bullseye", "aim"],
        "🎳": ["bowling", "pins", "sport"],
        "🎮": ["game", "controller", "video", "gaming"],
        "🎰": ["slot", "machine", "casino", "gambling"],
        "🧩": ["puzzle", "piece", "game", "jigsaw"],

        // Travel & Places
        "🚗": ["car", "vehicle", "drive", "auto"],
        "🚕": ["taxi", "cab", "car", "yellow"],
        "🚙": ["suv", "car", "vehicle"],
        "🚌": ["bus", "vehicle", "public", "transit"],
        "🏎️": ["racing", "car", "fast", "formula"],
        "🚓": ["police", "car", "cop", "vehicle"],
        "🚑": ["ambulance", "emergency", "medical"],
        "🚒": ["fire", "truck", "emergency"],
        "🚐": ["van", "minibus", "vehicle"],
        "🛻": ["pickup", "truck", "vehicle"],
        "🚚": ["truck", "delivery", "moving"],
        "🚜": ["tractor", "farm", "vehicle"],
        "🛴": ["scooter", "kick", "ride"],
        "🚲": ["bicycle", "bike", "cycle", "ride"],
        "🛵": ["scooter", "motor", "moped"],
        "🏍️": ["motorcycle", "bike", "motor"],
        "🚃": ["train", "rail", "metro"],
        "🚄": ["train", "bullet", "fast", "shinkansen"],
        "🚅": ["train", "bullet", "fast"],
        "🚂": ["train", "locomotive", "steam"],
        "🚇": ["metro", "subway", "underground"],
        "✈️": ["airplane", "plane", "flight", "travel"],
        "🛫": ["takeoff", "airplane", "departure"],
        "🛬": ["landing", "airplane", "arrival"],
        "🚀": ["rocket", "space", "launch", "fast"],
        "🛸": ["ufo", "alien", "spaceship", "flying saucer"],
        "🚁": ["helicopter", "chopper", "fly"],
        "🛶": ["canoe", "boat", "paddle", "kayak"],
        "⛵": ["sailboat", "boat", "sailing", "yacht"],
        "🚤": ["speedboat", "boat", "fast"],
        "🛳️": ["cruise", "ship", "boat", "passenger"],
        "🚢": ["ship", "boat", "cargo"],
        "⚓": ["anchor", "boat", "ship", "nautical"],
        "🚧": ["construction", "roadwork", "barrier"],
        "🚦": ["traffic", "light", "signal"],
        "🗺️": ["map", "world", "travel"],
        "🗽": ["statue", "liberty", "new york", "usa"],
        "🗼": ["tower", "tokyo", "eiffel"],
        "🏰": ["castle", "disney", "medieval"],
        "🏯": ["castle", "japanese", "japan"],
        "🎡": ["ferris", "wheel", "amusement", "carnival"],
        "🎢": ["roller", "coaster", "amusement", "thrill"],
        "🎠": ["carousel", "horse", "amusement"],
        "⛲": ["fountain", "water", "park"],
        "🏖️": ["beach", "umbrella", "vacation", "sand"],
        "🏝️": ["island", "tropical", "vacation", "desert"],
        "🏜️": ["desert", "sand", "hot"],
        "🌋": ["volcano", "eruption", "lava"],
        "⛰️": ["mountain", "hill", "peak"],
        "🏔️": ["mountain", "snow", "peak"],
        "🗻": ["mount fuji", "mountain", "japan"],
        "🏕️": ["camping", "tent", "outdoor"],
        "⛺": ["tent", "camping", "outdoor"],
        "🏠": ["house", "home", "building"],
        "🏡": ["house", "home", "garden"],
        "🏗️": ["construction", "building", "crane"],
        "🏭": ["factory", "industrial", "building"],
        "🏢": ["office", "building", "work"],
        "🏬": ["department", "store", "shopping"],
        "🏥": ["hospital", "medical", "health"],
        "🏦": ["bank", "money", "building"],
        "🏨": ["hotel", "lodging", "travel"],
        "🏪": ["store", "convenience", "shop"],
        "🏫": ["school", "education", "building"],
        "⛪": ["church", "religion", "christian"],
        "🕌": ["mosque", "religion", "islam", "muslim"],
        "🕍": ["synagogue", "religion", "jewish"],
        "🌅": ["sunrise", "morning", "sun"],
        "🌄": ["sunrise", "mountain", "morning"],
        "🌠": ["shooting star", "night", "wish"],
        "🎇": ["sparkler", "fireworks", "celebration"],
        "🎆": ["fireworks", "celebration", "night"],
        "🌇": ["sunset", "city", "evening"],
        "🌆": ["cityscape", "dusk", "evening"],
        "🏙️": ["city", "skyline", "urban"],
        "🌃": ["night", "city", "stars"],
        "🌌": ["milky way", "galaxy", "space", "stars"],
        "🌉": ["bridge", "night", "city"],

        // Objects & Tech
        "⌚": ["watch", "time", "apple"],
        "📱": ["phone", "iphone", "mobile", "cell"],
        "💻": ["laptop", "computer", "macbook", "work"],
        "⌨️": ["keyboard", "type", "computer"],
        "🖥️": ["desktop", "computer", "monitor", "imac"],
        "🖨️": ["printer", "print", "office"],
        "🖱️": ["mouse", "computer", "click"],
        "💽": ["disk", "computer", "storage", "minidisc"],
        "💾": ["floppy", "save", "disk", "storage"],
        "💿": ["cd", "disk", "dvd", "music"],
        "📀": ["dvd", "disk", "movie"],
        "📷": ["camera", "photo", "picture"],
        "📸": ["camera", "flash", "photo"],
        "📹": ["video", "camera", "camcorder"],
        "🎥": ["movie", "camera", "film"],
        "📞": ["phone", "telephone", "call"],
        "📺": ["tv", "television", "screen"],
        "📻": ["radio", "music", "broadcast"],
        "🎙️": ["microphone", "podcast", "recording"],
        "⏰": ["alarm", "clock", "time", "wake"],
        "⌛": ["hourglass", "time", "wait", "sand"],
        "⏳": ["hourglass", "time", "flowing", "wait"],
        "📡": ["satellite", "antenna", "signal"],
        "🔋": ["battery", "power", "charge"],
        "🔌": ["plug", "electric", "power"],
        "💡": ["lightbulb", "idea", "light", "bright"],
        "🔦": ["flashlight", "light", "torch"],
        "🕯️": ["candle", "light", "flame"],
        "💸": ["money", "fly", "cash", "spend"],
        "💵": ["dollar", "money", "cash", "bills"],
        "💳": ["credit", "card", "payment", "bank"],
        "💎": ["diamond", "gem", "jewel", "precious"],
        "🧰": ["toolbox", "tools", "fix", "repair"],
        "🔧": ["wrench", "tool", "fix", "repair"],
        "🔨": ["hammer", "tool", "build", "construction"],
        "🔩": ["nut", "bolt", "screw", "hardware"],
        "⚙️": ["gear", "settings", "cog", "mechanical"],
        "🔪": ["knife", "kitchen", "cut", "cook"],
        "🔮": ["crystal", "ball", "fortune", "magic"],
        "💊": ["pill", "medicine", "drug", "health"],
        "💉": ["syringe", "needle", "vaccine", "medical"],
        "🧬": ["dna", "genetics", "science"],
        "🦠": ["microbe", "virus", "bacteria", "germ"],
        "🧪": ["test", "tube", "science", "lab"],
        "🔬": ["microscope", "science", "lab", "research"],
        "🔭": ["telescope", "space", "astronomy", "stars"],
        "🧹": ["broom", "clean", "sweep"],
        "🧻": ["toilet", "paper", "tissue"],
        "🚽": ["toilet", "bathroom", "wc"],
        "🚿": ["shower", "bathroom", "water", "wash"],
        "🛁": ["bathtub", "bath", "relax"],
        "🛎️": ["bell", "service", "hotel"],
        "🔑": ["key", "lock", "unlock", "password"],
        "🚪": ["door", "enter", "exit", "room"],
        "🪑": ["chair", "seat", "furniture"],
        "🛋️": ["couch", "sofa", "furniture"],
        "🛏️": ["bed", "sleep", "furniture", "bedroom"],
        "🧸": ["teddy", "bear", "toy", "plush"],
        "🛍️": ["shopping", "bags", "buy"],
        "🛒": ["cart", "shopping", "grocery"],
        "🎁": ["gift", "present", "wrapped", "birthday"],
        "🎈": ["balloon", "party", "birthday", "celebration"],
        "🎉": ["party", "celebration", "confetti", "tada"],
        "🎊": ["confetti", "ball", "celebration", "party"],
        "✉️": ["envelope", "email", "mail", "letter"],
        "📧": ["email", "mail", "message", "at"],
        "📦": ["package", "box", "delivery", "shipping"],
        "📋": ["clipboard", "paste", "list"],
        "📁": ["folder", "file", "directory"],
        "📂": ["folder", "open", "file"],
        "📰": ["newspaper", "news", "press", "media"],
        "📓": ["notebook", "journal", "diary"],
        "📕": ["book", "read", "closed", "red"],
        "📗": ["book", "read", "green"],
        "📘": ["book", "read", "blue"],
        "📙": ["book", "read", "orange"],
        "📚": ["books", "library", "read", "study"],
        "📖": ["book", "open", "read"],
        "🔗": ["link", "chain", "url", "connect"],
        "📎": ["paperclip", "clip", "attach"],
        "✂️": ["scissors", "cut", "tool"],
        "📌": ["pin", "pushpin", "location"],
        "📍": ["pin", "location", "map"],
        "🖊️": ["pen", "write", "ballpoint"],
        "✏️": ["pencil", "write", "draw"],
        "🔍": ["magnifying", "glass", "search", "zoom"],
        "🔎": ["magnifying", "glass", "search", "zoom"],
        "🔒": ["lock", "secure", "closed", "private"],
        "🔓": ["unlock", "open", "lock"],

        // Symbols
        "❤️": ["heart", "love", "red"],
        "🧡": ["heart", "love", "orange"],
        "💛": ["heart", "love", "yellow"],
        "💚": ["heart", "love", "green"],
        "💙": ["heart", "love", "blue"],
        "💜": ["heart", "love", "purple"],
        "🖤": ["heart", "love", "black"],
        "🤍": ["heart", "love", "white"],
        "🤎": ["heart", "love", "brown"],
        "💔": ["heart", "broken", "love", "sad"],
        "❤️‍🔥": ["heart", "fire", "love", "passion"],
        "💕": ["hearts", "love", "two"],
        "💗": ["heart", "growing", "love"],
        "💖": ["heart", "sparkle", "love"],
        "💘": ["heart", "arrow", "cupid", "love"],
        "💝": ["heart", "ribbon", "gift", "love"],
        "💯": ["hundred", "score", "perfect"],
        "💢": ["anger", "angry", "symbol"],
        "❗": ["exclamation", "important", "alert"],
        "❓": ["question", "mark", "ask"],
        "⚠️": ["warning", "caution", "alert"],
        "✅": ["check", "done", "yes", "correct"],
        "❌": ["cross", "no", "wrong", "cancel"],
        "⭕": ["circle", "hollow", "ring"],
        "🚫": ["prohibited", "no", "forbidden", "ban"],
        "♻️": ["recycle", "environment", "green"],
        "💤": ["sleep", "zzz", "tired", "snoring"],
        "🔴": ["red", "circle", "dot"],
        "🟠": ["orange", "circle", "dot"],
        "🟡": ["yellow", "circle", "dot"],
        "🟢": ["green", "circle", "dot"],
        "🔵": ["blue", "circle", "dot"],
        "🟣": ["purple", "circle", "dot"],
        "⚫": ["black", "circle", "dot"],
        "⚪": ["white", "circle", "dot"],
        "🔔": ["bell", "notification", "alert", "ring"],
        "🔕": ["bell", "mute", "silent", "quiet"],
        "🔊": ["speaker", "loud", "volume", "sound"],
        "🔇": ["speaker", "mute", "silent", "quiet"],
        "💬": ["speech", "bubble", "comment", "chat"],
        "💭": ["thought", "bubble", "think"],
        "🗯️": ["speech", "angry", "shout"],
        "♠️": ["spade", "cards", "poker"],
        "♣️": ["club", "cards", "poker"],
        "♥️": ["heart", "cards", "poker"],
        "♦️": ["diamond", "cards", "poker"],
        "🃏": ["joker", "cards", "wild"],
        "🎵": ["music", "note", "sound"],
        "🎶": ["music", "notes", "sound", "melody"],
        "➕": ["plus", "add", "new"],
        "➖": ["minus", "subtract", "remove"],
        "✖️": ["multiply", "times", "x"],
        "➗": ["divide", "division"],
        "♾️": ["infinity", "forever", "unlimited"],
        "💲": ["dollar", "money", "price"],
        "™️": ["trademark", "tm", "brand"],
        "©️": ["copyright", "c", "rights"],
        "®️": ["registered", "r", "trademark"],
        "✔️": ["check", "done", "yes", "correct"]
    ]
}

// MARK: - Preview

#Preview {
    ScrollView {
        EmojiPickerGrid(
            selectedEmoji: .constant("⭐"),
            searchText: .constant(""),
            onSelect: { _ in }
        )
        .padding()
    }
    .frame(width: 400, height: 500)
    .background(Color(NSColor.windowBackgroundColor))
}
