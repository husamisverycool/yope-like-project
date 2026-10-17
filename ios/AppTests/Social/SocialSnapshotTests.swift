// Snapshots of every social screen in every state (docs/SCREENS_BRIEF.md rule 7, docs/REDESIGN_BRIEF.md "Pass 4"): every
// state in the light appearance, each surface's primary state also in the dark appearance, written to
// ios/build/snapshots/social/<surface>-<state>-<light|dark>.png for design/verification/<surface>.md. Each snapshot
// wraps the view in the appearance under test (`.environment(\.colorScheme, …)`); photo.viewer and the recap preview are
// media surfaces (dark in both by design), so their two files are expected to match.
// Screens run on the demo backend (`SocialDemo`, plus `richData()` for full recap cards and longer walls); photos and
// avatars are real sample photos (fixtures/photos/, `SocialSamplePhotos`). System alerts, context menus and sheets
// presented by a screen are not drawn by the snapshot renderer: sheets are recorded as their own views.
@testable import App
import AppData
import AppModels
import DesignSystem
import SwiftUI
import XCTest

@MainActor
final class SocialSnapshotTests: XCTestCase {
    private enum Appearance: String {
        case light
        case dark

        var scheme: ColorScheme { self == .dark ? .dark : .light }
    }

    private let both: [Appearance] = [.light, .dark]
    private var account: AccountDependencies!

    override func setUp() async throws {
        try await super.setUp()
        account = makeAccount()
        use(SocialDemo.makeData())
    }

    override func tearDown() async throws {
        SocialTabRoot.treatsEveryWallAsRoot = false
        try await super.tearDown()
    }

    // MARK: Helpers

    /// The account shell's dependencies (the C-04 tab bar under the walls tab roots).
    private func makeAccount() -> AccountDependencies {
        let suite = "social.snapshots.account"
        let defaults = UserDefaults(suiteName: suite) ?? .standard
        defaults.removePersistentDomain(forName: suite)
        return AccountDependencies.live(
            data: InMemoryAccountData(signedIn: SocialDemo.me),
            router: AppRouter(parser: .init(universalLinkHosts: [])),
            configuration: AppConfiguration(),
            notifications: StaticNotificationAuthorizer(status: .granted),
            purchases: InMemoryPurchases(),
            liveActivity: LiveActivityPreference(defaults: defaults),
            refusals: InMemoryAgeGateRefusalStore(),
            onboarding: OnboardingRecord(defaults: defaults)
        )
    }

    /// Installs `data` as the social backend the screens read (sample photos, fresh per-device flags).
    @discardableResult
    private func use(_ data: FakeSocialData) -> FakeSocialData {
        let suite = "social.snapshots"
        let defaults = UserDefaults(suiteName: suite) ?? .standard
        defaults.removePersistentDomain(forName: suite)
        SocialServices.shared = SocialServices(
            data: data, images: .samplePhotos(), flags: SocialFlags(defaults: defaults), saver: DemoPhotoSaver()
        )
        return data
    }

    /// Records `view` as `social/<surface>-<state>-<appearance>.png` for each appearance. `navigation`: hosted in a
    /// `NavigationStack` like a pushed screen (sheets with their own stack pass false).
    private func record<V: View>(
        _ view: @autoclosure () -> V,
        _ surface: String,
        _ state: String,
        _ appearances: [Appearance] = [.light],
        navigation: Bool = true,
        file: StaticString = #filePath,
        testName: String = #function,
        line: UInt = #line
    ) {
        for appearance in appearances {
            let name = surface + "-" + state + "-" + appearance.rawValue
            let built = view()
            let content = Group {
                if navigation {
                    NavigationStack { built }
                } else {
                    built
                }
            }
            .environment(account)
            .environment(\.colorScheme, appearance.scheme)
            guard let written = SnapshotRecorder.record(content, named: name, group: "social", file: file, testName: testName, line: line) else {
                XCTFail("snapshot \(name) not written", file: file, line: line)
                continue
            }
            let target = written.deletingLastPathComponent().appendingPathComponent(name + ".png")
            try? FileManager.default.removeItem(at: target)
            do {
                try FileManager.default.moveItem(at: written, to: target)
            } catch {
                XCTFail("could not name \(name): \(error)", file: file, line: line)
                continue
            }
            XCTAssertGreaterThan((try? Data(contentsOf: target).count) ?? 0, 0, file: file, line: line)
        }
    }

    /// Lets a held load reach its loading state (cache checked, request pending).
    private func startHeld(_ work: @escaping @MainActor () async -> Void, until ready: @MainActor () -> Bool) async -> Task<Void, Never> {
        let task = Task { await work() }
        _ = await socialEventually(ready)
        return task
    }

    private let utc = TimeZone(identifier: "UTC")!
    /// Friday 16 Oct 2026, 09:00 UTC (the demo's "now"): the current week starts Monday 12 Oct.
    private let friday: @Sendable () -> Date = { SocialDemo.monday.addingTimeInterval(4 * SocialDemo.day) }

    nonisolated private static func extraID(_ n: Int) -> PostID { PostID("00000000-0000-4000-8000-00000000c1" + String(10 + n)) }
    private static let recap2 = RecapID("00000000-0000-4000-8000-00000000d003")
    private static let recap3 = RecapID("00000000-0000-4000-8000-00000000d004")

