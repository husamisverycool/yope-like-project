// Shared component — C-18 friend card (photo card) with avatar and name, in a horizontal pager (design/components.md).
// Evidence: ST-01 (card x209–782 y1417–2278; avatar col x=264 y1331–1393; gap x784–820), ED-A (badge
// (947–1138, 1402–1495)); RV §3.4, §3.5, §3.8, §4 #4.
import DesignSystem
import SwiftUI

/// Avatar (`size.global.avatarList`) + name (text role `listTitle`, `color.global.textPrimary`, `size.global.cardNameGap`
/// after the avatar) above a 2:3 photo card (`size.global.friendCardWidth` × `.friendCardHeight`, `radius.global.card`
/// continuous, aspect-fill, no border, no shadow), `size.global.cardHeaderGap` below the avatar. Optional count-free
/// "new" badge (C-24) `size.global.badgeInset` from the card's top and right — Retro's "Seen" pill and "N new" counts
/// are not copied. Pressed: platform default; the viewer opens with `ComponentMotion.photoOpen`
/// (`duration.global.photoOpen`, `easing.global.standard`). Accessibility: one button labelled from copy
/// ("{name}'s week, new photos").
struct FriendCard: View {
    let name: String
    var avatar: PhotoSource?
    var photo: PhotoSource?
    var newLabel: String?
    let accessibilityLabel: String
    let action: () -> Void

    init(
        name: String,
        avatar: PhotoSource?,
        photo: PhotoSource?,
        newLabel: String? = nil,
        accessibilityLabel: String,
        action: @escaping () -> Void
    ) {
        self.name = name
        self.avatar = avatar
        self.photo = photo
        self.newLabel = newLabel
        self.accessibilityLabel = accessibilityLabel
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: Tokens.Sizes.globalCardHeaderGap) {
                HStack(spacing: Tokens.Sizes.globalCardNameGap) {
                    AvatarView(source: avatar, diameter: Tokens.Sizes.globalAvatarList)
                    Text(name)
                        .dsTextStyle(TextRole.listTitle)
                        .foregroundStyle(Tokens.Colors.globalTextPrimary)
                        .lineLimit(1)
                }
                PhotoView(source: photo)
                    .frame(width: Tokens.Sizes.globalFriendCardWidth, height: Tokens.Sizes.globalFriendCardHeight)
                    .clipShape(DSShape.rounded(Tokens.Radii.globalCard))
                    .newBadge(newLabel)
            }
            .frame(width: Tokens.Sizes.globalFriendCardWidth, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(accessibilityLabel))
        .accessibilityAddTraits(.isButton)
    }
}

/// Friend cards in a horizontal pager: the first card at `size.global.screenMargin`, cards `size.global.cardGap` apart,
/// the next card peeking; scrolling settles on a card (view-aligned).
struct FriendCardPager<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(alignment: .top, spacing: Tokens.Sizes.globalCardGap) {
                content
            }
            .scrollTargetLayout()
        }
        .contentMargins(.horizontal, Tokens.Sizes.globalScreenMargin, for: .scrollContent)
        .scrollTargetBehavior(.viewAligned)
    }
}
