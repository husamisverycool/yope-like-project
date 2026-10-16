// Social group — a fixed demo backend (DEBUG only) for the unit tests, the snapshot tests and the UI tests
// (launch argument `-SocialFakes`). Synthetic people and pictures; no reference content.
#if DEBUG
import AppData
import AppModels
import Foundation

enum SocialDemo {
    // People
    static let me = UserID("00000000-0000-4000-8000-00000000a001")
    static let ana = UserID("00000000-0000-4000-8000-00000000a002")
    static let ben = UserID("00000000-0000-4000-8000-00000000a003")
    static let cleo = UserID("00000000-0000-4000-8000-00000000a004")
    static let stranger = UserID("00000000-0000-4000-8000-00000000a009")

    // Groups
    static let groupID = GroupID("00000000-0000-4000-8000-00000000b001")
    static let otherGroupID = GroupID("00000000-0000-4000-8000-00000000b002")

    /// Monday 2026-10-12 09:00 UTC (ISO week 42).
    static let monday = Date(timeIntervalSince1970: 1_791_795_600)
    static let hour: TimeInterval = 3600
    static let day: TimeInterval = 86_400
    static let thisWeek = LocalDate(year: 2026, month: 10, day: 12)!
    static let lastWeek = LocalDate(year: 2026, month: 10, day: 5)!

    // Posts (p1–p4 this week, p5–p6 last week)
    static let p1 = PostID("00000000-0000-4000-8000-00000000c001")
    static let p2 = PostID("00000000-0000-4000-8000-00000000c002")
    static let p3 = PostID("00000000-0000-4000-8000-00000000c003")
    static let p4 = PostID("00000000-0000-4000-8000-00000000c004")
    static let p5 = PostID("00000000-0000-4000-8000-00000000c005")
    static let p6 = PostID("00000000-0000-4000-8000-00000000c006")
    /// p3's photo also sent to the other group.
    static let p3b = PostID("00000000-0000-4000-8000-00000000c013")

    static let recapID = RecapID("00000000-0000-4000-8000-00000000d001")
    static let pendingRecapID = RecapID("00000000-0000-4000-8000-00000000d002")
    static let albumID = AlbumID("00000000-0000-4000-8000-00000000e001")

    static func mediaID(_ post: PostID) -> MediaID {
        MediaID(post.rawValue.replacingOccurrences(of: "0000c0", with: "0000f0"))
    }

    static func profile(_ id: UserID, _ name: String) -> Profile {
        Profile(id: id, displayName: name, avatarPath: "fake/avatar/\(id.rawValue.suffix(2))", createdAt: monday, updatedAt: monday)
    }

    static let profiles: [Profile] = [
        profile(me, "Sam Reed"), profile(ana, "Ana Lima"), profile(ben, "Ben Ortiz"), profile(cleo, "Cleo Park"),
    ]

    static func group(_ id: GroupID, name: String, createdBy: UserID) -> PhotoGroup {
        PhotoGroup(
            id: id, name: name, kind: .friends, coverPath: "fake/cover/\(id.rawValue.suffix(2))", timeZone: "UTC",
            wakingStart: nil, wakingEnd: nil, invitationPaused: false, createdBy: createdBy,
            createdAt: monday.addingTimeInterval(-30 * day), updatedAt: monday
        )
    }

    static func member(_ user: UserID, in group: GroupID, role: MemberRole = .member) -> MemberProfile {
        MemberProfile(
            member: GroupMember(groupID: group, userID: user, role: role, muted: false, joinedAt: monday.addingTimeInterval(-29 * day)),
            profile: profiles.first { $0.id == user }
        )
    }

    /// Pixel size of the synthetic sample photos.
    static let samplePixels = (width: 1080, height: 1440) // provenance-ok: sample media pixel size (demo data, not a design value)

    static func post(
        _ id: PostID, by author: UserID, at date: Date, in group: GroupID = groupID, caption: String? = nil,
        voiceMs: Int? = nil, kind: MediaKind = .photo, media: MediaID? = nil, replyTo: PostID? = nil
    ) -> PostWithMedia {
        let mediaID = media ?? Self.mediaID(id)
        let path = "fake/photo/\(mediaID.rawValue.suffix(2))"
        return PostWithMedia(
            post: Post(
                id: id, mediaID: mediaID, groupID: group, authorID: author, caption: caption,
                voicePath: voiceMs.map { _ in "fake/voice/\(id.rawValue.suffix(2))" }, voiceDurationMs: voiceMs,
                replyToPostID: replyTo, createdAt: date
            ),
            media: Media(
                id: mediaID, ownerID: author, kind: kind, originalPath: path,
                motionPath: kind == .livePhoto ? path + ".mov" : nil, displayPath: path, thumbPath: path,
                width: samplePixels.width, height: samplePixels.height, renditionsReadyAt: date, createdAt: date
            )
        )
    }

    static func messageID(_ n: Int) -> MessageID {
        MessageID("00000000-0000-4000-8000-0000000a" + String(1000 + n).suffix(4))
    }

    static func message(
        _ n: Int, by author: UserID, at date: Date, text: String? = nil, post: PostID? = nil, voiceMs: Int? = nil,
        replyTo: PostID? = nil, replyToMessage: MessageID? = nil, in group: GroupID = groupID
    ) -> Message {
        let kind: MessageKind = post != nil ? .photo : (voiceMs != nil ? .voice : .text)
        return Message(
            id: messageID(n),
            groupID: group, authorID: author, kind: kind, body: text, postID: post,
            voicePath: voiceMs.map { _ in "fake/voice/m\(n)" }, voiceDurationMs: voiceMs,
            replyToPostID: replyTo, replyToMessageID: replyToMessage, createdAt: date
        )
    }

