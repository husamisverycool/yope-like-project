import AppModels
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import XCTest
@testable import AppData

/// Every repository against the local Supabase stack, in the order a group lives through them:
/// create group → invite → join → upload → create_post to two groups → feed → react → reply →
/// tag → wall → history weeks → on this day → album → recap → birthdays → invitations →
/// collages → year story → settings → delete media → gone everywhere.
final class ScenarioIntegrationTests: XCTestCase {
    private var users: TestUsers!

    override func setUp() async throws {
        try await LocalStack.require()
        users = TestUsers()
    }

    override func tearDown() async throws {
        await users?.cleanUp()
    }

    func testGroupsInvitesAndMembership() async throws {
        let ana = try await users.make("Ana")
        let rui = try await users.make("Rui")

        // Profiles
        let profile = try await ana.data.profiles.updateProfile(displayName: "Ana Lima \(users.runID)")
        XCTAssertEqual(profile.displayName, "Ana Lima \(users.runID)")
        let avatarPath = try await ana.data.uploader.uploadAvatar(jpeg: tinyJPEG)
        XCTAssertTrue(avatarPath.hasPrefix("avatars/\(ana.id.rawValue)/"))
        let withAvatar = try await ana.data.profiles.updateProfile(avatarPath: avatarPath)
        XCTAssertEqual(withAvatar.avatarPath, avatarPath)

        // Create with a cover and waking hours, list, read back.
        let cover = try await ana.data.uploader.uploadCover(jpeg: tinyJPEG)
        let group = try await ana.data.groups.create(
            name: "  Lima \(users.runID)  ", kind: .family, timeZone: "Europe/Paris", coverPath: cover,
            wakingStart: LocalTime(hour: 9, minute: 0), wakingEnd: LocalTime(hour: 21, minute: 0)
        )
        XCTAssertEqual(group.name, "Lima \(users.runID)", "the server trims the name")
        XCTAssertEqual(group.coverPath, cover)
        XCTAssertEqual(group.wakingStart, LocalTime(hour: 9, minute: 0))
        let mine = try await ana.data.groups.myGroups()
        XCTAssertEqual(mine.map(\.id), [group.id])
        let value1 = await ana.data.groups.cachedGroups()?.value.map(\.id)
        XCTAssertEqual(value1, [group.id], "cached for offline")

        // Errors are typed.
        await assertThrows(.api(.invalidName)) { try await ana.data.groups.create(name: " ", kind: .friends) }
        await assertThrows(.api(.invalidTimeZone)) { try await ana.data.groups.create(name: "x", kind: .friends, timeZone: "Mars/Base") }

        // Invite: create, preview (signed out), join, list members.
        let invite = try await ana.data.groups.createInvite(groupID: group.id)
        XCTAssertEqual(invite.token.count, 24)
        XCTAssertEqual(invite.link(domain: "example.com")?.absoluteString, "https://example.com/i/\(invite.token)")
        let anonymous = AppData.GroupRepository(client: DataClient(configuration: LocalStack.configuration) { nil })
        let preview = try await anonymous.invitePreview(token: invite.token)
        XCTAssertEqual(preview.groupName, group.name)
        XCTAssertEqual(preview.groupKind, .family)
        XCTAssertEqual(preview.inviterFirstName, "Ana")
        XCTAssertEqual(preview.members.count, 1)
        let active = try await ana.data.groups.activeInvites(groupID: group.id)
        XCTAssertEqual(active.map(\.token), [invite.token])

        let joined = try await rui.data.groups.join(token: invite.token)
        XCTAssertEqual(joined.id, group.id)
        let again = try await rui.data.groups.join(token: invite.token)
        XCTAssertEqual(again.id, group.id, "join is idempotent")
        let members = try await ana.data.groups.members(groupID: group.id)
        XCTAssertEqual(members.map(\.member.userID), [ana.id, rui.id])
        XCTAssertEqual(members.first?.member.role, .admin)
        XCTAssertEqual(members.last?.profile?.firstName, "Rui")
        let value2 = try await rui.data.groups.myMembership(groupID: group.id)?.role
        XCTAssertEqual(value2, .member)

        // Revoke: the link stops working for new people.
        try await ana.data.groups.revokeInvite(token: invite.token)
        await assertThrows(.api(.inviteRevoked)) { try await anonymous.invitePreview(token: invite.token) }
        await assertThrows(.api(.inviteNotFound)) { try await anonymous.invitePreview(token: "nope-nope-nope-nope-nope") }

        // Settings: mute, invitation hours, pause, rename (admins), member-only refusals.
        try await rui.data.groups.setMuted(groupID: group.id, muted: true)
        let value3 = try await rui.data.groups.myMembership(groupID: group.id)?.muted
        XCTAssertEqual(value3, true)
        let hours = try await ana.data.groups.setInvitationHours(groupID: group.id, start: LocalTime(hour: 22, minute: 0), end: LocalTime(hour: 7, minute: 0))
        XCTAssertEqual(hours.wakingStart, LocalTime(hour: 22, minute: 0))
        let defaults = try await ana.data.groups.setInvitationHours(groupID: group.id, start: nil, end: nil)
        XCTAssertNil(defaults.wakingStart)
        let value4 = try await ana.data.groups.setInvitationPaused(groupID: group.id, paused: true).invitationPaused
        XCTAssertTrue(value4)
        await assertThrows(.api(.notGroupAdmin)) {
            try await rui.data.groups.setInvitationPaused(groupID: group.id, paused: false)
        }
        await assertThrows(.api(.invalidWakingWindow)) {
            try await ana.data.groups.setInvitationHours(groupID: group.id, start: LocalTime(hour: 9, minute: 0), end: nil)
        }
        let renamed = try await ana.data.groups.update(groupID: group.id, name: "Renamed \(users.runID)", cover: .remove)
        XCTAssertEqual(renamed.name, "Renamed \(users.runID)")
        XCTAssertNil(renamed.coverPath)
        await assertThrows(.api(.notGroupAdmin)) { try await rui.data.groups.update(groupID: group.id, name: "Nope") }

        // Remove, then leave: the last member leaving deletes the group.
        await assertThrows(.api(.cannotTargetSelf)) { try await ana.data.groups.removeMember(groupID: group.id, userID: ana.id) }
        try await ana.data.groups.removeMember(groupID: group.id, userID: rui.id)
        let value5 = try await rui.data.groups.myGroups().isEmpty
        XCTAssertTrue(value5)
        try await ana.data.groups.leave(groupID: group.id)
        let value6 = try await ana.data.groups.myGroups().isEmpty
        XCTAssertTrue(value6)
        let value7 = await ana.data.groups.cachedGroups()?.value.first { $0.id == group.id }
        XCTAssertNil(value7)
    }

