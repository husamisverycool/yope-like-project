// Snapshots of every social screen in every state (docs/SCREENS_BRIEF.md rule 7), on the demo backend
// (`SocialDemo`) with real sample photos (`SocialSamplePhotos`): ios/build/snapshots/social/<surface>-<state>.png,
// recorded by CI (macOS) for the side-by-side verification images in design/verification/.
@testable import App
import AppData
import AppModels
import DesignSystem
import SwiftUI
import XCTest

@MainActor
final class SocialSnapshotTests: XCTestCase {
    private var data: FakeSocialData!

    override func setUp() async throws {
        try await super.setUp()
        data = SocialDemo.makeData()
        use(data)
    }

    private func use(_ data: FakeSocialData) {
        self.data = data
        let defaults = UserDefaults(suiteName: "social.snapshots")!
        defaults.removePersistentDomain(forName: "social.snapshots")
        SocialServices.shared = SocialServices(
            data: data, images: .samplePhotos(), voiceLevels: .demo(), flags: SocialFlags(defaults: defaults), saver: DemoPhotoSaver()
        )
    }

    /// Records `<surface>-<state>.png` in ios/build/snapshots/social/.
    private func record<V: View>(_ view: V, _ surface: String, _ state: String, file: StaticString = #filePath, testName: String = #function, line: UInt = #line) {
        let name = surface + "-" + state
        let screen = NavigationStack { view }.preferredColorScheme(.dark)
        guard let url = SnapshotRecorder.record(screen, named: name, group: "social", file: file, testName: testName, line: line) else {
            XCTFail("no snapshot for \(name)", file: file, line: line)
            return
        }
        let target = url.deletingLastPathComponent().appendingPathComponent(name + ".png")
        try? FileManager.default.removeItem(at: target)
        XCTAssertNoThrow(try FileManager.default.moveItem(at: url, to: target), file: file, line: line)
    }

    /// Lets a held load reach its loading state (cache checked, request pending).
    private func startHeld(_ load: @escaping @MainActor () async -> Void, until ready: @MainActor () -> Bool) async -> Task<Void, Never> {
        let task = Task { await load() }
        _ = await socialEventually(ready)
        return task
    }

    // MARK: chat.thread / chat.composer / chat.voice / chat.reactions

    func testChatThread() async {
        let ready = ChatThreadModel(groupID: SocialDemo.groupID, data: data)
        await ready.load()
        record(ChatThreadView(model: ready), "chat.thread", "ready")
        record(ChatThreadView(model: ready), "chat.composer", "idle")
        record(ChatThreadView(model: ready), "chat.voice", "playback")
        record(ChatThreadView(model: ready), "chat.reactions", "cluster")

        let held = SocialDemo.makeData()
        held.update { $0.holds.insert("messages") }
        use(held)
        let loading = ChatThreadModel(groupID: SocialDemo.groupID, data: held)
        let task = await startHeld({ await loading.load() }, until: { loading.showsLoading })
        record(ChatThreadView(model: loading), "chat.thread", "loading")
        task.cancel()

        let emptyData = SocialDemo.makeEmptyData()
        use(emptyData)
        let empty = ChatThreadModel(groupID: SocialDemo.groupID, data: emptyData)
        await empty.load()
        record(ChatThreadView(model: empty), "chat.thread", "empty")

        let failing = SocialDemo.makeData()
        failing.update { $0.mode = .failing }
        use(failing)
        let failed = ChatThreadModel(groupID: SocialDemo.groupID, data: failing)
        await failed.load()
        record(ChatThreadView(model: failed), "chat.thread", "error")

        let offlineData = SocialDemo.makeData()
        offlineData.update { $0.mode = .offline }
        use(offlineData)
        let offline = ChatThreadModel(groupID: SocialDemo.groupID, data: offlineData)
        await offline.load()
        record(ChatThreadView(model: offline), "chat.thread", "offline")

        let cachedData = SocialDemo.makeData()
        cachedData.update { state in
            state.mode = .offline
            state.cachedMessages[SocialDemo.groupID] = SocialDemo.messages.reversed()
            state.cachedFeeds[SocialDemo.groupID] = SocialDemo.posts
        }
        use(cachedData)
        let cached = ChatThreadModel(groupID: SocialDemo.groupID, data: cachedData)
        await cached.load()
        record(ChatThreadView(model: cached), "chat.thread", "offline-cached")

        // `chat.thread.layout.failedMessage`: a message of mine that could not be sent (red "!" + label).
        let failingSend = SocialDemo.makeData()
        use(failingSend)
        let notSent = ChatThreadModel(groupID: SocialDemo.groupID, data: failingSend)
        await notSent.load()
        failingSend.update { $0.failOnce.insert("sendText") }
        notSent.draft = "see you at 8"
        await notSent.sendDraft()
        record(ChatThreadView(model: notSent), "chat.thread", "send-failed")

        // `chat.composer.layout.typingState`: text in the field → the lime send circle in the mic's slot; an emoji-only
        // message (≤ `chat.thread.count.emojiOnlyMax`) above it.
        let typingData = SocialDemo.makeData()
        use(typingData)
        let typing = ChatThreadModel(groupID: SocialDemo.groupID, data: typingData)
        await typing.load()
        typing.draft = "🔥🔥🔥"
        await typing.sendDraft()
        typing.draft = "on my way"
        record(ChatThreadView(model: typing), "chat.composer", "typing")
    }

