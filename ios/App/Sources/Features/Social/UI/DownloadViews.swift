// Surface: settings.downloads — "Download My Photos" (settings.root → Privacy) and albums.view's "Download Album" (owner
// decisions 29 and 34). Spec: design/surfaces/settings.downloads.md. Mechanics: Retro "Download your package"
// (references/auto/retro/web/retro.app-web-copy-excerpts.txt /downloads), Yope "download all photos"
// (design/research/yope-a.md §2.13); composition of C-27 (glyph + explanation), the platform progress bar (PLATFORM),
// C-05 / C-06 capsules and the C-29 alert.
import AppData
import AppModels
import DesignSystem
import SwiftUI
import UIKit

/// The page's content: the C-27 block (`icon.global.download`, the explanation), then the state line — the platform
/// progress bar with "Downloading…" while saving (indeterminate for your photos, a bar without figures for an album;
/// never a number), "Saved!", the empty line or the error / offline line — and at the bottom the C-05 capsule
/// (Download / Continue) or, while saving, the C-06 Cancel capsule. Denied photo access: the platform alert with the
/// Settings button.
struct PhotoDownloadView: View {
    @State private var model: PhotoDownloadModel
    let detail: String
    /// Starts at once (the album's menu item already asked for it).
    var autoStart = false
    /// The album needs premium: the paywall at the full-quality downloads perk.
    var openPaywall: () -> Void = {}
    @Environment(\.openURL) private var openURL

    init(model: PhotoDownloadModel, detail: String, autoStart: Bool = false, openPaywall: @escaping () -> Void = {}) {
        _model = State(initialValue: model)
        self.detail = detail
        self.autoStart = autoStart
        self.openPaywall = openPaywall
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Tokens.Sizes.globalSectionGap) {
                EmptyStateView(
                    icon: Tokens.Icons.globalDownload,
                    title: nil,
                    detail: [detail, Copy.settingsDownloadsDetailLibrary].joined(separator: " ") // provenance-ok: joins two copy sentences
                )
                statusArea
            }
            .padding(.top, Tokens.Sizes.globalTitleToContent)
            .frame(maxWidth: .infinity)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) { bottomButton }
        .task {
            await model.load()
            if autoStart, model.phase == .idle { model.start() }
        }
        .onDisappear { model.stop() }
        .onChange(of: model.phase) { _, phase in announce(phase) }
        .onChange(of: model.paywallRequests) { _, _ in openPaywall() }
        .socialFeedback(model.signals.feedback)
        .alert(Copy.settingsDownloadsDeniedTitle, isPresented: $model.saveDenied) {
            Button(Copy.settingsDownloadsDeniedButton) {
                if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
            }
            Button(Copy.settingsDownloadsCancel, role: .cancel) {}
        } message: {
            Text(Copy.settingsDownloadsDeniedMessage)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("settings.downloads") // provenance-ok: accessibility identifier for UI tests
    }

    @ViewBuilder
    private var statusArea: some View {
        switch model.phase {
        case .running:
            VStack(spacing: Tokens.Sizes.globalListGap) {
                Group {
                    if let fraction = model.fraction {
                        ProgressView(value: fraction)
                            .progressViewStyle(.linear) // provenance-ok: the platform's linear progress style (PLATFORM), not an animation curve
                    } else {
                        // The total is never asked for: the platform's indeterminate indicator (C-28).
                        ProgressView()
                    }
                }
                .tint(Tokens.Colors.globalAccent)
                // Read as "Downloading…", never as a figure (tenet 2).
                .accessibilityValue(Text(Copy.settingsDownloadsProgress))
                statusLine(Copy.settingsDownloadsProgress)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, Tokens.Sizes.globalScreenMargin)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("settings.downloads.progress") // provenance-ok: accessibility identifier for UI tests
        case .done:
            statusLine(Copy.settingsDownloadsDone)
        case .empty:
            statusLine(Copy.settingsDownloadsEmpty)
        case .failed:
            statusLine(Copy.settingsDownloadsError)
        case .offline:
            statusLine(Copy.settingsDownloadsOffline)
        case .idle:
            EmptyView()
        }
    }

    private func statusLine(_ text: String) -> some View {
        Text(text)
            .dsTextStyle(TextRole.body)
            .foregroundStyle(Tokens.Colors.globalTextSecondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, Tokens.Sizes.globalScreenMargin)
    }

    /// Download / Continue (C-05), or Cancel (C-06 outline) while saving, `size.global.buttonMarginH` from the edges.
    @ViewBuilder
    private var bottomButton: some View {
        Group {
            if model.isRunning {
                CapsuleButton(Copy.settingsDownloadsCancel, style: .outline, fillsWidth: true) { model.cancel() }
                    .accessibilityIdentifier("settings.downloads.cancel") // provenance-ok: accessibility identifier for UI tests
            } else {
                PrimaryButton(model.canResume ? Copy.settingsDownloadsResume : Copy.settingsDownloadsStart) { _ = model.start() }
                    .accessibilityIdentifier("settings.downloads.start") // provenance-ok: accessibility identifier for UI tests
            }
        }
        .padding(.horizontal, Tokens.Sizes.globalButtonMarginH)
        .padding(.bottom, Tokens.Sizes.globalSectionGap)
        .background(Tokens.Colors.globalBackground.ignoresSafeArea())
    }

    /// C-26: the end states are announced (iOS draws no toast).
    private func announce(_ phase: PhotoDownloadModel.Phase) {
        let text: String?
        switch phase {
        case .done: text = Copy.settingsDownloadsDone
        case .empty: text = Copy.settingsDownloadsEmpty
        case .failed: text = Copy.settingsDownloadsError
        case .offline: text = Copy.settingsDownloadsOffline
        case .idle, .running: text = nil
        }
        if let text { AccessibilityNotification.Announcement(text).post() }
    }
}