    func testPostingBrowsingAndDeletingEverywhere() async throws {
        let ana = try await users.make("Ana")
        let rui = try await users.make("Rui")
        let g1 = try await ana.data.groups.create(name: "Family \(users.runID)", kind: .family, timeZone: "Europe/Paris")
        let g2 = try await ana.data.groups.create(name: "Friends \(users.runID)", kind: .friends, timeZone: "Europe/Paris")
        // Paused, so a scheduler running against the shared stack does not add invitations of its own.
        _ = try await ana.data.groups.setInvitationPaused(groupID: g1.id, paused: true)
        for group in [g1, g2] {
            let invite = try await ana.data.groups.createInvite(groupID: group.id)
            _ = try await rui.data.groups.join(token: invite.token)
        }

        // Upload a JPEG (+ a voice note) and post it to both groups through the outbox.
        let photo = try temporaryFile(tinyJPEG, extension: "jpg")
        let voice = try temporaryFile(Data(repeating: 0x41, count: 2048), extension: "m4a")
        let draft = PostDraft(
            kind: .photo,
            original: .init(url: photo, contentType: ContentType.jpeg),
            width: 1, height: 1,
            voice: .init(url: voice, contentType: ContentType.m4a), voiceDurationMs: 1500,
            groupIDs: [g1.id, g2.id],
            caption: "first light"
        )
        let posted = try await ana.data.publisher.publish(draft)
        XCTAssertEqual(Set(posted.map(\.groupID)), [g1.id, g2.id])
        XCTAssertTrue(posted.allSatisfy { $0.mediaID == draft.mediaID && $0.caption == "first light" && $0.voiceDurationMs == 1500 })
        XCTAssertEqual(posted.first?.voicePath, StoragePaths.postVoice(owner: ana.id, media: draft.mediaID))
        let value8 = await ana.data.publisher.pending().isEmpty
        XCTAssertTrue(value8, "posted drafts leave the outbox")
        let post1 = try XCTUnwrap(posted.first { $0.groupID == g1.id })
        let post2 = try XCTUnwrap(posted.first { $0.groupID == g2.id })

        // Replaying the same draft is idempotent (lost response): same posts, no error.
        let replay = try await ana.data.publisher.publish(draft)
        XCTAssertEqual(Set(replay.map(\.id)), Set(posted.map(\.id)))

        // Feed pagination (three more posts in g1, page size 2).
        var later: [Post] = []
        for index in 0..<3 {
            let file = try temporaryFile(tinyJPEG, extension: "jpg")
            later += try await ana.data.publisher.publish(PostDraft(kind: .photo, original: .init(url: file, contentType: ContentType.jpeg), groupIDs: [g1.id], caption: "p\(index)"))
        }
        let page1 = try await rui.data.posts.page(groupID: g1.id, limit: 2)
        XCTAssertEqual(page1.items.map(\.id), [later[2].id, later[1].id])
        let page2 = try await rui.data.posts.page(groupID: g1.id, before: try XCTUnwrap(page1.nextCursor), limit: 2)
        XCTAssertEqual(page2.items.map(\.id), [later[0].id, post1.id])
        let page3 = try await rui.data.posts.page(groupID: g1.id, before: try XCTUnwrap(page2.nextCursor), limit: 2)
        XCTAssertTrue(page3.items.isEmpty)
        XCTAssertNil(page3.nextCursor)
        let feed = try await rui.data.posts.feed(groupID: g1.id)
        XCTAssertEqual(feed.items.count, 4)
        XCTAssertEqual(feed.items.last?.media?.originalPath, StoragePaths.original(owner: ana.id, media: draft.mediaID, fileExtension: "jpg"))
        let value9 = await rui.data.posts.cachedFeed(groupID: g1.id)?.value.count
        XCTAssertEqual(value9, 4)

        // Signed URL: Rui (a member) can read Ana's original; the URL is reused until expiry.
        let media = try XCTUnwrap(feed.items.last?.media)
        // The original (a shared worker may already have made renditions).
        let path = media.originalPath
        let signed = try await rui.data.signedURLs.url(for: path)
        let again = try await rui.data.signedURLs.url(for: path)
        XCTAssertEqual(signed, again, "cached until expiry")
        let (bytes, response) = try await URLSession.shared.data(from: signed)
        XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 200)
        XCTAssertEqual(bytes, tinyJPEG)
        let thumb = try XCTUnwrap(media.imagePath(for: .thumb))
        let batch = try await rui.data.signedURLs.urls(for: [path, thumb])
        XCTAssertNotNil(batch[path])
        XCTAssertNotNil(batch[thumb])

