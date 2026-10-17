import Foundation
import Supabase

/// Something that happened in a group, as delivered by Realtime (docs/API.md §8).
public enum GroupEvent: Hashable, Sendable {
    case postInserted(Post)
    /// A reply lost its target (`reply_to_post_id` set to null after a deletion).
    case postUpdated(Post)
    case messageInserted(Message)
    case messageUpdated(Message)
    case reactionInserted(Reaction)
    /// A selfie reaction was sent or replaced (`selfie_reactions` inserts and updates, docs/API.md §14.1); its
    /// removals arrive as `reactionsChanged`.
    case selfieReactionUpserted(SelfieReaction)
    /// Remove the post and its chat photo message; drop it from walls, recaps, albums.
    case postDeleted(postID: PostID, mediaID: MediaID?)
    case messageDeleted(MessageID)
    /// Refetch that post's reactions (a reaction was removed; the payload names no one).
    case reactionsChanged(PostID)
    /// Overnight photos were set to develop or were revealed in the group (`developing_changed`, no payload; docs/API.md
    /// §14.3): refetch the posts and the developing state.
    case developingChanged
    /// A plan of the group or an answer to one was inserted or updated (`plans`, `plan_answers`; docs/API.md §14.2
    /// "Realtime: inserts and updates of both tables"): refetch the plans. Rows are not decoded: the screens refetch what
    /// RLS lets them read (a Can't go only reaches its author and the plan's maker).
    case plansChanged
    /// The topic was joined (first join; `realtime:group-<id>` or `realtime:group:<id>`).
    case subscribed(topic: String)
    /// The subscription is live again after a dropped connection: refetch the visible page
    /// (Realtime is best effort; events during the gap are lost, §8.3).
    case resubscribed
    /// The topic could not be joined (e.g. the deletion topic of a group the caller is not in).
    case subscriptionFailed(topic: String)

    public var groupScopedPostID: PostID? {
        switch self {
        case let .postInserted(post), let .postUpdated(post): return post.id
        case let .postDeleted(id, _): return id
        case let .reactionsChanged(id): return id
        case let .reactionInserted(reaction): return reaction.postID
        case let .selfieReactionUpserted(selfie): return selfie.postID
        default: return nil
        }
    }
}

/// Which events a subscriber wants.
public struct GroupEventFilter: OptionSet, Hashable, Sendable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }

    /// Inserts and updates of posts, messages, reactions, selfie reactions, plans and plan answers (`postgres_changes`,
    /// channel `group-<id>`).
    public static let changes = GroupEventFilter(rawValue: 1 << 0)
    /// The private `group:<id>` broadcast topic: deletions and reaction removals.
    public static let deletions = GroupEventFilter(rawValue: 1 << 1)
    public static let all: GroupEventFilter = [.changes, .deletions]
}

