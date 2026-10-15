// Social group — data access for chat.thread, chat.composer, chat.voice, chat.reactions, photo.viewer,
// walls.*, week.*, albums.* (design/surfaces/<id>.md "Data & actions"; docs/API.md).
//
// Every read and write goes through AppData (`LiveSocialData`). The protocol exists so view models can
// be tested with an in-memory fake and the UI tests can launch the app on fake data
// (`FakeSocialData`, DEBUG only). Foundation + AppData only: this file also builds on Linux.
import AppData
import AppModels
import Foundation

/// Reads and writes of the social screens. Implementations never count reactions (tenet: no counts).
protocol SocialDataSource: Sendable {
    /// The signed-in user (nil when signed out).
    func currentUserID() async -> UserID?

    // MARK: Groups and people
    func group(id: GroupID) async throws -> PhotoGroup?
    /// The group from the offline copy of the caller's group list.
    func cachedGroup(id: GroupID) async -> PhotoGroup?
    func myGroups() async throws -> [PhotoGroup]
    func cachedGroups() async -> [PhotoGroup]?
    func members(groupID: GroupID) async throws -> [MemberProfile]
    func cachedMembers(groupID: GroupID) async -> [MemberProfile]?
    func profiles(ids: [UserID]) async throws -> [Profile]
    func myMembership(groupID: GroupID) async throws -> GroupMember?

    // MARK: Chat (docs/API.md §5.9, §6.2)
    /// Newest first; `before` pages back.
    func messages(groupID: GroupID, before: Date?) async throws -> Page<Message>
    func cachedMessages(groupID: GroupID) async -> [Message]?
    func sendText(groupID: GroupID, body: String, replyToPostID: PostID?) async throws -> Message
    /// Uploads the `.m4a` (`u/<uid>/voice/<uuid>.m4a`), then sends it.
    func sendVoice(groupID: GroupID, fileURL: URL, durationMs: Int) async throws -> Message
    func deleteMessage(id: MessageID, groupID: GroupID) async throws

    // MARK: Posts (§5.7, §5.8)
    /// Visible posts among `ids` with their media, in the order of `ids`.
    func posts(ids: [PostID]) async throws -> [PostWithMedia]
    /// The offline copy of a group's feed (first page).
    func cachedPosts(groupID: GroupID) async -> [PostWithMedia]
    /// `delete_media`: removes the photo everywhere (owner only).
    func deleteMedia(id: MediaID) async throws

    // MARK: Reactions and self-tags (§5.10, §5.11)
    /// Rows `(user, emoji)`, oldest first. Never a count.
    func reactions(postIDs: [PostID]) async throws -> [Reaction]
    func react(postID: PostID, emoji: String) async throws -> Reaction
    func isTagged(postID: PostID, userID: UserID) async throws -> Bool
    /// `tag_self` / `untag_self`.
    func setTagged(_ tagged: Bool, postID: PostID) async throws

    // MARK: Safety (§6.3; the report sheet is the account group's `safety.report`)
    func block(userID: UserID) async throws

    // MARK: Walls (§6.4 `wall`)
    func wall(userID: UserID, before: Date?, limit: Int) async throws -> Page<WallItem>
    func cachedWall(userID: UserID) async -> [WallItem]?
    func collages(ids: [CollageID]) async throws -> [Collage]

    // MARK: Weeks and albums (§5.14, §5.15, §6.4)
    /// Newest week first.
    func recaps(groupID: GroupID) async throws -> [WeeklyRecap]
    func recap(id: RecapID) async throws -> WeeklyRecap?
    func updateRecap(id: RecapID, items: [PostID], text: String) async throws -> WeeklyRecap
    /// Weeks with posts, newest first, pages of 8; `beforeWeek` is exclusive.
    func historyWeeks(groupID: GroupID, beforeWeek: LocalDate?) async throws -> [HistoryWeek]
    func cachedHistoryWeeks(groupID: GroupID) async -> [HistoryWeek]?
    func albums(groupID: GroupID) async throws -> [AlbumWithItems]
    func cachedAlbums(groupID: GroupID) async -> [AlbumWithItems]?
    func saveAlbum(groupID: GroupID, name: String, postIDs: [PostID]) async throws -> Album
    func renameAlbum(id: AlbumID, name: String) async throws -> Album
    func deleteAlbum(id: AlbumID, groupID: GroupID) async throws

    // MARK: Files (§7)
    /// A short-lived signed URL for a private storage path.
    func fileURL(path: String) async throws -> URL

    // MARK: Live
    /// Realtime inserts, updates and deletion broadcasts of one group (§8).
    func events(groupID: GroupID) -> AsyncStream<GroupEvent>
    /// The current reachability, then every change.
    func network() -> AsyncStream<NetworkStatus>
}

/// Page sizes fixed by the API contract (docs/API.md §5.9, §6.4) and the specs' "Data" sections.
enum SocialPaging {
    /// `chat.thread`: `limit(50)`.
    static let messages = ChatRepository.pageSize
    /// `walls.*`: `wall(p_limit: 50)`.
    static let wall = 50
    /// `week.history`: `group_history_weeks(p_limit: 8)`.
    static let historyWeeks = 8
}

/// How a failed call is shown: every screen maps these to its own error / offline / gone copy.
enum SocialFailure: Equatable, Sendable {
    case offline
    case notFound
    case notReady
    case other

    init(_ error: Error) {
        guard let error = error as? DataError else {
            self = .other
            return
        }
        switch error {
        case .offline:
            self = .offline
        case let .api(code, _):
            switch code {
            case .postNotFound, .mediaNotFound, .messageNotFound, .recapNotFound, .albumNotFound, .targetNotFound,
                 .userNotFound:
                self = .notFound
            case .recapNotReady:
                self = .notReady
            default:
                self = .other
            }
        case .storage(.notFound):
            self = .notFound
        default:
            self = .other
        }
    }
}
