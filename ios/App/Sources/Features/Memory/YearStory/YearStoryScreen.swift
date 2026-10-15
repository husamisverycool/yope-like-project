// Surface: year.story — reference: Spotify Wrapped (2024 tap-through).
// Reference images: references/auto/wrapped/frames/wrapped24-rec-emilycraig-t020.png, -t020-bars-zoom2x.png,
// -t15.533-reveal-start.png, -t16.400-reveal-end.png, -sheet-every3s.png; references/auto/wrapped/press/wrapped24-press-minutes.jpg,
// wrapped24-press-summary-sharecard.jpg, wrapped25-press-minutes.png, wrapped25-press-sharecards.png, wrapped25-press-entrypoints.png;
// references/auto/wrapped/frames/wrapped25-rec-cdragon2010-t004.800.png, -t258.000.png, wrapped24-rec-xenarxoxo-sheet-every3s.png
// (design/surfaces/year.story.md). Replaces the container ios/App/Sources/Screens/YearStoryScreen.swift (`AppRoute.yearStory`).
import AppData
import DesignSystem
import SwiftUI
import UIKit

/// The group's December year story: Wrapped-style tap-through cards on a 9:16 canvas, one fact per
/// card, each fact card shareable as a 1080 × 1920 image. Present full screen (`YearStoryEntry`
/// does; the deep link pushes it on the main stack with the navigation bar hidden).
@MainActor
struct YearStoryScreen: View {
    let groupID: String
    let year: Int
    @State private var model: YearStoryModel
    /// Snapshots: subline shown at once instead of the reveal.
    private let revealsImmediately: Bool
    @Environment(\.dismiss) private var dismiss

    init(groupID: String, year: Int, model: YearStoryModel? = nil, revealsImmediately: Bool = false) {
        self.groupID = groupID
        self.year = year
        _model = State(initialValue: model ?? YearStoryModel(groupID: GroupID(groupID), year: year, dependencies: .current))
        self.revealsImmediately = revealsImmediately
    }

