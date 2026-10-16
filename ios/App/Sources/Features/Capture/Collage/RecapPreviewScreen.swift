// Shared screen — Retro's recap preview (ST-04 2026: references/auto/retro/store/retro-store-04.png; TC-REC 2023:
// references/auto/retro/press/tc-2023-12-recaps.png), measured by the capture group as `collage.view.layout.screen` +
// `collage.share.layout.pill` (design/surfaces/collage.view.md, collage.share.md; MERGE_DECISIONS RC-15, RC-19). One
// implementation on iOS for every surface that shows it (lead decision, Pass 4), as Android's
// `app.ui.recap.RecapPreviewScreen`:
//
//   - collage.view / collage.share (capture): the collage page as the card, dots below the page, "Share" pill;
//   - week.recap (social): memory's recap card / cover pages, dots below the page, the select-photos thumbnail as the
//     bottom-leading item, the "Save as Album" pill (text role `pill`);
//   - year.story / birthday.tribute (memory): the story cards, the position pill top-leading, the play / pause circle
//     bottom-leading, "Share"; dots below the page on the summary only; tap zones instead of swiping
//     (`swipeEnabled: false`).
//
// API
// ---
// `RecapPreviewScreen(backdrop:pageCount:currentPage:swipeEnabled:dots:dotsAccessibilityValue:closeAccessibilityLabel:
// onClose:page:topLeading:bottomLeading:pill:)` draws, on `color.global.backgroundDeep` and in the dark appearance (a
// media surface — `layout.global.appearance.media`; sheets the caller presents from it follow the system):
//
//  1. the media page: full width, from the safe-area top to `mediaPageBottomFromScreenBottom` (94.8) above the screen
//     bottom, corners `mediaPageCornerRadius` (26.5, continuous), content clipped. Inside it `backdrop` blurred
//     full-bleed (C-34 `BlurredBackdrop`: σ `size.global.backdropBlur` under `color.global.backdropDim`, L-5); with no
//     backdrop the page is `color.global.controlOnDeep` (collage.view loading / empty / error);
//  2. the pages: `page(index)` fills the media page; the caller lays its card out in it (`RecapPreviewMetrics.cardFrame`
//     gives the collage card's aspect-fit box). With `pageCount` > 1 and `swipeEnabled` the pages sit in a paging
//     `TabView` (finger-tracked, platform settle; index display hidden); `currentPage` (0-based) stays in sync both ways;
//  3. the close circle (C-11 on media: 36, #262626, `icon.global.close`), centre `closeCentreFromTrailing` (37.7) from
//     the trailing edge and `closeCentreBelowPageTop` (38) below the page top; label `closeAccessibilityLabel` (copy);
//  4. `topLeading` (year.story's C-22 position pill), centred on the close circle's centre line at the page's leading
//     edge — the caller gives it its own leading padding;
//  5. the bottom row, centred `bottomRowCentreFromScreenBottom` (59.2) above the screen bottom: `bottomLeading` at the
//     leading edge (the caller pads it, normally `size.global.buttonMarginH`) and `pill` with its trailing edge at
//     `size.global.buttonMarginH` (normally a `RecapPill`, or a `ShareLink` labelled with `RecapPillLabel`);
//  6. the page dots (C-31 on media: active `color.global.textOnMedia`, inactive `color.global.pageDotInactive` dark) only
//     with 2+ pages: `.belowPage` (default) centred `dimension.year.story.dots.offset` (16.1) below the media page — ST-04
//     measures 16.3 there, not on the pill's line (RC-19) — or `.inBottomRow` / `.hidden`. VoiceOver reads
//     `dotsAccessibilityValue(index, count)` (default `global.a11y.pagePosition`, "2 of 3") and adjusts the page; a tap on
//     the dots' trailing half shows the next page, on the leading half the previous one (platform page-control behaviour).
//
// Status bar: the caller's presentation (a full-screen cover with `.preferredColorScheme(.dark)` gives light content).
// Haptics: none on iOS (close / pill presses: `haptic.global.tap` is none on iOS; page changes are not selections).
// Focus order: close → top-leading → page → dots → bottom-leading → pill.
// Snapshots: AppTests/Capture/CaptureSnapshotTests `testCollageStates` (light and dark — identical by design).
import DesignSystem
import SwiftUI

