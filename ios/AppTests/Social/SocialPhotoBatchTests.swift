// Several photos posted together (owner decision 34, research #1; `layout.global.photoBatch`): the chat thread's one item
// (`chat.thread.layout.batch`), the viewer's order and dots (`photo.viewer.layout.batchDots`), one strip tile on the walls
// and on groups.screen.
@testable import App
import AppData
import AppModels
import Foundation
import XCTest

@MainActor
final class SocialPhotoBatchTests: XCTestCase {
    private let b1 = PostID("00000000-0000-4000-8000-00000000c101")
    private let b2 = PostID("00000000-0000-4000-8000-00000000c102")
    private let b3 = PostID("00000000-0000-4000-8000-00000000c103")
    private let batchID = "6a3b0c1d-2e3f-4a5b-8c7d-9e0f1a2b3c4d"

    private var utc: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .current
        return calendar
    }

    /// Ana's three photos posted together on Tuesday, a few seconds apart.
    private func batchPosts(group: GroupID = SocialDemo.groupID) -> [PostWithMedia] {
        [b1, b2, b3].enumerated().map { index, id in
            var post = SocialDemo.post(id, by: SocialDemo.ana, at: SocialDemo.at(SocialDemo.day + 2 * SocialDemo.hour + Double(index)), in: group)
            post.post.batchID = batchID
            return post
        }
    }

    private func batchMessages(from n: Int) -> [Message] {
        [b1, b2, b3].enumerated().map { index, id in
            SocialDemo.message(n + index, by: SocialDemo.ana, at: SocialDemo.at(SocialDemo.day + 2 * SocialDemo.hour + Double(index)), post: id)
        }
    }

    private func dataWithBatch() -> FakeSocialData {
        let data = SocialDemo.makeData()
        let posts = batchPosts()
        let messages = batchMessages(from: 40)
        data.update { state in
            state.posts += posts
            state.messages += messages
        }
        return data
    }

    private func rows(_ entries: [ChatEntry]) -> [ChatRow] {
        entries.compactMap { entry -> ChatRow? in if case let .message(row) = entry { return row } else { return nil } }
    }

    // MARK: chat.thread

    func testABatchIsOneThreadItemLedByItsFirstPhoto() {
        let messages = batchMessages(from: 40)
        let keys = Dictionary(uniqueKeysWithValues: batchPosts().map { ($0.id, $0.post.batchKey) })
        let result = rows(ChatThreadLayout.entries(messages, me: SocialDemo.me, calendar: utc) { message in
            message.postID.flatMap { keys[$0] ?? nil }
        })
        XCTAssertEqual(result.map(\.message.postID), [b1])
        XCTAssertEqual(result.first?.batch.map(\.postID), [b2, b3])
        XCTAssertTrue(result.first?.isBatch ?? false)
    }

    func testPhotosWithoutABatchKeepOneItemEach() {
        let messages = batchMessages(from: 40)
        let result = rows(ChatThreadLayout.entries(messages, me: SocialDemo.me, calendar: utc))
        XCTAssertEqual(result.map(\.message.postID), [b1, b2, b3])
        XCTAssertEqual(result.map(\.isBatch), [false, false, false])
        XCTAssertEqual(result.map(\.startsRun), [true, false, false])
    }

    func testAMessageBetweenSplitsTheBatchIntoTwoItems() {
        var messages = batchMessages(from: 40)
        messages.insert(SocialDemo.message(50, by: SocialDemo.ben, at: messages[1].createdAt.addingTimeInterval(0.5), text: "wow"), at: 2)
        let keys = Dictionary(uniqueKeysWithValues: batchPosts().map { ($0.id, $0.post.batchKey) })
        let result = rows(ChatThreadLayout.entries(messages, me: SocialDemo.me, calendar: utc) { message in
            message.postID.flatMap { keys[$0] ?? nil }
        })
        XCTAssertEqual(result.map(\.id), [SocialDemo.messageID(40), SocialDemo.messageID(50), SocialDemo.messageID(42)])
        XCTAssertEqual(result.map(\.batch.count), [1, 0, 0])
        XCTAssertEqual(result.map(\.isBatch), [true, false, false], "the photo after the interruption is alone")
    }

    func testTheThreadModelGroupsItsBatchAndOpensTheViewerOnAllItsPhotos() async {
        let model = ChatThreadModel(groupID: SocialDemo.groupID, data: dataWithBatch())
        await model.load()
        let batchRows = rows(model.entries(calendar: utc)).filter(\.isBatch)
        XCTAssertEqual(batchRows.map(\.message.postID), [b1])
        XCTAssertEqual(batchRows.first?.batch.map(\.postID), [b2, b3])
        XCTAssertEqual(model.photoPostIDs.filter { [b1, b2, b3].contains($0) }, [b1, b2, b3], "the viewer still gets every photo")
    }

    func testADeletedPhotoOfTheBatchLeavesTheRest() async {
        let model = ChatThreadModel(groupID: SocialDemo.groupID, data: dataWithBatch())
        await model.load()
        await model.handle(.postDeleted(postID: b2, mediaID: nil))
        XCTAssertEqual(rows(model.entries(calendar: utc)).first { $0.message.postID == b1 }?.batch.map(\.postID), [b3])
        await model.handle(.postDeleted(postID: b1, mediaID: nil))
        let lone = rows(model.entries(calendar: utc)).first { $0.message.postID == b3 }
        XCTAssertEqual(lone?.isBatch, false, "one photo left is an ordinary photo")
    }

    // MARK: photo.viewer

    func testTheViewerPutsTheBatchSideBySideInPostedOrderWithDots() async {
        let data = dataWithBatch()
        // a wall-like order: newest first, someone else's photo between
        let model = PhotoViewerModel(
            context: PhotoViewerContext(postIDs: [b3, SocialDemo.p1, b2, b1], start: b2, groupID: SocialDemo.groupID), data: data
        )
        await model.load()
        XCTAssertEqual(model.postIDs, [b1, b2, b3, SocialDemo.p1])
        XCTAssertEqual(model.selection, b2)
        XCTAssertEqual(model.batchPosition, PhotoBatchPosition(index: 2, total: 3))
        XCTAssertEqual(model.currentBatch, [b1, b2, b3])
        await model.select(SocialDemo.p1)
        XCTAssertNil(model.batchPosition, "dots only within the batch")
        await model.select(b3)
        await model.selectInBatch(0)
        XCTAssertEqual(model.selection, b1)
    }

    func testALinkToABatchPhotoOpensTheWholeBatch() async {
        let data = dataWithBatch()
        let model = PhotoViewerModel(
            context: PhotoViewerContext(postIDs: [b2], start: b2, groupID: SocialDemo.groupID, opensReveal: true), data: data
        )
        await model.load()
        XCTAssertEqual(model.postIDs, [b1, b2, b3])
        XCTAssertEqual(model.selection, b2)
        XCTAssertEqual(model.batchPosition, PhotoBatchPosition(index: 2, total: 3))
    }

    func testABatchFailureKeepsTheOnePhoto() async {
        let data = dataWithBatch()
        data.update { $0.failOnce.insert("batchWith") }
        let model = PhotoViewerModel(
            context: PhotoViewerContext(postIDs: [b2], start: b2, groupID: SocialDemo.groupID, opensReveal: true), data: data
        )
        await model.load()
        XCTAssertEqual(model.postIDs, [b2])
        XCTAssertNil(model.batchPosition)
    }

    func testAGonePhotoLeavesTheOthersDots() async {
        let model = PhotoViewerModel(
            context: PhotoViewerContext(postIDs: [b1, b2, b3], start: b1, groupID: SocialDemo.groupID), data: dataWithBatch()
        )
        await model.load()
        await model.handle(.postDeleted(postID: b2, mediaID: nil))
        XCTAssertEqual(model.batchPosition, PhotoBatchPosition(index: 1, total: 2))
    }

    func testAPhotoPostedAloneHasNoDots() async {
        let model = PhotoViewerModel(
            context: PhotoViewerContext(postIDs: [SocialDemo.p1, SocialDemo.p2], start: SocialDemo.p1, groupID: SocialDemo.groupID),
            data: dataWithBatch()
        )
        await model.load()
        XCTAssertEqual(model.postIDs, [SocialDemo.p1, SocialDemo.p2])
        XCTAssertNil(model.batchPosition)
    }

    // MARK: walls

    func testAWallShowsABatchAsOneTileAndTheViewerGetsAllItsPhotos() async {
        let data = SocialDemo.makeData()
        let posts = batchPosts()
        data.update { state in
            state.posts += posts
            state.walls[SocialDemo.ana] = posts.reversed().map { post in
                WallItem(
                    itemKind: .post, postID: post.id, mediaID: post.post.mediaID, collageID: nil,
                    groupIDs: [SocialDemo.groupID], createdAt: post.post.createdAt
                )
            }
        }
        let model = WallModel(owner: .member(SocialDemo.ana), data: data, timeZone: TimeZone(identifier: "UTC") ?? .current, now: { SocialDemo.at(4 * SocialDemo.day) })
        await model.load()
        let week = model.weeks.first { !$0.tiles.isEmpty }
        XCTAssertEqual(week?.tiles.map(\.id), ["p" + b1.rawValue])
        XCTAssertEqual(week.map { $0.tiles.map($0.isBatch) }, [true])
        XCTAssertEqual(model.photoPostIDs, [b1, b2, b3])
    }

    // MARK: groups.screen

    func testTheWeekStripShowsABatchAsOneRun() {
        let fixture = AccountFixture()
        let model = GroupFeedModel(groupID: SocialDemo.groupID, data: fixture.data, now: { SocialDemo.at(4 * SocialDemo.day) })
        let alone = SocialDemo.post(SocialDemo.p1, by: SocialDemo.ben, at: SocialDemo.at(SocialDemo.hour))
        model.seed(
            group: SocialDemo.group(SocialDemo.groupID, name: "roommates", createdBy: SocialDemo.ana), members: [],
            posts: Array((batchPosts() + [alone]).reversed()), phase: .loaded
        )
        XCTAssertEqual(model.thisWeekRuns.map { $0.map(\.id) }, [[SocialDemo.p1], [b1, b2, b3]])
    }
}