    var body: some View {
        GeometryReader { proxy in
            let canvas = YearStoryGeometry.canvasSize(in: proxy.size)
            ZStack {
                Tokens.Colors.yearStoryLetterbox
                    .ignoresSafeArea()
                YearStoryCanvasView(model: model, size: canvas, revealsImmediately: revealsImmediately)
                    .frame(width: canvas.width, height: canvas.height)
                    .task(id: renderKey(width: canvas.width)) {
                        await renderShares(width: canvas.width)
                    }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .statusBarHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .task { await model.loadIfNeeded() }
        .onDisappear { model.stopListening() }
        .onChange(of: model.isFinished) { _, finished in
            if finished { dismiss() }
        }
        .onChange(of: model.index) { _, _ in
            UIAccessibility.post(notification: .screenChanged, argument: nil)
        }
        .accessibilityIdentifier("year.story")
    }

    /// Share images are rendered when a fact card is shown, and all of them on the summary.
    private func renderKey(width: CGFloat) -> String {
        "\(model.phase == .loaded)-\(model.currentCard?.id ?? "")-\(Int(width))" // provenance-ok: task identity, not UI text
    }

    private func renderShares(width: CGFloat) async {
        guard model.phase == .loaded, let card = model.currentCard else { return }
        let targets = card == .summary ? model.shareableCards : (card.isShareable ? [card] : [])
        for target in targets where model.shareFiles[target.id] == nil {
            guard let output = await YearStoryShareRenderer.render(target, width: width, images: model.images) else { continue }
            model.shareFiles[target.id] = output.file
            model.shareImages[target.id] = output.image
        }
    }
}

/// The canvas with progress bar, chrome, card content, share row and tap zones.
struct YearStoryCanvasView: View {
    let model: YearStoryModel
    let size: CGSize
    var revealsImmediately = false

    var body: some View {
        ZStack(alignment: .topLeading) {
            Tokens.Colors.globalBackgroundDeep
            switch model.phase {
            case .idle, .loading:
                MemoryLoadingIndicator(text: Copy.yearStoryLoading)
                    .frame(width: size.width, height: size.height)
            case .error:
                stateMessage(title: Copy.yearStoryErrorTitle, detail: Copy.yearStoryErrorDetail)
            case .offline:
                stateMessage(title: Copy.yearStoryOfflineTitle, detail: Copy.yearStoryOfflineDetail)
            case .loaded:
                if let card = model.currentCard {
                    cardLayer(card)
                }
            }
            chrome
        }
        .frame(width: size.width, height: size.height)
        .clipped()
    }

    private func stateMessage(title: String, detail: String) -> some View {
        MemoryStateMessage(title: title, detail: detail, actionTitle: Copy.yearStoryErrorRetry) {
            Task { await model.retry() }
        }
        .frame(maxWidth: Tokens.Sizes.yearStoryTextMaxWidth)
        .frame(width: size.width, height: size.height)
    }

    @ViewBuilder
    private func cardLayer(_ card: YearStoryCard) -> some View {
        ZStack(alignment: .topLeading) {
            Group {
                if card == .summary {
                    YearStorySummaryView(model: model, size: size)
                } else {
                    YearStoryCardContent(card: card, size: size, revealed: revealsImmediately)
                }
            }
            // Cards change with a cut (Wrapped's chapter transitions are brand animation).
            .id(card.id)
            .accessibilityElement(children: .contain)
            .modifier(YearStoryNavigationActions(model: model))
            // Tap zones (`layout.year.story.navigation`): right half next, left half previous.
            .contentShape(Rectangle())
            .onTapGesture(coordinateSpace: .local) { location in
                if location.x >= size.width / 2 {
                    model.next()
                } else {
                    model.previous()
                }
            }
            YearStoryProgressBar(count: model.cards.count, index: model.index)
                .padding(.top, Tokens.Sizes.yearStoryProgressTop)
                .allowsHitTesting(false)
            if card.isShareable {
                shareRow(card)
                    .frame(width: size.width, height: size.height - Tokens.Sizes.yearStoryShareBottomInset, alignment: .bottom)
            }
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
    }

    @ViewBuilder
    private func shareRow(_ card: YearStoryCard) -> some View {
        if let file = model.shareFiles[card.id], let image = model.shareImages[card.id] {
            ShareLink(item: file, preview: SharePreview(card.headline, image: Image(uiImage: image))) {
                YearStoryShareRowLabel()
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("year.story.share")
            .accessibilitySortPriority(-1)
        } else {
            YearStoryShareRowLabel()
                .accessibilityIdentifier("year.story.share")
                .accessibilitySortPriority(-1)
        }
    }

    /// Close circle (`dimension.year.story.chrome.*`), centred `chrome.centerY` below the canvas top,
    /// `chrome.insetRight` from its right; hit area `size.global.minTouchTarget.ios`. The pause
    /// circle is not shown while `duration.year.story.card` is BLOCKED (no auto-advance).
    private var chrome: some View {
        let diameter = Tokens.Sizes.yearStoryChromeButton
        let hit = max(Tokens.Sizes.globalMinTouchTargetIos, diameter)
        return Button {
            model.close()
        } label: {
            Image(systemName: Tokens.Icons.globalClose)
                .resizable()
                .scaledToFit()
                .frame(height: Tokens.Sizes.yearStoryChromeGlyph)
                .foregroundStyle(Tokens.Colors.globalTextPrimary)
                .frame(width: diameter, height: diameter)
                .background(Tokens.Colors.yearStoryChromeFill, in: Circle())
                .frame(width: hit, height: hit)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Copy.yearStoryA11yClose)
        .accessibilityIdentifier("year.story.close")
        .accessibilitySortPriority(3)
        .position(
            x: size.width - Tokens.Sizes.yearStoryChromeInsetRight - diameter / 2,
            y: Tokens.Sizes.yearStoryChromeCenterY
        )
    }
}

/// `year.story.a11y.next` / `.previous` as custom actions (the tap zones are not reachable by VoiceOver).
private struct YearStoryNavigationActions: ViewModifier {
    let model: YearStoryModel

    func body(content: Content) -> some View {
        content
            .accessibilityAction(named: Copy.yearStoryA11yNext) { model.next() }
            .accessibilityAction(named: Copy.yearStoryA11yPrevious) { model.previous() }
    }
}

/// C. Summary (`layout.year.story.summary`): a pager of the story's share cards at
/// `previewWidthRatio` × canvas width, the Share pill for the card in view, then "Replay from
/// beginning". Page dots are BLOCKED (`layout.year.story.summary.dots`) → none.
struct YearStorySummaryView: View {
    @Bindable var model: YearStoryModel
    let size: CGSize

    var body: some View {
        let cards = model.shareableCards
        let previewWidth = size.width * Tokens.Layouts.YearStorySummary.previewWidthRatio
        let previewHeight = previewWidth / YearStoryGeometry.aspect
        VStack {
            if !cards.isEmpty {
                TabView(selection: $model.summaryPage) {
                    ForEach(Array(cards.enumerated()), id: \.element.id) { page, card in
                        preview(card)
                            .frame(width: previewWidth, height: previewHeight)
                            // The pager takes its own taps (no navigation from a tap on a share card).
                            .onTapGesture {}
                            .tag(page)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(width: size.width, height: previewHeight)
                .accessibilityIdentifier("year.story.summary.pager")
                sharePill(cards)
            }
            Button {
                model.replay()
            } label: {
                Label {
                    Text(Copy.yearStorySummaryReplay)
                } icon: {
                    Image(systemName: Tokens.Icons.yearStoryReplay)
                }
                .labelStyle(.titleAndIcon)
                .dsTextStyle(YearStoryType.body)
                .foregroundStyle(Tokens.Colors.globalTextPrimary)
                .frame(minHeight: Tokens.Sizes.globalMinTouchTargetIos)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("year.story.replay")
        }
        .frame(width: size.width, height: size.height)
    }

    @ViewBuilder
    private func preview(_ card: YearStoryCard) -> some View {
        if let image = model.shareImages[card.id] {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .accessibilityLabel(card.headline)
        } else {
            MemoryLoadingIndicator()
        }
    }

    @ViewBuilder
    private func sharePill(_ cards: [YearStoryCard]) -> some View {
        let page = min(max(model.summaryPage, 0), cards.count - 1)
        let card = cards[page]
        if let file = model.shareFiles[card.id], let image = model.shareImages[card.id] {
            ShareLink(item: file, preview: SharePreview(card.headline, image: Image(uiImage: image))) {
                YearStorySharePillLabel()
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("year.story.summary.share")
        } else {
            YearStorySharePillLabel()
                .accessibilityIdentifier("year.story.summary.share")
        }
    }
}
