// chat.thread link previews built on the sender's device (`chat.thread.layout.linkPreview`, migration 0053): which link
// gets one, the pipeline read → downscale → draft with fakes, and the model's best-effort, silent flow.
@testable import App
import AppData
import AppModels
import Foundation
import XCTest

@MainActor
final class SocialLinkPreviewTests: XCTestCase {
    // MARK: Which link

    func testTheFirstLinkWrittenWithItsSchemeIsTheCandidate() {
        let body = "menu at www.example.org or https://example.com/menu?day=fri and http://example.net"
        let candidate = ChatLinkPreviews.candidate(in: body)
        XCTAssertEqual(candidate?.text, "https://example.com/menu?day=fri", "as written in the text, which set_link_preview looks for")
        XCTAssertEqual(candidate?.url.host(), "example.com")
        XCTAssertTrue(body.contains(candidate?.text ?? "-"))
    }

    func testAnAddressTheDetectorCompletedOrAnotherSchemeGetsNone() {
        XCTAssertNil(ChatLinkPreviews.candidate(in: "see www.example.org"), "the completed http://www.example.org is not in the text")
        XCTAssertNil(ChatLinkPreviews.candidate(in: "mail me at ana@example.com"))
        XCTAssertNil(ChatLinkPreviews.candidate(in: "ftp://example.com/file"))
        XCTAssertNil(ChatLinkPreviews.candidate(in: "no links here"))
        XCTAssertNil(ChatLinkPreviews.candidate(in: ""))
    }

    func testTheSchemeMayBeWrittenInCapitalsAndKeepsItsSpelling() {
        XCTAssertEqual(ChatLinkPreviews.candidate(in: "HTTPS://Example.com/A")?.text, "HTTPS://Example.com/A")
    }

    func testTextIsTrimmedAndCutToTheServersLimits() {
        XCTAssertNil(ChatLinkPreviews.clip("   \n ", to: 10))
        XCTAssertNil(ChatLinkPreviews.clip(nil, to: 10))
        XCTAssertEqual(ChatLinkPreviews.clip("  A page  ", to: 10), "A page")
        let long = String(repeating: "é", count: 400)
        XCTAssertEqual(ChatLinkPreviews.clip(long, to: ChatLinkPreviews.titleMax)?.unicodeScalars.count, ChatLinkPreviews.titleMax)
        let flags = String(repeating: "🇫🇷", count: 80) // 2 scalars each: the server counts code points
        XCTAssertLessThanOrEqual(ChatLinkPreviews.clip(flags, to: ChatLinkPreviews.siteMax)?.unicodeScalars.count ?? 0, ChatLinkPreviews.siteMax)
    }

    func testTheHostWithoutWwwIsTheFallbackSite() {
        XCTAssertEqual(ChatLinkPreviews.host(of: URL(string: "https://www.example.com/a")!), "example.com")
        XCTAssertEqual(ChatLinkPreviews.host(of: URL(string: "https://news.example.com")!), "news.example.com")
    }

    func testAPreviewBelongsToATextOnlyWhileItHoldsTheAddress() {
        let preview = LinkPreview(url: "https://example.com/a", title: "A")
        XCTAssertEqual(ChatLinkPreviews.keeps(preview, body: "see https://example.com/a"), preview)
        XCTAssertNil(ChatLinkPreviews.keeps(preview, body: "never mind"))
        XCTAssertNil(ChatLinkPreviews.keeps(nil, body: "see https://example.com/a"))
    }

    // MARK: Pipeline

    func testTheBuilderReadsThePageOnceAndDownscalesItsImage() async {
        let reader = FakePageReader(LinkPageMetadata(title: "  Friday menu ", site: "Example Eats", imageData: Data([1, 2, 3])))
        let encoder = FakeImageEncoder(Data([9]))
        let draft = await LinkPreviewBuilder(reader: reader, encoder: encoder).build(for: "tonight? https://www.example.com/menu")
        XCTAssertEqual(draft, LinkPreviewDraft(url: "https://www.example.com/menu", title: "Friday menu", site: "Example Eats", jpeg: Data([9])))
        XCTAssertEqual(reader.urls.map(\.absoluteString), ["https://www.example.com/menu"])
        XCTAssertEqual(encoder.inputs, [Data([1, 2, 3])])
    }

