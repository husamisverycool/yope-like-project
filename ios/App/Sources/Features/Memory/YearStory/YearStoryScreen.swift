// Surface: year.story — Retro's yearly recap ("Year in Photos") in Retro's recap preview; Spotify Wrapped's tap-through
// pacing (mechanics). Reference images: references/auto/retro/store/retro-store-04.png (ST-04, recap preview 2026),
// references/auto/retro/press/tc-2023-12-recaps.png (TC-REC phones 2–3), references/auto/retro/press/tc-2023-12-retro-header.png
// (TC-H); mechanics: references/auto/wrapped/frames/wrapped24-rec-emilycraig-sheet-every3s.png (design/surfaces/year.story.md).
// Components: C-34, C-31, C-22 (position pill), C-11, C-09 (recap Share pill), C-27, C-28; the recap preview screen is
// the capture group's shared `RecapPreviewScreen` (Features/Capture/Collage).
import AppData
import DesignSystem
import SwiftUI
import UIKit

/// The group's December year story: one fact per card in the recap preview's rounded frame, auto-advancing every
/// `duration.year.story.card` (pause / play in the bottom row), tap halves to step, ending on the summary's two share
/// styles. Dark in both appearances; presented full screen (`MemoryModal.yearStory`).
@MainActor
struct YearStoryScreen: View {
    let groupID: String
    let year: Int
    @State private var model: YearStoryModel
    /// Snapshots: the reveal settled at once.
    private let revealsImmediately: Bool
    @State private var frameWidth: CGFloat = 0
    @Environment(\.dismiss) private var dismiss
    @Environment(\.displayScale) private var displayScale
    @Environment(\.scenePhase) private var scenePhase

    init(groupID: String, year: Int, model: YearStoryModel? = nil, revealsImmediately: Bool = false) {
        self.groupID = groupID
        self.year = year
        _model = State(initialValue: model ?? YearStoryModel(groupID: GroupID(groupID), year: year, dependencies: .current))
        self.revealsImmediately = revealsImmediately
    }

