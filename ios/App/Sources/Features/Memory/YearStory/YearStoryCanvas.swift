// Surface: year.story — the 9:16 canvas and its cards (B, C, D in design/surfaces/year.story.md).
import AppData
import DesignSystem
import SwiftUI
import UIKit

/// Text roles of the story (`font.year.story`, `layout.year.story.textStyleMap`).
enum YearStoryType {
    static var headline: DSTextStyle {
        MemoryType.style(Tokens.Fonts.yearStory, size: Tokens.FontSizes.yearStoryHeadline,
                         weight: Tokens.FontWeights.fontWeightYearStoryHeadline,
                         relativeTo: Tokens.Layouts.YearStoryTextStyleMap.headline, lineHeight: Tokens.LineHeights.yearStoryHeadline)
    }

    static var body: DSTextStyle {
        MemoryType.style(Tokens.Fonts.yearStory, size: Tokens.FontSizes.yearStoryBody,
                         weight: Tokens.FontWeights.fontWeightYearStoryBody,
                         relativeTo: Tokens.Layouts.YearStoryTextStyleMap.body, lineHeight: Tokens.LineHeights.yearStoryBody)
    }

    static var share: DSTextStyle {
        MemoryType.style(Tokens.Fonts.yearStory, size: Tokens.FontSizes.yearStoryShare,
                         weight: Tokens.FontWeights.fontWeightYearStoryShare, relativeTo: Tokens.Layouts.YearStoryTextStyleMap.share)
    }

    static var sharePill: DSTextStyle {
        MemoryType.style(Tokens.Fonts.yearStory, size: Tokens.FontSizes.yearStorySharePill,
                         weight: Tokens.FontWeights.fontWeightYearStorySharePill, relativeTo: Tokens.Layouts.YearStoryTextStyleMap.sharePill)
    }
}

enum YearStoryGeometry {
    /// 9:16 (`layout.year.story.canvas`).
    static var aspect: CGFloat { Tokens.Layouts.YearStoryCanvas.aspectWidth / Tokens.Layouts.YearStoryCanvas.aspectHeight }

    /// The canvas: screen width, kept 9:16, fitted inside the safe area.
    static func canvasSize(in available: CGSize) -> CGSize {
        let width = min(available.width, available.height * aspect)
        return CGSize(width: width, height: width / aspect)
    }
}

/// The content of one card on the canvas, without the progress bar, chrome or share row: this is
/// both what the player shows and what the share image (D) renders.
struct YearStoryCardContent: View {
    let card: YearStoryCard
    let size: CGSize
    /// True: the subline is shown at once (share images, snapshots). False: the reveal runs.
    var revealed = false

    var body: some View {
        switch card {
        case .mostReacted, .togetherDay:
            photoCard
        case .summary:
            Color.clear
        default:
            YearStoryTextBlock(headline: card.headline, subline: card.subline, revealed: revealed)
                .frame(maxWidth: Tokens.Sizes.yearStoryTextMaxWidth)
                .frame(width: size.width, height: size.height)
        }
    }

    /// `layout.year.story.photoCard`: square box `boxWidthRatio` × width, centred at
    /// `boxCenterYRatio` × height; photos fill it, collages are fitted inside it; headline
    /// `textGap` below. At large text sizes the text is pushed down, the box stays.
    private var photoCard: some View {
        let box = size.width * Tokens.Layouts.YearStoryPhotoCard.boxWidthRatio
        let boxTop = size.height * Tokens.Layouts.YearStoryPhotoCard.boxCenterYRatio - box / 2
        let isCollage: Bool = {
            if case .togetherDay = card { return true }
            return false
        }()
        return ZStack(alignment: .top) {
            MemoryRemoteImage(url: card.imageURL, contentMode: isCollage ? .fit : .fill)
                .frame(width: box, height: box)
                .padding(.top, boxTop)
                .accessibilityElement()
                .accessibilityLabel(collageLabel)
                .accessibilityHidden(!isCollage)
                .accessibilitySortPriority(0)
            Text(card.headline)
                .dsTextStyle(YearStoryType.headline)
                .foregroundStyle(Tokens.Colors.globalTextPrimary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: Tokens.Sizes.yearStoryTextMaxWidth)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, boxTop + box + Tokens.Layouts.YearStoryPhotoCard.textGap)
                .accessibilityAddTraits(.isHeader)
                .accessibilitySortPriority(2)
        }
        .frame(width: size.width, height: size.height, alignment: .top)
    }

    private var collageLabel: String {
        if case let .togetherDay(collage) = card {
            return Copy.yearStoryA11yCollage(date: MemoryFormat.storyDate(collage.date))
        }
        return ""
    }
}

