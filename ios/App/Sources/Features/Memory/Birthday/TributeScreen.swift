// Surface: birthday.tribute — reference: Tribute / VidDay (the screen the video plays on).
// Reference images: references/auto/vidday/store/vidday-store-08.png, -09.png;
// references/auto/tribute/mockups/tribute-home-phone-step-3-completed-page.png;
// references/auto/tribute/web/tribute-web-testimonials.computed-styles.json (design/surfaces/birthday.tribute.md).
// Replaces the container ios/App/Sources/Screens/TributeScreen.swift (`AppRoute.tribute`).
import AppData
import AVKit
import Combine
import DesignSystem
import SwiftUI
import UIKit

/// The birthday video for the honoree (and for members, who can watch it at any time):
/// title, group, the player with native controls, Download and Share.
@MainActor
struct TributeScreen: View {
    let tributeID: String
    let groupID: String?
    @State private var model: TributeModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    init(tributeID: String, groupID: String?, model: TributeModel? = nil) {
        self.tributeID = tributeID
        self.groupID = groupID
        _model = State(initialValue: model ?? TributeModel(tributeID: TributeID(tributeID), dependencies: .current))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                MemoryHeaderCircle(icon: Tokens.Icons.globalClose, label: Copy.birthdayTributeA11yClose) {
                    dismiss()
                }
                .accessibilityIdentifier("birthday.tribute.close")
                Spacer()
            }
            .padding(.horizontal, Tokens.Sizes.globalHeaderInset)
            switch model.phase {
            case .notFound:
                centred(MemoryStateMessage(title: Copy.birthdayTributeNotFoundTitle, detail: Copy.birthdayTributeNotFoundDetail))
            case .error:
                centred(MemoryStateMessage(
                    title: Copy.birthdayTributeErrorTitle, detail: Copy.birthdayTributeErrorDetail,
                    actionTitle: Copy.birthdayTributeErrorRetry
                ) {
                    Task { await model.retry() }
                })
            default:
                ScrollView {
                    content
                        .padding(.horizontal, Tokens.Sizes.birthdayRequestMargin)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Tokens.Colors.globalBackgroundDeep.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .memoryToast($model.toast)
        .task { await model.loadIfNeeded() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await model.refreshIfRendering() } }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("birthday.tribute")
    }

    private func centred(_ content: some View) -> some View {
        content
            .padding(.horizontal, Tokens.Sizes.birthdayRequestMargin)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(Copy.birthdayTributeTitle)
                .dsTextStyle(BirthdayType.requestTitle)
                .foregroundStyle(Tokens.Colors.globalTextPrimary)
                .accessibilityAddTraits(.isHeader)
            // The group line keeps its height while loading, so the player never moves.
            Text(model.groupName.isEmpty ? " " : model.groupName)
                .dsTextStyle(BirthdayType.message)
                .foregroundStyle(Tokens.Colors.globalTextSecondary)
                .accessibilityHidden(model.groupName.isEmpty)
            if model.phase == .offline {
                Text(Copy.birthdayTributeOffline)
                    .dsTextStyle(MemoryType.listSubtitle)
                    .foregroundStyle(Tokens.Colors.globalTextSecondary)
            }
            player
                .padding(.top, Tokens.Sizes.birthdayRequestMessageGap)
            VStack(spacing: Tokens.Sizes.birthdayTributeButtonGap) {
                MemoryFilledButton.tributeSecondary(Copy.birthdayTributeDownload, icon: Tokens.Icons.globalDownload) {
                    Task { await model.download() }
                }
                .disabled(!model.canUseFile)
                .accessibilityIdentifier("birthday.tribute.download")
                shareButton
            }
            .padding(.top, Tokens.Sizes.birthdayRequestCtaGap)
        }
        .padding(.bottom, Tokens.Sizes.birthdayRequestMargin)
    }

    /// `layout.birthday.tribute.player`: full content width, 16:9, native controls.
    @ViewBuilder
    private var player: some View {
        let aspect = Tokens.Layouts.BirthdayTributeVideo.width / Tokens.Layouts.BirthdayTributeVideo.height
        Group {
            if model.phase == .ready, let player = model.player {
                TributePlayer(player: player, posterURL: model.posterURL)
            } else {
                ZStack {
                    Tokens.Colors.birthdayTributePillarbox
                    if model.phase != .offline {
                        MemoryLoadingIndicator(text: Copy.birthdayTributeLoading)
                    }
                }
            }
        }
        .aspectRatio(aspect, contentMode: .fit)
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var shareButton: some View {
        let button = MemoryFilledButton.tributeSecondary(Copy.birthdayTributeShare, icon: Tokens.Icons.globalShare) {}
        if model.canUseFile, let file = model.localFile {
            // System share sheet with the MP4 file.
            ShareLink(item: file) {
                button.label
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("birthday.tribute.share")
        } else {
            button
                .disabled(true)
                .accessibilityIdentifier("birthday.tribute.share")
        }
    }
}

/// AVKit player (SwiftUI `VideoPlayer` = `AVPlayerViewController`, system controls) with the poster
/// (the title card) shown until playback starts. Plays once on open unless the system setting
/// "Auto-Play Video Previews" is off (`UIAccessibility.isVideoAutoplayEnabled`).
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
            // Plays once when the screen opens, unless "Auto-Play Video Previews" is off.
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
