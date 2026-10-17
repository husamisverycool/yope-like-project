import AppModels
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import XCTest
@testable import AppData

/// Selfie reactions and overnight photos (docs/API.md §14.1, §14.3): wire formats (no network), then the repositories
/// against the local Supabase stack (skipped when it is not reachable).
final class SelfieOvernightCodingTests: XCTestCase {
    func testSelfieReactionDecodesAPIRow() throws {
        let json = """
        {"id":"0B2E3C2A-1D4F-4E7A-9B1C-2D3E4F5A6B7C","post_id":"8b2e3c2a-1d4f-4e7a-9b1c-2d3e4f5a6b7c",
         "user_id":"9f1c1d2e-0000-4000-8000-000000000002","group_id":"9f1c1d2e-0000-4000-8000-000000000003",
         "image_path":"u/9f1c1d2e-0000-4000-8000-000000000002/selfies/a.jpg","created_at":"2026-10-16T08:00:00.123456+00:00"}
        """
        let row = try DataCoding.makeDecoder().decode(SelfieReaction.self, from: Data(json.utf8))
        XCTAssertEqual(row.id.rawValue, "0b2e3c2a-1d4f-4e7a-9b1c-2d3e4f5a6b7c")
        XCTAssertEqual(row.postID, PostID("8b2e3c2a-1d4f-4e7a-9b1c-2d3e4f5a6b7c"))
        XCTAssertEqual(row.imagePath, "u/9f1c1d2e-0000-4000-8000-000000000002/selfies/a.jpg")
        XCTAssertEqual(row.createdAt, Timestamp.parse("2026-10-16T08:00:00.123456Z"))
    }

