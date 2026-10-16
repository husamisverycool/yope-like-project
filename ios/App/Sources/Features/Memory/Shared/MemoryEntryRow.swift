// Entries the account pass places on `groups.screen` for the memory surfaces (onthisday, year.story, birthday.request):
// the memory group supplies what an entry says, its photo and what a tap opens; the placement and the final look belong
// to the groups.screen pass (design/surfaces/groups.screen.md items 6 and 8; onthisday.md "Entry", year.story.md
// "Entry", birthday.request.md "Entry"). The default rows below are those items' compositions of components:
// the feed card (C-18 geometry + `layout.global.photoScrim` + text role `displaySmall` + C-09) and the request row
// (C-14 + C-16).
import DesignSystem
import SwiftUI

/// What an entry says and shows.
struct MemoryEntryContent: Equatable {
    /// `onthisday.entry.title` / `year.story.entry.title` / `birthday.request.title`.
    let title: String
    /// `onthisday.entry.subtitle` / `year.story.entry.subtitle` / `birthday.request.due`.
    let subtitle: String
    /// `onthisday.entry.button` / `year.story.entry.button`; nil for the request row.
    var buttonTitle: String?
    /// The feature's glyph on the feed card's header line (`icon.global.rewind` / `icon.global.recap`).
    var icon: String?
    /// The feature's newest photo (storage path of its display rendition) for the feed card.
    var photoPath: String?
    /// The honoree's avatar (storage path) on the request row.
    var avatarPath: String?

    init(title: String, subtitle: String, buttonTitle: String? = nil, icon: String? = nil, photoPath: String? = nil, avatarPath: String? = nil) {
        self.title = title
        self.subtitle = subtitle
        self.buttonTitle = buttonTitle
        self.icon = icon
        self.photoPath = photoPath
        self.avatarPath = avatarPath
    }
}

/// groups.screen item 8 — a feed card in the members' pager: the header line (the feature's glyph in a
/// `size.global.avatarList` box, `size.global.cardNameGap`, the title in text role `listTitle`), `size.global.cardHeaderGap`
/// above a `size.global.friendCardWidth` × `.friendCardHeight` card (`radius.global.card`, continuous) showing the
/// feature's newest photo aspect-fill under `layout.global.photoScrim`; at its bottom inside `size.global.screenMargin`:
/// the title in `font.global.display` text role `displaySmall`, the line (text role `listSubtitle`), both
/// `color.global.textOnMedia`, then the C-09 light pill with the action. Spacing between the three was not measured —
/// platform stack spacing. One button for VoiceOver (title, line, action).
struct MemoryFeedCard: View {
    let content: MemoryEntryContent

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Sizes.globalCardHeaderGap) {
            HStack(spacing: Tokens.Sizes.globalCardNameGap) {
                if let icon = content.icon {
                    Glyph(icon)
                        .foregroundStyle(Tokens.Colors.globalTextPrimary)
                        .frame(width: Tokens.Sizes.globalAvatarList, height: Tokens.Sizes.globalAvatarList)
                }
                Text(content.title)
                    .dsTextStyle(TextRole.listTitle)
                    .foregroundStyle(Tokens.Colors.globalTextPrimary)
                    .lineLimit(1)
            }
            ZStack(alignment: .bottomLeading) {
                PhotoView(source: content.photoPath.map(PhotoSource.storage))
                PhotoScrim()
                VStack(alignment: .leading) {
                    Text(content.title)
                        .dsTextStyle(TextRole.displaySmall)
                    Text(content.subtitle)
                        .dsTextStyle(TextRole.listSubtitle)
                    if let button = content.buttonTitle {
                        LightPillLabel(button)
                    }
                }
                .foregroundStyle(Tokens.Colors.globalTextOnMedia)
                .multilineTextAlignment(.leading)
                .padding(Tokens.Sizes.globalScreenMargin)
            }
            .frame(width: Tokens.Sizes.globalFriendCardWidth, height: Tokens.Sizes.globalFriendCardHeight)
            .background(Tokens.Colors.globalBackgroundDeep)
            .clipShape(DSShape.rounded(Tokens.Radii.globalCard))
        }
        .frame(width: Tokens.Sizes.globalFriendCardWidth, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }
}

/// groups.screen item 6 — the birthday request row: one C-14 row inside `size.global.screenMargin` (fill
/// `color.global.control`, `radius.global.groupedRow`, platform row padding): the honoree's avatar
/// (`size.global.avatarPicker`, C-16), the title (text role `listTitle`, `color.global.textPrimary`) over the due line
/// (text role `listSubtitle`, `color.global.textSecondary`), trailing `icon.global.chevron` in `color.global.textSecondary`.
struct MemoryRequestRow: View {
    let content: MemoryEntryContent

    var body: some View {
        HStack {
            AvatarView(path: content.avatarPath, diameter: Tokens.Sizes.globalAvatarPicker)
            VStack(alignment: .leading) {
                Text(content.title)
                    .dsTextStyle(TextRole.listTitle)
                    .foregroundStyle(Tokens.Colors.globalTextPrimary)
                Text(content.subtitle)
                    .dsTextStyle(TextRole.listSubtitle)
                    .foregroundStyle(Tokens.Colors.globalTextSecondary)
            }
            .multilineTextAlignment(.leading)
            Spacer(minLength: 0)
            Glyph(Tokens.Icons.globalChevron, relativeTo: TextRole.body.relativeTo)
                .foregroundStyle(Tokens.Colors.globalTextSecondary)
        }
        .padding()
        .frame(minHeight: Tokens.Sizes.globalMinTouchTargetIos)
        .background(Tokens.Colors.globalControl, in: DSShape.rounded(Tokens.Radii.globalGroupedRow))
        .contentShape(DSShape.rounded(Tokens.Radii.globalGroupedRow))
        .padding(.horizontal, Tokens.Sizes.globalScreenMargin)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }
}