    /// The demo backend with a fuller history: six more photos last week (the ready recap then fills two rows of its
    /// card), photos and ready recaps for two earlier weeks, and a second album.
    private func richData() -> FakeSocialData {
        let data = SocialDemo.makeData()
        let authors = [SocialDemo.ana, SocialDemo.ben, SocialDemo.cleo, SocialDemo.me]
        let lastWeek = SocialDemo.monday.addingTimeInterval(-7 * SocialDemo.day)
        var extra: [PostWithMedia] = []
        for n in 0..<9 {
            let date: Date
            switch n {
            case 0..<6: date = lastWeek.addingTimeInterval(Double(n) * SocialDemo.day + Double(n) * SocialDemo.hour)
            case 6..<8: date = lastWeek.addingTimeInterval(-7 * SocialDemo.day + Double(n - 5) * SocialDemo.day)
            default: date = lastWeek.addingTimeInterval(-14 * SocialDemo.day + 2 * SocialDemo.day)
            }
            let id = Self.extraID(n)
            extra.append(SocialDemo.post(
                id, by: authors[n % authors.count], at: date,
                media: MediaID("00000000-0000-4000-8000-00000000f0" + String(["a1", "a2", "a3", "a4", "a5", "a6", "a7", "a8", "a9"][n]))
            ))
        }
        data.update { state in
            state.posts += extra
            if let index = state.recaps.firstIndex(where: { $0.id == SocialDemo.recapID }) {
                state.recaps[index].items = [SocialDemo.p6, SocialDemo.p5] + (0..<6).map(Self.extraID)
            }
            let earlier = { (weeksBack: Int) -> LocalDate in SocialDemo.lastWeek.adding(days: -7 * weeksBack) }
            state.recaps += [
                WeeklyRecap(
                    id: Self.recap2, groupID: SocialDemo.groupID, weekStart: earlier(1), items: [Self.extraID(6), Self.extraID(7)],
                    text: nil, status: .ready, generatedAt: lastWeek, editedBy: nil, createdAt: lastWeek, updatedAt: lastWeek
                ),
                WeeklyRecap(
                    id: Self.recap3, groupID: SocialDemo.groupID, weekStart: earlier(2), items: [Self.extraID(8)],
                    text: nil, status: .ready, generatedAt: lastWeek, editedBy: nil, createdAt: lastWeek, updatedAt: lastWeek
                ),
            ]
            state.albums.append(AlbumWithItems(
                album: Album(
                    id: AlbumID("00000000-0000-4000-8000-00000000e002"), groupID: SocialDemo.groupID, name: "lake weekend",
                    createdBy: SocialDemo.me, createdAt: SocialDemo.monday, updatedAt: SocialDemo.monday
                ),
                postIDs: [Self.extraID(3), Self.extraID(4), Self.extraID(5)]
            ))
        }
        return data
    }

    private func failing() -> FakeSocialData {
        let data = SocialDemo.makeData()
        data.update { $0.mode = .failing }
        return data
    }

    private func offline(_ configure: (inout FakeSocialData.State) -> Void = { _ in }) -> FakeSocialData {
        let data = SocialDemo.makeData()
        data.update { state in
            state.mode = .offline
            configure(&state)
        }
        return data
    }

    // MARK: chat.thread

    func testChatThread() async {
        let data = use(SocialDemo.makeData())
        let ready = ChatThreadModel(groupID: SocialDemo.groupID, data: data)
        await ready.load()
        record(ChatThreadView(model: ready), "chat.thread", "ready", both)

        let held = use(SocialDemo.makeData())
        held.update { $0.holds.insert("messages") }
        let loading = ChatThreadModel(groupID: SocialDemo.groupID, data: held)
        let task = await startHeld({ await loading.load() }, until: { loading.showsLoading })
        record(ChatThreadView(model: loading), "chat.thread", "loading")
        task.cancel()

        // Older pages: the activity indicator above the first loaded message.
        let paged = use(SocialDemo.makeData())
        paged.update { $0.messagePageSize = 4 }
        let older = ChatThreadModel(groupID: SocialDemo.groupID, data: paged)
        await older.load()
        record(ChatThreadView(model: older), "chat.thread", "loading-older")

        let emptyData = use(SocialDemo.makeEmptyData())
        let empty = ChatThreadModel(groupID: SocialDemo.groupID, data: emptyData)
        await empty.load()
        record(ChatThreadView(model: empty), "chat.thread", "empty")

        let failed = ChatThreadModel(groupID: SocialDemo.groupID, data: use(failing()))
        await failed.load()
        record(ChatThreadView(model: failed), "chat.thread", "error")

        let offlineModel = ChatThreadModel(groupID: SocialDemo.groupID, data: use(offline()))
        await offlineModel.load()
        record(ChatThreadView(model: offlineModel), "chat.thread", "offline")

        let cachedData = use(offline { state in
            state.cachedMessages[SocialDemo.groupID] = SocialDemo.messages.reversed()
            state.cachedFeeds[SocialDemo.groupID] = SocialDemo.posts
        })
        let cached = ChatThreadModel(groupID: SocialDemo.groupID, data: cachedData)
        await cached.load()
        record(ChatThreadView(model: cached), "chat.thread", "offline-cached")

        // A reply to a text message (the quote line above the bubble) and a deleted message's quote gone.
        let replies = use(SocialDemo.makeData())
        replies.update { state in
            state.messages.append(SocialDemo.message(
                20, by: SocialDemo.cleo, at: SocialDemo.monday.addingTimeInterval(3 * SocialDemo.day + 9 * SocialDemo.hour),
                text: "same, pasta forever", replyToMessage: SocialDemo.messageID(2)
            ))
        }
        let quoting = ChatThreadModel(groupID: SocialDemo.groupID, data: replies)
        await quoting.load()
        record(ChatThreadView(model: quoting), "chat.thread", "reply-quotes")

        // `chat.thread.layout.systemLine`: "{name} joined" and "{name} left the group" between messages (the person who
        // left is named from the line, their profile no longer shared).
        let lines = use(SocialDemo.makeData())
        lines.update { state in
            let at = SocialDemo.monday.addingTimeInterval(3 * SocialDemo.day + 8 * SocialDemo.hour)
            state.messages.append(Message(
                id: MessageID("00000000-0000-4000-8000-0000000c0001"), groupID: SocialDemo.groupID, authorID: SocialDemo.cleo,
                kind: .joined, body: "Cleo Ramos", createdAt: at
            ))
            state.messages.append(Message(
                id: MessageID("00000000-0000-4000-8000-0000000c0002"), groupID: SocialDemo.groupID,
                authorID: UserID("00000000-0000-4000-8000-00000000a0ff"), kind: .left, body: "Dana Silva", createdAt: at + 120
            ))
            state.messages.append(SocialDemo.message(21, by: SocialDemo.cleo, at: at + 300, text: "hi all!"))
        }
        let joined = ChatThreadModel(groupID: SocialDemo.groupID, data: lines)
        await joined.load()
        record(ChatThreadView(model: joined), "chat.thread", "joined-left", both)
    }

