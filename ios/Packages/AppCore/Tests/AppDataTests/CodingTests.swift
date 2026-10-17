import AppModels
import Foundation
import Supabase
import XCTest
@testable import AppData

/// Wire-format unit tests (no network).
final class CodingTests: XCTestCase {
    func testTimestampParsesPostgresTextWithMicroseconds() throws {
        let date = try XCTUnwrap(Timestamp.parse("2026-10-15T13:35:09.329469+00:00"))
        XCTAssertEqual(Timestamp.format(date), "2026-10-15T13:35:09.329469Z")
        XCTAssertEqual(date.timeIntervalSince1970, 1_792_071_309.329469, accuracy: 0.000001)
    }

    func testTimestampAcceptsOffsetsSpacesAndNoFraction() throws {
        let utc = try XCTUnwrap(Timestamp.parse("2026-10-15T13:35:09Z"))
        XCTAssertEqual(Timestamp.parse("2026-10-15 15:35:09+02"), utc)
        XCTAssertEqual(Timestamp.parse("2026-10-15T08:05:09-05:30"), utc)
        XCTAssertEqual(Timestamp.parse("2026-10-15T15:35:09+0200"), utc)
        XCTAssertEqual(Timestamp.parse("2026-10-15T13:35:09"), utc)
        XCTAssertNil(Timestamp.parse("2026-10-15"))
        XCTAssertNil(Timestamp.parse("2026-13-15T13:35:09Z"))
        XCTAssertNil(Timestamp.parse("2026-10-15T13:35:09.Z"))
        XCTAssertNil(Timestamp.parse("2026-10-15T13:35:09+00:00 extra"))
    }

    func testTimestampFormatRoundTripsMicrosecondCursors() {
        // A pagination cursor must not move: format(parse(x)) == x for every microsecond value.
        for micros in [0, 1, 329_469, 999_999, 500_000, 123_456] {
            let text = "2026-01-31T23:59:59.\(Timestamp.pad(micros, 6))Z"
            XCTAssertEqual(Timestamp.parse(text).map(Timestamp.format), text)
        }
        XCTAssertEqual(Timestamp.format(Date(timeIntervalSince1970: -1.5)), "1969-12-31T23:59:58.500000Z")
    }

    func testLocalDate() throws {
        let date = try XCTUnwrap(LocalDate("2024-02-29"))
        XCTAssertEqual(date.description, "2024-02-29")
        XCTAssertNil(LocalDate("2026-02-29"))
        XCTAssertNil(LocalDate("2026-2-1"))
        XCTAssertEqual(date.adding(days: 1).description, "2024-03-01")
        XCTAssertLessThan(date, date.adding(days: 1))
        let paris = try XCTUnwrap(TimeZone(identifier: "Europe/Paris"))
        let lateUTC = try XCTUnwrap(Timestamp.parse("2026-10-15T22:30:00Z"))
        XCTAssertEqual(LocalDate(lateUTC, in: paris).description, "2026-10-16")
        let json = try JSONEncoder().encode([date])
        XCTAssertEqual(String(decoding: json, as: UTF8.self), "[\"2024-02-29\"]")
        XCTAssertEqual(try JSONDecoder().decode([LocalDate].self, from: json), [date])
    }

    func testIdentifiersAreLowercase() {
        let upper = "8B2E3C2A-1D4F-4E7A-9B1C-2D3E4F5A6B7C"
        XCTAssertEqual(PostID(upper).rawValue, upper.lowercased())
        let generated = MediaID.generate()
        XCTAssertEqual(generated.rawValue, generated.rawValue.lowercased())
        XCTAssertNotNil(generated.uuid)
        XCTAssertEqual(PostID(upper), PostID(upper.lowercased()))
    }

