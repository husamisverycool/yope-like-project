// Surface: chat.reactions — composition of Retro components C-06 (chip), C-29 (context menu palette, sheets), C-12
// (search), C-20 (section labels), C-16 (people rows), C-11 (highlight circle) in WhatsApp / Apple Messages' order, with
// Locket's quick emoji. Spec: design/surfaces/chat.reactions.md.
// References: references/auto/whatsapp/store/whatsapp-store-04.png (summary under a message),
// references/auto/imessage/apple-support/messages-tapbacks-ios27.png (row above the long-pressed message),
// references/auto/locket/store/locket-store-08.png (quick emoji), references/auto/retro/apk/retro-android-2026.10.1150-strings.txt
// ("Reactions", "Search", "All", "Nothing to see here yet").
// Tenet: no number anywhere — not on the chip, not in the sheet, not in accessibility labels.
import AppData
import AppModels
import DesignSystem
import SwiftUI

// MARK: - Chip (`chat.reactions.layout.chip`)

/// The distinct emoji used on a photo — at most `chat.reactions.count.clusterMaxVisible`, newest first — in a C-06 fill
/// capsule: emoji at `fontSize.global.pill`, padding 12 horizontal / 8 vertical (read from
/// `chat.reactions.layout.chip.padding`), height hugging the line, `radius.global.capsule`; fill `color.global.control`
/// on a page, `color.global.controlOnDeep` on media. No number, no avatars. Hidden (zero size) when nobody reacted.
/// Tap → the Reactions sheet. Accessibility: one button, "Reactions: fire, sparkling heart".
struct ReactionChip: View {
    let emoji: [String]
    var onMedia = false
    let action: () -> Void

    private static let padding = SocialTokenNumbers.all(in: Tokens.Layouts.ChatReactionsLayoutChip.padding)

    private var shown: [String] { Array(emoji.prefix(Int(Tokens.Counts.chatReactionsCountClusterMaxVisible))) }

    var body: some View {
        if !emoji.isEmpty {
            Button(action: action) {
                Text(shown.joined())
                    .dsTextStyle(SocialTextRole.chipEmoji)
                    .lineLimit(1)
                    .fixedSize()
                    .padding(.horizontal, Self.padding.first ?? 0)
                    .padding(.vertical, Self.padding.dropFirst().first ?? 0)
                    .background(onMedia ? Tokens.Colors.globalControlOnDeep : Tokens.Colors.globalControl, in: Capsule())
                    .contentShape(Capsule())
                    .dsAnimation(ComponentMotion.crossfade, value: shown)
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(SocialEmoji.clusterLabel(shown)))
            .accessibilityAddTraits(.isButton)
        }
    }
}

// MARK: - Quick reactions (`chat.reactions.layout.quickReactions`)

/// The first row of a photo's native context menu (C-29): a palette of 🔥, 💖 and the add-reaction glyph. An emoji I
/// already used shows selected and takes it back; the glyph opens the picker. iOS 17 palette `ControlGroup`.
struct QuickReactionsPalette: View {
    let mine: Set<String>
    let onEmoji: (String) -> Void
    let onAdd: () -> Void

    var body: some View {
        ControlGroup {
            ForEach(SocialEmoji.quick, id: \.self) { emoji in
                Toggle(isOn: Binding(get: { mine.contains(emoji) }, set: { _ in onEmoji(emoji) })) {
                    Text(emoji)
                }
                .accessibilityLabel(Text(Copy.chatReactionsA11yQuick(emojiName: SocialEmoji.name(emoji))))
            }
            Button(action: onAdd) {
                Image(systemName: Tokens.Icons.chatReactionsIconAdd)
            }
            .accessibilityLabel(Text(Copy.chatReactionsA11yAdd))
        }
        .controlGroupStyle(.palette)
    }
}

// MARK: - Picker (`chat.reactions.layout.picker`)

/// Identifies the post a picker sheet reacts to.
struct ReactionPickerTarget: Identifiable, Hashable {
    let postID: PostID
    var id: String { postID.rawValue }
}