    // MARK: chat.composer

    func testChatComposer() async {
        let data = use(SocialDemo.makeData())
        let idle = ChatThreadModel(groupID: SocialDemo.groupID, data: data)
        await idle.load()
        record(ChatThreadView(model: idle), "chat.composer", "idle", both)

        let typing = ChatThreadModel(groupID: SocialDemo.groupID, data: data)
        await typing.load()
        typing.draft = "on my way"
        record(ChatThreadView(model: typing), "chat.composer", "typing")

        let replying = ChatThreadModel(groupID: SocialDemo.groupID, data: data)
        await replying.load()
        if let photo = replying.messages.first(where: { $0.postID == SocialDemo.p2 }) { replying.startReply(to: photo) }
        record(ChatThreadView(model: replying), "chat.composer", "replying")

        // Sending: the message shows with `chat.thread.sending` until the server answers.
        let slow = use(SocialDemo.makeData())
        slow.update { state in
            state.beforeSendReturns = { _ in _ = try? await Task.sleep(for: .seconds(30)) }
        }
        let sending = ChatThreadModel(groupID: SocialDemo.groupID, data: slow)
        await sending.load()
        sending.draft = "see you at 8"
        let sendTask = await startHeld({ await sending.sendDraft() }, until: { sending.isSending })
        record(ChatThreadView(model: sending), "chat.composer", "sending")
        sendTask.cancel()
        _ = await sendTask.value

        // Failed: the message stays with `chat.thread.sendFailed` (`chat.thread.layout.failedMessage`).
        let failingSend = use(SocialDemo.makeData())
        let notSent = ChatThreadModel(groupID: SocialDemo.groupID, data: failingSend)
        await notSent.load()
        failingSend.update { $0.failOnce.insert("sendText") }
        notSent.draft = "see you at 8"
        await notSent.sendDraft()
        record(ChatThreadView(model: notSent), "chat.composer", "failed")

        // An emoji-only message (≤ `chat.thread.count.emojiOnlyMax`) shows large, without a bubble.
        let emoji = ChatThreadModel(groupID: SocialDemo.groupID, data: use(SocialDemo.makeData()))
        await emoji.load()
        emoji.draft = "🔥🔥🔥"
        await emoji.sendDraft()
        record(ChatThreadView(model: emoji), "chat.composer", "emoji-only")
    }

    // MARK: chat.voice

    /// The loaded thread (header + messages) with [recorder] in the composer (no microphone needed in the snapshot).
    private func recordingThread(_ recorder: SocialVoiceRecorder) async -> some View {
        let model = ChatThreadModel(groupID: SocialDemo.groupID, data: use(SocialDemo.makeData()))
        await model.load()
        return ChatThreadView(model: model, recorder: recorder)
    }

