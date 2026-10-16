// Surface: chat.thread (with chat.composer, chat.voice and chat.reactions inside it) — Retro: composition of C-02,
// C-16, C-18, C-15, C-20, C-13, C-27 in Apple Messages / WhatsApp's order (RS-1 … RS-6). Spec: design/surfaces/chat.thread.md.
// References: references/auto/retro/press/engadget-2026-08-the-problem-with-friends-only-socials-1786385236.jpg (pushed
// serif header), references/auto/retro/press/tc-2023-07-retro-2b.jpg phone 2 (comment rows, field),
// references/auto/retro/store/retro-store-01.png (photo card), references/auto/retro/press/tc-2024-04-journals-1.webp
// (dated section header), references/auto/retro/apk/retro-android-2026.10.1150-strings.txt (thread strings),
// mechanics references/auto/imessage/apple-support/messages-tapbacks-ios27.png, references/auto/whatsapp/store/whatsapp-store-04.png.
import AppData
import AppModels
import AppServices
import DesignSystem
import SwiftUI
import UIKit

struct ChatThreadView: View {
    @Bindable var model: ChatThreadModel

    @State private var toasts = ToastCenter()
    @State private var viewer: PhotoViewerContext?
    @State private var pickerTarget: ReactionPickerTarget?
    @State private var reactionsTarget: ReactionsSheetTarget?
    @State private var unsendCandidate: Message?
    @State private var deletePhotoCandidate: Message?
    /// The bottom-most visible message (keeps the reading position when older pages load or messages arrive).
    @State private var anchor: String?
    @State private var didScrollToFocus = false
    @State private var recorder = SocialVoiceRecorder()
    @State private var micDenied = false
    @FocusState private var fieldFocused: Bool
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    /// - Parameter recorder: the composer's voice recorder (snapshots pass one showing a recording state); nil → a new one.
    init(model: ChatThreadModel, recorder: SocialVoiceRecorder? = nil) {
        _model = Bindable(model)
        _recorder = State(initialValue: recorder ?? SocialVoiceRecorder())
    }

    var body: some View {
        ZStack {
            Tokens.Colors.globalBackground.ignoresSafeArea()
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
            guard phase == .active else { return }
            Task { await model.refresh() }
            recorder.refreshPermission()
        }
        .onChange(of: model.arrival) { _, message in
            if let message { AccessibilityNotification.Announcement(accessibilityLabel(for: message)).post() }
        }
        .socialFeedback(model.signals.feedback)
        .socialNotices(model.signals.notice, toasts: toasts)
        .toastHost(toasts)
        .socialAnnouncesLoading(model.showsLoading)
        .socialPhotoViewer($viewer)
        .sheet(item: $pickerTarget) { target in
            ReactionPicker(
                mine: model.myEmoji(on: target.postID),
                onPick: { emoji in Task { await model.react(postID: target.postID, emoji: emoji) } },
                onRemove: { emoji in Task { await model.unreact(postID: target.postID, emoji: emoji) } }
            )
        }
        .sheet(item: $reactionsTarget) { target in
            ReactionsSheet(
                reactions: model.reactions[target.postID] ?? ReactionSummary(),
                me: model.me,
                profile: { model.profile($0) },
                onRemove: { emoji in Task { await model.unreact(postID: target.postID, emoji: emoji) } }
            )
            .presentationDetents([.medium, .large])
        }
        .alert(
            Copy.chatThreadDeleteMessageTitle,
            isPresented: Binding(get: { unsendCandidate != nil }, set: { if !$0 { unsendCandidate = nil } }),
            presenting: unsendCandidate
        ) { message in
            Button(Copy.chatThreadDeleteMessageConfirm, role: .destructive) {
                Task { await model.delete(message) }
            }
            Button(Copy.photoViewerDeleteCancel, role: .cancel) {}
        } message: { _ in
            Text(Copy.chatThreadDeleteMessageMessage)
        }
        .confirmationDialog(
            Copy.photoViewerDeleteTitle,
            isPresented: Binding(get: { deletePhotoCandidate != nil }, set: { if !$0 { deletePhotoCandidate = nil } }),
            titleVisibility: .visible,
            presenting: deletePhotoCandidate
        ) { message in
            Button(Copy.photoViewerDeleteConfirm, role: .destructive) {
                Task { await model.deletePhoto(message) }
            }
            Button(Copy.photoViewerDeleteCancel, role: .cancel) {}
        } message: { _ in
            Text(Copy.photoViewerDeleteMessage)
        }
        .alert(Copy.chatVoicePermissionTitle, isPresented: $micDenied) {
            Button(Copy.chatVoicePermissionButton) { openSettings() }
            Button(Copy.photoViewerDeleteCancel, role: .cancel) {}
        } message: {
            Text(Copy.chatVoicePermissionDetail)
        }
        .alert(Copy.photoViewerPermissionTitle, isPresented: $model.saveDenied) {
            Button(Copy.photoViewerPermissionButton) { openSettings() }
            Button(Copy.photoViewerDeleteCancel, role: .cancel) {}
        } message: {
            Text(Copy.photoViewerPermissionDetail)
        }
        .socialClearsReplyHandoff()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("chat.thread") // provenance-ok: accessibility identifier for UI tests
    }