/// Native sheet with a grabber on `color.global.background`: the C-12 search field inside `size.global.screenMargin`
/// (filters by the emoji's system name), "Frequently Used" (this device's recent emoji) and "All" (every emoji in
/// Unicode order) as C-20 labels without "•••" (`size.global.sectionGap` above a label, `size.global.sectionHeaderToContent`
/// below its baseline); `chat.reactions.count.pickerColumns` equal columns, emoji at `fontSize.global.headerTitle`. Emoji
/// already used on this photo sit on a `size.global.circleButton` circle in `color.global.control` (selected trait): a
/// tap takes it back; any other tap reacts and closes the sheet.
struct ReactionPicker: View {
    var mine: Set<String> = []
    let onPick: (String) -> Void
    var onRemove: (String) -> Void = { _ in }

    @Environment(\.dismiss) private var dismiss
    @State private var search = ""
    @State private var recent: [String] = []

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 0), count: Int(Tokens.Counts.chatReactionsCountPickerColumns))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                SearchField(Copy.chatReactionsPickerSearch, text: $search, accessibilityLabel: Copy.chatReactionsPickerSearch)
                    .padding(.horizontal, Tokens.Sizes.globalScreenMargin)
                    .padding(.top, Tokens.Sizes.globalScreenMargin)
                WeekSectionList {
                    if search.isEmpty {
                        if !recent.isEmpty { section(Copy.chatReactionsPickerFrequent, recent) }
                        section(Copy.chatReactionsPickerAll, ReactionPicker.allEmoji)
                    } else {
                        grid(ReactionPicker.allEmoji.filter { SocialEmoji.name($0).localizedStandardContains(search) })
                    }
                }
                .padding(.top, Tokens.Sizes.globalSectionGap - SocialMetrics.capTopOffset(TextRole.sectionLabel))
            }
            .padding(.bottom, Tokens.Sizes.globalScreenMargin)
        }
        .background(Tokens.Colors.globalBackground)
        .presentationDragIndicator(.visible)
        .dsSheetBackground()
        .onAppear {
            recent = Array(SocialServices.shared.flags.recentEmoji().prefix(Int(Tokens.Counts.chatReactionsCountPickerColumns)))
        }
    }

    private func section(_ title: String, _ emoji: [String]) -> some View {
        WeekStripSection {
            SectionHeader(title: title)
        } content: {
            grid(emoji)
        }
    }

    private func grid(_ emoji: [String]) -> some View {
        LazyVGrid(columns: columns, spacing: 0) {
            ForEach(emoji, id: \.self) { cell($0) }
        }
        .padding(.horizontal, Tokens.Sizes.globalScreenMargin)
    }

    private func cell(_ emoji: String) -> some View {
        let isMine = mine.contains(emoji)
        return Button {
            if isMine {
                onRemove(emoji)
            } else {
                SocialServices.shared.flags.recordEmoji(emoji, keep: Int(Tokens.Counts.chatReactionsCountPickerColumns))
                onPick(emoji)
                dismiss()
            }
        } label: {
            Text(emoji)
                .dsTextStyle(SocialTextRole.pickerEmoji)
                .fixedSize()
                .frame(minWidth: Tokens.Sizes.globalMinTouchTargetIos, minHeight: Tokens.Sizes.globalMinTouchTargetIos)
                .frame(maxWidth: .infinity)
                .background {
                    if isMine {
                        Circle()
                            .fill(Tokens.Colors.globalControl)
                            .frame(width: Tokens.Sizes.globalCircleButton, height: Tokens.Sizes.globalCircleButton)
                    }
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(SocialEmoji.name(emoji)))
        .accessibilityAddTraits(isMine ? .isSelected : [])
    }

    /// Single-scalar emoji with emoji presentation, in code point order.
    static let allEmoji: [String] = {
        let ranges: [ClosedRange<UInt32>] = [0x2600...0x27BF, 0x1F300...0x1F5FF, 0x1F600...0x1F64F, 0x1F680...0x1F6FF, 0x1F900...0x1F9FF, 0x1FA70...0x1FAFF] // provenance-ok: Unicode emoji blocks
        return ranges.flatMap { range in
            range.compactMap { value -> String? in
                guard let scalar = Unicode.Scalar(value), scalar.properties.isEmojiPresentation else { return nil }
                return String(scalar)
            }
        }
    }()
}