/// Headline, then subline, centred. Reveal on a card with a subline (year.story.md § Motion): the
/// headline moves up `dimension.year.story.reveal.headlineShift` over
/// `duration.year.story.reveal.headline` on `easing.year.story.reveal`; `duration.year.story.reveal.sublineDelay`
/// after the card appears the subline rises `dimension.year.story.reveal.sublineOffset` and fades in over
/// `duration.year.story.reveal.subline` on `easing.year.story.reveal.subline`. Reduce Motion
/// (`layout.global.reduceMotion`): nothing moves; the subline cross-fades in with the same delay,
/// duration and curve.
struct YearStoryTextBlock: View {
    let headline: String
    let subline: String?
    var revealed = false
    @State private var headlineSettled = false
    @State private var sublineVisible = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Movement, except under Reduce Motion (and in snapshots, which show the settled card).
    private var moves: Bool {
        !reduceMotion && !revealed
    }

    var body: some View {
        let sublineShown = revealed || sublineVisible
        VStack {
            Text(headline)
                .dsTextStyle(YearStoryType.headline)
                .offset(y: moves && subline != nil && !headlineSettled ? Tokens.Sizes.yearStoryRevealHeadlineShift : 0)
                .accessibilityAddTraits(.isHeader)
                .accessibilitySortPriority(2)
            if let subline {
                Text(subline)
                    .dsTextStyle(YearStoryType.body)
                    .opacity(sublineShown ? 1 : 0)
                    .offset(y: moves && !sublineShown ? Tokens.Sizes.yearStoryRevealSublineOffset : 0)
                    .accessibilitySortPriority(1)
            }
        }
        .foregroundStyle(Tokens.Colors.globalTextPrimary)
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
        .onAppear { reveal() }
    }

    private func reveal() {
        guard !revealed, subline != nil else { return }
        withAnimation(Tokens.Easings.yearStoryReveal.animation(duration: Tokens.Durations.yearStoryRevealHeadline)) {
            headlineSettled = true
        }
        let sublineAnimation = Tokens.Easings.yearStoryRevealSubline.animation(duration: Tokens.Durations.yearStoryRevealSubline)
        withAnimation(sublineAnimation.delay(Tokens.Durations.yearStoryRevealSublineDelay)) {
            sublineVisible = true
        }
    }
}

/// Segmented progress (`layout.year.story.progress`): one segment per card; completed segments
/// filled, the current one filling over `duration.year.story.card` on `easing.year.story.progress.fill`,
/// upcoming ones white at `opacity.year.story.progress.track`.
struct YearStoryProgressBar: View {
    let count: Int
    let index: Int
    /// Elapsed share (0…1) of the current card's time (`YearStoryModel.currentFraction(at:)`).
    var currentFraction: Double = 1

    var body: some View {
        HStack(spacing: Tokens.Sizes.yearStoryProgressGap) {
            ForEach(0..<count, id: \.self) { position in
                GeometryReader { segment in
                    ZStack(alignment: .leading) {
                        Tokens.Colors.globalTextPrimary.opacity(Tokens.Opacities.yearStoryProgressTrack)
                        Tokens.Colors.yearStoryProgressFill
                            .frame(width: segment.size.width * fill(position))
                    }
                }
                .frame(height: Tokens.Sizes.yearStoryProgressHeight)
            }
        }
        .padding(.horizontal, Tokens.Sizes.yearStoryProgressInset)
        .accessibilityHidden(true)
    }

