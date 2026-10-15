// Surface: onthisday — reference: Timehop.
// Reference images: references/auto/timehop/store/timehop-store-01.png, -02.png, -03.png, -05.png;
// references/auto/timehop/play/timehop-play-01.png, -02.png, -05.png;
// references/auto/timehop/help/th-help-2023-04-memory-view-hide.png, th-help-2024-03-intro-day-in-history.jpg,
// th-help-2024-02-panel-share-1-year-ago.png (design/surfaces/onthisday.md).
import AppData
import DesignSystem
import SwiftUI
import UIKit

/// The day: one full-screen page per year, newest year first, tapped through like Timehop.
/// Present it with `.fullScreenCover` (the `OnThisDayEntry` row does).
@MainActor
struct OnThisDayScreen: View {
    @State private var model: OnThisDayModel
    @Environment(\.dismiss) private var dismiss

    init(groupID: String, model: OnThisDayModel? = nil) {
        _model = State(initialValue: model ?? OnThisDayModel(groupID: GroupID(groupID), dependencies: .current))
    }

    var body: some View {
        GeometryReader { proxy in
            let safeTop = proxy.safeAreaInsets.top
            VStack(spacing: 0) {
                banner(safeTop: safeTop)
                // Year → year: the content cross-fades over `duration.onthisday.memoryChange` with the
                // platform's ease-in-out (`easing.global.native`); a cross-fade is already the Reduce
                // Motion substitute, so it is the same with the setting on. Only the content animates:
                // the banner label and the progress fill jump with the year (onthisday.md § Motion).
                ZStack {
                    content(width: proxy.size.width)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
                .animation(Self.memoryChange, value: model.currentYear?.id)
            }
            .background(Tokens.Colors.globalBackground)
            .ignoresSafeArea()
        }
        .toolbar(.hidden, for: .navigationBar)
        .task { await model.loadIfNeeded() }
        .onDisappear { model.stopListening() }
        .onChange(of: model.isFinished) { _, finished in
            if finished { dismiss() }
        }
        .onChange(of: model.index) { _, _ in
            UIAccessibility.post(notification: .screenChanged, argument: nil)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("onthisday")
    }

    /// `duration.onthisday.memoryChange` on the native ease-in-out curve.
    static let memoryChange = DSAnimation.timing(duration: Tokens.Durations.onthisdayMemoryChange, easing: .easeInOut).animation

    // MARK: Banner

    private func banner(safeTop: CGFloat) -> some View {
        OnThisDayBannerLayout(safeTop: safeTop) {
            progressBar
            Text(model.phase == .loaded ? (model.currentYear.map { model.bannerLabel(for: $0) } ?? "") : "")
                .dsTextStyle(OnThisDayType.bannerLabel)
                .foregroundStyle(Tokens.Colors.onthisdayBannerLabel)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
                .accessibilityHidden(model.phase != .loaded)
            MemoryHeaderCircle(icon: Tokens.Icons.globalClose, label: Copy.onthisdayA11yClose) {
                model.close()
            }
            .accessibilityIdentifier("onthisday.close")
        }
        .frame(maxWidth: .infinity)
        .background(Tokens.Colors.onthisdayBanner)
    }

    @ViewBuilder
    private var progressBar: some View {
        if model.phase == .loaded {
            GeometryReader { bar in
                ZStack(alignment: .leading) {
                    Tokens.Colors.onthisdayProgressTrack
                    Tokens.Colors.onthisdayProgressFill
                        .frame(width: bar.size.width * model.progress)
                }
            }
            .accessibilityHidden(true)
        } else {
            Color.clear
        }
    }

    // MARK: Content

    @ViewBuilder
    private func content(width: CGFloat) -> some View {
        switch model.phase {
        case .idle, .loading:
            MemoryLoadingIndicator(text: Copy.onthisdayLoading)
        case .error:
            MemoryStateMessage(title: Copy.onthisdayErrorTitle, detail: Copy.onthisdayErrorDetail, actionTitle: Copy.onthisdayErrorRetry) {
                Task { await model.retry() }
            }
            .padding(.horizontal, Tokens.Sizes.globalScreenMargin)
        case .offline:
            MemoryStateMessage(title: Copy.onthisdayOfflineTitle, detail: Copy.onthisdayOfflineDetail, actionTitle: Copy.onthisdayErrorRetry) {
                Task { await model.retry() }
            }
            .padding(.horizontal, Tokens.Sizes.globalScreenMargin)
        case .loaded:
            if let year = model.currentYear {
                Group {
                    if year.photos.count == 1, let photo = year.photos.first {
                        singlePhoto(photo, width: width)
                    } else {
                        grid(year, width: width)
                    }
                }
                // Keyed by year so a year change swaps the content (cross-fade, see `body`).
                .id(year.id)
                .transition(.opacity)
            }
        }
    }

    /// `layout.onthisday.photo.single`: full width, banner bottom to screen bottom, cropped, no corners.
    private func singlePhoto(_ photo: OnThisDayModel.Photo, width: CGFloat) -> some View {
        MemoryRemoteImage(url: photo.displayURL)
            .overlay(alignment: .topLeading) { metaRow(photo) }
            .contentShape(Rectangle())
            .onTapGesture(coordinateSpace: .local) { location in tap(at: location, width: width) }
            .accessibilityElement()
            .accessibilityLabel(model.accessibilityLabel(for: photo))
            .accessibilityAddTraits(.isImage)
            .modifier(OnThisDayNavigationActions(model: model))
    }

    /// Avatar (`dimension.onthisday.meta.avatar`) and "TUE 10:34 PM" over the photo's top-left.
    private func metaRow(_ photo: OnThisDayModel.Photo) -> some View {
        HStack(spacing: Tokens.Sizes.onthisdayMetaGap) {
            ZStack {
                Circle().fill(Tokens.Colors.globalControl)
                if photo.avatarURL == nil {
                    // No glyph-size token: the glyph takes the meta row's text size.
                    Image(systemName: Tokens.Icons.globalPerson)
                        .dsTextStyle(OnThisDayType.meta)
                        .foregroundStyle(Tokens.Colors.globalTextSecondary)
                } else {
                    MemoryRemoteImage(url: photo.avatarURL)
                        .clipShape(Circle())
                }
            }
            .frame(width: Tokens.Sizes.onthisdayMetaAvatar, height: Tokens.Sizes.onthisdayMetaAvatar)
            Text(model.meta(for: photo))
                .dsTextStyle(OnThisDayType.meta)
                .foregroundStyle(Tokens.Colors.onthisdayMetaText)
        }
        .frame(height: Tokens.Sizes.onthisdayMetaCenterY * 2, alignment: .center)
        .padding(.leading, Tokens.Sizes.onthisdayMetaInset)
        .accessibilityHidden(true)
    }

    /// `layout.onthisday.grid`: 2-column masonry, thumbs, newest first; scrolls under the banner.
    private func grid(_ year: OnThisDayModel.Year, width: CGFloat) -> some View {
        ScrollView(.vertical) {
            OnThisDayMasonry(
                columns: Int(Tokens.Layouts.OnthisdayGrid.columns),
                spacing: Tokens.Sizes.onthisdayGridGutter,
                aspectRatios: year.photos.map { $0.aspectRatio ?? OnThisDayMasonry.unknownAspectRatio }
            ) {
                ForEach(year.photos) { photo in
                    MemoryRemoteImage(url: photo.thumbURL)
                        .accessibilityElement()
                        .accessibilityLabel(model.accessibilityLabel(for: photo))
                        .accessibilityAddTraits(.isImage)
                        .modifier(OnThisDayNavigationActions(model: model))
                }
            }
            .padding(.horizontal, Tokens.Sizes.onthisdayGridMargin)
            .padding(.top, Tokens.Sizes.onthisdayGridTop)
            .contentShape(Rectangle())
            .onTapGesture(coordinateSpace: .local) { location in tap(at: location, width: width) }
        }
        .scrollIndicators(.hidden)
        .background(Tokens.Colors.globalBackground)
    }

    /// Right half → older year (closes after the oldest); left half → newer year.
    private func tap(at location: CGPoint, width: CGFloat) {
        guard width > 0 else { return }
        if location.x >= width / 2 {
            model.next()
        } else {
            model.previous()
        }
    }
}

/// `onthisday.a11y.next` ("Older") / `onthisday.a11y.previous` ("Back") as custom actions, since
/// VoiceOver cannot reach the tap zones.
private struct OnThisDayNavigationActions: ViewModifier {
    let model: OnThisDayModel

    func body(content: Content) -> some View {
        content
            .accessibilityAction(named: Copy.onthisdayA11yNext) { model.next() }
            .accessibilityAction(named: Copy.onthisdayA11yPrevious) { model.previous() }
    }
}

// MARK: - Layouts

/// The banner (`layout.onthisday.banner`): from the screen top to `dimension.onthisday.banner.height`
/// (grows with the label at large Dynamic Type sizes); progress bar on its top edge directly below
/// the status bar; label baseline `dimension.onthisday.banner.labelBaseline` above the bottom;
/// close circle `size.global.headerInset` from the right, centred on the label's row.
/// Subviews: progress bar, label, close.
struct OnThisDayBannerLayout: Layout {
    let safeTop: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 0
        guard subviews.count == 3 else { return CGSize(width: width, height: Tokens.Sizes.onthisdayBannerHeight) }
        let label = subviews[1].dimensions(in: ProposedViewSize(width: width, height: nil))
        let natural = safeTop + Tokens.Sizes.onthisdayProgressHeight + label[.lastTextBaseline] + Tokens.Sizes.onthisdayBannerLabelBaseline
        return CGSize(width: width, height: max(Tokens.Sizes.onthisdayBannerHeight, natural))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard subviews.count == 3 else { return }
        subviews[0].place(
            at: CGPoint(x: bounds.minX, y: bounds.minY + safeTop),
            anchor: .topLeading,
            proposal: ProposedViewSize(width: bounds.width, height: Tokens.Sizes.onthisdayProgressHeight)
        )
        let labelProposal = ProposedViewSize(width: bounds.width, height: nil)
        let label = subviews[1].dimensions(in: labelProposal)
        let baselineY = bounds.maxY - Tokens.Sizes.onthisdayBannerLabelBaseline
        let labelTop = baselineY - label[.lastTextBaseline]
        subviews[1].place(at: CGPoint(x: bounds.midX, y: labelTop), anchor: .top, proposal: labelProposal)
        let closeSize = Tokens.Sizes.globalHeaderButton
        subviews[2].place(
            at: CGPoint(x: bounds.maxX - Tokens.Sizes.globalHeaderInset - closeSize / 2, y: labelTop + label.height / 2),
            anchor: .center,
            proposal: ProposedViewSize(width: closeSize, height: closeSize)
        )
    }
}

/// Two-column masonry (`layout.onthisday.grid`): each photo keeps its aspect ratio and goes to
/// the shorter column; `spacing` between columns and rows.
struct OnThisDayMasonry: Layout {
    let columns: Int
    let spacing: CGFloat
    let aspectRatios: [CGFloat]