/// Where the recap preview's page dots sit.
enum RecapDots: Equatable {
    /// Centred `dimension.year.story.dots.offset` below the media page (ST-04; RC-19).
    case belowPage
    /// Centred on the bottom row's centre line (the Pass 2 spec text before RC-19).
    case inBottomRow
    case hidden
}

/// The recap preview's measured geometry (`collage.view.layout.screen`, `collage.share.layout.pill`).
enum RecapPreviewMetrics {
    typealias Screen = Tokens.Layouts.CollageViewLayoutScreen

    /// The card inset inside the media page, top and bottom: close-circle centre (38) + `size.global.circleButton` ÷ 2 +
    /// the 20-pt circle → photo gap of `camera.sendto.layout.preview` = 76 pt (`collage.view.layout.screen` card).
    static var cardInsetVertical: CGFloat {
        Screen.closeCentreBelowPageTop + Tokens.Sizes.globalCircleButton / 2 + Tokens.Layouts.CameraSendtoLayoutPreview.topBelowHeaderCircle
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

struct RecapPreviewScreen<Page: View, TopLeading: View, BottomLeading: View, Pill: View>: View {
    let backdrop: PhotoSource?
    let pageCount: Int
    @Binding var currentPage: Int
    var swipeEnabled: Bool
    var dots: RecapDots
    var dotsAccessibilityValue: (Int, Int) -> String
    let closeAccessibilityLabel: String
    let onClose: () -> Void
    @ViewBuilder let page: (Int) -> Page
    @ViewBuilder let topLeading: () -> TopLeading
    @ViewBuilder let bottomLeading: () -> BottomLeading
    @ViewBuilder let pill: () -> Pill

    init(
        backdrop: PhotoSource?,
        pageCount: Int,
        currentPage: Binding<Int>,
        swipeEnabled: Bool = true,
        dots: RecapDots = .belowPage,
        dotsAccessibilityValue: @escaping (Int, Int) -> String = RecapPreviewDefaults.pagePosition,
        closeAccessibilityLabel: String,
        onClose: @escaping () -> Void,
        @ViewBuilder page: @escaping (Int) -> Page,
        @ViewBuilder topLeading: @escaping () -> TopLeading,
        @ViewBuilder bottomLeading: @escaping () -> BottomLeading,
        @ViewBuilder pill: @escaping () -> Pill
    ) {
        self.backdrop = backdrop
        self.pageCount = pageCount
        _currentPage = currentPage
        self.swipeEnabled = swipeEnabled
        self.dots = dots
        self.dotsAccessibilityValue = dotsAccessibilityValue
        self.closeAccessibilityLabel = closeAccessibilityLabel
        self.onClose = onClose
        self.page = page
        self.topLeading = topLeading
        self.bottomLeading = bottomLeading
        self.pill = pill
    }

    private typealias Screen = RecapPreviewMetrics.Screen

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let safeTop = proxy.safeAreaInsets.top
            let screenHeight = proxy.size.height
            let pageBottom = screenHeight - Screen.mediaPageBottomFromScreenBottom
            let pageHeight = max(0, pageBottom - safeTop)
            let closeCentreY = safeTop + Screen.closeCentreBelowPageTop
            let rowCentreY = screenHeight - Screen.bottomRowCentreFromScreenBottom
            ZStack(alignment: .topLeading) {
                Tokens.Colors.globalBackgroundDeep
                mediaPage
                    .frame(width: width, height: pageHeight)
                    .clipShape(DSShape.rounded(Screen.mediaPageCornerRadius))
                    .offset(y: safeTop)
                    .accessibilitySortPriority(4)
                topLeading()
                    .frame(width: width, alignment: .leading)
                    .position(x: width / 2, y: closeCentreY)
                    .accessibilitySortPriority(5)
                CircleButton(icon: Tokens.Icons.globalClose, accessibilityLabel: closeAccessibilityLabel, style: .media, action: onClose)
                    .position(x: width - Screen.closeCentreFromTrailing, y: closeCentreY)
                    .accessibilitySortPriority(6)
                    .accessibilityIdentifier("recap.preview.close")
                if pageCount > 1 && dots != .hidden {
                    pageDots
                        .position(x: width / 2, y: dots == .belowPage ? pageBottom + Tokens.Sizes.yearStoryDotsOffset : rowCentreY)
                        .accessibilitySortPriority(3)
                }
                HStack(spacing: 0) {
                    bottomLeading()
                        .accessibilitySortPriority(2)
                    Spacer(minLength: 0)
                    pill()
                        .accessibilitySortPriority(1)
                        .padding(.trailing, Tokens.Sizes.globalButtonMarginH)
                }
                .frame(width: width)
                .position(x: width / 2, y: rowCentreY)
            }
            .accessibilityElement(children: .contain)
        }
        .ignoresSafeArea()
        .captureMediaAppearance()
    }

