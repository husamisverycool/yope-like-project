// Surface: chat.thread (with chat.composer, chat.voice and chat.reactions inside it) — reference app: Yope
// (reactions: Locket). Spec: design/surfaces/chat.thread.md, chat.composer.md, chat.voice.md, chat.reactions.md.
// References: references/auto/yope/store/yope-store-05.png (primary, lossless; coordinates in
// references/auto/yope/frames/b-derot-store-05-rot-1.68.png), references/auto/yope/frames/
// b-yopeapp-7591560669967682847-t49.50-reply-to-photo.png (reply quote), a-itsmthuyope-7644974799302823175-
// t51.23-group-created-empty-state.png (empty state), references/auto/locket/store/locket-store-04.png (cluster).
import AppData
import AppModels
import DesignSystem
import SwiftUI
import UIKit

struct ChatThreadView: View {
    @Bindable var model: ChatThreadModel

    @State private var toasts = ToastCenter()
    @State private var viewer: PhotoViewerContext?
    @State private var pickerTarget: ReactionPickerTarget?
    @State private var activityTarget: ReactionActivityTarget?
    @State private var deleteCandidate: Message?
    @State private var replyCamera: PhotoReplyHandoff.Target?
    /// The bottom-most visible message (keeps the reading position when older pages load or messages arrive).
    @State private var anchor: MessageID?
    @State private var didScrollToFocus = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    #if DEBUG
    @State private var recording = SocialVoiceRecording()
    @State private var micDenied = false
    #endif

