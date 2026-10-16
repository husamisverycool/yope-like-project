// Shared screen — Retro's recap preview (ST-04 2026: references/auto/retro/store/retro-store-04.png; TC-REC 2023:
// references/auto/retro/press/tc-2023-12-recaps.png), measured by the capture group as `collage.view.layout.screen` +
// `collage.share.layout.pill` (design/surfaces/collage.view.md, collage.share.md; MERGE_DECISIONS RC-15, RC-19, L-5). One
// implementation on iOS for every surface that shows it (lead decision, Pass 4), as Android's
// `app.ui.recap.RecapPreviewScreen`:
//
//   - collage.view / collage.share (capture): the collage page as the card on page 1 blurred, dots below the page,
//     "Share" pill (`CollageView`);
//   - week.recap (social): memory's `RecapCard` / cover pages, dots below the page, the select-photos thumbnail as
//     `leading`, the "Save as Album" pill (`RecapPillLabel(title:textRole: TextRole.pill)`);
//   - year.story / birthday.tribute (memory): the story cards, the position pill + close as `overlay`, the play / pause
//     circle as `leading`, "Share" as `trailing`; dots on the summary only; tap zones instead of swiping.
//
// API
// ---
// `RecapPreviewScreen(dots:onSelectPage:page:overlay:leading:trailing:)` draws, full screen on
// `color.global.backgroundDeep` in the dark appearance (a media surface — `layout.global.appearance.media`; sheets the
// caller presents from it follow the system; the caller's full-screen cover gives light status-bar content with
// `.preferredColorScheme(.dark)`):
//
//  1. the media page (`RecapPreviewGeometry.frame`): full width, from the safe-area top to
//     `mediaPageBottomFromScreenBottom` (94.8) above the screen bottom, corners `mediaPageCornerRadius` (26.5,
//     continuous), holding `page(geometry)` clipped to it. The caller fills it: a backdrop (C-34 `BlurredBackdrop`, σ
//     `size.global.backdropBlur` under `color.global.backdropDim` — L-5; collage.view's states fill it
//     `color.global.controlOnDeep`) and the card(s) — `RecapPreviewMetrics.cardSize(in:)` gives the collage card's aspect-fit box, `geometry.contentBox`
//     year.story's 9:16 box; a paging `TabView` for swiped pages;
//  2. `overlay(geometry)` on the page in frame coordinates: normally `RecapPreviewClose` (C-11 on media at
//     `closeCentreFromTrailing` (37.7) / `closeCentreBelowPageTop` (38)) and, for year.story, the C-22 position pill on the
//     close circle's centre line (`geometry.closeCentreInFrame`);
//  3. the page dots (C-31 on media: active `color.global.textOnMedia`, inactive `color.global.pageDotInactive` dark) when
//     `dots` is set: `.belowPage` (default) centred `dimension.year.story.dots.offset` (16.1) below the media page — ST-04
//     measures 16.3 there, not on the pill's line (RC-19) — or `.inBottomRow`. VoiceOver reads `dots.accessibilityValue`
//     and adjusts the page through `onSelectPage`; a tap on the dots' trailing half shows the next page, on the leading
//     half the previous one (platform page-control behaviour);
//  4. the bottom row, centred `bottomRowCentreFromScreenBottom` (59.2) above the screen bottom: `leading` and `trailing`
//     at `size.global.buttonMarginH` from the screen edges (`trailing` is normally a `RecapPill`, or a `ShareLink`
//     labelled with `RecapPillLabel` — collage.share.layout.pill: 43.5 high, padding 23, `button` role).
//
// Haptics: none on iOS (close / pill presses: `haptic.global.tap` is none on iOS; page changes are not selections).
// Focus order: the caller's sort priorities (collage: close → page → dots → Share).
// Snapshots: AppTests/Capture/CaptureSnapshotTests `testCollageStates` (light and dark — identical by design); memory's
// year.story and birthday.tribute snapshots.
import DesignSystem
import SwiftUI

