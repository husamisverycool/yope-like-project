// Surface: year.story — what one card shows inside the recap preview's frame (B "Card kinds", C summary, D share image
// in design/surfaces/year.story.md). The same view is the player's page and the 1080 × 1920 share image.
// Evidence: references/auto/retro/press/tc-2023-12-recaps.png phones 2–3 (recap card, full-bleed '2023' footer),
// references/auto/retro/store/retro-store-04.png (recap preview); Wrapped reveal positions / fit (mechanics).
import AppData
import DesignSystem
import SwiftUI
import UIKit

/// One card laid out in `size` (the frame on screen, the 9:16 box in the share image):
///
/// - **text** — the cover blurred over the whole area (C-34 `BlurredBackdrop`) under `layout.global.photoScrim`; a centred
///   block `size.width − 2 × dimension.year.story.frame.padding` wide (`YearStoryTextBlock`);
/// - **photo** — the photo full bleed (aspect-fill) under the scrim; footer: the date (`layout.year.story.dateFormat`,
///   display serif `displaySmall`) leading, `year.story.mostReacted.photo` ("Post by {name}", `listTitle`) trailing — no
///   number, rank or reaction glyph (T2); a self-tagged photo's trailing line is `tagging.with` ("with Ana and Rui");
/// - **collage** — the collage fitted whole (never cropped) on its own blurred backdrop, scrim, the date;
/// - **summary** — the style in view: the recap card (`layout.year.story.recapCard`) on the blurred cover, or the cover
///   full bleed with the year (`headerTitle`), the group name (`listTitle`) and under it the app line
///   `year.story.card.app` (`meta`): Retro prints its name in that place ('2023 / nathan / retro.app', TC-REC).
///
/// Text is `color.global.textOnMedia`; footers sit at `dimension.year.story.frame.padding` from the sides with their
/// baselines `dimension.year.story.footer.baseline` above the bottom (`RecapFooter`).
struct YearStoryCardContent: View {
    let card: YearStoryCard
    let size: CGSize
    var summary: YearStorySummary?
    var summaryStyle: YearStorySummary.Style = .cover
    var coverURL: URL?
    let images: any MemoryImageLoading
    /// True: the reveal is settled at once (share images, snapshots).
    var revealed = false

    var body: some View {
        ZStack {
            Tokens.Colors.globalBackgroundDeep
            switch card {
            case let .mostReacted(photo), let .tagged(photo):
                photoPage(url: photo.imageURL, date: photo.date, trailing: photo.trailing,
                          label: Copy.yearStoryA11yPhoto(name: photo.name, date: MemoryFormat.weekdayMonthDay(photo.date)))
            case let .togetherDay(collage):
                collagePage(collage)
            case .summary:
                summaryPage(summaryStyle)
            default:
                textPage
            }
        }
        .frame(width: size.width, height: size.height)
        .clipped()
    }

    // MARK: Text card

    private var textPage: some View {
        ZStack {
            BlurredBackdrop(source: images.source(coverURL))
            PhotoScrim()
            YearStoryTextBlock(headline: card.headline, subline: card.subline, revealed: revealed)
                .frame(width: max(0, size.width - 2 * Tokens.Sizes.yearStoryFramePadding))
        }
    }

    // MARK: Photo / collage cards