    var body: some View {
        ZStack {
            Tokens.Colors.globalBackground.ignoresSafeArea()
            // Behind the messages, in front of the background (`chat.reactions.layout.rainPath`).
            EmojiRain(trigger: model.sentReaction)
            content
        }
        .safeAreaInset(edge: .top, spacing: 0) { header }
        .safeAreaInset(edge: .bottom, spacing: 0) { composerArea }
        .socialHidesNavigationBar()
        .task {
            if model.phase == .loading {
                await model.load()
            } else {
                await model.refresh()
            }
            await model.run()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await model.refresh() } }
        }
        .onChange(of: model.arrival) { _, message in
            if let message { AccessibilityNotification.Announcement(accessibilityLabel(for: message)).post() }
        }
        .socialFeedback(model.signals.feedback)
        .socialNotices(model.signals.notice, toasts: toasts)
        .toastHost(toasts)
        .fullScreenCover(item: $viewer, onDismiss: openReplyCamera) { context in
            PhotoViewerView(context: context, presentation: .cover { target in replyCamera = target })
        }
        .sheet(item: $pickerTarget) { target in
            ReactionPicker { emoji in
                Task { await model.react(postID: target.postID, emoji: emoji) }
            }
        }
        .sheet(item: $activityTarget) { target in
            ReactionActivitySheet(
                reactions: model.reactions[target.postID] ?? ReactionSummary(),
                me: model.me,
                posterFirstName: model.posts[target.postID].flatMap { model.profile($0.post.authorID)?.socialFirstName } ?? "",
                nameOf: { model.profile($0)?.socialFirstName ?? "" }
            )
        }
        .confirmationDialog(
            Copy.chatThreadDeleteMessageTitle,
            isPresented: Binding(get: { deleteCandidate != nil }, set: { if !$0 { deleteCandidate = nil } }),
            titleVisibility: .visible,
            presenting: deleteCandidate
        ) { message in
            Button(Copy.photoViewerDeleteConfirm, role: .destructive) {
                Task { await model.delete(message) }
            }
            Button(Copy.photoViewerDeleteCancel, role: .cancel) {}
        } message: { _ in
            Text(Copy.chatThreadDeleteMessageMessage)
        }
        .socialClearsReplyHandoff()
        .accessibilityIdentifier("chat.thread") // provenance-ok: accessibility identifier for UI tests
    }

    /// After the viewer closed for a reply with a photo: the camera opens (`AppModal.camera` at the root).
    private func openReplyCamera() {
        guard let target = replyCamera else { return }
        replyCamera = nil
        SocialNav.router.presentCameraReplying(toPost: target.postID, groupID: target.groupID)
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: Tokens.Sizes.globalHeaderGap) {
            HeaderCircleButton(icon: Tokens.Icons.globalBack, accessibilityLabel: Copy.chatThreadA11yBack, fill: .onBackground) {
                dismiss()
            }
            groupCapsule
            Spacer(minLength: 0)
            if let recapID = model.latestRecapID {
                HeaderCircleButton(icon: Tokens.Icons.globalRecap, accessibilityLabel: Copy.chatThreadA11yRecap, fill: .onBackground) {
                    SocialNav.push(.recap(groupID: model.groupID.rawValue, recapID: recapID.rawValue))
                }
            }
        }
        .padding(.horizontal, Tokens.Sizes.globalHeaderInset)
    }

    /// Group avatar · name · › in a `color.global.control` capsule (insides as the groups.screen header capsule;
    /// the avatar sits centred in the capsule's height, so its start inset equals its top inset — not measured).
    private var groupCapsule: some View {
        let inset = (Tokens.Sizes.chatThreadDimensionHeaderCapsuleHeight - Tokens.Sizes.globalAvatarHeader) / 2
        return Button {
            SocialNav.push(.account(.groupProfile(groupID: model.groupID.rawValue)))
        } label: {
            HStack {
                SocialAvatar(path: model.group?.coverPath, diameter: Tokens.Sizes.globalAvatarHeader, placeholderIcon: Tokens.Icons.globalGroup)
                Text(model.group?.name ?? "")
                    .dsTextStyle(TextRole.headerTitle)
                    .foregroundStyle(Tokens.Colors.globalTextPrimary)
                    .lineLimit(1)
                Image(systemName: Tokens.Icons.globalChevron)
                    .foregroundStyle(Tokens.Colors.globalTextSecondary)
            }
            .padding(.horizontal, inset)
            .frame(minHeight: Tokens.Sizes.chatThreadDimensionHeaderCapsuleHeight)
            .background(Tokens.Colors.globalControl, in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(Copy.chatThreadA11yGroupCapsule(groupName: model.group?.name ?? "")))
    }

    // MARK: Content by state

    @ViewBuilder
    private var content: some View {
        switch model.phase {
        case .loading:
            if model.showsLoading { LoadingHUD() }
        case .empty:
            emptyState
        case .failed:
            EmptyStateView(
                title: Copy.chatThreadErrorTitle,
                detail: Copy.chatThreadErrorDetail,
                action: .init(Copy.chatThreadErrorRetry) { Task { await model.retry() } }
            )
        case .offline:
            EmptyStateView(title: Copy.chatThreadOfflineTitle, detail: Copy.chatThreadOfflineDetail)
        case .ready:
            messageList
        }
    }

    private var emptyState: some View {
        let names = model.addedMemberNames
        return EmptyStateView(
            title: model.viewerCreatedGroup ? Copy.chatThreadEmptyTitleCreator : Copy.chatThreadEmptyTitleMember(name: model.creatorFirstName ?? ""),
            detail: names.isEmpty ? nil : Copy.chatThreadEmptyDetail(names: names.joined(separator: ", ")),
            action: .init(Copy.chatThreadEmptyInvite, icon: Tokens.Icons.globalLink) {
                SocialNav.present(.account(.groupInvite(groupID: model.groupID.rawValue)))
            }
        )
    }

    // MARK: Messages

    private var messageList: some View {
        let rows = ChatRowLayout.rows(model.messages, me: model.me)
        return ScrollView {
            LazyVStack(spacing: 0) {
                if model.hasOlder {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .task(id: model.messages.first?.id) { await model.loadOlder() }
                }
                ForEach(rows) { row in
                    ChatMessageRow(
                        row: row,
                        model: model,
                        openPhoto: { postID in
                            viewer = PhotoViewerContext(postIDs: model.photoPostIDs, start: postID, groupID: model.groupID)
                        },
                        react: { pickerTarget = ReactionPickerTarget(postID: $0) },
                        showReactions: { activityTarget = ReactionActivityTarget(postID: $0) },
                        delete: { deleteCandidate = $0 },
                        report: report,
                        playFailed: { toasts.show(Copy.chatVoiceErrorPlay) }
                    )
                    .padding(.top, gap(row.gap))
                    .onAppear {
                        // Prefetch the next older page before the top is reached.
                        if row.id == prefetchID(rows), model.hasOlder { Task { await model.loadOlder() } }
                    }
                }
            }
            .scrollTargetLayout()
        }
        .defaultScrollAnchor(.bottom)
        .scrollPosition(id: $anchor, anchor: .bottom)
        .scrollDismissesKeyboard(.interactively)
        .onChange(of: model.messages.last?.id) { old, new in
            // Follow new messages only when the reader was at the bottom (or sent it).
            guard let new else { return }
            if anchor == nil || anchor == old || model.messages.last.map(model.isMine) == true { anchor = new }
        }
        .onAppear(perform: scrollToFocus)
        .onChange(of: model.messages.count) { _, _ in scrollToFocus() }
    }

    /// A row a little below the top: reaching it loads the next older page.
    private func prefetchID(_ rows: [ChatRowLayout]) -> MessageID? {
        let lead = SocialPaging.messages / 5
        return rows.indices.contains(lead) ? rows[lead].id : rows.first?.id
    }

    /// Deep link (`DeepLink.chatMessage`): the thread opens on that message.
    private func scrollToFocus() {
        guard !didScrollToFocus, let focus = model.focusMessageID, model.messages.contains(where: { $0.id == focus }) else { return }
        didScrollToFocus = true
        anchor = focus
    }

    private func gap(_ gap: ChatGap) -> CGFloat {
        switch gap {
        case .none: return 0
        case .sameSender: return Tokens.Sizes.chatThreadDimensionGapSameSender
        case .textToVoice: return Tokens.Sizes.chatThreadDimensionGapTextToVoice
        case .photo: return Tokens.Sizes.chatThreadDimensionPhotoGap
        case .betweenSenders: return Tokens.Sizes.chatThreadDimensionGapBetweenSenders
        }
    }

    /// `safety.report` for another member's text / voice message (account group's sheet).
    private func report(_ message: Message) {
        let name = model.profile(message.authorID)?.socialFirstName ?? ""
        SocialNav.report(ReportTarget(
            kind: .message, id: message.id.rawValue, name: nil,
            person: BlockTarget(userID: message.authorID.rawValue, firstName: name)
        ))
    }

    private func accessibilityLabel(for message: Message) -> String {
        let name = model.profile(message.authorID)?.socialFirstName ?? ""
        switch message.kind {
        case .voice:
            return Copy.chatVoiceA11yMessage(name: name, duration: SocialFormat.spokenDuration(milliseconds: message.voiceDurationMs ?? 0))
        case .photo:
            return Copy.chatThreadA11yPhoto(name: name, time: SocialFormat.time(message.createdAt))
        default:
            return Copy.chatThreadA11yMessage(name: name, message: message.body ?? "")
        }
    }

    // MARK: Composer

    private var composerArea: some View {
        VStack(spacing: Tokens.Sizes.globalListGap) {
            #if DEBUG
            if micDenied {
                PermissionCard(
                    title: Copy.chatVoicePermissionTitle,
                    detail: Copy.chatVoicePermissionDetail,
                    buttonTitle: Copy.chatVoicePermissionButton,
                    onEnable: openSettings,
                    onDismiss: { micDenied = false }
                )
                .padding(.horizontal, Tokens.Sizes.onboardingPermissionContactsSizeCardMarginH)
            }
            #endif
            ChatComposer(
                text: $model.draft,
                send: { Task { await model.sendDraft() } },
                camera: { SocialNav.openCamera(groupID: model.groupID.rawValue) },
                mic: micAction
            )
        }
    }

    /// `chat.voice.layout.recording` is BLOCKED: release builds have no mic circle; DEBUG builds tap to record and tap
    /// again to send (no recording UI).
    private var micAction: (() -> Void)? {
        #if DEBUG
        return {
            Task {
                switch await recording.toggle() {
                case let .success(finished):
                    if let finished {
                        await model.sendVoice(fileURL: finished.fileURL, durationMs: finished.durationMs)
                    } else if !recording.permission.allowsAccess {
                        micDenied = true
                    }
                case .failure:
                    model.voiceRecordingFailed()
                }
            }
        }
        #else
        return SocialBlocked.hasRecordingLayout ? {} : nil
        #endif
    }

    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
    }
}