    func testChatVoice() async {
        let data = use(SocialDemo.makeData())
        let idle = ChatThreadModel(groupID: SocialDemo.groupID, data: data)
        await idle.load()
        record(ChatThreadView(model: idle), "chat.voice", "idle", both)

        let holding = SocialVoiceRecorder()
        holding.showRecordingForSnapshot(.holding)
        let holdingView = await recordingThread(holding)
        record(holdingView, "chat.voice", "recording")

        // Locked (`chat.voice.layout.locked`): the live waveform in the field, delete · pause · send under it.
        let locked = SocialVoiceRecorder()
        locked.showRecordingForSnapshot(.locked, elapsedMs: 7_000, levels: SocialDemo.voiceLevelsMessage)
        let lockedView = await recordingThread(locked)
        record(lockedView, "chat.voice", "recording-locked", both)

        // Paused draft, previewing part-way: preview glyph · played / unplayed bars · elapsed; delete · continue · send.
        let paused = SocialVoiceRecorder()
        paused.showRecordingForSnapshot(.paused, elapsedMs: 11_000, levels: SocialDemo.voiceLevelsNote, previewProgress: 0.45)
        let pausedView = await recordingThread(paused)
        record(pausedView, "chat.voice", "recording-paused", both)

        // The audio could not be fetched: `chat.voice.error.play` in the capsule.
        let broken = use(SocialDemo.makeData())
        let failedPlay = ChatThreadModel(groupID: SocialDemo.groupID, data: broken)
        await failedPlay.load()
        broken.update { $0.failOnce.insert("fileURL") }
        let voice = SocialDemo.messages[4]
        _ = await SocialServices.shared.playback.toggle(key: voice.id.rawValue, path: voice.voicePath, localFile: nil)
        record(ChatThreadView(model: failedPlay), "chat.voice", "error-play")
    }

    // MARK: chat.reactions

    func testChatReactions() async {
        let data = use(SocialDemo.makeData())
        data.update { state in
            state.reactions += [
                SocialDemo.reaction(SocialDemo.p1, SocialDemo.ben, "😂", minutes: 80),
                SocialDemo.reaction(SocialDemo.p1, SocialDemo.cleo, "😍", minutes: 85),
                SocialDemo.reaction(SocialDemo.p4, SocialDemo.ana, "🐶", minutes: 4400),
            ]
        }
        let thread = ChatThreadModel(groupID: SocialDemo.groupID, data: data)
        await thread.load()
        record(ChatThreadView(model: thread), "chat.reactions", "cluster", both)

        record(ReactionPicker(catalog: SocialEmojiCatalog.bundled, onPick: { _ in }), "chat.reactions", "picker", navigation: false)
        // `chat.reactions.layout.unreact`: my reactions selected in the picker.
        record(ReactionPicker(mine: ["💖", "🔥"], catalog: SocialEmojiCatalog.bundled, onPick: { _ in }, onRemove: { _ in }), "chat.reactions", "picker-mine", navigation: false)

        let summary = thread.reactions[SocialDemo.p1] ?? ReactionSummary()
        record(
            ReactionsSheet(reactions: summary, me: SocialDemo.me, profile: { thread.profile($0) }, onRemove: { _ in }),
            "chat.reactions", "sheet", navigation: false
        )
        record(
            ReactionsSheet(reactions: ReactionSummary(), me: SocialDemo.me, profile: { _ in nil }, onRemove: { _ in }),
            "chat.reactions", "sheet-empty", navigation: false
        )
    }

    // MARK: photo.viewer

    private func viewer(_ start: PostID, data: FakeSocialData, ids: [PostID] = [SocialDemo.p1, SocialDemo.p2, SocialDemo.p3, SocialDemo.p4]) -> PhotoViewerModel {
        PhotoViewerModel(context: PhotoViewerContext(postIDs: ids, start: start, groupID: SocialDemo.groupID), data: data)
    }

    func testPhotoViewer() async {
        let data = use(SocialDemo.makeData())
        let others = viewer(SocialDemo.p2, data: data)
        await others.load()
        record(PhotoViewerView(model: others, presentation: .pushed), "photo.viewer", "ready", both)

        let own = viewer(SocialDemo.p3, data: data)
        await own.load()
        record(PhotoViewerView(model: own, presentation: .pushed), "photo.viewer", "ready-own")

        // memory's tag run under the photo: "with Ben and Sam".
        let tagData = use(SocialDemo.makeData())
        tagData.update { $0.tags = [SocialDemo.tag(SocialDemo.p2, SocialDemo.ben, minutes: 1), SocialDemo.tag(SocialDemo.p2, SocialDemo.me, minutes: 2)] }
        let tagged = viewer(SocialDemo.p2, data: tagData)
        await tagged.load()
        record(PhotoViewerView(model: tagged, presentation: .pushed), "photo.viewer", "tagged")

        let replying = viewer(SocialDemo.p2, data: tagData)
        await replying.load()
        replying.replyDraft = "so pretty"
        record(PhotoViewerView(model: replying, presentation: .pushed), "photo.viewer", "reply-typing")

        let live = viewer(SocialDemo.p4, data: data)
        await live.load()
        record(PhotoViewerView(model: live, presentation: .pushed), "photo.viewer", "live-photo")

        let fromWall = PhotoViewerModel(
            context: PhotoViewerContext(postIDs: [SocialDemo.p3, SocialDemo.p6], start: SocialDemo.p3, showsGroupName: true), data: data
        )
        await fromWall.load()
        record(PhotoViewerView(model: fromWall, presentation: .pushed), "photo.viewer", "from-wall")

        let loading = viewer(SocialDemo.p2, data: data)
        record(PhotoViewerView(model: loading, presentation: .pushed), "photo.viewer", "loading")

        let gone = viewer(SocialDemo.p2, data: data)
        await gone.load()
        await gone.handle(.postDeleted(postID: SocialDemo.p2, mediaID: nil))
        record(PhotoViewerView(model: gone, presentation: .pushed), "photo.viewer", "gone")

        let failed = viewer(SocialDemo.p2, data: use(failing()))
        await failed.load()
        record(PhotoViewerView(model: failed, presentation: .pushed), "photo.viewer", "error")

        let cachedData = use(offline { state in
            state.cachedFeeds[SocialDemo.groupID] = SocialDemo.posts.filter { $0.post.groupID == SocialDemo.groupID }
        })
        let cached = viewer(SocialDemo.p2, data: cachedData)
        await cached.load()
        record(PhotoViewerView(model: cached, presentation: .pushed), "photo.viewer", "offline")
    }