// MARK: - Reactions sheet (`chat.reactions.layout.list`)

/// Identifies the post whose Reactions sheet is open.
struct ReactionsSheetTarget: Identifiable, Hashable {
    let postID: PostID
    var id: String { postID.rawValue }
}

/// Native sheet titled "Reactions" (C-29 header, text role `sheetTitle`), a plain list on `color.global.background`: one
/// C-16 row per person and emoji — avatar `size.global.avatarPicker` at the margin, the name (text role `listTitle`)
/// `chat.thread.dimension.rowAvatarToText` after it, the emoji at the trailing margin in the `size.global.icon` box;
/// your rows add "Tap to remove" (`listSubtitle`, `color.global.textSecondary`) and a tap takes the reaction back. Rows
/// `size.global.listGap` apart; order `chat.reactions.layout.listOrder` (newest first, `ReactionSummary.listRows`). Empty (all taken
/// back while open): C-27 title only. Never a count. In photo.viewer the selfie reactions (viewer.selfiereaction §4) sit
/// among the emoji rows by time (`SelfieReactionRow`).
struct ReactionsSheet: View {
    let reactions: ReactionSummary
    /// viewer.selfiereaction: the photo's selfies (photo.viewer only).
    var selfies = SelfieSummary()
    let me: UserID?
    let profile: (UserID) -> Profile?
    let onRemove: (String) -> Void
    /// The selfie rows' faces and actions (photo.viewer only).
    var selfieActions: SelfieRowActions?

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(title: Copy.chatReactionsActivityTitle)
                .padding(.top, Tokens.Sizes.globalScreenMargin)
            if reactions.isEmpty && selfies.isEmpty {
                Spacer(minLength: 0)
                EmptyStateView(title: Copy.chatReactionsEmpty)
                Spacer(minLength: 0)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: Tokens.Sizes.globalListGap) {
                        ForEach(Array(ReactionsSheetEntry.merged(emoji: reactions.listRows(), selfies: selfies.rows).enumerated()), id: \.offset) { _, entry in
                            switch entry {
                            case let .emoji(row): rowView(row)
                            case let .selfie(selfie): selfieRow(selfie)
                            }
                        }
                    }
                    .padding(.vertical, Tokens.Sizes.globalTitleToContent)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Tokens.Colors.globalBackground)
        .presentationDragIndicator(.visible)
        .dsSheetBackground()
    }

    @ViewBuilder
    private func rowView(_ row: Reaction) -> some View {
        let isMine = row.userID == me
        let person = profile(row.userID)
        let content = SocialPersonRow(
            name: person?.displayName ?? "",
            line: isMine ? Copy.chatReactionsListRemoveHint : nil,
            avatar: SocialImages.source(person?.avatarPath)
        ) {
            Text(row.emoji)
                .dsTextStyle(SocialTextRole.chipEmoji)
                .fixedSize()
                .frame(minWidth: Tokens.Sizes.globalIcon, minHeight: Tokens.Sizes.globalIcon)
        }
        let label = isMine
            ? Copy.chatReactionsActivityRowMine(emoji: SocialEmoji.name(row.emoji))
            : Copy.chatReactionsActivityRow(name: person?.socialFirstName ?? "", emoji: SocialEmoji.name(row.emoji))
        if isMine {
            Button { onRemove(row.emoji) } label: { content.contentShape(Rectangle()) }
                .buttonStyle(.plain)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(label))
                .accessibilityHint(Text(Copy.chatReactionsListRemoveHint))
                .accessibilityAddTraits(.isButton)
        } else {
            content
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(label))
        }
    }

    /// A selfie row: mine is a button that takes it back (`chat.reactions.layout.unreact`); a long press on anyone else's
    /// opens the C-29 menu — "Remove" on my own photo (destructive, → the confirmation) and "Report Selfie"
    /// (destructive, → `safety.report`); the same items are accessibility actions.
    @ViewBuilder
    private func selfieRow(_ selfie: SelfieReaction) -> some View {
        let isMine = selfie.userID == me
        let person = profile(selfie.userID)
        let firstName = person?.socialFirstName ?? ""
        let content = SelfieReactionRow(
            name: person?.displayName ?? "",
            line: isMine ? Copy.viewerSelfiereactionActivityRowMine : Copy.viewerSelfiereactionActivityRow(name: firstName),
            removeHint: isMine ? Copy.chatReactionsListRemoveHint : nil,
            face: selfieActions?.face(selfie)
        )
        let label = isMine ? Copy.viewerSelfiereactionA11yFaceMine : Copy.viewerSelfiereactionA11yFace(name: firstName)
        if isMine {
            Button { selfieActions?.removeMine(selfie) } label: { content.contentShape(Rectangle()) }
                .buttonStyle(.plain)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(label))
                .accessibilityValue(Text(Copy.viewerSelfiereactionActivityRowMine))
                .accessibilityHint(Text(Copy.chatReactionsListRemoveHint))
                .accessibilityAddTraits(.isButton)
                .accessibilityIdentifier("chat.reactions.selfie.mine") // provenance-ok: accessibility identifier for UI tests
        } else {
            content
                .contentShape(Rectangle())
                .contextMenu { selfieMenu(selfie) }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(label))
                .accessibilityValue(Text(Copy.viewerSelfiereactionActivityRow(name: firstName)))
                .accessibilityActions { selfieMenu(selfie) }
                .accessibilityIdentifier("chat.reactions.selfie.\(selfie.userID.rawValue)") // provenance-ok: accessibility identifier for UI tests
        }
    }

    @ViewBuilder
    private func selfieMenu(_ selfie: SelfieReaction) -> some View {
        if let actions = selfieActions {
            if actions.isAuthor {
                Button(role: .destructive) { actions.remove(selfie) } label: {
                    Label(Copy.viewerSelfiereactionMenuRemove, systemImage: Tokens.Icons.globalTrash)
                }
            }
            if let report = actions.report {
                Button(role: .destructive) { report(selfie) } label: {
                    Label(Copy.viewerSelfiereactionMenuReport, systemImage: Tokens.Icons.globalReport)
                }
            }
        }
    }
}

