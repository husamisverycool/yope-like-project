// walls.mine / walls.member / walls.browse view models (design/surfaces/walls.*.md).
@testable import App
import AppData
import AppModels
import Foundation
import XCTest

@MainActor
final class SocialWallModelTests: XCTestCase {
    private let utc = TimeZone(identifier: "UTC")!
    /// Friday 16 Oct 2026, 09:00 UTC: the demo's current week starts Monday 12 Oct.
    private let friday: @Sendable () -> Date = { SocialDemo.monday.addingTimeInterval(4 * SocialDemo.day) }

    private func wall(_ owner: WallModel.Owner, _ data: FakeSocialData = SocialDemo.makeData()) -> WallModel {
        WallModel(owner: owner, data: data, timeZone: utc, now: friday)
    }

    func testMyWallIsNewestFirstAndOnePerPhoto() async {
        let model = wall(.me)
        await model.load()
        XCTAssertEqual(model.phase, .ready)
        XCTAssertEqual(model.photoPostIDs, [SocialDemo.p3, SocialDemo.p6], "p3 was sent to two groups: one tile")
    }

    func testWeeksStartWithTheCurrentWeekAndListItsEmptyDays() async {
        let model = wall(.me)
        await model.load()
        XCTAssertEqual(model.currentWeekStart, SocialDemo.thisWeek)
        XCTAssertEqual(model.currentWeekNumber, 42)
        XCTAssertEqual(model.weeks.map(\.weekStart), [SocialDemo.thisWeek, SocialDemo.lastWeek])
        XCTAssertEqual(model.weeks.map(\.isCurrent), [true, false])
        XCTAssertEqual(model.weeks.map { $0.tiles.map(\.id) }, [["p" + SocialDemo.p3.rawValue], ["p" + SocialDemo.p6.rawValue]])
        let current = model.weeks[0]
        XCTAssertEqual(model.emptyDays(of: current), [12, 13, 15, 16, 17, 18].map { LocalDate(year: 2026, month: 10, day: $0)! }, "Wednesday has a photo")
        XCTAssertTrue(model.emptyDays(of: model.weeks[1]).isEmpty, "past weeks show their photos only")
    }

    func testAWallWithoutPhotosThisWeekStillShowsTheCurrentWeek() async {
        let data = SocialDemo.makeData()
        data.update { state in state.posts.removeAll { $0.id == SocialDemo.p3 || $0.id == SocialDemo.p3b } }
        let model = wall(.me, data)
        await model.load()
        XCTAssertEqual(model.weeks.map(\.weekStart), [SocialDemo.thisWeek, SocialDemo.lastWeek])
        XCTAssertTrue(model.weeks[0].tiles.isEmpty)
        XCTAssertEqual(model.emptyDays(of: model.weeks[0]).count, 7)
    }

    func testTilesInsideAWeekAreInTimeOrder() async {
        let data = SocialDemo.makeData()
        let early = PostID("00000000-0000-4000-8000-00000000c021")
        data.update { state in
            state.posts.append(SocialDemo.post(early, by: SocialDemo.me, at: SocialDemo.monday.addingTimeInterval(SocialDemo.hour)))
        }
        let model = wall(.me, data)
        await model.load()
        XCTAssertEqual(model.weeks[0].tiles.map(\.id), ["p" + early.rawValue, "p" + SocialDemo.p3.rawValue], "Monday before Wednesday")
        XCTAssertEqual(model.photoPostIDs, [early, SocialDemo.p3, SocialDemo.p6], "the viewer moves in the wall's order")
    }

    func testMemberWallAndEmptyWall() async {
        let model = wall(.member(SocialDemo.ana))
        await model.load()
        XCTAssertEqual(model.photoPostIDs, [SocialDemo.p2, SocialDemo.p5])
        XCTAssertEqual(model.displayName, "Ana Lima")

        let stranger = wall(.member(SocialDemo.stranger))
        await stranger.load()
        XCTAssertEqual(stranger.phase, .empty, "no shared group, a block or no pics: the empty state")
    }

    func testBlockingEmptiesTheWall() async {
        let model = wall(.member(SocialDemo.ana))
        await model.load()
        model.blocked()
        XCTAssertEqual(model.phase, .empty)
        XCTAssertTrue(model.photoPostIDs.isEmpty)
        XCTAssertFalse(model.hasMore)
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
        let model = wall(.me, data)
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
        let model = wall(.me, data)
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
        let model = wall(.me, data)
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
        let model = wall(.me)
        await model.load()
        // The other group's post of the same photo: matched by media id.
        model.handle(.postDeleted(postID: SocialDemo.p3b, mediaID: SocialDemo.mediaID(SocialDemo.p3)))
        XCTAssertEqual(model.photoPostIDs, [SocialDemo.p6])
        model.handle(.postDeleted(postID: SocialDemo.p6, mediaID: nil))
        XCTAssertEqual(model.phase, .empty)
    }