    private func photoPage(url: URL?, date: LocalDate, trailing: String?, label: String) -> some View {
        ZStack {
            MemoryRemoteImage(url: url)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(label))
                .accessibilityAddTraits(.isImage)
            PhotoScrim()
            RecapFooter {
                Text(MemoryFormat.weekdayMonthDay(date))
                    .dsTextStyle(TextRole.displaySmall)
                    .foregroundStyle(Tokens.Colors.globalTextOnMedia)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
            } trailing: {
                if let trailing {
                    Text(trailing)
                        .dsTextStyle(TextRole.listTitle)
                        .foregroundStyle(Tokens.Colors.globalTextOnMedia)
                        .multilineTextAlignment(.trailing)
                        .lineLimit(1)
                }
            }
        }
    }

    private func collagePage(_ collage: YearStoryCollage) -> some View {
        ZStack {
            BlurredBackdrop(source: images.source(collage.imageURL))
            MemoryRemoteImage(url: collage.imageURL, contentMode: .fit)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(Copy.yearStoryA11yCollage(date: MemoryFormat.weekdayMonthDay(collage.date))))
                .accessibilityAddTraits(.isImage)
            PhotoScrim()
            RecapFooter {
                Text(MemoryFormat.weekdayMonthDay(collage.date))
                    .dsTextStyle(TextRole.displaySmall)
                    .foregroundStyle(Tokens.Colors.globalTextOnMedia)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
            }
        }
    }

    // MARK: Summary styles

    @ViewBuilder
    private func summaryPage(_ style: YearStorySummary.Style) -> some View {
        let year = String(summary?.year ?? 0)
        switch style {
        case .recapCard:
            ZStack {
                BlurredBackdrop(source: images.source(coverURL))
                RecapCard(
                    photos: (summary?.grid ?? []).map { photo in
                        RecapCardPhoto(
                            id: photo.postID.rawValue, source: images.source(photo.imageURL),
                            accessibilityLabel: Copy.yearStoryA11yPhoto(name: photo.name, date: MemoryFormat.weekdayMonthDay(photo.date))
                        )
                    },
                    title: year,
                    name: summary?.groupName,
                    detail: Copy.yearStoryCardApp,
                    frameWidth: size.width
                )
            }
        case .cover:
            ZStack {
                MemoryRemoteImage(url: coverURL)
                    .accessibilityHidden(true)
                PhotoScrim()
                RecapFooter {
                    Text(year)
                        .dsTextStyle(TextRole.headerTitle)
                        .foregroundStyle(Tokens.Colors.globalTextOnMedia)
                        .accessibilityAddTraits(.isHeader)
                } trailing: {
                    VStack(alignment: .trailing, spacing: 0) {
                        if let name = summary?.groupName {
                            Text(name)
                                .dsTextStyle(TextRole.listTitle)
                                .foregroundStyle(Tokens.Colors.globalTextOnMedia)
                                .multilineTextAlignment(.trailing)
                                .lineLimit(1)
                        }
                        Text(Copy.yearStoryCardApp)
                            .dsTextStyle(TextRole.meta)
                            .foregroundStyle(Tokens.Colors.globalTextOnMedia)
                            .lineLimit(1)
                    }
                }
            }
        }
    }
}

/// A text card's block, centred: the headline in `font.global.display` text role `displayMedium`, then — its cap top
/// `dimension.birthday.request.headlineToMessage` below the headline's last baseline — the subline in text role
/// `textButton`; both `color.global.textOnMedia`, centred.
///
/// Reveal (Wrapped mechanics, cards with a subline): the headline rises `dimension.year.story.reveal.headlineShift` over
/// `duration.year.story.reveal.headline` (`easing.year.story.reveal`); `duration.year.story.reveal.sublineDelay` later the
/// subline rises from `dimension.year.story.reveal.sublineOffset` below over `duration.year.story.reveal.subline`
/// (`easing.year.story.reveal.subline`); both fade in over `duration.global.fade`. Reduce Motion
/// (`layout.global.reduceMotion`): no movement, the same durations as cross-fades.
struct YearStoryTextBlock: View {
    let headline: String
    let subline: String?
    var revealed = false
    @State private var headlineShown = false
    @State private var headlineSettled = false
    @State private var sublineShown = false
    @State private var sublineSettled = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Cards with a subline reveal; the others (and share images, snapshots) show settled.
    private var reveals: Bool { subline != nil && !revealed }

    var body: some View {
        MetricStack(alignment: .center) {
            Text(headline)
                .dsTextRole(TextRole.displayMedium)
                .foregroundStyle(Tokens.Colors.globalTextOnMedia)
                .opacity(!reveals || headlineShown ? 1 : 0)
                .offset(y: moves && !headlineSettled ? Tokens.Sizes.yearStoryRevealHeadlineShift : 0)
                .accessibilityAddTraits(.isHeader)
            if let subline {
                Text(subline)
                    .dsTextRole(TextRole.textButton)
                    .foregroundStyle(Tokens.Colors.globalTextOnMedia)
                    .opacity(!reveals || sublineShown ? 1 : 0)
                    .offset(y: moves && !sublineSettled ? Tokens.Sizes.yearStoryRevealSublineOffset : 0)
                    .metricGap(Tokens.Sizes.birthdayRequestHeadlineToMessage, from: .lastBaseline, to: .capTop)
            }
        }
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
        .onAppear(perform: reveal)
    }

