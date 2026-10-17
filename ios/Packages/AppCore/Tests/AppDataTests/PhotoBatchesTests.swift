import Foundation
import XCTest
@testable import AppData

/// Several photos posted together (migration 0051, `layout.global.photoBatch`): grouping, the viewer's order and its dots.
final class PhotoBatchesTests: XCTestCase {
    private let ana = UserID("9f1c1d2e-0000-4000-8000-0000000000a1")
    private let ben = UserID("9f1c1d2e-0000-4000-8000-0000000000b2")

    private struct Item: Equatable {
        let id: String
        let key: PhotoBatchKey?
    }

    private func item(_ id: String, _ author: UserID? = nil, _ batch: String? = nil) -> Item {
        Item(id: id, key: author.flatMap { author in batch.map { PhotoBatchKey(authorID: author, batchID: $0) } })
    }

    private func ids(_ runs: [[Item]]) -> [[String]] { runs.map { $0.map(\.id) } }

    func testPostDecodesBatchIDAndKeepsNilWithoutIt() throws {
        let json = """
        {"id":"0f8fad5b-d9cb-469f-a165-70867728950e","media_id":"7c9e6679-7425-40de-944b-e07fc1f90ae7",
         "group_id":"9f1c1d2e-0000-4000-8000-000000000001","author_id":"9f1c1d2e-0000-4000-8000-000000000002",
         "in_window":false,"created_at":"2026-10-15T13:35:09.329469+00:00",
         "batch_id":"6A3B0C1D-2E3F-4A5B-8C7D-9E0F1A2B3C4D"}
        """
        let post = try DataCoding.makeDecoder().decode(Post.self, from: Data(json.utf8))
        XCTAssertEqual(post.batchID, "6A3B0C1D-2E3F-4A5B-8C7D-9E0F1A2B3C4D")
        XCTAssertEqual(post.batchKey, PhotoBatchKey(authorID: post.authorID, batchID: "6a3b0c1d-2e3f-4a5b-8c7d-9e0f1a2b3c4d"))
        let single = json.replacingOccurrences(of: ",\n \"batch_id\":\"6A3B0C1D-2E3F-4A5B-8C7D-9E0F1A2B3C4D\"", with: "")
        let alone = try DataCoding.makeDecoder().decode(Post.self, from: Data(single.utf8))
        XCTAssertNil(alone.batchID)
        XCTAssertNil(alone.batchKey)
    }

    func testSameAuthorAndBatchConsecutiveIsOneRun() {
        let runs = PhotoBatches.runs([item("1", ana, "b"), item("2", ana, "b"), item("3", ana, "b")], key: \.key)
        XCTAssertEqual(ids(runs), [["1", "2", "3"]])
    }

    func testPhotosWithoutBatchStandAlone() {
        let runs = PhotoBatches.runs([item("1", ana), item("2", ana), item("3")], key: \.key)
        XCTAssertEqual(ids(runs), [["1"], ["2"], ["3"]])
    }

    func testOtherAuthorOrOtherBatchStartsANewRun() {
        let runs = PhotoBatches.runs(
            [item("1", ana, "b"), item("2", ana, "b"), item("3", ben, "b"), item("4", ana, "c"), item("5", ana, "c")],
            key: \.key
        )
        XCTAssertEqual(ids(runs), [["1", "2"], ["3"], ["4", "5"]])
    }

    func testAnInterruptionSplitsTheBatchIntoTwoRuns() {
        let runs = PhotoBatches.runs([item("1", ana, "b"), item("2", ana, "b"), item("m"), item("3", ana, "b")], key: \.key)
        XCTAssertEqual(ids(runs), [["1", "2"], ["m"], ["3"]])
    }

    func testADeletedPhotoLeavesTheRestTogether() {
        let all = [item("1", ana, "b"), item("2", ana, "b"), item("3", ana, "b")]
        XCTAssertEqual(ids(PhotoBatches.runs(all.filter { $0.id != "2" }, key: \.key)), [["1", "3"]])
        XCTAssertEqual(ids(PhotoBatches.runs(all.filter { $0.id != "1" && $0.id != "2" }, key: \.key)), [["3"]])
    }

    func testBatchIDsCompareWithoutCase() {
        XCTAssertEqual(PhotoBatchKey(authorID: ana, batchID: "ABC"), PhotoBatchKey(authorID: ana, batchID: "abc"))
    }

    func testGatherPutsTheBatchSideBySideInPostedOrder() {
        // a wall (newest first) holds the batch reversed, with someone's photo between
        XCTAssertEqual(PhotoBatches.gather(["x", "3", "y", "2", "1", "z"], batch: ["1", "2", "3"]), ["x", "1", "2", "3", "y", "z"])
        // already in order: unchanged
        XCTAssertEqual(PhotoBatches.gather(["1", "2", "3", "x"], batch: ["1", "2", "3"]), ["1", "2", "3", "x"])
        // members the context does not hold are not added
        XCTAssertEqual(PhotoBatches.gather(["x", "3", "1"], batch: ["1", "2", "3"]), ["x", "1", "3"])
        // one member or none: unchanged
        XCTAssertEqual(PhotoBatches.gather(["x", "3"], batch: ["1", "2", "3"]), ["x", "3"])
    }

    func testPositionIsWithinTheBatchOnly() {
        let context = ["x", "1", "2", "3", "y"]
        XCTAssertEqual(PhotoBatches.position(of: "2", in: context, batch: ["1", "2", "3"]), PhotoBatchPosition(index: 2, total: 3))
        XCTAssertNil(PhotoBatches.position(of: "x", in: context, batch: ["1", "2", "3"]))
        // a deleted member leaves the rest
        XCTAssertEqual(PhotoBatches.position(of: "3", in: ["1", "3"], batch: ["1", "2", "3"]), PhotoBatchPosition(index: 2, total: 2))
        // a batch with one photo left has no dots
        XCTAssertNil(PhotoBatches.position(of: "3", in: ["3"], batch: ["1", "2", "3"]))
    }
}
