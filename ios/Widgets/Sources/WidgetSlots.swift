// Surfaces: widget.home.small / .medium / .large / .xl, widget.lock.rect / .circular / .inline, widget.arrival — visual
// reference Retro's Glance widgets (Albums variant: name over the group), mechanics Locket, sizes Apple HIG.
// Reference images: references/auto/retro/apk/widget_preview_journals.webp, …_friends.webp, …_memories.webp (full-bleed
// photo, white two-line stack bottom-trailing), references/auto/retro/apk/retro-android-2026.10.1150-excerpts.txt
// §"Glance widget" (state glyph in a 48-dp box, white 85 %), references/auto/retro/press/tc-2023-07-retro-1b.webp (C-16
// people row), references/auto/platform/hig-widgets-ios-dimensions.png (design/surfaces/widget.*.md; RC-9 … RC-11).
// The widget's content views, filled from the App Group snapshot. Pure SwiftUI (no timeline types), so AppTests
// snapshots them per family and state (linked into ios/AppTests/Capture/Linked).
import AppModels
import DesignSystem
import SwiftUI
import UIKit
import WidgetKit

/// What a group widget shows, resolved from `WidgetStore` by the timeline provider.
struct GroupWidgetContent {
    enum State: Equatable {
        /// Just added; no rendition cached yet (also the gallery preview).
        case loading
        /// No group: none chosen, left or deleted.
        case notSetUp
        /// Nobody is signed in on this device (the app wrote no group list).
        case signedOut
        /// The configured group has no photo yet.
        case empty
        /// The newest item is a photo.
        case photo
        /// The newest item is the same-moment collage.
        case collage
    }

    var state: State
    var groupName: String?
    /// The poster's display name (the widget shows its first word).
    var senderName: String?
    var postedAt: Date?
    var photo: UIImage?
    var avatar: UIImage?

    static let loading = GroupWidgetContent(state: .loading)

    init(state: State, groupName: String? = nil, senderName: String? = nil, postedAt: Date? = nil, photo: UIImage? = nil, avatar: UIImage? = nil) {
        self.state = state
        self.groupName = groupName
        self.senderName = senderName
        self.postedAt = postedAt
        self.photo = photo
        self.avatar = avatar
    }

    /// {name}: the first word of the poster's display name (notifications.push, widget.home.small).
    var firstName: String {
        let trimmed = (senderName ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.split(separator: " ").first.map(String.init) ?? trimmed
    }

    /// The visible state line (`widget.home.small.empty.*`), when the widget has nothing to show.
    var stateLine: String? {
        switch state {
        case .notSetUp: return Copy.widgetHomeSmallEmptySetUp
        case .signedOut: return Copy.widgetHomeSmallEmptySignedOut
        case .empty: return Copy.widgetHomeSmallEmptyNoPhotos
        case .loading, .photo, .collage: return nil
        }
    }

    /// {date} of `widget.home.small.a11y.collage`: the day in the locale's long date ("May 26, 2026", `retro.voice.formats`).
    var dateText: String {
        postedAt.map { $0.formatted(date: .long, time: .omitted) } ?? ""
    }

    /// One accessibility label per widget (who and where).
    var accessibilityLabel: String {
        let group = groupName ?? ""
        switch state {
        case .photo: return Copy.widgetHomeSmallA11yPhoto(name: firstName, group: group)
        case .collage: return Copy.widgetHomeSmallA11yCollage(group: group, date: dateText)
        case .notSetUp, .signedOut, .empty: return stateLine ?? ""
        case .loading: return ""
        }
    }
}

// MARK: - Home Screen (small, medium, large, extra large): one layout at every size (RC-11)

/// The removable container background: the photo / collage page aspect-filling the widget under the bottom scrim
/// (`widget.home.small.layout.photo`, `layout.global.photoScrim`); every other state is `color.global.backgroundDeep`
/// (composition, RC-10). Errors keep the last photo (HIG): the timeline only replaces it with a newer one.
struct WidgetContainerBackground: View {
    let content: GroupWidgetContent

