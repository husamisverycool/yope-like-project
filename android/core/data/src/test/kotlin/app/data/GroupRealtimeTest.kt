package app.data

import app.data.realtime.ChannelHandle
import app.data.realtime.GroupEvent
import app.data.realtime.GroupRealtime
import app.data.realtime.RealtimeChannels
import app.data.realtime.ReconnectPolicy
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.awaitCancellation
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.advanceTimeBy
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import kotlin.time.Duration.Companion.seconds

/** Sharing, reconnection and backoff of [GroupRealtime], with fake channels and virtual time. */
@OptIn(ExperimentalCoroutinesApi::class)
class GroupRealtimeTest {

    private class FakeChannel(val groupId: String, val stream: GroupEvent.Stream, val sink: (GroupEvent) -> Unit) : ChannelHandle {
        val state = MutableStateFlow(false)
        var closed = false
        override val live: StateFlow<Boolean> = state
        override suspend fun close() { closed = true }
    }

    private class FakeChannels(var hang: Boolean = false, var refuse: Boolean = false) : RealtimeChannels {
        val opened = mutableListOf<FakeChannel>()
        override suspend fun open(groupId: String, stream: GroupEvent.Stream, sink: (GroupEvent) -> Unit): ChannelHandle {
            if (hang) awaitCancellation()
            if (refuse) error("refused")
            return FakeChannel(groupId, stream, sink).also { opened += it }
        }

        fun current(stream: GroupEvent.Stream) = opened.last { it.stream == stream && !it.closed }
    }

    private val policy = ReconnectPolicy(subscribeTimeout = 10.seconds, staleAfter = 20.seconds, initialBackoff = 1.seconds, maxBackoff = 8.seconds, stopTimeout = 5.seconds)

    private fun TestScope.collect(realtime: GroupRealtime, groupId: String, into: MutableList<GroupEvent>) =
        backgroundScope.launch { realtime.events(groupId).collect { into += it } }

    @Test fun announcesSubscriptionForwardsEventsAndSharesOneChannelPerStream() = runTest {
        val channels = FakeChannels()
        val realtime = GroupRealtime(channels, backgroundScope, policy)
        val first = mutableListOf<GroupEvent>()
        val second = mutableListOf<GroupEvent>()
        collect(realtime, "g", first)
        collect(realtime, "g", second)
        runCurrent()
        assertEquals(2, channels.opened.size) // Changes + Deletions, shared by both collectors
        channels.opened.forEach { it.state.value = true }
        runCurrent()
        val deleted = GroupEvent.PostDeleted("g", "p", "m")
        channels.current(GroupEvent.Stream.Deletions).sink(deleted)
        runCurrent()
        for (events in listOf(first, second)) {
            assertEquals(
                setOf(GroupEvent.Subscribed("g", GroupEvent.Stream.Changes, false), GroupEvent.Subscribed("g", GroupEvent.Stream.Deletions, false)),
                events.filterIsInstance<GroupEvent.Subscribed>().toSet(),
            )
            assertEquals(deleted, events.last())
        }
    }

    @Test fun aShortDropResumesInPlaceALongOneReopensWithBackoff() = runTest {
        val channels = FakeChannels()
        val realtime = GroupRealtime(channels, backgroundScope, policy)
        val events = mutableListOf<GroupEvent>()
        backgroundScope.launch { realtime.deletions("g").collect { events += it } }
        runCurrent()
        val channel = channels.current(GroupEvent.Stream.Deletions)
        channel.state.value = true
        runCurrent()

        // supabase-kt reconnects by itself within staleAfter: same channel, "resumed".
        channel.state.value = false
        advanceTimeBy(5_000)
        channel.state.value = true
        runCurrent()
        assertEquals(GroupEvent.Subscribed("g", GroupEvent.Stream.Deletions, resumed = true), events.last())
        assertEquals(1, channels.opened.size)

        // Down for longer than staleAfter: closed, reopened after the backoff, "resumed" again.
        channel.state.value = false
        advanceTimeBy(20_001)
        runCurrent()
        assertTrue(channel.closed)
        advanceTimeBy(1_001)
        runCurrent()
        assertEquals(2, channels.opened.size)
        channels.current(GroupEvent.Stream.Deletions).state.value = true
        runCurrent()
        assertEquals(GroupEvent.Subscribed("g", GroupEvent.Stream.Deletions, resumed = true), events.last())
    }

    @Test fun anUnreachableOrRefusedSubscriptionIsReportedAndRetriedWithGrowingBackoff() = runTest {
        val channels = FakeChannels()
        val realtime = GroupRealtime(channels, backgroundScope, policy)
        val events = mutableListOf<GroupEvent>()
        backgroundScope.launch { realtime.deletions("g").collect { events += it } }
        runCurrent()
        // Never becomes live (e.g. not a member of the private topic).
        advanceTimeBy(10_001)
        runCurrent()
        assertEquals(GroupEvent.Unavailable("g", GroupEvent.Stream.Deletions), events.last())
        assertTrue(channels.opened.first().closed)
        advanceTimeBy(1_001); runCurrent()
        assertEquals(2, channels.opened.size)
        advanceTimeBy(10_001 + 2_001); runCurrent()
        assertEquals(3, channels.opened.size)
        // A hanging open (socket never connects) is bounded by the subscribe timeout too.
        channels.hang = true
        advanceTimeBy(10_001 + 4_001 + 10_001 + 8_001); runCurrent()
        channels.hang = false
        channels.refuse = true
        advanceTimeBy(8_001); runCurrent()
        channels.refuse = false
        advanceTimeBy(8_001); runCurrent()
        val reopened = channels.opened.size
        assertTrue("reopened $reopened", reopened >= 4)
        assertEquals(GroupEvent.Stream.entries.size, 2)
    }

    @Test fun channelsCloseAfterTheLastCollectorLeavesAndListenersSeeEveryEvent() = runTest {
        val channels = FakeChannels()
        val realtime = GroupRealtime(channels, backgroundScope, policy)
        val seen = mutableListOf<GroupEvent>()
        realtime.addListener { seen += it }
        val job = backgroundScope.launch { realtime.events("g").collect { } }
        runCurrent()
        channels.opened.forEach { it.state.value = true }
        runCurrent()
        channels.current(GroupEvent.Stream.Deletions).sink(GroupEvent.MessageDeleted("g", "m"))
        runCurrent()
        assertTrue(seen.contains(GroupEvent.MessageDeleted("g", "m")))
        job.cancel()
        advanceTimeBy(4_000); runCurrent()
        assertTrue(channels.opened.none { it.closed })
        advanceTimeBy(1_500); runCurrent()
        assertTrue(channels.opened.all { it.closed })
    }

    @Test fun backoffDoublesUpToTheCap() {
        assertEquals(listOf(1, 2, 4, 8, 8, 8), (1..6).map { policy.backoff(it).inWholeSeconds.toInt() })
    }
}
