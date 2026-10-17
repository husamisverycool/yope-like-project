// Private favorites, a photo as the group cover and albums anyone can add to (owner decision 34; research #19, #14,
// #10): the viewer's menu items, the favorites grid, the album picker, the add sheet and removing from an album.
// Specs: design/surfaces/photo.viewer.md, favorites.md, albums.view.md.
@testable import App
import AppData
import AppModels
import DesignSystem
import Foundation
import XCTest

@MainActor
final class SocialFavoritesAndAlbumAddTests: XCTestCase {
    private func viewer(_ data: FakeSocialData, start: PostID = SocialDemo.p2) -> PhotoViewerModel {
        PhotoViewerModel(
            context: PhotoViewerContext(postIDs: [SocialDemo.p1, SocialDemo.p2, SocialDemo.p3], start: start, groupID: SocialDemo.groupID),
            data: data
        )
    }

    private func makeMeAdmin(_ data: FakeSocialData) {
        data.update { state in
            state.members[SocialDemo.groupID] = state.members[SocialDemo.groupID]?.map { member in
                var member = member
                if member.member.userID == SocialDemo.me { member.member.role = .admin }
                return member
            }
        }
    }

    // MARK: Favorites (viewer)

    func testFavoriteTogglesAtOnceAndOnlyForMe() async {
        let data = SocialDemo.makeData()
        let model = viewer(data)
        await model.load()
        XCTAssertFalse(model.isCurrentFavorite)
        await model.toggleFavorite()
        XCTAssertTrue(model.isCurrentFavorite, "Unfavorite is offered now")
        XCTAssertNotNil(data.read { $0.favorites[SocialDemo.mediaID(SocialDemo.p2)] })
        XCTAssertEqual(model.signals.feedback?.kind, .select)
        await model.toggleFavorite()
        XCTAssertFalse(model.isCurrentFavorite)
        XCTAssertNil(data.read { $0.favorites[SocialDemo.mediaID(SocialDemo.p2)] })
    }

    func testFavoritesShowFromMyOwnRows() async {
        let data = SocialDemo.makeData()
        data.update { $0.favorites[SocialDemo.mediaID(SocialDemo.p3)] = SocialDemo.monday }
        let model = viewer(data, start: SocialDemo.p3)
        await model.load()
        XCTAssertTrue(model.isCurrentFavorite)
        model.show(SocialDemo.p2)
        XCTAssertFalse(model.isCurrentFavorite)
    }

    func testFailedFavoriteGoesBack() async {
        let data = SocialDemo.makeData()
        data.update { $0.failOnce = ["setFavorite"] }
        let model = viewer(data)
        await model.load()
        await model.toggleFavorite()
        XCTAssertFalse(model.isCurrentFavorite, "the heart goes back")
        XCTAssertEqual(model.signals.notice?.notice, .favoriteFailed)
        XCTAssertEqual(model.signals.feedback?.kind, .failed)
        XCTAssertEqual(SocialNotice.favoriteFailed.text, Copy.photoViewerErrorFavorite)
    }

    // MARK: Use as Cover (viewer)

    func testUseAsCoverIsForGroupAdminsOnly() async {
        let member = viewer(SocialDemo.makeData())
        await member.load()
        XCTAssertFalse(member.canUseCurrentAsCover, "I am not an admin of roommates")
        await member.useCurrentAsCover()
        XCTAssertNil(member.signals.notice)

        let data = SocialDemo.makeData()
        makeMeAdmin(data)
        let admin = viewer(data)
        await admin.load()
        XCTAssertTrue(admin.canUseCurrentAsCover)
        await admin.useCurrentAsCover()
        XCTAssertEqual(data.read { $0.coverPosts[SocialDemo.groupID] }, SocialDemo.p2)
        XCTAssertEqual(admin.signals.notice?.notice, .coverSet)
        XCTAssertEqual(SocialNotice.coverSet.text, Copy.weekEditToastSaved)
    }

    func testCoverOfAPhotoStillProcessingSaysSo() async {
        let data = SocialDemo.makeData()
        makeMeAdmin(data)
        data.update { $0.renditionsPending = [SocialDemo.p2] }
        let model = viewer(data)
        await model.load()
        await model.useCurrentAsCover()
        XCTAssertEqual(model.signals.notice?.notice, .coverNotReady)
        XCTAssertNil(data.read { $0.coverPosts[SocialDemo.groupID] })

        data.update { $0.renditionsPending = []; $0.failOnce = ["setGroupCover"] }
        await model.useCurrentAsCover()
        XCTAssertEqual(model.signals.notice?.notice, .coverFailed)
    }