    func testOvernightRowsDecode() throws {
        let status = try DataCoding.makeDecoder().decode([OvernightStatus].self, from: Data(#"[{"developing":true,"reveal_at":"2026-10-17T07:00:00+00:00"}]"#.utf8))
        XCTAssertEqual(status, [OvernightStatus(developing: true, revealAt: Timestamp.parse("2026-10-17T07:00:00Z"))])
        let none = try DataCoding.makeDecoder().decode([OvernightStatus].self, from: Data(#"[{"developing":false,"reveal_at":null}]"#.utf8))
        XCTAssertEqual(none.first, .notDeveloping)
        let developing = try DataCoding.makeDecoder().decode(
            [DevelopingPost].self,
            from: Data(#"[{"group_id":"9F1C1D2E-0000-4000-8000-000000000003","develops_at":"2026-10-17T07:00:00Z"}]"#.utf8)
        )
        XCTAssertEqual(developing.first?.groupID, GroupID("9f1c1d2e-0000-4000-8000-000000000003"))
    }

    func testNotificationSettingsDefaultOvernightOn() throws {
        let old = #"{"user_id":"9f1c1d2e-0000-4000-8000-000000000002","quiet_start":null,"quiet_end":null,"time_zone":null,"updated_at":"2026-10-16T08:00:00Z"}"#
        XCTAssertTrue(try DataCoding.makeDecoder().decode(NotificationSettings.self, from: Data(old.utf8)).overnight)
        let off = #"{"user_id":"9f1c1d2e-0000-4000-8000-000000000002","quiet_start":"22:00:00","quiet_end":"07:00:00","time_zone":"UTC","updated_at":"2026-10-16T08:00:00Z","overnight":false}"#
        let settings = try DataCoding.makeDecoder().decode(NotificationSettings.self, from: Data(off.utf8))
        XCTAssertFalse(settings.overnight)
        XCTAssertEqual(settings.quietStart, LocalTime(hour: 22, minute: 0))
    }

    /// The opt-in memory notification (migration 0049): off when the column is missing (older offline copies), else as sent.
    func testNotificationSettingsMemoriesDefaultOff() throws {
        let old = #"{"user_id":"9f1c1d2e-0000-4000-8000-000000000002","quiet_start":null,"quiet_end":null,"time_zone":null,"updated_at":"2026-10-16T08:00:00Z"}"#
        let before = try DataCoding.makeDecoder().decode(NotificationSettings.self, from: Data(old.utf8))
        XCTAssertFalse(before.memories)
        XCTAssertNil(before.memoryTimeZone)
        let on = #"{"user_id":"9f1c1d2e-0000-4000-8000-000000000002","quiet_start":null,"quiet_end":null,"time_zone":null,"updated_at":"2026-10-16T08:00:00Z","memories":true,"memory_time_zone":"Europe/Lisbon"}"#
        let settings = try DataCoding.makeDecoder().decode(NotificationSettings.self, from: Data(on.utf8))
        XCTAssertTrue(settings.memories)
        XCTAssertEqual(settings.memoryTimeZone, "Europe/Lisbon")
    }

    func testSelfiePathAndReportKind() {
        let owner = UserID("9F1C1D2E-0000-4000-8000-000000000002")
        let id = UUID(uuidString: "7C9E6679-7425-40DE-944B-E07FC1F90AE7")!
        let path = StoragePaths.selfie(owner: owner, id: id)
        XCTAssertEqual(path, "u/9f1c1d2e-0000-4000-8000-000000000002/selfies/7c9e6679-7425-40de-944b-e07fc1f90ae7.jpg")
        XCTAssertTrue(StoragePaths.isSafe(path))
        XCTAssertEqual(ReportTargetKind(rawValue: "selfie"), .selfie)
    }

    func testDraftsSavedBeforeOvernightStillDecode() throws {
        let draft = PostDraft(
            kind: .photo, original: .init(url: URL(fileURLWithPath: "/tmp/original.jpg"), contentType: ContentType.jpeg),
            groupIDs: [GroupID("9f1c1d2e-0000-4000-8000-000000000003")]
        )
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: DataCoding.makeEncoder().encode(draft)) as? [String: Any])
        object.removeValue(forKey: "overnight")
        let decoded = try DataCoding.makeDecoder().decode(PostDraft.self, from: JSONSerialization.data(withJSONObject: object))
        XCTAssertNil(decoded.overnight)
        var overnight = draft
        overnight.overnight = true
        let roundTrip = try DataCoding.makeDecoder().decode(PostDraft.self, from: DataCoding.makeEncoder().encode(overnight))
        XCTAssertEqual(roundTrip.overnight, true)
    }
}

final class SelfieOvernightIntegrationTests: XCTestCase {
    private var users: TestUsers!

    override func setUp() async throws {
        try await LocalStack.require()
        users = TestUsers()
    }

    override func tearDown() async throws {
        await users?.cleanUp()
    }

    /// A group of Ana's that Rui joined, and one photo Ana posted to it.
    private func groupWithPost(_ ana: TestUser, _ rui: TestUser) async throws -> (group: PhotoGroup, post: Post) {
        let group = try await ana.data.groups.create(name: "Roommates \(users.runID)", kind: .roommates, timeZone: "Europe/Paris")
        _ = try await ana.data.groups.setInvitationPaused(groupID: group.id, paused: true)
        _ = try await rui.data.groups.join(token: try await ana.data.groups.createInvite(groupID: group.id).token)
        let file = try temporaryFile(tinyJPEG, extension: "jpg")
        let posted = try await ana.data.publisher.publish(PostDraft(kind: .photo, original: .init(url: file, contentType: ContentType.jpeg), groupIDs: [group.id]))
        return (group, try XCTUnwrap(posted.first))
    }

    func testSelfieReactionsReplaceRemoveAndReport() async throws {
        let ana = try await users.make("Ana")
        let rui = try await users.make("Rui")
        let (group, post) = try await groupWithPost(ana, rui)

        // Rui reacts: the image is his upload, the row is readable by Ana, and so is the file.
        let first = try await rui.data.selfies.react(postID: post.id, jpeg: tinyJPEG)
        XCTAssertEqual(first.userID, rui.id)
        XCTAssertEqual(first.groupID, group.id)
        XCTAssertTrue(first.imagePath.hasPrefix("u/\(rui.id.rawValue)/selfies/"))
        let seen = try await ana.data.selfies.selfies(postIDs: [post.id])
        XCTAssertEqual(seen.map(\.id), [first.id])
        let url = try await ana.data.signedURLs.url(for: first.imagePath)
        let (bytes, response) = try await URLSession.shared.data(from: url)
        XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 200)
        XCTAssertEqual(bytes, tinyJPEG)

        // One per person and post: a new selfie replaces his.
        let second = try await rui.data.selfies.react(postID: post.id, jpeg: tinyJPEG)
        XCTAssertNotEqual(second.imagePath, first.imagePath)
        let replaced = try await ana.data.selfies.selfies(postID: post.id)
        XCTAssertEqual(replaced.map(\.imagePath), [second.imagePath])

        // The author cannot react to her own post, and the image must be the caller's upload.
        await assertThrows(.database(code: "PT400", message: "own_post")) {
            try await ana.data.selfies.react(postID: post.id, jpeg: tinyJPEG)
        }
        await assertThrows(.database(code: "PT400", message: "invalid_image")) {
            try await ana.data.selfies.react(postID: post.id, imagePath: second.imagePath)
        }

        // Report (target kind 'selfie', by the row's id).
        let reportID = try await ana.data.safety.report(.selfie, targetID: second.id.rawValue, reason: "test report")
        XCTAssertNotNil(reportID.uuid)

        // Only the author may remove someone else's; Rui removes his own, then Ana removes his next one.
        await assertThrows(.api(.notAllowed)) {
            try await rui.data.selfies.remove(postID: post.id, userID: ana.id)
        }
        try await rui.data.selfies.remove(postID: post.id)
        let afterOwn = try await ana.data.selfies.selfies(postID: post.id)
        XCTAssertTrue(afterOwn.isEmpty)
        _ = try await rui.data.selfies.react(postID: post.id, jpeg: tinyJPEG)
        try await ana.data.selfies.remove(postID: post.id, userID: rui.id)
        let afterAuthor = try await rui.data.selfies.selfies(postID: post.id)
        XCTAssertTrue(afterAuthor.isEmpty)
    }

    func testOvernightPhotoDevelopsLaterAndAlertsSwitch() async throws {
        let ana = try await users.make("Ana")
        let rui = try await users.make("Rui")
        let (group, _) = try await groupWithPost(ana, rui)
        let before = try await ana.data.posts.myDeveloping()
        XCTAssertEqual(before, .notDeveloping)

        // A 9 AM photo goes through the outbox like any post, then develops: nobody sees a post yet.
        let file = try temporaryFile(tinyJPEG, extension: "jpg")
        let draft = PostDraft(kind: .photo, original: .init(url: file, contentType: ContentType.jpeg), width: 1, height: 1, groupIDs: [group.id], overnight: true)
        let posted = try await ana.data.publisher.publish(draft)
        XCTAssertTrue(posted.isEmpty)
        let pending = await ana.data.publisher.pending()
        XCTAssertTrue(pending.isEmpty, "a developing photo leaves the outbox")
        let developing = try await ana.data.posts.myDeveloping()
        XCTAssertTrue(developing.developing)
        let reveal = try XCTUnwrap(developing.revealAt)
        XCTAssertGreaterThan(reveal, Date())
        var paris = Calendar(identifier: .gregorian)
        paris.timeZone = TimeZone(identifier: "Europe/Paris")!
        XCTAssertEqual(paris.component(.hour, from: reveal), 9)
        XCTAssertEqual(paris.component(.minute, from: reveal), 0)
        let feed = try await rui.data.posts.page(groupID: group.id).items
        XCTAssertFalse(feed.contains { $0.mediaID == draft.mediaID }, "nobody reads it before the reveal")

        // A replay (lost response) is accepted.
        let replay = try await ana.data.publisher.publish(draft)
        XCTAssertTrue(replay.isEmpty)

        // Overnight alerts: on by default, off by the switch, kept when quiet hours change.
        let off = try await ana.data.account.setOvernightAlerts(false)
        XCTAssertFalse(off.overnight)
        _ = try await ana.data.account.setQuietHours(start: LocalTime(hour: 22, minute: 0), end: LocalTime(hour: 7, minute: 0), timeZone: "UTC")
        let stored = try await ana.data.account.notificationSettings()
        XCTAssertEqual(stored?.overnight, false)
        let on = try await ana.data.account.setOvernightAlerts(true)
        XCTAssertTrue(on.overnight)
    }

    /// Realtime: a selfie arrives as an upsert, its removal as `reactions_changed`, a photo set to develop as
    /// `developing_changed`.
    func testRealtimeDeliversSelfiesAndDevelopingChanges() async throws {
        try await LocalStack.requireWebSockets()
        let ana = try await users.make("Ana")
        let rui = try await users.make("Rui")
        let (group, post) = try await groupWithPost(ana, rui)
        let events = EventRecorder(ana.data.realtime.events(for: group.id, filter: .all))
        defer { events.stop() }
        let joined = await eventually {
            events.contains { $0 == .subscribed(topic: "realtime:group:\(group.id.rawValue)") }
                && events.contains { $0 == .subscribed(topic: "realtime:group-\(group.id.rawValue)") }
        }
        XCTAssertTrue(joined, "\(events.events)")

        let selfie = try await rui.data.selfies.react(postID: post.id, jpeg: tinyJPEG)
        let upserted = await eventually {
            events.contains { if case let .selfieReactionUpserted(row) = $0 { return row.id == selfie.id }; return false }
        }
        XCTAssertTrue(upserted, "\(events.events)")
        try await rui.data.selfies.remove(postID: post.id)
        let removed = await eventually { events.contains { $0 == .reactionsChanged(post.id) } }
        XCTAssertTrue(removed, "\(events.events)")

        let file = try temporaryFile(tinyJPEG, extension: "jpg")
        _ = try await rui.data.publisher.publish(
            PostDraft(kind: .photo, original: .init(url: file, contentType: ContentType.jpeg), groupIDs: [group.id], overnight: true)
        )
        let developing = await eventually { events.contains { $0 == .developingChanged } }
        XCTAssertTrue(developing, "\(events.events)")
    }

    func testPhotosRevealedTogetherAreReadOldestFirst() async throws {
        let ana = try await users.make("Ana")
        let rui = try await users.make("Rui")
        let (group, first) = try await groupWithPost(ana, rui)
        let file = try temporaryFile(tinyJPEG, extension: "jpg")
        let posted = try await ana.data.publisher.publish(
            PostDraft(kind: .photo, original: .init(url: file, contentType: ContentType.jpeg), groupIDs: [group.id])
        )
        let second = try XCTUnwrap(posted.first)
        // What the scheduler (`due_developed_posts`) writes at a reveal, set here as the worker would.
        let reveal = try XCTUnwrap(Timestamp.parse("2026-10-17T07:00:00Z"))
        for post in [first, second] {
            try await LocalStack.update("posts", id: post.id.rawValue, ["revealed_at": Timestamp.format(reveal)])
        }
        let together = try await rui.data.posts.revealed(groupID: group.id, at: reveal)
        XCTAssertEqual(together.map(\.id), [first.id, second.id], "oldest first: capture time")
        XCTAssertEqual(together.first?.revealedAt, reveal)
        let feed = try await rui.data.posts.page(groupID: group.id).items
        XCTAssertTrue(feed.allSatisfy { $0.revealedAt == reveal })
    }
}
