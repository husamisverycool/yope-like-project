// Surface: onthisday — Retro Rewind (design/surfaces/onthisday.md B–D; MERGE RM-2…RM-7).
// Reference images: references/auto/retro/press/tc-2025-12-rewind-device-b.jpg (RWB, dial at rest, share / random glass
// circles, 'Jul 22, 2022'), references/auto/retro/press/tc-2025-12-rewind-device-a.png (RWA, title and '•••' glass),
// references/auto/retro/press/tc-2025-12-rewind-panels.png (RWP, playing / menu / share sheet),
// references/auto/retro/store/retro-store-05.png (ST-05, the subtitle). Components: C-35 full-bleed media page (composed
// here with a pushed C-02 back chevron, which `FullBleedMediaPage` does not carry), C-11 glass circles, C-29 menu /
// feature intro / alerts, C-27 / C-28 states.
import AppData
import DesignSystem
import SwiftUI
import UIKit

/// One memory at a time, full bleed on black (dark in both appearances, `layout.global.appearance.media`): the date in
/// the display serif with the poster under it, '•••' (save / report / delete), and the control row — share, the dial,
/// random. Pushed on the group's stack with the bar hidden; the back chevron pops.
@MainActor
struct OnThisDayScreen: View {
    let groupID: String
    @State private var model: OnThisDayModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.displayScale) private var displayScale

    init(groupID: String, model: OnThisDayModel? = nil) {
        self.groupID = groupID
        _model = State(initialValue: model ?? OnThisDayModel(groupID: GroupID(groupID), dependencies: .current))
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Tokens.Colors.globalBackgroundDeep
                    .ignoresSafeArea()
                if model.phase == .loaded {
                    photo
                    PhotoScrim()
                        .ignoresSafeArea()
                }
                content
            }
            .onAppear {
                let longest = max(proxy.size.width, proxy.size.height + proxy.safeAreaInsets.top + proxy.safeAreaInsets.bottom)
                model.imagePixelSize = longest * displayScale
                model.preloadNeighbours()
            }
        }
        // The media page is dark in both appearances; its sheets follow the system (RM-16).
        .environment(\.colorScheme, .dark)
        .toolbar(.hidden, for: .navigationBar)
        // Pushed with the bar hidden: the edge swipe still pops. The light status bar is set at the push site
        // (the shell's `.mediaStatusBar()` around `MemoryDestination`).
        .memoryInteractivePop()
        .task { await model.loadIfNeeded() }
        .onDisappear { model.stopListening() }
        .onChange(of: model.current?.id) { _, _ in
            // After a dial change the new date title is announced.
            if UIAccessibility.isVoiceOverRunning, !model.title.isEmpty {
                AccessibilityNotification.Announcement(model.title).post()
            }
        }
        .sheet(isPresented: $model.showsIntro, onDismiss: { model.dismissIntro() }) {
            FeatureIntroSheet(
                title: Copy.onthisdayNuxTitle,
                rows: [FeatureIntroRow(icon: Tokens.Icons.globalRewind, text: Copy.onthisdayNuxMessage(group: model.groupName))],
                buttonTitle: Copy.onthisdayNuxButton,
                onButton: { model.dismissIntro() }
            )
            .presentationDetents([.medium])
            .dsSheetBackground()
            .environment(\.colorScheme, SystemAppearance.colorScheme)
            // The page's controller is dark (the shell's `.mediaStatusBar()`); the sheet's chrome follows the system.
            .preferredColorScheme(SystemAppearance.colorScheme)
            // A container: without .contain its identifier would replace every child's (XCUITest).
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("onthisday.intro")
        }
        .alert(
            Copy.onthisdayDeleteTitle,
            isPresented: Binding(get: { model.deleteCandidate != nil }, set: { if !$0 { model.deleteCandidate = nil } }),
            presenting: model.deleteCandidate
        ) { memory in
            Button(Copy.onthisdayDeleteConfirm, role: .destructive) {
                Task { await model.confirmDelete(memory) }
            }
            Button(Copy.onthisdayDeleteCancel, role: .cancel) {}
        } message: { _ in
            Text(Copy.onthisdayDeleteMessage(group: model.groupName))
        }
        .alert(Copy.onthisdaySaveDeniedTitle, isPresented: $model.showsSaveDenied) {
            Button(Copy.onthisdaySaveDeniedButton) {
                if let settings = URL(string: UIApplication.openSettingsURLString) { openURL(settings) }
            }
        } message: {
            Text(Copy.onthisdaySaveDeniedMessage)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("onthisday")
    }

    // MARK: Photo

    /// The memory's display rendition, full bleed under the status bar, aspect-fill (`radius.global.photo` 0). A dial step
    /// cross-fades over `duration.global.crossfade`, a step while playing over `duration.onthisday.memoryChange`.
    private var photo: some View {
        ZStack {
            ForEach([model.current].compactMap { $0 }) { memory in
                MemoryRemoteImage(url: memory.displayURL)
                    .transition(.opacity)
            }
        }
        .ignoresSafeArea()
        .animation(
            (model.lastChange == .play ? Self.playChange : ComponentMotion.crossfade).resolved(reduceMotion: false),
            value: model.current?.id
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(model.photoLabel))
        .accessibilityAddTraits(.isImage)
        .accessibilitySortPriority(5)
    }

    /// `duration.onthisday.memoryChange` with `easing.global.standard` (a cross-fade: the same under Reduce Motion).
    private static let playChange = DSAnimation.timing(duration: Tokens.Durations.onthisdayMemoryChange, easing: Tokens.Easings.globalStandard)

    // MARK: Foreground

    @ViewBuilder
    private var content: some View {
        VStack(spacing: 0) {
            header
            switch model.phase {
            case .idle, .loading:
                Spacer(minLength: 0)
                MemoryLoadingIndicator(announcement: Copy.onthisdayLoading)
                Spacer(minLength: 0)
            case .loaded:
                Spacer(minLength: 0)
                controls
                    .padding(.bottom, Tokens.Sizes.onthisdayControlsCenterY - Tokens.Sizes.onthisdayDialDiameter / 2)
            case .empty:
                Spacer(minLength: 0)
                EmptyStateView(title: Copy.onthisdayEmptyTitle)
                    .accessibilityIdentifier("onthisday.empty")
                Spacer(minLength: 0)
            case .error:
                Spacer(minLength: 0)
                MemoryMediaStateBlock(
                    title: Copy.onthisdayErrorTitle, detail: Copy.onthisdayErrorDetail, retryTitle: Copy.onthisdayErrorRetry
                ) {
                    Task { await model.retry() }
                }
                Spacer(minLength: 0)
            case .offline:
                Spacer(minLength: 0)
                MemoryMediaStateBlock(
                    title: Copy.onthisdayOfflineTitle, detail: Copy.onthisdayOfflineDetail, retryTitle: Copy.onthisdayErrorRetry
                ) {
                    Task { await model.retry() }
                }
                Spacer(minLength: 0)
            }
        }
    }

    // MARK: Header (C-02 on media, C-35 title)

    /// The back chevron's width at its symbol size (`size.global.icon`, as C-02 draws it), so the title starts
    /// `size.global.headerGap` after it and the subtitle shares the title's leading edge.
    private static let backChevronWidth: CGFloat = {
        let configuration = UIImage.SymbolConfiguration(pointSize: Tokens.Sizes.globalIcon, weight: .regular)
        return UIImage(systemName: Tokens.Icons.globalBack, withConfiguration: configuration)?.size.width ?? Tokens.Sizes.globalIcon
    }()

    private var titleLeading: CGFloat {
        Tokens.Sizes.globalBackInset + Self.backChevronWidth + Tokens.Sizes.globalHeaderGap
    }

    /// The date title's first baseline `size.global.titleTop` below the safe-area top (text role `headerTitle` in the
    /// display serif, `color.global.textOnMedia`, wrapping to two lines at large sizes); the back chevron (ink at
    /// `size.global.backInset`) and the '•••' glass circle (`size.global.circleButtonPhoto`, ink `size.global.headerInset`
    /// from the right) centred on its cap middle; the subtitle's baseline `dimension.onthisday.subtitleBaseline` below the
    /// title's last baseline, on the title's leading edge.
    private var header: some View {
        MetricStack {
            titleLine
                .metricGap(Tokens.Sizes.globalTitleTop, from: .top, to: .firstBaseline)
            if model.phase == .loaded, let subtitle = model.subtitle {
                Text(subtitle)
                    .dsTextStyle(TextRole.textButton)
                    .foregroundStyle(Tokens.Colors.onthisdaySubtitle)
                    .padding(.leading, titleLeading)
                    .padding(.trailing, Tokens.Sizes.globalScreenMargin)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .dsAnimation(ComponentMotion.crossfade, value: subtitle)
                    .accessibilitySortPriority(7)
                    .accessibilityIdentifier("onthisday.subtitle")
                    .metricGap(Tokens.Sizes.onthisdaySubtitleBaseline, from: .lastBaseline, to: .firstBaseline)
            }
        }
    }

    /// The mode menu (and its chevron) belong to a loaded page.
    private var showsModeMenu: Bool { model.phase == .loaded && model.current != nil }

    /// The chevron's room after the title: `dimension.onthisday.modeChevron.gap` + `.width`.
    private static let modeChevronReserve = Tokens.Sizes.onthisdayModeChevronGap + Tokens.Sizes.onthisdayModeChevronWidth

    /// The date title with, on a loaded page, the expand chevron after it (RWA 'May 1, 2019 ⌄': ink
    /// `dimension.onthisday.modeChevron.width` wide, `dimension.onthisday.modeChevron.gap` after the title, centred
    /// `dimension.onthisday.modeChevron.drop` below its cap middle). Title and chevron open the mode menu; for VoiceOver the
    /// menu is the title (header, pop-up button).
    private var titleLine: some View {
        Text(model.phase == .loaded ? model.title : "")
            .dsTextRole(TextRole.headerTitle)
            .foregroundStyle(Tokens.Colors.globalTextOnMedia)
            .accessibilityHidden(true)
            .overlay(alignment: Alignment(horizontal: .trailing, vertical: .capMiddle)) {
                if showsModeMenu {
                    ModeChevron()
                        .alignmentGuide(HorizontalAlignment.trailing) { dimensions in
                            dimensions[HorizontalAlignment.leading] - Tokens.Sizes.onthisdayModeChevronGap
                        }
                        .alignmentGuide(.capMiddle) { dimensions in
                            dimensions[VerticalAlignment.center] - Tokens.Sizes.onthisdayModeChevronDrop
                        }
                }
            }
            .overlay(alignment: .topLeading) {
                if showsModeMenu {
                    modeMenu
                }
            }
            .padding(.leading, titleLeading)
            .padding(
                .trailing,
                Tokens.Sizes.globalHeaderInset + Tokens.Sizes.globalCircleButtonPhoto + Tokens.Sizes.globalHeaderGap
                    + (showsModeMenu ? Self.modeChevronReserve : 0)
            )
            .frame(maxWidth: .infinity, alignment: .leading)
            .dsAnimation(ComponentMotion.crossfade, value: model.title)
            .overlay(alignment: Alignment(horizontal: .leading, vertical: .capMiddle)) {
                backButton
                    .padding(.leading, Tokens.Sizes.globalBackInset)
            }
            .overlay(alignment: Alignment(horizontal: .trailing, vertical: .capMiddle)) {
                if model.phase == .loaded, model.current != nil {
                    moreMenu
                        .padding(.trailing, Tokens.Sizes.globalHeaderInset)
                }
            }
    }

    private var backButton: some View {
        Button {
            model.stopPlaying()
            dismiss()
        } label: {
            Image(systemName: Tokens.Icons.globalBack)
                .font(Tokens.Fonts.globalFamily.font(size: Tokens.Sizes.globalIcon, weight: Font.Weight.regular))
                .foregroundStyle(Tokens.Colors.globalTextOnMedia)
                .minimumHitArea(drawn: CGSize(width: Self.backChevronWidth, height: Tokens.Sizes.globalIcon))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(Copy.onthisdayA11yBack))
        .accessibilitySortPriority(9)
        .accessibilityIdentifier("onthisday.back")
    }

    /// Retro's Rewind mode menu (native pull-down, PLATFORM): "On this day…" (back to the day's memories) and "Shuffle"
    /// (the dice). Its invisible label covers the title and reaches over the chevron; it carries the title for VoiceOver.
    private var modeMenu: some View {
        Menu {
            Button(Copy.onthisdayModeDay) {
                model.showDay()
            }
            Button(Copy.onthisdayModeShuffle) {
                Task { await model.shuffle() }
            }
        } label: {
            Color.clear
                .contentShape(Rectangle())
        }
        .padding(.trailing, -Self.modeChevronReserve)
        .accessibilityLabel(Text(model.title))
        .accessibilityAddTraits(.isHeader)
        .accessibilitySortPriority(8)
        .accessibilityIdentifier("onthisday.title")
    }

    /// D. The native menu: save and delete (your memory; delete destructive) or report (someone else's, destructive). Saving
    /// someone else's photo is not offered (owner decision 12).
    private var moreMenu: some View {
        CircleMenu(icon: Tokens.Icons.globalMore, accessibilityLabel: Copy.onthisdayA11yMore, style: .glass) {
            if let current = model.current {
                if current.isMine {
                    Button(Copy.onthisdayMenuSave) {
                        Task { await model.save() }
                    }
                    Button(Copy.onthisdayMenuDelete, role: .destructive) {
                        model.requestDelete()
                    }
                } else {
                    Button(Copy.onthisdayMenuReport, role: .destructive) {
                        model.report()
                    }
                }
            }
        }
        .accessibilitySortPriority(6)
        .accessibilityIdentifier("onthisday.more")
    }

    // MARK: Control row (`layout.onthisday.controls`)

    /// Share, the dial and random, with equal gaps across the width; share and random fade out while playing
    /// (`duration.global.fade`, `easing.global.standard`). Share shows only on your own memory (owner decision 12); on
    /// someone else's its place stays empty, so the dial does not move.
    private var controls: some View {
        HStack(spacing: 0) {
            Spacer(minLength: 0)
            shareCircle
                .modifier(HiddenInPlace(isHidden: model.isPlaying || !model.canExport))
                .accessibilitySortPriority(4)
            Spacer(minLength: 0)
            RewindDial(
                slot: model.dialSlot,
                isPlaying: model.isPlaying,
                accessibilityValue: model.dialValue,
                onStep: { delta in delta > 0 ? model.next() : model.previous() },
                onPlayPause: { model.togglePlay() },
                onDragStart: { model.stopPlaying() }
            )
            .accessibilitySortPriority(3)
            Spacer(minLength: 0)
            CircleButton(icon: Tokens.Icons.globalRandom, accessibilityLabel: Copy.onthisdayA11yShuffle, style: .glassLarge) {
                Task { await model.shuffle() }
            }
            .disabled(model.isPicking)
            .modifier(HiddenInPlace(isHidden: model.isPlaying))
            .accessibilitySortPriority(1)
            .accessibilityIdentifier("onthisday.shuffle")
            Spacer(minLength: 0)
        }
    }

    /// The native share sheet with your memory's original; preview title = today's date (`layout.year.story.dateFormat`).
    @ViewBuilder
    private var shareCircle: some View {
        MemoryImageScope { images in
            if let item = model.shareItem {
                if let image = model.current?.displayURL.flatMap({ images.cachedImage(for: $0) }) {
                    ShareLink(item: item, preview: SharePreview(model.shareTitle, image: Image(uiImage: image))) {
                        CircleButtonFace(icon: Tokens.Icons.globalShare, style: .glassLarge)
                    }
                    .buttonStyle(.plain)
                } else {
                    ShareLink(item: item, preview: SharePreview(model.shareTitle)) {
                        CircleButtonFace(icon: Tokens.Icons.globalShare, style: .glassLarge)
                    }
                    .buttonStyle(.plain)
                }
            } else {
                CircleButtonFace(icon: Tokens.Icons.globalShare, style: .glassLarge)
            }
        }
        .simultaneousGesture(TapGesture().onEnded { model.stopPlaying() })
        .accessibilityLabel(Text(Copy.onthisdayA11yShare))
        .accessibilityIdentifier("onthisday.share")
    }
}

