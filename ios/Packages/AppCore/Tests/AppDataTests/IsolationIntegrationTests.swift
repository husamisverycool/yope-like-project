import AppModels
import Foundation
import XCTest
@testable import AppData

/// Security invariant 1 through AppData: someone who is not a member of a group gets nothing
/// of it from any repository, RPC or storage read.
final class IsolationIntegrationTests: XCTestCase {
    private var users: TestUsers!

    override func setUp() async throws {
        try await LocalStack.require()
        users = TestUsers()
    }

    override func tearDown() async throws {
        await users?.cleanUp()
    }

    func testOutsiderGetsNothing() async throws {
        let ana = try await users.make("Ana")
        let rui = try await users.make("Rui")
        let eve = try await users.make("Eve")
        let group = try await ana.data.groups.create(name: "Private \(users.runID)", kind: .family)
        let invite = try await ana.data.groups.createInvite(groupID: group.id)
        _ = try await rui.data.groups.join(token: invite.token)
        _ = try await eve.data.groups.create(name: "Eve \(users.runID)", kind: .friends)

        let file = try temporaryFile(tinyJPEG, extension: "jpg")
        let posts = try await ana.data.publisher.publish(PostDraft(kind: .photo, original: .init(url: file, contentType: ContentType.jpeg), groupIDs: [group.id], caption: "secret"))
        let post = try XCTUnwrap(posts.first)
        try await rui.data.reactions.react(postID: post.id, emoji: "🎉")
        try await rui.data.reactions.tagSelf(postID: post.id)
        let message = try await rui.data.chat.sendText(groupID: group.id, body: "members only")
        _ = try await rui.data.memories.saveAlbum(groupID: group.id, name: "Album", postIDs: [post.id])
        _ = try await LocalStack.insert("daily_invitations", [
            "group_id": group.id.rawValue, "local_date": LocalDate(Date(), in: TimeZone(identifier: "UTC")!).adding(days: -3).description,
            "fires_at": Timestamp.format(Date().addingTimeInterval(-10)), "closes_at": Timestamp.format(Date().addingTimeInterval(110)),
        ])
        let value1 = try await ana.data.posts.media(ids: [post.mediaID]).first
        let media = try XCTUnwrap(value1)

        // Tables: nothing.
        let groupRow = try await eve.data.groups.group(id: group.id)
        XCTAssertNil(groupRow)
        let members = try await eve.data.groups.members(groupID: group.id)
        XCTAssertTrue(members.isEmpty)
        let invites = try await eve.data.groups.activeInvites(groupID: group.id)
        XCTAssertTrue(invites.isEmpty)
        let page = try await eve.data.posts.page(groupID: group.id)
        XCTAssertTrue(page.items.isEmpty)
        let postRow = try await eve.data.posts.post(id: post.id)
        XCTAssertNil(postRow)
        let mediaRows = try await eve.data.posts.media(ids: [post.mediaID])
        XCTAssertTrue(mediaRows.isEmpty)
        let chat = try await eve.data.chat.page(groupID: group.id)
        XCTAssertTrue(chat.items.isEmpty)
        let messageRow = try await eve.data.chat.message(id: message.id)
        XCTAssertNil(messageRow)
        let reactions = try await eve.data.reactions.reactions(postID: post.id)
        XCTAssertTrue(reactions.isEmpty)
        let tags = try await eve.data.reactions.tags(postID: post.id)
        XCTAssertTrue(tags.isEmpty)
        let albums = try await eve.data.memories.albums(groupID: group.id)
        XCTAssertTrue(albums.isEmpty)
        let collages = try await eve.data.memories.collages(groupID: group.id)
        XCTAssertTrue(collages.items.isEmpty)
        let recaps = try await eve.data.memories.recaps(groupID: group.id)
        XCTAssertTrue(recaps.isEmpty)
        let stories = try await eve.data.memories.yearStories(groupID: group.id)
        XCTAssertTrue(stories.isEmpty)
        let invitation = try await eve.data.invitations.currentInvitation(groupID: group.id)
        XCTAssertNil(invitation)
        let memberInvitation = try await rui.data.invitations.currentInvitation(groupID: group.id)
        XCTAssertNotNil(memberInvitation, "control: members see the open invitation")
        let profile = try await eve.data.profiles.profile(id: ana.id)
        XCTAssertNil(profile, "no shared group, no profile")
        let wall = try await eve.data.memories.wall(userID: ana.id)
        XCTAssertTrue(wall.items.isEmpty)

        // RPCs refuse.
        await assertThrows(.api(.notGroupMember)) { try await eve.data.memories.historyWeeks(groupID: group.id) }
        await assertThrows(.api(.notGroupMember)) { try await eve.data.memories.onThisDay(groupID: group.id, localDate: LocalDate(year: 2026, month: 1, day: 1)!) }
        await assertThrows(.api(.notGroupMember)) { try await eve.data.groups.createInvite(groupID: group.id) }
        await assertThrows(.api(.notGroupMember)) { try await eve.data.chat.sendText(groupID: group.id, body: "hi") }
        await assertThrows(.api(.notGroupMember)) { try await eve.data.groups.leave(groupID: group.id) }
        await assertThrows(.api(.postNotFound)) { try await eve.data.reactions.react(postID: post.id, emoji: "👀") }
        await assertThrows(.api(.postNotFound)) { try await eve.data.reactions.tagSelf(postID: post.id) }
        await assertThrows(.api(.targetNotFound)) { try await eve.data.safety.report(.post, targetID: post.id.rawValue, reason: "x") }
        await assertThrows(.api(.mediaNotFound)) { try await eve.data.posts.deleteMedia(id: post.mediaID) }
        await assertThrows(.api(.inviteNotFound)) { try await eve.data.groups.revokeInvite(token: invite.token) }
        let eveFile = try temporaryFile(tinyJPEG, extension: "jpg")
        await assertThrows(.api(.notGroupMember)) {
            try await eve.data.publisher.publish(PostDraft(kind: .photo, original: .init(url: eveFile, contentType: ContentType.jpeg), groupIDs: [group.id]))
        }
        await eve.data.publisher.removeAll()

        // Storage: no read of the group's objects, no write outside her folder.
        await assertThrows(.storage(.notFound)) { try await eve.data.signedURLs.url(for: media.originalPath) }
        let batch = try await eve.data.signedURLs.urls(for: [media.originalPath])
        XCTAssertTrue(batch.isEmpty)
        do {
            try await eve.data.uploader.upload(data: tinyJPEG, path: "u/\(ana.id.rawValue)/\(UUID().uuidString.lowercased())/original.jpg", contentType: ContentType.jpeg)
            XCTFail("wrote into another user's folder")
        } catch let error as DataError {
            XCTAssertEqual(error, .storage(.unauthorized))
        }
        // Members still read it (control).
        let memberURL = try await rui.data.signedURLs.url(for: media.originalPath)
        XCTAssertNotNil(memberURL)
    }
}
