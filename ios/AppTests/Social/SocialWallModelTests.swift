// walls.mine / walls.member / walls.browse view models (design/surfaces/walls.*.md).
@testable import App
import AppData
import AppModels
import Foundation
import XCTest

@MainActor
final class SocialWallModelTests: XCTestCase {
    func testMyWallIsNewestFirstAndOnePerPhoto() async {
        let model = WallModel(owner: .me, data: SocialDemo.makeData())
        await model.load()
        XCTAssertEqual(model.phase, .ready)
        XCTAssertEqual(model.photoPostIDs, [SocialDemo.p3, SocialDemo.p6], "p3 was sent to two groups: one tile")
    }

    func testMemberWallAndEmptyWall() async {
        let model = WallModel(owner: .member(SocialDemo.ana), data: SocialDemo.makeData())
        await model.load()
        XCTAssertEqual(model.photoPostIDs, [SocialDemo.p2, SocialDemo.p5])
        XCTAssertEqual(model.displayName, "Ana Lima")

        let stranger = WallModel(owner: .member(SocialDemo.stranger), data: SocialDemo.makeData())
        await stranger.load()
        XCTAssertEqual(stranger.phase, .empty, "no shared group, a block or no pics: the empty state")
    }

    func testPagingByFifty() async {
        let data = SocialDemo.makeData()
        data.update { state in
            state.walls[SocialDemo.me] = (0..<60).map { index in
                let id = PostID("00000000-0000-4000-8000-0000001" + String(10_000 + index).suffix(5))
                state.posts.append(SocialDemo.post(id, by: SocialDemo.me, at: SocialDemo.monday.addingTimeInterval(-Double(index) * 60)))
                return WallItem(itemKind: .post, postID: id, mediaID: SocialDemo.mediaID(id), collageID: nil, groupIDs: [SocialDemo.groupID],
                                createdAt: SocialDemo.monday.addingTimeInterval(-Double(index) * 60))
            }
        }
        let model = WallModel(owner: .me, data: data)
        await model.load()
        XCTAssertEqual(model.tiles.count, 50)
        XCTAssertTrue(model.hasMore)
        await model.loadMore()
        XCTAssertEqual(model.tiles.count, 60)
        XCTAssertFalse(model.hasMore)
    }

    func testCollagesShowOnlyWhenReady() async {
        let data = SocialDemo.makeData()
        let ready = CollageID("00000000-0000-4000-8000-00000000aa01")
        let pending = CollageID("00000000-0000-4000-8000-00000000aa02")
        data.update { state in
            state.collages = [
                Collage(id: ready, groupID: SocialDemo.groupID, invitationID: nil, option: "A", postIDs: [SocialDemo.p3], imagePath: "fake/collage/1",
                        widgetPath: nil, sharePath: nil, status: .ready, composedAt: SocialDemo.monday, createdAt: SocialDemo.monday),
                Collage(id: pending, groupID: SocialDemo.groupID, invitationID: nil, option: "A", postIDs: [SocialDemo.p3], imagePath: nil,
                        widgetPath: nil, sharePath: nil, status: .pending, composedAt: nil, createdAt: SocialDemo.monday),
            ]
            state.walls[SocialDemo.me] = [
                WallItem(itemKind: .collage, postID: nil, mediaID: nil, collageID: pending, groupIDs: [SocialDemo.groupID], createdAt: SocialDemo.monday),
                WallItem(itemKind: .collage, postID: nil, mediaID: nil, collageID: ready, groupIDs: [SocialDemo.groupID], createdAt: SocialDemo.monday),
            ]
        }
        let model = WallModel(owner: .me, data: data)
        await model.load()
        XCTAssertEqual(model.tiles.map(\.id), ["c" + ready.rawValue])
    }

    func testOfflineShowsTheCachedWallAndErrorStates() async {
        let data = SocialDemo.makeData()
        data.update { state in
            state.mode = .offline
            state.cachedWalls[SocialDemo.me] = [
                WallItem(itemKind: .post, postID: SocialDemo.p3, mediaID: SocialDemo.mediaID(SocialDemo.p3), collageID: nil,
                         groupIDs: [SocialDemo.groupID], createdAt: SocialDemo.monday),
            ]
        }
        let model = WallModel(owner: .me, data: data)
        await model.load()
        XCTAssertTrue(model.isOffline)
        XCTAssertEqual(model.items.count, 1, "cached grid stays")

        let nothing = SocialDemo.makeData()
        nothing.update { $0.mode = .offline }
        let offline = WallModel(owner: .me, data: nothing)
        await offline.load()
        XCTAssertEqual(offline.phase, .offline)

        let failing = SocialDemo.makeData()
        failing.update { $0.mode = .failing }
        let failed = WallModel(owner: .me, data: failing)
        await failed.load()
        XCTAssertEqual(failed.phase, .failed)
    }

    func testPostDeletedDropsEveryTileOfThatPhoto() async {
        let model = WallModel(owner: .me, data: SocialDemo.makeData())
        await model.load()
        // The other group's post of the same photo: matched by media id.
        model.handle(.postDeleted(postID: SocialDemo.p3b, mediaID: SocialDemo.mediaID(SocialDemo.p3)))
        XCTAssertEqual(model.photoPostIDs, [SocialDemo.p6])
        model.handle(.postDeleted(postID: SocialDemo.p6, mediaID: nil))
        XCTAssertEqual(model.phase, .empty)
    }

    func testBrowseListsMeFirstThenNewestWallFirst() async {
        let model = WallsBrowseModel(data: SocialDemo.makeData())
        await model.load()
        XCTAssertEqual(model.phase, .ready)
        // Newest wall items: Cleo (Thu), Ana (Tue), Ben (Mon).
        XCTAssertEqual(model.people.map(\.id), [SocialDemo.me, SocialDemo.cleo, SocialDemo.ana, SocialDemo.ben])
        XCTAssertEqual(model.selectedID, SocialDemo.me)
        XCTAssertEqual(model.selectedWall?.owner, .me)
        XCTAssertNil(model.signals.feedback, "the initial selection plays no haptic")

        await model.select(SocialDemo.ana)
        XCTAssertEqual(model.signals.feedback?.kind, .select)
        XCTAssertEqual(model.selectedWall?.photoPostIDs, [SocialDemo.p2, SocialDemo.p5])
    }

    func testBrowseScopedToOneGroup() async {
        let model = WallsBrowseModel(data: SocialDemo.makeData(), groupID: SocialDemo.otherGroupID)
        await model.load()
        XCTAssertEqual(model.people.map(\.id), [SocialDemo.me, SocialDemo.ben])
    }

    func testBrowseWithNobodyElse() async {
        let data = FakeSocialData(me: SocialDemo.me)
        data.update { $0.profiles[SocialDemo.me] = SocialDemo.profiles[0] }
        let model = WallsBrowseModel(data: data)
        await model.load()
        XCTAssertTrue(model.hasNobodyElse)
        XCTAssertEqual(model.people.map(\.id), [SocialDemo.me])
    }
}
