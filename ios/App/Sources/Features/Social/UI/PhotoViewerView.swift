// Surface: photo.viewer — reference apps: Yope (frame, header, reply row, menu) + Locket (reactions, quick reactions,
// emoji rain). Spec: design/surfaces/photo.viewer.md; the "i'm in this" toggle: design/surfaces/tagging.md.
// References: references/auto/yope/frames/b-yopeapp-7591560669967682847-t57.07-photo-viewer.png (primary),
// …-t57.20/57.30/57.40 (swipe), a-yrrah-7434441926000037121-t33.73-group-menu-leave-report-2024.png (menu),
// references/auto/locket/store/locket-store-08.png (quick reactions), locket-store-04.png (cluster).
import AppData
import AppModels
import AppServices
import AVKit
import DesignSystem
import Photos
import PhotosUI
import SwiftUI
import UIKit

struct PhotoViewerView: View {
    /// Opened from a social screen (`.fullScreenCover`) or pushed by a deep link (`AppRoute.post`).
    enum Presentation {
        case pushed
        /// Reply with a photo: the cover closes first, then its host opens the camera.
        case cover(onReplyCamera: (PhotoReplyHandoff.Target) -> Void)
    }

    let presentation: Presentation
    @State private var model: PhotoViewerModel
    @State private var toasts = ToastCenter()
    @State private var pickerOpen = false
    @State private var activityOpen = false
    @State private var confirmingDelete = false
    @State private var reportTarget: ReportTarget?
    @State private var blockTarget: BlockTarget?
    @State private var cardDismissed = false
    @State private var width: CGFloat = 0
    @Environment(\.dismiss) private var dismiss
    @Environment(\.displayScale) private var displayScale
    @Environment(AccountDependencies.self) private var account: AccountDependencies?

    init(context: PhotoViewerContext, presentation: Presentation) {
        self.init(model: PhotoViewerModel(context: context, data: SocialServices.shared.data, flags: SocialServices.shared.flags), presentation: presentation)
    }

    init(model: PhotoViewerModel, presentation: Presentation) {
        _model = State(initialValue: model)
        self.presentation = presentation
    }