    // MARK: Media page

    private var mediaPage: some View {
        ZStack {
            Tokens.Colors.globalControlOnDeep
            if let backdrop {
                // C-34 backdrop (`layout.global.materials.backdrop`; MERGE_DECISIONS L-5): the photo blurred σ
                // `size.global.backdropBlur` under `color.global.backdropDim`, clipped to the media page.
                BlurredBackdrop(source: backdrop)
            }
            pages
        }
    }

    @ViewBuilder
    private var pages: some View {
        if pageCount > 1 && swipeEnabled {
            TabView(selection: $currentPage) {
                ForEach(0..<pageCount, id: \.self) { index in
                    page(index)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        } else {
            page(min(max(0, currentPage), max(0, pageCount - 1)))
        }
    }

    // MARK: Page dots (C-31 on media)

    private var pageDots: some View {
        let dotsWidth = Tokens.Sizes.globalPageDot + CGFloat(max(0, pageCount - 1)) * Tokens.Sizes.globalPageDotPitch
        return PageDots(
            count: pageCount,
            index: currentPage,
            onMedia: true,
            accessibilityValue: dotsAccessibilityValue(currentPage, pageCount)
        ) { index in
            select(index)
        }
        .frame(minHeight: Tokens.Sizes.globalMinTouchTargetIos)
        .contentShape(Rectangle())
        .onTapGesture(coordinateSpace: .local) { location in
            select(location.x >= dotsWidth / 2 ? currentPage + 1 : currentPage - 1)
        }
        .accessibilityIdentifier("recap.preview.dots")
    }

    private func select(_ index: Int) {
        guard (0..<pageCount).contains(index) else { return }
        withDSAnimation(ComponentMotion.crossfade) { currentPage = index }
    }
}

extension RecapPreviewScreen where TopLeading == EmptyView, BottomLeading == EmptyView {
    /// No top-leading item and no bottom-leading item (collage.view).
    init(
        backdrop: PhotoSource?,
        pageCount: Int,
        currentPage: Binding<Int>,
        swipeEnabled: Bool = true,
        dots: RecapDots = .belowPage,
        dotsAccessibilityValue: @escaping (Int, Int) -> String = RecapPreviewDefaults.pagePosition,
        closeAccessibilityLabel: String,
        onClose: @escaping () -> Void,
        @ViewBuilder page: @escaping (Int) -> Page,
        @ViewBuilder pill: @escaping () -> Pill
    ) {
        self.init(
            backdrop: backdrop, pageCount: pageCount, currentPage: currentPage, swipeEnabled: swipeEnabled, dots: dots,
            dotsAccessibilityValue: dotsAccessibilityValue, closeAccessibilityLabel: closeAccessibilityLabel, onClose: onClose,
            page: page, topLeading: { EmptyView() }, bottomLeading: { EmptyView() }, pill: pill
        )
    }
}

enum RecapPreviewDefaults {
    /// `global.a11y.pagePosition` ("2 of 3") for a 0-based index.
    static func pagePosition(_ index: Int, _ count: Int) -> String {
        Copy.globalA11yPagePosition(position: String(index + 1), count: String(count))
    }
}

// MARK: - Recap pill (C-09 light, recap size)

/// The recap preview's light pill (`collage.share.layout.pill`, ST-04): height 43.5 (a minimum: the label grows with
/// Dynamic Type and never truncates), horizontal padding 23, width hugging the label, `radius.global.capsule`, fill
/// `color.global.surfaceLight`, label in `color.global.onSurfaceLight` — text role `button` (17 semibold: "Share" on
/// collage.share / year.story) or `pill` (week.recap's "Save as Album"). Busy: the label is replaced by the platform
/// activity indicator in the label colour (C-05 busy rule), cross-fading over `duration.global.crossfade`; the width
/// stays. For a label inside another control (a `ShareLink`).
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