    func testWithoutASiteNameTheHostIsUsedAndAnImageAloneIsEnough() async {
        let reader = FakePageReader(LinkPageMetadata(imageData: Data([1])))
        let draft = await LinkPreviewBuilder(reader: reader, encoder: FakeImageEncoder(Data([2]))).build(for: "https://www.example.com/p")
        XCTAssertEqual(draft, LinkPreviewDraft(url: "https://www.example.com/p", title: nil, site: "example.com", jpeg: Data([2])))
    }

    func testNoPreviewWithoutALinkAPageOrSomethingToShow() async {
        let unread = FakePageReader(nil)
        let builder = LinkPreviewBuilder(reader: unread, encoder: FakeImageEncoder(Data([2])))
        let none = await builder.build(for: "no link")
        XCTAssertNil(none)
        XCTAssertTrue(unread.urls.isEmpty, "no link → the page is never read")
        let unreadable = await builder.build(for: "https://example.com")
        XCTAssertNil(unreadable, "the page could not be read")

        let bare = LinkPreviewBuilder(reader: FakePageReader(LinkPageMetadata(site: "Example")), encoder: FakeImageEncoder(Data([2])))
        let empty = await bare.build(for: "https://example.com")
        XCTAssertNil(empty, "neither a title nor an image")

        let undecodable = LinkPreviewBuilder(reader: FakePageReader(LinkPageMetadata(title: "T", imageData: Data([1]))), encoder: FakeImageEncoder(nil))
        let titleOnly = await undecodable.build(for: "https://example.com")
        XCTAssertEqual(titleOnly?.title, "T")
        XCTAssertNil(titleOnly?.jpeg, "an image that cannot be encoded is left out")
    }

    // MARK: Model

    func testSendingALinkBuildsItsPreviewAfterTheMessageIsSent() async {
        let data = SocialDemo.makeData()
        let reader = FakePageReader(LinkPageMetadata(title: "Friday menu", imageData: Data([1])))
        let model = ChatThreadModel(
            groupID: SocialDemo.groupID, data: data,
            linkPreviews: LinkPreviewBuilder(reader: reader, encoder: FakeImageEncoder(Data([7])))
        )
        await model.load()
        model.draft = "dinner? https://example.com/menu"
        await model.sendDraft()
        await model.linkPreviewsSettled()

        let sent = model.messages.last
        XCTAssertEqual(sent?.body, "dinner? https://example.com/menu")
        XCTAssertEqual(sent?.linkPreview?.url, "https://example.com/menu")
        XCTAssertEqual(sent?.linkPreview?.title, "Friday menu")
        XCTAssertEqual(sent?.linkPreview?.site, "example.com")
        XCTAssertNotNil(sent?.linkPreview?.imagePath)
        XCTAssertEqual(sent.flatMap { model.linkPreview(of: $0) }, sent?.linkPreview)
        XCTAssertEqual(data.read { $0.linkPreviewsSent }.map(\.jpeg), [Data([7])])
        let calls = data.read { $0.calls }
        XCTAssertLessThan(calls.firstIndex(of: "sendText") ?? .max, calls.firstIndex(of: "setLinkPreview") ?? -1, "after send_message")
    }

    func testAFailedPreviewIsSilentAndLeavesTheMessageAlone() async {
        let data = SocialDemo.makeData()
        data.update { $0.failOnce.insert("setLinkPreview") }
        let model = ChatThreadModel(
            groupID: SocialDemo.groupID, data: data,
            linkPreviews: LinkPreviewBuilder(reader: FakePageReader(LinkPageMetadata(title: "T")), encoder: FakeImageEncoder(nil))
        )
        await model.load()
        model.draft = "https://example.com"
        await model.sendDraft()
        let afterSend = model.signals
        await model.linkPreviewsSettled()
        XCTAssertNil(model.messages.last?.linkPreview)
        XCTAssertEqual(model.signals, afterSend, "no notice, no haptic")
        XCTAssertFalse(model.isFailed(model.messages.last!))
    }