/// settings.root → Privacy → Download My Photos: pushed inside the Settings sheet with its native title (free, owner
/// decision 29).
struct MyPhotosDownloadScreen: View {
    var body: some View {
        PhotoDownloadView(
            model: PhotoDownloadModel(scope: .mine, data: SocialServices.shared.data, saver: SocialServices.shared.saver),
            detail: Copy.settingsDownloadsDetail
        )
        .settingsPage(title: Copy.settingsDownloadsTitle)
    }
}

/// albums.view "•••" → Download Album (premium): a page sheet that starts saving at once. Should the server still answer
/// `premium_required`, the sheet closes and `onNeedsPremium` lets the album open the paywall once it is gone.
struct AlbumDownloadSheet: View {
    let albumID: AlbumID
    var onNeedsPremium: () -> Void = {}
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(title: Copy.settingsDownloadsAlbumTitle, closeAccessibilityLabel: Copy.photoViewerA11yClose) { dismiss() }
            PhotoDownloadView(
                model: PhotoDownloadModel(scope: .album(albumID), data: SocialServices.shared.data, saver: SocialServices.shared.saver),
                detail: Copy.settingsDownloadsAlbumDetail,
                autoStart: true,
                openPaywall: {
                    onNeedsPremium()
                    dismiss()
                }
            )
        }
        .background(Tokens.Colors.globalBackground.ignoresSafeArea())
        .presentationDetents([.medium, .large])
        .dsSheetBackground()
    }
}

/// The premium gate of "Download Album" (owner decision 29): without premium the item carries `icon.global.lock` and opens
/// the paywall at the full-quality downloads perk through the locked-perk entry (at most once per session,
/// `paywall.layout.promptRule`; otherwise the item keeps its lock glyph and nothing opens).
@MainActor
enum AlbumDownloadGate {
    static var isPremium: Bool { SocialNav.router.isPremium() }

    /// Claims the session's one premium prompt and points the paywall at the downloads perk; false when it may not show
    /// (premium already, or the prompt was used). The album presents the paywall itself (it is shown in a sheet, where
    /// the shell's modal cannot appear).
    static func claimPaywall() -> Bool {
        let router = SocialNav.router
        guard !router.isPremium(), router.consumePremiumPrompt() else { return false }
        router.paywallPerk = PaywallPerk.export.rawValue
        return true
    }
}