// MARK: - Geometry

/// Where the recap preview's parts sit on a full screen (`collage.view.layout.screen`, `collage.share.layout.pill`,
/// `dimension.year.story.dots.offset`). Values are in full-screen coordinates (origin at the screen's top-left) unless
/// named "in frame".
struct RecapPreviewGeometry: Equatable {
    /// The full screen (safe areas included).
    let screen: CGSize
    /// The safe-area top (status bar).
    let safeTop: CGFloat

    private typealias Screen = Tokens.Layouts.CollageViewLayoutScreen

    /// The media page: full width (`mediaPageSideInset`), from the safe-area top to `mediaPageBottomFromScreenBottom`
    /// above the screen bottom.
    var frame: CGRect {
        let top = safeTop
        let bottom = screen.height - Screen.mediaPageBottomFromScreenBottom
        return CGRect(
            x: Screen.mediaPageSideInset, y: top,
            width: max(0, screen.width - 2 * Screen.mediaPageSideInset), height: max(0, bottom - top)
        )
    }

    /// The close circle's centre (`closeCentreFromTrailing`, `closeCentreBelowPageTop`), in frame coordinates.
    var closeCentreInFrame: CGPoint {
        CGPoint(x: frame.width - Screen.closeCentreFromTrailing, y: Screen.closeCentreBelowPageTop)
    }

    /// The page dots' centre line below the page (`dimension.year.story.dots.offset`; RC-19).
    var dotsCentreY: CGFloat { frame.maxY + Tokens.Sizes.yearStoryDotsOffset }

    /// The bottom row's centre line (`bottomRowCentreFromScreenBottom` above the screen bottom).
    var bottomRowCentreY: CGFloat { screen.height - Screen.bottomRowCentreFromScreenBottom }

    /// year.story's 9:16 content box (`layout.year.story.frame` aspectWidth / aspectHeight) as wide as the frame, centred
    /// vertically in it, in frame coordinates.
    var contentBox: CGRect {
        let height = frame.width * Tokens.Layouts.YearStoryFrame.aspectHeight / Tokens.Layouts.YearStoryFrame.aspectWidth
        return CGRect(x: 0, y: (frame.height - height) / 2, width: frame.width, height: height)
    }
}

/// Where the recap preview's page dots sit.
enum RecapDots: Equatable {
    /// Centred `dimension.year.story.dots.offset` below the media page (ST-04; RC-19).
    case belowPage
    /// Centred on the bottom row's centre line (the Pass 2 spec text before RC-19).
    case inBottomRow
}

/// The page dots of the recap preview (C-31 on media).
struct RecapPreviewDots: Equatable {
    let count: Int
    /// 0-based.
    let index: Int
    /// "N of M" from copy (`global.a11y.pagePosition` or the surface's own key).
    let accessibilityValue: String
    var placement: RecapDots = .belowPage

    init(count: Int, index: Int, accessibilityValue: String, placement: RecapDots = .belowPage) {
        self.count = count
        self.index = index
        self.accessibilityValue = accessibilityValue
        self.placement = placement
    }
}

/// The recap preview's measured geometry for its cards (`collage.view.layout.screen` card).
enum RecapPreviewMetrics {
    /// The card inset inside the media page, top and bottom: close-circle centre (38) + `size.global.circleButton` ÷ 2 +
    /// the 20-pt circle → photo gap of `camera.sendto.layout.preview` = 76 pt (`collage.view.layout.screen` card).
    static var cardInsetVertical: CGFloat {
        Tokens.Layouts.CollageViewLayoutScreen.closeCentreBelowPageTop + Tokens.Sizes.globalCircleButton / 2
            + Tokens.Layouts.CameraSendtoLayoutPreview.topBelowHeaderCircle
    }