    var body: some View {
        ZStack {
            Tokens.Colors.globalBackgroundDeep
            if content.state == .photo || content.state == .collage, let photo = content.photo {
                WidgetPhotoImage(image: photo)
                WidgetPhotoScrim()
            }
        }
    }
}

/// The photo, full colour in tinted / clear Home Screen appearances (HIG: media such as album art).
struct WidgetPhotoImage: View {
    let image: UIImage

    var body: some View {
        if #available(iOS 18.0, *) {
            Image(uiImage: image)
                .resizable()
                .widgetAccentedRenderingMode(.fullColor)
                .scaledToFill()
                .transition(.identity)
        } else {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .transition(.identity)
        }
    }
}

/// Home-screen content over the photo: Retro's text stack at the bottom-trailing corner, or the state column. One
/// accessibility element with the button trait (a tap opens the camera).
struct WidgetOverlay: View {
    let content: GroupWidgetContent

    var body: some View {
        ZStack {
            switch content.state {
            case .photo:
                WidgetTextStack(lines: [content.firstName, content.groupName ?? ""])
            case .collage:
                WidgetTextStack(lines: [content.groupName ?? ""])
            case .empty, .notSetUp, .signedOut:
                WidgetStateColumn(line: content.stateLine)
            case .loading:
                Color.clear
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(content.accessibilityLabel))
        .accessibilityAddTraits(.isButton)
    }
}

/// Retro's widget text stack (`widget.home.small.layout.overlay`): trailing-aligned lines in
/// `widget.home.small.fontSize.overlay` / `.fontWeight.overlay`, `color.global.textOnMedia`; the last baseline
/// `lastBaselineFromBottom` (15) above the bottom edge, lines `linePitch` (13) apart baseline to baseline, `trailingInset`
/// (11) from the trailing edge; each line one line, truncated at the leading `size.global.screenMargin`. The pitch scales
/// with the text (Caption 2).
struct WidgetTextStack: View {
    /// Top to bottom (photo: first name, group; collage: group).
    let lines: [String]

    @ScaledMetric private var pitch: CGFloat
    @ScaledMetric private var lastBaseline: CGFloat

    private typealias Overlay = Tokens.Layouts.WidgetHomeSmallLayoutOverlay

    init(lines: [String]) {
        self.lines = lines
        let style = WidgetType.overlay.relativeTo
        _pitch = ScaledMetric(wrappedValue: Overlay.linePitch, relativeTo: style)
        _lastBaseline = ScaledMetric(wrappedValue: Overlay.lastBaselineFromBottom, relativeTo: style)
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Color.clear
            ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                Text(line)
                    .dsTextStyle(WidgetType.overlay)
                    .foregroundStyle(Tokens.Colors.globalTextOnMedia)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .contentTransition(.identity)
                    // Each line's baseline sits `lastBaseline` + n × `pitch` above the bottom edge (n = lines below it).
                    .alignmentGuide(.bottom) { dimensions in
                        dimensions[.lastTextBaseline] + lastBaseline + CGFloat(lines.count - 1 - index) * pitch
                    }
            }
        }
        .padding(.leading, Tokens.Sizes.globalScreenMargin)
        .padding(.trailing, Overlay.trailingInset)
    }
}

/// Retro's widget state column (RC-10): `icon.global.camera` (the tap's action) at `size.global.icon` in a 48-pt box —
/// the APK's 48-dp Glance box, the platform minimum target `size.global.minTouchTarget.android` (no capture token holds
/// the box) — then the line in `widget.home.small.fontSize.overlay`, both tinted `widget.home.small.color.stateTint`
/// (white 85 %), centred, up to 2 lines.
struct WidgetStateColumn: View {
    var line: String?

    var body: some View {
        VStack(spacing: 0) {
            Image(systemName: Tokens.Icons.globalCamera)
                .resizable()
                .scaledToFit()
                .frame(width: Tokens.Sizes.globalIcon, height: Tokens.Sizes.globalIcon)
                .frame(width: Tokens.Sizes.globalMinTouchTargetAndroid, height: Tokens.Sizes.globalMinTouchTargetAndroid)
            if let line {
                Text(line)
                    .dsTextStyle(WidgetType.overlay)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
        }
        .foregroundStyle(Tokens.Colors.widgetHomeSmallColorStateTint)
        .padding(.horizontal, Tokens.Sizes.globalScreenMargin)
    }
}

// MARK: - Lock Screen (vibrant: the system renders everything in grayscale; HIG)

/// The newest poster's avatar for the Lock Screen (C-23 circle, aspect-fill, full opacity — the system desaturates it);
/// no photo: `icon.global.person` (C-23 fallback); a collage or a state: `icon.global.camera`.
struct WidgetLockAvatar: View {
    let content: GroupWidgetContent
    let diameter: CGFloat