    // MARK: The favorites grid

    func testFavoritesNewestFirstOnePerPhoto() async {
        let data = SocialDemo.makeData()
        data.update { state in
            state.favorites[SocialDemo.mediaID(SocialDemo.p1)] = SocialDemo.at(1 * SocialDemo.hour)
            state.favorites[SocialDemo.mediaID(SocialDemo.p3)] = SocialDemo.at(2 * SocialDemo.hour)
        }
        let model = FavoritesModel(data: data)
        await model.load()
        XCTAssertEqual(model.phase, .ready)
        XCTAssertEqual(model.items.map(\.postID), [SocialDemo.p3, SocialDemo.p1], "newest favorite first; p3 and p3b are one photo")
        XCTAssertEqual(model.items.first?.groupName, "roommates")
        let context = model.viewerContext(start: SocialDemo.p1)
        XCTAssertEqual(context.postIDs, [SocialDemo.p3, SocialDemo.p1])
        XCTAssertTrue(context.showsGroupName, "the header names each photo's group, as from a wall")
        XCTAssertEqual(model.profiles[SocialDemo.ben]?.socialFirstName, "Ben", "cell labels name the author")
    }

    func testFavoritesStates() async {
        let empty = FavoritesModel(data: SocialDemo.makeData())
        await empty.load()
        XCTAssertEqual(empty.phase, .empty)

        let failingData = SocialDemo.makeData()
        failingData.update { $0.mode = .failing }
        let failing = FavoritesModel(data: failingData)
        await failing.load()
        XCTAssertEqual(failing.phase, .failed)

        let offlineData = SocialDemo.makeData()
        offlineData.update { $0.mode = .offline }
        let offline = FavoritesModel(data: offlineData)
        await offline.load()
        XCTAssertEqual(offline.phase, .offline)
        XCTAssertTrue(offline.isOffline)
    }

    // MARK: Album picker (viewer)

    func testAlbumPickerAddsThePhoto() async {
        let data = SocialDemo.makeData()
        let model = AlbumPickerModel(groupID: SocialDemo.groupID, postID: SocialDemo.p4, data: data)
        await model.load()
        XCTAssertEqual(model.phase, .ready)
        XCTAssertEqual(model.albums.map(\.album.name), ["weekend"])
        XCTAssertEqual(model.savedByName(model.albums[0]), "Ana")
        await model.add(to: model.albums[0])
        XCTAssertTrue(model.isDone)
        let album = data.read { $0.albums.first { $0.album.id == SocialDemo.albumID } }
        XCTAssertEqual(album?.postIDs, [SocialDemo.p1, SocialDemo.p2, SocialDemo.p4], "after the album's last item")
        XCTAssertEqual(album?.adder(of: SocialDemo.p4), SocialDemo.me)
    }

    func testAlbumPickerNewAlbumNeedsAName() async {
        let data = SocialDemo.makeData()
        let model = AlbumPickerModel(groupID: SocialDemo.groupID, postID: SocialDemo.p4, data: data)
        await model.load()
        model.startNaming()
        model.newName = "  "
        await model.createAlbum()
        XCTAssertTrue(model.nameMissing)
        XCTAssertFalse(model.isDone)
        model.newName = "cleo's best"
        await model.createAlbum()
        XCTAssertTrue(model.isDone)
        XCTAssertFalse(model.isNaming)
        XCTAssertEqual(data.read { $0.albums.first { $0.album.name == "cleo's best" }?.postIDs }, [SocialDemo.p4])
    }

    func testAlbumPickerFailureKeepsTheSheet() async {
        let data = SocialDemo.makeData()
        let model = AlbumPickerModel(groupID: SocialDemo.groupID, postID: SocialDemo.p4, data: data)
        await model.load()
        data.update { $0.failOnce = ["addToAlbum"] }
        await model.add(to: model.albums[0])
        XCTAssertFalse(model.isDone)
        XCTAssertEqual(model.signals.notice?.notice, .changesFailed)

        let offlineData = SocialDemo.makeData()
        offlineData.update { $0.mode = .offline }
        let offline = AlbumPickerModel(groupID: SocialDemo.groupID, postID: SocialDemo.p4, data: offlineData)
        await offline.load()
        XCTAssertEqual(offline.phase, .offline, "nothing cached: the error line under New Album")
    }