    func testNoPreviewIsAskedForWithoutALinkOrWithoutABuilder() async {
        let data = SocialDemo.makeData()
        let reader = FakePageReader(LinkPageMetadata(title: "T"))
        let model = ChatThreadModel(
            groupID: SocialDemo.groupID, data: data,
            linkPreviews: LinkPreviewBuilder(reader: reader, encoder: FakeImageEncoder(nil))
        )
        await model.load()
        model.draft = "see you at 8"
        await model.sendDraft()
        await model.linkPreviewsSettled()
        XCTAssertTrue(reader.urls.isEmpty)

        let plain = ChatThreadModel(groupID: SocialDemo.groupID, data: data)
        await plain.load()
        plain.draft = "https://example.com"
        await plain.sendDraft()
        await plain.linkPreviewsSettled()
        XCTAssertFalse(data.read { $0.calls }.contains("setLinkPreview"))
    }

    func testAnEditThatDropsTheAddressDropsThePreviewAtOnce() async {
        let data = SocialDemo.makeData()
        let id = SocialDemo.messages[3].id // mine, "yes please"
        let sentAt = SocialDemo.messages[3].createdAt
        data.update { state in
            state.config = PublicAppConfig(messageEditWindowSeconds: 900, typingTTLSeconds: 6)
            guard let index = state.messages.firstIndex(where: { $0.id == id }) else { return }
            state.messages[index].body = "yes please https://example.com/a"
            state.messages[index].linkPreview = LinkPreview(url: "https://example.com/a", title: "A")
        }
        let model = ChatThreadModel(groupID: SocialDemo.groupID, data: data, now: { sentAt.addingTimeInterval(60) })
        await model.load()
        guard let mine = model.messages.first(where: { $0.id == id }) else { return XCTFail("my demo text") }
        XCTAssertNotNil(model.linkPreview(of: mine))

        model.startEdit(mine)
        XCTAssertTrue(model.isEditing)
        model.draft = "yes please"
        await model.sendDraft()
        let edited = model.messages.first { $0.id == id }
        XCTAssertNil(edited?.linkPreview)
        XCTAssertNil(edited.flatMap { model.linkPreview(of: $0) })
    }

    func testAnUpdateFromSomeoneElseShowsTheirPreview() async {
        let data = SocialDemo.makeData()
        let model = ChatThreadModel(groupID: SocialDemo.groupID, data: data)
        await model.load()
        guard var theirs = model.messages.first(where: { $0.kind == .text && !model.isMine($0) }) else {
            return XCTFail("the demo thread has someone else's text")
        }
        theirs.body = (theirs.body ?? "") + " https://example.com/x"
        theirs.linkPreview = LinkPreview(url: "https://example.com/x", title: "X", site: "Example")
        await model.handle(.messageUpdated(theirs))
        XCTAssertEqual(model.messages.first { $0.id == theirs.id }.flatMap { model.linkPreview(of: $0) }?.title, "X")
    }
}

/// Answers every page read with the same metadata and records the addresses asked.
private final class FakePageReader: LinkPageReading, @unchecked Sendable {
    private let lock = NSLock()
    private let answer: LinkPageMetadata?
    private var asked: [URL] = []

    init(_ answer: LinkPageMetadata?) { self.answer = answer }

    var urls: [URL] { lock.withLock { asked } }

    func read(_ url: URL) async -> LinkPageMetadata? {
        lock.withLock { asked.append(url) }
        return answer
    }
}

/// "Encodes" every image to the same bytes (nil: cannot) and records its inputs.
private final class FakeImageEncoder: LinkPreviewImageEncoding, @unchecked Sendable {
    private let lock = NSLock()
    private let output: Data?
    private var received: [Data] = []

    init(_ output: Data?) { self.output = output }

    var inputs: [Data] { lock.withLock { received } }

    func jpeg(from data: Data) async -> Data? {
        lock.withLock { received.append(data) }
        return output
    }
}