        // Reactions: rows (user, emoji), several emoji per person, idempotent, unreact.
        try await rui.data.reactions.react(postID: post1.id, emoji: "🌅")
        try await rui.data.reactions.react(postID: post1.id, emoji: "👨‍👩‍👧")
        try await rui.data.reactions.react(postID: post1.id, emoji: "🌅")
        try await ana.data.reactions.react(postID: post1.id, emoji: "❤️")
        let reactions = try await ana.data.reactions.reactions(postID: post1.id)
        XCTAssertEqual(Set(reactions.map { "\($0.userID.rawValue):\($0.emoji)" }),
                       ["\(rui.id.rawValue):🌅", "\(rui.id.rawValue):👨‍👩‍👧", "\(ana.id.rawValue):❤️"])
        await assertThrows(.api(.invalidEmoji)) { try await rui.data.reactions.react(postID: post1.id, emoji: "ok") }
        try await rui.data.reactions.unreact(postID: post1.id, emoji: "👨‍👩‍👧")
        let value10 = try await ana.data.reactions.reactions(postIDs: [post1.id, post2.id]).count
        XCTAssertEqual(value10, 2)

        // Chat: reply to the photo with text, reply to a message, then a photo reply.
        let text = try await rui.data.chat.sendText(groupID: g1.id, body: "so good", replyToPostID: post1.id)
        XCTAssertEqual(text.kind, .text)
        XCTAssertEqual(text.replyToPostID, post1.id)
        let answer = try await ana.data.chat.sendText(groupID: g1.id, body: "thanks", replyToMessageID: text.id)
        XCTAssertEqual(answer.replyToMessageID, text.id)
        await assertThrows(.api(.replyGroupMismatch)) {
            try await rui.data.chat.sendText(groupID: g2.id, body: "wrong group", replyToPostID: post1.id)
        }
        await assertThrows(.api(.invalidBody)) { try await rui.data.chat.sendText(groupID: g1.id, body: "   ") }
        let voicePath = try await rui.data.uploader.uploadChatVoice(fileURL: try temporaryFile(Data(repeating: 1, count: 512), extension: "m4a"))
        let voiceMessage = try await rui.data.chat.sendVoice(groupID: g1.id, voicePath: voicePath, durationMs: 900)
        XCTAssertEqual(voiceMessage.kind, .voice)
        let value11 = try await ana.data.signedURLs.url(for: voicePath)
        XCTAssertNotNil(value11, "members read chat voice notes")
        let replyFile = try temporaryFile(tinyJPEG, extension: "jpg")
        let photoReply = try await rui.data.publisher.publish(PostDraft(
            kind: .photo, original: .init(url: replyFile, contentType: ContentType.jpeg), groupIDs: [g1.id], replyToPostID: post1.id
        ))
        XCTAssertEqual(photoReply.first?.replyToPostID, post1.id)
        let chat = try await ana.data.chat.page(groupID: g1.id)
        XCTAssertTrue(chat.items.contains { $0.kind == .photo && $0.postID == post1.id }, "create_post adds a photo message")
        XCTAssertTrue(chat.items.contains { $0.id == answer.id })
        try await ana.data.chat.delete(messageID: answer.id, groupID: g1.id)
        let value12 = try await rui.data.chat.message(id: answer.id)
        XCTAssertNil(value12)
        await assertThrows(.api(.messageNotFound)) { try await ana.data.chat.delete(messageID: text.id, groupID: g1.id) }

