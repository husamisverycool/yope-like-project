// Shared component — C-19 profile header (design/components.md). Evidence: ST-02 (avatar 919–1072; info rows
// y911/978/1048; buttons y1129–1217), JED, Apptisan; RV §3.4, §4 #12.
import DesignSystem
import SwiftUI

/// An info row of the profile header: a glyph (`icon.global.location`, `.calendar`, `.camera`) and its text.
/// "Weeks Posted: N" is not copied (a count).
struct ProfileInfoRow {
    let icon: String
    let text: String

    init(icon: String, text: String) {
        self.icon = icon
        self.text = text
    }
}

/// The name in the display serif (text role `headerTitle`, `color.global.textPrimary`, as typed), the real name below
/// (text role `meta`, `color.global.textSecondary`), the avatar (`size.global.avatarProfile`) with its ink at the right
/// margin, centred on the name block; info rows (glyph `size.global.iconSmall` in `color.global.textPrimary` + text role
/// `body`, row pitch `size.global.infoRowPitch`); then the action row (`actions`: C-06 capsules in a `CapsuleRow` —
/// equal widths, `size.global.pillGap` apart, a trailing icon-only `icon.global.settings` capsule). Week sections follow
/// (C-20 + C-17), with no divider (2026). Inset `size.global.screenMargin`. The vertical gaps between the name block,
/// the info rows and the action row were not measured (Gap) — platform stack spacing.
/// Accessibility: the name is a header; the avatar is labelled with the person's name.
struct ProfileHeader<Actions: View>: View {
    let name: String
    var realName: String?
    var avatar: PhotoSource?
    let avatarAccessibilityLabel: String
    var infoRows: [ProfileInfoRow]
    @ViewBuilder let actions: () -> Actions

    init(
        name: String,
        realName: String? = nil,
        avatar: PhotoSource?,
        avatarAccessibilityLabel: String,
        infoRows: [ProfileInfoRow] = [],
        @ViewBuilder actions: @escaping () -> Actions
    ) {
        self.name = name
        self.realName = realName
        self.avatar = avatar
        self.avatarAccessibilityLabel = avatarAccessibilityLabel
        self.infoRows = infoRows
        self.actions = actions
    }

    var body: some View {
        VStack(alignment: .leading) {
            HStack(alignment: .center) {
                VStack(alignment: .leading) {
                    Text(name)
                        .dsTextStyle(TextRole.headerTitle)
                        .foregroundStyle(Tokens.Colors.globalTextPrimary)
                        .accessibilityAddTraits(.isHeader)
                    if let realName {
                        Text(realName)
                            .dsTextStyle(TextRole.meta)
                            .foregroundStyle(Tokens.Colors.globalTextSecondary)
                    }
                }
                Spacer(minLength: 0)
                AvatarView(source: avatar, diameter: Tokens.Sizes.globalAvatarProfile, accessibilityLabel: avatarAccessibilityLabel)
            }
            if !infoRows.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(infoRows.indices, id: \.self) { index in
                        HStack {
                            Glyph(infoRows[index].icon, size: Tokens.Sizes.globalIconSmall, relativeTo: TextRole.body.relativeTo)
                            Text(infoRows[index].text)
                                .dsTextStyle(TextRole.body)
                        }
                        .foregroundStyle(Tokens.Colors.globalTextPrimary)
                        .frame(minHeight: Tokens.Sizes.globalInfoRowPitch)
                        .accessibilityElement(children: .combine)
                    }
                }
            }
            actions()
        }
        .padding(.horizontal, Tokens.Sizes.globalScreenMargin)
    }
}