    var body: some View {
        ZStack {
            if content.state == .photo {
                if let avatar = content.avatar {
                    Image(uiImage: avatar)
                        .resizable()
                        .scaledToFill()
                        .frame(width: diameter, height: diameter)
                        .clipShape(Circle())
                } else {
                    glyph(Tokens.Icons.globalPerson)
                }
            } else {
                glyph(Tokens.Icons.globalCamera)
            }
        }
        .frame(width: diameter, height: diameter)
    }

    private func glyph(_ name: String) -> some View {
        Image(systemName: name)
            .resizable()
            .scaledToFit()
            .frame(width: Tokens.Sizes.globalIcon, height: Tokens.Sizes.globalIcon)
            .foregroundStyle(Tokens.Colors.globalTextOnMedia)
    }
}

/// `.accessoryRectangular` (`widget.lock.rect.layout.content`): one C-16 row — the avatar (`size.global.avatarPicker`),
/// then `size.global.cardNameGap` after it the name (text role `listTitle`) over the group (text role `listSubtitle`),
/// white, one line each. Collage: the group name alone (`listTitle`) with the camera glyph in the avatar slot. States: the
/// camera glyph + the state line (`listSubtitle`); loading: the glyph alone.
struct WidgetRectangularSlot: View {
    let content: GroupWidgetContent

    var body: some View {
        HStack(spacing: Tokens.Sizes.globalCardNameGap) {
            WidgetLockAvatar(content: content, diameter: Tokens.Sizes.globalAvatarPicker)
            VStack(alignment: .leading, spacing: 0) {
                switch content.state {
                case .photo:
                    line(content.firstName, style: WidgetType.listTitle)
                    line(content.groupName ?? "", style: WidgetType.listSubtitle)
                case .collage:
                    line(content.groupName ?? "", style: WidgetType.listTitle)
                case .empty, .notSetUp, .signedOut:
                    if let text = content.stateLine {
                        Text(text)
                            .dsTextStyle(WidgetType.listSubtitle)
                            .foregroundStyle(Tokens.Colors.globalTextOnMedia)
                            .lineLimit(2)
                    }
                case .loading:
                    EmptyView()
                }
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(content.accessibilityLabel))
        .accessibilityAddTraits(.isButton)
    }

    private func line(_ text: String, style: DSTextStyle) -> some View {
        Text(text)
            .dsTextStyle(style)
            .foregroundStyle(Tokens.Colors.globalTextOnMedia)
            .lineLimit(1)
            .truncationMode(.tail)
            .contentTransition(.identity)
    }
}

/// `.accessoryCircular`: the newest poster's avatar filling the circle (C-23); a collage or a state: the camera glyph.
struct WidgetCircularSlot: View {
    let content: GroupWidgetContent

    var body: some View {
        GeometryReader { proxy in
            WidgetLockAvatar(content: content, diameter: min(proxy.size.width, proxy.size.height))
                .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(content.accessibilityLabel))
        .accessibilityAddTraits(.isButton)
    }
}

/// `.accessoryInline` (one line above the clock, styled by the system): `widget.lock.inline.text` "{name} · {group}";
/// a collage: the group name; the state lines; loading: an empty line.
struct WidgetInlineSlot: View {
    let content: GroupWidgetContent

    var body: some View {
        Text(line)
            .accessibilityLabel(Text(content.state == .photo || content.state == .collage ? content.accessibilityLabel : line))
    }

    var line: String {
        switch content.state {
        case .photo: return Copy.widgetLockInlineText(name: content.firstName, group: content.groupName ?? "")
        case .collage: return content.groupName ?? ""
        case .empty, .notSetUp, .signedOut: return content.stateLine ?? ""
        case .loading: return ""
        }
    }
}
