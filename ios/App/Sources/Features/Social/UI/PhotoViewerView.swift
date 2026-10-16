// Surface: photo.viewer — Retro's media viewer (black page, header avatar + name + "Week N", "3 of 4" pill, close circle,
// full-width photo, footer place / date with the reaction slot, hairline, comment rows, comment field) and its native
// menu. Spec: design/surfaces/photo.viewer.md (RS-10 … RS-13); the tag run: design/surfaces/tagging.md (memory's TagRun).
// References: references/auto/retro/press/tc-2023-07-retro-2b.jpg phone 2 (primary, 2.209 px/pt),
// references/auto/retro/press/tc-2023-12-retro3.png phone 1, references/auto/retro/web/retro.app-j-welcome-iphone-full.png,
// references/auto/retro/press/tc-2025-12-rewind-panels.png (menu).
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
    @State private var reactionsOpen = false
    @State private var tagSheetOpen = false
    @State private var confirmingDelete = false
    @State private var unsendCandidate: Message?
    @State private var reportTarget: ReportTarget?
    @State private var blockTarget: BlockTarget?
    @State private var width: CGFloat = 0
    @FocusState private var fieldFocused: Bool
    @Environment(\.dismiss) private var dismiss
    @Environment(\.displayScale) private var displayScale
    @Environment(AccountDependencies.self) private var account: AccountDependencies?

    init(context: PhotoViewerContext, presentation: Presentation) {
        self.init(model: PhotoViewerModel(context: context, data: SocialServices.shared.data), presentation: presentation)
    }

    init(model: PhotoViewerModel, presentation: Presentation) {
        _model = State(initialValue: model)
        self.presentation = presentation
    }

    var body: some View {
        page
            // `photo.viewer.layout.appearance`: dark in both appearances; sheets and alerts follow the system.
            .environment(\.colorScheme, .dark)
            .socialHidesNavigationBar()
            .task {
                if model.phase == .loading { await model.load() }
                prefetchNeighbours()
                await model.run()
            }
            .onChange(of: model.selection) { _, _ in
                prefetchNeighbours()
                Task { await model.loadSelectedDetails() }
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
            .sheet(isPresented: $reactionsOpen) {
                if let post = model.current {
                    ReactionsSheet(
                        reactions: model.reactions[post.id] ?? ReactionSummary(),
                        me: model.me,
                        profile: { model.profiles[$0] },
                        onRemove: { emoji in Task { await model.unreact(emoji) } }
                    )
                    .presentationDetents([.medium, .large])
                }
            }
            .sheet(isPresented: $tagSheetOpen) {
                TaggingSheet(
                    people: tagPeople,
                    isTagged: model.isCurrentTagged,
                    isPending: model.tagPending.contains(model.selection),
                    onRemove: { Task { await model.toggleTag() } },
                    onTag: { Task { await model.toggleTag() } },
                    onClose: { tagSheetOpen = false }
                )
                .presentationDetents([.medium])
                .dsSheetBackground()
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
            .alert(
                Copy.chatThreadDeleteMessageTitle,
                isPresented: Binding(get: { unsendCandidate != nil }, set: { if !$0 { unsendCandidate = nil } }),
                presenting: unsendCandidate
            ) { message in
                Button(Copy.chatThreadDeleteMessageConfirm, role: .destructive) {
                    Task { await model.deleteComment(message) }
                }
                Button(Copy.photoViewerDeleteCancel, role: .cancel) {}
            } message: { _ in
                Text(Copy.chatThreadDeleteMessageMessage)
            }
            .alert(Copy.photoViewerPermissionTitle, isPresented: $model.saveDenied) {
                Button(Copy.photoViewerPermissionButton) {
                    if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                }
                Button(Copy.photoViewerDeleteCancel, role: .cancel) {}
            } message: {
                Text(Copy.photoViewerPermissionDetail)
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
        SocialImages.prefetch(paths, pixels: Int((width * displayScale).rounded(.up)))
    }

    // MARK: Page

    private var page: some View {
        VStack(spacing: 0) {
            header
            GeometryReader { area in
                ScrollView {
                    content(area: area.size)
                        .padding(.bottom, Tokens.Sizes.photoViewerDimensionCommentsToField)
                }
                .scrollBounceBehavior(.basedOnSize)
                .scrollDismissesKeyboard(.interactively)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Tokens.Colors.globalBackgroundDeep.ignoresSafeArea())
        .background {
            GeometryReader { proxy in
                Color.clear
                    .onAppear { width = proxy.size.width }
                    .onChange(of: proxy.size.width) { _, value in width = value }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) { replyField }
    }

    @ViewBuilder
    private func content(area: CGSize) -> some View {
        switch model.phase {
        case .loading:
            LoadingHUD()
                .frame(width: area.width, height: area.height)
        case .failed, .empty, .offline:
            errorLine { Task { await model.retry() } }
                .frame(width: area.width, height: area.height)
        case .ready:
            if model.isCurrentGone || model.current == nil {
                EmptyStateView(title: Copy.photoViewerGoneTitle, detail: Copy.photoViewerGoneDetail)
                    .frame(width: area.width, height: area.height)
            } else if let post = model.current {
                ViewerPostPage(
                    post: post,
                    model: model,
                    area: area,
                    menu: AnyView(menuItems),
                    openPicker: { pickerOpen = true },
                    openReactions: { reactionsOpen = true },
                    openTags: { tagSheetOpen = true },
                    replyToComment: { _ in fieldFocused = true },
                    unsendComment: { unsendCandidate = $0 },
                    reportComment: report(message:)
                )
                .id(post.id)
                .transition(.opacity)
            }
        }
    }

    /// One tappable line centred on the photo frame (text role `body`, `color.global.textSecondary`).
    private func errorLine(_ retry: @escaping () -> Void) -> some View {
        Button(action: retry) {
            Text(Copy.photoViewerErrorLoad)
                .dsTextStyle(TextRole.body)
                .foregroundStyle(Tokens.Colors.globalTextSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Tokens.Sizes.globalScreenMargin)
        }
        .buttonStyle(.plain)
    }

    // MARK: Header

    /// Avatar `size.global.avatarHeader` at `photo.viewer.dimension.headerInset`; `.headerAvatarToText` after it the
    /// name (`listTitle`, `color.global.textOnMedia`) over the week (`listSubtitle`, `color.global.textSecondary`),
    /// baselines `.headerLinePitch` apart, centred on the avatar; trailing the position pill (C-22, only for more than
    /// one photo), `size.global.pillGap`, then the close circle (`photo.viewer.dimension.closeCircle`,
    /// `color.global.controlOnDeep`, '×' ink `.closeGlyph` in `color.global.textOnMedia`) whose right edge sits on
    /// `size.global.screenMargin`.
    private var header: some View {
        HStack(spacing: 0) {
            if let post = model.current, !model.isCurrentGone {
                Button { SocialNav.openWall(of: post.post.authorID, me: model.me) } label: {
                    HStack(spacing: Tokens.Sizes.photoViewerDimensionHeaderAvatarToText) {
                        AvatarView(source: SocialImages.source(model.author(of: post)?.avatarPath), diameter: Tokens.Sizes.globalAvatarHeader)
                        MetricStack {
                            Text(model.author(of: post)?.displayName ?? "")
                                .dsTextStyle(TextRole.listTitle)
                                .foregroundStyle(Tokens.Colors.globalTextOnMedia)
                            Text(weekLine(post))
                                .dsTextStyle(TextRole.listSubtitle)
                                .foregroundStyle(Tokens.Colors.globalTextSecondary)
                                .metricGap(Tokens.Sizes.photoViewerDimensionHeaderLinePitch, from: .firstBaseline, to: .firstBaseline)
                        }
                        .lineLimit(1)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .combine)
            }
            Spacer(minLength: Tokens.Sizes.globalPillGap)
            if let position = model.position {
                PositionPill(label: Copy.photoViewerPosition(index: String(position.index), total: String(position.total)))
                    .padding(.trailing, Tokens.Sizes.globalPillGap)
                    .accessibilityLabel(Text(Copy.photoViewerPosition(index: String(position.index), total: String(position.total))))
            }
            Button { dismiss() } label: {
                Glyph(Tokens.Icons.globalClose, size: Tokens.Sizes.photoViewerDimensionCloseGlyph)
                    .foregroundStyle(Tokens.Colors.globalTextOnMedia)
                    .frame(width: Tokens.Sizes.photoViewerDimensionCloseCircle, height: Tokens.Sizes.photoViewerDimensionCloseCircle)
                    .background(Tokens.Colors.globalControlOnDeep, in: Circle())
                    .minimumHitArea(drawn: CGSize(width: Tokens.Sizes.photoViewerDimensionCloseCircle, height: Tokens.Sizes.photoViewerDimensionCloseCircle))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(Copy.photoViewerA11yClose))
            .accessibilitySortPriority(1)
            .accessibilityIdentifier("close") // provenance-ok: accessibility identifier for UI tests
        }
        .frame(minHeight: Tokens.Sizes.globalAvatarHeader)
        .padding(.leading, Tokens.Sizes.photoViewerDimensionHeaderInset)
        .padding(.trailing, Tokens.Sizes.globalScreenMargin)
    }

    /// "Week 28", or opened from a wall "{group} · Week 28" (`photo.viewer.header.week` / `.groupWeek`).
    private func weekLine(_ post: PostWithMedia) -> String {
        let number = String(model.weekNumber(of: post))
        if model.showsGroupName, let group = model.group(of: post) {
            return Copy.photoViewerHeaderGroupWeek(groupName: group.name, weekNumber: number)
        }
        return Copy.photoViewerHeaderWeek(weekNumber: number)
    }

    // MARK: Menu (`photo.viewer.layout.menu`)

    /// Save to Camera Roll (always) · Delete (mine, destructive) · Report Post (others', destructive) · Block {name}.
    @ViewBuilder
    private var menuItems: some View {
        Button { Task { await model.saveCurrent(using: SocialServices.shared.saver) } } label: {
            Label(Copy.photoViewerMenuSave, systemImage: Tokens.Icons.globalDownload)
        }
        if model.isCurrentOwn {
            Button(role: .destructive) { confirmingDelete = true } label: {
                Label(Copy.photoViewerMenuDelete, systemImage: Tokens.Icons.globalTrash)
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
            Button {
                blockTarget = BlockTarget(userID: post.post.authorID.rawValue, firstName: firstName)
            } label: {
                Text(Copy.photoViewerMenuBlock(name: firstName))
            }
        }
    }

    private func report(message: Message) {
        let name = model.profiles[message.authorID]?.socialFirstName ?? ""
        reportTarget = ReportTarget(
            kind: .message, id: message.id.rawValue, name: nil,
            person: BlockTarget(userID: message.authorID.rawValue, firstName: name)
        )
    }

    // MARK: Reply field (C-13 on media)

    /// `color.global.controlOnDeep`; own avatar; "Add a comment…"; trailing `icon.global.camera` then `icon.global.more`
    /// (the menu) in `color.global.textSecondary`; with text both become `icon.global.send`. On the safe area, on the
    /// keyboard while typing.
    @ViewBuilder
    private var replyField: some View {
        if model.phase == .ready, model.current != nil, !model.isCurrentGone {
            let hasText = !model.replyDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            HStack(alignment: .top, spacing: 0) {
                SocialFieldInput(
                    text: $model.replyDraft,
                    avatar: SocialImages.source(model.me.flatMap { model.profiles[$0] }?.avatarPath),
                    placeholder: Copy.photoViewerReplyPlaceholder,
                    accessibilityLabel: Copy.photoViewerReplyPlaceholder,
                    onMedia: true,
                    identifier: "photo.viewer.reply", // provenance-ok: accessibility identifier for UI tests
                    focus: $fieldFocused
                )
                Group {
                    if hasText {
                        SocialFieldGlyph(
                            icon: Tokens.Icons.globalSend, color: Tokens.Colors.globalTextPrimary,
                            accessibilityLabel: Copy.chatComposerA11ySend,
                            identifier: "photo.viewer.send" // provenance-ok: accessibility identifier for UI tests
                        ) { Task { await model.sendReply() } }
                    } else {
                        HStack(spacing: SocialFieldMetrics.glyphSpacing) {
                            SocialFieldGlyph(icon: Tokens.Icons.globalCamera, color: Tokens.Colors.globalTextSecondary, accessibilityLabel: Copy.chatComposerA11yCamera) {
                                replyWithPhoto()
                            }
                            Menu {
                                menuItems
                            } label: {
                                Glyph(Tokens.Icons.globalMore)
                                    .foregroundStyle(Tokens.Colors.globalTextSecondary)
                                    .frame(width: Tokens.Sizes.globalHeaderButton, height: Tokens.Sizes.globalHeaderButton)
                                    .contentShape(Rectangle())
                            }
                            .accessibilityLabel(Text(Copy.photoViewerA11yMore))
                        }
                    }
                }
                .padding(.top, SocialFieldMetrics.glyphTop)
                .padding(.trailing, SocialFieldMetrics.glyphTrailing)
                .dsAnimation(ComponentMotion.crossfade, value: hasText)
            }
            .socialFieldShape(onMedia: true)
            .padding(.bottom, Tokens.Sizes.chatComposerDimensionBottomInset)
            .background(Tokens.Colors.globalBackgroundDeep.ignoresSafeArea())
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

    // MARK: Tagging sheet (memory's `TaggingSheet`)

    private var tagPeople: [TaggingSheetPerson] {
        model.taggedPeople(on: model.selection).map { id in
            let profile = model.profiles[id]
            return TaggingSheetPerson(
                id: id.rawValue, firstName: profile?.socialFirstName ?? "",
                avatar: SocialImages.source(profile?.avatarPath), isMe: id == model.me
            )
        }
    }
}

// MARK: - One photo with its footer and comments

/// The scroll area of one photo: the photo `photo.viewer.dimension.headerToPhoto` below the header (full width, its own
/// aspect, never cropped, letterboxed when taller than the area), the footer, the hairline and the comments.
struct ViewerPostPage: View {
    let post: PostWithMedia
    let model: PhotoViewerModel
    let area: CGSize
    let menu: AnyView
    let openPicker: () -> Void
    let openReactions: () -> Void
    let openTags: () -> Void
    let replyToComment: (Message) -> Void
    let unsendComment: (Message) -> Void
    let reportComment: (Message) -> Void

    @State private var trailingWidth: CGFloat = 0

    private var aspectRatio: CGFloat {
        if let media = post.media, let width = media.width, let height = media.height, width > 0, height > 0 {
            return CGFloat(width) / CGFloat(height)
        }
        // The app's own capture shape (3:4, the C-17 tile) until the media's size is known.
        return Tokens.Sizes.globalStripTileWidth / Tokens.Sizes.globalStripTileHeight
    }

    var body: some View {
        let photoHeight = min(area.width / aspectRatio, max(0, area.height - Tokens.Sizes.photoViewerDimensionHeaderToPhoto))
        MetricStack {
            photo
                .frame(width: area.width, height: photoHeight)
                .metricGap(Tokens.Sizes.photoViewerDimensionHeaderToPhoto, from: .top, to: .top)
            footer
                .metricGap(0, from: .bottom, to: .top)
            if !model.currentComments.isEmpty {
                HairlineDivider(color: Tokens.Colors.globalSeparator.darkAppearanceValue)
                    .padding(.horizontal, Tokens.Sizes.globalScreenMargin)
                    .metricGap(
                        Tokens.Sizes.photoViewerDimensionFooterToDivider,
                        from: hasVoice ? .bottom : .lastBaseline, to: .top
                    )
                comments
                    .metricGap(Tokens.Sizes.photoViewerDimensionDividerToComments, from: .bottom, to: .top)
            }
        }
    }

    private var hasVoice: Bool { post.post.voicePath != nil && post.post.voiceDurationMs != nil }

    // MARK: Photo

    /// Tap advances (`photo.viewer.layout.advance`), the leading zone goes back (`photo.viewer.layout.backZone`,
    /// BLOCKED — `SocialBlocked.viewerBackZoneFraction`); long press: the menu with the quick-reaction row.
    private var photo: some View {
        ViewerMedia(post: post, accessibilityLabel: photoLabel)
            .viewerTapNavigation(
                previousFraction: SocialBlocked.viewerBackZoneFraction,
                previousLabel: Copy.photoViewerA11yPrevious,
                nextLabel: Copy.photoViewerA11yNext,
                onPrevious: { withDSAnimation(ComponentMotion.crossfade) { model.goBack() } },
                onNext: { withDSAnimation(ComponentMotion.crossfade) { model.advance() } }
            )
            .contextMenu {
                QuickReactionsPalette(
                    mine: model.myEmojiOnCurrent,
                    onEmoji: { emoji in Task { await model.toggleReaction(emoji) } },
                    onAdd: openPicker
                )
                menu
            }
            .accessibilityHint(Text(Copy.photoViewerA11yAdvanceHint))
            .accessibilityActions { menu }
    }

    private var photoLabel: String {
        var text = SocialA11y.photo(post, author: model.author(of: post), me: model.me)
        if let caption = post.post.caption, !caption.isEmpty { text += ", " + Copy.chatThreadA11yCaption(caption: caption) } // provenance-ok: joins copy strings
        return text
    }

    // MARK: Footer

    /// Inside `size.global.screenMargin`: the caption (`listTitle`, `color.global.textOnMedia`, wraps) — Retro's place
    /// line — first baseline `photo.viewer.dimension.footerFirstBaseline` below the photo; the date ("Wednesday, July 5",
    /// `listSubtitle`, `color.global.textSecondary`) + " · " + the tag run (memory's `TagRun`) on the next line,
    /// `.footerLinePitch` below; the voice note capsule `.footerLinePitch` below that line's baseline. Trailing, centred
    /// on the first line: the reaction chip (on `color.global.controlOnDeep`) and the add-reaction glyph at the margin.
    private var footer: some View {
        let caption = post.post.caption.flatMap { $0.isEmpty ? nil : $0 }
        let firstRole = caption != nil ? TextRole.listTitle : TextRole.listSubtitle
        return MetricStack {
            if let caption {
                Text(caption)
                    .dsTextRole(DSTextStyle(
                        family: TextRole.listTitle.family, size: TextRole.listTitle.size, weight: TextRole.listTitle.weight,
                        relativeTo: TextRole.listTitle.relativeTo, lineHeight: Tokens.Sizes.photoViewerDimensionFooterLinePitch
                    ))
                    .foregroundStyle(Tokens.Colors.globalTextOnMedia)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.trailing, trailingWidth)
                    .metricGap(Tokens.Sizes.photoViewerDimensionFooterFirstBaseline, from: .top, to: .firstBaseline)
            }
            TagRunLine(
                leadingText: SocialFormat.viewerDate(post.post.createdAt, timeZone: model.group(of: post)?.resolvedTimeZone ?? .current),
                run: TagRun(
                    names: model.taggedPeople(on: post.id).map { model.profiles[$0]?.socialFirstName ?? "" },
                    isTagged: model.isCurrentTagged,
                    isPending: model.tagPending.contains(post.id)
                ) {
                    if model.taggedPeople(on: post.id).isEmpty {
                        Task { await model.toggleTag() }
                    } else {
                        openTags()
                    }
                }
            )
            .padding(.trailing, caption == nil ? trailingWidth : 0)
            .metricGap(
                caption == nil ? Tokens.Sizes.photoViewerDimensionFooterFirstBaseline : Tokens.Sizes.photoViewerDimensionFooterLinePitch,
                from: caption == nil ? .top : .lastBaseline,
                to: .firstBaseline
            )
            if let voicePath = post.post.voicePath, let duration = post.post.voiceDurationMs {
                VoiceCapsule(
                    key: post.id.rawValue,
                    path: voicePath,
                    durationMs: duration,
                    onMedia: true,
                    accessibilityLabel: model.isOwn(post)
                        ? Copy.chatVoiceA11yMessageMine(duration: SocialFormat.spokenDuration(milliseconds: duration))
                        : Copy.chatVoiceA11yMessage(name: model.author(of: post)?.socialFirstName ?? "", duration: SocialFormat.spokenDuration(milliseconds: duration))
                )
                .metricGap(Tokens.Sizes.photoViewerDimensionFooterLinePitch, from: .lastBaseline, to: .top)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .topTrailing) {
            reactionSlot
                .background {
                    GeometryReader { proxy in
                        Color.clear
                            .onAppear { trailingWidth = proxy.size.width + Tokens.Sizes.globalPillGap }
                            .onChange(of: proxy.size.width) { _, value in trailingWidth = value + Tokens.Sizes.globalPillGap }
                    }
                }
                .alignmentGuide(.top) { dimensions in
                    // Centred on the first line's cap middle.
                    dimensions[VerticalAlignment.center]
                        - (Tokens.Sizes.photoViewerDimensionFooterFirstBaseline - SocialMetrics.metrics(firstRole).capHeight / 2)
                }
        }
        .padding(.horizontal, Tokens.Sizes.globalScreenMargin)
    }

    /// Retro's reaction slot (its heart like is do-not-copy): the chip (hidden when empty) and the add glyph.
    private var reactionSlot: some View {
        HStack(spacing: Tokens.Sizes.globalPillGap) {
            ReactionChip(emoji: model.reactions[post.id]?.distinctEmoji ?? [], onMedia: true, action: openReactions)
            Button(action: openPicker) {
                Glyph(Tokens.Icons.chatReactionsIconAdd)
                    .foregroundStyle(Tokens.Colors.globalTextSecondary)
                    .minimumHitArea(drawn: CGSize(width: Tokens.Sizes.globalIcon, height: Tokens.Sizes.globalIcon))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(Copy.chatReactionsA11yAdd))
        }
    }

    // MARK: Comments (`photo.viewer.layout.comments`)

    private var comments: some View {
        VStack(alignment: .leading, spacing: Tokens.Sizes.globalListGap) {
            ForEach(model.currentComments) { message in
                ViewerCommentRow(
                    message: message,
                    author: model.profiles[message.authorID],
                    isMine: message.authorID == model.me,
                    reply: { replyToComment(message) },
                    copy: {
                        UIPasteboard.general.string = message.body
                        model.copied()
                    },
                    unsend: { unsendComment(message) },
                    report: { reportComment(message) },
                    openWall: { SocialNav.openWall(of: message.authorID, me: model.me) }
                )
            }
        }
    }
}

/// A comment under the photo: the `chat.thread` message row (C-16) in `color.global.textOnMedia` — avatar
/// `size.global.avatarComment`, `chat.thread.dimension.rowAvatarToText`, name (`listTitle`) · time (`caption`,
/// `color.global.textSecondary`), the text (`body`) with its first baseline `chat.thread.dimension.rowLinePitch` below the
/// name's. Long press → the thread's message menu.
struct ViewerCommentRow: View {
    let message: Message
    let author: Profile?
    let isMine: Bool
    let reply: () -> Void
    let copy: () -> Void
    let unsend: () -> Void
    let report: () -> Void
    let openWall: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: Tokens.Sizes.chatThreadDimensionRowAvatarToText) {
            Button(action: openWall) {
                AvatarView(source: SocialImages.source(author?.avatarPath), diameter: Tokens.Sizes.globalAvatarComment)
            }
            .buttonStyle(.plain)
            .accessibilityHidden(true)
            MetricStack {
                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    Text(author?.displayName ?? "")
                        .dsTextStyle(TextRole.listTitle)
                        .foregroundStyle(Tokens.Colors.globalTextOnMedia)
                        .lineLimit(1)
                    Text(" " + SocialFormat.time(message.createdAt))
                        .dsTextStyle(TextRole.caption)
                        .foregroundStyle(Tokens.Colors.globalTextSecondary)
                        .lineLimit(1)
                        .fixedSize()
                }
                .accessibilityHidden(true)
                if message.kind == .voice {
                    VoiceCapsule(
                        key: message.id.rawValue,
                        path: message.voicePath,
                        durationMs: message.voiceDurationMs ?? 0,
                        onMedia: true,
                        accessibilityLabel: isMine
                            ? Copy.chatVoiceA11yMessageMine(duration: SocialFormat.spokenDuration(milliseconds: message.voiceDurationMs ?? 0))
                            : Copy.chatVoiceA11yMessage(name: author?.socialFirstName ?? "", duration: SocialFormat.spokenDuration(milliseconds: message.voiceDurationMs ?? 0))
                    )
                    .metricGap(Tokens.Sizes.chatThreadDimensionItemGap, from: .bottom, to: .top)
                } else {
                    Text(message.body ?? "")
                        .dsTextRole(SocialTextRole.threadBody)
                        .foregroundStyle(Tokens.Colors.globalTextOnMedia)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityLabel(Text(isMine
                            ? Copy.chatThreadA11yMessageMine(message: message.body ?? "")
                            : Copy.chatThreadA11yMessage(name: author?.socialFirstName ?? "", message: message.body ?? "")))
                        .metricGap(Tokens.Sizes.chatThreadDimensionRowLinePitch, from: .lastBaseline, to: .firstBaseline)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .contextMenu { menu }
            .accessibilityActions { menu }
        }
        .padding(.horizontal, Tokens.Sizes.globalScreenMargin)
    }

    @ViewBuilder
    private var menu: some View {
        Button(Copy.chatThreadMenuReply, action: reply)
        if message.kind == .text {
            Button(Copy.chatThreadMenuCopy, action: copy)
        }
        if isMine {
            Button(Copy.chatThreadMenuDelete, role: .destructive, action: unsend)
        } else {
            Button(Copy.chatThreadMenuReport, role: .destructive, action: report)
        }
    }
}

// MARK: - The picture

/// The picture itself, never cropped (aspect fit, letterboxed on `color.global.backgroundDeep`): the grid thumbnail at
/// once, replaced by `display_path` when loaded (docs/API.md §7) with `duration.global.fade`; a dual capture as
/// `daily.dualimage` (capture group's `DualImageView`); a Live Photo plays while pressed (platform `PHLivePhotoView`); a
/// video with the platform player. When the display rendition cannot load: `photo.viewer.error.load` centred (tap
/// retries).
struct ViewerMedia: View {
    let post: PostWithMedia
    let accessibilityLabel: String

    var body: some View {
        Group {
            if let media = post.media {
                switch media.kind {
                case .video:
                    ViewerVideo(path: media.originalPath)
                default:
                    if media.frontOriginalPath != nil {
                        ViewerDualImage(media: media, accessibilityLabel: accessibilityLabel)
                    } else {
                        ZStack {
                            ViewerDisplayImage(thumbPath: media.gridPath, displayPath: media.displayImagePath)
                            if media.kind == .livePhoto { ViewerLivePhoto(media: media) }
                        }
                    }
                }
            } else {
                Text(Copy.photoViewerErrorLoad)
                    .dsTextStyle(TextRole.body)
                    .foregroundStyle(Tokens.Colors.globalTextSecondary)
            }
        }
        .background(Tokens.Colors.globalBackgroundDeep)
        .clipped()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(accessibilityLabel))
        .accessibilityAddTraits(.isImage)
    }
}

/// Thumbnail first, the display rendition faded in over it; a failed display load shows the error line.
struct ViewerDisplayImage: View {
    let thumbPath: String?
    let displayPath: String?

    @State private var image: UIImage?
    @State private var failed = false
    @State private var attempt = 0
    @Environment(\.displayScale) private var displayScale

    init(thumbPath: String?, displayPath: String?) {
        self.thumbPath = thumbPath
        self.displayPath = displayPath
        _image = State(initialValue: displayPath.flatMap { SocialServices.shared.images.cached($0) })
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                if image == nil {
                    SocialImage(path: thumbPath, contentMode: .fit) { Color.clear }
                }
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .transition(.opacity)
                }
                if failed {
                    Button {
                        failed = false
                        attempt += 1
                    } label: {
                        Text(Copy.photoViewerErrorLoad)
                            .dsTextStyle(TextRole.body)
                            .foregroundStyle(Tokens.Colors.globalTextSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, Tokens.Sizes.globalScreenMargin)
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .task(id: (displayPath ?? "") + "#" + String(attempt)) {
                guard image == nil, let displayPath else { return }
                let pixels = Int((max(proxy.size.width, proxy.size.height) * displayScale).rounded(.up))
                let loaded = await SocialServices.shared.images.load(displayPath, maxPixel: pixels > 0 ? pixels : nil)
                withDSAnimation(ComponentMotion.fade) {
                    image = loaded
                    failed = loaded == nil
                }
            }
        }
    }
}

/// `daily.dualimage` for a post with a front photo.
struct ViewerDualImage: View {
    let media: Media
    let accessibilityLabel: String

    @State private var main: UIImage?
    @State private var inset: UIImage?

    var body: some View {
        DualImageView(main: main, inset: inset, accessibilityLabel: accessibilityLabel)
            .task(id: media.id) {
                if let path = media.displayImagePath { main = await SocialServices.shared.images.load(path) }
                if let path = media.frontImagePath(for: .display) { inset = await SocialServices.shared.images.load(path) }
            }
    }
}

/// A Live Photo: the still and its motion (the pair that constitutes it, PLATFORM_CONSTRAINTS §6) are downloaded when
/// the page shows; the platform view plays it while pressed.
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
                withResourceFileURLs: [still, motion], placeholderImage: nil, targetSize: .zero, contentMode: .aspectFit
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
        view.contentMode = .scaleAspectFit
        view.clipsToBounds = true
        return view
    }

    func updateUIView(_ view: PHLivePhotoView, context: Context) {
        view.livePhoto = livePhoto
    }
}

/// Video posts (premium): the platform player.
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