// MARK: - One message

struct ChatMessageRow: View {
    let row: ChatRowLayout
    let model: ChatThreadModel
    let openPhoto: (PostID) -> Void
    let react: (PostID) -> Void
    let showReactions: (PostID) -> Void
    let delete: (Message) -> Void
    let report: (Message) -> Void
    let playFailed: () -> Void

    private var message: Message { row.message }
    private var authorName: String { model.profile(message.authorID)?.socialFirstName ?? "" }

    var body: some View {
        if message.kind == .photo {
            photoRow
        } else {
            bubbleRow
        }
    }

    // Another member's messages: avatar column (`chat.thread.dimension.avatarInset`, `size.global.avatarSmall`,
    // `chat.thread.dimension.avatarGap`); mine: right-aligned at `chat.thread.dimension.bubbleInsetMine`. Bubbles are
    // bounded by the opposite side's inset while `chat.thread.dimension.bubbleMaxWidth` is BLOCKED.
    private var bubbleRow: some View {
        HStack(alignment: .bottom, spacing: 0) {
            if row.isMine {
                Spacer(minLength: Tokens.Sizes.chatThreadDimensionBubbleInsetTheirs)
                bubbleContent
                    .padding(.trailing, Tokens.Sizes.chatThreadDimensionBubbleInsetMine)
            } else {
                avatarColumn
                bubbleContent
                Spacer(minLength: Tokens.Sizes.chatThreadDimensionBubbleInsetMine)
            }
        }
    }

