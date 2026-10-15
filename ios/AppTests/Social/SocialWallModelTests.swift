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

    func testBrowseShowsCachedPeopleFirstThenRefreshesInPlace() async {
        let data = SocialDemo.makeData()
        data.update { state in
            state.holds.insert("myGroups")
            state.cachedGroups = state.groups.filter { $0.id == SocialDemo.otherGroupID }
            state.cachedMembers[SocialDemo.otherGroupID] = state.members[SocialDemo.otherGroupID]
        }
        let model = WallsBrowseModel(data: data)
        XCTAssertFalse(model.showsLoading)
        let task = Task { await model.load() }
        let cachedReady = await socialEventually { model.phase == .ready }
        XCTAssertTrue(cachedReady, "the cached people show while the server is asked")
        XCTAssertFalse(model.showsLoading, "no indicator over cached content")
        XCTAssertEqual(model.people.map(\.id), [SocialDemo.me, SocialDemo.ben])
        XCTAssertEqual(model.selectedID, SocialDemo.me)

        data.update { $0.holds.remove("myGroups") }
        await task.value
        XCTAssertEqual(model.people.map(\.id), [SocialDemo.me, SocialDemo.cleo, SocialDemo.ana, SocialDemo.ben])
        XCTAssertEqual(model.selectedID, SocialDemo.me, "the selection survives the refresh")
        XCTAssertNil(model.signals.feedback)
    }

    func testBrowseOfflineKeepsTheCachedPeople() async {
        let data = SocialDemo.makeData()
        data.update { state in
            state.cachedGroups = state.groups
            for group in state.groups { state.cachedMembers[group.id] = state.members[group.id] }
        }
        data.update { $0.mode = .offline }
        let model = WallsBrowseModel(data: data)
        await model.load()
        XCTAssertEqual(model.phase, .ready)
        XCTAssertTrue(model.isOffline)
        XCTAssertEqual(model.people.first?.id, SocialDemo.me)
        XCTAssertEqual(Set(model.people.map(\.id)), [SocialDemo.me, SocialDemo.ana, SocialDemo.ben, SocialDemo.cleo])

        let nothing = SocialDemo.makeData()
        nothing.update { $0.mode = .offline }
        let empty = WallsBrowseModel(data: nothing)
        await empty.load()
        XCTAssertEqual(empty.phase, .offline)
    }

    func testLoadingIndicatorOnlyWithoutACachedCopy() async {
        let data = SocialDemo.makeData()
        data.update { $0.holds.insert("wall") }
        let model = WallModel(owner: .me, data: data)
        XCTAssertFalse(model.showsLoading)
        let task = Task { await model.load() }
        let shown = await socialEventually { model.showsLoading }
        XCTAssertTrue(shown, "nothing cached: the indicator shows while the wall loads")
        task.cancel()

        let cached = SocialDemo.makeData()
        cached.update { state in
            state.holds.insert("wall")
            state.cachedWalls[SocialDemo.me] = [
                WallItem(itemKind: .post, postID: SocialDemo.p6, mediaID: SocialDemo.mediaID(SocialDemo.p6), collageID: nil,
                         groupIDs: [SocialDemo.groupID], createdAt: SocialDemo.monday),
            ]
        }
        let fromCache = WallModel(owner: .me, data: cached)
        let second = Task { await fromCache.load() }
        let ready = await socialEventually { fromCache.phase == .ready }
        XCTAssertTrue(ready, "the cached grid shows at once")
        XCTAssertFalse(fromCache.showsLoading, "no indicator flashes before cached content")
        second.cancel()
        _ = await second.value
    }
}
