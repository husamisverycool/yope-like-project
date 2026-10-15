import AppModels
import Foundation
import XCTest
@testable import AppData

/// Realtime as AppData exposes it: typed events for members, nothing for outsiders
/// (docs/API.md §8, security invariant 1).
final class RealtimeIntegrationTests: XCTestCase {
    private var users: TestUsers!

    override func setUp() async throws {
        try await LocalStack.require()
        users = TestUsers()
    }

    override func tearDown() async throws {
        await users?.cleanUp()
    }

    func testMembersReceiveTypedEventsAndOutsidersNothing() async throws {
        let ana = try await users.make("Ana")
        let rui = try await users.make("Rui")
        let eve = try await users.make("Eve")
        let group = try await ana.data.groups.create(name: "Realtime \(users.runID)", kind: .friends)
        let other = try await ana.data.groups.create(name: "Other \(users.runID)", kind: .friends)
        for target in [group, other] {
            _ = try await rui.data.groups.join(token: try await ana.data.groups.createInvite(groupID: target.id).token)
        }
        _ = try await eve.data.groups.create(name: "Eve's \(users.runID)", kind: .friends)

        let ruiEvents = EventRecorder(rui.data.realtime.events(for: group.id))
        let eveEvents = EventRecorder(eve.data.realtime.events(for: group.id))
        defer {
            ruiEvents.stop()
            eveEvents.stop()
        }
        let changesTopic = "realtime:group-\(group.id.rawValue)"
        let deletionsTopic = "realtime:group:\(group.id.rawValue)"

        // Rui joins both channels; Eve's join of the private deletion topic is refused.
        let joined = await eventually {
            ruiEvents.contains { $0 == .subscribed(topic: changesTopic) } && ruiEvents.contains { $0 == .subscribed(topic: deletionsTopic) }
        }
        XCTAssertTrue(joined, "member subscriptions: \(ruiEvents.events)")
        let refused = await eventually(timeout: 20) { eveEvents.contains { $0 == .subscriptionFailed(topic: deletionsTopic) } }
        XCTAssertTrue(refused, "outsider must not join group:<id>: \(eveEvents.events)")
        XCTAssertFalse(eveEvents.contains { $0 == .subscribed(topic: deletionsTopic) })

        // Postgres changes need a moment after the join; probe until one arrives.
        let ready = await eventually(timeout: 20) {
            _ = try? await ana.data.chat.sendText(groupID: group.id, body: "probe")
            try? await Task.sleep(nanoseconds: 700_000_000)
            return ruiEvents.contains { if case let .messageInserted(message) = $0 { return message.body == "probe" }; return false }
        }
        XCTAssertTrue(ready, "postgres_changes never delivered: \(ruiEvents.events)")

        // Inserts: post (+ its photo message), text message, reaction.
        let file = try temporaryFile(tinyJPEG, extension: "jpg")
        let posts = try await ana.data.publisher.publish(PostDraft(kind: .photo, original: .init(url: file, contentType: ContentType.jpeg), groupIDs: [group.id]))
        let post = try XCTUnwrap(posts.first)
        let reply = try await ana.data.chat.sendText(groupID: group.id, body: "about that photo", replyToPostID: post.id)
        let goodbye = try await ana.data.chat.sendText(groupID: group.id, body: "to be deleted")
        try await ana.data.reactions.react(postID: post.id, emoji: "🌅")
        _ = try await ana.data.chat.sendText(groupID: other.id, body: "other group")

        let inserted = await eventually {
            ruiEvents.contains { if case let .postInserted(p) = $0 { return p.id == post.id && p.authorID == ana.id }; return false }
                && ruiEvents.contains { if case let .messageInserted(m) = $0 { return m.kind == .photo && m.postID == post.id }; return false }
                && ruiEvents.contains { if case let .messageInserted(m) = $0 { return m.id == reply.id }; return false }
                && ruiEvents.contains { if case let .reactionInserted(r) = $0 { return r.postID == post.id && r.emoji == "🌅" && r.userID == ana.id }; return false }
        }
        XCTAssertTrue(inserted, "missing inserts: \(ruiEvents.events)")

        // Deletions arrive on the private topic; a reply losing its photo arrives as an update.
        try await ana.data.reactions.unreact(postID: post.id, emoji: "🌅")
        try await ana.data.chat.delete(messageID: goodbye.id, groupID: group.id)
        try await ana.data.posts.deletePost(id: post.id)
        let deleted = await eventually {
            ruiEvents.contains { $0 == .reactionsChanged(post.id) }
                && ruiEvents.contains { $0 == .messageDeleted(goodbye.id) }
                && ruiEvents.contains { $0 == .postDeleted(postID: post.id, mediaID: post.mediaID) }
                && ruiEvents.contains { if case let .messageUpdated(m) = $0 { return m.id == reply.id && m.replyToPostID == nil }; return false }
        }
        XCTAssertTrue(deleted, "missing deletion events: \(ruiEvents.events)")
        XCTAssertFalse(ruiEvents.contains { if case let .messageInserted(m) = $0 { return m.body == "other group" }; return false },
                       "events are filtered by group")

        // The outsider received no data at all.
        try await Task.sleep(nanoseconds: 1_500_000_000)
        let leaked = eveEvents.events.filter {
            switch $0 {
            case .subscribed, .subscriptionFailed: return false
            default: return true
            }
        }
        XCTAssertEqual(leaked, [], "an outsider must receive nothing of the group")

        // After leaving, Rui gets nothing more from the group.
        try await rui.data.groups.leave(groupID: group.id)
        let countAfterLeaving = ruiEvents.events.count
        _ = try await ana.data.chat.sendText(groupID: group.id, body: "after leaving")
        try await Task.sleep(nanoseconds: 2_500_000_000)
        XCTAssertFalse(ruiEvents.events.dropFirst(countAfterLeaving).contains {
            if case let .messageInserted(m) = $0 { return m.body == "after leaving" }
            return false
        })
    }

    func testHubSharesOneChannelPerTopicAndClosesIt() async throws {
        let ana = try await users.make("Ana")
        let group = try await ana.data.groups.create(name: "Shared \(users.runID)", kind: .friends)
        let first = EventRecorder(ana.data.realtime.events(for: group.id, filter: .deletions))
        let second = EventRecorder(ana.data.realtime.events(for: group.id, filter: .deletions))
        let topic = "realtime:group:\(group.id.rawValue)"
        let both = await eventually {
            first.contains { $0 == .subscribed(topic: topic) } && second.contains { $0 == .subscribed(topic: topic) }
        }
        XCTAssertTrue(both, "\(first.events) / \(second.events)")
        XCTAssertEqual(ana.client.supabase.channels.map(\.topic), [topic], "one channel for both subscribers")

        let file = try temporaryFile(tinyJPEG, extension: "jpg")
        let posts = try await ana.data.publisher.publish(PostDraft(kind: .photo, original: .init(url: file, contentType: ContentType.jpeg), groupIDs: [group.id]))
        try await ana.data.posts.deletePost(id: posts[0].id)
        let delivered = await eventually {
            first.contains { $0 == .postDeleted(postID: posts[0].id, mediaID: posts[0].mediaID) }
                && second.contains { $0 == .postDeleted(postID: posts[0].id, mediaID: posts[0].mediaID) }
        }
        XCTAssertTrue(delivered)

        first.stop()
        second.stop()
        let closed = await eventually { await ana.data.realtime.subscribedGroups().isEmpty && ana.client.supabase.channels.isEmpty }
        XCTAssertTrue(closed, "the channel closes with its last subscriber")
    }
}