    // MARK: Header (C-02)

    /// Back chevron + the group's name in the display serif, one line; no trailing glyphs.
    private var header: some View {
        PushedScreenHeader(title: model.group?.name ?? "", backAccessibilityLabel: Copy.chatThreadA11yBack) { dismiss() }
            .lineLimit(1)
            .truncationMode(.tail)
            .background(Tokens.Colors.globalBackground)
    }

    // MARK: Content by state

    @ViewBuilder
    private var content: some View {
        switch model.phase {
        case .loading:
            if model.showsLoading {
                LoadingHUD()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        case .empty:
            centred(EmptyStateView(
                icon: Tokens.Icons.globalChats,
                title: Copy.chatThreadEmptyTitle,
                detail: Copy.chatThreadEmptyDetail,
                action: .init(Copy.chatThreadEmptyInvite) {
                    SocialNav.present(.account(.groupInvite(groupID: model.groupID.rawValue)))
                }
            ))
        case .failed:
            centred(EmptyStateView(
                title: Copy.chatThreadErrorTitle,
                detail: Copy.chatThreadErrorDetail,
                action: .init(Copy.chatThreadErrorRetry) { Task { await model.retry() } }
            ))
        case .offline:
            centred(EmptyStateView(title: Copy.chatThreadOfflineTitle, detail: Copy.chatThreadOfflineDetail))
        case .ready:
            messageList
        }
    }

    private func centred(_ view: some View) -> some View {
        VStack {
            Spacer(minLength: 0)
            view
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Messages

    private var messageList: some View {
        let entries = model.entries()
        return ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                if model.hasOlder {
                    ProgressView()
                        .tint(Tokens.Colors.globalTextSecondary)
                        .frame(maxWidth: .infinity)
                        .task(id: model.messages.first?.id) { await model.loadOlder() }
                }
                ForEach(entries) { entry in
                    entryView(entry)
                        .transition(.opacity)
                }
            }
            .padding(.bottom, Tokens.Sizes.globalTitleToContent)
            .scrollTargetLayout()
            .animation(
                DSAnimation.timing(duration: Tokens.Durations.chatThreadDurationEntry, easing: Tokens.Easings.chatThreadEasingEntry).animation,
                value: model.messages.map(\.id)
            )
        }
        .defaultScrollAnchor(.bottom)
        .scrollPosition(id: $anchor, anchor: .bottom)
        .scrollDismissesKeyboard(.interactively)
        .onChange(of: model.messages.last?.id) { old, new in
            // `chat.thread.layout.followNewest`: someone else's message is followed only while the reader is at the
            // bottom; my own sends go through `followRequest` (below), which also covers a reply sent from the viewer.
            guard let new, let last = model.messages.last, !model.isMine(last), viewer == nil else { return }
            if anchor == nil || anchor == old?.rawValue {
                anchor = new.rawValue
            }
        }
        .onChange(of: model.followRequest) { _, id in follow(id) }
        .onChange(of: viewer == nil) { _, closed in
            if closed { follow(model.followRequest) }
        }
        .onAppear { scrollToFocus() }
        .onChange(of: model.messages.count) { _, _ in scrollToFocus() }
    }

    @ViewBuilder
    private func entryView(_ entry: ChatEntry) -> some View {
        switch entry {
        case let .day(day, gap):
            SectionHeader(title: SocialFormat.dayDivider(day))
                .padding(.top, space(gap))
                .id(entry.id)
        case let .message(row):
            ChatMessageRow(
                row: row,
                model: model,
                actions: actions
            )
            .padding(.top, space(row.gap))
            .id(entry.id)
        }
    }

    /// `chat.thread.layout.runs.spacing`.
    private func space(_ gap: ChatGap) -> CGFloat {
        switch gap {
        case .none: return 0
        case .item: return Tokens.Sizes.chatThreadDimensionItemGap
        case .run: return Tokens.Sizes.globalListGap
        case .divider: return max(0, Tokens.Sizes.globalSectionGap - SocialMetrics.capTopOffset(TextRole.sectionLabel))
        case .afterDivider: return max(0, Tokens.Sizes.globalSectionHeaderToContent - SocialMetrics.belowBaseline(TextRole.sectionLabel))
        }
    }

    private var actions: ChatMessageActions {
        ChatMessageActions(
            openPhoto: { postID in
                let ids = model.photoPostIDs.contains(postID) ? model.photoPostIDs : [postID]
                viewer = PhotoViewerContext(postIDs: ids, start: postID, groupID: model.groupID)
            },
            openQuotedMessage: { id in anchor = id.rawValue },
            openWall: { SocialNav.openWall(of: $0, me: model.me) },
            reply: { message in
                model.startReply(to: message)
                fieldFocused = true
            },
            copy: { message in
                UIPasteboard.general.string = message.body
                model.copied()
            },
            save: { message in Task { await model.savePhoto(message, using: SocialServices.shared.saver) } },
            report: report,
            unsend: { unsendCandidate = $0 },
            deletePhoto: { deletePhotoCandidate = $0 },
            retry: { message in Task { await model.retry(message) } },
            react: { postID, emoji in Task { await model.toggleReaction(postID: postID, emoji: emoji) } },
            openPicker: { pickerTarget = ReactionPickerTarget(postID: $0) },
            openReactions: { reactionsTarget = ReactionsSheetTarget(postID: $0) }
        )
    }

    /// `chat.thread.layout.followNewest`: brings my just-sent message into view — at once from the composer, or as the
    /// photo viewer closes when the reply was sent from there (a covered list does not scroll).
    private func follow(_ id: MessageID?) {
        guard let id, viewer == nil, model.messages.contains(where: { $0.id == id }) else { return }
        Task { @MainActor in
            await Task.yield()
            self.anchor = id.rawValue
            self.model.didFollow(id)
        }
    }

    /// Deep link (`DeepLink.chatMessage`): the thread opens on that message.
    private func scrollToFocus() {
        guard !didScrollToFocus, let focus = model.focusMessageID, model.messages.contains(where: { $0.id == focus }) else { return }
        didScrollToFocus = true
        anchor = focus.rawValue
    }

    /// `safety.report` for another member's message (account group's sheet).
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

    /// The reply bar (when replying) `size.global.sectionHeaderToContent` from its baseline to the field, then the field.
    private var composerArea: some View {
        MetricStack {
            if let target = model.replyTarget {
                ChatReplyBar(label: replyLabel(target)) { model.cancelReply() }
                    .transition(.opacity)
            }
            ChatComposer(
                text: $model.draft,
                avatar: SocialImages.source(model.me.flatMap { model.profile($0) }?.avatarPath),
                isReplying: model.replyTarget != nil,
                send: { Task { await model.sendDraft() } },
                camera: openCamera,
                recorder: recorder,
                onRecorded: { recording in
                    Task { await model.sendVoice(fileURL: recording.fileURL, durationMs: recording.durationMs, levels: recording.levels) }
                },
                onRecordFailed: { model.voiceRecordingFailed() },
                onMicDenied: { micDenied = true },
                focus: $fieldFocused
            )
            .metricGap(model.replyTarget == nil ? 0 : Tokens.Sizes.globalSectionHeaderToContent, from: model.replyTarget == nil ? .top : .lastBaseline, to: .top)
        }
        .padding(.top, Tokens.Sizes.chatThreadDimensionItemGap)
        .background(Tokens.Colors.globalBackground)
        .dsAnimation(ComponentMotion.fade, value: model.replyTarget)
    }

    private func replyLabel(_ target: ChatReplyTarget) -> String {
        if target.author == model.me { return Copy.chatThreadReplyBarSelf }
        return Copy.chatThreadReplyBar(name: model.profile(target.author)?.socialFirstName ?? "")
    }

    /// The camera for this group; while the reply bar quotes a photo, the photo is sent as a reply to it.
    private func openCamera() {
        if let postID = model.replyPostID {
            SocialNav.router.presentCameraReplying(toPost: postID.rawValue, groupID: model.groupID.rawValue)
            model.cancelReply()
        } else {
            SocialNav.openCamera(groupID: model.groupID.rawValue)
        }
    }

    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
    }
}

