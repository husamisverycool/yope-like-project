// Downloads (owner decisions 29 and 34, research #2): "Download My Photos" pages download_items('mine') and saves each
// original; "Download Album" (premium). Spec: design/surfaces/settings.downloads.md.
@testable import App
import AppData
import AppModels
import Foundation
import XCTest

@MainActor
final class SocialDownloadModelTests: XCTestCase {
    private func store(_ name: String = #function) -> DownloadCursorStore {
        let suite = "social.downloads.tests." + name
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return DownloadCursorStore(defaults: defaults)
    }

    /// `count` of my photos, one minute apart, the newest first by `posted_at`; the second is a Live Photo.
    private func items(_ count: Int) -> [DownloadItem] {
        (0..<count).map { index in
            let suffix = String(100_000_000_000 + index).suffix(12)
            return DownloadItem(
                postID: PostID("00000000-0000-4000-8000-" + suffix),
                mediaID: MediaID("00000000-0000-4000-9000-" + suffix),
                kind: index == 1 ? .livePhoto : .photo,
                originalPath: "u/me/\(index)/original.jpg",
                motionPath: index == 1 ? "u/me/\(index)/motion.mov" : nil,
                postedAt: SocialDemo.monday.addingTimeInterval(TimeInterval(-60 * index))
            )
        }
    }

    private func makeModel(_ data: FakeSocialData, scope: DownloadScope = .mine, saver: any SocialPhotoSaving = RecordingPhotoSaver(), store: DownloadCursorStore) -> PhotoDownloadModel {
        PhotoDownloadModel(scope: scope, data: data, saver: saver, store: store)
    }

    func testEveryOneOfMyPhotosIsSaved() async {
        let data = SocialDemo.makeData()
        let mine = items(5)
        data.update { $0.downloads = mine }
        let saver = RecordingPhotoSaver()
        let model = makeModel(data, saver: saver, store: store())
        await model.load()
        XCTAssertFalse(model.canResume)
        XCTAssertEqual(model.phase, .idle)
        await model.start()?.value
        XCTAssertEqual(model.phase, .done)
        XCTAssertEqual(saver.savedCount, 5)
        XCTAssertEqual(model.signals.feedback?.kind, .success, "haptic.global.success")
        XCTAssertNil(model.fraction, "your photos: an indeterminate indicator, never a figure")
        XCTAssertFalse(model.canResume)
    }

    func testFullPagesAreFollowedByTheNextOneUntilAShortPage() async {
        let data = SocialDemo.makeData()
        let all = items(SocialPaging.downloads + 3)
        data.update { $0.downloads = all }
        let saver = RecordingPhotoSaver()
        let model = makeModel(data, saver: saver, store: store())
        await model.load()
        await model.start()?.value
        XCTAssertEqual(model.phase, .done)
        XCTAssertEqual(saver.savedCount, all.count)
        let cursors = data.read { state in state.downloadCalls.map { $0.before } }
        XCTAssertEqual(cursors.count, 2)
        XCTAssertNil(cursors[0])
        XCTAssertEqual(cursors[1], all[SocialPaging.downloads - 1].postedAt, "the next page starts before the last row's posted_at")
    }

    func testALivePhotoSavesItsMotionToo() async {
        let data = SocialDemo.makeData()
        let mine = items(2)
        data.update { $0.downloads = mine }
        let saver = RecordingPhotoSaver()
        let model = makeModel(data, saver: saver, store: store())
        await model.load()
        await model.start()?.value
        XCTAssertEqual(saver.savedCount, 2)
        XCTAssertEqual(saver.lastMotionURL?.lastPathComponent, "motion.mov", "the oldest (last saved) is the Live Photo")
    }

    func testAFailureStopsAndContinueGoesOnFromTheLastSavedPhoto() async {
        let data = SocialDemo.makeData()
        let all = items(4)
        data.update { $0.downloads = all }
        let cursors = store()
        let saver = RecordingPhotoSaver()
        let model = makeModel(data, saver: saver, store: cursors)
        await model.load()
        // The first page read fails: nothing is saved, the error line shows.
        data.update { $0.failOnce.insert("downloadItems") }
        await model.start()?.value
        XCTAssertEqual(model.phase, .failed)
        XCTAssertFalse(model.canResume, "nothing was saved: Download again")
        XCTAssertEqual(model.signals.feedback?.kind, .failed)

        // A file fails after two saves: the place is kept.
        data.update { $0.downloads = all }
        let failing = FailingAfterSaver(after: 2)
        let interrupted = makeModel(data, saver: failing, store: cursors)
        await interrupted.load()
        await interrupted.start()?.value
        XCTAssertEqual(interrupted.phase, .failed)
        XCTAssertTrue(interrupted.canResume, "Continue")

        // Reopened: it goes on before the last saved photo.
        let reopened = makeModel(data, saver: saver, store: cursors)
        await reopened.load()
        XCTAssertTrue(reopened.canResume)
        let before = saver.savedCount
        await reopened.start()?.value
        XCTAssertEqual(reopened.phase, .done)
        XCTAssertEqual(saver.savedCount - before, 2, "only the photos not saved yet")
        XCTAssertEqual(data.read { $0.downloadCalls.last?.before }, all[1].postedAt)
        XCTAssertFalse(reopened.canResume, "done: the place is forgotten")
    }