        // Tags.
        let tag = try await rui.data.reactions.tagSelf(postID: post1.id)
        XCTAssertEqual(tag.userID, rui.id)
        let value13 = try await ana.data.reactions.tags(postID: post1.id).map(\.userID)
        XCTAssertEqual(value13, [rui.id])
        let value14 = try await rui.data.reactions.myTags(groupID: g1.id).map(\.postID)
        XCTAssertEqual(value14, [post1.id])

        // Wall: Ana's photo appears once with both shared groups.
        let wall = try await rui.data.memories.wall(userID: ana.id)
        let wallItem = try XCTUnwrap(wall.items.first { $0.mediaID == draft.mediaID })
        XCTAssertEqual(wallItem.itemKind, .post)
        XCTAssertEqual(Set(wallItem.groupIDs), [g1.id, g2.id])
        XCTAssertEqual(wall.items.filter { $0.mediaID == draft.mediaID }.count, 1)
        let wallPage = try await rui.data.memories.wall(userID: ana.id, before: wall.items.first?.createdAt, limit: 1)
        XCTAssertEqual(wallPage.items.count, 1)

        // History weeks.
        let weeks = try await rui.data.memories.historyWeeks(groupID: g1.id)
        XCTAssertEqual(weeks.count, 1)
        XCTAssertTrue(weeks[0].postIDs.contains(post1.id))
        XCTAssertEqual(weeks[0].postIDs.first, post1.id, "chronological within the week")

        // On this day: backdate one post by a year (as the worker / time would).
        let paris = TimeZone(identifier: "Europe/Paris")!
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = paris
        let lastYear = calendar.date(byAdding: .year, value: -1, to: Date())!
        try await LocalStack.update("posts", id: later[0].id.rawValue, ["created_at": Timestamp.format(lastYear)])
        let today = LocalDate(Date(), in: paris)
        let memories = try await rui.data.memories.onThisDay(groupID: g1.id, localDate: today)
        XCTAssertEqual(memories.map(\.postID), [later[0].id])
        XCTAssertEqual(memories.first?.yearsAgo, 1)