    // MARK: walls

    private func wall(_ owner: WallModel.Owner, _ data: FakeSocialData) -> WallModel {
        WallModel(owner: owner, data: data, timeZone: utc, now: friday)
    }

    func testWallsMine() async {
        // The profile tab's root: no back chevron, the tab bar below.
        SocialTabRoot.treatsEveryWallAsRoot = true
        let data = use(richData())
        let mine = wall(.me, data)
        await mine.load()
        record(WallMineScreen(model: mine), "walls.mine", "ready", both)

        let held = use(SocialDemo.makeData())
        held.update { $0.holds.insert("wall") }
        let loading = wall(.me, held)
        let task = await startHeld({ await loading.load() }, until: { loading.showsLoading })
        record(WallMineScreen(model: loading), "walls.mine", "loading")
        task.cancel()

        let empty = wall(.me, use(SocialDemo.makeEmptyData()))
        await empty.load()
        record(WallMineScreen(model: empty), "walls.mine", "empty")

        let failed = wall(.me, use(failing()))
        await failed.load()
        record(WallMineScreen(model: failed), "walls.mine", "error")

        let cachedData = use(offline { state in
            state.cachedWalls[SocialDemo.me] = [
                WallItem(itemKind: .post, postID: SocialDemo.p3, mediaID: SocialDemo.mediaID(SocialDemo.p3), collageID: nil,
                         groupIDs: [SocialDemo.groupID], createdAt: SocialDemo.monday.addingTimeInterval(2 * SocialDemo.day)),
                WallItem(itemKind: .post, postID: SocialDemo.p6, mediaID: SocialDemo.mediaID(SocialDemo.p6), collageID: nil,
                         groupIDs: [SocialDemo.groupID], createdAt: SocialDemo.monday.addingTimeInterval(-4 * SocialDemo.day)),
            ]
            state.cachedFeeds[SocialDemo.groupID] = SocialDemo.posts
        })
        let cached = wall(.me, cachedData)
        await cached.load()
        record(WallMineScreen(model: cached), "walls.mine", "offline")
    }

    func testWallsMember() async {
        let data = use(richData())
        let member = wall(.member(SocialDemo.ana), data)
        await member.load()
        record(WallMemberScreen(userID: SocialDemo.ana.rawValue, model: member), "walls.member", "ready", both)

        let held = use(SocialDemo.makeData())
        held.update { $0.holds.insert("wall") }
        let loading = wall(.member(SocialDemo.ana), held)
        let task = await startHeld({ await loading.load() }, until: { loading.showsLoading })
        record(WallMemberScreen(userID: SocialDemo.ana.rawValue, model: loading), "walls.member", "loading")
        task.cancel()

        let empty = wall(.member(SocialDemo.ben), use(SocialDemo.makeEmptyData()))
        await empty.load()
        record(WallMemberScreen(userID: SocialDemo.ben.rawValue, model: empty), "walls.member", "empty")

        let blocked = wall(.member(SocialDemo.ana), use(SocialDemo.makeData()))
        await blocked.load()
        blocked.blocked()
        record(WallMemberScreen(userID: SocialDemo.ana.rawValue, model: blocked), "walls.member", "blocked")

        let failed = wall(.member(SocialDemo.ana), use(failing()))
        await failed.load()
        record(WallMemberScreen(userID: SocialDemo.ana.rawValue, model: failed), "walls.member", "error")

        let offlineModel = wall(.member(SocialDemo.ana), use(offline()))
        await offlineModel.load()
        record(WallMemberScreen(userID: SocialDemo.ana.rawValue, model: offlineModel), "walls.member", "offline")
    }

    func testWallsBrowse() async {
        // The Friends tab's root (C-01 title, tab bar below).
        SocialTabRoot.treatsEveryWallAsRoot = true
        let data = use(SocialDemo.makeData())
        let browse = WallsBrowseModel(data: data)
        await browse.load()
        record(WallsBrowseScreen(groupID: nil, model: browse), "walls.browse", "ready", both)

        let searching = WallsBrowseModel(data: data)
        await searching.load()
        searching.search = "zed"
        record(WallsBrowseScreen(groupID: nil, model: searching), "walls.browse", "no-results")

        let held = use(SocialDemo.makeData())
        held.update { $0.holds.insert("myGroups") }
        let loading = WallsBrowseModel(data: held)
        let task = await startHeld({ await loading.load() }, until: { loading.showsLoading })
        record(WallsBrowseScreen(groupID: nil, model: loading), "walls.browse", "loading")
        task.cancel()

        let alone = FakeSocialData(me: SocialDemo.me)
        alone.update { $0.profiles[SocialDemo.me] = SocialDemo.profiles[0] }
        let lonely = WallsBrowseModel(data: use(alone))
        await lonely.load()
        record(WallsBrowseScreen(groupID: nil, model: lonely), "walls.browse", "empty")

        let failed = WallsBrowseModel(data: use(failing()))
        await failed.load()
        record(WallsBrowseScreen(groupID: nil, model: failed), "walls.browse", "error")

        let cachedData = use(offline { state in
            state.cachedGroups = state.groups
            for group in state.groups { state.cachedMembers[group.id] = state.members[group.id] }
        })
        let cached = WallsBrowseModel(data: cachedData)
        await cached.load()
        record(WallsBrowseScreen(groupID: nil, model: cached), "walls.browse", "offline")

        // Group-scoped entry (pushed: C-02 back chevron + title).
        SocialTabRoot.treatsEveryWallAsRoot = false
        let scoped = WallsBrowseModel(data: use(SocialDemo.makeData()), groupID: SocialDemo.groupID)
        await scoped.load()
        record(WallsBrowseScreen(groupID: SocialDemo.groupID.rawValue, model: scoped), "walls.browse", "group")
    }

