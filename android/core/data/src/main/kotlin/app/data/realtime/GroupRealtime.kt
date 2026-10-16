package app.data.realtime

import app.data.model.DataJson
import app.data.model.Message
import app.data.model.Post
import app.data.model.Reaction
import app.data.model.SelfieReaction
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.realtime.PostgresAction
import io.github.jan.supabase.realtime.Realtime
import io.github.jan.supabase.realtime.RealtimeChannel
import io.github.jan.supabase.realtime.broadcastFlow
import io.github.jan.supabase.realtime.channel
import io.github.jan.supabase.realtime.postgresChangeFlow
import io.github.jan.supabase.postgrest.query.filter.FilterOperator
import io.github.jan.supabase.realtime.realtime
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.CoroutineStart
import kotlinx.coroutines.NonCancellable
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.buffer
import kotlinx.coroutines.flow.channelFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.filterIsInstance
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.merge
import kotlinx.coroutines.flow.onEach
import kotlinx.coroutines.flow.shareIn
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import kotlinx.coroutines.withTimeoutOrNull
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.contentOrNull
import kotlinx.serialization.json.jsonPrimitive
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.CopyOnWriteArrayList
import kotlin.math.min
import kotlin.time.Duration
import kotlin.time.Duration.Companion.seconds

/** An open subscription. [live] is true while it delivers events. */
interface ChannelHandle {
    val live: StateFlow<Boolean>
    suspend fun close()
}

/** Opens one stream of one group; decoded events go to [sink]. */
fun interface RealtimeChannels {
    suspend fun open(groupId: String, stream: GroupEvent.Stream, sink: (GroupEvent) -> Unit): ChannelHandle
}

/** Backoff and timeouts of [GroupRealtime]. */
data class ReconnectPolicy(
    /** How long to wait for a new subscription to become live before retrying. */
    val subscribeTimeout: Duration = 15.seconds,
    /** How long a dropped subscription may stay down (supabase-kt reconnects itself) before it is re-opened. */
    val staleAfter: Duration = 20.seconds,
    val initialBackoff: Duration = 1.seconds,
    val maxBackoff: Duration = 60.seconds,
    /** Keep a group's channels open this long after the last collector leaves (screen rotation). */
    val stopTimeout: Duration = 5.seconds,
) {
    fun backoff(failures: Int): Duration {
        val factor = 1L shl min(failures.coerceAtLeast(1) - 1, MAX_SHIFT)
        return minOf(initialBackoff * factor.toDouble(), maxBackoff)
    }

    private companion object {
        const val MAX_SHIFT = 10
    }
}

/**
 * Per-group realtime as typed flows (docs/API.md §8): one shared subscription per group and
 * stream, however many screens collect it; re-opened with exponential backoff when it cannot be
 * established or stays down. Every (re)subscription is announced with [GroupEvent.Subscribed]
 * so screens refetch what they show (§8.3: realtime is best effort).
 */
class GroupRealtime(
    private val channels: RealtimeChannels,
    private val scope: CoroutineScope,
    private val policy: ReconnectPolicy = ReconnectPolicy(),
) {
    private val streams = ConcurrentHashMap<Pair<String, GroupEvent.Stream>, SharedFlow<GroupEvent>>()
    private val listeners = CopyOnWriteArrayList<suspend (GroupEvent) -> Unit>()

    /** Everything for [groupId]: inserts / updates, deletions and subscription state. */
    fun events(groupId: String): Flow<GroupEvent> = merge(stream(groupId, GroupEvent.Stream.Changes), stream(groupId, GroupEvent.Stream.Deletions))

    /** Only the private deletion topic (what the widget glue needs for every group). */
    fun deletions(groupId: String): Flow<GroupEvent> = stream(groupId, GroupEvent.Stream.Deletions)

    /** Called for every event of every collected group before collectors see it (cache upkeep). */
    fun addListener(listener: suspend (GroupEvent) -> Unit) {
        listeners += listener
    }

    private fun stream(groupId: String, stream: GroupEvent.Stream): SharedFlow<GroupEvent> =
        streams.getOrPut(groupId to stream) {
            connection(groupId, stream)
                .onEach { event -> listeners.forEach { listener -> runCatching { listener(event) } } }
                .shareIn(scope, SharingStarted.WhileSubscribed(policy.stopTimeout.inWholeMilliseconds, 0), replay = 0)
        }

    internal fun connection(groupId: String, stream: GroupEvent.Stream): Flow<GroupEvent> = channelFlow {
        var everLive = false
        var failures = 0
        while (true) {
            // Subscribing waits for the socket; bounded so a dead server cannot stall the loop.
            val handle = try {
                withTimeoutOrNull(policy.subscribeTimeout) { channels.open(groupId, stream) { event -> trySend(event) } }
            } catch (e: CancellationException) {
                throw e
            } catch (_: Exception) {
                null
            }
            if (handle != null) {
                try {
                    val live = withTimeoutOrNull(policy.subscribeTimeout) { handle.live.first { it } } != null
                    if (live) {
                        failures = 0
                        send(GroupEvent.Subscribed(groupId, stream, resumed = everLive))
                        everLive = true
                        while (true) {
                            handle.live.first { !it }
                            withTimeoutOrNull(policy.staleAfter) { handle.live.first { it } } ?: break
                            send(GroupEvent.Subscribed(groupId, stream, resumed = true))
                        }
                    } else {
                        send(GroupEvent.Unavailable(groupId, stream))
                    }
                } finally {
                    withContext(NonCancellable) { runCatching { handle.close() } }
                }
            }
            failures++
            delay(policy.backoff(failures))
        }
    }.buffer(Channel.UNLIMITED)
}

