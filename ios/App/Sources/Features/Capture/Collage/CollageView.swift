// Surfaces: collage.view + collage.share — reference: BeReal dual image + Yope wall composition,
// Yope day view and share pill.
// Reference images: design/collage-options/option-B.jpg, references/auto/yope/frames/b-presskit-wall.png,
// references/owner/yope-week-recap.jpg, references/auto/yope/frames/b-alexaa-7652512140875566349-t5.33-day-view-recap.png,
// references/auto/yope/frames/a-itsmthuyope-7644974799302823175-t50.60-loading-hud.png,
// references/auto/yope/store/yope-store-04.png, references/auto/yope/frames/b-derot-store-04-rot-3.65.png
// (design/surfaces/collage.view.md, collage.share.md).
import DesignSystem
import SwiftUI
import UIKit

/// The same-moment collage of one daily invitation: back circle + date title, native page dots
/// (2+ pages), the 9:16 page (option B, composed by the worker), the share pill.
struct CollageView: View {
    @Bindable var model: CollageModel
    @Environment(\.dismiss) private var dismiss

    private typealias Screen = Tokens.Layouts.CollageViewLayoutScreen
    private typealias Page = Tokens.Layouts.CollageViewLayoutPage

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let bottomInset = proxy.safeAreaInsets.bottom
            let screenHeight = proxy.size.height + proxy.safeAreaInsets.top + bottomInset
            let pageArea = CGSize(width: width, height: max(0, screenHeight - Screen.pageTop))
            ZStack(alignment: .top) {
                Tokens.Colors.globalBackgroundDeep
                header(width: width)
                    .offset(y: Screen.headerCenterFromTop - Tokens.Sizes.globalHeaderButton / 2)
                if model.state == .ready && model.pageCount > 1 {
                    CollagePageControl(numberOfPages: model.pageCount, currentPage: $model.currentPage)
                        .fixedSize()
                        .frame(height: 0)
                        .offset(y: Screen.dotsCenterFromTop)
                        .accessibilitySortPriority(3)
                }
                content(area: pageArea, bottomInset: bottomInset)
                    .frame(width: pageArea.width, height: pageArea.height)
                    .offset(y: Screen.pageTop)
                if model.canShare, let item = model.shareItem() {
                    sharePill(item)
                        .frame(maxHeight: .infinity, alignment: .bottom)
                        .padding(.bottom, Tokens.Layouts.CollageShareLayoutPill.bottomFromScreenBottom)
                }
            }
            .ignoresSafeArea()
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("collage.view")
        .task { await model.load() }
        .onChange(of: model.currentPage) { _, _ in
            Task { await model.pageChanged() }
        }
    }

    // MARK: Header

    private func header(width: CGFloat) -> some View {
        ZStack {
            Text(model.title)
                .dsTextStyle(CaptureType.collageTitle)
                .foregroundStyle(Tokens.Colors.globalTextPrimary)
                .accessibilityAddTraits(.isHeader)
                .accessibilitySortPriority(4)
            HStack {
                HeaderCircleButton(icon: Tokens.Icons.globalBack, accessibilityLabel: Copy.collageViewA11yBack, fill: .onDeep) {
                    dismiss()
                }
                .accessibilitySortPriority(5)
                .accessibilityIdentifier("collage.view.back")
                Spacer()
            }
            .padding(.leading, Tokens.Sizes.globalHeaderInset)
        }
        .frame(width: width, height: Tokens.Sizes.globalHeaderButton)
    }

    // MARK: Pages and states

    @ViewBuilder
    private func content(area: CGSize, bottomInset: CGFloat) -> some View {
        // 9:16 page, aspect-fit into the space above the home indicator, centred.
        let available = CGSize(width: area.width, height: max(0, area.height - bottomInset))
        let pageWidth = min(available.width, available.height * Page.canvasAspect)
        let pageSize = CGSize(width: pageWidth, height: pageWidth / Page.canvasAspect)
        switch model.state {
        case .idle:
            Color.clear
        case .loading:
            loadingHUD
                .frame(width: pageSize.width, height: pageSize.height)
                .frame(maxWidth: .infinity, maxHeight: available.height, alignment: .top)
        case .ready:
            TabView(selection: $model.currentPage) {
                ForEach(1...model.pageCount, id: \.self) { number in
                    pageImage(number)
                        .frame(width: pageSize.width, height: pageSize.height)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                        .tag(number)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: available.height)
            .accessibilitySortPriority(2)
            .accessibilityIdentifier("collage.view.pages")
        case .empty:
            CaptureEmptyState(
                title: Copy.collageViewEmptyTitle,
                detail: Copy.collageViewEmptyDetail(group: model.groupName),
                buttonTitle: Copy.collageViewEmptyButton,
                action: { model.openCamera() }
            )
            .frame(maxWidth: .infinity, maxHeight: available.height)
            .accessibilityIdentifier("collage.view.empty")
        case .error:
            CaptureEmptyState(
                title: Copy.collageViewErrorTitle,
                buttonTitle: Copy.collageViewErrorButton,
                action: { Task { await model.reload() } }
            )
            .frame(maxWidth: .infinity, maxHeight: available.height)
            .accessibilityIdentifier("collage.view.error")
        case .offline:
            CaptureEmptyState(
                title: Copy.collageViewOfflineTitle,
                buttonTitle: Copy.collageViewErrorButton,
                action: { Task { await model.reload() } }
            )
            .frame(maxWidth: .infinity, maxHeight: available.height)
            .accessibilityIdentifier("collage.view.offline")
        }
    }

    @ViewBuilder
    private func pageImage(_ number: Int) -> some View {
        if let image = model.pages[number] {
            // The JPEG carries its own rounded corners on the matte `color.global.backgroundDeep`.
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .accessibilityLabel(model.pageAccessibilityLabel)
                .accessibilityAddTraits(.isImage)
        } else {
            loadingHUD
        }
    }

    /// Yope's loading HUD: platform activity indicator over the word.
    private var loadingHUD: some View {
        let hud = Tokens.Layouts.CollageViewLayoutHud.self
        return VStack {
            ProgressView()
            Text(Copy.collageViewLoading)
                .dsTextStyle(CaptureType.body)
                .foregroundStyle(Tokens.Colors.globalTextPrimary)
        }
        .frame(width: hud.width, height: hud.height)
        .background(Tokens.Colors.collageViewColorHud, in: RoundedRectangle(cornerRadius: hud.cornerRadius, style: .continuous))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("collage.view.loading")
    }

    // MARK: Share

    /// The share pill (`collage.share.layout.pill`). Its frosted fill `collage.share.color.pill` is
    /// BLOCKED and not drawn; glyph and label are `color.global.textPrimary`.
    private func sharePill(_ item: CollageSharePage) -> some View {
        let pill = Tokens.Layouts.CollageShareLayoutPill.self
        let preview = model.pages[model.currentPage].map { Image(uiImage: $0) } ?? Image(systemName: Tokens.Icons.collageShareIconShare)
        return ShareLink(item: item, preview: SharePreview(Copy.collageShareSheetTitle, image: preview)) {
            HStack {
                Image(systemName: Tokens.Icons.collageShareIconShare)
                    .resizable()
                    .scaledToFit()
                    .frame(width: pill.glyph, height: pill.glyph)
                    .accessibilityHidden(true)
                Text(Copy.collageShareButton)
                    .dsTextStyle(CaptureType.shareLabel)
            }
            .foregroundStyle(Tokens.Colors.globalTextPrimary)
            .frame(width: pill.width, height: pill.height)
            .contentShape(RoundedRectangle(cornerRadius: pill.cornerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Copy.collageShareButton)
        .accessibilitySortPriority(1)
        .accessibilityIdentifier("collage.share")
    }
}

/// The native page control (iOS uses it on this kind of screen, MERGE_DECISIONS C-22).
struct CollagePageControl: UIViewRepresentable {
    let numberOfPages: Int
    @Binding var currentPage: Int

    func makeUIView(context: Context) -> UIPageControl {
        let control = UIPageControl()
        control.hidesForSinglePage = true
        control.addTarget(context.coordinator, action: #selector(Coordinator.changed(_:)), for: .valueChanged)
        return control
    }

    func updateUIView(_ control: UIPageControl, context: Context) {
        context.coordinator.binding = $currentPage
        control.numberOfPages = numberOfPages
        control.currentPage = max(0, currentPage - 1)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(binding: $currentPage)
    }

    @MainActor
    final class Coordinator: NSObject {
        var binding: Binding<Int>

        init(binding: Binding<Int>) {
            self.binding = binding
        }

        @objc func changed(_ control: UIPageControl) {
            binding.wrappedValue = control.currentPage + 1
        }
    }
}
