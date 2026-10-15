// Shared component — images from the private `media` bucket, and avatars.
import DesignSystem
import SwiftUI

/// Turns a storage path (`avatars/<uid>/…`, `u/<uid>/<media>/…`) into a short-lived signed URL
/// (docs/API.md §7). The app shell injects one backed by AppData's `SignedURLCache`.
typealias StorageURLResolver = @MainActor @Sendable (String) async throws -> URL

private struct StorageURLResolverKey: EnvironmentKey {
    static let defaultValue: StorageURLResolver? = nil
}

extension EnvironmentValues {
    /// Resolves storage paths for `StorageImage` / `AvatarView`. Nil (previews, snapshots): placeholders are shown.
    var storageURLResolver: StorageURLResolver? {
        get { self[StorageURLResolverKey.self] }
        set { self[StorageURLResolverKey.self] = newValue }
    }
}

/// An image from the private bucket, loaded through a signed URL, filling its frame (`contentMode`) or showing
/// `placeholder` until it has loaded (and when the path is nil or unreadable). Callers size and clip it.
struct StorageImage<Placeholder: View>: View {
    let path: String?
    var contentMode: ContentMode = .fill
    @ViewBuilder var placeholder: () -> Placeholder

    @Environment(\.storageURLResolver) private var resolver
    @State private var url: URL?

    init(path: String?, contentMode: ContentMode = .fill, @ViewBuilder placeholder: @escaping () -> Placeholder) {
        self.path = path
        self.contentMode = contentMode
        self.placeholder = placeholder
    }

    var body: some View {
        AsyncImage(url: url) { phase in
            if let image = phase.image {
                image.resizable().aspectRatio(contentMode: contentMode)
            } else {
                placeholder()
            }
        }
        .task(id: path) {
            url = nil
            guard let path, let resolver else { return }
            url = try? await resolver(path)
        }
    }
}

/// A circular avatar.
///
/// Shows, in order of preference: a local image (just picked), the image at `path` (signed URL), else the default
/// look — a `color.global.controlRaised` circle with `placeholderIcon` (`icon.global.person` for people,
/// `icon.global.group` for groups) in `color.global.textSecondary` (`auth.profile.layout.avatarPicker`,
/// groups.list avatar). The glyph is drawn at the platform's default symbol size (its size was not measured).
/// Decorative by default: callers label the control that contains it.
struct AvatarView: View {
    var path: String?
    var localImage: Image?
    let diameter: CGFloat
    var placeholderIcon: String = Tokens.Icons.globalPerson

    var body: some View {
        Group {
            if let localImage {
                localImage.resizable().aspectRatio(contentMode: .fill)
            } else if path != nil {
                StorageImage(path: path) { fallback }
            } else {
                fallback
            }
        }
        .frame(width: diameter, height: diameter)
        .clipShape(Circle())
        .accessibilityHidden(true)
    }

    private var fallback: some View {
        ZStack {
            Circle().fill(Tokens.Colors.globalControlRaised)
            Image(systemName: placeholderIcon)
                .foregroundStyle(Tokens.Colors.globalTextSecondary)
        }
    }
}

/// Avatars overlapping in a row (group profile members row; `size.global.avatarSmall`). No count is ever shown.
/// The overlap is the platform's negative stack spacing of a quarter diameter — **approximation** (not measured).
struct AvatarStack: View {
    let paths: [String?]
    var diameter: CGFloat = Tokens.Sizes.globalAvatarSmall

    var body: some View {
        HStack(spacing: -diameter / 4) {
            ForEach(Array(paths.enumerated()), id: \.offset) { _, path in
                AvatarView(path: path, diameter: diameter)
            }
        }
    }
}