// MARK: - One message

/// What a message row can do (the thread owns the sheets, alerts and navigation).
struct ChatMessageActions {
    let openPhoto: (PostID) -> Void
    let openQuotedMessage: (MessageID) -> Void
    let openWall: (UserID) -> Void
    let reply: (Message) -> Void
    let copy: (Message) -> Void
    let save: (Message) -> Void
    let report: (Message) -> Void
    let unsend: (Message) -> Void
    let deletePhoto: (Message) -> Void
    let retry: (Message) -> Void
    let react: (PostID, String) -> Void
    let openPicker: (PostID) -> Void
    let openReactions: (PostID) -> Void
}

/// A message in its run (`chat.thread.layout.runs`): the run's first message is the C-16 comment row — avatar
/// `size.global.avatarComment` at the margin with its top on the name line's ascender, then
/// `chat.thread.dimension.rowAvatarToText` after it the name (text role `listTitle`) and, one space after it, the time
/// (`chat.thread.layout.timeFormat`, text role `caption`, `color.global.textSecondary`). Every item sits in the text
/// column: text (`body`, first baseline `chat.thread.dimension.rowLinePitch` below the name's, lines at that pitch), the
/// C-18 photo card, the reaction chip `chat.reactions.dimension.chipTop` under the photo, the caption, the voice capsule,
/// the reply quote above the reply, the status line under my message in flight / failed; items
/// `chat.thread.dimension.itemGap` apart. Later messages of a run carry no avatar or name. Everyone's messages use the
/// same row (Retro shows every comment the same way).
struct ChatMessageRow: View {
    let row: ChatRow
    let model: ChatThreadModel
    let actions: ChatMessageActions