    func testBrowseListsEveryoneElseByName() async {
        let model = WallsBrowseModel(data: SocialDemo.makeData(), locale: Locale(identifier: "en_US"))
        await model.load()
        XCTAssertEqual(model.phase, .ready)
        // walls.browse.layout.rowOrder: display name A to Z (Apple Photos' people grid "Sort by Name"); never me.
        XCTAssertEqual(model.people.map(\.id), [SocialDemo.ana, SocialDemo.ben, SocialDemo.cleo])
        XCTAssertEqual(model.people.map(\.name), ["Ana Lima", "Ben Ortiz", "Cleo Park"])
    }

    func testPeopleOrderIgnoresCaseAndAccentsAndBreaksTiesByID() {
        struct Named { let id: String; let name: String }
        let people = [Named(id: "4", name: "zoë"), Named(id: "3", name: "Émile"), Named(id: "2", name: "ana"), Named(id: "1", name: "Ana"), Named(id: "5", name: "Bea")]
        let ordered = SocialOrdering.byName(people, name: \.name, id: \.id, locale: Locale(identifier: "en_US"))
        XCTAssertEqual(ordered.map(\.id), ["1", "2", "5", "3", "4"], "same comparison as Android's Collator at PRIMARY strength")
    }

    func testBrowseSearchFiltersByName() async {
        let model = WallsBrowseModel(data: SocialDemo.makeData())
        await model.load()
        model.search = "  an "
        XCTAssertEqual(model.visiblePeople.map(\.id), [SocialDemo.ana], "case-insensitive, trimmed")
        model.search = "o"
        XCTAssertEqual(model.visiblePeople.map(\.id), [SocialDemo.ben, SocialDemo.cleo])
        model.search = "zed"
        XCTAssertTrue(model.visiblePeople.isEmpty, "no search results")
        XCTAssertEqual(model.phase, .ready)
        model.search = ""
        XCTAssertEqual(model.visiblePeople.count, 3)
    }

    func testBrowseScopedToOneGroup() async {
        let model = WallsBrowseModel(data: SocialDemo.makeData(), groupID: SocialDemo.otherGroupID)
        await model.load()
        XCTAssertEqual(model.people.map(\.id), [SocialDemo.ben])
    }

    func testBrowseWithNobodyElse() async {
        let data = FakeSocialData(me: SocialDemo.me)
        data.update { $0.profiles[SocialDemo.me] = SocialDemo.profiles[0] }
        let model = WallsBrowseModel(data: data)
        await model.load()
        XCTAssertEqual(model.phase, .empty)
        XCTAssertTrue(model.people.isEmpty)
    }

    func testBrowseShowsCachedPeopleFirstThenRefreshesInPlace() async {
        let data = SocialDemo.makeData()
        data.update { state in
            state.holds.insert("myGroups")
            state.cachedGroups = state.groups.filter { $0.id == SocialDemo.otherGroupID }
            state.cachedMembers[SocialDemo.otherGroupID] = state.members[SocialDemo.otherGroupID]
        }
        let model = WallsBrowseModel(data: data, locale: Locale(identifier: "en_US"))
        XCTAssertFalse(model.showsLoading)
        let task = Task { await model.load() }
        let cachedReady = await socialEventually { model.phase == .ready }
        XCTAssertTrue(cachedReady, "the cached people show while the server is asked")
        XCTAssertFalse(model.showsLoading, "no indicator over cached content")
        XCTAssertEqual(model.people.map(\.id), [SocialDemo.ben])

        data.update { $0.holds.remove("myGroups") }
        await task.value
        // Refreshed in place, in walls.browse.layout.rowOrder: display name A to Z.
        XCTAssertEqual(model.people.map(\.name), ["Ana Lima", "Ben Ortiz", "Cleo Park"])
        XCTAssertEqual(model.people.map(\.id), [SocialDemo.ana, SocialDemo.ben, SocialDemo.cleo])
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
        XCTAssertEqual(Set(model.people.map(\.id)), [SocialDemo.ana, SocialDemo.ben, SocialDemo.cleo])

        let nothing = SocialDemo.makeData()
        nothing.update { $0.mode = .offline }
        let empty = WallsBrowseModel(data: nothing)
        await empty.load()
        XCTAssertEqual(empty.phase, .offline)

        let failing = SocialDemo.makeData()
        failing.update { $0.mode = .failing }
        let failed = WallsBrowseModel(data: failing)
        await failed.load()
        XCTAssertEqual(failed.phase, .failed)
    }

    func testLoadingIndicatorOnlyWithoutACachedCopy() async {
        let data = SocialDemo.makeData()
        data.update { $0.holds.insert("wall") }
        let model = wall(.me, data)
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
