// Surface: birthday.tribute — the screen the birthday video plays on: a media page with the display serif title at the
// margin (Retro Rewind, C-35) and Retro's recap-preview bottom row (its Share pill is the capture group's shared
// `RecapPillLabel`) (design/surfaces/birthday.tribute.md B; MERGE RM-12).
// Reference images: references/auto/retro/press/tc-2025-12-rewind-device-a.png (title on a media page),
// references/auto/retro/store/retro-store-04.png (bottom row: circle + white 'Share' pill), references/auto/retro/press/
// tc-2023-07-retro-2b.jpg phone 2 (media at full width, letterboxed). Mechanics: Tribute / VidDay (the worker renders the
// video). Components: C-35 / C-01 title placement, C-11, C-09 recap Share pill, C-22 media placement, C-27, C-28, C-29.
import AppData
import AVKit
import Combine
import DesignSystem
import SwiftUI
import UIKit

/// The birthday video for the honoree (after delivery) and for members (any time): title and group, the player with
/// native controls, save and Share. Dark in both appearances; full screen.
@MainActor
struct TributeScreen: View {
    let tributeID: String
    let groupID: String?
    @State private var model: TributeModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL

    init(tributeID: String, groupID: String?, model: TributeModel? = nil) {
        self.tributeID = tributeID
        self.groupID = groupID
        _model = State(initialValue: model ?? TributeModel(tributeID: TributeID(tributeID), dependencies: .current))
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Tokens.Colors.globalBackgroundDeep
                    .ignoresSafeArea()
                VStack(spacing: 0) {
                    header
                    content
                        .frame(maxHeight: .infinity)
                    // The bottom row's space, so the player centres between the header and the row.
                    Color.clear
                        .frame(height: bottomRowReserve(safeBottom: proxy.safeAreaInsets.bottom))
                }
                if showsBottomRow {
                    bottomRow
                        .frame(maxHeight: .infinity, alignment: .bottom)
                        .padding(.bottom, max(0, Tokens.Layouts.CollageViewLayoutScreen.bottomRowCentreFromScreenBottom
                                - Tokens.Layouts.CollageShareLayoutPill.height / 2 - proxy.safeAreaInsets.bottom))
                }
            }
        }
        .environment(\.colorScheme, .dark)
        .preferredColorScheme(.dark)
        .toolbar(.hidden, for: .navigationBar)
        .task { await model.loadIfNeeded() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await model.refreshIfRendering() } }
        }
        .alert(Copy.birthdayTributeSaveDeniedTitle, isPresented: $model.showsSaveDenied) {
            Button(Copy.birthdayTributeSaveDeniedButton) {
                if let settings = URL(string: UIApplication.openSettingsURLString) { openURL(settings) }
            }
        } message: {
            Text(Copy.birthdayTributeSaveDeniedMessage)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("birthday.tribute")
    }

    /// Height the bottom row takes above the safe-area bottom (its centre `bottomRowCentreFromScreenBottom` above the
    /// screen bottom, `collage.share.layout.pill.height` tall).
    private func bottomRowReserve(safeBottom: CGFloat) -> CGFloat {
        max(0, Tokens.Layouts.CollageViewLayoutScreen.bottomRowCentreFromScreenBottom + Tokens.Layouts.CollageShareLayoutPill.height / 2 - safeBottom)
    }

    // MARK: Header

    /// The title (`birthday.tribute.title` / `.title.member`, display serif `headerTitle`, `color.global.textOnMedia`, up to
    /// two lines) at `size.global.screenMargin`, its first baseline `size.global.titleTop` below the safe-area top; the group
    /// name (text role `textButton`, `color.global.textSecondary`) with its baseline `dimension.onthisday.subtitleBaseline`
    /// below the title's; the close circle (C-11 on media) at `size.global.headerInset`, centred on the title's cap middle.
    private var header: some View {
        MetricStack {
            Text(model.phase == .notFound ? "" : model.title)
                .dsTextRole(TextRole.headerTitle)
                .foregroundStyle(Tokens.Colors.globalTextOnMedia)
                .lineLimit(2)
                .padding(.leading, Tokens.Sizes.globalScreenMargin)
                .padding(.trailing, Tokens.Sizes.globalHeaderInset + Tokens.Sizes.globalCircleButton + Tokens.Sizes.globalHeaderGap)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityAddTraits(.isHeader)
                .accessibilityHidden(model.title.isEmpty || model.phase == .notFound)
                .accessibilitySortPriority(4)
                .overlay(alignment: Alignment(horizontal: .trailing, vertical: .capMiddle)) {
                    CircleButton(
                        icon: Tokens.Icons.globalClose, accessibilityLabel: Copy.birthdayTributeA11yClose, style: .media,
                        glyphSize: Tokens.Sizes.globalIconSmall
                    ) {
                        dismiss()
                    }
                    .padding(.trailing, Tokens.Sizes.globalHeaderInset)
                    .accessibilitySortPriority(2)
                    .accessibilityIdentifier("birthday.tribute.close")
                }
                .metricGap(Tokens.Sizes.globalTitleTop, from: .top, to: .firstBaseline)
            if !model.groupName.isEmpty {
                Text(model.groupName)
                    .dsTextStyle(TextRole.textButton)
                    .foregroundStyle(Tokens.Colors.globalTextSecondary)
                    .padding(.horizontal, Tokens.Sizes.globalScreenMargin)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilitySortPriority(3)
                    .metricGap(Tokens.Sizes.onthisdaySubtitleBaseline, from: .lastBaseline, to: .firstBaseline)
            }
        }
    }

    // MARK: Player and states

    @ViewBuilder
    private var content: some View {
        switch model.phase {
        case .notFound:
            EmptyStateView(title: Copy.birthdayTributeNotFoundTitle)
                .accessibilityIdentifier("birthday.tribute.notFound")
        case .error:
            MemoryMediaStateBlock(
                title: Copy.birthdayTributeErrorTitle, detail: Copy.birthdayTributeErrorDetail, retryTitle: Copy.birthdayTributeErrorRetry
            ) {
                Task { await model.retry() }
            }
        case .offline:
            MemoryMediaStateBlock(
                title: Copy.birthdayTributeOfflineTitle, detail: Copy.birthdayTributeOffline, retryTitle: Copy.birthdayTributeErrorRetry
            ) {
                Task { await model.retry() }
            }
        case .idle, .loading, .rendering, .ready:
            player
                .accessibilitySortPriority(1)
        }
    }

    /// `layout.birthday.tribute.player`: full screen width, 16:9 (`layout.birthday.tribute.video`), native controls; the
    /// platform activity indicator while loading or re-rendering.
    @ViewBuilder
    private var player: some View {
        let aspect = Tokens.Layouts.BirthdayTributeVideo.width / Tokens.Layouts.BirthdayTributeVideo.height
        Group {
            if model.phase == .ready, let player = model.player {
                TributePlayer(player: player, posterURL: model.posterURL)
            } else {
                ZStack {
                    Tokens.Colors.birthdayTributePillarbox
                    MemoryLoadingIndicator(announcement: Copy.birthdayTributeLoading)
                }
            }
        }
        .aspectRatio(aspect, contentMode: .fit)
        .frame(maxWidth: .infinity)
    }

    // MARK: Bottom row (Retro's recap preview)

    /// Leading: the save circle (C-11 on media, `icon.global.download` in a `size.global.icon` box) at
    /// `size.global.buttonMarginH`; trailing: the Share pill (`collage.share.layout.pill`). Disabled until the file is
    /// on the device.
    private var bottomRow: some View {
        HStack(spacing: 0) {
            CircleButton(icon: Tokens.Icons.globalDownload, accessibilityLabel: Copy.birthdayTributeDownload, style: .media) {
                Task { await model.download() }
            }
            .disabled(!model.canUseFile)
            .accessibilityIdentifier("birthday.tribute.download")
            Spacer(minLength: 0)
            Group {
                if model.canUseFile, let file = model.localFile {
                    ShareLink(item: file) {
                        RecapPillLabel(title: Copy.birthdayTributeShare)
                    }
                    .buttonStyle(.plain)
                } else {
                    RecapPillLabel(title: Copy.birthdayTributeShare)
                        .accessibilityAddTraits(.isButton)
                }
            }
            .accessibilityIdentifier("birthday.tribute.share")
        }
        .padding(.horizontal, Tokens.Sizes.globalButtonMarginH)
        .frame(minHeight: Tokens.Layouts.CollageShareLayoutPill.height)
    }

    /// The row belongs to the video: shown while it loads (disabled) and when it is ready.
    private var showsBottomRow: Bool {
        switch model.phase {
        case .idle, .loading, .rendering, .ready: return true
        case .notFound, .error, .offline: return false
        }
    }
}

/// AVKit player (SwiftUI `VideoPlayer` = `AVPlayerViewController`, system controls) with the poster (the title card)
/// until playback starts. Plays once on open unless "Auto-Play Video Previews" is off
/// (`UIAccessibility.isVideoAutoplayEnabled`, birthday.tribute.md Motion).
private struct TributePlayer: View {
    let player: AVPlayer
    let posterURL: URL?
    @State private var hasStarted = false
    @State private var didAutoplay = false

    var body: some View {
        ZStack {
            Tokens.Colors.birthdayTributePillarbox
            VideoPlayer(player: player) {
                if !hasStarted {
                    MemoryRemoteImage(url: posterURL, contentMode: .fit)
                        .allowsHitTesting(false)
                }
            }
            .onReceive(player.publisher(for: \.timeControlStatus).receive(on: DispatchQueue.main)) { status in
                if status == .playing { hasStarted = true }
            }
        }
        .onAppear {
            guard !didAutoplay else { return }
            didAutoplay = true
            if UIAccessibility.isVideoAutoplayEnabled {
                player.play()
            }
        }
        .onDisappear {
            player.pause()
        }
    }
}