/// One place that owns the Realtime channels of each group and fans their events out to any
/// number of `AsyncStream` subscribers (supabase-swift keeps one channel per topic, so two
/// screens — or a screen and the session glue — must share it).
///
/// Per group there are up to two channels, each opened on first use and closed when its last
/// subscriber goes away:
/// - `group-<id>`: `postgres_changes` INSERT/UPDATE on messages, posts, reactions, selfie_reactions, plans and
///   plan_answers filtered by `group_id` (RLS applies, so only rows the caller could select arrive);
/// - `group:<id>` (private): broadcasts `post_deleted`, `message_deleted`, `reactions_changed`, `developing_changed`;
///   only current members can join.
public actor RealtimeHub {
    public let client: DataClient

    private final class Channel {
        let channel: RealtimeChannelV2
        var tasks: [Task<Void, Never>] = []
        init(channel: RealtimeChannelV2) { self.channel = channel }
    }

    private struct Subscriber {
        let filter: GroupEventFilter
        let continuation: AsyncStream<GroupEvent>.Continuation
    }

    private struct GroupState {
        var subscribers: [UUID: Subscriber] = [:]
        var changes: Channel?
        var deletions: Channel?
    }

    private var groups: [GroupID: GroupState] = [:]
    /// Channel removals in progress, by topic. supabase-swift hands back the channel registered under a topic until
    /// `removeChannel` returns, so a channel of that topic is made again only once its removal has finished (run 110:
    /// a subscriber that came right after the last one left got the channel being removed, and its join never
    /// completed).
    private var removals: [String: Task<Void, Never>] = [:]

    public init(client: DataClient) {
        self.client = client
    }

    /// Events of one group. The stream stays open until the consumer stops iterating (or the
    /// task is cancelled); then the group's channels close if nobody else listens.
    public nonisolated func events(for groupID: GroupID, filter: GroupEventFilter = .all) -> AsyncStream<GroupEvent> {
        let (stream, continuation) = AsyncStream<GroupEvent>.makeStream(bufferingPolicy: .bufferingNewest(500))
        let id = UUID()
        continuation.onTermination = { [weak self] _ in
            guard let self else { return }
            Task { await self.removeSubscriber(id, groupID: groupID) }
        }
        Task { await self.addSubscriber(id, groupID: groupID, filter: filter, continuation: continuation) }
        return stream
    }

    /// Groups with at least one live subscriber.
    public func subscribedGroups() -> [GroupID] {
        Array(groups.keys)
    }

    /// Closes every channel and finishes every stream (sign-out).
    public func stopAll() async {
        let all = groups
        groups.removeAll()
        for (_, state) in all {
            for subscriber in state.subscribers.values { subscriber.continuation.finish() }
            await close(state.changes)
            await close(state.deletions)
        }
    }

    // MARK: Subscribers

    private func addSubscriber(_ id: UUID, groupID: GroupID, filter: GroupEventFilter, continuation: AsyncStream<GroupEvent>.Continuation) async {
        var registered = groups[groupID] ?? GroupState()
        registered.subscribers[id] = Subscriber(filter: filter, continuation: continuation)
        groups[groupID] = registered
        // A channel to make whose topic is still being removed waits for the removal (see `removals`).
        if filter.contains(.changes), registered.changes == nil { await awaitRemoval(of: Self.changesTopic(groupID)) }
        if filter.contains(.deletions), registered.deletions == nil { await awaitRemoval(of: Self.deletionsTopic(groupID)) }
        // Meanwhile the subscriber may have left, or another one made the channels.
        guard var state = groups[groupID], state.subscribers[id] != nil else { return }
        let needsChanges = filter.contains(.changes) && state.changes == nil
        let needsDeletions = filter.contains(.deletions) && state.deletions == nil
        if needsChanges { state.changes = makeChangesChannel(groupID) }
        if needsDeletions { state.deletions = makeDeletionsChannel(groupID) }
        groups[groupID] = state
        // A late subscriber of an already joined channel learns that it is live.
        for (kind, box) in [(GroupEventFilter.changes, state.changes), (.deletions, state.deletions)]
        where filter.contains(kind) && !(kind == .changes ? needsChanges : needsDeletions) {
            if let box, box.channel.status == .subscribed {
                continuation.yield(.subscribed(topic: box.channel.topic))
            }
        }
        if needsChanges, let channel = state.changes { await subscribe(channel, groupID: groupID, kind: .changes) }
        if needsDeletions, let channel = state.deletions { await subscribe(channel, groupID: groupID, kind: .deletions) }
    }

    private func removeSubscriber(_ id: UUID, groupID: GroupID) async {
        guard var state = groups[groupID], state.subscribers.removeValue(forKey: id) != nil else { return }
        let wantsChanges = state.subscribers.values.contains { $0.filter.contains(.changes) }
        let wantsDeletions = state.subscribers.values.contains { $0.filter.contains(.deletions) }
        var closing: [Channel] = []
        if !wantsChanges, let channel = state.changes {
            closing.append(channel)
            state.changes = nil
        }
        if !wantsDeletions, let channel = state.deletions {
            closing.append(channel)
            state.deletions = nil
        }
        groups[groupID] = state.subscribers.isEmpty ? nil : state
        // Registered before the first suspension, so a subscriber arriving meanwhile waits for them.
        let removing = closing.map { beginRemoval($0) }
        for removal in removing { await removal.value }
    }

    private func emit(_ event: GroupEvent, groupID: GroupID, kind: GroupEventFilter) {
        guard let state = groups[groupID] else { return }
        RealtimeTrace.log("group \(groupID.rawValue): \(RealtimeTrace.kind(event)) to \(state.subscribers.count) subscriber(s)")
        for subscriber in state.subscribers.values where !subscriber.filter.isDisjoint(with: kind) {
            subscriber.continuation.yield(event)
        }
    }

    // MARK: Channels

    /// supabase-swift's full topic names of a group's channels (`realtime:` + the name given to `channel(_:)`).
    private static func changesTopic(_ groupID: GroupID) -> String { "realtime:group-\(groupID.rawValue)" }
    private static func deletionsTopic(_ groupID: GroupID) -> String { "realtime:group:\(groupID.rawValue)" }

    private func makeChangesChannel(_ groupID: GroupID) -> Channel {
        let channel = client.supabase.channel("group-\(groupID.rawValue)")
        let box = Channel(channel: channel)
        let filter = RealtimePostgresFilter.eq("group_id", value: groupID.rawValue)
        // Streams are registered before subscribing, as supabase-swift requires.
        let postInserts = channel.postgresChange(InsertAction.self, schema: "public", table: "posts", filter: filter)
        let postUpdates = channel.postgresChange(UpdateAction.self, schema: "public", table: "posts", filter: filter)
        let messageInserts = channel.postgresChange(InsertAction.self, schema: "public", table: "messages", filter: filter)
        let messageUpdates = channel.postgresChange(UpdateAction.self, schema: "public", table: "messages", filter: filter)
        let reactionInserts = channel.postgresChange(InsertAction.self, schema: "public", table: "reactions", filter: filter)
        let selfieInserts = channel.postgresChange(InsertAction.self, schema: "public", table: "selfie_reactions", filter: filter)
        let selfieUpdates = channel.postgresChange(UpdateAction.self, schema: "public", table: "selfie_reactions", filter: filter)
        let planInserts = channel.postgresChange(InsertAction.self, schema: "public", table: "plans", filter: filter)
        let planUpdates = channel.postgresChange(UpdateAction.self, schema: "public", table: "plans", filter: filter)
        let answerInserts = channel.postgresChange(InsertAction.self, schema: "public", table: "plan_answers", filter: filter)
        let answerUpdates = channel.postgresChange(UpdateAction.self, schema: "public", table: "plan_answers", filter: filter)
        box.tasks.append(forward(postInserts, groupID: groupID) { try GroupEvent.postInserted($0.decodeRecord(decoder: DataCoding.makeDecoder())) })
        box.tasks.append(forward(postUpdates, groupID: groupID) { try GroupEvent.postUpdated($0.decodeRecord(decoder: DataCoding.makeDecoder())) })
        box.tasks.append(forward(messageInserts, groupID: groupID) { try GroupEvent.messageInserted($0.decodeRecord(decoder: DataCoding.makeDecoder())) })
        box.tasks.append(forward(messageUpdates, groupID: groupID) { try GroupEvent.messageUpdated($0.decodeRecord(decoder: DataCoding.makeDecoder())) })
        box.tasks.append(forward(reactionInserts, groupID: groupID) { try GroupEvent.reactionInserted($0.decodeRecord(decoder: DataCoding.makeDecoder())) })
        box.tasks.append(forward(selfieInserts, groupID: groupID) { try GroupEvent.selfieReactionUpserted($0.decodeRecord(decoder: DataCoding.makeDecoder())) })
        box.tasks.append(forward(selfieUpdates, groupID: groupID) { try GroupEvent.selfieReactionUpserted($0.decodeRecord(decoder: DataCoding.makeDecoder())) })
        for plans in [planInserts, answerInserts] {
            box.tasks.append(forward(plans, groupID: groupID) { _ in GroupEvent.plansChanged })
        }
        for plans in [planUpdates, answerUpdates] {
            box.tasks.append(forward(plans, groupID: groupID) { _ in GroupEvent.plansChanged })
        }
        return box
    }

    private func makeDeletionsChannel(_ groupID: GroupID) -> Channel {
        let channel = client.supabase.channel("group:\(groupID.rawValue)") { $0.isPrivate = true }
        let box = Channel(channel: channel)
        let postDeleted = channel.broadcastStream(event: "post_deleted")
        let messageDeleted = channel.broadcastStream(event: "message_deleted")
        let reactionsChanged = channel.broadcastStream(event: "reactions_changed")
        let developingChanged = channel.broadcastStream(event: "developing_changed")
        box.tasks.append(forwardBroadcast(postDeleted, groupID: groupID) { (payload: JSONObject) -> GroupEvent? in
            guard let post = payload["post_id"]?.stringValue else { return nil }
            let media: MediaID? = payload["media_id"]?.stringValue.map { (text: String) -> MediaID in MediaID(rawValue: text) }
            return GroupEvent.postDeleted(postID: PostID(rawValue: post), mediaID: media)
        })
        box.tasks.append(forwardBroadcast(messageDeleted, groupID: groupID) { (payload: JSONObject) -> GroupEvent? in
            guard let message = payload["message_id"]?.stringValue else { return nil }
            return GroupEvent.messageDeleted(MessageID(rawValue: message))
        })
        box.tasks.append(forwardBroadcast(reactionsChanged, groupID: groupID) { (payload: JSONObject) -> GroupEvent? in
            guard let post = payload["post_id"]?.stringValue else { return nil }
            return GroupEvent.reactionsChanged(PostID(rawValue: post))
        })
        box.tasks.append(forwardBroadcast(developingChanged, groupID: groupID) { (_: JSONObject) -> GroupEvent? in
            GroupEvent.developingChanged
        })
        return box
    }

    private nonisolated func forward<Action: Sendable>(
        _ stream: AsyncStream<Action>,
        groupID: GroupID,
        _ makeEvent: @escaping @Sendable (Action) throws -> GroupEvent
    ) -> Task<Void, Never> {
        Task { [weak self] in
            for await action in stream {
                guard let event = try? makeEvent(action) else { continue }
                await self?.emit(event, groupID: groupID, kind: .changes)
            }
        }
    }

    private nonisolated func forwardBroadcast(
        _ stream: AsyncStream<JSONObject>,
        groupID: GroupID,
        _ makeEvent: @escaping @Sendable (JSONObject) -> GroupEvent?
    ) -> Task<Void, Never> {
        Task { [weak self] in
            for await message in stream {
                // supabase-swift hands over the whole broadcast: {event, payload, type}.
                let payload = message["payload"]?.objectValue ?? message
                guard let event = makeEvent(payload) else { continue }
                await self?.emit(event, groupID: groupID, kind: .deletions)
            }
        }
    }

    private func subscribe(_ box: Channel, groupID: GroupID, kind: GroupEventFilter, attempt: Int = 0) async {
        let channel = box.channel
        do {
            try await channel.subscribeWithError()
        } catch {
            // The server answers a refused join (a non-member on `group:<id>`) with nothing, so a
            // failure of that topic on a connected socket is final; with the socket down (offline) it
            // is retried. `group-<id>` refuses no one (RLS filters its rows): its failures are retried.
            let socketDown = client.supabase.realtimeV2.status != .connected
            RealtimeTrace.log("join failed \(channel.topic): \(error) (socket \(client.supabase.realtimeV2.status))")
            emit(.subscriptionFailed(topic: channel.topic), groupID: groupID, kind: kind)
            // Drop the dead channel so a later subscriber (or the retry) can join again.
            if var state = groups[groupID] {
                if kind == .changes, state.changes === box { state.changes = nil }
                if kind == .deletions, state.deletions === box { state.deletions = nil }
                groups[groupID] = state
            }
            await close(box)
            if socketDown || kind == .changes { scheduleRetry(groupID: groupID, kind: kind, attempt: attempt + 1) }
            return
        }
        emit(.subscribed(topic: channel.topic), groupID: groupID, kind: kind)
        // After the first join, every return to `.subscribed` follows a reconnect.
        let statuses = channel.statusChange
        let topic = channel.topic
        box.tasks.append(Task { [weak self] in
            var wasDown = false
            for await status in statuses {
                RealtimeTrace.log("\(topic): \(status)")
                switch status {
                case .subscribed:
                    if wasDown {
                        wasDown = false
                        await self?.emit(.resubscribed, groupID: groupID, kind: kind)
                    }
                case .unsubscribed, .subscribing:
                    wasDown = true
                case .unsubscribing:
                    break
                }
            }
        })
    }

    /// Re-joins after `min(60, 2^attempt)` seconds while someone still wants that channel.
    private func scheduleRetry(groupID: GroupID, kind: GroupEventFilter, attempt: Int) {
        let delay = min(60, pow(2, Double(attempt)))
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            await self?.retry(groupID: groupID, kind: kind, attempt: attempt)
        }
    }

    private func retry(groupID: GroupID, kind: GroupEventFilter, attempt: Int) async {
        await awaitRemoval(of: kind == .changes ? Self.changesTopic(groupID) : Self.deletionsTopic(groupID))
        guard var state = groups[groupID], state.subscribers.values.contains(where: { $0.filter.contains(kind) }) else { return }
        let box: Channel
        if kind == .changes {
            guard state.changes == nil else { return }
            box = makeChangesChannel(groupID)
            state.changes = box
        } else {
            guard state.deletions == nil else { return }
            box = makeDeletionsChannel(groupID)
            state.deletions = box
        }
        groups[groupID] = state
        await subscribe(box, groupID: groupID, kind: kind, attempt: attempt)
    }

    private func close(_ box: Channel?) async {
        guard let box else { return }
        await beginRemoval(box).value
    }

    /// Stops forwarding `box`'s events and removes its channel from supabase-swift, recorded in `removals` under its
    /// topic until done (after any earlier removal of the same topic).
    private func beginRemoval(_ box: Channel) -> Task<Void, Never> {
        box.tasks.forEach { $0.cancel() }
        let channel = box.channel
        let topic = channel.topic
        let earlier = removals[topic]
        let supabase = client.supabase
        let removal = Task {
            await earlier?.value
            await supabase.removeChannel(channel)
        }
        removals[topic] = removal
        return removal
    }

    /// Returns once no channel of `topic` is being removed.
    private func awaitRemoval(of topic: String) async {
        while let removal = removals[topic] {
            await removal.value
            if removals[topic] == removal { removals[topic] = nil }
        }
    }
}