    func testCancelStopsAndKeepsThePlace() async {
        let data = SocialDemo.makeData()
        let mine = items(3)
        data.update { $0.downloads = mine }
        let cursors = store()
        let saver = CancellingSaver()
        let model = makeModel(data, saver: saver, store: cursors)
        saver.onSave = { [weak model] in model?.cancel() }
        await model.load()
        await model.start()?.value
        XCTAssertEqual(model.phase, .idle)
        XCTAssertTrue(model.canResume, "the photo being saved finished; Continue goes on after it")
        XCTAssertEqual(saver.savedCount, 1)
    }

    func testDeniedPhotoAccessShowsTheAlert() async {
        let data = SocialDemo.makeData()
        let mine = items(2)
        data.update { $0.downloads = mine }
        let model = makeModel(data, saver: RecordingPhotoSaver(denied: true), store: store())
        await model.load()
        await model.start()?.value
        XCTAssertTrue(model.saveDenied)
        XCTAssertEqual(model.phase, .idle)
        XCTAssertEqual(model.signals.feedback?.kind, .failed)
    }

    func testNothingToDownloadAndOffline() async {
        let data = SocialDemo.makeData()
        let empty = makeModel(data, store: store())
        await empty.load()
        await empty.start()?.value
        XCTAssertEqual(empty.phase, .empty)

        let mine = items(1)
        data.update { $0.downloads = mine }
        data.setNetwork(.offline)
        let offline = makeModel(data, store: store("offline"))
        await offline.load()
        await offline.start()?.value
        XCTAssertEqual(offline.phase, .offline)
    }

    func testAnAlbumSavesInAlbumOrderWithABarAndResumes() async {
        let data = SocialDemo.makeData()
        let album = AlbumID("00000000-0000-4000-8000-0000000a1b01")
        let rows = items(3)
        data.update { $0.albumDownloads[album] = rows }
        let cursors = store()
        let failing = FailingAfterSaver(after: 1)
        let model = makeModel(data, scope: .album(album), saver: failing, store: cursors)
        await model.load()
        await model.start()?.value
        XCTAssertEqual(model.phase, .failed)
        XCTAssertEqual(model.fraction ?? 0, 1.0 / 3.0, accuracy: 0.0001, "a bar without figures")

        let saver = RecordingPhotoSaver()
        let reopened = makeModel(data, scope: .album(album), saver: saver, store: cursors)
        await reopened.load()
        XCTAssertTrue(reopened.canResume)
        await reopened.start()?.value
        XCTAssertEqual(reopened.phase, .done)
        XCTAssertEqual(saver.savedCount, 2, "the rows after the last saved one")
        XCTAssertEqual(reopened.fraction ?? 0, 1, accuracy: 0.0001)
    }

    func testAnAlbumWithoutPremiumAsksForThePaywall() async {
        let data = SocialDemo.makeData()
        let album = AlbumID("00000000-0000-4000-8000-0000000a1b02")
        let row = items(1)
        data.update { state in
            state.albumDownloads[album] = row
            state.downloadsNeedPremium = true
        }
        let saver = RecordingPhotoSaver()
        let model = makeModel(data, scope: .album(album), saver: saver, store: store())
        await model.load()
        await model.start()?.value
        XCTAssertEqual(model.paywallRequests, 1)
        XCTAssertEqual(model.phase, .idle)
        XCTAssertEqual(saver.savedCount, 0)
    }

    func testCursorsAreKeptPerAccountAndScope() {
        let me = UserID("00000000-0000-4000-8000-000000000001")
        let album = AlbumID("00000000-0000-4000-8000-0000000a1b03")
        XCTAssertNotEqual(DownloadCursorStore.key(scope: .mine, user: me), DownloadCursorStore.key(scope: .album(album), user: me))
        XCTAssertNotEqual(DownloadCursorStore.key(scope: .mine, user: me), DownloadCursorStore.key(scope: .mine, user: nil))
    }
}

/// Saves `after` photos, then fails like a dropped download.
private final class FailingAfterSaver: SocialPhotoSaving, @unchecked Sendable {
    private let lock = NSLock()
    private var saved = 0
    let after: Int

    init(after: Int) {
        self.after = after
    }

    func save(kind: MediaKind, fileURL: URL, motionURL: URL?) async throws {
        lock.lock()
        defer { lock.unlock() }
        guard saved < after else { throw DataError.http(status: 500) }
        saved += 1
    }
}

/// Saves, then runs `onSave` (the test cancels from it, as Cancel during a save does).
@MainActor
private final class CancellingSaver: SocialPhotoSaving {
    var onSave: (() -> Void)?
    private(set) var savedCount = 0

    nonisolated func save(kind: MediaKind, fileURL: URL, motionURL: URL?) async throws {
        await record()
    }

    private func record() {
        savedCount += 1
        onSave?()
    }
}
