// tagging — the "i'm in this" self-tag (design/surfaces/tagging.md).
@testable import App
import AppData
import DesignSystem
import XCTest

@MainActor
final class MemoryTaggingTests: XCTestCase {
    func testTogglesOnAndOffOptimistically() async {
        let context = MemoryTestContext()
        let model = SelfTagModel(postID: MemoryIDs.post(3), isTagged: false, isOthersPhoto: true, dependencies: context.dependencies)
        await model.toggle()
        XCTAssertTrue(model.isOn)
        XCTAssertTrue(context.data.snapshot.myTags.contains(MemoryIDs.post(3)))
        await model.toggle()
        XCTAssertFalse(model.isOn)
        XCTAssertFalse(context.data.snapshot.myTags.contains(MemoryIDs.post(3)))
        XCTAssertEqual(context.haptics, [Tokens.Haptics.globalSelect, Tokens.Haptics.globalSelect])
        XCTAssertEqual(context.data.calls(of: .tagSelf), 1)
        XCTAssertEqual(context.data.calls(of: .untagSelf), 1)
        XCTAssertFalse(model.isPending)
    }

    func testReadsItsStateWhenTheHostDidNot() async {
        let context = MemoryTestContext()
        let model = SelfTagModel(postID: MemoryIDs.post(2), isTagged: nil, isOthersPhoto: true, dependencies: context.dependencies)
        XCTAssertFalse(model.isKnown)
        await model.loadIfNeeded()
        XCTAssertTrue(model.isKnown)
        XCTAssertTrue(model.isOn)
    }

    func testOfflineDoesNotChangeTheToggle() async {
        let context = MemoryTestContext { $0.network = .offline }
        let model = SelfTagModel(postID: MemoryIDs.post(3), isTagged: false, isOthersPhoto: false, dependencies: context.dependencies)
        await model.toggle()
        XCTAssertFalse(model.isOn)
        XCTAssertEqual(model.message, .offline)
        XCTAssertEqual(model.message?.text, Copy.taggingOffline)
        XCTAssertEqual(context.data.calls(of: .tagSelf), 0)
        XCTAssertEqual(context.haptics, [Tokens.Haptics.globalError])
    }

    func testFailuresRevert() async {
        let context = MemoryTestContext()
        context.data.fail(.tagSelf, with: .http(status: 500))
        let model = SelfTagModel(postID: MemoryIDs.post(3), isTagged: false, isOthersPhoto: false, dependencies: context.dependencies)
        await model.toggle()
        XCTAssertFalse(model.isOn, "back to its previous state")
        XCTAssertEqual(model.message, .error)

        context.data.fail(.tagSelf, with: nil)
        let gone = SelfTagModel(postID: PostID("00000000-0000-4000-8000-0000000001ff"), isTagged: false, isOthersPhoto: false, dependencies: context.dependencies)
        await gone.toggle()
        XCTAssertFalse(gone.isOn)
        XCTAssertTrue(gone.isGone, "the viewer closes the photo")
        XCTAssertEqual(gone.message, .notFound)
        await gone.toggle()
        XCTAssertEqual(context.data.calls(of: .tagSelf), 2, "no call once the photo is gone")
    }

    func testCoachShowsOnceOnOthersPhotos() async {
        let context = MemoryTestContext()
        let own = SelfTagModel(postID: MemoryIDs.post(1), isTagged: false, isOthersPhoto: false, dependencies: context.dependencies)
        await own.loadIfNeeded()
        XCTAssertFalse(own.coachVisible)

        let others = SelfTagModel(postID: MemoryIDs.post(3), isTagged: false, isOthersPhoto: true, dependencies: context.dependencies)
        await others.loadIfNeeded()
        XCTAssertTrue(others.coachVisible)
        await others.toggle()
        XCTAssertFalse(others.coachVisible, "any tap on the toggle dismisses it for good")

        let next = SelfTagModel(postID: MemoryIDs.post(5), isTagged: false, isOthersPhoto: true, dependencies: context.dependencies)
        await next.loadIfNeeded()
        XCTAssertFalse(next.coachVisible, "once per account")
    }
}
