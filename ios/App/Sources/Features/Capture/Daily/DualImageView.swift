// Surface: daily.dualimage — reference app: BeReal.
// Reference images: references/auto/bereal/help/help-21083730354333_feed-bonus-3x.png,
// help-21083708285725_bts-post-preview-2x.png, references/auto/bereal/frames/appstore-preview-2026_t6.80s_feed.png
// (design/surfaces/daily.dualimage.md).
// How the back and front photos of one answer are shown together. Every value is a ratio of the
// main image width W (`daily.dualimage.layout.composition`), so the component scales. Used by the
// daily-capture preview; the chat thread and photo viewer may place it for posts with a front photo.
import DesignSystem
import SwiftUI
import UIKit

struct DualImageView: View {
    /// The back photo (or the photo of the camera that was live); nil while loading.
    let main: UIImage?
    /// The front photo; nil for a single-camera answer.
    let inset: UIImage?
    let accessibilityLabel: String

    private typealias Composition = Tokens.Layouts.DailyDualimageLayoutComposition

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let insetOuterWidth = Composition.insetWidthRatio * width
            let insetOuterHeight = insetOuterWidth / Composition.insetAspect
            let border = Composition.insetBorderRatio * width
            let outerRadius = Composition.insetOuterRadiusRatio * insetOuterWidth
            let margin = Composition.insetMarginRatio * width
            ZStack(alignment: .topLeading) {
                Tokens.Colors.globalBackgroundDeep
                if let main {
                    Image(uiImage: main)
                        .resizable()
                        .scaledToFill()
                        .frame(width: width, height: proxy.size.height)
                        .clipped()
                }
                if let inset {
                    // The border is drawn outside the photo in `color.global.backgroundDeep`.
                    Image(uiImage: inset)
                        .resizable()
                        .scaledToFill()
                        .frame(width: insetOuterWidth - border * 2, height: insetOuterHeight - border * 2)
                        .clipShape(RoundedRectangle(cornerRadius: max(0, outerRadius - border), style: .continuous))
                        .padding(border)
                        .background(Tokens.Colors.globalBackgroundDeep, in: RoundedRectangle(cornerRadius: outerRadius, style: .continuous))
                        .offset(x: margin, y: margin)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: Composition.mainRadiusRatio * width, style: .continuous))
        }
        .aspectRatio(Composition.mainAspect, contentMode: .fit)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(.isImage)
    }
}