    func testModelsDecodeAPIRows() throws {
        let json = """
        {"id":"0f8fad5b-d9cb-469f-a165-70867728950e","media_id":"7c9e6679-7425-40de-944b-e07fc1f90ae7",
         "group_id":"9f1c1d2e-0000-4000-8000-000000000001","author_id":"9f1c1d2e-0000-4000-8000-000000000002",
         "caption":null,"voice_path":null,"voice_duration_ms":null,"invitation_id":null,"in_window":false,
         "reply_to_post_id":null,"created_at":"2026-10-15T13:35:09.329469+00:00"}
        """
        let post = try DataCoding.makeDecoder().decode(Post.self, from: Data(json.utf8))
        XCTAssertEqual(post.id.rawValue, "0f8fad5b-d9cb-469f-a165-70867728950e")
        XCTAssertFalse(post.inWindow)
        XCTAssertEqual(post.visibleAt, post.createdAt, "a post shared at once is visible when it was taken")

        // an overnight photo (with the server's generated visible_at): its week is the week it developed in
        let overnightJSON = json.replacingOccurrences(of: "\"created_at\":\"2026-10-15T13:35:09.329469+00:00\"",
            with: "\"created_at\":\"2026-10-11T21:30:00+00:00\",\"revealed_at\":\"2026-10-12T07:00:00+00:00\",\"visible_at\":\"2026-10-12T07:00:00+00:00\"")
        let overnight = try DataCoding.makeDecoder().decode(Post.self, from: Data(overnightJSON.utf8))
        XCTAssertEqual(overnight.visibleAt, overnight.revealedAt)
        XCTAssertNotEqual(overnight.visibleAt, overnight.createdAt)

        let group = """
        {"id":"9f1c1d2e-0000-4000-8000-000000000001","name":"Lima","kind":"family","cover_path":null,
         "time_zone":"Europe/Paris","waking_start":"09:00:00","waking_end":"21:30:00","invitation_paused":false,
         "created_by":null,"created_at":"2026-10-15T13:35:09+00:00","updated_at":"2026-10-15T13:35:09+00:00"}
        """
        let decoded = try DataCoding.makeDecoder().decode(PhotoGroup.self, from: Data(group.utf8))
        XCTAssertEqual(decoded.kind, .family)
        XCTAssertEqual(decoded.wakingEnd, LocalTime(hour: 21, minute: 30))
    }