/// A C-16 people row with the spacing the social specs measured: avatar `size.global.avatarPicker` at the margin, the
/// name (`listTitle`, `color.global.textPrimary`) over an optional line (`listSubtitle`, `color.global.textSecondary`)
/// `chat.thread.dimension.rowAvatarToText` after it, then the trailing content at the margin. (The shared `PeopleRow`
/// spaces avatar and text with the platform's spacing — reported as a component gap.)
struct SocialPersonRow<Trailing: View>: View {
    let name: String
    var line: String?
    var avatar: PhotoSource?
    @ViewBuilder let trailing: () -> Trailing

    var body: some View {
        HStack(spacing: Tokens.Sizes.chatThreadDimensionRowAvatarToText) {
            AvatarView(source: avatar, diameter: Tokens.Sizes.globalAvatarPicker)
            VStack(alignment: .leading, spacing: 0) {
                Text(name)
                    .dsTextStyle(TextRole.listTitle)
                    .foregroundStyle(Tokens.Colors.globalTextPrimary)
                    .lineLimit(1)
                if let line {
                    Text(line)
                        .dsTextStyle(TextRole.listSubtitle)
                        .foregroundStyle(Tokens.Colors.globalTextSecondary)
                }
            }
            Spacer(minLength: 0)
            trailing()
        }
        .padding(.horizontal, Tokens.Sizes.globalScreenMargin)
    }
}