    /// Movement only when revealing and Reduce Motion is off.
    private var moves: Bool { reveals && !reduceMotion }

    private func reveal() {
        guard reveals else { return }
        let headlineMove = Tokens.Easings.yearStoryReveal.animation(duration: Tokens.Durations.yearStoryRevealHeadline)
        let sublineMove = Tokens.Easings.yearStoryRevealSubline.animation(duration: Tokens.Durations.yearStoryRevealSubline)
            .delay(Tokens.Durations.yearStoryRevealSublineDelay)
        // Reduce Motion: the movement's durations and curves carry a cross-fade instead.
        let headlineFade = reduceMotion ? headlineMove : ComponentMotion.fade.animation
        let sublineFade = reduceMotion ? sublineMove : ComponentMotion.fade.animation.delay(Tokens.Durations.yearStoryRevealSublineDelay)
        withAnimation(headlineFade) { headlineShown = true }
        withAnimation(sublineFade) { sublineShown = true }
        guard !reduceMotion else { return }
        withAnimation(headlineMove) { headlineSettled = true }
        withAnimation(sublineMove) { sublineSettled = true }
    }
}

// MARK: - Share image (D)

/// Renders a card's frame content (no close circle, position pill or bottom row) as `layout.year.story.shareCard`:
/// the 9:16 box at 1080 px wide (scale = 1080 ÷ box width), PNG, at the default text size.
@MainActor
enum YearStoryShareRenderer {
    struct Output {
        let image: UIImage
        let file: URL
    }

    /// - Parameter width: the frame width in points the card is laid out at (the player's frame).
    static func render(
        _ card: YearStoryCard,
        width: CGFloat,
        summary: YearStorySummary?,
        summaryStyle: YearStorySummary.Style,
        coverURL: URL?,
        images: any MemoryImageLoading,
        name: String
    ) async -> Output? {
        guard width > 0 else { return nil }
        // Every image the card draws is decoded first, so the renderer draws it at once.
        var urls = [card.imageURL, coverURL].compactMap { $0 }
        if card == .summary { urls += summary?.grid.compactMap(\.imageURL) ?? [] }
        for url in urls { _ = await images.image(for: url, maxPixelSize: Tokens.Layouts.YearStoryShareCard.width) }
        let box = CGSize(width: width, height: width * Tokens.Layouts.YearStoryShareCard.height / Tokens.Layouts.YearStoryShareCard.width)
        let content = YearStoryCardContent(
            card: card, size: box, summary: summary, summaryStyle: summaryStyle, coverURL: coverURL, images: images, revealed: true
        )
        .environment(\.memoryImageLoader, images)
        .environment(\.dynamicTypeSize, .large)
        .environment(\.colorScheme, .dark)
        let renderer = ImageRenderer(content: content)
        renderer.scale = Tokens.Layouts.YearStoryShareCard.width / width
        renderer.isOpaque = true
        guard let cgImage = renderer.cgImage else { return nil }
        let frame = DecodedImage(image: cgImage)
        let fileName = name + ".png" // provenance-ok: file extension of the PNG
        let file = await Task.detached(priority: .utility) { () -> URL? in
            let folder = FileManager.default.temporaryDirectory.appendingPathComponent("YearStoryShare", isDirectory: true)
            guard let png = UIImage(cgImage: frame.image).pngData() else { return nil }
            do {
                try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                let file = folder.appendingPathComponent(fileName)
                try png.write(to: file, options: .atomic)
                return file
            } catch {
                return nil
            }
        }.value
        guard let file else { return nil }
        return Output(image: UIImage(cgImage: cgImage), file: file)
    }
}
