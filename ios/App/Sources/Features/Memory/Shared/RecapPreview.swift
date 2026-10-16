// Retro's recap preview and recap card, shared by year.story and birthday.tribute (memory) and week.recap (social)
// (MERGE RM-8, lead notes L-4). Evidence: `references/auto/retro/store/retro-store-04.png` (2026 recap preview: full-width
// media page with 26.5 corners, close #262626 top-right, page dots, white 'Share' pill at the trailing margin, row centre
// 59.2 above the bottom) and `references/auto/retro/press/tc-2023-12-recaps.png` phones 2–3 (the recap card: white, 4 × 6
// grid, '2023' serif footer; the full-bleed style). Components: C-34 (card on a blurred backdrop), C-31, C-11, C-09, C-35.
//
// The chrome's values are the capture group's (`collage.view.layout.screen`, `collage.share.layout.pill`); capture owns
// the collage.view screen. This file is the memory group's one composition of that chrome — swap `RecapPreviewScreen`
// for capture's shared view when it exists (Features/Capture/Collage); the recap card (`layout.year.story.recapCard`,
// white in both appearances) is memory's and is used as is by week.recap:
//
//     RecapCard(photos: cells, title: Copy.photoViewerHeaderWeek(number: …), name: groupName, detail: range,
//               frameWidth: frame.width) { cell in open(cell) }
import DesignSystem
import SwiftUI

// MARK: - Geometry

/// Where the recap preview's parts sit on a full screen (`collage.view.layout.screen`, `collage.share.layout.pill`,
/// `dimension.year.story.dots.offset`). All values are in full-screen coordinates (origin at the screen's top-left).
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

    /// The page dots' centre line (`dimension.year.story.dots.offset` below the frame).
    var dotsCentreY: CGFloat { frame.maxY + Tokens.Sizes.yearStoryDotsOffset }

    /// The bottom row's centre line (`bottomRowCentreFromScreenBottom` above the screen bottom).
    var bottomRowCentreY: CGFloat { screen.height - Screen.bottomRowCentreFromScreenBottom }

    /// The 9:16 content box (`layout.year.story.frame` aspectWidth / aspectHeight) as wide as the frame, centred
    /// vertically in it, in frame coordinates.
    var contentBox: CGRect {
        let height = frame.width * Tokens.Layouts.YearStoryFrame.aspectHeight / Tokens.Layouts.YearStoryFrame.aspectWidth
        return CGRect(x: 0, y: (frame.height - height) / 2, width: frame.width, height: height)
    }
}

// MARK: - Screen

/// The recap preview screen (dark in both appearances: render it with `.environment(\.colorScheme, .dark)`): page
/// `color.global.backgroundDeep`; the rounded media page (`mediaPageCornerRadius`, continuous — `layout.global.cornerStyle`)
/// holding `page`, clipped; `overlay` on top of the page in frame coordinates (close circle, position pill); optional
/// page dots (C-31 on media) under the frame; the bottom row — `leading` at `size.global.buttonMarginH`, `trailing` at
/// `collage.share.layout.pill.trailingInset` — centred `bottomRowCentreFromScreenBottom` above the screen bottom.
struct RecapPreviewScreen<Page: View, Overlay: View, Leading: View, Trailing: View>: View {
    var dots: RecapPreviewDots?
    @ViewBuilder let page: (RecapPreviewGeometry) -> Page
    @ViewBuilder let overlay: (RecapPreviewGeometry) -> Overlay
    @ViewBuilder let leading: () -> Leading
    @ViewBuilder let trailing: () -> Trailing

    init(
        dots: RecapPreviewDots? = nil,
        @ViewBuilder page: @escaping (RecapPreviewGeometry) -> Page,
        @ViewBuilder overlay: @escaping (RecapPreviewGeometry) -> Overlay,
        @ViewBuilder leading: @escaping () -> Leading,
        @ViewBuilder trailing: @escaping () -> Trailing
    ) {
        self.dots = dots
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
                if let dots {
                    PageDots(count: dots.count, index: dots.index, onMedia: true, accessibilityValue: dots.accessibilityValue)
                        .frame(width: geometry.screen.width)
                        .position(x: geometry.screen.width / 2, y: geometry.dotsCentreY)
                }
                HStack(spacing: 0) {
                    leading()
                    Spacer(minLength: 0)
                    trailing()
                }
                .padding(.leading, Tokens.Sizes.globalButtonMarginH)
                .padding(.trailing, Tokens.Sizes.globalButtonMarginH)
                .frame(width: geometry.screen.width)
                .position(x: geometry.screen.width / 2, y: geometry.bottomRowCentreY)
            }
            .frame(width: geometry.screen.width, height: geometry.screen.height, alignment: .topLeading)
            .offset(x: -proxy.safeAreaInsets.leading, y: -proxy.safeAreaInsets.top)
        }
    }
}