    // MARK: week.recap

    func testWeekRecapList() async {
        let data = use(richData())
        let list = WeekRecapListModel(groupID: SocialDemo.groupID, data: data)
        await list.load()
        record(WeekRecapListScreen(model: list), "week.recap", "list", both, navigation: false)

        let held = use(SocialDemo.makeData())
        held.update { $0.holds.insert("recaps") }
        let loading = WeekRecapListModel(groupID: SocialDemo.groupID, data: held)
        let task = await startHeld({ await loading.load() }, until: { loading.showsLoading })
        record(WeekRecapListScreen(model: loading), "week.recap", "list-loading", navigation: false)
        task.cancel()

        let empty = WeekRecapListModel(groupID: SocialDemo.groupID, data: use(SocialDemo.makeEmptyData()))
        await empty.load()
        record(WeekRecapListScreen(model: empty), "week.recap", "list-empty", navigation: false)

        let failed = WeekRecapListModel(groupID: SocialDemo.groupID, data: use(failing()))
        await failed.load()
        record(WeekRecapListScreen(model: failed), "week.recap", "list-error", navigation: false)

        let offlineList = WeekRecapListModel(groupID: SocialDemo.groupID, data: use(offline()))
        await offlineList.load()
        record(WeekRecapListScreen(model: offlineList), "week.recap", "list-offline", navigation: false)
    }

    func testWeekRecapPreview() async {
        let data = use(richData())
        let ready = WeekRecapModel(groupID: SocialDemo.groupID, recapID: SocialDemo.recapID, data: data)
        await ready.load()
        record(WeekRecapPreviewScreen(model: ready), "week.recap", "preview", both)
        record(WeekRecapPreviewScreen(model: ready, page: 1), "week.recap", "preview-cover")

        // week.recap.layout.gridFill: 1 photo fills the area, 5 → 2 × 3 with a short last row, 9 → 3 × 3 (Retro TC-H).
        for (count, name) in [(1, "preview-one"), (5, "preview-five"), (9, "preview-nine")] {
            let filled = use(richData())
            filled.update { state in
                if let index = state.recaps.firstIndex(where: { $0.id == SocialDemo.recapID }) {
                    state.recaps[index].items = Array(([SocialDemo.p6, SocialDemo.p5] + (0..<9).map(Self.extraID)).prefix(count))
                }
            }
            let model = WeekRecapModel(groupID: SocialDemo.groupID, recapID: SocialDemo.recapID, data: filled)
            await model.load()
            record(WeekRecapPreviewScreen(model: model), "week.recap", name)
        }

        let noted = use(richData())
        noted.update { state in
            if let index = state.recaps.firstIndex(where: { $0.id == SocialDemo.recapID }) {
                state.recaps[index].text = "best week of the fall, lake day was everything"
                state.recaps[index].editedBy = SocialDemo.ana
            }
        }
        let note = WeekRecapModel(groupID: SocialDemo.groupID, recapID: SocialDemo.recapID, data: noted)
        await note.load()
        record(WeekRecapPreviewScreen(model: note), "week.recap", "preview-note")

        let held = use(SocialDemo.makeData())
        held.update { $0.holds.insert("recap") }
        let loading = WeekRecapModel(groupID: SocialDemo.groupID, recapID: SocialDemo.recapID, data: held)
        let task = await startHeld({ await loading.load() }, until: { loading.showsLoading })
        record(WeekRecapPreviewScreen(model: loading), "week.recap", "preview-loading")
        task.cancel()

        let pending = WeekRecapModel(groupID: SocialDemo.groupID, recapID: SocialDemo.pendingRecapID, data: use(SocialDemo.makeData()))
        await pending.load()
        record(WeekRecapPreviewScreen(model: pending), "week.recap", "preview-pending")

        let failed = WeekRecapModel(groupID: SocialDemo.groupID, recapID: SocialDemo.recapID, data: use(failing()))
        await failed.load()
        record(WeekRecapPreviewScreen(model: failed), "week.recap", "preview-error")
    }

    // MARK: week.edit

