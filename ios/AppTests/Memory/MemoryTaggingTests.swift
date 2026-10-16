// tagging — the self-tag run ("I'm in this" / "with {names}") and the "In this photo" sheet (design/surfaces/tagging.md).
@testable import App
import AppData
import DesignSystem
import SwiftUI
import XCTest

@MainActor
final class MemoryTaggingTests: XCTestCase {
    func testReadsTheTagsInTagOrderWithFirstNames() async {
        let context = MemoryTestContext()
        let model = TagRunModel(postID: MemoryIDs.post(2), dependencies: context.dependencies)
        XCTAssertFalse(model.isKnown)
        await model.load()
        XCTAssertTrue(model.isKnown)
        XCTAssertEqual(model.people.map(\.firstName), ["Bea", "Ana"], "others first, then yours, in tag order")
        XCTAssertTrue(model.isTagged)
        XCTAssertNotNil(model.people.first?.avatarURL)
        XCTAssertEqual(model.namesText, MemoryFormat.names(["Bea", "Ana"]))
    }

    func testTheHostsTagsAreUsedWithoutAnotherRead() async {
        let context = MemoryTestContext()
        let model = TagRunModel(postID: MemoryIDs.post(6), taggedUserIDs: [MemoryIDs.other, MemoryIDs.friend], dependencies: context.dependencies)
        XCTAssertTrue(model.isKnown)
        await model.load()
        XCTAssertEqual(model.people.map(\.firstName), ["Caio", "Bea"])
        XCTAssertFalse(model.isTagged)
        XCTAssertEqual(context.data.calls(of: .tags), 0)
    }

    func testTaggingYourselfIsOptimisticAndUntaggingRemovesYourRow() async {
        let context = MemoryTestContext()
        let model = TagRunModel(postID: MemoryIDs.post(3), dependencies: context.dependencies)
        await model.load()
        XCTAssertTrue(model.people.isEmpty, "nobody tagged: the run says \"I'm in this\"")
        await model.tag()
        XCTAssertTrue(model.isTagged)
        XCTAssertEqual(model.people.map(\.firstName), ["Ana"])
        XCTAssertTrue(context.data.snapshot.myTags.contains(MemoryIDs.post(3)))
        await model.untag()
        XCTAssertFalse(model.isTagged)
        XCTAssertTrue(model.people.isEmpty)
        XCTAssertFalse(context.data.snapshot.myTags.contains(MemoryIDs.post(3)))
        XCTAssertEqual(context.haptics, [Tokens.Haptics.globalSelect, Tokens.Haptics.globalSelect], "a toggled selection, Retro's tick")
        XCTAssertEqual(context.data.calls(of: .tagSelf), 1)
        XCTAssertEqual(context.data.calls(of: .untagSelf), 1)
        XCTAssertFalse(model.isPending)
    }

    func testOfflineChangesNothing() async {
        let context = MemoryTestContext { $0.network = .offline }
        let model = TagRunModel(postID: MemoryIDs.post(3), dependencies: context.dependencies)
        await model.load()
        await model.tag()
        XCTAssertFalse(model.isTagged)
        XCTAssertEqual(model.message, .offline)
        XCTAssertEqual(context.lastToast, Copy.taggingOffline)
        XCTAssertEqual(context.data.calls(of: .tagSelf), 0)
        XCTAssertEqual(context.haptics, [Tokens.Haptics.globalError])
    }

    func testFailuresRevertWithTheirOwnLine() async {
        let context = MemoryTestContext()
        context.data.fail(.tagSelf, with: .http(status: 500))
        let model = TagRunModel(postID: MemoryIDs.post(3), dependencies: context.dependencies)
        await model.load()
        await model.tag()
        XCTAssertFalse(model.isTagged, "back to its previous state")
        XCTAssertEqual(model.message, .addFailed)
        XCTAssertEqual(context.lastToast, Copy.taggingError)

        context.data.fail(.untagSelf, with: .http(status: 500))
        let tagged = TagRunModel(postID: MemoryIDs.post(2), dependencies: context.dependencies)
        await tagged.load()
        await tagged.untag()
        XCTAssertTrue(tagged.isTagged)
        XCTAssertEqual(tagged.message, .removeFailed)
        XCTAssertEqual(context.lastToast, Copy.taggingRemoveError)

        context.data.fail(.tagSelf, with: nil)
        let gone = TagRunModel(postID: PostID("00000000-0000-4000-8000-0000000001ff"), taggedUserIDs: [], dependencies: context.dependencies)
        await gone.load()
        await gone.tag()
        XCTAssertFalse(gone.isTagged)
        XCTAssertTrue(gone.isGone, "the viewer closes the photo")
        XCTAssertEqual(gone.message, .notFound)
        await gone.tag()
        XCTAssertEqual(context.data.calls(of: .tagSelf), 2, "no call once the photo is gone")
    }

    func testTheRunEmphasisesEachNameAndNeverCounts() {
        let names = ["Ana", "Bea", "Caio"]
        let full = Copy.taggingWith(names: MemoryFormat.names(names, locale: Locale(identifier: "en_US")))
        XCTAssertFalse(full.contains("3"), "never a count")
        XCTAssertEqual(MemoryFormat.names(names, locale: Locale(identifier: "en_US")), "Ana, Bea, and Caio")
        _ = TagRun.withNames(names)
    }
}
