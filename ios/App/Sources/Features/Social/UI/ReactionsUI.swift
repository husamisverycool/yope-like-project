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
/// already used shows selected and takes it back; the glyph opens the picker. iOS 17 palette `ControlGroup`. A tap
/// closes the menu, as the row's references (Messages' Tapbacks, WhatsApp) and Android's `PhotoContextMenu` do: a
/// `Toggle` in a menu keeps it open by default (`.automatic`), which left the menu over the viewer after a reaction
/// (run 105's "ios e2e").
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
                .menuActionDismissBehavior(.enabled)
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
/// (filters by the emoji's Unicode name), "Frequently Used" (this device's recent emoji), then every emoji of Unicode's
/// RGI set in its standard groups ("Smileys & Emotion" … "Flags", `chat.reactions.picker.group.*`) as C-20 labels
/// without "•••" (`size.global.sectionGap` above a label, `size.global.sectionHeaderToContent` below its baseline);
/// `chat.reactions.count.pickerColumns` equal columns, emoji at `fontSize.global.headerTitle`. An emoji with skin tones
/// offers them on touch and hold (the system emoji keyboard, support.apple.com/102507) in a platform popover. Emoji
/// already used on this photo sit on a `size.global.circleButton` circle in `color.global.control` (selected trait): a
/// tap takes it back; any other tap reacts and closes the sheet. Only emoji this device's emoji font draws are shown.
struct ReactionPicker: View {
    var mine: Set<String> = []
    /// The catalog to show (snapshots pass the bundled one); nil: the device-filtered catalog, read on appear.
    var catalog: EmojiCatalog?
    let onPick: (String) -> Void
    var onRemove: (String) -> Void = { _ in }

    @Environment(\.dismiss) private var dismiss
    @State private var search = ""
    @State private var recent: [String] = []
    @State private var loaded: EmojiCatalog?
    /// The cell (section + emoji) whose skin tones are open (touch and hold).
    @State private var variantsOf: String?
    /// The tap that ends a touch and hold is not a pick.
    @State private var holdEnded: String?

    private var shown: EmojiCatalog { catalog ?? loaded ?? EmojiCatalog(groups: []) }