/** [RealtimeChannels] over supabase-kt Realtime. */
class SupabaseRealtimeChannels(private val client: SupabaseClient, private val scope: CoroutineScope) : RealtimeChannels {

    override suspend fun open(groupId: String, stream: GroupEvent.Stream, sink: (GroupEvent) -> Unit): ChannelHandle {
        val realtime = client.realtime
        val channelId = when (stream) {
            GroupEvent.Stream.Changes -> "group-changes-$groupId"
            GroupEvent.Stream.Deletions -> "group:$groupId"
        }
        // supabase-kt hands back a channel still registered under the same topic; start clean.
        realtime.subscriptions["realtime:$channelId"]?.let { stale -> runCatching { realtime.removeChannel(stale) } }
        val channel: RealtimeChannel = when (stream) {
            GroupEvent.Stream.Changes -> realtime.channel(channelId)
            // Only current members may join (RLS on realtime.messages); clients cannot send on it.
            GroupEvent.Stream.Deletions -> realtime.channel(channelId) { isPrivate = true }
        }
        val job = SupervisorJob(scope.coroutineContext[kotlinx.coroutines.Job])
        val channelScope = CoroutineScope(scope.coroutineContext + job)
        when (stream) {
            GroupEvent.Stream.Changes -> for (table in CHANGE_TABLES) {
                val flow = channel.postgresChangeFlow<PostgresAction>(schema = "public") {
                    this.table = table
                    filter("group_id", FilterOperator.EQ, groupId)
                }
                channelScope.launch(start = CoroutineStart.UNDISPATCHED) {
                    flow.collect { action -> RealtimeDecoding.change(groupId, table, action)?.let(sink) }
                }
            }
            GroupEvent.Stream.Deletions -> for (event in BROADCAST_EVENTS) {
                val flow = channel.broadcastFlow<JsonObject>(event)
                channelScope.launch(start = CoroutineStart.UNDISPATCHED) {
                    flow.collect { payload -> RealtimeDecoding.broadcast(groupId, event, payload)?.let(sink) }
                }
            }
        }
        val live = combine(realtime.status, channel.status) { socket, joined ->
            socket == Realtime.Status.CONNECTED && joined == RealtimeChannel.Status.SUBSCRIBED
        }.stateIn(channelScope, SharingStarted.Eagerly, false)
        try {
            channel.subscribe(blockUntilSubscribed = false)
        } catch (t: Throwable) {
            withContext(NonCancellable) {
                job.cancel()
                runCatching { realtime.removeChannel(channel) }
            }
            throw t
        }
        return object : ChannelHandle {
            override val live: StateFlow<Boolean> = live

            override suspend fun close() {
                job.cancel()
                runCatching { realtime.removeChannel(channel) }
            }
        }
    }

    private companion object {
        val CHANGE_TABLES = listOf("messages", "posts", "reactions", "selfie_reactions")
        val BROADCAST_EVENTS = listOf("post_deleted", "message_deleted", "reactions_changed", "developing_changed")
    }
}

/** Realtime payload → [GroupEvent]. Rows from another group are dropped (defence in depth). */
object RealtimeDecoding {

    fun change(groupId: String, table: String, action: PostgresAction): GroupEvent? {
        val record = when (action) {
            is PostgresAction.Insert -> action.record
            is PostgresAction.Update -> action.record
            else -> return null // deletions are never published (§8.2)
        }
        val update = action is PostgresAction.Update
        return change(groupId, table, record, update)
    }

    fun change(groupId: String, table: String, record: JsonObject, update: Boolean): GroupEvent? = try {
        when (table) {
            "messages" -> DataJson.decodeFromJsonElement(Message.serializer(), record).takeIf { it.groupId == groupId }
                ?.let { if (update) GroupEvent.MessageUpdated(groupId, it) else GroupEvent.MessageInserted(groupId, it) }
            "posts" -> DataJson.decodeFromJsonElement(Post.serializer(), record).takeIf { it.groupId == groupId }
                ?.let { if (update) GroupEvent.PostUpdated(groupId, it) else GroupEvent.PostInserted(groupId, it) }
            "reactions" -> DataJson.decodeFromJsonElement(Reaction.serializer(), record).takeIf { it.groupId == groupId }
                ?.let { GroupEvent.ReactionAdded(groupId, it) }
            "selfie_reactions" -> DataJson.decodeFromJsonElement(SelfieReaction.serializer(), record).takeIf { it.groupId == groupId }
                ?.let { GroupEvent.SelfieReactionChanged(groupId, it) }
            else -> null
        }
    } catch (_: Exception) {
        null
    }

    /** `realtime.send` payloads arrive either bare or wrapped as `{event, payload, type}`. */
    fun broadcast(groupId: String, event: String, message: JsonObject): GroupEvent? {
        val payload = (message["payload"] as? JsonObject) ?: message
        fun field(name: String) = runCatching { payload[name]?.jsonPrimitive?.contentOrNull }.getOrNull()
        return when (event) {
            "post_deleted" -> field("post_id")?.let { GroupEvent.PostDeleted(groupId, it, field("media_id")) }
            "message_deleted" -> field("message_id")?.let { GroupEvent.MessageDeleted(groupId, it) }
            "reactions_changed" -> field("post_id")?.let { GroupEvent.ReactionsChanged(groupId, it) }
            "developing_changed" -> GroupEvent.DevelopingChanged(groupId)
            else -> null
        }
    }
}

/** Keeps only events of the given type. */
inline fun <reified T : GroupEvent> Flow<GroupEvent>.only(): Flow<T> = filterIsInstance<T>()