    func testWeekEdit() async {
        let data = use(richData())
        let ready = WeekEditModel(groupID: SocialDemo.groupID, mode: .recap(SocialDemo.recapID), data: data)
        await ready.load()
        record(WeekEditView(model: ready, toasts: ToastCenter()), "week.edit", "ready", both, navigation: false)

        let loading = WeekEditModel(groupID: SocialDemo.groupID, mode: .recap(SocialDemo.recapID), data: data)
        record(WeekEditView(model: loading, toasts: ToastCenter()), "week.edit", "loading", navigation: false)

        let slow = use(richData())
        slow.update { $0.holds.insert("updateRecap") }
        let saving = WeekEditModel(groupID: SocialDemo.groupID, mode: .recap(SocialDemo.recapID), data: slow)
        await saving.load()
        let task = await startHeld({ await saving.save() }, until: { saving.isSaving })
        record(WeekEditView(model: saving, toasts: ToastCenter()), "week.edit", "saving", navigation: false)
        task.cancel()

        let cleared = WeekEditModel(groupID: SocialDemo.groupID, mode: .recap(SocialDemo.recapID), data: use(richData()))
        await cleared.load()
        for id in cleared.chosen { cleared.toggle(id) }
        record(WeekEditView(model: cleared, toasts: ToastCenter()), "week.edit", "empty-selection", navigation: false)

        let notReady = WeekEditModel(groupID: SocialDemo.groupID, mode: .recap(SocialDemo.pendingRecapID), data: use(SocialDemo.makeData()))
        await notReady.load()
        record(WeekEditView(model: notReady, toasts: ToastCenter()), "week.edit", "not-ready", navigation: false)

        // The album sheet alone (week.history's "Save as Album"), then submitted without a name.
        let album = WeekEditModel(groupID: SocialDemo.groupID, mode: .album(weekStart: SocialDemo.thisWeek), data: use(SocialDemo.makeData()))
        await album.load()
        record(WeekEditView(model: album, toasts: ToastCenter()), "week.edit", "album-sheet", navigation: false)
        await album.saveAlbum()
        record(WeekEditView(model: album, toasts: ToastCenter()), "week.edit", "album-name-missing", navigation: false)

        var message = "best week of the fall"
        record(
            WeekEditMessageSheet(text: Binding(get: { message }, set: { message = $0 })),
            "week.edit", "message", navigation: false
        )
    }

    // MARK: week.history

    private func history(_ data: FakeSocialData) -> WeekHistoryModel {
        WeekHistoryModel(groupID: SocialDemo.groupID, data: data, now: friday)
    }

    func testWeekHistory() async {
        let ready = history(use(richData()))
        await ready.load()
        record(WeekHistoryScreen(model: ready), "week.history", "ready", both)

        let held = use(SocialDemo.makeData())
        held.update { $0.holds.insert("historyWeeks") }
        let loading = history(held)
        let task = await startHeld({ await loading.load() }, until: { loading.showsLoading })
        record(WeekHistoryScreen(model: loading), "week.history", "loading")
        task.cancel()

        let empty = history(use(SocialDemo.makeEmptyData()))
        await empty.load()
        record(WeekHistoryScreen(model: empty), "week.history", "empty")

        let failed = history(use(failing()))
        await failed.load()
        record(WeekHistoryScreen(model: failed), "week.history", "error")

        let offlineModel = history(use(offline { state in
            state.cachedHistory[SocialDemo.groupID] = [HistoryWeek(weekStart: SocialDemo.lastWeek, postIDs: [SocialDemo.p5, SocialDemo.p6])]
            state.cachedGroups = [SocialDemo.group(SocialDemo.groupID, name: "roommates", createdBy: SocialDemo.ana)]
            state.cachedFeeds[SocialDemo.groupID] = SocialDemo.posts
        }))
        await offlineModel.load()
        record(WeekHistoryScreen(model: offlineModel), "week.history", "offline")
    }

    /// week.history's calendar (`week.history.layout.calendar`): the months with the days that open a week.
    func testWeekHistoryCalendar() async {
        let model = history(use(richData()))
        await model.load()
        XCTAssertFalse(model.months.isEmpty, "the calendar glyph shows once the months are known")
        record(
            HistoryCalendarSheet(months: model.months.map(HistoryCalendarMonth.init), timeZone: utc, onSelect: { _ in }, onClose: {}),
            "week.history", "calendar", both, navigation: false
        )
    }

    // MARK: search.photos

    func testSearchPhotos() async {
        let data = use(richData())
        let idle = SearchPhotosModel(groupID: SocialDemo.groupID, data: data)
        await idle.loadMembers()
        record(SearchPhotosScreen(model: idle), "search.photos", "idle", both)

        let found = SearchPhotosModel(groupID: nil, data: data)
        await found.loadMembers()
        await found.toggle(member: SocialDemo.ana)
        XCTAssertEqual(found.phase, .results)
        record(SearchPhotosScreen(model: found), "search.photos", "results", both)

        let none = SearchPhotosModel(groupID: SocialDemo.groupID, data: data)
        none.text = "zzz"
        await none.search()
        XCTAssertEqual(none.phase, .empty)
        record(SearchPhotosScreen(model: none), "search.photos", "empty")

        let held = use(SocialDemo.makeData())
        held.update { $0.holds.insert("searchPhotos") }
        let loading = SearchPhotosModel(groupID: SocialDemo.groupID, data: held)
        loading.text = "snow"
        let task = await startHeld({ await loading.search() }, until: { loading.phase == .loading })
        record(SearchPhotosScreen(model: loading), "search.photos", "loading")
        task.cancel()

        let failed = SearchPhotosModel(groupID: SocialDemo.groupID, data: use(failing()))
        failed.text = "snow"
        await failed.search()
        record(SearchPhotosScreen(model: failed), "search.photos", "error")

        let offlineModel = SearchPhotosModel(groupID: SocialDemo.groupID, data: use(offline { _ in }))
        offlineModel.text = "snow"
        await offlineModel.search()
        XCTAssertEqual(offlineModel.phase, .offline)
        record(SearchPhotosScreen(model: offlineModel), "search.photos", "offline", both)

        record(SearchDatesSheet(from: nil, to: nil, onDone: { _, _ in }), "search.photos", "dates", navigation: false)
    }

