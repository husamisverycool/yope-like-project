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
    /// `send_message` (text); `replyToPostID` quotes a photo, `replyToMessageID` a message (`chat.thread.layout.replyQuote`).
    func sendText(groupID: GroupID, body: String, replyToPostID: PostID?, replyToMessageID: MessageID?) async throws -> Message
    /// One message by id (a quoted message outside the loaded pages).
    func message(id: MessageID) async throws -> Message?
    /// The group-chat replies to a photo (`messages.reply_to_post_id = post`), oldest first (`photo.viewer.layout.comments`).
    func replies(postID: PostID) async throws -> [Message]
    /// Uploads the `.m4a` (`u/<uid>/voice/<uuid>.m4a`), then sends it with its waveform (`levels`: 100 values of 0…31,
    /// `p_voice_levels`; nil sends none).
    func sendVoice(groupID: GroupID, fileURL: URL, durationMs: Int, levels: [Int]?) async throws -> Message
    func deleteMessage(id: MessageID, groupID: GroupID) async throws
    /// `edit_message` (`chat.thread.layout.editMessage`): my own text message inside the edit window; the row with
    /// `edited_at` set. `edit_window_closed` once the window passed.
    func editMessage(id: MessageID, body: String) async throws -> Message
    /// `public_app_config` (§11): `message_edit_window_s` (Edit is offered only inside it) and `typing_ttl_s`.
    func publicConfig() async throws -> PublicAppConfig
    /// Link previews built on the sender's device (migration 0053, `chat.thread.layout.linkPreview`): uploads the draft's
    /// JPEG (`u/<uid>/links/<uuid>.jpg`) when it has one, then `set_link_preview` on my own text message; the row with
    /// `link_preview` set.
    func setLinkPreview(messageID: MessageID, preview: LinkPreviewDraft) async throws -> Message

    // MARK: Reactions on messages (§5.10a; `chat.reactions.layout.messageReactions`)
    /// Rows `(message, user, emoji)`, oldest first: one per person and message. Never a count.
    func messageReactions(messageIDs: [MessageID]) async throws -> [MessageReaction]
    /// `react_to_message`: sets or replaces my one reaction on a text or voice message.
    func reactToMessage(id: MessageID, emoji: String) async throws -> MessageReaction
    /// `unreact_to_message`: takes mine back.
    func unreactToMessage(id: MessageID) async throws

    // MARK: Typing (§5.10b; `chat.thread.layout.typingLine`)
    /// The group's `chat_typing` rows whose `until` is still ahead.
    func typing(groupID: GroupID) async throws -> [ChatTyping]
    /// `set_typing`.
    func setTyping(_ typing: Bool, groupID: GroupID) async throws

    // MARK: Posts (§5.7, §5.8)
    /// Visible posts among `ids` with their media, in the order of `ids`.
    func posts(ids: [PostID]) async throws -> [PostWithMedia]
    /// The photos revealed together with `post` in one overnight reveal (`revealed_at`, camera.overnight C), oldest
    /// first; empty for a photo shared at once.
    func revealedWith(_ post: Post) async throws -> [PostWithMedia]
    /// The offline copy of a group's feed (first page).
    func cachedPosts(groupID: GroupID) async -> [PostWithMedia]
    /// Posts among `ids` already on the device (fetched this session, or in the group's offline feed), in the order
    /// of `ids`; missing ones are left out.
    func cachedPosts(ids: [PostID], groupID: GroupID?) async -> [PostWithMedia]
    /// `delete_media`: removes the photo everywhere (owner only).
    func deleteMedia(id: MediaID) async throws

    // MARK: Reactions and self-tags (§5.10, §5.11)
    /// Rows `(user, emoji)`, oldest first. Never a count.
    func reactions(postIDs: [PostID]) async throws -> [Reaction]
    func react(postID: PostID, emoji: String) async throws -> Reaction
    /// `unreact`: takes back one of my reactions (`chat.reactions.layout.unreact`).
    func unreact(postID: PostID, emoji: String) async throws
    func isTagged(postID: PostID, userID: UserID) async throws -> Bool
    /// Who is in the photo (`post_tags`), in tag order (`tagging.with`).
    func tags(postID: PostID) async throws -> [PostTag]
    /// `tag_self` / `untag_self`.
    func setTagged(_ tagged: Bool, postID: PostID) async throws

    // MARK: Selfie reactions (§14.1, viewer.selfiereaction)
    /// One row per person and post, oldest first. Never a count.
    func selfieReactions(postIDs: [PostID]) async throws -> [SelfieReaction]
    /// Uploads the JPEG (`u/<uid>/selfies/<uuid>.jpg`), then `react_with_selfie`: replaces my selfie on the post.
    func reactWithSelfie(postID: PostID, jpeg: Data) async throws -> SelfieReaction
    /// `remove_selfie_reaction`: mine (`userID` nil), or anyone's on my own post.
    func removeSelfieReaction(postID: PostID, userID: UserID?) async throws

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
    /// The recap as last fetched this session (AppData keeps no offline copy of recaps).
    func cachedRecap(id: RecapID) async -> WeeklyRecap?
    func updateRecap(id: RecapID, items: [PostID], text: String) async throws -> WeeklyRecap
    /// Weeks with posts, newest first, pages of 8; `beforeWeek` is exclusive.
    func historyWeeks(groupID: GroupID, beforeWeek: LocalDate?) async throws -> [HistoryWeek]
    func cachedHistoryWeeks(groupID: GroupID) async -> [HistoryWeek]?
    /// `group_history_months` (migration 0045): the history's months, their days with something and the week each jumps
    /// to, newest month first (`week.history.layout.calendar`).
    func historyMonths(groupID: GroupID) async throws -> [HistoryMonth]
    func albums(groupID: GroupID) async throws -> [AlbumWithItems]
    func cachedAlbums(groupID: GroupID) async -> [AlbumWithItems]?
    func saveAlbum(groupID: GroupID, name: String, postIDs: [PostID]) async throws -> Album
    func renameAlbum(id: AlbumID, name: String) async throws -> Album
    func deleteAlbum(id: AlbumID, groupID: GroupID) async throws
    /// `add_to_album` (any member; photos already there are skipped).
    func addToAlbum(id: AlbumID, groupID: GroupID, postIDs: [PostID]) async throws -> Album
    /// `remove_from_album`: what you added; the album's creator and group admins remove any (`not_allowed` otherwise).
    func removeFromAlbum(id: AlbumID, groupID: GroupID, postIDs: [PostID]) async throws

    // MARK: Favorites and the group cover (migrations 0038, 0039)
    /// `set_favorite`: a heart only you see.
    func setFavorite(_ on: Bool, mediaID: MediaID) async throws
    /// Which of `mediaIDs` you favorited (your own `favorites` rows).
    func favoriteMediaIDs(among mediaIDs: [MediaID]) async throws -> Set<MediaID>
    /// `my_favorites`, newest favorite first; `before` pages back (the last `favoritedAt`).
    func favorites(before: Date?, limit: Int) async throws -> [FavoritePhoto]
    /// The first page of favorites as loaded this session (memory only: a deleted photo never stays on the device).
    func cachedFavorites() async -> [FavoritePhoto]?
    /// `set_group_cover_from_post` (group admins).
    func setGroupCover(groupID: GroupID, postID: PostID) async throws

    // MARK: Search (migration 0040, search.photos)
    /// `search_photos`: newest first, pages of `SocialPaging.search`; `before` pages back (the last hit's `createdAt`).
    /// Never called with an empty query (the RPC refuses it).
    func searchPhotos(_ query: PhotoSearchQuery, before: Date?) async throws -> [PhotoSearchHit]

    // MARK: Files (§7)
    /// A short-lived signed URL for a private storage path.
    func fileURL(path: String) async throws -> URL

    // MARK: Live
    /// Realtime inserts, updates and deletion broadcasts of one group (§8).
    func events(groupID: GroupID) -> AsyncStream<GroupEvent>
    /// The current reachability, then every change.
    func network() -> AsyncStream<NetworkStatus>
}