    func testVoiceLevelsDecodeAndOlderRowsWithoutThem() throws {
        let levels = (0..<100).map { $0 % 32 }
        let json = """
        {"id":"0f8fad5b-d9cb-469f-a165-70867728950f","group_id":"9f1c1d2e-0000-4000-8000-000000000001",
         "author_id":"9f1c1d2e-0000-4000-8000-000000000002","kind":"voice","body":null,"post_id":null,
         "voice_path":"u/x/voice/a.m4a","voice_duration_ms":4100,"voice_levels":\(levels),
         "reply_to_post_id":null,"reply_to_message_id":null,"created_at":"2026-10-16T08:00:00+00:00"}
        """
        let message = try DataCoding.makeDecoder().decode(Message.self, from: Data(json.utf8))
        XCTAssertEqual(message.voiceLevels, levels)
        let older = json.replacingOccurrences(of: #""voice_levels":\#(levels),"#, with: "")
        XCTAssertNil(try DataCoding.makeDecoder().decode(Message.self, from: Data(older.utf8)).voiceLevels)
        let none = json.replacingOccurrences(of: #""voice_levels":\#(levels),"#, with: #""voice_levels":null,"#)
        XCTAssertNil(try DataCoding.makeDecoder().decode(Message.self, from: Data(none.utf8)).voiceLevels)
        XCTAssertEqual(AnyJSON.levels([3, 31]), .array([.integer(3), .integer(31)]))
        XCTAssertEqual(AnyJSON.levels(nil), .null)
    }

    func testCollagePagesAndOlderRowsWithoutPageCount() throws {
        let json = """
        {"id":"c1","group_id":"g1","invitation_id":null,"option":"B","post_ids":["p1"],"page_count":3,
         "image_path":"g/g1/collages/c1/v2/display-1.jpg","widget_path":"g/g1/collages/c1/v2/widget.jpg",
         "share_path":"g/g1/collages/c1/v2/share-1.jpg","status":"ready","composed_at":null,
         "created_at":"2026-10-15T13:35:09+00:00"}
        """
        let collage = try DataCoding.makeDecoder().decode(Collage.self, from: Data(json.utf8))
        XCTAssertEqual(collage.pageCount, 3)
        XCTAssertEqual(collage.imagePath(page: 2), "g/g1/collages/c1/v2/display-2.jpg")
        XCTAssertEqual(collage.sharePath(page: 3), "g/g1/collages/c1/v2/share-3.jpg")
        XCTAssertNil(collage.imagePath(page: 4))
        XCTAssertNil(collage.imagePath(page: 0))
        let older = json.replacingOccurrences(of: #""page_count":3,"#, with: "")
        XCTAssertEqual(try DataCoding.makeDecoder().decode(Collage.self, from: Data(older.utf8)).pageCount, 1)
    }

    /// `my_favorites` rows (migration 0038) and `album_items.added_by` (0039); older album copies have no adders.
    func testFavoritesAndAlbumAddersDecode() throws {
        let json = """
        [{"media_id":"7c9e6679-7425-40de-944b-e07fc1f90ae7","post_id":"0f8fad5b-d9cb-469f-a165-70867728950e",
          "group_id":"9f1c1d2e-0000-4000-8000-000000000001","group_name":"Lima","author_id":"9f1c1d2e-0000-4000-8000-000000000002",
          "kind":"live_photo","thumb_path":"u/a/m/thumb.jpg","display_path":"u/a/m/display.jpg","widget_path":null,
          "taken_at":"2026-10-15T13:35:09+00:00","favorited_at":"2026-10-16T08:00:00.123456+00:00"}]
        """
        let rows = try DataCoding.makeDecoder().decode([FavoritePhoto].self, from: Data(json.utf8))
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows[0].id, MediaID("7c9e6679-7425-40de-944b-e07fc1f90ae7"))
        XCTAssertEqual(rows[0].kind, .livePhoto)
        XCTAssertEqual(rows[0].groupName, "Lima")
        XCTAssertNil(rows[0].widgetPath)
        XCTAssertEqual(Timestamp.format(rows[0].favoritedAt), "2026-10-16T08:00:00.123456Z")

        let item = """
        {"album_id":"a1","post_id":"p1","position":0,"added_by":"9f1c1d2e-0000-4000-8000-000000000002","added_at":"2026-10-16T08:00:00+00:00"}
        """
        XCTAssertEqual(try DataCoding.makeDecoder().decode(AlbumItem.self, from: Data(item.utf8)).addedBy,
                       UserID("9f1c1d2e-0000-4000-8000-000000000002"))
        let gone = item.replacingOccurrences(of: #""added_by":"9f1c1d2e-0000-4000-8000-000000000002""#, with: #""added_by":null"#)
        XCTAssertNil(try DataCoding.makeDecoder().decode(AlbumItem.self, from: Data(gone.utf8)).addedBy)

        let creator = UserID("9f1c1d2e-0000-4000-8000-000000000003")
        let saved = Date(timeIntervalSince1970: 1_792_000_000)
        let album = Album(id: AlbumID("a1"), groupID: GroupID("g1"), name: "A", createdBy: creator, createdAt: saved, updatedAt: saved)
        XCTAssertEqual(AlbumWithItems(album: album, postIDs: [PostID("p1")]).adder(of: PostID("p1")), creator,
                       "a copy cached before migration 0039: the creator added every item")
        let adder = UserID("9f1c1d2e-0000-4000-8000-000000000004")
        let withAdders = AlbumWithItems(album: album, postIDs: [PostID("p1"), PostID("p2")], addedBy: [PostID("p1"): adder])
        XCTAssertEqual(withAdders.adder(of: PostID("p1")), adder)
        XCTAssertNil(withAdders.adder(of: PostID("p2")), "the adder's account is gone")
        let cached = try DataCoding.makeEncoder().encode([withAdders])
        XCTAssertEqual(try DataCoding.makeDecoder().decode([AlbumWithItems].self, from: cached), [withAdders])
    }

    func testSearchHitsAndHistoryMonthsDecodeAPIRows() throws {
        let hits = """
        [{"post_id":"0f8fad5b-d9cb-469f-a165-70867728950e","media_id":"7c9e6679-7425-40de-944b-e07fc1f90ae7",
          "group_id":"9f1c1d2e-0000-4000-8000-000000000001","author_id":"9f1c1d2e-0000-4000-8000-000000000002",
          "created_at":"2026-10-15T13:35:09.329469+00:00","matched":["caption","tag"]},
         {"post_id":"0f8fad5b-d9cb-469f-a165-70867728950f","media_id":"7c9e6679-7425-40de-944b-e07fc1f90ae8",
          "group_id":"9f1c1d2e-0000-4000-8000-000000000001","author_id":"9f1c1d2e-0000-4000-8000-000000000002",
          "created_at":"2026-10-14T13:35:09+00:00","matched":null}]
        """
        let decoded = try DataCoding.makeDecoder().decode([PhotoSearchHit].self, from: Data(hits.utf8))
        XCTAssertEqual(decoded.map(\.matched), [["caption", "tag"], []])
        XCTAssertEqual(decoded[0].groupID, GroupID("9f1c1d2e-0000-4000-8000-000000000001"))
        XCTAssertGreaterThan(decoded[0].createdAt, decoded[1].createdAt)

        let months = """
        [{"month":"2026-10-01","days":["2026-10-03","2026-10-15"],"newest_week":"2026-10-12"},
         {"month":"2026-09-01","days":["2026-09-30"],"newest_week":"2026-09-28"}]
        """
        let rows = try DataCoding.makeDecoder().decode([HistoryMonth].self, from: Data(months.utf8))
        XCTAssertEqual(rows.map(\.month), [LocalDate("2026-10-01")!, LocalDate("2026-09-01")!])
        XCTAssertEqual(rows[0].days, [LocalDate("2026-10-03")!, LocalDate("2026-10-15")!])
        XCTAssertEqual(rows[1].newestWeek, LocalDate("2026-09-28")!)
        XCTAssertEqual(rows[1].id, rows[1].month)
    }

    func testEnumsDecodeUnknownValuesLeniently() throws {
        let kinds = try JSONDecoder().decode([MessageKind].self, from: Data(#"["text","sticker"]"#.utf8))
        XCTAssertEqual(kinds, [.text, .unknown])
        XCTAssertEqual(try JSONDecoder().decode([MediaKind].self, from: Data(#"["live_photo"]"#.utf8)), [.livePhoto])
    }

    func testPostgrestErrorsMapToAPICodes() {
        let error = PostgrestError(details: "abc", hint: nil, code: "PT403", message: "not_group_member")
        XCTAssertEqual(DataError.from(error), .api(.notGroupMember, details: "abc"))
        let rls = PostgrestError(code: "42501", message: "new row violates row-level security policy")
        XCTAssertEqual(DataError.from(rls), .database(code: "42501", message: "new row violates row-level security policy"))
        XCTAssertEqual(DataError.from(URLError(.notConnectedToInternet)), .offline)
        XCTAssertTrue(DataError.offline.isTransient)
        XCTAssertFalse(DataError.api(.groupFull).isTransient)
    }

    func testStorageErrorsMap() {
        XCTAssertEqual(DataError.from(StorageError(statusCode: "409", message: "The resource already exists", error: "Duplicate")),
                       .storage(.alreadyExists))
        XCTAssertEqual(DataError.from(StorageError(statusCode: "403", message: "new row violates row-level security policy", error: "Unauthorized")),
                       .storage(.unauthorized))
        XCTAssertEqual(DataError.from(StorageError(statusCode: "400", message: "Object not found", error: "not_found")),
                       .storage(.notFound))
    }

    func testEveryAPIErrorCodeOfTheContractIsKnown() {
        // docs/API.md §3 table (keep in sync).
        let documented = """
        not_authenticated not_group_member not_group_admin not_album_owner not_allowed post_not_eligible under_minimum_age
        premium_required video_too_long post_not_found media_not_found message_not_found member_not_found user_not_found
        invite_not_found recap_not_found album_not_found request_not_found target_not_found invite_revoked
        invite_expired group_full already_posted recap_not_ready media_not_ready edit_window_closed tribute_closed
        age_gate_not_configured
        invalid_name invalid_kind invalid_time_zone invalid_waking_window invalid_path invalid_caption invalid_voice
        invalid_body invalid_emoji invalid_items invalid_text invalid_line invalid_reason invalid_platform
        invalid_token invalid_quiet_hours invalid_birthday invalid_birthdate reply_group_mismatch cannot_target_self
        no_groups invalid_argument
        """.split(whereSeparator: \.isWhitespace).map(String.init)
        XCTAssertEqual(Set(documented), Set(APIErrorCode.allCases.map(\.rawValue)))
    }

    func testStoragePaths() {
        let owner = UserID("9F1C1D2E-0000-4000-8000-000000000002")
        let media = MediaID("7C9E6679-7425-40DE-944B-E07FC1F90AE7")
        XCTAssertEqual(StoragePaths.original(owner: owner, media: media, fileExtension: "JPG"),
                       "u/9f1c1d2e-0000-4000-8000-000000000002/7c9e6679-7425-40de-944b-e07fc1f90ae7/original.jpg")
        XCTAssertTrue(StoragePaths.front(owner: owner, media: media).hasSuffix("/front.jpg"))
        XCTAssertTrue(StoragePaths.motion(owner: owner, media: media).hasSuffix("/motion.mov"))
        XCTAssertTrue(StoragePaths.postVoice(owner: owner, media: media).hasSuffix("/voice.m4a"))
        XCTAssertTrue(StoragePaths.chatVoice(owner: owner).hasPrefix("u/\(owner.rawValue)/voice/"))
        XCTAssertTrue(StoragePaths.cover(owner: owner).hasPrefix("u/\(owner.rawValue)/covers/"))
        XCTAssertTrue(StoragePaths.avatar(owner: owner).hasPrefix("avatars/\(owner.rawValue)/"))
        XCTAssertTrue(StoragePaths.isSafe(StoragePaths.chatVoice(owner: owner)))
        XCTAssertFalse(StoragePaths.isSafe("u/x/../y"))
        XCTAssertFalse(StoragePaths.isSafe("u//x"))
        XCTAssertFalse(StoragePaths.isSafe("u/x y"))
        XCTAssertEqual(ContentType.forExtension("M4A"), "audio/mp4")
        XCTAssertNil(ContentType.forExtension("gif"))
    }

    func testMediaRenditionChoice() {
        var media = Media(id: .generate(), ownerID: UserID("u"), kind: .photo, originalPath: "u/o/m/original.jpg",
                          thumbPath: "u/o/m/r/thumb.jpg", createdAt: Date())
        XCTAssertEqual(media.imagePath(for: .thumb), "u/o/m/original.jpg", "original until renditions are ready")
        media.renditionsReadyAt = Date()
        XCTAssertEqual(media.imagePath(for: .thumb), "u/o/m/r/thumb.jpg")
        XCTAssertEqual(media.imagePath(for: .display), "u/o/m/original.jpg", "missing rendition falls back")
        media.kind = .video
        XCTAssertNil(media.imagePath(for: .display))
        // A video's poster renditions show before the transcode finishes (renditions_ready_at still null).
        media.renditionsReadyAt = nil
        XCTAssertEqual(media.imagePath(for: .thumb), "u/o/m/r/thumb.jpg")
        XCTAssertNil(media.imagePath(for: .display), "no poster yet: nothing (the original is the movie)")
    }

    func testJWTSubject() {
        func b64(_ text: String) -> String {
            Data(text.utf8).base64EncodedString().replacingOccurrences(of: "=", with: "")
                .replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_")
        }
        let token = b64(#"{"alg":"HS256"}"#) + "." + b64(#"{"sub":"abc-123","role":"authenticated"}"#) + ".sig"
        XCTAssertEqual(JWTClaims.subject(of: token), "abc-123")
        XCTAssertNil(JWTClaims.subject(of: "garbage"))
    }

    func testPublicConfigRows() throws {
        let rows = try JSONDecoder().decode([PublicAppConfig.Row].self, from: Data("""
        [{"key":"invitation_window_seconds","value":120},{"key":"min_age_years","value":null},
         {"key":"max_group_members","value":30},{"key":"free_history_days"}]
        """.utf8))
        let config = PublicAppConfig(rows: rows)
        XCTAssertEqual(config.invitationWindowSeconds, 120)
        XCTAssertEqual(config.maxGroupMembers, 30)
        XCTAssertNil(config.minAgeYears)
        XCTAssertNil(config.freeHistoryDays)
        XCTAssertNil(config.messageEditWindowSeconds, "not set: the chat offers no Edit")
        XCTAssertNil(config.typingTTLSeconds)
        XCTAssertNil(config.batchMaxPhotos, "not set: the composer picks one photo")

        let batch = try JSONDecoder().decode([PublicAppConfig.Row].self, from: Data(#"[{"key":"batch_max_photos","value":20}]"#.utf8))
        XCTAssertEqual(PublicAppConfig(rows: batch).batchMaxPhotos, 20)
    }

    func testChatTunablesFromPublicConfig() throws {
        let rows = try JSONDecoder().decode([PublicAppConfig.Row].self, from: Data("""
        [{"key":"message_edit_window_s","value":900},{"key":"message_edit_max","value":5},{"key":"typing_ttl_s","value":6}]
        """.utf8))
        let config = PublicAppConfig(rows: rows)
        XCTAssertEqual(config.messageEditWindowSeconds, 900)
        XCTAssertEqual(config.typingTTLSeconds, 6)
    }

    /// Migration 0047 / 0048 rows: `messages.edited_at`, `message_reactions`, `chat_typing`.
    func testEditedMessagesMessageReactionsAndTypingRowsDecode() throws {
        let message = """
        {"id":"0f8fad5b-d9cb-469f-a165-70867728950f","group_id":"9f1c1d2e-0000-4000-8000-000000000001",
         "author_id":"9f1c1d2e-0000-4000-8000-000000000002","kind":"text","body":"see you at 8","post_id":null,
         "voice_path":null,"voice_duration_ms":null,"reply_to_post_id":null,"reply_to_message_id":null,
         "created_at":"2026-10-16T08:00:00+00:00","edited_at":"2026-10-16T08:03:00.250+00:00"}
        """
        let edited = try DataCoding.makeDecoder().decode(Message.self, from: Data(message.utf8))
        XCTAssertEqual(edited.editedAt, Timestamp.parse("2026-10-16T08:03:00.250+00:00"))
        let older = message.replacingOccurrences(of: #","edited_at":"2026-10-16T08:03:00.250+00:00""#, with: "")
        XCTAssertNil(try DataCoding.makeDecoder().decode(Message.self, from: Data(older.utf8)).editedAt)

        let reaction = """
        {"message_id":"0f8fad5b-d9cb-469f-a165-70867728950f","user_id":"9f1c1d2e-0000-4000-8000-000000000003",
         "emoji":"🔥","group_id":"9f1c1d2e-0000-4000-8000-000000000001","created_at":"2026-10-16T08:01:00+00:00"}
        """
        let row = try DataCoding.makeDecoder().decode(MessageReaction.self, from: Data(reaction.utf8))
        XCTAssertEqual(row.messageID, MessageID("0f8fad5b-d9cb-469f-a165-70867728950f"))
        XCTAssertEqual(row.emoji, "🔥")

        let typing = """
        {"group_id":"9f1c1d2e-0000-4000-8000-000000000001","user_id":"9f1c1d2e-0000-4000-8000-000000000003",
         "until":"2026-10-16T08:01:06+00:00"}
        """
        let typist = try DataCoding.makeDecoder().decode(ChatTyping.self, from: Data(typing.utf8))
        XCTAssertEqual(typist.until, Timestamp.parse("2026-10-16T08:01:06+00:00"))
    }

    /// Migrations 0050 / 0051: the media insert carries the day a library photo was taken and the selection's batch id;
    /// posts and media read them back; drafts saved before them still decode.
    func testTakenOnAndBatchIDRideTheMediaInsertAndDecode() throws {
        let day = try XCTUnwrap(LocalDate("2026-09-14"))
        let draft = PostDraft(
            mediaID: MediaID("7c9e6679-7425-40de-944b-e07fc1f90ae7"),
            kind: .photo,
            original: .init(url: URL(fileURLWithPath: "/tmp/original.jpg"), contentType: ContentType.jpeg),
            groupIDs: [GroupID("9f1c1d2e-0000-4000-8000-000000000001")],
            takenOn: day,
            batchID: "5b0b5e43-2f0e-4c5e-9a55-3f7d0b8f1a20"
        )
        let row = draft.mediaRow(owner: UserID("9f1c1d2e-0000-4000-8000-000000000002")).row
        XCTAssertEqual(row["taken_on"], .string("2026-09-14"))
        XCTAssertEqual(row["batch_id"], .string("5b0b5e43-2f0e-4c5e-9a55-3f7d0b8f1a20"))

        // A camera photo posted alone: both null (the server places it by created_at; no batch).
        let camera = PostDraft(kind: .photo, original: draft.original, groupIDs: draft.groupIDs)
        let cameraRow = camera.mediaRow(owner: UserID("9f1c1d2e-0000-4000-8000-000000000002")).row
        XCTAssertEqual(cameraRow["taken_on"], .null)
        XCTAssertEqual(cameraRow["batch_id"], .null)

        // The outbox keeps both across a relaunch; a draft saved before them decodes without them.
        let saved = try DataCoding.makeDecoder().decode(PostDraft.self, from: DataCoding.makeEncoder().encode(draft))
        XCTAssertEqual(saved.takenOn, day)
        XCTAssertEqual(saved.batchID, draft.batchID)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: DataCoding.makeEncoder().encode(camera)) as? [String: Any])
        object.removeValue(forKey: "takenOn")
        object.removeValue(forKey: "batchID")
        let older = try DataCoding.makeDecoder().decode(PostDraft.self, from: JSONSerialization.data(withJSONObject: object))
        XCTAssertNil(older.takenOn)
        XCTAssertNil(older.batchID)

        let post = try DataCoding.makeDecoder().decode(Post.self, from: Data("""
        {"id":"0f8fad5b-d9cb-469f-a165-70867728950e","media_id":"7c9e6679-7425-40de-944b-e07fc1f90ae7",
         "group_id":"9f1c1d2e-0000-4000-8000-000000000001","author_id":"9f1c1d2e-0000-4000-8000-000000000002",
         "caption":null,"voice_path":null,"voice_duration_ms":null,"invitation_id":null,"in_window":false,
         "reply_to_post_id":null,"created_at":"2026-10-15T13:35:09.329469+00:00","taken_on":"2026-09-14",
         "batch_id":"5b0b5e43-2f0e-4c5e-9a55-3f7d0b8f1a20"}
        """.utf8))
        XCTAssertEqual(post.takenOn, day)
        XCTAssertEqual(post.batchID, "5b0b5e43-2f0e-4c5e-9a55-3f7d0b8f1a20")

        let media = try DataCoding.makeDecoder().decode(Media.self, from: Data("""
        {"id":"7c9e6679-7425-40de-944b-e07fc1f90ae7","owner_id":"9f1c1d2e-0000-4000-8000-000000000002","kind":"photo",
         "original_path":"u/x/y/original.jpg","created_at":"2026-10-15T13:35:09+00:00","taken_on":null,"batch_id":null}
        """.utf8))
        XCTAssertNil(media.takenOn)
        XCTAssertNil(media.batchID)
    }
}