/// The expand chevron after the date title (`icon.global.chevronDown`, `color.global.textOnMedia`): the symbol scaled so its
/// ink is `dimension.onthisday.modeChevron.width` wide, at `fontWeight.onthisday.modeChevron` (the HIG's weight match with
/// the title). Decorative: the mode menu carries the label.
private struct ModeChevron: View {
    var body: some View {
        Image(systemName: Tokens.Icons.globalChevronDown)
            .resizable()
            .scaledToFit()
            .fontWeight(Tokens.FontWeights.fontWeightOnthisdayModeChevron)
            .frame(width: Tokens.Sizes.onthisdayModeChevronWidth)
            .foregroundStyle(Tokens.Colors.globalTextOnMedia)
            .accessibilityHidden(true)
    }
}

/// Share and random while playing (and share on someone else's memory): faded out (`duration.global.fade`,
/// `easing.global.standard`), not tappable, hidden from VoiceOver; they keep their place so the dial does not move.
private struct HiddenInPlace: ViewModifier {
    let isHidden: Bool

    func body(content: Content) -> some View {
        content
            .opacity(isHidden ? 0 : 1)
            .allowsHitTesting(!isHidden)
            .accessibilityHidden(isHidden)
            .dsAnimation(ComponentMotion.fade, value: isHidden)
    }
}