    func testComposerVoiceAndReactionParts() {
        var text = ""
        let binding = Binding(get: { text }, set: { text = $0 })
        record(
            ZStack(alignment: .bottom) {
                Tokens.Colors.globalBackground.ignoresSafeArea()
                VStack(spacing: Tokens.Sizes.globalListGap) {
                    PermissionCard(
                        title: Copy.chatVoicePermissionTitle, detail: Copy.chatVoicePermissionDetail,
                        buttonTitle: Copy.chatVoicePermissionButton, onEnable: {}, onDismiss: {}
                    )
                    .padding(.horizontal, Tokens.Sizes.onboardingPermissionContactsSizeCardMarginH)
                    ChatComposer(
                        text: binding, send: {}, camera: {}, recorder: SocialVoiceRecorder(),
                        onRecorded: { _ in }, onRecordFailed: {}, onMicDenied: {}
                    )
                }
            },
            "chat.voice", "permission-denied"
        )
        record(ReactionPicker(onPick: { _ in }), "chat.reactions", "picker")
        // `chat.reactions.layout.unreact`: my reactions highlighted in the picker.
        record(ReactionPicker(mine: ["💛", "🔥"], onPick: { _ in }, onRemove: { _ in }), "chat.reactions", "picker-mine")
        record(
            ReactionActivitySheet(
                reactions: ReactionSummary(SocialDemo.reactions.filter { $0.postID == SocialDemo.p1 }),
                me: SocialDemo.me, posterFirstName: "Ben",
                nameOf: { id in SocialDemo.profiles.first { $0.id == id }?.socialFirstName ?? "" }
            ),
            "chat.reactions", "activity"
        )
        record(
            ReactionActivitySheet(reactions: ReactionSummary(), me: SocialDemo.me, posterFirstName: "Ben", nameOf: { _ in "" }),
            "chat.reactions", "activity-empty"
        )
    }

    // MARK: photo.viewer

    private func viewer(_ start: PostID, data: FakeSocialData) -> PhotoViewerModel {
        PhotoViewerModel(
            context: PhotoViewerContext(postIDs: [SocialDemo.p1, SocialDemo.p2, SocialDemo.p3, SocialDemo.p4], start: start, groupID: SocialDemo.groupID),
            data: data, flags: SocialServices.shared.flags
        )
    }

    func testPhotoViewer() async {
        let others = viewer(SocialDemo.p2, data: data)
        await others.load()
        record(PhotoViewerView(model: others, presentation: .pushed), "photo.viewer", "ready")

        // Reply typed: the camera circle's slot shows the lime send circle.
        let replying = viewer(SocialDemo.p2, data: data)
        await replying.load()
        replying.replyDraft = "so pretty"
        record(PhotoViewerView(model: replying, presentation: .pushed), "photo.viewer", "reply-typing")

        let own = viewer(SocialDemo.p3, data: data)
        await own.load()
        record(PhotoViewerView(model: own, presentation: .pushed), "photo.viewer", "ready-own")

        await own.saveCurrent(using: DeniedSaver())
        record(PhotoViewerView(model: own, presentation: .pushed), "photo.viewer", "permission-denied")

        let loading = viewer(SocialDemo.p2, data: data)
        record(PhotoViewerView(model: loading, presentation: .pushed), "photo.viewer", "loading")

        let gone = viewer(SocialDemo.p2, data: data)
        await gone.load()
        await gone.handle(.postDeleted(postID: SocialDemo.p2, mediaID: nil))
        record(PhotoViewerView(model: gone, presentation: .pushed), "photo.viewer", "gone")

        let failing = SocialDemo.makeData()
        failing.update { $0.mode = .failing }
        let failed = viewer(SocialDemo.p2, data: failing)
        await failed.load()
        record(PhotoViewerView(model: failed, presentation: .pushed), "photo.viewer", "error")

        let offlineData = SocialDemo.makeData()
        offlineData.update { $0.mode = .offline }
        let offline = viewer(SocialDemo.p2, data: offlineData)
        await offline.load()
        record(PhotoViewerView(model: offline, presentation: .pushed), "photo.viewer", "offline")
    }