    private func fill(_ position: Int) -> CGFloat {
        if position < index { return 1 }
        if position == index {
            let elapsed = min(max(currentFraction, 0), 1)
            return CGFloat(Tokens.Easings.yearStoryProgressFill.unitCurve.value(at: elapsed))
        }
        return 0
    }
}

/// "Share this story" row look (`layout.year.story.share`): glyph as tall as the row, gap, label.
struct YearStoryShareRowLabel: View {
    var body: some View {
        HStack(spacing: Tokens.Sizes.yearStoryShareGlyphGap) {
            Image(systemName: Tokens.Icons.yearStoryShare)
                .resizable()
                .scaledToFit()
                .frame(height: Tokens.Sizes.yearStoryShareRowHeight)
                .accessibilityHidden(true)
            Text(Copy.yearStoryShare)
                .dsTextStyle(YearStoryType.share)
        }
        .foregroundStyle(Tokens.Colors.globalTextPrimary)
        .frame(minHeight: Tokens.Sizes.yearStoryShareRowHeight)
        .frame(minHeight: Tokens.Sizes.globalMinTouchTargetIos)
        .contentShape(Rectangle())
    }
}

/// Share pill of the summary (`dimension.year.story.summary.shareWidth/Height`, capsule, light fill).
struct YearStorySharePillLabel: View {
    var body: some View {
        Text(Copy.yearStorySummaryShare)
            .dsTextStyle(YearStoryType.sharePill)
            .foregroundStyle(Tokens.Colors.globalOnSurfaceLight)
            .frame(minWidth: Tokens.Sizes.yearStorySummaryShareWidth, minHeight: Tokens.Sizes.yearStorySummaryShareHeight)
            .background(Tokens.Colors.globalSurfaceLight, in: Capsule())
            .contentShape(Capsule())
    }
}

// MARK: - Share image (D)

/// Renders a fact card's canvas (no progress bar, chrome or share row) at 1080 × 1920 px
/// (`layout.year.story.shareCard`) with `ImageRenderer`, at the default text size, and writes the PNG.
@MainActor
enum YearStoryShareRenderer {
    struct Output {
        let image: UIImage
        let file: URL
    }

    /// - Parameters:
    ///   - width: the canvas width in points the card is laid out at (the player's canvas).
    ///   - pixelSize: the photo box's pixel size (`YearStoryModel.imagePixelSize`).
    static func render(_ card: YearStoryCard, width: CGFloat, pixelSize: CGFloat?, images: any MemoryImageLoading) async -> Output? {
        guard width > 0 else { return nil }
        if let url = card.imageURL { _ = await images.image(for: url, maxPixelSize: pixelSize) }
        let size = CGSize(width: width, height: width / YearStoryGeometry.aspect)
        let content = YearStoryCardContent(card: card, size: size, revealed: true)
            .frame(width: size.width, height: size.height)
            .background(Tokens.Colors.globalBackgroundDeep)
            .environment(\.memoryImageLoader, images)
            .environment(\.dynamicTypeSize, .large)
        // `ImageRenderer` draws on the main actor (one card, a few milliseconds); PNG encoding and the
        // file write run off it.
        let renderer = ImageRenderer(content: content)
        renderer.scale = Tokens.Layouts.YearStoryShareCard.width / width
        renderer.isOpaque = true
        guard let cgImage = renderer.cgImage else { return nil }
        let frame = DecodedImage(image: cgImage)
        let name = card.id + ".png" // provenance-ok: file extension of the PNG
        let file = await Task.detached(priority: .utility) { () -> URL? in
            let folder = FileManager.default.temporaryDirectory.appendingPathComponent("YearStoryShare", isDirectory: true)
            guard let png = UIImage(cgImage: frame.image).pngData() else { return nil }
            do {
                try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                let file = folder.appendingPathComponent(name)
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