    var body: some View {
        ZStack {
            Tokens.Colors.photoViewerColorBackground.ignoresSafeArea()
            // Behind the photo, in front of the background (S-9).
            EmojiRain(trigger: model.sentReaction)
            VStack(spacing: 0) {
                header
                content
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) { bottomArea }
        .socialReadsWidth($width)
        .socialHidesNavigationBar()
        .task {
            if model.phase == .loading { await model.load() }
            prefetchNeighbours()
            await model.run()
        }
        .onChange(of: model.selection) { _, _ in
            prefetchNeighbours()
            Task { await model.loadSelectedTag() }
        }
        .onChange(of: model.isClosed) { _, closed in
            if closed { dismiss() }
        }
        .socialFeedback(model.signals.feedback)
        .socialNotices(model.signals.notice, toasts: toasts)
        .toastHost(toasts)
        .sheet(isPresented: $pickerOpen) {
            ReactionPicker(
                mine: model.myEmojiOnCurrent,
                onPick: { emoji in Task { await model.react(emoji) } },
                onRemove: { emoji in Task { await model.unreact(emoji) } }
            )
        }
        .sheet(isPresented: $activityOpen) {
            if let post = model.current {
                ReactionActivitySheet(
                    reactions: model.reactions[post.id] ?? ReactionSummary(),
                    me: model.me,
                    posterFirstName: model.author(of: post)?.socialFirstName ?? "",
                    nameOf: { model.profiles[$0]?.socialFirstName ?? "" }
                )
            }
        }
        .sheet(item: $reportTarget) { target in
            reportSheet(target)
        }
        .confirmationDialog(Copy.photoViewerDeleteTitle, isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button(Copy.photoViewerDeleteConfirm, role: .destructive) {
                Task { await model.deleteCurrent() }
            }
            Button(Copy.photoViewerDeleteCancel, role: .cancel) {}
        } message: {
            Text(Copy.photoViewerDeleteMessage)
        }
        .blockConfirmation(
            target: $blockTarget,
            toasts: toasts,
            perform: { target in try await model.blockAuthor(UserID(target.userID)) },
            onBlocked: { target in model.authorBlocked(UserID(target.userID)) }
        )
        .socialClearsReplyHandoff()
        .accessibilityIdentifier("photo.viewer") // provenance-ok: accessibility identifier for UI tests
    }

    @ViewBuilder
    private func reportSheet(_ target: ReportTarget) -> some View {
        // The account group's report flow needs its dependencies; the entry is offered only when they are present.
        if let account {
            ReportSheet(target: target)
                .environment(account)
                .toastHost(account.toasts)
        }
    }

    private func prefetchNeighbours() {
        let paths = model.neighbours.compactMap { $0.media?.displayImagePath }
        SocialServices.shared.images.prefetch(paths, maxPixel: screenPixels)
    }

    /// The photo's width in pixels (it spans the screen width).
    private var screenPixels: Int? {
        width > 0 ? Int((width * displayScale).rounded(.up)) : nil
    }

    // MARK: Header

    /// ✕ · two-line title · •••, centred `photo.viewer.dimension.headerCenterY` below the top safe-area inset.
    private var header: some View {
        let half = Tokens.Sizes.globalMinTouchTargetIos / 2
        return title
            .frame(maxWidth: .infinity, minHeight: Tokens.Sizes.photoViewerDimensionHeaderCenterY * 2)
            .padding(.horizontal, Tokens.Sizes.photoViewerDimensionCloseCenterX + half)
            .overlay(alignment: .leading) {
                Button { dismiss() } label: {
                    Image(systemName: Tokens.Icons.globalClose)
                        .resizable()
                        .scaledToFit()
                        .frame(height: Tokens.Sizes.photoViewerDimensionCloseGlyph)
                        .foregroundStyle(Tokens.Colors.globalTextPrimary)
                        .frame(width: Tokens.Sizes.globalMinTouchTargetIos, height: Tokens.Sizes.globalMinTouchTargetIos)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(Copy.photoViewerA11yClose))
                .offset(x: Tokens.Sizes.photoViewerDimensionCloseCenterX - half)
            }
            .overlay(alignment: .trailing) {
                menu.offset(x: half - Tokens.Sizes.photoViewerDimensionMoreCenterTrailing)
            }
    }

    @ViewBuilder
    private var title: some View {
        if let post = model.current {
            let name = model.isOwn(post) ? Copy.photoViewerTitleYou : (model.author(of: post)?.socialFirstName ?? "")
            let group = model.group(of: post)?.name ?? ""
            ZStack(alignment: Alignment(horizontal: .center, vertical: .firstTextBaseline)) {
                Text(titleLine(name: name, group: group))
                    .dsTextStyle(TextRole.headerTitle)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Text(SocialFormat.viewerDate(post.post.createdAt))
                    .dsTextStyle(TextRole.listSubtitle)
                    .foregroundStyle(Tokens.Colors.globalTextSecondary)
                    .alignmentGuide(.firstTextBaseline) { $0[.firstTextBaseline] - Tokens.Sizes.photoViewerDimensionTitleToDate }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(titleLine(name: name, group: group)) + Text(", " + SocialFormat.viewerDate(post.post.createdAt)))
            .accessibilityAddTraits(.isHeader)
        }
    }

    /// "{you | name} sent to {group}": names in `color.global.textPrimary`, "sent to" in `color.global.textSecondary`.
    private func titleLine(name: String, group: String) -> AttributedString {
        var first = AttributedString(name)
        first.foregroundColor = Tokens.Colors.globalTextPrimary
        var middle = AttributedString(" " + Copy.photoViewerTitleSentTo + " ")
        middle.foregroundColor = Tokens.Colors.globalTextSecondary
        var last = AttributedString(group)
        last.foregroundColor = Tokens.Colors.globalTextPrimary
        return first + middle + last
    }

    /// Native pull-down menu (`photo.viewer.layout.menu`): save; delete (mine) or report and block (others').
    private var menu: some View {
        Menu {
            menuItems
        } label: {
            Image(systemName: Tokens.Icons.globalMore)
                .resizable()
                .scaledToFit()
                .frame(width: Tokens.Sizes.photoViewerDimensionMoreGlyphWidth)
                .foregroundStyle(Tokens.Colors.globalTextPrimary)
                .frame(width: Tokens.Sizes.globalMinTouchTargetIos, height: Tokens.Sizes.globalMinTouchTargetIos)
                .contentShape(Rectangle())
        }
        .accessibilityLabel(Text(Copy.photoViewerA11yMore))
        .disabled(model.current == nil || model.isCurrentGone)
    }

    /// The menu's items, also exposed as accessibility actions on the photo.
    @ViewBuilder
    private var menuItems: some View {
        Button { Task { await model.saveCurrent(using: SocialServices.shared.saver) } } label: {
            Label(Copy.photoViewerMenuSave, systemImage: Tokens.Icons.globalDownload)
        }
        if model.isCurrentOwn {
            Button(role: .destructive) { confirmingDelete = true } label: {
                Label(Copy.photoViewerMenuDelete, systemImage: Tokens.Icons.photoViewerIconDelete)
            }
        } else if let post = model.current {
            let firstName = model.author(of: post)?.socialFirstName ?? ""
            if account != nil {
                Button(role: .destructive) {
                    reportTarget = ReportTarget(
                        kind: .post, id: post.id.rawValue, name: nil,
                        person: BlockTarget(userID: post.post.authorID.rawValue, firstName: firstName)
                    )
                } label: {
                    Label(Copy.photoViewerMenuReport, systemImage: Tokens.Icons.globalReport)
                }
            }
            Button(role: .destructive) {
                blockTarget = BlockTarget(userID: post.post.authorID.rawValue, firstName: firstName)
            } label: {
                Text(Copy.photoViewerMenuBlock(name: firstName))
            }
        }
    }

    // MARK: Pages

    @ViewBuilder
    private var content: some View {
        switch model.phase {
        case .loading:
            Spacer()
        case .failed, .empty:
            Spacer()
            EmptyStateView(title: Copy.photoViewerErrorLoad)
            Spacer()
        case .offline:
            Spacer()
            EmptyStateView(title: Copy.chatThreadOfflineTitle, detail: Copy.chatThreadOfflineDetail)
            Spacer()
        case .ready:
            TabView(selection: Binding(get: { model.selection }, set: { model.show($0) })) {
                ForEach(model.postIDs, id: \.self) { id in
                    page(id).tag(id)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .padding(.top, Tokens.Sizes.photoViewerDimensionPhotoTop - Tokens.Sizes.photoViewerDimensionHeaderCenterY * 2)
        }
    }

    @ViewBuilder
    private func page(_ id: PostID) -> some View {
        if model.gone.contains(id) || model.posts[id] == nil {
            VStack {
                Spacer()
                EmptyStateView(title: Copy.photoViewerGoneTitle, detail: Copy.photoViewerGoneDetail)
                Spacer()
            }
        } else if let post = model.posts[id] {
            VStack(alignment: .leading, spacing: Tokens.Sizes.globalScreenMargin) {
                ViewerPhoto(
                    post: post,
                    model: model,
                    maxPixel: screenPixels,
                    openActivity: { activityOpen = true },
                    menuActions: AnyView(menuItems)
                )
                if let voicePath = post.post.voicePath, let duration = post.post.voiceDurationMs {
                    // Position BLOCKED (`photo.viewer.layout.voiceNote`): the spec's approximation, under the photo.
                    VoiceBubble(
                        key: post.id.rawValue,
                        path: voicePath,
                        durationMs: duration,
                        isMine: model.isOwn(post),
                        accessibilityLabel: model.isOwn(post)
                            ? Copy.chatVoiceA11yMessageMine(duration: SocialFormat.spokenDuration(milliseconds: duration))
                            : Copy.chatVoiceA11yMessage(name: model.author(of: post)?.socialFirstName ?? "", duration: SocialFormat.spokenDuration(milliseconds: duration)),
                        onPlayFailed: { toasts.show(Copy.chatVoiceErrorPlay) }
                    )
                    .padding(.leading, Tokens.Sizes.globalScreenMargin)
                }
                Spacer(minLength: 0)
            }
        }
    }

    // MARK: Reply row

    private var bottomArea: some View {
        VStack(spacing: Tokens.Sizes.globalListGap) {
            if model.saveDenied, !cardDismissed {
                PermissionCard(
                    title: Copy.photoViewerPermissionTitle,
                    detail: Copy.photoViewerPermissionDetail,
                    buttonTitle: Copy.photoViewerPermissionButton,
                    onEnable: {
                        if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                    },
                    onDismiss: { cardDismissed = true }
                )
                .padding(.horizontal, Tokens.Sizes.onboardingPermissionContactsSizeCardMarginH)
            }
            if model.phase == .ready, model.current != nil, !model.isCurrentGone {
                ViewerReplyRow(
                    text: $model.replyDraft,
                    groupName: model.current.flatMap { model.group(of: $0) }?.name ?? "",
                    send: { Task { await model.sendReply() } },
                    react: { emoji in Task { await model.react(emoji) } },
                    openPicker: { pickerOpen = true },
                    camera: replyWithPhoto
                )
            }
        }
        .onChange(of: model.saveDenied) { _, denied in
            if denied { cardDismissed = false }
        }
    }

    private func replyWithPhoto() {
        guard let post = model.current else { return }
        let target = PhotoReplyHandoff.Target(groupID: post.post.groupID.rawValue, postID: post.id.rawValue)
        switch presentation {
        case .pushed:
            SocialNav.router.presentCameraReplying(toPost: target.postID, groupID: target.groupID)
        case let .cover(onReplyCamera):
            onReplyCamera(target)
            dismiss()
        }
    }
}

// MARK: - The photo with its overlays

/// Full width, the photo's own aspect, `radius.global.photo`, top `photo.viewer.dimension.photoTop`; scaled down to
/// fit when taller than the space (approximation). Over it: sender (top-left), "i'm in this" (top-right, Yope's chip
/// slot, S-19), caption (bottom-centre), reaction cluster (bottom-left).
struct ViewerPhoto: View {
    let post: PostWithMedia
    let model: PhotoViewerModel
    let maxPixel: Int?
    let openActivity: () -> Void
    /// The ••• menu's items, exposed as accessibility actions on the photo.
    var menuActions = AnyView(EmptyView())

    private var aspectRatio: CGFloat? {
        guard let media = post.media, let width = media.width, let height = media.height, width > 0, height > 0 else { return nil }
        return CGFloat(width) / CGFloat(height)
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Tokens.Radii.globalPhoto)
        ViewerMedia(post: post, maxPixel: maxPixel, accessibilityLabel: label)
            .accessibilityActions { menuActions }
            .aspectRatio(aspectRatio, contentMode: .fit)
            .frame(maxWidth: .infinity)
            .clipShape(shape)
            .overlay(alignment: .topLeading) { sender }
            .overlay(alignment: .topTrailing) { tagging }
            .overlay(alignment: .bottom) {
                if let caption = post.post.caption, !caption.isEmpty {
                    PhotoCaption(text: caption, wraps: true)
                        .padding(.horizontal, Tokens.Sizes.chatReactionsDimensionClusterInsetLeading)
                        .padding(.bottom, Tokens.Sizes.chatThreadDimensionCaptionInsetBottom)
                }
            }
            .overlay(alignment: .bottomLeading) {
                let emoji = model.reactions[post.id]?.distinctEmoji ?? []
                Button(action: openActivity) {
                    ReactionCluster(emoji: emoji)
                }
                .buttonStyle(.plain)
                .allowsHitTesting(!emoji.isEmpty)
                .accessibilityHidden(emoji.isEmpty)
                .padding(.leading, Tokens.Sizes.chatReactionsDimensionClusterInsetLeading)
                .padding(.bottom, Tokens.Sizes.chatReactionsDimensionClusterInsetBottom)
            }
    }

    private var label: String {
        let date = SocialFormat.spokenDate(post.post.createdAt)
        var text = model.isOwn(post)
            ? Copy.photoViewerA11yPhotoMine(date: date)
            : Copy.photoViewerA11yPhoto(name: model.author(of: post)?.socialFirstName ?? "", date: date)
        if let caption = post.post.caption, !caption.isEmpty { text += ", " + Copy.chatThreadA11yCaption(caption: caption) }
        return text
    }

    private var sender: some View {
        let own = model.isOwn(post)
        return Button {
            SocialNav.push(own ? .social(.wallMine) : .social(.wallMember(userID: post.post.authorID.rawValue)))
        } label: {
            HStack(alignment: .top, spacing: Tokens.Sizes.photoViewerDimensionSenderNameGap) {
                SocialAvatar(path: model.author(of: post)?.avatarPath, diameter: Tokens.Sizes.photoViewerDimensionSenderAvatar)
                Text(own ? Copy.photoViewerTitleYou : (model.author(of: post)?.socialFirstName ?? ""))
                    .dsTextStyle(TextRole.headerTitle)
                    .foregroundStyle(Tokens.Colors.globalTextPrimary)
                    .lineLimit(1)
            }
            .padding(.leading, Tokens.Sizes.photoViewerDimensionSenderInsetLeading)
            .padding(.top, Tokens.Sizes.photoViewerDimensionSenderInsetTop)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(own ? Copy.photoViewerTitleYou : (model.author(of: post)?.socialFirstName ?? "")))
    }

    /// The memory group's "i'm in this" control (`tagging`), drawn from this model's state: optimistic toggle,
    /// first-use coach, toasts and haptics come from `PhotoViewerModel`. Its centre sits
    /// `photo.viewer.dimension.actionCenterTop` below the photo's top, `.actionTrailing` from its right edge.
    private var tagging: some View {
        SelfTagToggleControl(
            isOn: model.tagged[post.id] ?? false,
            isPending: model.tagPending.contains(post.id),
            showsCoach: model.coachVisible && model.selection == post.id,
            onToggle: { Task { await model.toggleTag() } },
            onDismissCoach: { model.dismissCoach() }
        )
        .padding(.trailing, Tokens.Sizes.photoViewerDimensionActionTrailing)
        .padding(.top, Tokens.Sizes.photoViewerDimensionActionCenterTop - max(Tokens.Sizes.globalButtonHeight, Tokens.Sizes.globalMinTouchTargetIos) / 2)
    }
}

/// The picture itself: the grid thumbnail at once, replaced by `display_path` when loaded (docs/API.md §7); a dual
/// capture as `daily.dualimage` (capture group's `DualImageView`); a Live Photo plays while pressed (platform
/// `PHLivePhotoView`); a video with the platform player.
struct ViewerMedia: View {
    let post: PostWithMedia
    let maxPixel: Int?
    let accessibilityLabel: String

    @State private var failed = false

    var body: some View {
        Group {
            if let media = post.media {
                switch media.kind {
                case .video:
                    ViewerVideo(path: media.originalPath)
                default:
                    if media.frontOriginalPath != nil {
                        ViewerDualImage(media: media, maxPixel: maxPixel, accessibilityLabel: accessibilityLabel)
                    } else {
                        ZStack {
                            SocialPhoto(path: media.gridPath)
                            SocialPhoto(path: media.displayImagePath, maxPixel: maxPixel) {
                                Text(Copy.photoViewerErrorLoad)
                                    .dsTextStyle(TextRole.emptyDetail)
                                    .foregroundStyle(Tokens.Colors.globalTextSecondary)
                            }
                            if media.kind == .livePhoto { ViewerLivePhoto(media: media) }
                        }
                    }
                }
            } else {
                Text(Copy.photoViewerErrorLoad)
                    .dsTextStyle(TextRole.emptyDetail)
                    .foregroundStyle(Tokens.Colors.globalTextSecondary)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(accessibilityLabel))
        .accessibilityAddTraits(.isImage)
    }
}

/// `daily.dualimage` for a post with a front photo.
struct ViewerDualImage: View {
    let media: Media
    let maxPixel: Int?
    let accessibilityLabel: String

    @State private var main: UIImage?
    @State private var inset: UIImage?

    var body: some View {
        DualImageView(main: main, inset: inset, accessibilityLabel: accessibilityLabel)
            .task(id: media.id) {
                if let path = media.displayImagePath { main = await SocialServices.shared.images.load(path, maxPixel: maxPixel) }
                if let path = media.frontImagePath(for: .display) { inset = await SocialServices.shared.images.load(path, maxPixel: maxPixel) }
            }
    }
}

/// A Live Photo: the still and its motion (the pair that constitutes it, PLATFORM_CONSTRAINTS §6) are downloaded
/// when the page shows; the platform view plays it while pressed.
struct ViewerLivePhoto: View {
    let media: Media
    @State private var livePhoto: PHLivePhoto?

    var body: some View {
        Group {
            if let livePhoto {
                LivePhotoRepresentable(livePhoto: livePhoto)
            }
        }
        .task(id: media.id) {
            guard livePhoto == nil, let motionPath = media.motionPath else { return }
            let data = SocialServices.shared.data
            guard let stillURL = try? await data.fileURL(path: media.originalPath),
                  let motionURL = try? await data.fileURL(path: motionPath),
                  let still = await SocialImageLoader.download(stillURL),
                  let motion = await SocialImageLoader.download(motionURL),
                  let stillFile = try? SocialVoiceFiles.writeMedia(still, name: media.id.rawValue + "-still", fileExtension: "jpg"),
                  let motionFile = try? SocialVoiceFiles.writeMedia(motion, name: media.id.rawValue + "-motion", fileExtension: "mov")
            else { return }
            livePhoto = await LivePhotoLoader.load(still: stillFile, motion: motionFile)
        }
    }
}

enum LivePhotoLoader {
    /// `PHLivePhoto.request(withResourceFileURLs:…)`; nil if the pair does not form a Live Photo. The handler may run
    /// on any queue and more than once (degraded first); the continuation resumes once.
    @MainActor
    static func load(still: URL, motion: URL) async -> PHLivePhoto? {
        let result = await withCheckedContinuation { (continuation: CheckedContinuation<Loaded, Never>) in
            let once = ResumeOnce()
            PHLivePhoto.request(
                withResourceFileURLs: [still, motion], placeholderImage: nil, targetSize: .zero, contentMode: .aspectFill
            ) { @Sendable photo, info in
                let degraded = (info[PHLivePhotoInfoIsDegradedKey] as? Bool) ?? false
                guard !degraded || photo == nil, once.claim() else { return }
                continuation.resume(returning: Loaded(photo: photo))
            }
        }
        return result.photo
    }

    /// Carries the finished photo out of the handler (it is only read once the request is complete).
    private struct Loaded: @unchecked Sendable {
        let photo: PHLivePhoto?
    }

    private final class ResumeOnce: @unchecked Sendable {
        private let lock = NSLock()
        private var done = false

        func claim() -> Bool {
            lock.lock()
            defer { lock.unlock() }
            guard !done else { return false }
            done = true
            return true
        }
    }
}

struct LivePhotoRepresentable: UIViewRepresentable {
    let livePhoto: PHLivePhoto

    func makeUIView(context: Context) -> PHLivePhotoView {
        let view = PHLivePhotoView()
        view.contentMode = .scaleAspectFill
        view.clipsToBounds = true
        return view
    }

    func updateUIView(_ view: PHLivePhotoView, context: Context) {
        view.livePhoto = livePhoto
    }
}

/// Video posts (premium): the platform player (not observed in Yope, spec Gaps).
struct ViewerVideo: View {
    let path: String
    @State private var player: AVPlayer?

    var body: some View {
        VideoPlayer(player: player)
            .task(id: path) {
                guard player == nil, let url = try? await SocialServices.shared.data.fileURL(path: path) else { return }
                player = AVPlayer(url: url)
            }
            .onDisappear { player?.pause() }
    }
}

/// The viewer's reply row (`photo.viewer` Structure 4): the composer field with `photo.viewer.reply.placeholder`, the
/// quick reactions 🔥 💖 and the add-reaction glyph inside its right end (`chat.reactions.layout.quickReactions`), then
/// the camera circle, whose slot shows the lime send circle while the field has text (`chat.composer.layout.typingState`).
/// Quick reactions use the field's text role (their size was not measured).
struct ViewerReplyRow: View {
    @Binding var text: String
    let groupName: String
    let send: () -> Void
    let react: (String) -> Void
    let openPicker: () -> Void
    let camera: () -> Void

    private static let fieldInset = SocialMetrics.singleLineInset(height: Tokens.Sizes.chatComposerDimensionFieldHeight, style: TextRole.body)

    private var quickEmoji: [String] {
        Tokens.Layouts.ChatReactionsLayoutQuickReactions.emoji.split(separator: " ").map(String.init)
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            HStack(alignment: .bottom) {
                TextField(
                    text: $text,
                    prompt: Text(Copy.photoViewerReplyPlaceholder(groupName: groupName)).foregroundStyle(Tokens.Colors.globalTextSecondary),
                    axis: .vertical
                ) {
                    Text(Copy.photoViewerReplyPlaceholder(groupName: groupName))
                }
                .dsTextStyle(TextRole.body)
                .foregroundStyle(Tokens.Colors.globalTextPrimary)
                .padding(.vertical, Self.fieldInset)
                .accessibilityIdentifier("photo.viewer.reply") // provenance-ok: accessibility identifier for UI tests
                ForEach(quickEmoji, id: \.self) { emoji in
                    Button { react(emoji) } label: {
                        Text(emoji)
                            .dsTextStyle(TextRole.body)
                            .frame(minHeight: Tokens.Sizes.chatComposerDimensionFieldHeight)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(Copy.chatReactionsA11yQuick(emojiName: SocialEmoji.name(emoji))))
                }
                Button(action: openPicker) {
                    Image(systemName: Tokens.Icons.chatReactionsIconAdd)
                        .dsTextStyle(TextRole.body)
                        .foregroundStyle(Tokens.Colors.globalTextSecondary)
                        .frame(minHeight: Tokens.Sizes.chatComposerDimensionFieldHeight)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(Copy.chatReactionsA11yAdd))
            }
            .padding(.horizontal, Tokens.Sizes.chatComposerDimensionFieldPaddingLeading)
            .frame(maxWidth: .infinity, minHeight: Tokens.Sizes.chatComposerDimensionFieldHeight, alignment: .leading)
            .background(Tokens.Colors.globalControl, in: Capsule())
            .socialRim(Capsule(), top: Tokens.Colors.chatComposerColorFieldRimTop, bottom: Tokens.Colors.chatComposerColorFieldRimBottom, width: Tokens.Sizes.chatComposerDimensionFieldRim)

            Group {
                if hasText {
                    // `chat.composer.layout.typingState`: the camera circle's slot shows the lime send circle.
                    SendCircle(identifier: "photo.viewer.send", action: send) // provenance-ok: accessibility identifier for UI tests
                } else {
                    Button(action: camera) {
                        Image(systemName: Tokens.Icons.globalCamera)
                            .resizable()
                            .scaledToFit()
                            .frame(height: Tokens.Sizes.chatComposerDimensionCameraGlyph)
                            .foregroundStyle(Tokens.Colors.globalTextPrimary)
                            .frame(width: Tokens.Sizes.chatComposerDimensionSideButton, height: Tokens.Sizes.chatComposerDimensionSideButton)
                            .background(Tokens.Colors.globalControlRaised, in: Circle())
                            .contentShape(Circle().inset(by: -max(0, Tokens.Sizes.globalMinTouchTargetIos - Tokens.Sizes.chatComposerDimensionSideButton) / 2))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(Copy.chatComposerA11yCamera))
                }
            }
            .padding(.leading, Tokens.Sizes.chatComposerDimensionGapFieldButton)
        }
        .padding(.leading, Tokens.Sizes.chatComposerDimensionInsetLeading)
        .padding(.trailing, Tokens.Sizes.chatComposerDimensionInsetTrailing)
        .padding(.bottom, Tokens.Sizes.chatComposerDimensionBottomInset)
    }

    private var hasText: Bool { !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
}
