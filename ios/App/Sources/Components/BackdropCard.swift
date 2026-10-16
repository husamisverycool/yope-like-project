// Shared component — C-34 card on a blurred backdrop (recap card, plan card) (design/components.md). Evidence: TC-REC
// phones 2–3, ST-04, TC-H, PAY (card x60–1144 y1386–2456; TL corner); RV §3.4, §3.5, §3.7, §4 #23.
import DesignSystem
import SwiftUI

/// A full-screen, colour-rich blurred version of `backdrop` (`layout.global.materials.backdrop`) with a card centred on
/// it: fill `color.global.surfaceElevated` (#FFFFFF / #181818; the paywall's iOS card is translucent, alpha not
/// derivable — Gap — so the APK's opaque value is used), corners `cornerRadius` (continuous), padding `padding`, width =
/// screen − 2 × `size.global.buttonMarginH`. Below the card, `below` (page dots C-31 and a light pill C-09 on the recap
/// preview; the plan pager on the paywall). The close circle (C-11 `.glassSmall`) is the caller's.
///
/// - Plan card (defaults): `radius.global.cardLarge`, `size.global.planCardPadding`; its capsule (C-05 `.media` or
///   `.page`) sits 16 pt from the card sides and bottom (`size.global.screenMargin` — no token of its own, Gap).
/// - Recap card: Retro's corner (≈4.5–5 % of the card width) has no token (Gap — one lossless share-image export); pass
///   the recap surface's radius.
///
/// The backdrop is the photo with a mild Gaussian blur (`size.global.backdropBlur`, σ 1.8 pt) under a black layer
/// (`color.global.backdropDim`, 22 %), both fitted on ST-04 (MERGE_DECISIONS L-5): not a frosted material.
/// Accessibility: the backdrop is decorative; the card's content reads in order.
struct BackdropCard<Content: View, Below: View>: View {
    let backdrop: PhotoSource?
    var cornerRadius: CGFloat
    var padding: CGFloat
    @ViewBuilder let content: () -> Content
    @ViewBuilder let below: () -> Below

    init(
        backdrop: PhotoSource?,
        cornerRadius: CGFloat = Tokens.Radii.globalCardLarge,
        padding: CGFloat = Tokens.Sizes.globalPlanCardPadding,
        @ViewBuilder content: @escaping () -> Content,
        @ViewBuilder below: @escaping () -> Below
    ) {
        self.backdrop = backdrop
        self.cornerRadius = cornerRadius
        self.padding = padding
        self.content = content
        self.below = below
    }

    var body: some View {
        ZStack {
            BlurredBackdrop(source: backdrop)
            VStack {
                content()
                    .padding(padding)
                    .frame(maxWidth: .infinity)
                    .background(Tokens.Colors.globalSurfaceElevated, in: DSShape.rounded(cornerRadius))
                    .padding(.horizontal, Tokens.Sizes.globalButtonMarginH)
                below()
            }
        }
    }
}

extension BackdropCard where Below == EmptyView {
    init(
        backdrop: PhotoSource?,
        cornerRadius: CGFloat = Tokens.Radii.globalCardLarge,
        padding: CGFloat = Tokens.Sizes.globalPlanCardPadding,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.init(backdrop: backdrop, cornerRadius: cornerRadius, padding: padding, content: content) { EmptyView() }
    }
}

/// The full-screen blurred photo behind a C-34 card (on `color.global.backgroundDeep` while it loads).
struct BlurredBackdrop: View {
    let source: PhotoSource?

    var body: some View {
        ZStack {
            Tokens.Colors.globalBackgroundDeep
            PhotoView(source: source)
                .blur(radius: Tokens.Sizes.globalBackdropBlur, opaque: true)
            Tokens.Colors.globalBackdropDim
        }
        .clipped()
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

/// A photo blurred to a colour field (`layout.global.colourFieldBackdrop`, MERGE L-9): aspect-filled, extended
/// `bleedSigmas` σ past the frame so the blur has no faded edge, Gaussian-blurred at σ = `sigmaToWidth` × the frame
/// width, under `color.global.backdropDim`; `color.global.backgroundDeep` while it loads. Used where Retro shows a
/// structure-free wash (paywall, invite card) — not the recap's mild blur (`BlurredBackdrop`, L-5).
struct ColourFieldBackdrop: View {
    let source: PhotoSource?
    var sigmaToWidth: CGFloat = Tokens.Layouts.GlobalColourFieldBackdrop.blurSigmaToWidth

    var body: some View {
        GeometryReader { proxy in
            let sigma = proxy.size.width * sigmaToWidth
            let bleed = sigma * Tokens.Layouts.GlobalColourFieldBackdrop.bleedSigmas
            ZStack {
                Tokens.Colors.globalBackgroundDeep
                PhotoView(source: source)
                    .frame(width: proxy.size.width + bleed * 2, height: proxy.size.height + bleed * 2)
                    .blur(radius: sigma)
                    .frame(width: proxy.size.width, height: proxy.size.height)
                Tokens.Colors.globalBackdropDim
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}
