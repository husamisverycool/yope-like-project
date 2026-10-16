// Shared component — C-15 list row with thumbnail (albums / groups) (design/components.md). Evidence: ED-W3 (thumbs
// (1870–2148, 842–1217), title x=2213, '+' x3138–3277), ED-A; RV §3.4, §4 #10.
import DesignSystem
import SwiftUI

/// A list row: a 3:4 cover thumbnail (`size.global.rowThumbWidth` × `.rowThumbHeight`, `radius.global.thumbnail`,
/// continuous, aspect-fill), then — `size.global.rowThumbGap` after it — the title (text role `listTitle`,
/// `color.global.textPrimary`), the subtitle (text role `listSubtitle`, `color.global.textSecondary`, with the actor's
/// name in the `listTitle` weight: "**daniel** shared…"), and an avatar stack (C-23); an optional trailing circle
/// button (C-11 `.page`, `icon.global.add`) with its ink at the right margin. Rows sit `size.global.listGap` apart
/// (`ThumbnailRowList`). Counts in subtitles are Retro's; ours come from copy, which drops them (tenets).
/// Text block → stack spacing was not measured (Gap) — platform stack spacing.
/// Accessibility: the row is one button (title and subtitle combined, `accessibilityLabel` from copy); the '+' is a
/// separate labelled button.
struct ThumbnailRow: View {
    let title: String
    var subtitle: String?
    /// The part of `subtitle` drawn in the title weight (the actor's name); nil: none.
    var subtitleEmphasis: String?
    var thumbnail: PhotoSource?
    var avatars: [PhotoSource?] = []
    let accessibilityLabel: String
    var addAccessibilityLabel: String?
    var onAdd: (() -> Void)?
    let action: () -> Void

    init(
        title: String,
        subtitle: String? = nil,
        subtitleEmphasis: String? = nil,
        thumbnail: PhotoSource?,
        avatars: [PhotoSource?] = [],
        accessibilityLabel: String,
        addAccessibilityLabel: String? = nil,
        onAdd: (() -> Void)? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.subtitle = subtitle
        self.subtitleEmphasis = subtitleEmphasis
        self.thumbnail = thumbnail
        self.avatars = avatars
        self.accessibilityLabel = accessibilityLabel
        self.addAccessibilityLabel = addAccessibilityLabel
        self.onAdd = onAdd
        self.action = action
    }

    var body: some View {
        HStack(spacing: 0) {
            Button(action: action) {
                HStack(spacing: Tokens.Sizes.globalRowThumbGap) {
                    PhotoView(source: thumbnail)
                        .frame(width: Tokens.Sizes.globalRowThumbWidth, height: Tokens.Sizes.globalRowThumbHeight)
                        .clipShape(DSShape.rounded(Tokens.Radii.globalThumbnail))
                    VStack(alignment: .leading) {
                        Text(title)
                            .dsTextStyle(TextRole.listTitle)
                            .foregroundStyle(Tokens.Colors.globalTextPrimary)
                        if let subtitle {
                            subtitleText(subtitle)
                                .dsTextStyle(TextRole.listSubtitle)
                                .foregroundStyle(Tokens.Colors.globalTextSecondary)
                        }
                        if !avatars.isEmpty {
                            AvatarStack(sources: avatars)
                        }
                    }
                    .multilineTextAlignment(.leading)
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(accessibilityLabel))
            .accessibilityAddTraits(.isButton)
            if let onAdd, let addAccessibilityLabel {
                CircleButton(icon: Tokens.Icons.globalAdd, accessibilityLabel: addAccessibilityLabel, style: .page, action: onAdd)
            }
        }
        .padding(.horizontal, Tokens.Sizes.globalScreenMargin)
    }

    /// The subtitle with `subtitleEmphasis` (its first occurrence) in the `listTitle` weight.
    private func subtitleText(_ subtitle: String) -> Text {
        guard let subtitleEmphasis, let range = subtitle.range(of: subtitleEmphasis) else { return Text(subtitle) }
        let before = Text(String(subtitle[..<range.lowerBound]))
        let emphasis = Text(String(subtitle[range])).fontWeight(Tokens.FontWeights.fontWeightGlobalListTitle)
        let after = Text(String(subtitle[range.upperBound...]))
        return Text("\(before)\(emphasis)\(after)") // provenance-ok: concatenates copy strings, no literal text
    }
}

/// Thumbnail rows `size.global.listGap` apart (row pitch 119.5 in Retro's albums list).
struct ThumbnailRowList<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        LazyVStack(spacing: Tokens.Sizes.globalListGap) {
            content
        }
    }
}