    private var message: Message { row.message }
    private var author: Profile? { model.profile(message.authorID) }
    private var authorName: String { author?.socialFirstName ?? "" }

    var body: some View {
        HStack(alignment: .top, spacing: Tokens.Sizes.chatThreadDimensionRowAvatarToText) {
            if row.startsRun {
                Button { actions.openWall(message.authorID) } label: {
                    AvatarView(source: SocialImages.source(author?.avatarPath), diameter: Tokens.Sizes.globalAvatarComment)
                }
                .buttonStyle(.plain)
                .accessibilityHidden(true)
            } else {
                Color.clear.frame(width: Tokens.Sizes.globalAvatarComment, height: 0)
            }
            column
        }
        .padding(.horizontal, Tokens.Sizes.globalScreenMargin)
    }

    private var column: some View {
        MetricStack {
            if row.startsRun {
                runHeader
            }
            if let quoted = model.quotedPost(of: message), message.kind != .photo {
                postQuote(quoted)
                    .metricGap(Tokens.Sizes.chatThreadDimensionItemGap, from: .bottom, to: .top)
            } else if let quoted = model.quotedMessage(of: message) {
                messageQuote(quoted)
                    .metricGap(Tokens.Sizes.chatThreadDimensionItemGap, from: .bottom, to: .top)
            }
            items
            if row.isMine, model.isPending(message) || model.isFailed(message) {
                statusLine
                    .metricGap(Tokens.Sizes.chatThreadDimensionItemGap, from: .bottom, to: .top)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Name · time on one baseline; a tap opens the person's wall. Hidden from VoiceOver (each message's label names its
    /// sender; the avatar and name are decorative next to it).
    private var runHeader: some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            Text(author?.displayName ?? "")
                .dsTextStyle(TextRole.listTitle)
                .foregroundStyle(Tokens.Colors.globalTextPrimary)
                .lineLimit(1)
            Text(" " + SocialFormat.time(message.createdAt))
                .dsTextStyle(TextRole.caption)
                .foregroundStyle(Tokens.Colors.globalTextSecondary)
                .lineLimit(1)
                .fixedSize()
        }
        .contentShape(Rectangle())
        .onTapGesture { actions.openWall(message.authorID) }
        .accessibilityHidden(true)
    }

    // MARK: Items

    @ViewBuilder
    private var items: some View {
        switch message.kind {
        case .photo:
            photoItems
        case .voice:
            voice
                .metricGap(Tokens.Sizes.chatThreadDimensionItemGap, from: .bottom, to: .top)
        default:
            text(message.body ?? "", label: textLabel)
        }
    }

    /// The text of a message (or a caption): after the name line its first baseline sits `rowLinePitch` below the
    /// name's; after another item, `itemGap` below it. 1–3 emoji only: `fontSize.global.headerTitle`.
    @ViewBuilder
    private func text(_ string: String, label: String, isCaption: Bool = false) -> some View {
        let afterHeader = row.startsRun && !isCaption && !model.hasQuote(message)
        if let count = SocialEmojiText.emojiOnlyCount(string), count <= Int(Tokens.Counts.chatThreadCountEmojiOnlyMax) {
            Text(string)
                .dsTextStyle(SocialTextRole.emojiOnly)
                .fixedSize()
                .modifier(MessageMenu(row: row, model: model, actions: actions))
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(label))
                .metricGap(Tokens.Sizes.chatThreadDimensionItemGap, from: .bottom, to: .top)
        } else {
            Text(string)
                .dsTextRole(SocialTextRole.threadBody)
                .foregroundStyle(Tokens.Colors.globalTextPrimary)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .modifier(MessageMenu(row: row, model: model, actions: actions))
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(label))
                .accessibilityValue(Text(model.isFailed(message) ? Copy.chatThreadSendFailed : ""))
                .metricGap(
                    afterHeader ? Tokens.Sizes.chatThreadDimensionRowLinePitch : Tokens.Sizes.chatThreadDimensionItemGap,
                    from: afterHeader ? .lastBaseline : .bottom,
                    to: afterHeader ? .firstBaseline : .top
                )
        }
    }

    private var textLabel: String {
        row.isMine ? Copy.chatThreadA11yMessageMine(message: message.body ?? "") : Copy.chatThreadA11yMessage(name: authorName, message: message.body ?? "")
    }

    private var voice: some View {
        let duration = SocialFormat.spokenDuration(milliseconds: message.voiceDurationMs ?? 0)
        return VoiceCapsule(
            key: message.id.rawValue,
            path: message.voicePath,
            localFile: model.localVoiceFiles[message.id],
            durationMs: message.voiceDurationMs ?? 0,
            levels: message.voiceLevels,
            accessibilityLabel: row.isMine ? Copy.chatVoiceA11yMessageMine(duration: duration) : Copy.chatVoiceA11yMessage(name: authorName, duration: duration)
        )
        .modifier(MessageMenu(row: row, model: model, actions: actions))
    }

    /// Photo card, reaction chip, caption, voice note (`chat.thread.layout.photoFit`, `chat.reactions.layout.chip`).
    @ViewBuilder
    private var photoItems: some View {
        let post = model.post(of: message)
        if let quoted = model.quotedPost(of: message) {
            postQuote(quoted)
                .metricGap(Tokens.Sizes.chatThreadDimensionItemGap, from: .bottom, to: .top)
        }
        photoCard(post)
            .metricGap(Tokens.Sizes.chatThreadDimensionItemGap, from: .bottom, to: .top)
        if let postID = message.postID, let summary = model.reactions[postID], !summary.isEmpty {
            ReactionChip(emoji: summary.distinctEmoji) { actions.openReactions(postID) }
                .accessibilityIdentifier("chat.reactions." + postID.rawValue) // provenance-ok: accessibility identifier for UI tests
                .metricGap(Tokens.Sizes.chatReactionsDimensionChipTop, from: .bottom, to: .top)
        }
        if let caption = post?.post.caption, !caption.isEmpty {
            text(caption, label: Copy.chatThreadA11yCaption(caption: caption), isCaption: true)
        }
        if let post, let voicePath = post.post.voicePath, let duration = post.post.voiceDurationMs {
            VoiceCapsule(
                key: post.id.rawValue,
                path: voicePath,
                durationMs: duration,
                levels: post.post.voiceLevels,
                accessibilityLabel: row.isMine
                    ? Copy.chatVoiceA11yMessageMine(duration: SocialFormat.spokenDuration(milliseconds: duration))
                    : Copy.chatVoiceA11yMessage(name: authorName, duration: SocialFormat.spokenDuration(milliseconds: duration))
            )
            .metricGap(Tokens.Sizes.chatThreadDimensionItemGap, from: .bottom, to: .top)
        }
    }

    /// C-18 photo card: `size.global.friendCardWidth` × `.friendCardHeight`, `radius.global.card`, aspect fill.
    private func photoCard(_ post: PostWithMedia?) -> some View {
        Button {
            if let id = message.postID { actions.openPhoto(id) }
        } label: {
            PhotoView(source: SocialImages.source(post?.media?.displayImagePath))
                .frame(width: Tokens.Sizes.globalFriendCardWidth, height: Tokens.Sizes.globalFriendCardHeight)
                .clipShape(DSShape.rounded(Tokens.Radii.globalCard))
                .contentShape(DSShape.rounded(Tokens.Radii.globalCard))
        }
        .buttonStyle(.plain)
        .modifier(MessageMenu(row: row, model: model, actions: actions))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(photoLabel(post)))
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("chat.photo." + (message.postID?.rawValue ?? "")) // provenance-ok: accessibility identifier for UI tests
    }

    private func photoLabel(_ post: PostWithMedia?) -> String {
        let time = SocialFormat.time(message.createdAt)
        return row.isMine ? Copy.chatThreadA11yPhotoMine(time: time) : Copy.chatThreadA11yPhoto(name: authorName, time: time)
    }

    // MARK: Quotes (`chat.thread.layout.replyQuote`)

    /// A quoted photo: a C-15 row — thumbnail `size.global.rowThumbWidth` × `.rowThumbHeight`, `radius.global.thumbnail`,
    /// then (`size.global.rowThumbGap`) "Post by {name}" (`listTitle`) over "Week {n}" (`listSubtitle`,
    /// `color.global.textSecondary`). Tap → the photo. (The shared `ThumbnailRow` always applies the screen margin, so
    /// it cannot sit in the text column — reported as a component gap.)
    private func postQuote(_ quoted: PostWithMedia) -> some View {
        let name = model.profile(quoted.post.authorID)?.socialFirstName ?? ""
        let week = SocialCalendar.weekNumber(containing: quoted.post.createdAt, in: model.timeZone)
        return Button { actions.openPhoto(quoted.id) } label: {
            HStack(alignment: .top, spacing: Tokens.Sizes.globalRowThumbGap) {
                PhotoView(source: SocialImages.source(quoted.media?.gridPath))
                    .frame(width: Tokens.Sizes.globalRowThumbWidth, height: Tokens.Sizes.globalRowThumbHeight)
                    .clipShape(DSShape.rounded(Tokens.Radii.globalThumbnail))
                VStack(alignment: .leading, spacing: 0) {
                    Text(Copy.chatThreadReplyPostTitle(name: name))
                        .dsTextStyle(TextRole.listTitle)
                        .foregroundStyle(Tokens.Colors.globalTextPrimary)
                    Text(Copy.chatThreadReplyPostWeek(weekNumber: String(week)))
                        .dsTextStyle(TextRole.listSubtitle)
                        .foregroundStyle(Tokens.Colors.globalTextSecondary)
                }
                .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(Copy.chatThreadA11yReplyQuote(name: name)))
        .accessibilityAddTraits(.isButton)
    }

    /// A quoted message: one grey line "**name** text…" (`listSubtitle`, `color.global.textSecondary`, the name in the
    /// `listTitle` weight), tail truncation. A voice / photo message reads "Attachment", an empty text "Message".
    private func messageQuote(_ quoted: Message) -> some View {
        let name = model.profile(quoted.authorID)?.socialFirstName ?? ""
        let body: String
        switch quoted.kind {
        case .voice, .photo: body = Copy.chatThreadReplyDefaultAttachment
        default: body = (quoted.body?.isEmpty == false ? quoted.body : nil) ?? Copy.chatThreadReplyDefaultText
        }
        let line = Text(name).fontWeight(Tokens.FontWeights.fontWeightGlobalListTitle) + Text(" " + body)
        return Button { actions.openQuotedMessage(quoted.id) } label: {
            line
                .dsTextStyle(TextRole.listSubtitle)
                .foregroundStyle(Tokens.Colors.globalTextSecondary)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(name) + Text(", " + body)) // provenance-ok: joins a name and a message (data)
    }

    // MARK: Status (`chat.thread.layout.failedMessage`)

    /// "Sending" (`color.global.textSecondary`) while in flight; "Couldn't send. Tap to retry" (`color.global.destructive`)
    /// after a failure — a tap sends it again. Text role `caption`.
    @ViewBuilder
    private var statusLine: some View {
        if model.isFailed(message) {
            Button { actions.retry(message) } label: {
                Text(Copy.chatThreadSendFailed)
                    .dsTextStyle(TextRole.caption)
                    .foregroundStyle(Tokens.Colors.globalDestructive)
            }
            .buttonStyle(.plain)
        } else {
            Text(Copy.chatThreadSending)
                .dsTextStyle(TextRole.caption)
                .foregroundStyle(Tokens.Colors.globalTextSecondary)
        }
    }
}