        // Albums.
        let album = try await rui.data.memories.saveAlbum(groupID: g1.id, name: "Best \(users.runID)", postIDs: [later[1].id, post1.id])
        let renamed = try await ana.data.memories.renameAlbum(id: album.id, name: "Best of")
        XCTAssertEqual(renamed.name, "Best of")
        var albums = try await ana.data.memories.albums(groupID: g1.id)
        XCTAssertEqual(albums.first?.postIDs, [later[1].id, post1.id])
        await assertThrows(.api(.invalidItems)) { try await rui.data.memories.saveAlbum(groupID: g1.id, name: "x", postIDs: [post2.id]) }

        // Weekly recap (row written by the worker; members edit it).
        let monday = today.adding(days: -((calendar.component(.weekday, from: Date()) + 5) % 7))
        let recapRow = try await LocalStack.insert("weekly_recaps", [
            "group_id": g1.id.rawValue, "week_start": monday.description,
            "items": [post1.id.rawValue, later[1].id.rawValue, later[2].id.rawValue], "status": "ready",
            "text": "A week", "generated_at": Timestamp.format(Date()),
        ])
        let recapID = RecapID(try XCTUnwrap(recapRow["id"] as? String))
        let recaps = try await rui.data.memories.recaps(groupID: g1.id)
        XCTAssertEqual(recaps.map(\.id), [recapID])
        let edited = try await rui.data.memories.updateRecap(id: recapID, items: [later[2].id, post1.id], text: "Our week")
        XCTAssertEqual(edited.items, [later[2].id, post1.id])
        XCTAssertEqual(edited.text, "Our week")
        XCTAssertEqual(edited.editedBy, rui.id)
        let value15 = try await rui.data.memories.updateRecap(id: recapID, text: "").text
        XCTAssertEqual(value15, nil, "\"\" clears the text")

        // Birthdays: a request about Ana is visible to Rui only; Rui contributes his own photo.
        let birthday = try await ana.data.birthdays.setBirthday(LocalDate(year: 1990, month: 3, day: 3)!, optIn: true)
        XCTAssertTrue(birthday.birthdayOptIn)
        await assertThrows(.api(.invalidBirthday)) { try await ana.data.birthdays.setBirthday(nil, optIn: true) }
        let requestRow = try await LocalStack.insert("tribute_requests", [
            "group_id": g1.id.rawValue, "honoree_id": ana.id.rawValue,
            "birthday_date": today.adding(days: 5).description,
            "due_at": Timestamp.format(Date().addingTimeInterval(5 * 86_400)),
        ])
        let requestID = TributeRequestID(try XCTUnwrap(requestRow["id"] as? String))
        let value16 = try await rui.data.birthdays.openRequests().map(\.id)
        XCTAssertEqual(value16, [requestID])
        let value17 = try await ana.data.birthdays.openRequests().isEmpty
        XCTAssertTrue(value17, "the honoree never sees the request")
        let ruiPhoto = try XCTUnwrap(photoReply.first)
        await assertThrows(.api(.postNotEligible)) {
            try await rui.data.birthdays.contribute(requestID: requestID, postID: later[1].id, line: "hi")
        }
        let contribution = try await rui.data.birthdays.contribute(requestID: requestID, postID: ruiPhoto.id, line: "  Happy birthday!  ")
        XCTAssertEqual(contribution.line, "Happy birthday!")
        let tagged = try await rui.data.birthdays.contribute(requestID: requestID, postID: post1.id, line: "In this one")
        XCTAssertEqual(tagged.id, contribution.id, "one contribution per person, replaced")
        let value18 = try await rui.data.birthdays.myContribution(requestID: requestID)?.postID
        XCTAssertEqual(value18, post1.id)
        let value19 = try await rui.data.birthdays.eligiblePostIDs(groupID: g1.id).sorted()
        XCTAssertEqual(value19, [ruiPhoto.id, post1.id].sorted())
        try await rui.data.birthdays.withdraw(requestID: requestID)
        let value20 = try await rui.data.birthdays.myContribution(requestID: requestID)
        XCTAssertNil(value20)
        let tributeRow = try await LocalStack.insert("tributes", [
            "request_id": requestID.rawValue, "group_id": g1.id.rawValue, "honoree_id": ana.id.rawValue,
            "status": "ready", "delivered_at": Timestamp.format(Date().addingTimeInterval(-60)),
        ])
        let value21 = try await ana.data.birthdays.tributesForMe().map(\.id.rawValue)
        XCTAssertEqual(value21, [try XCTUnwrap(tributeRow["id"] as? String)])

