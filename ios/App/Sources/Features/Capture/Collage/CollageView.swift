// Surfaces: collage.view + collage.share — visual reference Retro's recap preview (C-34 card on a blurred backdrop, C-11
// close, C-31 dots, C-09 light pill); the collage is the worker's composition of BeReal dual images (option B pages).
// Reference images: references/auto/retro/store/retro-store-04.png (ST-04: media page, corner, close, dots 16.3 pt below
// the page, "Share" pill), references/auto/retro/press/tc-2023-12-recaps.png phones 2–3 (TC-REC: card centred on the
// blurred backdrop), references/auto/retro/press/tc-2023-12-retro-header.png (TC-H: card corners ≈ 5 %),
// references/auto/retro/press/tc-2025-12-rewind-panels.png phone 3 (system share sheet titled with the date),
// design/collage-options/option-B.jpg (design/surfaces/collage.view.md, collage.share.md; RC-14, RC-15, RC-19).
import DesignSystem
import SwiftUI
import UIKit

/// The same-moment collage of one daily invitation in the recap preview (`RecapPreviewScreen`): page 1 blurred in the
/// rounded media page, the current page as the card (aspect-fit, corners `outerRadiusRatio` × its width), the close
/// circle, the dots below the page (2+ pages), and the "Share" pill once the share image exists.
struct CollageView: View {
    @Bindable var model: CollageModel
    /// True when presented as a full-screen cover: the cover then asks for light status-bar content.
    var isPresentedModally = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        preview
            .preferredColorScheme(isPresentedModally ? .dark : nil)
            .navigationBarBackButtonHidden(true)
            .toolbar(.hidden, for: .navigationBar)
            .accessibilityIdentifier("collage.view")
            .task { await model.load() }
            .onChange(of: model.currentPage) { _, _ in
                Task { await model.pageChanged() }
            }
    }

    private var isReady: Bool { model.state == .ready && !model.pages.isEmpty }

    private var preview: some View {
        RecapPreviewScreen(
            dots: isReady && model.pageCount > 1 ? RecapPreviewDots(
                count: model.pageCount,
                index: model.currentPage - 1,
                accessibilityValue: Copy.collageViewA11yPage(page: String(model.currentPage), pages: String(model.pageCount))
            ) : nil,
            onSelectPage: { index in model.currentPage = index + 1 }
        ) { _ in
            mediaPage
                .accessibilitySortPriority(3)
        } overlay: { geometry in
            RecapPreviewClose(geometry: geometry, accessibilityLabel: Copy.collageViewA11yClose) { dismiss() }
                .accessibilitySortPriority(4)
                .accessibilityIdentifier("collage.view.close")
        } leading: {
            EmptyView()
        } trailing: {
            if model.canShare, let item = model.shareItem() {
                sharePill(item)
                    .accessibilitySortPriority(1)
            }
        }
    }

    /// The media page's content: page 1 blurred (C-34 backdrop) under the swiped cards once ready; otherwise the state on
    /// `color.global.controlOnDeep` (collage.view States).
    @ViewBuilder
    private var mediaPage: some View {
        if isReady {
            ZStack {
                BlurredBackdrop(source: model.pages[1].map { PhotoSource.image($0) })
                if model.pageCount > 1 {
                    TabView(selection: $model.currentPage) {
                        ForEach(1...model.pageCount, id: \.self) { number in
                            pageCard(number)
                                .tag(number)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .accessibilityIdentifier("collage.view.pages")
                } else {
                    pageCard(1)
                        .accessibilityIdentifier("collage.view.pages")
                }
            }
        } else {
            ZStack {
                Tokens.Colors.globalControlOnDeep
                stateContent
            }
        }
    }

    // MARK: Pages and states

    @ViewBuilder
    private var stateContent: some View {
        switch model.state {
        case .idle, .ready:
            Color.clear
        case .loading:
            CaptureMediaProgress(text: Copy.collageViewLoading)
                .accessibilityIdentifier("collage.view.loading")
        case .empty:
            EmptyStateView(
                icon: Tokens.Icons.globalCamera,
                title: Copy.collageViewEmptyTitle,
                detail: Copy.collageViewEmptyDetail,
                action: EmptyStateView.Action(Copy.collageViewEmptyButton) { model.openCamera() }
            )
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("collage.view.empty")
        case .error:
            errorLine(Copy.collageViewErrorTitle)
                .accessibilityIdentifier("collage.view.error")
        case .offline:
            errorLine(Copy.collageViewOfflineTitle)
                .accessibilityIdentifier("collage.view.offline")
        }
    }

    /// One page: the card box (`RecapPreviewMetrics.cardSize`) centred in the media page.
    private func pageCard(_ number: Int) -> some View {
        GeometryReader { proxy in
            card(number: number, size: RecapPreviewMetrics.cardSize(in: proxy.size))
                .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }

    /// The page image (9:16) as Retro's recap card: aspect-fit in the card box, corners
    /// `collage.view.layout.page.outerRadiusRatio` × its width (continuous). It appears with `duration.global.fade`.
    private func card(number: Int, size: CGSize) -> some View {
        ZStack {
            if let image = model.pages[number] {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size.width, height: size.height)
                    .clipShape(DSShape.rounded(size.width * Tokens.Layouts.CollageViewLayoutPage.outerRadiusRatio))
                    .dsTransition(.opacity)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(Text(model.pageAccessibilityLabel))
                    .accessibilityAddTraits(.isImage)
            } else {
                ProgressView()
                    .tint(Tokens.Colors.globalTextOnMedia)
            }
        }
        .frame(width: size.width, height: size.height)
        .dsAnimation(ComponentMotion.fade, value: model.pages[number] != nil)
    }

    /// Retro's list-error line: one tappable line centred, text role `body`, `color.global.textOnMedia`; tap refetches.
    private func errorLine(_ text: String) -> some View {
        Button {
            Task { await model.reload() }
        } label: {
            Text(text)
                .dsTextStyle(TextRole.body)
                .foregroundStyle(Tokens.Colors.globalTextOnMedia)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Tokens.Sizes.globalScreenMargin)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: Share (collage.share)

    /// The recap pill "Share" → the system share sheet with the current page's Stories-sized image (exported lazily,
    /// `collage.share.layout.sheet`) and the preview title `collage.share.sheetTitle` ({date}).
    private func sharePill(_ item: CollageSharePage) -> some View {
        let preview = model.pages[model.currentPage].map { Image(uiImage: $0) } ?? Image(systemName: Tokens.Icons.globalShare)
        return ShareLink(item: item, preview: SharePreview(model.shareSheetTitle, image: preview)) {
            RecapPillLabel(title: Copy.collageShareButton)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(Copy.collageShareButton))
        .accessibilityIdentifier("collage.share")
    }
}