    private var avatarColumn: some View {
        Group {
            if row.showsAvatar {
                Button {
                    SocialNav.push(.social(.wallMember(userID: message.authorID.rawValue)))
                } label: {
                    SocialAvatar(path: model.profile(message.authorID)?.avatarPath, diameter: Tokens.Sizes.globalAvatarSmall)
                }
                .buttonStyle(.plain)
                .accessibilityHidden(true)
            } else {
                Color.clear.frame(width: Tokens.Sizes.globalAvatarSmall, height: Tokens.Sizes.globalAvatarSmall)
            }
        }
        .padding(.leading, Tokens.Sizes.chatThreadDimensionAvatarInset)
        .padding(.trailing, Tokens.Sizes.chatThreadDimensionAvatarGap)
    }

    @ViewBuilder
    private var bubbleContent: some View {
        switch message.kind {
        case .voice:
            VoiceBubble(
                key: message.id.rawValue,
                path: message.voicePath,
                localFile: model.localVoiceFiles[message.id],
                durationMs: message.voiceDurationMs ?? 0,
                isMine: row.isMine,
                accessibilityLabel: row.isMine
                    ? Copy.chatVoiceA11yMessageMine(duration: SocialFormat.spokenDuration(milliseconds: message.voiceDurationMs ?? 0))
                    : Copy.chatVoiceA11yMessage(name: authorName, duration: SocialFormat.spokenDuration(milliseconds: message.voiceDurationMs ?? 0)),
                onPlayFailed: playFailed
            )
            .contextMenu { menu }
            .accessibilityActions { menu }
        default:
            Group {
                if let replyTo = message.replyToPostID, let quoted = model.posts[replyTo] {
                    ReplyBubble(
                        quote: ReplyQuote(
                            posterFirstName: model.profile(quoted.post.authorID)?.socialFirstName ?? "",
                            thumbPath: quoted.media?.gridPath
                        ) { openPhoto(replyTo) },
                        text: message.body ?? "",
                        isMine: row.isMine,
                        accessibilityLabel: textLabel
                    )
                } else {
                    TextBubble(text: message.body ?? "", isMine: row.isMine, accessibilityLabel: textLabel)
                }
            }
            .contextMenu { menu }
            .accessibilityActions { menu }
        }
    }