        // Daily invitation: open now → in-window answer; collage of the day.
        // A past local day the scheduler never uses (it schedules today and tomorrow only).
        let invitationDay = today.adding(days: -2)
        let invitationRow = try await LocalStack.insert("daily_invitations", [
            "group_id": g1.id.rawValue, "local_date": invitationDay.description,
            "fires_at": Timestamp.format(Date().addingTimeInterval(-30)),
            "closes_at": Timestamp.format(Date().addingTimeInterval(90)), "status": "fired",
        ])
        let invitationID = InvitationID(try XCTUnwrap(invitationRow["id"] as? String))
        let value22 = try await rui.data.invitations.currentInvitation(groupID: g1.id)
        let current = try XCTUnwrap(value22)
        XCTAssertEqual(current.id, invitationID)
        XCTAssertTrue(current.isOpen())
        let value23 = try await rui.data.invitations.myAnswer(invitationID: invitationID)
        XCTAssertNil(value23)
        let answerFile = try temporaryFile(tinyJPEG, extension: "jpg")
        let answerPosts = try await rui.data.publisher.publish(PostDraft(
            kind: .photo, original: .init(url: answerFile, contentType: ContentType.jpeg),
            groupIDs: [g1.id, g2.id], invitationID: invitationID
        ))
        XCTAssertEqual(answerPosts.first { $0.groupID == g1.id }?.inWindow, true)
        XCTAssertEqual(answerPosts.first { $0.groupID == g2.id }?.inWindow, false, "other groups get an ordinary post")
        let value24 = try await rui.data.invitations.myAnswer(invitationID: invitationID)?.groupID
        XCTAssertEqual(value24, g1.id)
        let value25 = try await ana.data.invitations.answers(invitationID: invitationID).count
        XCTAssertEqual(value25, 1)
        let collageRow = try await LocalStack.insert("collages", [
            "group_id": g1.id.rawValue, "invitation_id": invitationID.rawValue, "option": "B",
            "post_ids": [answerPosts[0].id.rawValue, post1.id.rawValue],
            "image_path": "g/\(g1.id.rawValue)/collages/x/image.jpg", "status": "ready",
            "composed_at": Timestamp.format(Date()),
        ])
        let collageID = CollageID(try XCTUnwrap(collageRow["id"] as? String))
        XCTAssertEqual(collageRow["page_count"] as? Int, 1, "migration 0015 default")
        let value26 = try await ana.data.memories.collages(groupID: g1.id, localDate: invitationDay).map(\.id)
        XCTAssertEqual(value26, [collageID])
        let value27 = try await ana.data.memories.collage(invitationID: invitationID)?.id
        XCTAssertEqual(value27, collageID)
        let value28 = try await ana.data.memories.collages(groupID: g1.id).items.map(\.id)
        XCTAssertEqual(value28, [collageID])

        // Year story.
        _ = try await LocalStack.insert("year_stories", [
            "group_id": g1.id.rawValue, "year": 2026, "status": "ready",
            "data": ["pages": [["kind": "cover"]]], "post_ids": [post1.id.rawValue],
        ])
        let value29 = try await rui.data.memories.yearStory(groupID: g1.id, year: 2026)
        let story = try XCTUnwrap(value29)
        XCTAssertEqual(story.postIDs, [post1.id])
        XCTAssertEqual(story.data?["pages"], .array([.object(["kind": .string("cover")])]))

