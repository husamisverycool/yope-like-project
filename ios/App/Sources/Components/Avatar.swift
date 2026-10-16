// Shared component — C-23 avatars and avatar stacks (design/components.md). Evidence: ED-W3, ED-A, ST-01, ST-02,
// TC-1B, TC-2B; RV §4 #11.
import DesignSystem
import SwiftUI

/// A circular avatar, aspect-fill photo.
///
/// Sizes (callers pass one): `size.global.avatarSmall` 22.6 (stack), `.avatarList` 26.5 (friend-card header),
/// `.avatarComment` 30 (comment rows, reply field), `.avatarPicker` 37 (request / member rows), `.avatarHeader` 39
/// (viewer header), `.avatarProfile` 64 (profile header), `.avatarGrid` 81 (people grid).
///
/// Shows, in order: a local image (just picked), the photo at `source` / `path`, else the no-photo look. Retro's no-photo
/// avatar is initials on a colour circle whose palette is not measurable (Gap: one raw screenshot of a friend without
/// a photo); until then `placeholderIcon` (`icon.global.person`; `icon.global.group` for groups) in
/// `color.global.textSecondary` on `color.global.control`, at the platform's symbol size. The viewer header's white
/// ring with a gap and the stack's white ring are not drawn: their widths were not measured (Gap).
///
/// Accessibility: decorative next to a visible name (the default); alone, pass the person's name as
/// `accessibilityLabel`.
struct AvatarView: View {
    var source: PhotoSource?
    var localImage: Image?
    let diameter: CGFloat
    var placeholderIcon: String
    var accessibilityLabel: String?

    init(path: String? = nil, localImage: Image? = nil, diameter: CGFloat, placeholderIcon: String = Tokens.Icons.globalPerson) {
        source = path.map { PhotoSource.storage($0) }
        self.localImage = localImage
        self.diameter = diameter
        self.placeholderIcon = placeholderIcon
        accessibilityLabel = nil
    }

    init(source: PhotoSource?, diameter: CGFloat, placeholderIcon: String = Tokens.Icons.globalPerson, accessibilityLabel: String? = nil) {
        self.source = source
        localImage = nil
        self.diameter = diameter
        self.placeholderIcon = placeholderIcon
        self.accessibilityLabel = accessibilityLabel
    }

    var body: some View {
        photo
            .frame(width: diameter, height: diameter)
            .clipShape(Circle())
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(accessibilityLabel ?? ""))
            .accessibilityAddTraits(.isImage)
            .accessibilityHidden(accessibilityLabel == nil)
    }

    @ViewBuilder
    private var photo: some View {
        if let localImage {
            localImage.resizable().aspectRatio(contentMode: .fill)
        } else {
            switch source {
            case let .storage(path)?:
                StorageImage(path: path) { fallback }
            case let .url(url)?:
                URLImage(url: url) { fallback }
            case let .image(image)?:
                Image(uiImage: image).resizable().aspectRatio(contentMode: .fill)
            case nil:
                fallback
            }
        }
    }

    private var fallback: some View {
        ZStack {
            Circle().fill(Tokens.Colors.globalControl)
            Image(systemName: placeholderIcon)
                .foregroundStyle(Tokens.Colors.globalTextSecondary)
        }
    }
}

/// Which avatars of a stack are shown. A stack never shows a count ('+3'): people past the limit are left out (tenets).
enum AvatarStackLayout {
    /// How many of `count` avatars are shown: all, or at most `maxVisible`, or as many as fit in `maxWidth`.
    static func visibleCount(count: Int, maxVisible: Int? = nil, maxWidth: CGFloat? = nil, diameter: CGFloat, overlap: CGFloat) -> Int {
        var visible = max(0, count)
        if let maxVisible { visible = min(visible, max(0, maxVisible)) }
        if let maxWidth { visible = min(visible, fittingCount(width: maxWidth, diameter: diameter, overlap: overlap)) }
        return visible
    }

    /// Width of `count` avatars of `diameter` overlapping by `overlap`.
    static func width(count: Int, diameter: CGFloat, overlap: CGFloat) -> CGFloat {
        guard count > 0 else { return 0 }
        return diameter + CGFloat(count - 1) * (diameter - overlap)
    }

    /// How many avatars of `diameter` overlapping by `overlap` fit in `width`.
    static func fittingCount(width: CGFloat, diameter: CGFloat, overlap: CGFloat) -> Int {
        guard diameter > 0, width >= diameter else { return 0 }
        let pitch = diameter - overlap
        guard pitch > 0 else { return Int.max }
        var count = Int(((width - diameter) / pitch).rounded(.down)) + 1
        // Floating-point rounding at an exact fit: settle on the largest count whose width fits.
        if Self.width(count: count + 1, diameter: diameter, overlap: overlap) <= width { count += 1 }
        while count > 0, Self.width(count: count, diameter: diameter, overlap: overlap) > width { count -= 1 }
        return count
    }
}

/// Avatars overlapping in a row (album rows, a group's members; C-15): `size.global.avatarSmall` by default,
/// overlapping by `size.global.avatarStackOverlap`. Shows at most `maxVisible` / as many as fit in `maxWidth`, never a
/// count. Decorative: the row that contains it carries the label.
struct AvatarStack: View {
    let sources: [PhotoSource?]
    var diameter: CGFloat = Tokens.Sizes.globalAvatarSmall
    var maxVisible: Int?
    var maxWidth: CGFloat?

    init(sources: [PhotoSource?], diameter: CGFloat = Tokens.Sizes.globalAvatarSmall, maxVisible: Int? = nil, maxWidth: CGFloat? = nil) {
        self.sources = sources
        self.diameter = diameter
        self.maxVisible = maxVisible
        self.maxWidth = maxWidth
    }

    init(paths: [String?], diameter: CGFloat = Tokens.Sizes.globalAvatarSmall, maxVisible: Int? = nil, maxWidth: CGFloat? = nil) {
        self.init(sources: paths.map { $0.map { PhotoSource.storage($0) } }, diameter: diameter, maxVisible: maxVisible, maxWidth: maxWidth)
    }

    var body: some View {
        let shown = AvatarStackLayout.visibleCount(
            count: sources.count, maxVisible: maxVisible, maxWidth: maxWidth,
            diameter: diameter, overlap: Tokens.Sizes.globalAvatarStackOverlap
        )
        HStack(spacing: -Tokens.Sizes.globalAvatarStackOverlap) {
            ForEach(0..<shown, id: \.self) { index in
                AvatarView(source: sources[index], diameter: diameter)
            }
        }
        .accessibilityHidden(true)
    }
}
