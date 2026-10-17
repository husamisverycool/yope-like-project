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
    /// "Add to Album": the album picker for this photo (`photo.viewer.layout.albumPicker`).
    @State private var albumPicker: AlbumPickerTarget?
    @State private var unsendCandidate: Message?
    @State private var reportTarget: ReportTarget?
    @State private var blockTarget: BlockTarget?
    @State private var width: CGFloat = 0
    /// viewer.selfiereaction: the capture layer while open, the front camera it uses (made once per viewer), the hold on
    /// the add-reaction glyph, the header's bottom (the panel starts `photo.viewer.dimension.headerToPhoto` below it), and
    /// the Reactions sheet's pending removal and report.
    @State private var selfieLayer: SelfieCaptureModel?
    @State private var selfieCamera: CaptureCamera?
    @State private var selfieHold = SelfieHoldTracker()
    @State private var headerBottom: CGFloat = 0
    @State private var selfieToRemove: SelfieReaction?
    @State private var selfieReport: ReportTarget?
    @FocusState private var fieldFocused: Bool
    @Environment(\.dismiss) private var dismiss
    @Environment(\.displayScale) private var displayScale
    @Environment(AccountDependencies.self) private var account: AccountDependencies?

    init(context: PhotoViewerContext, presentation: Presentation) {
        self.init(model: PhotoViewerModel(context: context, data: SocialServices.shared.data), presentation: presentation)
    }

    /// - Parameter selfieLayer: the capture layer already open (snapshots of viewer.selfiereaction's states).
    init(model: PhotoViewerModel, presentation: Presentation, selfieLayer: SelfieCaptureModel? = nil) {
        _model = State(initialValue: model)
        _selfieLayer = State(initialValue: selfieLayer)
        self.presentation = presentation
    }

    var body: some View {
        page
            .overlay { selfieLayerView }
            // `photo.viewer.layout.appearance`: dark in both appearances; sheets and alerts follow the system.
            .environment(\.colorScheme, .dark)
            .socialHidesNavigationBar()
            .task {
                if model.phase == .loading { await model.load() }
                prefetchNeighbours()
                await model.run()
            }
            .task {
                if selfieCamera == nil { selfieCamera = SocialServices.shared.selfieCamera() }
            }
            .onChange(of: model.selection) { _, _ in
                closeSelfieLayer()
                prefetchNeighbours()
                Task { await model.loadSelectedDetails() }
            }
            // viewer.selfiereaction "photo deleted while open": the layer closes; the gone state shows.
            .onChange(of: model.isCurrentGone) { _, gone in
                if gone { closeSelfieLayer() }
            }
            .onDisappear { closeSelfieLayer() }
            .onChange(of: model.isClosed) { _, closed in
                if closed { dismiss() }
            }
            .socialFeedback(model.signals.feedback)
            .socialNotices(model.signals.notice, toasts: toasts)
            .socialFeedback(model.selfies.signals.feedback)
            .socialNotices(model.selfies.signals.notice, toasts: toasts)
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
                        selfies: model.selfies.summary(for: post.id),
                        me: model.me,
                        profile: { model.profiles[$0] },
                        onRemove: { emoji in Task { await model.unreact(emoji) } },
                        selfieActions: selfieRowActions(post)
                    )
                    .presentationDetents([.medium, .large])
                    // viewer.selfiereaction: the author's removal (`photo.viewer.layout.deleteConfirm` form) and the report
                    // flow, presented over the sheet.
                    .confirmationDialog(
                        Text(Copy.viewerSelfiereactionRemoveTitle(name: selfieToRemove.flatMap { model.profiles[$0.userID]?.socialFirstName } ?? "")),
                        isPresented: Binding(get: { selfieToRemove != nil }, set: { if !$0 { selfieToRemove = nil } }),
                        titleVisibility: .visible,
                        presenting: selfieToRemove
                    ) { selfie in
                        Button(Copy.viewerSelfiereactionRemoveConfirm, role: .destructive) {
                            Task { await model.removeSelfie(of: selfie.userID, postID: selfie.postID) }
                        }
                        Button(Copy.photoViewerDeleteCancel, role: .cancel) {}
                    } message: { _ in
                        Text(Copy.viewerSelfiereactionRemoveMessage)
                    }
                    .sheet(item: $selfieReport) { target in
                        reportSheet(target)
                    }
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
            .sheet(item: $albumPicker) { target in
                AlbumPickerSheet(
                    model: AlbumPickerModel(groupID: target.groupID, postID: target.postID, data: SocialServices.shared.data),
                    onDone: { model.addedToAlbum() }
                )
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
            // `photo.viewer.layout.editCaption`: the platform alert with one text field (iMessage's edit, Retro's caption
            // field); Save → edit_caption, empty removes the caption.
            .alert(captionAlertTitle, isPresented: $model.isEditingCaption) {
                TextField(Copy.photoViewerCaptionPlaceholder, text: $model.captionText, axis: .vertical)
                    .onChange(of: model.captionText) { _, _ in model.limitCaptionText() }
                Button(Copy.photoViewerCaptionSave) { Task { await model.saveCaption() } }
                Button(Copy.photoViewerDeleteCancel, role: .cancel) { model.cancelCaptionEdit() }
            }
            .blockConfirmation(
                target: $blockTarget,
                toasts: toasts,
                perform: { target in try await model.blockAuthor(UserID(target.userID)) },
                onBlocked: { target in model.authorBlocked(UserID(target.userID)) }
            )
            .socialClearsReplyHandoff()
            .accessibilityElement(children: .contain)
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
                    mediaActive: selfieLayer == nil,
                    menu: AnyView(menuItems),
                    openPicker: { pickerOpen = true },
                    openReactions: { reactionsOpen = true },
                    openTags: { tagSheetOpen = true },
                    selfieEntry: selfieEntry,
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

    // MARK: Selfie reactions (viewer.selfiereaction)

    /// The entry points of the photo on screen: hidden on my own photo and without a front camera.
    private var selfieEntry: SelfieEntry? {
        guard model.canReactWithSelfie, selfieCamera?.hasCamera(at: .front) == true else { return nil }
        return SelfieEntry(
            hold: selfieHold,
            onTap: { pickerOpen = true },
            onHoldBegan: { openSelfieLayer(.hold) },
            onMove: { selfieLayer?.moved(to: $0) },
            onRelease: { releaseSelfie(at: $0) },
            openTapMode: { openSelfieLayer(.tap) }
        )
    }

    @ViewBuilder
    private var selfieLayerView: some View {
        if let layer = selfieLayer {
            SelfieCaptureLayer(
                model: layer,
                panelTop: headerBottom + Tokens.Sizes.photoViewerDimensionHeaderToPhoto,
                onCapture: { captureSelfie(layer) },
                onClose: { closeSelfieLayer() },
                onOpenSettings: {
                    if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                }
            )
            .transition(.opacity)
        }
    }

    /// Layer in: `duration.global.fade` + `easing.global.standard` (Reduce Motion: the same).
    private func openSelfieLayer(_ mode: SelfieCaptureModel.Mode) {
        guard selfieLayer == nil, model.canReactWithSelfie, let post = model.current, let camera = selfieCamera else { return }
        let layer = SelfieCaptureModel(postID: post.id, mode: mode, camera: camera)
        withDSAnimation(ComponentMotion.fade) { selfieLayer = layer }
        Task { await layer.start() }
    }

    private func closeSelfieLayer() {
        guard let layer = selfieLayer else { return }
        withDSAnimation(ComponentMotion.fade) { selfieLayer = nil }
        Task { await layer.stop() }
    }

    /// Hold mode: released on the target ring or the circle, the selfie is taken and sent; anywhere else nothing is sent
    /// and the layer closes (touch-up-inside semantics, PLATFORM).
    private func releaseSelfie(at point: CGPoint) {
        guard let layer = selfieLayer else { return }
        if layer.phase == .live, layer.contains(point) {
            captureSelfie(layer)
        } else {
            closeSelfieLayer()
        }
    }

    /// Sending: the layer closes and my face joins the stack at once (optimistic), taken back out if the send fails.
    private func captureSelfie(_ layer: SelfieCaptureModel) {
        guard layer.phase == .live, !layer.isCapturing else { return }
        Task {
            let jpeg = await layer.capture()
            closeSelfieLayer()
            guard let jpeg else {
                model.selfies.captureFailed()
                return
            }
            await model.sendSelfie(jpeg, to: layer.postID)
        }
    }

    /// The faces and actions of the Reactions sheet's selfie rows.
    private func selfieRowActions(_ post: PostWithMedia) -> SelfieRowActions {
        let scale = displayScale
        return SelfieRowActions(
            face: { selfie in SelfieFaceImages.source(selfie, sent: model.selfies.sentImages[selfie.id], displayScale: scale) },
            isAuthor: model.isOwn(post),
            removeMine: { _ in Task { await model.removeMySelfie(postID: post.id) } },
            remove: { selfieToRemove = $0 },
            report: account == nil ? nil : { selfie in
                selfieReport = ReportTarget(
                    kind: .selfie, id: selfie.id.rawValue, name: nil,
                    person: BlockTarget(userID: selfie.userID.rawValue, firstName: model.profiles[selfie.userID]?.socialFirstName ?? "")
                )
            }
        )
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
                        ViewerAvatarRing(source: SocialImages.source(model.author(of: post)?.avatarPath), fraction: model.ringFraction)
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
        .background {
            GeometryReader { proxy in
                Color.clear
                    .onAppear { headerBottom = proxy.frame(in: .global).maxY }
                    .onChange(of: proxy.frame(in: .global).maxY) { _, value in headerBottom = value }
            }
        }
        // viewer.selfiereaction: the header stays visible and inert under the capture layer (BeReal keeps its header).
        .allowsHitTesting(selfieLayer == nil)
        .accessibilityHidden(selfieLayer != nil)
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

    /// On my own photo first Edit Caption (Add a Caption when it has none; owner decision 34); then Save to Camera Roll on
    /// every photo (owner decision 28: any member saves any photo they can see), Favorite / Unfavorite (private, Apple
    /// Photos), Add to Album, Use as Cover (group admins), then mine: Delete (destructive); others': Report Post
    /// (destructive) · Block {name}.
    @ViewBuilder
    private var menuItems: some View {
        if model.canEditCurrentCaption {
            Button { model.beginCaptionEdit() } label: {
                Label(model.currentHasCaption ? Copy.photoViewerMenuEditCaption : Copy.photoViewerMenuAddCaption, systemImage: Tokens.Icons.globalEdit)
            }
        }
        if let post = model.current {
            Button { Task { await model.saveCurrent(using: SocialServices.shared.saver) } } label: {
                Label(Copy.photoViewerMenuSave, systemImage: Tokens.Icons.globalDownload)
            }
            if !model.isCurrentGone {
                Button { Task { await model.toggleFavorite() } } label: {
                    if model.isCurrentFavorite {
                        Label(Copy.photoViewerMenuUnfavorite, systemImage: Tokens.Icons.globalUnfavorite)
                    } else {
                        Label(Copy.photoViewerMenuFavorite, systemImage: Tokens.Icons.globalFavorite)
                    }
                }
                Button { albumPicker = AlbumPickerTarget(groupID: post.post.groupID, postID: post.id) } label: {
                    Label(Copy.photoViewerMenuAddToAlbum, systemImage: Tokens.Icons.globalAlbums)
                }
            }
            if model.canUseCurrentAsCover {
                Button { Task { await model.useCurrentAsCover() } } label: {
                    Label(Copy.photoViewerMenuUseAsCover, systemImage: Tokens.Icons.globalCover)
                }
            }
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

    /// The caption alert's title: the menu item that opened it.
    private var captionAlertTitle: String {
        model.currentHasCaption ? Copy.photoViewerMenuEditCaption : Copy.photoViewerMenuAddCaption
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
    /// False while a layer (the selfie capture) covers the photo: a video pauses.
    var mediaActive = true
    let menu: AnyView
    let openPicker: () -> Void
    let openReactions: () -> Void
    let openTags: () -> Void
    /// viewer.selfiereaction's entry points (nil: hidden — my own photo, no front camera).
    let selfieEntry: SelfieEntry?
    let replyToComment: (Message) -> Void
    let unsendComment: (Message) -> Void
    let reportComment: (Message) -> Void

    @State private var trailingWidth: CGFloat = 0
    /// photo.viewer.layout.livePhoto: the Live Photo's view, played while the photo is held.
    @State private var livePlayback = LivePhotoPlayback()
    /// photo.viewer.layout.video: this page's player.
    @State private var videoPlayback = ViewerVideoPlayback()
    @Environment(\.displayScale) private var displayScale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var isLivePhoto: Bool { post.media?.kind == .livePhoto && post.media?.motionPath != nil && post.media?.frontOriginalPath == nil }
    private var isVideo: Bool { post.media?.kind == .video }
    /// photo.viewer.layout.video → reduceMotion: Reduce Motion or Auto-Play Video Previews off — no autoplay.
    private var videoAutoplays: Bool { !reduceMotion && UIAccessibility.isVideoAutoplayEnabled }
    /// The play circle shows: no autoplay and not playing, or the system paused it (headphones out, an interruption).
    private var videoWaitsForPlay: Bool { (!videoAutoplays && !videoPlayback.isPlaying) || videoPlayback.interrupted }

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
                .overlay { mediaControls(frame: CGSize(width: area.width, height: photoHeight)) }
                .overlay(alignment: .bottomLeading) {
                    selfieStack(frame: CGSize(width: area.width, height: photoHeight))
                }
                .metricGap(Tokens.Sizes.photoViewerDimensionHeaderToPhoto, from: .top, to: .top)
            if let position = model.batchPosition(of: post.id) {
                batchDots(position)
                    .frame(width: area.width, height: Tokens.Sizes.yearStoryDotsOffset * 2) // provenance-ok: the dots' centre one offset below the photo (photo.viewer.layout.batchDots)
                    .metricGap(0, from: .bottom, to: .top)
            }
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

    /// `photo.viewer.layout.batchDots`: C-31 dots on media, one per photo of the batch (never the whole list), centred
    /// under the photo; read as "2 of 3" within the batch (`photo.viewer.position`), adjustable within the batch.
    private func batchDots(_ position: PhotoBatchPosition) -> some View {
        PageDots(
            count: position.total,
            index: position.index - 1,
            onMedia: true,
            accessibilityValue: Copy.photoViewerPosition(index: String(position.index), total: String(position.total))
        ) { index in
            Task { await model.selectInBatch(index) }
        }
        .accessibilityIdentifier("photo.viewer.batchDots") // provenance-ok: accessibility identifier for UI tests
    }

    // MARK: Photo

    /// Tap advances (`photo.viewer.layout.advance`), the leading 20 % goes back (`photo.viewer.layout.backZone`, Retro's
    /// viewer); long press: the menu with the quick-reaction row.
    private var photo: some View {
        ViewerMedia(
            post: post,
            accessibilityLabel: photoLabel,
            livePlayback: livePlayback,
            videoPlayback: videoPlayback,
            video: ViewerVideoState(
                active: mediaActive,
                autoplay: videoAutoplays,
                soundOn: Binding(get: { model.videoSoundOn }, set: { model.videoSoundOn = $0 }),
                playRequests: model.videoPlayRequests
            )
        )
        .viewerTapNavigation(
            previousFraction: Tokens.Layouts.PhotoViewerLayoutBackZone.fraction,
            previousLabel: Copy.photoViewerA11yPrevious,
            nextLabel: Copy.photoViewerA11yNext,
            onPrevious: { withDSAnimation(ComponentMotion.crossfade) { model.goBack() } },
            onNext: { withDSAnimation(ComponentMotion.crossfade) { model.advance() } },
            // photo.viewer.layout.livePhoto: holding a Live Photo plays it; its menu is the field's "•••".
            onHold: isLivePhoto ? { holding in holding ? livePlayback.start() : livePlayback.stop() } : nil
        )
        .viewerPhotoMenu(enabled: !isLivePhoto) {
            QuickReactionsPalette(
                mine: model.myEmojiOnCurrent,
                onEmoji: { emoji in Task { await model.toggleReaction(emoji) } },
                onAdd: openPicker
            )
            // viewer.selfiereaction: under the quick-reaction row, the layer in tap mode.
            if let selfieEntry {
                Button(action: selfieEntry.openTapMode) {
                    Label(Copy.viewerSelfiereactionMenuReact, systemImage: Tokens.Icons.globalCamera)
                }
            }
            menu
        }
        .accessibilityHint(Text(Copy.photoViewerA11yAdvanceHint))
        .accessibilityActions {
            if isLivePhoto {
                Button(Copy.photoViewerA11yPlay) { livePlayback.playOnce() }
            }
            if isVideo {
                if videoWaitsForPlay {
                    Button(Copy.photoViewerA11yPlay) {
                        model.videoSoundOn = true
                        model.videoPlayRequests += 1
                    }
                } else {
                    Button(model.videoSoundOn ? Copy.photoViewerA11yMute : Copy.photoViewerA11yUnmute) { model.videoSoundOn.toggle() }
                }
            }
            if let selfieEntry {
                Button(Copy.viewerSelfiereactionA11yAction, action: selfieEntry.openTapMode)
            }
            menu
        }
    }

    /// Over the photo, above its tap zones: a video's glass circles (`photo.viewer.layout.video`: sound at the visible video's
    /// bottom-trailing corner `size.global.screenMargin` in; the play circle centred when it waits for a tap; the error line
    /// when it cannot play) and a Live Photo's system badge at the top-leading corner, `size.global.videoPillInset` in.
    /// VoiceOver reaches these through the photo's actions.
    @ViewBuilder
    private func mediaControls(frame: CGSize) -> some View {
        let imageWidth = min(frame.width, frame.height * aspectRatio)
        let letterbox = max(0, frame.width - imageWidth) / 2
        if isVideo {
            if videoPlayback.failed {
                Button { videoPlayback.retry() } label: {
                    Text(Copy.photoViewerErrorLoad)
                        .dsTextStyle(TextRole.body)
                        .foregroundStyle(Tokens.Colors.globalTextSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Tokens.Sizes.globalScreenMargin)
                }
                .buttonStyle(.plain)
            } else if videoWaitsForPlay {
                CircleButton(icon: Tokens.Icons.globalPlay, accessibilityLabel: Copy.photoViewerA11yPlay, style: .glass) {
                    model.videoSoundOn = true
                    model.videoPlayRequests += 1
                }
                .accessibilityHidden(true)
            } else {
                CircleButton(
                    icon: model.videoSoundOn ? Tokens.Icons.photoViewerSoundOn : Tokens.Icons.photoViewerSoundOff,
                    accessibilityLabel: model.videoSoundOn ? Copy.photoViewerA11yMute : Copy.photoViewerA11yUnmute,
                    style: .glass
                ) {
                    model.videoSoundOn.toggle()
                }
                .accessibilityHidden(true)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .padding(.trailing, letterbox + Tokens.Sizes.globalScreenMargin)
                .padding(.bottom, Tokens.Sizes.globalScreenMargin)
            }
        } else if isLivePhoto, livePlayback.isPlayable {
            LivePhotoBadge()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(.leading, letterbox + Tokens.Sizes.globalVideoPillInset)
                .padding(.top, Tokens.Sizes.globalVideoPillInset)
                .allowsHitTesting(false)
        }
    }

    /// viewer.selfiereaction §3: the faces over the visible image's bottom-leading corner (a letterboxed photo: the
    /// image's own edges), `size.global.screenMargin` in on both axes (H-RP's equal insets). Tap → the Reactions sheet.
    private func selfieStack(frame: CGSize) -> some View {
        let imageWidth = min(frame.width, frame.height * aspectRatio)
        let faces = model.selfies.summary(for: post.id).faces(limit: Int(Tokens.Counts.chatReactionsCountClusterMaxVisible))
        let sent = model.selfies.sentImages
        let scale = displayScale
        return SelfieFaceStack(
            faces: faces,
            names: faces.map { model.profiles[$0.userID]?.socialFirstName ?? "" },
            source: { SelfieFaceImages.source($0, sent: sent[$0.id], displayScale: scale) },
            action: openReactions
        )
        .padding(.leading, max(0, frame.width - imageWidth) / 2 + Tokens.Sizes.globalScreenMargin)
        .padding(.bottom, Tokens.Sizes.globalScreenMargin)
    }

    private var photoLabel: String {
        var text = SocialA11y.withVideo(SocialA11y.photo(post, author: model.author(of: post), me: model.me), media: post.media)
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
                leadingText: dateLine,
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
                    levels: post.post.voiceLevels,
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

    /// "Wednesday, July 5", or once the caption was edited "Wednesday, July 5 · Edited" (`chat.thread.edited`, Retro's
    /// ' · ' meta separator, `photo.viewer.layout.editCaption`).
    private var dateLine: String {
        let date = SocialFormat.viewerDate(post.post.createdAt, timeZone: model.group(of: post)?.resolvedTimeZone ?? .current)
        guard model.isCaptionEdited(post) else { return date }
        return date + " · " + Copy.chatThreadEdited // provenance-ok: Retro's meta separator between two copy / data runs
    }

    /// Retro's reaction slot (its heart like is do-not-copy): the chip (hidden when empty) and the add glyph.
    private var reactionSlot: some View {
        HStack(spacing: Tokens.Sizes.globalPillGap) {
            ReactionChip(emoji: model.reactions[post.id]?.distinctEmoji ?? [], onMedia: true, action: openReactions)
            addReactionGlyph
        }
    }

    /// The add-reaction glyph: a tap opens the emoji picker; with selfie reactions available, touch and hold opens the
    /// capture layer in hold mode with the finger still down (viewer.selfiereaction §1; iOS plays no haptic for the
    /// hold, `haptic.global.longPressStart`), and the accessibility action `viewer.selfiereaction.a11y.action` opens it in
    /// tap mode (VoiceOver never gets hold mode).
    @ViewBuilder
    private var addReactionGlyph: some View {
        let glyph = Glyph(Tokens.Icons.chatReactionsIconAdd)
            .foregroundStyle(Tokens.Colors.globalTextSecondary)
            .minimumHitArea(drawn: CGSize(width: Tokens.Sizes.globalIcon, height: Tokens.Sizes.globalIcon))
        if let selfieEntry {
            glyph
                .gesture(
                    DragGesture(minimumDistance: 0, coordinateSpace: .global)
                        .onChanged { selfieEntry.changed($0.location) }
                        .onEnded { selfieEntry.ended($0.location) }
                )
                .accessibilityElement()
                .accessibilityLabel(Text(Copy.chatReactionsA11yAdd))
                .accessibilityAddTraits(.isButton)
                .accessibilityAction { openPicker() }
                .accessibilityAction(named: Text(Copy.viewerSelfiereactionA11yAction)) { selfieEntry.openTapMode() }
                .accessibilityIdentifier("photo.viewer.addReaction") // provenance-ok: accessibility identifier for UI tests
        } else {
            Button(action: openPicker) {
                glyph
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(Copy.chatReactionsA11yAdd))
            .accessibilityIdentifier("photo.viewer.addReaction") // provenance-ok: accessibility identifier for UI tests
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
                        levels: message.voiceLevels,
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
    /// photo.viewer.layout.livePhoto: the page's Live Photo playback (held / VoiceOver).
    var livePlayback: LivePhotoPlayback?
    /// photo.viewer.layout.video: the page's player and how it plays.
    var videoPlayback: ViewerVideoPlayback?
    var video = ViewerVideoState()

    var body: some View {
        Group {
            if let media = post.media {
                if media.frontOriginalPath != nil {
                    ViewerDualImage(media: media, accessibilityLabel: accessibilityLabel)
                } else {
                    ZStack {
                        // A video's poster (its display rendition) shows until the first frame.
                        ViewerDisplayImage(thumbPath: media.gridPath, displayPath: media.displayImagePath)
                        if media.kind == .livePhoto { ViewerLivePhoto(media: media, playback: livePlayback) }
                        if media.kind == .video, let videoPlayback {
                            ViewerVideo(media: media, playback: videoPlayback, state: video)
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
/// the page shows; the platform view plays it while the photo is held (`photo.viewer.layout.livePhoto`: the page's hold
/// drives `playback`; the view's own press gesture is off because the photo's taps go forward and back).
struct ViewerLivePhoto: View {
    let media: Media
    var playback: LivePhotoPlayback?
    @State private var livePhoto: PHLivePhoto?

    var body: some View {
        Group {
            if let livePhoto {
                LivePhotoRepresentable(livePhoto: livePhoto, playback: playback)
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
            playback?.loaded(livePhoto != nil)
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
    var playback: LivePhotoPlayback?

    func makeUIView(context: Context) -> PHLivePhotoView {
        let view = PHLivePhotoView()
        view.contentMode = .scaleAspectFit
        view.clipsToBounds = true
        playback?.attach(view)
        return view
    }

    func updateUIView(_ view: PHLivePhotoView, context: Context) {
        view.livePhoto = livePhoto
    }
}

/// The header avatar with Retro's progress ring (`photo.viewer.layout.avatarRing`, TC-2B "3 of 4" → three quarters):
/// `size.global.avatarHeader` across the ring; a `color.global.textOnMedia` arc `strokeWidth` wide with round caps, from
/// 12 o'clock clockwise through `fraction` of the circle (the position over the total; one photo: the full circle); the
/// photo `gap` inside it. The arc changes with the page cross-fade. Hidden from VoiceOver: the position pill names the
/// position.
struct ViewerAvatarRing: View {
    let source: PhotoSource?
    let fraction: Double

    private typealias Ring = Tokens.Layouts.PhotoViewerLayoutAvatarRing

    var body: some View {
        let outer = Tokens.Sizes.globalAvatarHeader
        ZStack {
            Circle()
                .inset(by: Ring.strokeWidth / 2)
                .trim(from: 0, to: min(max(fraction, 0), 1))
                .stroke(Tokens.Colors.globalTextOnMedia, style: StrokeStyle(lineWidth: Ring.strokeWidth, lineCap: .round))
                .rotationEffect(.degrees(-90)) // provenance-ok: geometry — the arc starts at 12 o'clock (photo.viewer.layout.avatarRing start)
            AvatarView(source: source, diameter: outer - 2 * (Ring.strokeWidth + Ring.gap))
        }
        .frame(width: outer, height: outer)
        .dsAnimation(ComponentMotion.crossfade, value: fraction)
        .accessibilityHidden(true)
    }
}

extension View {
    /// The photo's long-press menu (C-29 with the quick-reaction row), left off where the long press does something else
    /// (a Live Photo plays while held, `photo.viewer.layout.livePhoto`).
    @ViewBuilder
    func viewerPhotoMenu<MenuItems: View>(enabled: Bool, @ViewBuilder menuItems: () -> MenuItems) -> some View {
        if enabled {
            contextMenu(menuItems: menuItems)
        } else {
            self
        }
    }
}

/// The photo the album picker adds (`photo.viewer.layout.albumPicker`).
struct AlbumPickerTarget: Identifiable, Hashable {
    let groupID: GroupID
    let postID: PostID
    var id: String { postID.rawValue }
}