    /// The collage card: the page image (aspect `collage.view.layout.page.canvasAspect`, 9:16) aspect-fit and centred in
    /// the media page inset `cardInsetVertical` top and bottom (393 × 852: 307 × 546). The spec's "≥ 32 pt at the sides"
    /// (TC-REC, prose only) never binds on a portrait iPhone (the box is height-limited: 43 pt on 393, 75 pt on 375 × 667).
    static func cardSize(in page: CGSize, aspect: CGFloat = Tokens.Layouts.CollageViewLayoutPage.canvasAspect) -> CGSize {
        let height = max(0, page.height - cardInsetVertical * 2)
        let width = min(page.width, height * aspect)
        return CGSize(width: width, height: width / max(aspect, .leastNonzeroMagnitude))
    }
}

// MARK: - Screen

struct RecapPreviewScreen<Page: View, Overlay: View, Leading: View, Trailing: View>: View {
    var dots: RecapPreviewDots?
    var onSelectPage: ((Int) -> Void)?
    @ViewBuilder let page: (RecapPreviewGeometry) -> Page
    @ViewBuilder let overlay: (RecapPreviewGeometry) -> Overlay
    @ViewBuilder let leading: () -> Leading
    @ViewBuilder let trailing: () -> Trailing

    init(
        dots: RecapPreviewDots? = nil,
        onSelectPage: ((Int) -> Void)? = nil,
        @ViewBuilder page: @escaping (RecapPreviewGeometry) -> Page,
        @ViewBuilder overlay: @escaping (RecapPreviewGeometry) -> Overlay,
        @ViewBuilder leading: @escaping () -> Leading,
        @ViewBuilder trailing: @escaping () -> Trailing
    ) {
        self.dots = dots
        self.onSelectPage = onSelectPage
        self.page = page
        self.overlay = overlay
        self.leading = leading
        self.trailing = trailing
    }

    var body: some View {
        GeometryReader { proxy in
            let geometry = RecapPreviewGeometry(
                screen: CGSize(
                    width: proxy.size.width + proxy.safeAreaInsets.leading + proxy.safeAreaInsets.trailing,
                    height: proxy.size.height + proxy.safeAreaInsets.top + proxy.safeAreaInsets.bottom
                ),
                safeTop: proxy.safeAreaInsets.top
            )
            let frame = geometry.frame
            ZStack(alignment: .topLeading) {
                Tokens.Colors.globalBackgroundDeep
                ZStack(alignment: .topLeading) {
                    page(geometry)
                        .frame(width: frame.width, height: frame.height)
                    .clipShape(DSShape.rounded(Tokens.Layouts.CollageViewLayoutScreen.mediaPageCornerRadius))
                    overlay(geometry)
                        .frame(width: frame.width, height: frame.height, alignment: .topLeading)
                }
                .frame(width: frame.width, height: frame.height)
                .offset(x: frame.minX, y: frame.minY)
                if let dots, dots.count > 1 {
                    pageDots(dots)
                        .position(x: geometry.screen.width / 2, y: dots.placement == .belowPage ? geometry.dotsCentreY : geometry.bottomRowCentreY)
                }
                HStack(spacing: 0) {
                    leading()
                    Spacer(minLength: 0)
                    trailing()
                }
                .padding(.horizontal, Tokens.Sizes.globalButtonMarginH)
                .frame(width: geometry.screen.width)
                .position(x: geometry.screen.width / 2, y: geometry.bottomRowCentreY)
            }
            .frame(width: geometry.screen.width, height: geometry.screen.height, alignment: .topLeading)
            .offset(x: -proxy.safeAreaInsets.leading, y: -proxy.safeAreaInsets.top)
        }
        .captureMediaAppearance()
    }

    // MARK: Page dots (C-31 on media)

    private func pageDots(_ dots: RecapPreviewDots) -> some View {
        let dotsWidth = Tokens.Sizes.globalPageDot + CGFloat(max(0, dots.count - 1)) * Tokens.Sizes.globalPageDotPitch
        return PageDots(count: dots.count, index: dots.index, onMedia: true, accessibilityValue: dots.accessibilityValue) { index in
            select(index, in: dots)
        }
        .frame(minHeight: Tokens.Sizes.globalMinTouchTargetIos)
        .contentShape(Rectangle())
        .onTapGesture(coordinateSpace: .local) { location in
            select(location.x >= dotsWidth / 2 ? dots.index + 1 : dots.index - 1, in: dots)
        }
        .accessibilityIdentifier("recap.preview.dots")
    }