    private var textLabel: String {
        row.isMine ? Copy.chatThreadA11yMessageMine(message: message.body ?? "") : Copy.chatThreadA11yMessage(name: authorName, message: message.body ?? "")
    }

    /// Native context menu: own text / voice → delete; another member's → report (`chat.thread` Data & actions).
    @ViewBuilder
    private var menu: some View {
        if row.isMine {
            Button(role: .destructive) { delete(message) } label: {
                Label(Copy.chatThreadMenuDelete, systemImage: Tokens.Icons.photoViewerIconDelete)
            }
        } else {
            Button(role: .destructive) { report(message) } label: {
                Label(Copy.chatThreadMenuReport, systemImage: Tokens.Icons.globalReport)
            }
        }
    }

    // MARK: Photo message

    /// From `chat.thread.dimension.bubbleInsetTheirs` to `chat.thread.dimension.photoInsetTrailing`, shape
    /// `chat.thread.dimension.photoWidth` × `.photoHeight`, `radius.global.photo`, aspect fill.
    private var photoRow: some View {
        HStack(alignment: .bottom, spacing: 0) {
            if row.isMine {
                Color.clear.frame(width: Tokens.Sizes.chatThreadDimensionBubbleInsetTheirs, height: 0)
            } else {
                avatarColumn
            }
            ChatPhotoMessage(
                post: message.postID.flatMap { model.posts[$0] },
                reactions: message.postID.flatMap { model.reactions[$0] } ?? ReactionSummary(),
                isMine: row.isMine,
                authorName: authorName,
                open: { if let id = message.postID { openPhoto(id) } },
                react: { if let id = message.postID { react(id) } },
                showReactions: { if let id = message.postID { showReactions(id) } }
            )
            .padding(.trailing, Tokens.Sizes.chatThreadDimensionPhotoInsetTrailing)
        }
    }
}

/// A text bubble: `chat.thread.radius.bubble`, height `chat.thread.dimension.bubbleHeight` per line (minimum),
/// `chat.thread.dimension.bubblePaddingH`, fill and hairline rim of the sender, text role `body`.
struct TextBubble: View {
    let text: String
    let isMine: Bool
    /// `chat.thread.a11y.message` / `.messageMine`.
    let accessibilityLabel: String

    private static let verticalInset = SocialMetrics.singleLineInset(height: Tokens.Sizes.chatThreadDimensionBubbleHeight, style: TextRole.body)

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Tokens.Radii.chatThreadRadiusBubble)
        Text(text)
            .dsTextStyle(TextRole.body)
            .foregroundStyle(Tokens.Colors.globalTextPrimary)
            .modifier(SocialMaxWidth(value: SocialBlocked.bubbleMaxWidth))
            .padding(.horizontal, Tokens.Sizes.chatThreadDimensionBubblePaddingH)
            .padding(.vertical, Self.verticalInset)
            .frame(minHeight: Tokens.Sizes.chatThreadDimensionBubbleHeight)
            .background(isMine ? Tokens.Colors.chatThreadColorBubbleMine : Tokens.Colors.chatThreadColorBubbleTheirs, in: shape)
            .socialRim(
                shape,
                top: isMine ? Tokens.Colors.chatThreadColorBubbleRimMineTop : Tokens.Colors.chatThreadColorBubbleRimTheirsTop,
                bottom: isMine ? Tokens.Colors.chatThreadColorBubbleRimMineBottom : Tokens.Colors.chatThreadColorBubbleRimTheirsBottom,
                width: Tokens.Sizes.chatThreadDimensionBubbleRim
            )
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(accessibilityLabel))
    }
}