    // MARK: albums.view: add and remove

    func testAddSheetOffersPhotosTheAlbumLacks() async {
        let data = SocialDemo.makeData()
        let model = AlbumAddModel(groupID: SocialDemo.groupID, albumID: SocialDemo.albumID, excluding: [SocialDemo.p1, SocialDemo.p2], data: data)
        await model.load()
        XCTAssertEqual(model.phase, .ready)
        let shown = model.posts.map(\.id)
        XCTAssertFalse(shown.contains(SocialDemo.p1))
        XCTAssertFalse(shown.contains(SocialDemo.p2))
        XCTAssertTrue(shown.contains(SocialDemo.p3))
        XCTAssertFalse(shown.contains(SocialDemo.p3b), "only the album's group")
        XCTAssertFalse(model.canAdd, "nothing picked yet")
        model.toggle(SocialDemo.p4)
        model.toggle(SocialDemo.p3)
        XCTAssertEqual(model.picked, [SocialDemo.p4, SocialDemo.p3])
        await model.add()
        XCTAssertTrue(model.isDone)
        XCTAssertEqual(data.read { $0.albums.first { $0.album.id == SocialDemo.albumID }?.postIDs },
                       [SocialDemo.p1, SocialDemo.p2, SocialDemo.p4, SocialDemo.p3], "in the order picked")
    }

    func testRemoveOnlyWhatIAddedUnlessCreatorOrAdmin() async {
        let data = SocialDemo.makeData()
        _ = try? await data.addToAlbum(id: SocialDemo.albumID, groupID: SocialDemo.groupID, postIDs: [SocialDemo.p3])
        let model = AlbumModel(groupID: SocialDemo.groupID, albumID: SocialDemo.albumID, data: data)
        await model.load()
        XCTAssertFalse(model.canDelete)
        XCTAssertFalse(model.canRemove(SocialDemo.p1), "Ana added it")
        XCTAssertTrue(model.canRemove(SocialDemo.p3), "I added it")
        await model.remove(SocialDemo.p1)
        XCTAssertEqual(model.postIDs, [SocialDemo.p1, SocialDemo.p2, SocialDemo.p3], "not offered, nothing happens")
        await model.remove(SocialDemo.p3)
        XCTAssertEqual(model.postIDs, [SocialDemo.p1, SocialDemo.p2])
        XCTAssertEqual(model.signals.notice?.notice, .albumPhotoRemoved)
        XCTAssertTrue(data.read { $0.posts.contains { $0.id == SocialDemo.p3 } }, "the photo stays in the group")

        let creatorData = SocialDemo.makeData()
        creatorData.update { $0.me = SocialDemo.ana }
        let creator = AlbumModel(groupID: SocialDemo.groupID, albumID: SocialDemo.albumID, data: creatorData)
        await creator.load()
        XCTAssertTrue(creator.canRemove(SocialDemo.p1))
    }

    func testRemoveRefusedPutsThePhotoBack() async {
        let data = SocialDemo.makeData()
        _ = try? await data.addToAlbum(id: SocialDemo.albumID, groupID: SocialDemo.groupID, postIDs: [SocialDemo.p3])
        let model = AlbumModel(groupID: SocialDemo.groupID, albumID: SocialDemo.albumID, data: data)
        await model.load()
        // Meanwhile the server's row says someone else added it.
        data.update { state in
            if let index = state.albums.firstIndex(where: { $0.album.id == SocialDemo.albumID }) {
                state.albums[index].addedBy?[SocialDemo.p3] = SocialDemo.ben
            }
        }
        await model.remove(SocialDemo.p3)
        XCTAssertEqual(model.postIDs, [SocialDemo.p1, SocialDemo.p2, SocialDemo.p3], "back in place")
        XCTAssertEqual(model.signals.notice?.notice, .removeNotAllowed)
        XCTAssertEqual(SocialNotice.removeNotAllowed.text, Copy.albumsViewErrorNotAllowed)
        XCTAssertTrue(SocialFailure.isNotAllowed(DataError.database(code: "PT403", message: "not_allowed")))
    }
}