    private struct DeniedSaver: SocialPhotoSaving {
        func save(kind: MediaKind, fileURL: URL, motionURL: URL?) async throws { throw SocialSaveFailure.notAuthorized }
    }

    // MARK: walls

    func testWalls() async {
        // The "me" and "walls" tab roots (no back circle; the shell's tab bar is not part of these snapshots).
        SocialTabRoot.treatsEveryWallAsRoot = true
        defer { SocialTabRoot.treatsEveryWallAsRoot = false }
        let mine = WallModel(owner: .me, data: data)
        await mine.load()
        record(WallMineScreen(model: mine), "walls.mine", "ready")

        let member = WallModel(owner: .member(SocialDemo.ana), data: data)
        await member.load()
        record(WallMemberScreen(userID: SocialDemo.ana.rawValue, model: member), "walls.member", "ready")

        let browse = WallsBrowseModel(data: data)
        await browse.load()
        record(WallsBrowseScreen(groupID: nil, model: browse), "walls.browse", "ready")

        let held = SocialDemo.makeData()
        held.update { $0.holds.insert("wall") }
        let loadingWall = WallModel(owner: .me, data: held)
        let task = await startHeld({ await loadingWall.load() }, until: { loadingWall.showsLoading })
        record(WallMineScreen(model: loadingWall), "walls.mine", "loading")
        task.cancel()

        let heldPeople = SocialDemo.makeData()
        heldPeople.update { $0.holds.insert("myGroups") }
        let loadingBrowse = WallsBrowseModel(data: heldPeople)
        let browseTask = await startHeld({ await loadingBrowse.load() }, until: { loadingBrowse.showsLoading })
        record(WallsBrowseScreen(groupID: nil, model: loadingBrowse), "walls.browse", "loading")
        browseTask.cancel()

        let emptyData = SocialDemo.makeEmptyData()
        let emptyMine = WallModel(owner: .me, data: emptyData)
        await emptyMine.load()
        record(WallMineScreen(model: emptyMine), "walls.mine", "empty")
        let emptyMember = WallModel(owner: .member(SocialDemo.ben), data: emptyData)
        await emptyMember.load()
        record(WallMemberScreen(userID: SocialDemo.ben.rawValue, model: emptyMember), "walls.member", "empty")

        let alone = FakeSocialData(me: SocialDemo.me)
        alone.update { $0.profiles[SocialDemo.me] = SocialDemo.profiles[0] }
        let lonely = WallsBrowseModel(data: alone)
        await lonely.load()
        record(WallsBrowseScreen(groupID: nil, model: lonely), "walls.browse", "empty")

        let failing = SocialDemo.makeData()
        failing.update { $0.mode = .failing }
        let failedMine = WallModel(owner: .me, data: failing)
        await failedMine.load()
        record(WallMineScreen(model: failedMine), "walls.mine", "error")
        let failedMember = WallModel(owner: .member(SocialDemo.ana), data: failing)
        await failedMember.load()
        record(WallMemberScreen(userID: SocialDemo.ana.rawValue, model: failedMember), "walls.member", "error")
        let failedBrowse = WallsBrowseModel(data: failing)
        await failedBrowse.load()
        record(WallsBrowseScreen(groupID: nil, model: failedBrowse), "walls.browse", "error")

        let offlineData = SocialDemo.makeData()
        offlineData.update { $0.mode = .offline }
        let offlineMine = WallModel(owner: .me, data: offlineData)
        await offlineMine.load()
        record(WallMineScreen(model: offlineMine), "walls.mine", "offline")
        let offlineMember = WallModel(owner: .member(SocialDemo.ana), data: offlineData)
        await offlineMember.load()
        record(WallMemberScreen(userID: SocialDemo.ana.rawValue, model: offlineMember), "walls.member", "offline")
        let offlineBrowse = WallsBrowseModel(data: offlineData)
        await offlineBrowse.load()
        record(WallsBrowseScreen(groupID: nil, model: offlineBrowse), "walls.browse", "offline")
    }

