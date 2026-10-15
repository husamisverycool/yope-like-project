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
        replyToPostID: PostID? = nil,
        replyToMessageID: MessageID? = nil
    ) async throws -> Message {
        try await client.rpc("send_message", [
            "p_group_id": .id(groupID),
            "p_kind": .string(MessageKind.voice.rawValue),
            "p_voice_path": .string(voicePath),
            "p_voice_duration_ms": .integer(durationMs),
            "p_reply_to_post_id": .id(replyToPostID),
            "p_reply_to_message_id": .id(replyToMessageID),
        ])
    }

    /// Deletes the caller's own text or voice message (a photo message goes with `deletePost`).
    public func delete(messageID: MessageID, groupID: GroupID) async throws {
        try await client.rpcVoid("delete_message", ["p_message_id": .id(messageID)])
        await cache?.purgeMessage(messageID, groupID: groupID)
    }
}