    /// Unicode's standard groups in the catalog's order (tools/emoji-catalog.mjs).
    private static let groupTitles = [
        Copy.chatReactionsPickerGroupSmileysEmotion, Copy.chatReactionsPickerGroupPeopleBody,
        Copy.chatReactionsPickerGroupAnimalsNature, Copy.chatReactionsPickerGroupFoodDrink,
        Copy.chatReactionsPickerGroupTravelPlaces, Copy.chatReactionsPickerGroupActivities,
        Copy.chatReactionsPickerGroupObjects, Copy.chatReactionsPickerGroupSymbols, Copy.chatReactionsPickerGroupFlags,
    ]

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
                        if !recent.isEmpty {
                            section(Copy.chatReactionsPickerFrequent, key: "recent", recent.map { emoji in // provenance-ok: view identity, not shown
                                PickerCell(emoji: emoji, entry: shown.entry(containing: emoji))
                            })
                        }
                        ForEach(Array(zip(Self.groupTitles, shown.groups).enumerated()), id: \.offset) { index, pair in
                            if !pair.1.entries.isEmpty {
                                section(pair.0, key: String(index), pair.1.entries.map { PickerCell(emoji: $0.base.emoji, entry: $0) })
                            }
                        }
                    } else {
                        grid(key: "search", shown.search(search).map { PickerCell(emoji: $0.base.emoji, entry: $0) }) // provenance-ok: view identity, not shown
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
        .task {
            if catalog == nil, loaded == nil { loaded = await SocialEmojiCatalog.shown() }
        }
    }

    /// One grid cell: the emoji shown and its catalog entry (its skin tones), when it has one.
    private struct PickerCell: Identifiable {
        let emoji: String
        let entry: EmojiCatalog.Entry?
        var id: String { emoji }
    }

    private func section(_ title: String, key: String, _ cells: [PickerCell]) -> some View {
        WeekStripSection {
            SectionHeader(title: title)
        } content: {
            grid(key: key, cells)
        }
    }

    private func grid(key: String, _ cells: [PickerCell]) -> some View {
        LazyVGrid(columns: columns, spacing: 0) {
            ForEach(cells) { item in cell(item.emoji, entry: item.entry, key: key + " " + item.emoji) } // provenance-ok: view identity, not shown
        }
        .padding(.horizontal, Tokens.Sizes.globalScreenMargin)
    }

    /// One emoji. With skin tones (`entry` has variants): touch and hold opens them; VoiceOver lists them as actions.
    private func cell(_ emoji: String, entry: EmojiCatalog.Entry?, key: String) -> some View {
        let choices: [EmojiCatalog.Emoji] = (entry?.variants.isEmpty ?? true) ? [] : (entry?.choices ?? [])
        return Button {
            if holdEnded == key {
                holdEnded = nil
                return
            }
            choose(emoji)
        } label: {
            emojiFace(emoji)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(LongPressGesture().onEnded { _ in
            guard !choices.isEmpty else { return }
            holdEnded = key
            variantsOf = key
        })
        .popover(isPresented: Binding(get: { variantsOf == key }, set: { if !$0 { variantsOf = nil; holdEnded = nil } })) {
            variantGrid(choices)
                .presentationCompactAdaptation(.popover)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(SocialEmoji.name(emoji)))
        .accessibilityAddTraits(mine.contains(emoji) ? [.isButton, .isSelected] : .isButton)
        .accessibilityAction { choose(emoji) }
        .accessibilityActions {
            ForEach(choices.filter { $0.emoji != emoji }, id: \.emoji) { choice in
                Button(choice.name) { choose(choice.emoji) }
            }
        }
    }

    /// The base and its skin tones, `chat.reactions.count.pickerColumns` to a row at most (Unicode's order).
    private func variantGrid(_ choices: [EmojiCatalog.Emoji]) -> some View {
        let count = min(choices.count, Int(Tokens.Counts.chatReactionsCountPickerColumns))
        return LazyVGrid(columns: Array(repeating: GridItem(.fixed(Tokens.Sizes.globalMinTouchTargetIos), spacing: 0), count: max(count, 1)), spacing: 0) {
            ForEach(choices, id: \.emoji) { choice in
                Button {
                    variantsOf = nil
                    holdEnded = nil
                    choose(choice.emoji)
                } label: {
                    emojiFace(choice.emoji)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(choice.name))
                .accessibilityAddTraits(mine.contains(choice.emoji) ? .isSelected : [])
            }
        }
        .padding(Tokens.Sizes.globalScreenMargin)
    }

    private func emojiFace(_ emoji: String) -> some View {
        Text(emoji)
            .dsTextStyle(SocialTextRole.pickerEmoji)
            .fixedSize()
            .frame(minWidth: Tokens.Sizes.globalMinTouchTargetIos, minHeight: Tokens.Sizes.globalMinTouchTargetIos)
            .frame(maxWidth: .infinity)
            .background {
                if mine.contains(emoji) {
                    Circle()
                        .fill(Tokens.Colors.globalControl)
                        .frame(width: Tokens.Sizes.globalCircleButton, height: Tokens.Sizes.globalCircleButton)
                }
            }
            .contentShape(Rectangle())
    }

    /// Mine → take it back; otherwise react, remember it ("Frequently Used") and close.
    private func choose(_ emoji: String) {
        if mine.contains(emoji) {
            onRemove(emoji)
        } else {
            SocialServices.shared.flags.recordEmoji(emoji, keep: Int(Tokens.Counts.chatReactionsCountPickerColumns))
            onPick(emoji)
            dismiss()
        }
    }
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