    // MARK: week.recap / week.edit / week.history

    func testWeekRecap() async {
        let ready = WeekRecapModel(groupID: SocialDemo.groupID, recapID: SocialDemo.recapID, data: data)
        await ready.load()
        record(WeekRecapView(model: ready), "week.recap", "ready")

        let pending = WeekRecapModel(groupID: SocialDemo.groupID, recapID: SocialDemo.pendingRecapID, data: data)
        await pending.load()
        record(WeekRecapView(model: pending), "week.recap", "pending")

        let empty = WeekRecapModel(groupID: SocialDemo.groupID, recapID: RecapID("00000000-0000-4000-8000-00000000d0ff"), data: data)
        await empty.load()
        record(WeekRecapView(model: empty), "week.recap", "empty")

        let heldRecap = SocialDemo.makeData()
        heldRecap.update { $0.holds.insert("recap") }
        let loading = WeekRecapModel(groupID: SocialDemo.groupID, recapID: SocialDemo.recapID, data: heldRecap)
        let recapTask = await startHeld({ await loading.load() }, until: { loading.showsLoading })
        record(WeekRecapView(model: loading), "week.recap", "loading")
        recapTask.cancel()

        let failing = SocialDemo.makeData()
        failing.update { $0.mode = .failing }
        let failed = WeekRecapModel(groupID: SocialDemo.groupID, recapID: SocialDemo.recapID, data: failing)
        await failed.load()
        record(WeekRecapView(model: failed), "week.recap", "error")

        let offlineData = SocialDemo.makeData()
        offlineData.update { $0.mode = .offline }
        let offline = WeekRecapModel(groupID: SocialDemo.groupID, recapID: SocialDemo.recapID, data: offlineData)
        await offline.load()
        record(WeekRecapView(model: offline), "week.recap", "offline")
    }

    func testWeekEdit() async {
        let ready = WeekEditModel(groupID: SocialDemo.groupID, mode: .recap(SocialDemo.recapID), data: data)
        await ready.load()
        ready.toggle(SocialDemo.p5)
        record(WeekEditView(model: ready, toasts: ToastCenter()), "week.edit", "ready")

        let failingSave = SocialDemo.makeData()
        let saveFails = WeekEditModel(groupID: SocialDemo.groupID, mode: .recap(SocialDemo.recapID), data: failingSave)
        await saveFails.load()
        failingSave.update { $0.failOnce.insert("updateRecap") }
        await saveFails.save()
        record(WeekEditView(model: saveFails, toasts: ToastCenter()), "week.edit", "error")

        let notReady = WeekEditModel(groupID: SocialDemo.groupID, mode: .recap(SocialDemo.pendingRecapID), data: data)
        await notReady.load()
        record(WeekEditView(model: notReady, toasts: ToastCenter()), "week.edit", "not-ready")

        let loading = WeekEditModel(groupID: SocialDemo.groupID, mode: .recap(SocialDemo.recapID), data: data)
        record(WeekEditView(model: loading, toasts: ToastCenter()), "week.edit", "loading")

        var name = ""
        record(
            AlbumNameSheet(
                title: Copy.weekEditAlbumTitle, name: Binding(get: { name }, set: { name = $0 }),
                isEnabled: false, showsMissingName: true, onNameChange: {}, onSave: {}
            ),
            "week.edit", "album-sheet"
        )
    }

