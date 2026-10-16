// Shared component — C-13 reply / comment bar (design/components.md). Evidence: TC-2B (48 pt rows 1821–1934; corner
// fit 12.1; avatar x1377–1446; fill (1700–1720, 1880–1890)); RV §4 #15; APK-X vv3.l "reply bar".
import DesignSystem
import SwiftUI

/// The field at the bottom of the viewer (and of a thread): own avatar leading, placeholder, trailing glyph.
///
/// - Fill: on media `color.global.controlOnDeep` (#262626, both appearances); on a page `color.global.control`.
/// - Height `size.global.commentFieldHeight` (a minimum, grows with Dynamic Type), corners
///   `radius.global.commentField` (a rounded rectangle, continuous — not a capsule), inset `size.global.screenMargin`
///   on each side (applied here).
/// - Leading avatar `size.global.avatarComment` (own photo).
/// - Placeholder text role `body` in `color.global.textSecondary`; typed text `color.global.textOnMedia` on media,
///   `color.global.textPrimary` on a page.
/// - Trailing glyph in `color.global.textSecondary`: `icon.global.send` when there is text (mechanics: send), else
///   `icon.global.more` when `onMore` is given.
/// Inner insets (avatar → edge, avatar → text) were not measured (Gap) — platform padding and spacing.
/// Accessibility: a text field labelled from copy; send and more are labelled buttons with a hit area of at least
/// `size.global.minTouchTarget.ios`. Contrast: placeholder on #262626 5.31:1 (CONTRAST row 41).
struct ReplyBar: View {
    enum Surface {
        case media
        case page
    }

    @Binding var text: String
    let placeholder: String
    let accessibilityLabel: String
    var avatar: PhotoSource?
    var surface: Surface = .media
    let sendLabel: String
    let onSend: () -> Void
    var moreLabel: String?
    var onMore: (() -> Void)?

    init(
        text: Binding<String>,
        placeholder: String,
        accessibilityLabel: String,
        avatar: PhotoSource? = nil,
        surface: Surface = .media,
        sendLabel: String,
        onSend: @escaping () -> Void,
        moreLabel: String? = nil,
        onMore: (() -> Void)? = nil
    ) {
        _text = text
        self.placeholder = placeholder
        self.accessibilityLabel = accessibilityLabel
        self.avatar = avatar
        self.surface = surface
        self.sendLabel = sendLabel
        self.onSend = onSend
        self.moreLabel = moreLabel
        self.onMore = onMore
    }

    private var hasText: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        HStack {
            AvatarView(source: avatar, diameter: Tokens.Sizes.globalAvatarComment)
            TextField(text: $text, prompt: Text(placeholder).foregroundStyle(Tokens.Colors.globalTextSecondary)) {
                Text(accessibilityLabel)
            }
            .dsTextStyle(TextRole.body)
            .foregroundStyle(surface == .media ? Tokens.Colors.globalTextOnMedia : Tokens.Colors.globalTextPrimary)
            .submitLabel(.send)
            .onSubmit { if hasText { onSend() } }
            .accessibilityLabel(Text(accessibilityLabel))
            trailing
        }
        .padding(.horizontal)
        .frame(maxWidth: .infinity, minHeight: Tokens.Sizes.globalCommentFieldHeight)
        .background(
            surface == .media ? Tokens.Colors.globalControlOnDeep : Tokens.Colors.globalControl,
            in: DSShape.rounded(Tokens.Radii.globalCommentField)
        )
        .padding(.horizontal, Tokens.Sizes.globalScreenMargin)
        .dsAnimation(ComponentMotion.crossfade, value: hasText)
    }

    @ViewBuilder
    private var trailing: some View {
        if hasText {
            glyphButton(Tokens.Icons.globalSend, label: sendLabel, action: onSend)
        } else if let onMore, let moreLabel {
            glyphButton(Tokens.Icons.globalMore, label: moreLabel, action: onMore)
        }
    }

    private func glyphButton(_ icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Glyph(icon)
                .foregroundStyle(Tokens.Colors.globalTextSecondary)
                .minimumHitArea(drawn: CGSize(width: Tokens.Sizes.globalIcon, height: Tokens.Sizes.globalIcon))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(label))
    }
}