/// The page dots under the recap preview's frame (C-31 on media).
struct RecapPreviewDots: Equatable {
    let count: Int
    let index: Int
    /// "Page N of M" from copy.
    let accessibilityValue: String
}

/// The close circle of the recap preview: C-11 on media (`size.global.circleButton`, `color.global.controlOnDeep`,
/// `icon.global.close` in `color.global.textOnMedia`) centred `closeCentreFromTrailing` / `closeCentreBelowPageTop` in the
/// frame. Retro's '×' is ≈9.7 pt with no token: the glyph box is `size.global.iconSmall`, the nearest glyph token
/// (component gap reported).
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

/// The recap preview's light 'Share' pill (`collage.share.layout.pill`: height `height` (a minimum, it grows with
/// Dynamic Type), `paddingHorizontal`, `radius.global.capsule`, fill `color.global.surfaceLight`, label text role
/// `button` in `color.global.onSurfaceLight`, no glyph — ST-04).
struct RecapSharePillLabel: View {
    let title: String

    var body: some View {
        Text(title)
            .dsTextStyle(TextRole.button)
            .foregroundStyle(Tokens.Colors.globalOnSurfaceLight)
            .lineLimit(1)
            .padding(.horizontal, Tokens.Layouts.CollageShareLayoutPill.paddingHorizontal)
            .frame(minHeight: Tokens.Layouts.CollageShareLayoutPill.height)
            .background(Tokens.Colors.globalSurfaceLight, in: Capsule())
            .contentShape(Capsule())
    }
}

// MARK: - Recap card (`layout.year.story.recapCard`)

/// One photo of the recap card's grid.
struct RecapCardPhoto: Identifiable, Hashable {
    let id: String
    var source: PhotoSource?
    /// From copy (who / when), for the cell's VoiceOver label.
    let accessibilityLabel: String

    init(id: String, source: PhotoSource?, accessibilityLabel: String) {
        self.id = id
        self.source = source
        self.accessibilityLabel = accessibilityLabel
    }
}

/// Retro's recap card (TC-REC phone 2; MERGE L-4: white in both appearances): a card `widthRatio` of the frame width,
/// fill `color.global.surfaceLight`, corners `cornerRadiusRatio` × its width (continuous); padding `paddingRatio` × its
/// width; a grid of `columns` columns × up to `maxRows` rows of square-cornered cells (`cellAspect` width ÷ height,
/// aspect-fill), `size.global.stripGap` apart; then the footer, `footerHeightRatio` × the card width: `title` (the year,
/// "Week 27") in `font.global.display` text role `headerTitle`, bottom-leading at the card padding; trailing,
/// right-aligned on the title's baseline, `name` (text role `listTitle`) over `detail` (text role `meta`,
/// `color.global.textSecondary`); title and name in `color.global.onSurfaceLight`. Photos past `columns × maxRows` are
/// left out (the caller decides which rows to fill). The card is a picture of a card (it is also the share image), so
/// its text keeps the default size. Place it centred on the blurred cover (`BlurredBackdrop`, C-34).
struct RecapCard: View {
    let photos: [RecapCardPhoto]
    let title: String
    var name: String?
    var detail: String?
    /// Width of the media page the card sits on.
    let frameWidth: CGFloat
    var onSelect: ((RecapCardPhoto) -> Void)?

    private typealias Card = Tokens.Layouts.YearStoryRecapCard

    init(
        photos: [RecapCardPhoto],
        title: String,
        name: String? = nil,
        detail: String? = nil,
        frameWidth: CGFloat,
        onSelect: ((RecapCardPhoto) -> Void)? = nil
    ) {
        self.photos = photos
        self.title = title
        self.name = name
        self.detail = detail
        self.frameWidth = frameWidth
        self.onSelect = onSelect
    }

    /// The card's width for a frame `frameWidth` wide.
    static func width(frameWidth: CGFloat) -> CGFloat { frameWidth * Card.widthRatio }

