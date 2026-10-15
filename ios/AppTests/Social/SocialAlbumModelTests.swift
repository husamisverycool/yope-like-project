// albums.list / albums.view view models (design/surfaces/albums.*.md).
@testable import App
import AppData
import AppModels
import Foundation
import XCTest

@MainActor
final class SocialAlbumModelTests: XCTestCase {
    func testAlbumsListWithCoverAndSavedBy() async {
        let model = AlbumsListModel(groupID: SocialDemo.groupID, data: SocialDemo.makeData())
        await model.load()
        XCTAssertEqual(model.phase, .ready)
        let album = try! XCTUnwrap(model.albums.first)
        XCTAssertEqual(album.album.name, "weekend")
        XCTAssertEqual(model.cover(of: album)?.id, SocialDemo.p1)
        XCTAssertEqual(model.savedByName(album), "Ana")
    }

    func testAlbumsListStates() async {
        let empty = AlbumsListModel(groupID: SocialDemo.groupID, data: SocialDemo.makeEmptyData())
        await empty.load()
        XCTAssertEqual(empty.phase, .empty)

        let failingData = SocialDemo.makeData()
        failingData.update { $0.mode = .failing }
        let failing = AlbumsListModel(groupID: SocialDemo.groupID, data: failingData)
        await failing.load()
        XCTAssertEqual(failing.phase, .failed)

        let cachedData = SocialDemo.makeData()
        cachedData.update { state in
            state.mode = .offline
            state.cachedAlbums[SocialDemo.groupID] = SocialDemo.albums
        }
        let cached = AlbumsListModel(groupID: SocialDemo.groupID, data: cachedData)
        await cached.load()
        XCTAssertEqual(cached.phase, .ready)
        XCTAssertTrue(cached.isOffline)

        let offlineData = SocialDemo.makeData()
        offlineData.update { $0.mode = .offline }
        let offline = AlbumsListModel(groupID: SocialDemo.groupID, data: offlineData)
        await offline.load()
        XCTAssertEqual(offline.phase, .offline)
    }

    func testAlbumViewInPositionOrder() async {
        let model = AlbumModel(groupID: SocialDemo.groupID, albumID: SocialDemo.albumID, data: SocialDemo.makeData())
        await model.load()
        XCTAssertEqual(model.phase, .ready)
        XCTAssertEqual(model.postIDs, [SocialDemo.p1, SocialDemo.p2])
        XCTAssertEqual(model.album?.name, "weekend")
        XCTAssertFalse(model.canDelete, "Sam neither created the album nor is an admin")
    }

    func testCreatorOrAdminMayDelete() async {
        let data = SocialDemo.makeData()
        data.update { $0.me = SocialDemo.ana }
        let model = AlbumModel(groupID: SocialDemo.groupID, albumID: SocialDemo.albumID, data: data)
        await model.load()
        XCTAssertTrue(model.canDelete)
        await model.delete()
        XCTAssertTrue(model.isDeleted)
        XCTAssertTrue(data.read { $0.albums }.isEmpty)
        XCTAssertFalse(data.read { $0.posts }.isEmpty, "posts are never deleted with an album")
        XCTAssertEqual(model.signals.notice?.notice, .albumDeleted)
    }

    func testRenameNeedsAName() async {
        let data = SocialDemo.makeData()
        let model = AlbumModel(groupID: SocialDemo.groupID, albumID: SocialDemo.albumID, data: data)
        await model.load()
        model.startRename()
        XCTAssertEqual(model.renameText, "weekend")
        model.renameText = "   "
        await model.rename()
        XCTAssertTrue(model.renameMissing)
        model.renameText = "long weekend"
        await model.rename()
        XCTAssertEqual(model.album?.name, "long weekend")
        XCTAssertFalse(model.isRenaming)
        XCTAssertEqual(model.signals.notice?.notice, .albumRenamed)
    }

    func testMissingEmptiedAndFailingAlbums() async {
        let missing = AlbumModel(groupID: SocialDemo.groupID, albumID: AlbumID("00000000-0000-4000-8000-00000000e0ff"), data: SocialDemo.makeData())
        await missing.load()
        XCTAssertEqual(missing.phase, .notFound)

        let model = AlbumModel(groupID: SocialDemo.groupID, albumID: SocialDemo.albumID, data: SocialDemo.makeData())
        await model.load()
        model.handle(.postDeleted(postID: SocialDemo.p1, mediaID: nil))
        model.handle(.postDeleted(postID: SocialDemo.p2, mediaID: nil))
        XCTAssertEqual(model.phase, .empty)

        let failingData = SocialDemo.makeData()
        failingData.update { $0.mode = .failing }
        let failing = AlbumModel(groupID: SocialDemo.groupID, albumID: SocialDemo.albumID, data: failingData)
        await failing.load()
        XCTAssertEqual(failing.phase, .failed)

        let renameFails = SocialDemo.makeData()
        let renaming = AlbumModel(groupID: SocialDemo.groupID, albumID: SocialDemo.albumID, data: renameFails)
        await renaming.load()
        renameFails.update { $0.failOnce.insert("renameAlbum") }
        renaming.startRename()
        renaming.renameText = "x"
        await renaming.rename()
        XCTAssertEqual(renaming.signals.notice?.notice, .changesFailed)
        XCTAssertTrue(renaming.isRenaming)
    }
}