    private func select(_ index: Int, in dots: RecapPreviewDots) {
        guard let onSelectPage, (0..<dots.count).contains(index) else { return }
        withDSAnimation(ComponentMotion.crossfade) { onSelectPage(index) }
    }
}

// MARK: - Close circle

/// The recap preview's close circle: C-11 on media (`size.global.circleButton`, `color.global.controlOnDeep`,
/// `icon.global.close` in `color.global.textOnMedia`) centred `closeCentreFromTrailing` / `closeCentreBelowPageTop` in the
/// frame. Retro's '×' is ≈ 9.7 pt with no token: the glyph box is `size.global.iconSmall`, the nearest glyph token
/// (component gap reported) — the same in every recap preview and on the black composer (`CaptureMediaHeader`).
struct RecapPreviewClose: View {
    let geometry: RecapPreviewGeometry
    let accessibilityLabel: String
    let action: () -> Void

    var body: some View {
        CircleButton(
            icon: Tokens.Icons.globalClose, accessibilityLabel: accessibilityLabel, style: .media,
            glyphSize: Tokens.Sizes.globalIconSmall, action: action
        )
        .position(geometry.closeCentreInFrame)
    }
}

// MARK: - Recap pill (C-09 light, recap size)

/// The recap preview's light pill (`collage.share.layout.pill`, ST-04): height 43.5 (a minimum: the label grows with
/// Dynamic Type and never truncates), horizontal padding 23, width hugging the label, `radius.global.capsule`, fill
/// `color.global.surfaceLight`, label in `color.global.onSurfaceLight` — text role `button` (17 semibold: "Share" on
/// collage.share / year.story / birthday.tribute) or `pill` (week.recap's "Save as Album"). Busy: the label is replaced by
/// the platform activity indicator in the label colour (C-05 busy rule), cross-fading over `duration.global.crossfade`;
/// the width stays. For a label inside another control (a `ShareLink`).
struct RecapPillLabel: View {
    let title: String
    var textRole: DSTextStyle = TextRole.button
    var isBusy: Bool = false

    private typealias Pill = Tokens.Layouts.CollageShareLayoutPill

    var body: some View {
        ZStack {
            Text(title)
                .dsTextStyle(textRole)
                .multilineTextAlignment(.center)
                .opacity(isBusy ? 0 : 1)
            if isBusy {
                ProgressView()
                    .tint(Tokens.Colors.globalOnSurfaceLight)
            }
        }
        .dsAnimation(ComponentMotion.crossfade, value: isBusy)
        .foregroundStyle(Tokens.Colors.globalOnSurfaceLight)
        .padding(.horizontal, Pill.paddingHorizontal)
        .frame(minHeight: Pill.height)
        .background(Tokens.Colors.globalSurfaceLight, in: Capsule())
        .contentShape(Capsule())
    }
}

/// The name memory's screens use for the "Share" pill label.
typealias RecapSharePillLabel = RecapPillLabel

/// `RecapPillLabel` as a button (accessibility: button labelled with the visible text; busy announced as updating).
struct RecapPill: View {
    let title: String
    var textRole: DSTextStyle = TextRole.button
    var isBusy: Bool = false
    let action: () -> Void

    init(_ title: String, textRole: DSTextStyle = TextRole.button, isBusy: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.textRole = textRole
        self.isBusy = isBusy
        self.action = action
    }

    var body: some View {
        Button {
            guard !isBusy else { return }
            action()
        } label: {
            RecapPillLabel(title: title, textRole: textRole, isBusy: isBusy)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(title))
        .accessibilityAddTraits(isBusy ? .updatesFrequently : [])
    }
}
