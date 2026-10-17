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
        not_authenticated not_group_member not_group_admin not_album_owner post_not_eligible under_minimum_age
        premium_required video_too_long post_not_found media_not_found message_not_found member_not_found user_not_found
        invite_not_found recap_not_found album_not_found request_not_found target_not_found invite_revoked
        invite_expired group_full already_posted recap_not_ready tribute_closed age_gate_not_configured
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
    }
}