    /// Photos of the full rows only, at most `maxRows` rows (year.story: "only full rows").
    static func fullRows<T>(_ items: [T]) -> [T] {
        let columns = max(1, Int(Card.columns))
        let rows = min(Int(Card.maxRows), items.count / columns)
        return Array(items.prefix(rows * columns))
    }

    var body: some View {
        let width = Self.width(frameWidth: frameWidth)
        let padding = width * Card.paddingRatio
        let columns = max(1, Int(Card.columns))
        let gap = Tokens.Sizes.globalStripGap
        let cellWidth = max(0, (width - 2 * padding - CGFloat(columns - 1) * gap) / CGFloat(columns))
        let cellHeight = cellWidth / Card.cellAspect
        let shown = Array(photos.prefix(columns * Int(Card.maxRows)))
        let rows = stride(from: 0, to: shown.count, by: columns).map { Array(shown[$0..<min($0 + columns, shown.count)]) }
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: gap) {
                ForEach(rows.indices, id: \.self) { row in
                    HStack(spacing: gap) {
                        ForEach(rows[row]) { photo in
                            cell(photo, width: cellWidth, height: cellHeight)
                        }
                    }
                }
            }
            .padding([.top, .horizontal], padding)
            footer(padding: padding)
                .frame(width: width, height: width * Card.footerHeightRatio, alignment: .bottom)
        }
        .frame(width: width)
        .background(Tokens.Colors.globalSurfaceLight, in: DSShape.rounded(width * Card.cornerRadiusRatio))
        .environment(\.dynamicTypeSize, .large)
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private func cell(_ photo: RecapCardPhoto, width: CGFloat, height: CGFloat) -> some View {
        let image = PhotoView(source: photo.source)
            .frame(width: width, height: height)
            .clipped()
        if let onSelect {
            Button {
                onSelect(photo)
            } label: {
                image
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(photo.accessibilityLabel))
        } else {
            image
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(photo.accessibilityLabel))
                .accessibilityAddTraits(.isImage)
        }
    }

    private func footer(padding: CGFloat) -> some View {
        HStack(alignment: .lastTextBaseline, spacing: padding) {
            Text(title)
                .dsTextStyle(TextRole.headerTitle)
                .foregroundStyle(Tokens.Colors.globalOnSurfaceLight)
                .lineLimit(1)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 0)
            if name != nil || detail != nil {
                VStack(alignment: .trailing, spacing: 0) {
                    if let name {
                        Text(name)
                            .dsTextStyle(TextRole.listTitle)
                            .foregroundStyle(Tokens.Colors.globalOnSurfaceLight)
                    }
                    if let detail {
                        Text(detail)
                            .dsTextStyle(TextRole.meta)
                            .foregroundStyle(Tokens.Colors.globalTextSecondary)
                    }
                }
                .multilineTextAlignment(.trailing)
                .lineLimit(1)
            }
        }
        .padding([.horizontal, .bottom], padding)
    }
}

// MARK: - Footer on a full-bleed page

/// The footer of a full-bleed recap page (TC-REC phone 3; year.story photo / collage / cover cards, week.recap page 2):
/// `leading` and `trailing` at `dimension.year.story.frame.padding` from the frame's sides, their last baselines
/// `dimension.year.story.footer.baseline` above the frame bottom. The caller styles the texts.
struct RecapFooter<Leading: View, Trailing: View>: View {
    @ViewBuilder let leading: () -> Leading
    @ViewBuilder let trailing: () -> Trailing

    init(@ViewBuilder leading: @escaping () -> Leading, @ViewBuilder trailing: @escaping () -> Trailing) {
        self.leading = leading
        self.trailing = trailing
    }

    var body: some View {
        HStack(alignment: .lastTextBaseline, spacing: Tokens.Sizes.yearStoryFramePadding) {
            leading()
            Spacer(minLength: 0)
            trailing()
        }
        .alignmentGuide(.bottom) { dimensions in dimensions[.lastTextBaseline] }
        .padding(.horizontal, Tokens.Sizes.yearStoryFramePadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .padding(.bottom, Tokens.Sizes.yearStoryFooterBaseline)
    }
}

extension RecapFooter where Trailing == EmptyView {
    init(@ViewBuilder leading: @escaping () -> Leading) {
        self.init(leading: leading) { EmptyView() }
    }
}