    static func tag(_ post: PostID, _ user: UserID, minutes: Double) -> PostTag {
        PostTag(postID: post, userID: user, groupID: groupID, createdAt: monday.addingTimeInterval(minutes * 60))
    }

    static func reaction(_ post: PostID, _ user: UserID, _ emoji: String, minutes: Double) -> Reaction {
        Reaction(postID: post, userID: user, emoji: emoji, groupID: groupID, createdAt: monday.addingTimeInterval(minutes * 60))
    }

    static var posts: [PostWithMedia] {
        [
            post(p1, by: ben, at: monday.addingTimeInterval(1 * hour)),
            post(p2, by: ana, at: monday.addingTimeInterval(1 * day + 10 * hour), caption: "first snow", voiceMs: 38_000),
            post(p3, by: me, at: monday.addingTimeInterval(2 * day + 4 * hour)),
            post(p3b, by: me, at: monday.addingTimeInterval(2 * day + 4 * hour), in: otherGroupID, media: mediaID(p3)),
            post(p4, by: cleo, at: monday.addingTimeInterval(3 * day + 8 * hour), kind: .livePhoto),
            post(p5, by: ana, at: monday.addingTimeInterval(-5 * day)),
            post(p6, by: me, at: monday.addingTimeInterval(-4 * day), caption: "picnic"),
        ]
    }

    static var messages: [Message] {
        [
            message(1, by: ana, at: monday.addingTimeInterval(0.2 * hour), text: "who's cooking tonight?"),
            message(2, by: ana, at: monday.addingTimeInterval(0.3 * hour), text: "i can do pasta"),
            message(3, by: ben, at: monday.addingTimeInterval(1 * hour), post: p1),
            message(4, by: me, at: monday.addingTimeInterval(1.2 * hour), text: "yes please"),
            message(5, by: me, at: monday.addingTimeInterval(1.3 * hour), voiceMs: 38_000),
            message(6, by: ana, at: monday.addingTimeInterval(1 * day + 10 * hour), post: p2),
            message(7, by: ben, at: monday.addingTimeInterval(1 * day + 11 * hour), text: "so pretty", replyTo: p2),
            message(8, by: me, at: monday.addingTimeInterval(2 * day + 4 * hour), post: p3),
            message(9, by: cleo, at: monday.addingTimeInterval(3 * day + 8 * hour), post: p4),
        ]
    }

    static var reactions: [Reaction] {
        [
            reaction(p1, ana, "🔥", minutes: 70), reaction(p1, cleo, "🔥", minutes: 71), reaction(p1, me, "💖", minutes: 72),
            reaction(p2, ben, "😍", minutes: 1500),
        ]
    }

    static var recaps: [WeeklyRecap] {
        let sunday = monday.addingTimeInterval(-1 * day + 9 * hour)
        return [
            WeeklyRecap(
                id: recapID, groupID: groupID, weekStart: lastWeek, items: [p6, p5], text: nil, status: .ready,
                generatedAt: sunday, editedBy: nil, createdAt: sunday, updatedAt: sunday
            ),
            WeeklyRecap(
                id: pendingRecapID, groupID: groupID, weekStart: thisWeek, items: [], text: nil, status: .pending,
                generatedAt: nil, editedBy: nil, createdAt: monday, updatedAt: monday
            ),
        ]
    }

    static var albums: [AlbumWithItems] {
        [
            AlbumWithItems(
                album: Album(id: albumID, groupID: groupID, name: "weekend", createdBy: ana, createdAt: monday, updatedAt: monday),
                postIDs: [p1, p2]
            ),
        ]
    }

    /// The demo backend: four people in one group ("roommates", created by Ana) plus a second group with Ben.
    static func makeData(now: Date? = nil) -> FakeSocialData {
        let data = FakeSocialData(me: me)
        data.update { state in
            state.groups = [
                group(groupID, name: "roommates", createdBy: ana),
                group(otherGroupID, name: "climbing", createdBy: me),
            ]
            state.members[groupID] = [
                member(ana, in: groupID, role: .admin), member(me, in: groupID), member(ben, in: groupID), member(cleo, in: groupID),
            ]
            state.members[otherGroupID] = [member(me, in: otherGroupID, role: .admin), member(ben, in: otherGroupID)]
            for profile in profiles { state.profiles[profile.id] = profile }
            state.posts = posts
            state.messages = messages
            state.reactions = reactions
            state.recaps = recaps
            state.albums = albums
            state.now = now ?? monday.addingTimeInterval(4 * day)
        }
        return data
    }

    /// A group with no posts and no messages, created by `creator`.
    static func makeEmptyData(creator: UserID = ana) -> FakeSocialData {
        let data = FakeSocialData(me: me)
        data.update { state in
            state.groups = [group(groupID, name: "roommates", createdBy: creator)]
            state.members[groupID] = [member(creator, in: groupID, role: .admin)] + [me, ben].filter { $0 != creator }.map { member($0, in: groupID) }
            for profile in profiles { state.profiles[profile.id] = profile }
        }
        return data
    }
}
#endif
