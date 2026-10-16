// Retro's recap card and the footer of a full-bleed recap page, shared by year.story (memory) and week.recap (social)
// (MERGE RM-8, lead notes L-4). Evidence: `references/auto/retro/press/tc-2023-12-recaps.png` phones 2–3 (the recap card:
// white, 4 × 6 grid, '2023' serif footer; the full-bleed style), `references/auto/retro/press/tc-2023-12-retro-header.png`.
// Components: C-34 (card on a blurred backdrop), C-35 (full-bleed footer). The recap preview screen around them (media
// page, close, dots, bottom row, Share pill) is the capture group's `RecapPreviewScreen` / `RecapPillLabel`
// (Features/Capture/Collage/RecapPreviewScreen.swift); the recap card (`layout.year.story.recapCard`, white in both
// appearances) is memory's and is used as is by week.recap:
//
//     RecapCard(photos: cells, title: Copy.photoViewerHeaderWeek(number: …), name: groupName, detail: range,
//               frameWidth: pageWidth) { cell in open(cell) }
import DesignSystem
import SwiftUI

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