    // MARK: albums.list

    func testAlbumsList() async {
        let data = use(richData())
        let list = AlbumsListModel(groupID: SocialDemo.groupID, data: data)
        await list.load()
        record(AlbumsListScreen(model: list), "albums.list", "ready", both)

        let searching = AlbumsListModel(groupID: SocialDemo.groupID, data: data)
        await searching.load()
        searching.search = "zzz"
        record(AlbumsListScreen(model: searching), "albums.list", "no-results")

        let held = use(SocialDemo.makeData())
        held.update { $0.holds.insert("albums") }
        let loading = AlbumsListModel(groupID: SocialDemo.groupID, data: held)
        let task = await startHeld({ await loading.load() }, until: { loading.showsLoading })
        record(AlbumsListScreen(model: loading), "albums.list", "loading")
        task.cancel()

        let empty = AlbumsListModel(groupID: SocialDemo.groupID, data: use(SocialDemo.makeEmptyData()))
        await empty.load()
        record(AlbumsListScreen(model: empty), "albums.list", "empty")

        let failed = AlbumsListModel(groupID: SocialDemo.groupID, data: use(failing()))
        await failed.load()
        record(AlbumsListScreen(model: failed), "albums.list", "error")

        let cached = AlbumsListModel(groupID: SocialDemo.groupID, data: use(offline { state in
            state.cachedAlbums[SocialDemo.groupID] = SocialDemo.albums
            state.cachedFeeds[SocialDemo.groupID] = SocialDemo.posts
        }))
        await cached.load()
        record(AlbumsListScreen(model: cached), "albums.list", "offline")
    }

    // MARK: albums.view

    func testAlbumsView() async {
        let data = use(richData())
        let album = AlbumModel(groupID: SocialDemo.groupID, albumID: SocialDemo.albumID, data: data)
        await album.load()
        record(AlbumScreen(model: album), "albums.view", "ready", both, navigation: false)

        let mine = AlbumModel(groupID: SocialDemo.groupID, albumID: AlbumID("00000000-0000-4000-8000-00000000e002"), data: data)
        await mine.load()
        record(AlbumScreen(model: mine), "albums.view", "ready-mine", navigation: false)

        let held = use(SocialDemo.makeData())
        held.update { $0.holds.insert("albums") }
        let loading = AlbumModel(groupID: SocialDemo.groupID, albumID: SocialDemo.albumID, data: held)
        let task = await startHeld({ await loading.load() }, until: { loading.showsLoading })
        record(AlbumScreen(model: loading, initialName: "weekend"), "albums.view", "loading", navigation: false)
        task.cancel()

        let emptied = AlbumModel(groupID: SocialDemo.groupID, albumID: SocialDemo.albumID, data: use(SocialDemo.makeData()))
        await emptied.load()
        emptied.handle(.postDeleted(postID: SocialDemo.p1, mediaID: nil))
        emptied.handle(.postDeleted(postID: SocialDemo.p2, mediaID: nil))
        record(AlbumScreen(model: emptied), "albums.view", "empty", navigation: false)

        let missing = AlbumModel(groupID: SocialDemo.groupID, albumID: AlbumID("00000000-0000-4000-8000-00000000e0ff"), data: use(SocialDemo.makeData()))
        await missing.load()
        record(AlbumScreen(model: missing), "albums.view", "not-found", navigation: false)

        let failed = AlbumModel(groupID: SocialDemo.groupID, albumID: SocialDemo.albumID, data: use(failing()))
        await failed.load()
        record(AlbumScreen(model: failed), "albums.view", "error", navigation: false)

        let cached = AlbumModel(groupID: SocialDemo.groupID, albumID: SocialDemo.albumID, data: use(offline { state in
            state.cachedAlbums[SocialDemo.groupID] = SocialDemo.albums
            state.cachedFeeds[SocialDemo.groupID] = SocialDemo.posts
        }))
        await cached.load()
        record(AlbumScreen(model: cached), "albums.view", "offline", navigation: false)

        // The rename sheet (prefilled), then submitted empty.
        func renameSheet(_ name: String, missing: Bool) -> SocialNameSheet {
            var text = name
            return SocialNameSheet(
                title: Copy.albumsViewRenameTitle,
                placeholder: Copy.weekEditAlbumNamePlaceholder,
                buttonTitle: Copy.albumsViewRenameSave,
                name: Binding(get: { text }, set: { text = $0 }),
                isEnabled: !name.isEmpty,
                isBusy: false,
                showsMissingName: missing,
                closeAccessibilityLabel: Copy.photoViewerA11yClose,
                onNameChange: {}, onSave: {}, onClose: {}
            )
        }
        record(renameSheet("weekend", missing: false), "albums.view", "rename", navigation: false)
        record(renameSheet("", missing: true), "albums.view", "rename-missing", navigation: false)
    }
}
