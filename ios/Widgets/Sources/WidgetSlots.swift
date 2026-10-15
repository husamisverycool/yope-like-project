// Surfaces: widget.home.small / .medium / .large / .xl, widget.lock.rect / .circular / .inline,
// widget.arrival — reference app: Locket (+ Apple HIG Widgets).
// Reference images: references/auto/locket/store/locket-store-03.png, locket-store-06.png,
// references/auto/locket/help/locket-help-7914857-widget-with-avatar-crop.png,
// references/auto/locket/frames/locket-tt-7168613044728155438-15.133s-widget-placeholder-just-added.jpg,
// references/auto/platform/hig-widgets-ios-dimensions.png (design/surfaces/widget.*.md).
// The widget's content views, filled from the App Group snapshot. Pure SwiftUI (no timeline types),
// so AppTests snapshots them per family and state.
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
        /// No group: none chosen, left, deleted, signed out.
        case notSetUp
        /// The configured group has no photo yet.
        case empty
        /// The newest item is a photo.
        case photo
        /// The newest item is the same-moment collage.
        case collage
    }

    var state: State
    var groupName: String?
    var senderName: String?
    var caption: String?
    var postedAt: Date?
    var photo: UIImage?
    var avatar: UIImage?

    static let loading = GroupWidgetContent(state: .loading)

    init(state: State, groupName: String? = nil, senderName: String? = nil, caption: String? = nil,
         postedAt: Date? = nil, photo: UIImage? = nil, avatar: UIImage? = nil) {
        self.state = state
        self.groupName = groupName
        self.senderName = senderName
        self.caption = caption
        self.postedAt = postedAt
        self.photo = photo
        self.avatar = avatar
    }

    var hasCaption: Bool {
        guard let caption else { return false }
        return !caption.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// The visible empty text (`widget.home.small.empty.*`), when the widget has nothing to show.
    var emptyText: String? {
        switch state {
        case .notSetUp: return Copy.widgetHomeSmallEmptySetUp
        case .empty: return Copy.widgetHomeSmallEmptyNoPhotos
        default: return nil
        }
    }

    /// One accessibility label per widget (who and where, HIG; the avatar and pill are combined into it).
    var accessibilityLabel: String {
        let name = senderName ?? ""
        let group = groupName ?? ""
        switch state {
        case .photo:
            if hasCaption, let caption {
                return Copy.widgetHomeSmallA11yPhotoWithCaption(name: name, group: group, caption: caption)
            }
            return Copy.widgetHomeSmallA11yPhoto(name: name, group: group)
        case .collage:
            let date = postedAt.map { $0.formatted(date: .abbreviated, time: .omitted) } ?? ""
            return Copy.widgetHomeSmallA11yCollage(group: group, date: date)
        case .notSetUp, .empty:
            return emptyText ?? ""
        case .loading:
            return ""
        }
    }
}

// MARK: - Home Screen (small, medium, large, extra large)

/// The removable container background: the photo / collage page aspect-filling the widget, or the
/// loading / empty gradients.
struct WidgetEmptyState: View {
    let content: GroupWidgetContent