        // Delete the media: gone from both groups, chat, reactions, tags, album, recap, wall,
        // weeks, collage, year story and storage reads — for every member.
        try await ana.data.posts.deleteMedia(id: draft.mediaID)
        let value30 = try await rui.data.posts.post(id: post1.id)
        XCTAssertNil(value30)
        let value31 = try await rui.data.posts.post(id: post2.id)
        XCTAssertNil(value31)
        let value32 = try await rui.data.posts.posts(mediaID: draft.mediaID).isEmpty
        XCTAssertTrue(value32)
        let value33 = try await rui.data.posts.media(ids: [draft.mediaID]).isEmpty
        XCTAssertTrue(value33)
        let value34 = try await rui.data.chat.page(groupID: g1.id).items.contains { $0.postID == post1.id }
        XCTAssertFalse(value34)
        let value35 = try await rui.data.chat.message(id: text.id)?.replyToPostID
        XCTAssertNil(value35, "replies stay, detached")
        let value36 = try await rui.data.chat.message(id: text.id)
        XCTAssertNotNil(value36)
        let value37 = try await rui.data.reactions.reactions(postID: post1.id).isEmpty
        XCTAssertTrue(value37)
        let value38 = try await rui.data.reactions.tags(postID: post1.id).isEmpty
        XCTAssertTrue(value38)
        albums = try await rui.data.memories.albums(groupID: g1.id)
        XCTAssertEqual(albums.first?.postIDs, [later[1].id])
        let value39 = try await rui.data.memories.recap(id: recapID)?.items
        XCTAssertEqual(value39, [later[2].id])
        let value40 = try await rui.data.memories.wall(userID: ana.id).items.contains { $0.mediaID == draft.mediaID }
        XCTAssertFalse(value40)
        let value41 = try await rui.data.memories.historyWeeks(groupID: g1.id).flatMap(\.postIDs).contains(post1.id)
        XCTAssertFalse(value41)
        let value42 = try await rui.data.memories.collage(id: collageID)
        let recomposing = try XCTUnwrap(value42)
        XCTAssertFalse(recomposing.postIDs.contains(post1.id))
        XCTAssertEqual(recomposing.status, .pending)
        XCTAssertNil(recomposing.imagePath)
        let value43 = try await rui.data.memories.yearStory(groupID: g1.id, year: 2026)?.postIDs.contains(post1.id) ?? true
        XCTAssertFalse(value43)
        let value44 = try await rui.data.birthdays.myContribution(requestID: requestID)
        XCTAssertNil(value44)
        let freshCache = SignedURLCache(client: rui.client)
        await assertThrows(.storage(.notFound)) { try await freshCache.url(for: media.originalPath) }
        let value45 = try await freshCache.urls(for: [media.originalPath])[media.originalPath]
        XCTAssertNil(value45)
        await assertThrows(.api(.mediaNotFound)) { try await ana.data.posts.deleteMedia(id: draft.mediaID) }

