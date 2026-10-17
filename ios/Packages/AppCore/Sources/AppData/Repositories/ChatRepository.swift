import Foundation
import Supabase

/// Group chat (docs/API.md §5.9, §6.2). Photo messages are created by `create_post`.
public struct ChatRepository: Sendable {
    public static let pageSize = 50

    public let client: DataClient
    private let cache: OfflineCache?

    public init(client: DataClient, cache: OfflineCache? = nil) {
        self.client = client
        self.cache = cache
    }

    /// Newest first. The first page is cached for offline display.
    public func page(groupID: GroupID, before: Date? = nil, limit: Int = ChatRepository.pageSize) async throws -> Page<Message> {
        let messages = try await client.rows(Message.self) {
            var query = client.supabase.from("messages").select().eq("group_id", value: groupID.rawValue)
            if let before { query = query.lt("created_at", value: Timestamp.format(before)) }
            return query.order("created_at", ascending: false).limit(limit)
        }
        if before == nil { await cache?.write(messages, for: .chat(groupID)) }
        return Page(items: messages, nextCursor: messages.count == limit ? messages.last?.createdAt : nil)
    }

    public func cachedPage(groupID: GroupID) async -> CachedValue<[Message]>? {
        await cache?.read([Message].self, for: .chat(groupID))
    }

    public func message(id: MessageID) async throws -> Message? {
        try await client.firstRow(Message.self) {
            client.supabase.from("messages").select().eq("id", value: id.rawValue).limit(1)
        }
    }

    /// A text message (non-blank, ≤ 4000). `replyToPostID` replies to a photo of this group,
    /// `replyToMessageID` to a message.
    public func sendText(
        groupID: GroupID,
        body: String,
        replyToPostID: PostID? = nil,
        replyToMessageID: MessageID? = nil
    ) async throws -> Message {
        try await client.rpc("send_message", [
            "p_group_id": .id(groupID),
            "p_kind": .string(MessageKind.text.rawValue),
            "p_body": .string(body),
            "p_reply_to_post_id": .id(replyToPostID),
            "p_reply_to_message_id": .id(replyToMessageID),
        ])
    }

    /// A voice message: upload first (`MediaUploader.uploadChatVoice`), then send its path.
    public func sendVoice(
        groupID: GroupID,
        voicePath: String,
        durationMs: Int,
        levels: [Int]? = nil,
        replyToPostID: PostID? = nil,
        replyToMessageID: MessageID? = nil
    ) async throws -> Message {
        try await client.rpc("send_message", [
            "p_group_id": .id(groupID),
            "p_kind": .string(MessageKind.voice.rawValue),
            "p_voice_path": .string(voicePath),
            "p_voice_duration_ms": .integer(durationMs),
            "p_voice_levels": .levels(levels),
            "p_reply_to_post_id": .id(replyToPostID),
            "p_reply_to_message_id": .id(replyToMessageID),
        ])
    }

    /// `edit_message` (migration 0047): your own text message, inside `message_edit_window_s`; returns the row with
    /// `edited_at` set. Fails with `edit_window_closed` once the window passed (or the edits ran out).
    public func edit(messageID: MessageID, body: String) async throws -> Message {
        try await client.rpc("edit_message", ["p_message_id": .id(messageID), "p_body": .string(body)])
    }

    /// `set_typing` (migration 0048): `true` while typing (again every `typing_ttl_s / 2`), `false` when the field
    /// empties, the message is sent or the thread closes.
    public func setTyping(groupID: GroupID, typing: Bool) async throws {
        try await client.rpcVoid("set_typing", ["p_group_id": .id(groupID), "p_typing": .bool(typing)])
    }

    /// The group's `chat_typing` rows whose `until` is still ahead (§5.10b): who is typing now. Never a count.
    public func typing(groupID: GroupID, now: Date = Date()) async throws -> [ChatTyping] {
        try await client.rows(ChatTyping.self) {
            client.supabase.from("chat_typing").select()
                .eq("group_id", value: groupID.rawValue)
                .gt("until", value: Timestamp.format(now))
        }
    }

    /// Deletes the caller's own text or voice message (a photo message goes with `deletePost`).
    public func delete(messageID: MessageID, groupID: GroupID) async throws {
        try await client.rpcVoid("delete_message", ["p_message_id": .id(messageID)])
        await cache?.purgeMessage(messageID, groupID: groupID)
    }
}