    /// Until the photo's own size is known it is laid out square.
    static let unknownAspectRatio: CGFloat = 1 // provenance-ok: placeholder ratio for a photo without stored dimensions

    struct Placement {
        let column: Int
        let y: CGFloat
        let height: CGFloat
    }

    func placements(width: CGFloat, count: Int) -> (items: [Placement], height: CGFloat) {
        let columnCount = max(columns, 1)
        let columnWidth = max(0, (width - spacing * CGFloat(columnCount - 1)) / CGFloat(columnCount))
        var heights = Array(repeating: CGFloat(0), count: columnCount)
        var items: [Placement] = []
        for index in 0..<count {
            let ratio = aspectRatios.indices.contains(index) && aspectRatios[index] > 0 ? aspectRatios[index] : Self.unknownAspectRatio
            let height = columnWidth / ratio
            let column = heights.indices.min { heights[$0] < heights[$1] } ?? 0
            let y = heights[column] == 0 ? 0 : heights[column] + spacing
            items.append(Placement(column: column, y: y, height: height))
            heights[column] = y + height
        }
        return (items, heights.max() ?? 0)
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 0
        return CGSize(width: width, height: placements(width: width, count: subviews.count).height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let columnCount = max(columns, 1)
        let columnWidth = max(0, (bounds.width - spacing * CGFloat(columnCount - 1)) / CGFloat(columnCount))
        let layout = placements(width: bounds.width, count: subviews.count)
        for (index, subview) in subviews.enumerated() {
            let item = layout.items[index]
            subview.place(
                at: CGPoint(x: bounds.minX + CGFloat(item.column) * (columnWidth + spacing), y: bounds.minY + item.y),
                anchor: .topLeading,
                proposal: ProposedViewSize(width: columnWidth, height: item.height)
            )
        }
    }
}

// MARK: - Text roles

enum OnThisDayType {
    static var bannerLabel: DSTextStyle {
        MemoryType.style(Tokens.Fonts.onthisday, size: Tokens.FontSizes.onthisdayBannerLabel,
                         weight: Tokens.FontWeights.fontWeightOnthisdayBannerLabel,
                         relativeTo: Tokens.Layouts.OnthisdayTextStyleMap.bannerLabel)
    }

    static var meta: DSTextStyle {
        MemoryType.style(Tokens.Fonts.onthisday, size: Tokens.FontSizes.onthisdayMeta,
                         weight: Tokens.FontWeights.fontWeightOnthisdayMeta,
                         relativeTo: Tokens.Layouts.OnthisdayTextStyleMap.meta)
    }
}
