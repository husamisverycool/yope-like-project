// Surface: daily.dualimage — mechanics BeReal (dual image), visual reference Retro photo treatment (the outer shape is
// the host container's; the only colour is Retro's media black).
// Reference images: references/auto/bereal/help/help-21083730354333_feed-bonus-3x.png (inset size, margin, border,
// corners), references/auto/bereal/help/help-21083708285725_bts-post-preview-2x.png (3:4, 2-pt border),
// references/auto/retro/store/retro-store-01.png and references/auto/retro/press/tc-2023-07-retro-2b.jpg phone 2 (Retro
// hosts: card corners 18, viewer full width corners 0) (design/surfaces/daily.dualimage.md; RC-13).
// How the back and front photos of one answer are shown together. Every value is a ratio of the main image width W
// (`daily.dualimage.layout.composition`; the worker composes collage tiles with the same token), so it scales. Used by
// the daily-capture preview, the photo viewer (social) and any host that places a post with a front photo.
import DesignSystem
import SwiftUI
import UIKit

struct DualImageView: View {
    /// The outer corners: the host container's shape (daily.dualimage Structure 1).
    enum Corners: Equatable {
        /// The host's corner radius: `radius.global.viewfinder` (18) in daily.capture, `radius.global.photo` (0) in the
        /// viewer, `radius.global.card` (18) on cards.
        case host(CGFloat)
        /// The token's own `mainRadiusRatio` × W (≈ 18 pt at 393), only where the host draws no shape of its own.
        case composition
    }

    /// The back photo (or the photo of the camera that was live); nil while loading.
    let main: UIImage?
    /// The front photo; nil for a single-camera answer.
    let inset: UIImage?
    let accessibilityLabel: String
    var corners: Corners = .host(Tokens.Radii.globalPhoto)
    /// The loading fill: `color.global.backgroundDeep` on media hosts, `color.global.control` (Retro's placeholder tile)
    /// on page hosts.
    var onMedia: Bool = true

    init(main: UIImage?, inset: UIImage?, accessibilityLabel: String, corners: Corners = .host(Tokens.Radii.globalPhoto), onMedia: Bool = true) {
        self.main = main
        self.inset = inset
        self.accessibilityLabel = accessibilityLabel
        self.corners = corners
        self.onMedia = onMedia
    }

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
                onMedia ? Tokens.Colors.globalBackgroundDeep : Tokens.Colors.globalControl
                if let main {
                    Image(uiImage: main)
                        .resizable()
                        .scaledToFill()
                        .frame(width: width, height: proxy.size.height)
                        .clipped()
                        .dsTransition(.opacity)
                }
                if let inset {
                    // The border is drawn outside the photo in `color.global.backgroundDeep`.
                    Image(uiImage: inset)
                        .resizable()
                        .scaledToFill()
                        .frame(width: insetOuterWidth - border * 2, height: insetOuterHeight - border * 2)
                        .clipShape(DSShape.rounded(max(0, outerRadius - border)))
                        .padding(border)
                        .background(Tokens.Colors.globalBackgroundDeep, in: DSShape.rounded(outerRadius))
                        .offset(x: margin, y: margin)
                        .dsTransition(.opacity)
                }
            }
            .dsAnimation(ComponentMotion.fade, value: main != nil)
            .clipShape(DSShape.rounded(cornerRadius(width: width)))
        }
        .aspectRatio(Composition.mainAspect, contentMode: .fit)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(accessibilityLabel))
        .accessibilityAddTraits(.isImage)
    }

    private func cornerRadius(width: CGFloat) -> CGFloat {
        switch corners {
        case let .host(radius): return radius
        case .composition: return Composition.mainRadiusRatio * width
        }
    }
}
