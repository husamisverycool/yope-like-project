// Social group — parts drawn on photos: the caption box (chat.thread, photo.viewer) and the grid tiles of walls /
// week / albums. The "i'm in this" toggle is the memory group's `SelfTagToggleControl` (design/surfaces/tagging.md).
import AppData
import AppModels
import DesignSystem
import SwiftUI

/// Caption box on a photo (`chat.thread` "On a photo message" 2; `photo.viewer` caption): height
/// `chat.thread.dimension.captionHeight` (minimum), padding `chat.thread.dimension.captionPaddingH`, corners
/// `chat.thread.radius.caption`, text `chat.thread.fontSize.caption` / `.fontWeight.caption` in
/// `color.global.textPrimary`. Fill `color.global.scrim`.
struct PhotoCaption: View {
    let text: String
    /// Thread: one line, tail truncation (S-8). Viewer: long captions wrap.
    var wraps = false

    var body: some View {
        Text(text)
            .dsTextStyle(SocialText.caption)
            .foregroundStyle(Tokens.Colors.globalTextPrimary)
            .lineLimit(wraps ? nil : 1)
            .truncationMode(.tail)
            .multilineTextAlignment(.center)
            .padding(.horizontal, Tokens.Sizes.chatThreadDimensionCaptionPaddingH)
            .frame(minHeight: Tokens.Sizes.chatThreadDimensionCaptionHeight)
            .background(Tokens.Colors.globalScrim, in: RoundedRectangle(cornerRadius: Tokens.Radii.chatThreadRadiusCaption))
            .accessibilityHidden(true)
    }
}

/// A photo tile in a grid: aspect fill in a frame of the grid's tile shape, with the grid's corners.
struct PhotoGridTile: View {
    let path: String?
    let aspectRatio: CGFloat
    var cornerRadius: CGFloat = 0
    /// Longest side of the tile in pixels (thumbnail decode size).
    var maxPixel: Int?

    var body: some View {
        SocialPhoto(path: path, maxPixel: maxPixel)
            .aspectRatio(aspectRatio, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .contentShape(RoundedRectangle(cornerRadius: cornerRadius))
    }
}

/// Grid columns sized from a container width (for thumbnail decode sizes and tile frames).
enum SocialGrid {
    static func tileWidth(container: CGFloat, columns: CGFloat, inset: CGFloat, gap: CGFloat) -> CGFloat {
        max(0, (container - inset * 2 - gap * (columns - 1)) / columns)
    }

    static func maxPixel(width: CGFloat, aspectRatio: CGFloat, scale: CGFloat) -> Int {
        Int((max(width, width / max(aspectRatio, .leastNonzeroMagnitude)) * scale).rounded(.up))
    }
}