    func testWeekHistory() async {
        let now: @Sendable () -> Date = { SocialDemo.monday.addingTimeInterval(4 * SocialDemo.day) }
        let ready = WeekHistoryModel(groupID: SocialDemo.groupID, data: data, now: now)
        await ready.load()
        record(WeekHistoryScreen(model: ready), "week.history", "ready")

        let held = SocialDemo.makeData()
        held.update { $0.holds.insert("historyWeeks") }
        let loading = WeekHistoryModel(groupID: SocialDemo.groupID, data: held, now: now)
        let task = await startHeld({ await loading.load() }, until: { loading.showsLoading })
        record(WeekHistoryScreen(model: loading), "week.history", "loading")
        task.cancel()

        let empty = WeekHistoryModel(groupID: SocialDemo.groupID, data: SocialDemo.makeEmptyData(), now: now)
        await empty.load()
        record(WeekHistoryScreen(model: empty), "week.history", "empty")

        let failing = SocialDemo.makeData()
        failing.update { $0.mode = .failing }
        let failed = WeekHistoryModel(groupID: SocialDemo.groupID, data: failing, now: now)
        await failed.load()
        record(WeekHistoryScreen(model: failed), "week.history", "error")

        let offlineData = SocialDemo.makeData()
        offlineData.update { state in
            state.mode = .offline
            state.cachedHistory[SocialDemo.groupID] = [HistoryWeek(weekStart: SocialDemo.lastWeek, postIDs: [SocialDemo.p5, SocialDemo.p6])]
            state.cachedGroups = [SocialDemo.group(SocialDemo.groupID, name: "roommates", createdBy: SocialDemo.ana)]
        }
        let offline = WeekHistoryModel(groupID: SocialDemo.groupID, data: offlineData, now: now)
        await offline.load()
        record(WeekHistoryScreen(model: offline), "week.history", "offline")
    }

    // MARK: albums

    func testAlbums() async {
        let list = AlbumsListModel(groupID: SocialDemo.groupID, data: data)
        await list.load()
        record(AlbumsListScreen(model: list), "albums.list", "ready")

        let album = AlbumModel(groupID: SocialDemo.groupID, albumID: SocialDemo.albumID, data: data)
        await album.load()
        record(AlbumScreen(model: album), "albums.view", "ready")

        let held = SocialDemo.makeData()
        held.update { $0.holds.insert("albums") }
        let loadingList = AlbumsListModel(groupID: SocialDemo.groupID, data: held)
        let task = await startHeld({ await loadingList.load() }, until: { loadingList.showsLoading })
        record(AlbumsListScreen(model: loadingList), "albums.list", "loading")
        task.cancel()
        let loadingAlbum = AlbumModel(groupID: SocialDemo.groupID, albumID: SocialDemo.albumID, data: held)
        let albumTask = await startHeld({ await loadingAlbum.load() }, until: { loadingAlbum.showsLoading })
        record(AlbumScreen(model: loadingAlbum), "albums.view", "loading")
        albumTask.cancel()

        let emptyList = AlbumsListModel(groupID: SocialDemo.groupID, data: SocialDemo.makeEmptyData())
        await emptyList.load()
        record(AlbumsListScreen(model: emptyList), "albums.list", "empty")

        let emptied = AlbumModel(groupID: SocialDemo.groupID, albumID: SocialDemo.albumID, data: data)
        await emptied.load()
        emptied.handle(.postDeleted(postID: SocialDemo.p1, mediaID: nil))
        emptied.handle(.postDeleted(postID: SocialDemo.p2, mediaID: nil))
        record(AlbumScreen(model: emptied), "albums.view", "empty")

        let missing = AlbumModel(groupID: SocialDemo.groupID, albumID: AlbumID("00000000-0000-4000-8000-00000000e0ff"), data: data)
        await missing.load()
        record(AlbumScreen(model: missing), "albums.view", "not-found")

        let failing = SocialDemo.makeData()
        failing.update { $0.mode = .failing }
        let failedList = AlbumsListModel(groupID: SocialDemo.groupID, data: failing)
        await failedList.load()
        record(AlbumsListScreen(model: failedList), "albums.list", "error")
        let failedAlbum = AlbumModel(groupID: SocialDemo.groupID, albumID: SocialDemo.albumID, data: failing)
        await failedAlbum.load()
        record(AlbumScreen(model: failedAlbum), "albums.view", "error")

        let offlineData = SocialDemo.makeData()
        offlineData.update { $0.mode = .offline }
        let offlineList = AlbumsListModel(groupID: SocialDemo.groupID, data: offlineData)
        await offlineList.load()
        record(AlbumsListScreen(model: offlineList), "albums.list", "offline")
        let offlineAlbum = AlbumModel(groupID: SocialDemo.groupID, albumID: SocialDemo.albumID, data: offlineData)
        await offlineAlbum.load()
        record(AlbumScreen(model: offlineAlbum), "albums.view", "offline")

        var name = "weekend"
        record(
            AlbumNameSheet(
                title: Copy.albumsViewRenameTitle, name: Binding(get: { name }, set: { name = $0 }),
                isEnabled: true, showsMissingName: false, onNameChange: {}, onSave: {}
            ),
            "albums.view", "rename"
        )
    }
}
