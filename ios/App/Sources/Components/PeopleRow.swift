// Shared component — C-16 people row (request / member) and comment row (design/components.md). Evidence: TC-1B
// (avatar 1356–1436; Accept x1473–1802 y1402–1482; unread dot), TC-2B (comment row 'elton 2h'); RV §3.4, §4 #9–#11.
import DesignSystem
import SwiftUI

/// A people row: avatar `size.global.avatarPicker`, name (text role `listTitle`, `color.global.textPrimary`) over an
/// optional line (text role `listSubtitle`, `color.global.textSecondary`), an optional count-free unread dot (C-24),
/// then `actions` — typically a pair of C-06 capsules (`CapsuleRow`, `size.global.pillGap` apart). Avatar → text and
/// the dot's placement were not measured (Gap) — platform spacing, the dot after the name. Inset
/// `size.global.screenMargin` (applied here). Accessibility: name and line read as one element (with `unreadValue` from
/// copy when marked); actions are separate buttons.
struct PeopleRow<Actions: View>: View {
    let name: String
    var line: String?
    var avatar: PhotoSource?
    var unreadValue: String?
    @ViewBuilder let actions: () -> Actions

    init(name: String, line: String? = nil, avatar: PhotoSource?, unreadValue: String? = nil, @ViewBuilder actions: @escaping () -> Actions) {
        self.name = name
        self.line = line
        self.avatar = avatar
        self.unreadValue = unreadValue
        self.actions = actions
    }

    var body: some View {
        HStack {
            AvatarView(source: avatar, diameter: Tokens.Sizes.globalAvatarPicker)
            VStack(alignment: .leading) {
                HStack {
                    Text(name)
                        .dsTextStyle(TextRole.listTitle)
                        .foregroundStyle(Tokens.Colors.globalTextPrimary)
                    if unreadValue != nil {
                        UnreadDot()
                    }
                }
                if let line {
                    Text(line)
                        .dsTextStyle(TextRole.listSubtitle)
                        .foregroundStyle(Tokens.Colors.globalTextSecondary)
                }
            }
            .multilineTextAlignment(.leading)
            .accessibilityElement(children: .combine)
            .accessibilityValue(Text(unreadValue ?? ""))
            Spacer(minLength: 0)
            actions()
        }
        .padding(.horizontal, Tokens.Sizes.globalScreenMargin)
    }
}

extension PeopleRow where Actions == EmptyView {
    init(name: String, line: String? = nil, avatar: PhotoSource?, unreadValue: String? = nil) {
        self.init(name: name, line: line, avatar: avatar, unreadValue: unreadValue) { EmptyView() }
    }
}

/// A comment row (viewer / thread): avatar `size.global.avatarComment`; "name 2h" — name text role `listTitle`, time
/// text role `caption` in `color.global.textSecondary` on the name's baseline; the comment in text role `body`. On media
/// (the viewer) name and comment are `color.global.textOnMedia`; on a page `color.global.textPrimary`. Inset
/// `size.global.screenMargin`. Accessibility: one element (name, time, comment).
struct CommentRow: View {
    let name: String
    var time: String?
    let text: String
    var avatar: PhotoSource?
    var onMedia: Bool = true

    init(name: String, time: String? = nil, text: String, avatar: PhotoSource?, onMedia: Bool = true) {
        self.name = name
        self.time = time
        self.text = text
        self.avatar = avatar
        self.onMedia = onMedia
    }

    private var primary: Color { onMedia ? Tokens.Colors.globalTextOnMedia : Tokens.Colors.globalTextPrimary }

    var body: some View {
        HStack(alignment: .top) {
            AvatarView(source: avatar, diameter: Tokens.Sizes.globalAvatarComment)
            VStack(alignment: .leading) {
                HStack(alignment: .firstTextBaseline) {
                    Text(name)
                        .dsTextStyle(TextRole.listTitle)
                        .foregroundStyle(primary)
                    if let time {
                        Text(time)
                            .dsTextStyle(TextRole.caption)
                            .foregroundStyle(Tokens.Colors.globalTextSecondary)
                    }
                }
                Text(text)
                    .dsTextStyle(TextRole.body)
                    .foregroundStyle(primary)
            }
            .multilineTextAlignment(.leading)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Tokens.Sizes.globalScreenMargin)
        .accessibilityElement(children: .combine)
    }
}