    var body: some View {
        switch content.state {
        case .photo, .collage:
            if let photo = content.photo {
                WidgetPhotoImage(image: photo)
            } else {
                placeholderGradient
            }
        case .loading:
            placeholderGradient
        case .empty, .notSetUp:
            LinearGradient(
                colors: [Tokens.Colors.widgetHomeSmallColorEmptyTop, Tokens.Colors.widgetHomeSmallColorEmptyBottom],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    /// Loading placeholder (Locket 2022). Its member avatars are not drawn: the App Group store holds
    /// no member avatars before the first rendition arrives.
    private var placeholderGradient: some View {
        LinearGradient(
            colors: [Tokens.Colors.widgetHomeSmallColorPlaceholderTop, Tokens.Colors.widgetHomeSmallColorPlaceholderBottom],
            startPoint: .top,
            endPoint: .bottom
        )
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

/// Home-screen content over the photo: bottom-leading avatar and caption pill (photo only, not on
/// the collage); the empty stack for empty / not set up. One accessibility element.
struct WidgetOverlay: View {
    let content: GroupWidgetContent
    let family: WidgetFamily

    var body: some View {
        ZStack {
            switch content.state {
            case .photo:
                senderRow
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            case .empty, .notSetUp:
                WidgetEmptyStack(text: content.emptyText)
            case .collage, .loading:
                Color.clear
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(content.accessibilityLabel)
        .accessibilityAddTraits(.isButton)
    }

    private var senderRow: some View {
        HStack(spacing: Tokens.Sizes.widgetHomeSmallSizeCaptionGap) {
            WidgetAvatar(image: content.avatar, diameter: Tokens.Sizes.widgetHomeSmallSizeAvatar, ring: true)
            if content.hasCaption, let caption = content.caption {
                Text(caption)
                    .dsTextStyle(WidgetType.caption)
                    .foregroundStyle(Tokens.Colors.globalTextPrimary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .contentTransition(.identity)
                    .padding(.horizontal, Tokens.Sizes.widgetHomeSmallSizeCaptionPadding)
                    .frame(minHeight: Tokens.Sizes.widgetHomeSmallSizeCaptionHeight)
                    .background(Tokens.Colors.widgetHomeSmallColorCaptionPill, in: Capsule())
            }
        }
        .padding(Tokens.Sizes.widgetHomeSmallSizeAvatarInset)
    }
}

/// Locket's empty widget (`widget.home.small.layout.empty`, md variant): a translucent circle holding
/// the photo glyph inside a ring, then the label `labelGap` below in `label` pt,
/// `widget.home.small.color.emptyLabel` (weight not measured: platform regular). The lg variant for
/// large / extra large exists only in the token's notes, so md is used at every size.
struct WidgetEmptyStack: View {
    var text: String?

    private typealias Empty = Tokens.Layouts.WidgetHomeSmallLayoutEmpty

    var body: some View {
        VStack(spacing: Empty.labelGap) {
            graphic
            if let text {
                Text(text)
                    .dsTextStyle(DSTextStyle(
                        family: Tokens.Fonts.globalFamily,
                        size: Empty.label,
                        weight: .regular,
                        relativeTo: WidgetTextStyleName.resolve(Tokens.Layouts.WidgetHomeSmallLayoutTextStyleMap.emptyLabel)
                    ))
                    .foregroundStyle(Tokens.Colors.widgetHomeSmallColorEmptyLabel)
                    .lineLimit(1)
            }
        }
    }

    private var graphic: some View {
        ZStack {
            Circle()
                .strokeBorder(Tokens.Colors.widgetHomeSmallColorEmptyRing, lineWidth: Empty.ringStroke)
                .frame(width: Empty.ring, height: Empty.ring)
            Circle()
                .fill(Tokens.Colors.widgetHomeSmallColorEmptyCircle)
                .frame(width: Empty.circle, height: Empty.circle)
            Image(systemName: Tokens.Icons.globalGallery)
                .resizable()
                .scaledToFit()
                .frame(width: Empty.glyphWidth, height: Empty.glyphHeight)
                .foregroundStyle(Tokens.Colors.globalTextPrimary)
        }
    }
}

/// The poster's avatar; without one, Locket's placeholder gradient (no glyph).
struct WidgetAvatar: View {
    let image: UIImage?
    let diameter: CGFloat
    /// The 1-pt ring (`widget.home.small.color.avatarRing`) on the Home Screen.
    var ring: Bool

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                LinearGradient(
                    colors: [Tokens.Colors.widgetAndroidColorAvatarPlaceholderTop, Tokens.Colors.widgetAndroidColorAvatarPlaceholderBottom],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        }
        .frame(width: diameter, height: diameter)
        .clipShape(Circle())
        .overlay {
            if ring {
                Circle().strokeBorder(Tokens.Colors.widgetHomeSmallColorAvatarRing, lineWidth: Tokens.Sizes.widgetHomeSmallSizeAvatarRing)
            }
        }
    }
}

// MARK: - Lock Screen (vibrant: the system renders everything in grayscale)

/// `.accessoryRectangular`: avatar + caption in one leading row; no caption → the avatar alone in its
/// slot (`widget.lock.rect.layout.content`; the entry is always the newest single photo).
struct WidgetRectangularSlot: View {
    let content: GroupWidgetContent

    var body: some View {
        HStack(spacing: Tokens.Sizes.widgetHomeSmallSizeCaptionGap) {
            switch content.state {
            case .photo, .collage:
                WidgetAvatar(image: content.avatar, diameter: Tokens.Sizes.widgetHomeSmallSizeAvatar, ring: false)
                if content.hasCaption, let caption = content.caption {
                    Text(caption)
                        .dsTextStyle(WidgetType.caption)
                        .foregroundStyle(Tokens.Colors.globalTextPrimary)
                        .truncationMode(.tail)
                        .contentTransition(.identity)
                }
            case .loading, .empty, .notSetUp:
                Image(systemName: Tokens.Icons.globalGallery)
                    .foregroundStyle(Tokens.Colors.globalTextPrimary)
                    .frame(width: Tokens.Sizes.widgetHomeSmallSizeAvatar)
                if let text = content.emptyText {
                    Text(text)
                        .dsTextStyle(WidgetType.caption)
                        .foregroundStyle(Tokens.Colors.globalTextPrimary)
                }
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(content.accessibilityLabel)
        .accessibilityAddTraits(.isButton)
    }
}

/// `.accessoryCircular`: the newest single photo's sender avatar filling the circle
/// (`widget.lock.rect.layout.content`).
struct WidgetCircularSlot: View {
    let content: GroupWidgetContent

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            ZStack {
                switch content.state {
                case .photo, .collage:
                    WidgetAvatar(image: content.avatar, diameter: side, ring: false)
                case .loading, .empty, .notSetUp:
                    Image(systemName: Tokens.Icons.globalGallery)
                        .foregroundStyle(Tokens.Colors.globalTextPrimary)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(content.accessibilityLabel)
        .accessibilityAddTraits(.isButton)
    }
}

/// `.accessoryInline` (one line of text above the clock, styled by the system): the newest single
/// photo's caption; without one, the `widget.home.small.a11y.photo` sentence
/// (`widget.lock.rect.layout.content`); the empty texts. Loading: an empty line.
struct WidgetInlineSlot: View {
    let content: GroupWidgetContent

    var body: some View {
        Text(line)
            .accessibilityLabel(content.state == .photo ? content.accessibilityLabel : line)
    }

    var line: String {
        switch content.state {
        case .photo, .collage:
            if content.hasCaption, let caption = content.caption { return caption }
            return Copy.widgetHomeSmallA11yPhoto(name: content.senderName ?? "", group: content.groupName ?? "")
        case .empty, .notSetUp: return content.emptyText ?? ""
        case .loading: return ""
        }
    }
}
