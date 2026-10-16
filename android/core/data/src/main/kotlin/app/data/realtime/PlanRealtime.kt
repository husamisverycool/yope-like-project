package app.data.realtime

import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.postgrest.query.filter.FilterOperator
import io.github.jan.supabase.realtime.PostgresAction
import io.github.jan.supabase.realtime.RealtimeChannel
import io.github.jan.supabase.realtime.channel
import io.github.jan.supabase.realtime.postgresChangeFlow
import io.github.jan.supabase.realtime.realtime
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.NonCancellable
import kotlinx.coroutines.awaitCancellation
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.channelFlow
import kotlinx.coroutines.flow.conflate
import kotlinx.coroutines.flow.shareIn
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.util.concurrent.ConcurrentHashMap

/**
 * Inserts and updates of `plans` and `plan_answers` in one group (docs/API.md §14.2 "Realtime: inserts and updates of
 * both tables"), as a refetch signal: one `Unit` per change, and one each time the subscription becomes live (a
 * reconnect may have missed changes, §8.3). Its own channel (`plans-<group id>`), shared by every collector of the
 * group, so the group screen's and the plan page's subscriptions never replace each other; rows are not decoded (the
 * screens refetch what RLS lets them see — Can't go rows included only for their author and the maker).
 */
class PlanRealtime(private val client: SupabaseClient, private val scope: CoroutineScope, private val stopTimeoutMillis: Long = STOP_TIMEOUT_MS) {
    private val streams = ConcurrentHashMap<String, SharedFlow<Unit>>()

    fun changes(groupId: String): Flow<Unit> = streams.getOrPut(groupId) {
        open(groupId).shareIn(scope, SharingStarted.WhileSubscribed(stopTimeoutMillis, 0), replay = 0)
    }

    private fun open(groupId: String): Flow<Unit> = channelFlow {
        val realtime = client.realtime
        val topic = "plans-$groupId"
        // supabase-kt hands back a channel still registered under the same topic; start clean.
        realtime.subscriptions["realtime:$topic"]?.let { stale -> runCatching { realtime.removeChannel(stale) } }
        val channel = realtime.channel(topic)
        for (table in TABLES) {
            val flow = channel.postgresChangeFlow<PostgresAction>(schema = "public") {
                this.table = table
                filter("group_id", FilterOperator.EQ, groupId)
            }
            launch { flow.collect { action -> if (action is PostgresAction.Insert || action is PostgresAction.Update) send(Unit) } }
        }
        launch { channel.status.collect { status -> if (status == RealtimeChannel.Status.SUBSCRIBED) send(Unit) } }
        try {
            channel.subscribe(blockUntilSubscribed = false)
            awaitCancellation()
        } finally {
            withContext(NonCancellable) { runCatching { realtime.removeChannel(channel) } }
        }
    }.conflate()

    private companion object {
        val TABLES = listOf("plans", "plan_answers")

        /** Keep a group's channel open this long after the last collector leaves (screen rotation, page → group). */
        const val STOP_TIMEOUT_MS = 5_000L
    }
}