    var body: some View {
        MemoryImageScope { images in
            RecapPreviewScreen(dots: dots, onSelectPage: { model.summaryPage = $0 }) { geometry in
                pageContent(size: geometry.frame.size, images: images)
                    .accessibilitySortPriority(3)
            } overlay: { geometry in
                ZStack(alignment: .topLeading) {
                    positionPill(geometry)
                        .accessibilitySortPriority(4)
                    RecapPreviewClose(geometry: geometry, accessibilityLabel: Copy.yearStoryA11yClose) { model.close() }
                        .accessibilityIdentifier("year.story.close")
                        .accessibilitySortPriority(5)
                }
            } leading: {
                leadingCircle
                    .accessibilitySortPriority(2)
            } trailing: {
                sharePill
                    .accessibilitySortPriority(1)
            }
            .task(id: renderKey) { await renderShare(images: images) }
        }
        .environment(\.colorScheme, .dark)
        .preferredColorScheme(.dark)
        .toolbar(.hidden, for: .navigationBar)
        .task { await model.loadIfNeeded() }
        .onDisappear { model.stopListening() }
        .onChange(of: model.isFinished) { _, finished in
            if finished { dismiss() }
        }
        .onChange(of: model.index) { _, _ in
            UIAccessibility.post(notification: .screenChanged, argument: nil)
        }
        // The card clock stops while the app is not in the foreground and resumes on return.
        .onChange(of: scenePhase, initial: true) { _, phase in
            model.setSuspended(phase != .active)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("year.story")
    }

    /// The summary's share styles are pages (swiped, page dots `dimension.year.story.dots.offset` below the frame);
    /// every other card is one page and shows no dots.
    private var dots: RecapPreviewDots? {
        let count = model.summaryStyles.count
        guard model.phase == .loaded, model.currentCard == .summary, count > 1 else { return nil }
        let index = min(max(model.summaryPage, 0), count - 1)
        return RecapPreviewDots(
            count: count, index: index,
            accessibilityValue: Copy.globalA11yPagePosition(position: String(index + 1), count: String(count))
        )
    }

    // MARK: Frame

    /// The frame's content: the state, or the card in view (the summary: a pager of its share styles).
    @ViewBuilder
    private func pageContent(size: CGSize, images: any MemoryImageLoading) -> some View {
        switch model.phase {
        case .idle, .loading:
            ZStack {
                Tokens.Colors.globalBackgroundDeep
                MemoryLoadingIndicator(announcement: Copy.yearStoryLoading)
            }
        case .error:
            ZStack {
                Tokens.Colors.globalBackgroundDeep
                MemoryMediaStateBlock(title: Copy.yearStoryErrorTitle, detail: Copy.yearStoryErrorDetail, retryTitle: Copy.yearStoryErrorRetry) {
                    Task { await model.retry() }
                }
            }
        case .offline:
            ZStack {
                Tokens.Colors.globalBackgroundDeep
                MemoryMediaStateBlock(title: Copy.yearStoryOfflineTitle, detail: Copy.yearStoryOfflineDetail, retryTitle: Copy.yearStoryErrorRetry) {
                    Task { await model.retry() }
                }
            }
        case .loaded:
            if let card = model.currentCard {
                Group {
                    if card == .summary, model.summaryStyles.count > 1 {
                        TabView(selection: $model.summaryPage) {
                            ForEach(Array(model.summaryStyles.enumerated()), id: \.offset) { index, style in
                                cardPage(card, style: style, size: size, images: images)
                                    .tag(index)
                            }
                        }
                        .tabViewStyle(.page(indexDisplayMode: .never))
                    } else {
                        cardPage(card, style: model.summaryStyle, size: size, images: images)
                    }
                }
                .onAppear { updateFrameWidth(size.width) }
                .onChange(of: size.width) { _, width in updateFrameWidth(width) }
            }
        }
    }

    private func cardPage(_ card: YearStoryCard, style: YearStorySummary.Style, size: CGSize, images: any MemoryImageLoading) -> some View {
        YearStoryCardContent(
            card: card, size: size, summary: model.summary, summaryStyle: style, coverURL: model.coverURL,
            images: images, revealed: revealsImmediately
        )
        // Tap zones (`layout.year.story.navigation`): right half next, left half previous (the summary's pages swipe).
        .contentShape(Rectangle())
        .onTapGesture { location in
            if location.x >= size.width / 2 {
                model.next()
            } else {
                model.previous()
            }
        }
        // Cards change with a cut (Wrapped's chapter animations are brand art, not reproduced).
        .id(card.id)
        .accessibilityElement(children: .contain)
        .accessibilityAction(named: Text(Copy.yearStoryA11yNext)) { model.next() }
        .accessibilityAction(named: Text(Copy.yearStoryA11yPrevious)) { model.previous() }
    }

    /// C-22 position pill, its leading edge at `dimension.year.story.frame.padding`, centred on the close circle's centre
    /// line (`RecapPreviewGeometry.closeCentreInFrame`); hidden on the summary.
    @ViewBuilder
    private func positionPill(_ geometry: RecapPreviewGeometry) -> some View {
        if model.phase == .loaded, let position = model.position {
            HStack(spacing: 0) {
                PositionPill(label: position)
                    .fixedSize()
                    .accessibilityIdentifier("year.story.position")
                Spacer(minLength: 0)
            }
            .padding(.leading, Tokens.Sizes.yearStoryFramePadding)
            .frame(width: geometry.frame.width)
            .position(x: geometry.frame.width / 2, y: geometry.closeCentreInFrame.y)
        }
    }

    // MARK: Bottom row

    /// Pause / play on the cards, replay on the summary (C-11 on media, `size.global.icon` glyph box); the shared bottom
    /// row places it at `size.global.buttonMarginH`.
    @ViewBuilder
    private var leadingCircle: some View {
        if model.phase == .loaded, let card = model.currentCard {
            Group {
                if card == .summary {
                    CircleButton(icon: Tokens.Icons.yearStoryReplay, accessibilityLabel: Copy.yearStorySummaryReplay, style: .media) {
                        model.replay()
                    }
                    .accessibilityIdentifier("year.story.replay")
                } else {
                    CircleButton(
                        icon: model.isPaused ? Tokens.Icons.globalPlay : Tokens.Icons.globalPause,
                        accessibilityLabel: model.isPaused ? Copy.yearStoryA11yPlay : Copy.yearStoryA11yPause,
                        style: .media
                    ) {
                        model.togglePause()
                    }
                    .accessibilityIdentifier("year.story.pause")
                }
            }
        }
    }

    /// The Share pill (`collage.share.layout.pill`, text role `button`) on the fact cards, the outro and the summary
    /// (fading in and out with `duration.global.fade`); elsewhere its place stays empty.
    @ViewBuilder
    private var sharePill: some View {
        ZStack {
            if model.phase == .loaded, let card = model.currentCard, card.isShareable {
                let key = model.shareKey(card)
                Group {
                    if let file = model.shareFiles[key], let image = model.shareImages[key] {
                        ShareLink(item: file, preview: SharePreview(Copy.yearStoryEntrySubtitle(year: String(year)), image: Image(uiImage: image))) {
                            RecapPillLabel(title: Copy.yearStoryShare)
                        }
                        .buttonStyle(.plain)
                        // The card stays in view while the share sheet is up (play resumes it).
                        .simultaneousGesture(TapGesture().onEnded { model.pause() })
                    } else {
                        // The share image renders when the card shows (a few milliseconds): the pill shows it is busy.
                        RecapPillLabel(title: Copy.yearStoryShare, isBusy: true)
                    }
                }
                .accessibilityIdentifier("year.story.share")
                .dsTransition(.opacity)
            }
        }
        .dsAnimation(ComponentMotion.fade, value: model.currentCard?.isShareable == true)
    }

    // MARK: Share images

    private var renderKey: String {
        let card = model.currentCard.map { model.shareKey($0) } ?? ""
        return "\(model.phase == .loaded)-\(card)-\(Int(frameWidth))" // provenance-ok: task identity, not UI text
    }

    private func updateFrameWidth(_ width: CGFloat) {
        guard width > 0, width != frameWidth else { return }
        frameWidth = width
        model.imagePixelSize = width * max(displayScale, Tokens.Layouts.YearStoryShareCard.width / width)
        model.preloadUpcoming()
    }

    /// The share image of the card in view (each summary style on its own), rendered when it shows.
    private func renderShare(images: any MemoryImageLoading) async {
        guard model.phase == .loaded, frameWidth > 0, let card = model.currentCard, card.isShareable else { return }
        let key = model.shareKey(card)
        guard model.shareFiles[key] == nil else { return }
        await Task.yield()
        guard !Task.isCancelled, let output = await YearStoryShareRenderer.render(
            card, width: frameWidth, summary: model.summary, summaryStyle: model.summaryStyle,
            coverURL: model.coverURL, images: images, name: key
        ) else { return }
        model.shareFiles[key] = output.file
        model.shareImages[key] = output.image
    }
}