/// Applies a maximum width only when it is known.
struct SocialMaxWidth: ViewModifier {
    let value: CGFloat?

    func body(content: Content) -> some View {
        if let value {
            content.frame(maxWidth: value, alignment: .leading)
        } else {
            content
        }
    }
}

/// Reply to a photo (S5-r): the lime quote part, then the sender's text bubble overlapping its bottom so the lime
/// shows behind the bubble's top corners. Width: the quote's natural width (`chat.thread.dimension.replyWidth`); a
/// longer text widens the text part (not observed).
struct ReplyBubble: View {
    let quote: ReplyQuote
    let text: String
    let isMine: Bool
    let accessibilityLabel: String

    var body: some View {
        VStack(alignment: isMine ? .trailing : .leading, spacing: 0) {
            quote
            TextBubble(text: text, isMine: isMine, accessibilityLabel: accessibilityLabel)
                .frame(minWidth: Tokens.Sizes.chatThreadDimensionReplyWidth)
                .padding(.top, -Tokens.Radii.chatThreadRadiusBubble)
        }
    }
}

/// The quote part: `chat.thread.dimension.replyQuoteHeight`, `color.global.accent`, top corners
/// `chat.thread.radius.replyQuote`; quote bar, poster's first name (cap top `replyNameCapTop`), "pic" (baseline
/// `replyLabelBaseline`), square thumbnail at the top-right.
struct ReplyQuote: View {
    let posterFirstName: String
    let thumbPath: String?
    let open: () -> Void

    @Environment(\.displayScale) private var displayScale

    var body: some View {
        let nameCap = SocialMetrics.capHeight(SocialText.replyName)
        Button(action: open) {
            ZStack(alignment: .topLeading) {
                UnevenRoundedRectangle(
                    topLeadingRadius: Tokens.Radii.chatThreadRadiusReplyQuote,
                    topTrailingRadius: Tokens.Radii.chatThreadRadiusReplyQuote
                )
                .fill(Tokens.Colors.globalAccent)
                Rectangle()
                    .fill(Tokens.Colors.globalOnAccent)
                    .frame(
                        width: Tokens.Sizes.chatThreadDimensionReplyQuoteBar,
                        height: Tokens.Sizes.chatThreadDimensionReplyLabelBaseline - Tokens.Sizes.chatThreadDimensionReplyNameCapTop
                    )
                    .alignmentGuide(.leading) { $0[.leading] - Tokens.Sizes.chatThreadDimensionReplyQuoteBarInset }
                    .alignmentGuide(.top) { $0[.top] - Tokens.Sizes.chatThreadDimensionReplyNameCapTop }
                Text(posterFirstName)
                    .dsTextStyle(SocialText.replyName)
                    .lineLimit(1)
                    .alignmentGuide(.leading) { $0[.leading] - Tokens.Sizes.chatThreadDimensionReplyTextInset }
                    .alignmentGuide(.top) { $0[.firstTextBaseline] - nameCap - Tokens.Sizes.chatThreadDimensionReplyNameCapTop }
                Text(Copy.chatThreadReplyPhotoLabel)
                    .dsTextStyle(SocialText.replyLabel)
                    .alignmentGuide(.leading) { $0[.leading] - Tokens.Sizes.chatThreadDimensionReplyTextInset }
                    .alignmentGuide(.top) { $0[.firstTextBaseline] - Tokens.Sizes.chatThreadDimensionReplyLabelBaseline }
            }
            .foregroundStyle(Tokens.Colors.globalOnAccent)
            .frame(width: Tokens.Sizes.chatThreadDimensionReplyWidth, height: Tokens.Sizes.chatThreadDimensionReplyQuoteHeight)
            .overlay(alignment: .topTrailing) {
                SocialPhoto(path: thumbPath, maxPixel: Int((Tokens.Sizes.chatThreadDimensionReplyThumb * displayScale).rounded(.up)))
                    .frame(width: Tokens.Sizes.chatThreadDimensionReplyThumb, height: Tokens.Sizes.chatThreadDimensionReplyThumb)
                    .clipShape(RoundedRectangle(cornerRadius: Tokens.Radii.chatThreadRadiusReplyThumb))
                    .padding(.top, Tokens.Sizes.chatThreadDimensionReplyThumbInsetTop)
                    .padding(.trailing, Tokens.Sizes.chatThreadDimensionReplyThumbInsetTrailing)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(Copy.chatThreadA11yReplyQuote(name: posterFirstName)))
    }
}

/// A photo message: time centred (text role `overlayTime`, `chat.thread.layout.timeFormat`), caption box,
/// reaction cluster bottom-left. Tap → viewer; long press → reaction picker (`haptic.global.reaction`: iOS plays the
/// system's only with a context menu, so no custom haptic here).
struct ChatPhotoMessage: View {
    let post: PostWithMedia?
    let reactions: ReactionSummary
    let isMine: Bool
    let authorName: String
    let open: () -> Void
    let react: () -> Void
    let showReactions: () -> Void