/// The native context menu of a message (C-29; items Sentence case, destructive last and red) and the same items as
/// accessibility custom actions.
/// - text: Reply · Copy · Report Message (others') / Unsend (mine)
/// - voice: Reply · Report Message / Unsend
/// - photo: the quick-reaction row · Reply · Save + Delete (mine) / Report Message (others' — no Save, owner decision 12)
/// - my failed message: Retry · Unsend
struct MessageMenu: ViewModifier {
    let row: ChatRow
    let model: ChatThreadModel
    let actions: ChatMessageActions

    private var message: Message { row.message }

    func body(content: Content) -> some View {
        content
            .contextMenu { items(includingPalette: true) }
            .accessibilityActions { items(includingPalette: false) }
    }

    @ViewBuilder
    private func items(includingPalette: Bool) -> some View {
        if model.isFailed(message) {
            Button(Copy.chatThreadMenuRetry) { actions.retry(message) }
            Button(Copy.chatThreadMenuDelete, role: .destructive) { actions.unsend(message) }
        } else if !model.isPending(message) {
            switch message.kind {
            case .photo:
                if includingPalette, let postID = message.postID {
                    QuickReactionsPalette(
                        mine: model.myEmoji(on: postID),
                        onEmoji: { actions.react(postID, $0) },
                        onAdd: { actions.openPicker(postID) }
                    )
                } else if let postID = message.postID {
                    Button(Copy.chatReactionsA11yAdd) { actions.openPicker(postID) }
                }
                Button(Copy.chatThreadMenuReply) { actions.reply(message) }
                if row.isMine {
                    Button(Copy.chatThreadMenuSave) { actions.save(message) }
                    Button(Copy.chatThreadMenuDeletePhoto, role: .destructive) { actions.deletePhoto(message) }
                } else {
                    Button(Copy.chatThreadMenuReport, role: .destructive) { actions.report(message) }
                }
            case .voice:
                Button(Copy.chatThreadMenuReply) { actions.reply(message) }
                if row.isMine {
                    Button(Copy.chatThreadMenuDelete, role: .destructive) { actions.unsend(message) }
                } else {
                    Button(Copy.chatThreadMenuReport, role: .destructive) { actions.report(message) }
                }
            default:
                Button(Copy.chatThreadMenuReply) { actions.reply(message) }
                Button(Copy.chatThreadMenuCopy) { actions.copy(message) }
                if row.isMine {
                    Button(Copy.chatThreadMenuDelete, role: .destructive) { actions.unsend(message) }
                } else {
                    Button(Copy.chatThreadMenuReport, role: .destructive) { actions.report(message) }
                }
            }
        }
    }
}