        // delete_post removes one group's copy only.
        let both = try await ana.data.publisher.publish(PostDraft(
            kind: .photo, original: .init(url: try temporaryFile(tinyJPEG, extension: "jpg"), contentType: ContentType.jpeg),
            groupIDs: [g1.id, g2.id]
        ))
        let inG1 = try XCTUnwrap(both.first { $0.groupID == g1.id })
        await assertThrows(.api(.postNotFound)) { try await rui.data.posts.deletePost(id: inG1.id) }
        try await ana.data.posts.deletePost(id: inG1.id)
        let value46 = try await rui.data.posts.posts(mediaID: inG1.mediaID).map(\.groupID)
        XCTAssertEqual(value46, [g2.id])
    }

    func testAccountSettingsSafetyAndDeletion() async throws {
        let ana = try await users.make("Ana")
        let rui = try await users.make("Rui")
        let group = try await ana.data.groups.create(name: "Roommates \(users.runID)", kind: .roommates)
        _ = try await rui.data.groups.join(token: try await ana.data.groups.createInvite(groupID: group.id).token)

        // Age gate: fails closed until min_age_years is configured (or passes when it is).
        let config = try await ana.data.account.publicConfig()
        XCTAssertEqual(config.invitationWindowSeconds, 120)
        XCTAssertEqual(config.maxGroupMembers, 30)
        if config.minAgeYears == nil {
            await assertThrows(.api(.ageGateNotConfigured)) {
                try await ana.data.auth.confirmAge(birthdate: LocalDate(year: 1990, month: 1, day: 1)!)
            }
        } else {
            let value47 = try await ana.data.auth.confirmAge(birthdate: LocalDate(year: 1990, month: 1, day: 1)!).ageConfirmedAt
            XCTAssertNotNil(value47)
        }
        let value48 = try await ana.data.profiles.myPrivateProfile()?.userID
        XCTAssertEqual(value48, ana.id)

        // Quiet hours.
        let value49 = try await ana.data.account.notificationSettings()
        XCTAssertNil(value49)
        let quiet = try await ana.data.account.setQuietHours(start: LocalTime(hour: 22, minute: 0), end: LocalTime(hour: 7, minute: 0), timeZone: "Europe/Lisbon")
        XCTAssertEqual(quiet.quietHours?.start, LocalTime(hour: 22, minute: 0))
        let value50 = try await ana.data.account.notificationSettings()?.timeZone
        XCTAssertEqual(value50, "Europe/Lisbon")
        await assertThrows(.api(.invalidQuietHours)) {
            try await ana.data.account.setQuietHours(start: LocalTime(hour: 22, minute: 0), end: nil)
        }
        let value51 = try await ana.data.account.setQuietHours(start: nil, end: nil, timeZone: nil).quietHours
        XCTAssertNil(value51)

        // Devices: register (all three tokens), re-register moves the token, unregister.
        let apns = String(repeating: "ab", count: 32) + users.runID
        let device = try await ana.data.account.registerDevice(pushToken: apns, pushToStartToken: "p2s-\(users.runID)", widgetPushToken: "w-\(users.runID)")
        XCTAssertEqual(device.platform, .ios)
        XCTAssertEqual(device.widgetPushToken, "w-\(users.runID)")
        let value52 = try await ana.data.account.myDevices().map(\.pushToken)
        XCTAssertEqual(value52, [apns])
        _ = try await rui.data.account.registerDevice(pushToken: apns, pushToStartToken: nil, widgetPushToken: nil)
        let value53 = try await ana.data.account.myDevices().isEmpty
        XCTAssertTrue(value53, "a token belongs to one account")
        try await rui.data.account.unregisterDevice(pushToken: apns)
        let value54 = try await rui.data.account.myDevices().isEmpty
        XCTAssertTrue(value54)

        // Entitlements (written by the RevenueCat webhook).
        let value55 = try await ana.data.account.hasPremium()
        XCTAssertFalse(value55)
        _ = try await LocalStack.insert("entitlements", ["user_id": ana.id.rawValue, "entitlement": "premium", "source": "test"])
        let value56 = try await ana.data.account.hasPremium()
        XCTAssertTrue(value56)

        // Blocks and reports.
        let file = try temporaryFile(tinyJPEG, extension: "jpg")
        let posted = try await rui.data.publisher.publish(PostDraft(kind: .photo, original: .init(url: file, contentType: ContentType.jpeg), groupIDs: [group.id]))
        let reportID = try await ana.data.safety.report(.post, targetID: posted[0].id.rawValue, reason: "test report")
        XCTAssertNotNil(reportID.uuid)
        await assertThrows(.api(.targetNotFound)) {
            try await ana.data.safety.report(.post, targetID: UUID().uuidString, reason: "missing")
        }
        try await ana.data.safety.block(userID: rui.id)
        let value57 = try await ana.data.safety.blocked().map(\.blockedID)
        XCTAssertEqual(value57, [rui.id])
        let value58 = try await ana.data.posts.page(groupID: group.id).items.isEmpty
        XCTAssertTrue(value58, "a block hides the other's posts")
        let value59 = try await ana.data.memories.wall(userID: rui.id).items.isEmpty
        XCTAssertTrue(value59)
        await assertThrows(.api(.cannotTargetSelf)) { try await ana.data.safety.block(userID: ana.id) }
        try await ana.data.safety.unblock(userID: rui.id)
        let value60 = try await ana.data.posts.page(groupID: group.id).items.map(\.id)
        XCTAssertEqual(value60, [posted[0].id])

        // Video needs premium; Rui has none.
        let video = try temporaryFile(Data(repeating: 0, count: 4096), extension: "mp4")
        await assertThrows(.api(.premiumRequired)) {
            try await rui.data.publisher.publish(PostDraft(kind: .video, original: .init(url: video, contentType: ContentType.mp4), durationMs: 2000, groupIDs: [group.id]))
        }
        let value61 = await rui.data.publisher.pending().count
        XCTAssertEqual(value61, 1, "a refused draft stays until discarded")
        await rui.data.publisher.removeAll()

        // Account deletion: every later call says not_authenticated.
        try await rui.data.account.deleteAccount()
        await assertThrows(.api(.notAuthenticated)) { try await rui.data.groups.createInvite(groupID: group.id) }
        await assertThrows(.api(.notAuthenticated)) { try await rui.data.groups.create(name: "x", kind: .friends) }
        let value62 = try await ana.data.groups.members(groupID: group.id).map(\.member.userID)
        XCTAssertEqual(value62, [ana.id])
    }
}