    @Environment(\.displayScale) private var displayScale

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Tokens.Radii.globalPhoto)
        ZStack {
            SocialPhoto(
                path: post?.media?.displayImagePath,
                maxPixel: Int((Tokens.Sizes.chatThreadDimensionPhotoWidth * displayScale).rounded(.up))
            )
            if let post {
                Text(SocialFormat.time(post.post.createdAt))
                    .dsTextStyle(TextRole.overlayTime)
                    .foregroundStyle(Tokens.Colors.globalTextPrimary)
                    .accessibilityHidden(true)
            }
        }
        .overlay(alignment: .bottom) {
            if let caption = post?.post.caption, !caption.isEmpty {
                PhotoCaption(text: caption)
                    .padding(.bottom, Tokens.Sizes.chatThreadDimensionCaptionInsetBottom)
            }
        }
        .overlay(alignment: .bottomLeading) {
            Button(action: showReactions) {
                ReactionCluster(emoji: reactions.distinctEmoji)
            }
            .buttonStyle(.plain)
            .padding(.leading, Tokens.Sizes.chatReactionsDimensionClusterInsetLeading)
            .padding(.bottom, Tokens.Sizes.chatReactionsDimensionClusterInsetBottom)
        }
        .aspectRatio(Tokens.Sizes.chatThreadDimensionPhotoWidth / Tokens.Sizes.chatThreadDimensionPhotoHeight, contentMode: .fit)
        .frame(maxWidth: .infinity)
        .clipShape(shape)
        .contentShape(shape)
        .onTapGesture(perform: open)
        .onLongPressGesture(perform: react)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(label))
        .accessibilityValue(Text(reactions.isEmpty ? "" : SocialEmoji.clusterLabel(reactions.distinctEmoji)))
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(.default, open)
        .accessibilityAction(named: Text(Copy.chatReactionsA11yAdd), react)
        .accessibilityAction(named: Text(Copy.chatReactionsActivityTitle), showReactions)
    }

    private var label: String {
        guard let post else { return "" }
        let time = SocialFormat.time(post.post.createdAt)
        var text = isMine ? Copy.chatThreadA11yPhotoMine(time: time) : Copy.chatThreadA11yPhoto(name: authorName, time: time)
        if let caption = post.post.caption, !caption.isEmpty { text += ", " + Copy.chatThreadA11yCaption(caption: caption) }
        return text
    }
}

// MARK: - Composer

