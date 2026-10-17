// search.photos view model (design/surfaces/search.photos.md "States", "Data & actions") over the demo backend.
@testable import App
import AppData
import AppModels
import Foundation
import XCTest

@MainActor
final class SocialSearchModelTests: XCTestCase {
    private func model(_ data: FakeSocialData = SocialDemo.makeData(), group: GroupID? = SocialDemo.groupID) -> SearchPhotosModel {
        SearchPhotosModel(groupID: group, data: data)
    }

    func testNothingToSearchStaysIdleAndAsksNothing() async {
        let data = SocialDemo.makeData()
        let search = model(data)
        search.text = "   "
        await search.search()
        XCTAssertEqual(search.phase, .idle)
        XCTAssertTrue(data.read { $0.searches.isEmpty }, "search_photos refuses an empty search: it is never asked")
    }

    func testWordsMatchTheCaptionOrTheChatAboutAPhoto() async {
        let data = SocialDemo.makeData()
        let search = model(data)
        search.text = "Snow"
        await search.search()
        XCTAssertEqual(search.phase, .results)
        XCTAssertEqual(search.results.map(\.id), [SocialDemo.p2])
        XCTAssertEqual(search.hits.first?.matched, ["caption"])

        search.text = "pret"
        await search.search()
        XCTAssertEqual(search.results.map(\.id), [SocialDemo.p2], "Ben's reply 'so pretty' is about p2")
        XCTAssertEqual(search.hits.first?.matched, ["chat"])

        search.text = "first picnic"
        await search.search()
        XCTAssertEqual(search.phase, .empty, "every word must match")
        XCTAssertEqual(data.read { $0.searches.last?.query.groupID }, SocialDemo.groupID)
    }

    func testAMemberChipFindsTheirPhotosAndTheOnesTheyAreIn() async {
        let data = SocialDemo.makeData()
        data.update { $0.tags.append(SocialDemo.tag(SocialDemo.p1, SocialDemo.me, minutes: 70)) }
        let search = model(data)
        await search.toggle(member: SocialDemo.me)
        XCTAssertEqual(search.memberID, SocialDemo.me)
        XCTAssertEqual(search.results.map(\.id), [SocialDemo.p3, SocialDemo.p1, SocialDemo.p6], "newest first")
        XCTAssertEqual(search.hits.first { $0.postID == SocialDemo.p1 }?.matched, ["tag"])

        await search.toggle(member: SocialDemo.ana)
        XCTAssertEqual(search.memberID, SocialDemo.ana, "one member at a time")
        XCTAssertEqual(search.results.map(\.id), [SocialDemo.p2, SocialDemo.p5])

        await search.toggle(member: SocialDemo.ana)
        XCTAssertNil(search.memberID)
        XCTAssertEqual(search.phase, .idle, "the chosen chip again clears it")
    }

    func testAllGroupsShowEachPhotoOnceAndNameItsGroupInTheViewer() async {
        let data = SocialDemo.makeData()
        let everywhere = model(data, group: nil)
        await everywhere.toggle(member: SocialDemo.me)
        XCTAssertEqual(everywhere.results.map(\.id), [SocialDemo.p3, SocialDemo.p6], "p3's photo was also sent to climbing: one cell")
        let context = everywhere.viewer(start: SocialDemo.p6)
        XCTAssertEqual(context.postIDs, [SocialDemo.p3, SocialDemo.p6])
        XCTAssertTrue(context.showsGroupName)

        let climbing = model(data, group: SocialDemo.otherGroupID)
        await climbing.toggle(member: SocialDemo.me)
        XCTAssertEqual(climbing.results.map(\.id), [SocialDemo.p3b], "in one group, that group's post")
        XCTAssertFalse(climbing.viewer(start: SocialDemo.p3b).showsGroupName)
    }

    func testTheDateFilterIsOrderedAndCleared() async {
        let data = SocialDemo.makeData()
        let search = model(data)
        let tuesday = SocialDemo.thisWeek.adding(days: 1)
        await search.setDates(from: tuesday, to: tuesday)
        XCTAssertEqual(search.results.map(\.id), [SocialDemo.p2])
        XCTAssertEqual(search.hits.first?.matched, ["date"])

        await search.setDates(from: SocialDemo.thisWeek.adding(days: 6), to: SocialDemo.thisWeek)
        XCTAssertEqual(search.from, SocialDemo.thisWeek, "a reversed range is put in order")
        XCTAssertEqual(search.to, SocialDemo.thisWeek.adding(days: 6))
        XCTAssertEqual(search.results.map(\.id), [SocialDemo.p4, SocialDemo.p3, SocialDemo.p2, SocialDemo.p1])

        await search.clearDates()
        XCTAssertFalse(search.hasDates)
        XCTAssertEqual(search.phase, .idle)
    }

    func testClearingTheFieldGoesBackToIdle() async {
        let search = model()
        search.text = "snow"
        await search.search()
        XCTAssertEqual(search.phase, .results)
        search.text = ""
        search.textChanged()
        XCTAssertEqual(search.phase, .idle)
        XCTAssertTrue(search.results.isEmpty)
    }

    func testResultsPageWithTheLastCreatedAt() async {
        let data = SocialDemo.makeData()
        data.update { state in
            for n in 0..<61 {
                let id = PostID("00000000-0000-4000-8000-0000003" + String(10_000 + n).suffix(5))
                state.posts.append(SocialDemo.post(id, by: SocialDemo.ben, at: SocialDemo.monday.addingTimeInterval(-Double(n + 1) * 3 * SocialDemo.hour), caption: "beach day"))
            }
        }
        let search = model(data)
        search.text = "beach"
        await search.search()
        XCTAssertEqual(search.results.count, SocialPaging.search)
        XCTAssertTrue(search.hasMore)
        let last = search.hits.last?.createdAt
        search.text = "something else typed meanwhile"
        await search.loadMore()
        XCTAssertEqual(search.results.count, 61)
        XCTAssertFalse(search.hasMore)
        let second = data.read { $0.searches.last }
        XCTAssertEqual(second?.before, last)
        XCTAssertEqual(second?.query.trimmedText, "beach", "paging repeats the search the results answer")
    }

    func testErrorsAndOfflineThenRetry() async {
        let data = SocialDemo.makeData()
        data.update { $0.mode = .failing }
        let search = model(data)
        search.text = "snow"
        await search.search()
        XCTAssertEqual(search.phase, .error)

        data.update { $0.mode = .offline }
        await search.search()
        XCTAssertEqual(search.phase, .offline)

        data.update { $0.mode = .normal }
        await search.search()
        XCTAssertEqual(search.phase, .results)
    }

    func testMemberChipsPutYouFirstThenJoiningOrderEachPersonOnce() async {
        let one = model()
        await one.loadMembers()
        XCTAssertEqual(one.members.map(\.id), [SocialDemo.me, SocialDemo.ana, SocialDemo.ben, SocialDemo.cleo])
        XCTAssertEqual(one.members.first?.isMe, true)
        XCTAssertEqual(one.members[1].name, "Ana")

        let all = model(group: nil)
        await all.loadMembers()
        XCTAssertEqual(all.members.map(\.id), [SocialDemo.me, SocialDemo.ana, SocialDemo.ben, SocialDemo.cleo], "Ben is in both groups: one chip")
    }

    func testNoCountIsWritten() {
        for text in [Copy.searchPhotosEmptyTitle, Copy.searchPhotosIdleTitle, Copy.searchPhotosIdleDetail, Copy.searchPhotosError, Copy.searchPhotosOffline] {
            XCTAssertFalse(text.socialContainsDigit, text)
        }
    }
}