extension SocialDataSource {
    /// A text message that quotes nothing, or only a photo.
    func sendText(groupID: GroupID, body: String, replyToPostID: PostID?) async throws -> Message {
        try await sendText(groupID: groupID, body: body, replyToPostID: replyToPostID, replyToMessageID: nil)
    }
}

/// Page sizes fixed by the API contract (docs/API.md §5.9, §6.4) and the specs' "Data" sections.
enum SocialPaging {
    /// `chat.thread`: `limit(50)`.
    static let messages = ChatRepository.pageSize
    /// `walls.*`: `wall(p_limit: 50)`.
    static let wall = 50
    /// `week.history`: `group_history_weeks(p_limit: 8)`.
    static let historyWeeks = 8
    /// `favorites`: `my_favorites(p_limit: 60)`.
    static let favorites = 60
    /// `search.photos`: `search_photos(p_limit: 60)` (the API's default page).
    static let search = 60
}

/// What `search.photos` asks `search_photos` (migration 0040): every criterion given must match. No face or AI search.
struct PhotoSearchQuery: Equatable, Sendable {
    /// Words of a caption or of the chat about a photo (each a prefix).
    var text: String = ""
    /// One group (opened from `groups.screen`); nil: all your groups.
    var groupID: GroupID?
    /// Posted it, or tagged themselves "I'm in this".
    var memberID: UserID?
    /// The days it was taken, group-local, inclusive (either open).
    var from: LocalDate?
    var to: LocalDate?

    var trimmedText: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }

    /// No criterion: the page stays idle and nothing is asked (`invalid_argument` otherwise).
    var isEmpty: Bool { trimmedText.isEmpty && memberID == nil && from == nil && to == nil }
}

/// How a failed call is shown: every screen maps these to its own error / offline / gone copy.
enum SocialFailure: Equatable, Sendable {
    case offline
    case notFound
    case notReady
    case other

    /// `not_allowed` (PT403): someone else's row (`remove_from_album` of a photo another member added). AppData maps it
    /// to `APIErrorCode.notAllowed`; a fake or an older mapping may still carry it as `DataError.database`.
    static func isNotAllowed(_ error: Error) -> Bool {
        let mapped = DataError.from(error)
        if mapped.apiCode == .notAllowed { return true }
        if case let .database(_, message) = mapped { return message == notAllowedCode }
        return false
    }

    /// `media_not_ready` (PT409): the photo's display rendition is not made yet (`set_group_cover_from_post`).
    static func isMediaNotReady(_ error: Error) -> Bool {
        DataError.from(error).apiCode == .mediaNotReady
    }

    static let notAllowedCode = "not_allowed" // provenance-ok: API error code (docs/API.md §3)

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
