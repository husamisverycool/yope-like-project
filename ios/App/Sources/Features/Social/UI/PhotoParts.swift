// Social group — parts drawn on photos: the caption box (chat.thread, photo.viewer), the "i'm in this" toggle and
// its coach (design/surfaces/tagging.md; placed by photo.viewer), and the grid tiles of walls / week / albums.
import AppData
import AppModels
import DesignSystem
import SwiftUI

/// Caption box on a photo (`chat.thread` "On a photo message" 2; `photo.viewer` caption): height
/// `chat.thread.dimension.captionHeight` (minimum), padding `chat.thread.dimension.captionPaddingH`, corners
/// `chat.thread.radius.caption`, text `chat.thread.fontSize.caption` / `.fontWeight.caption` in
/// `color.global.textPrimary`. Its fill `color.global.scrim` is BLOCKED: the box is drawn without a fill.
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
            .clipShape(RoundedRectangle(cornerRadius: Tokens.Radii.chatThreadRadiusCaption))
            .accessibilityHidden(true)
    }
}

/// "i'm in this" (`tagging`): white capsule (`color.global.surfaceLight`), state glyph `size.global.checkCircle`
/// (off `icon.global.uncheck` in `color.global.onSurfaceLight`, on `icon.global.check` in `color.global.selection`),
/// gap `size.global.headerGap`, label `tagging.toggle` in text role `button`, `color.global.onSurfaceLight`. Height
/// `size.global.minTouchTarget.ios` (the touch target); the glyph sits centred in a touch-target circle at the
/// capsule's start and the label ends the same distance from the trailing edge (the inner padding was not measured).
/// Glyph swap without animation; `haptic.global.select` comes from the model.
struct TagToggle: View {
    let isOn: Bool
    let isPending: Bool
    let action: () -> Void

    private var inset: CGFloat { (Tokens.Sizes.globalMinTouchTargetIos - Tokens.Sizes.globalCheckCircle) / 2 }

    var body: some View {
        Button(action: action) {
            HStack(spacing: Tokens.Sizes.globalHeaderGap) {
                Image(systemName: isOn ? Tokens.Icons.globalCheck : Tokens.Icons.globalUncheck)
                    .resizable()
                    .scaledToFit()
                    .frame(width: Tokens.Sizes.globalCheckCircle, height: Tokens.Sizes.globalCheckCircle)
                    .foregroundStyle(isOn ? Tokens.Colors.globalSelection : Tokens.Colors.globalOnSurfaceLight)
                Text(Copy.taggingToggle)
                    .dsTextStyle(TextRole.button)
                    .foregroundStyle(Tokens.Colors.globalOnSurfaceLight)
            }
            .padding(.horizontal, inset)
            .frame(minHeight: Tokens.Sizes.globalMinTouchTargetIos)
            .background(Tokens.Colors.globalSurfaceLight, in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .allowsHitTesting(!isPending)
        .accessibilityLabel(Text(Copy.taggingToggle))
        .accessibilityAddTraits(isOn ? .isSelected : [])
        .accessibilityIdentifier("tagging.toggle") // provenance-ok: accessibility identifier for UI tests
    }
}

/// The foundations coach tooltip (`camera.capture.layout.coach`): lime pill (`color.global.accent`) with its pointer
/// up towards the target, text in `color.global.onAccent` (`camera.capture.fontSize.coach`), ✕ dismisses for good.
struct CoachTooltip: View {
    let text: String
    let onClose: () -> Void

    private typealias Coach = Tokens.Layouts.CameraCaptureLayoutCoach

    var body: some View {
        VStack(alignment: .trailing, spacing: 0) {
            PointerUp()
                .fill(Tokens.Colors.globalAccent)
                .frame(width: Coach.pointerWidth, height: Coach.pointerHeight)
                .padding(.trailing, Coach.paddingHorizontal)
            HStack(spacing: Coach.textToCloseGap) {
                Text(text)
                    .dsTextStyle(SocialText.coach)
                Button(action: onClose) {
                    Image(systemName: Tokens.Icons.globalClose)
                        .resizable()
                        .scaledToFit()
                        .frame(width: Coach.closeGlyph, height: Coach.closeGlyph)
                        .socialMinimumHitArea()
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(Copy.cameraCaptureA11yClose))
            }
            .foregroundStyle(Tokens.Colors.globalOnAccent)
            .padding(.leading, Coach.paddingHorizontal)
            .frame(minHeight: Coach.height)
            .background(Tokens.Colors.globalAccent, in: RoundedRectangle(cornerRadius: Coach.cornerRadius))
        }
        .padding(.top, Coach.pointerToTarget)
        .accessibilityElement(children: .contain)
    }
}

/// The coach's pointer triangle (apex up).
struct PointerUp: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.midX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.closeSubpath()
        }
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