/// `chat.composer`: lime camera circle · text field · mic circle on one centre line. The sticker circle is
/// do-not-build. The send control is BLOCKED (`chat.composer.layout.typingState`): the keyboard's return key sends.
/// The mic circle is drawn only while recording is available (`mic` non-nil).
struct ChatComposer: View {
    @Binding var text: String
    let send: () -> Void
    let camera: () -> Void
    let mic: (() -> Void)?

    private static let fieldInset = SocialMetrics.singleLineInset(height: Tokens.Sizes.chatComposerDimensionFieldHeight, style: TextRole.body)

    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            Button(action: camera) {
                Image(systemName: Tokens.Icons.globalCamera)
                    .resizable()
                    .scaledToFit()
                    .frame(height: Tokens.Sizes.chatComposerDimensionCameraGlyph)
                    .foregroundStyle(Tokens.Colors.globalOnAccent)
                    .frame(width: Tokens.Sizes.chatComposerDimensionCameraButton, height: Tokens.Sizes.chatComposerDimensionCameraButton)
                    .background(Tokens.Colors.globalAccent, in: Circle())
                    .contentShape(Circle().inset(by: -max(0, Tokens.Sizes.globalMinTouchTargetIos - Tokens.Sizes.chatComposerDimensionCameraButton) / 2))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(Copy.chatComposerA11yCamera))
            .padding(.trailing, Tokens.Sizes.chatComposerDimensionGapCameraField)

            field

            if let mic {
                Button(action: mic) {
                    Image(systemName: Tokens.Icons.globalMic)
                        .resizable()
                        .scaledToFit()
                        .frame(height: Tokens.Sizes.chatComposerDimensionMicGlyph)
                        .foregroundStyle(Tokens.Colors.globalTextPrimary)
                        .frame(width: Tokens.Sizes.chatComposerDimensionSideButton, height: Tokens.Sizes.chatComposerDimensionSideButton)
                        .background(Tokens.Colors.globalControlRaised, in: Circle())
                        .contentShape(Circle().inset(by: -max(0, Tokens.Sizes.globalMinTouchTargetIos - Tokens.Sizes.chatComposerDimensionSideButton) / 2))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(Copy.chatComposerA11yMic))
                .accessibilityIdentifier("chat.composer.mic") // provenance-ok: accessibility identifier for UI tests
                .padding(.leading, Tokens.Sizes.chatComposerDimensionGapFieldButton)
            }
        }
        .padding(.leading, Tokens.Sizes.chatComposerDimensionInsetLeading)
        .padding(.trailing, Tokens.Sizes.chatComposerDimensionInsetTrailing)
        .padding(.bottom, SocialBlocked.composerBottomInset ?? 0)
    }

    private var field: some View {
        TextField(
            text: $text,
            prompt: Text(Copy.chatComposerPlaceholder).foregroundStyle(Tokens.Colors.globalTextSecondary),
            axis: .vertical
        ) {
            Text(Copy.chatComposerA11yField)
        }
        .dsTextStyle(TextRole.body)
        .foregroundStyle(Tokens.Colors.globalTextPrimary)
        .submitLabel(.send)
        .onSubmit(send)
        .onChange(of: text) { _, new in
            // Return sends (vertical text fields insert a newline instead of submitting).
            guard new.contains("\n") else { return }
            text = new.replacingOccurrences(of: "\n", with: "")
            send()
        }
        .padding(.horizontal, Tokens.Sizes.chatComposerDimensionFieldPaddingLeading)
        .padding(.vertical, Self.fieldInset)
        .frame(maxWidth: .infinity, minHeight: Tokens.Sizes.chatComposerDimensionFieldHeight, alignment: .leading)
        .background(Tokens.Colors.globalControl, in: Capsule())
        .socialRim(Capsule(), top: Tokens.Colors.chatComposerColorFieldRimTop, bottom: Tokens.Colors.chatComposerColorFieldRimBottom, width: Tokens.Sizes.chatComposerDimensionFieldRim)
        .accessibilityIdentifier("chat.composer.field") // provenance-ok: accessibility identifier for UI tests
    }
}
