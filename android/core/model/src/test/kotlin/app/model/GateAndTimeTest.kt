package app.model

import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.toList
import kotlinx.coroutines.test.currentTime
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.Duration
import java.time.Instant
import java.time.LocalTime
import java.time.ZoneId
import java.time.ZonedDateTime
import java.util.concurrent.CountDownLatch
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicInteger

class SessionPromptGateTest {
    @Test fun claimsAtMostOncePerSession() {
        val gate = SessionPromptGate()
        assertTrue(gate.canPrompt)
        assertTrue(gate.tryClaim())
        assertFalse(gate.tryClaim())
        assertTrue(gate.hasPrompted)
        assertFalse(gate.canPrompt)
    }

    @Test fun neverDuringCaptureOrOnboarding() {
        val gate = SessionPromptGate()
        gate.during(SessionPromptGate.Blocker.Capture) {
            assertTrue(gate.isBlocked)
            assertFalse(gate.tryClaim())
        }
        gate.enter(SessionPromptGate.Blocker.Onboarding)
        gate.enter(SessionPromptGate.Blocker.Onboarding)
        gate.exit(SessionPromptGate.Blocker.Onboarding)
        assertFalse("nested enter keeps it blocked", gate.tryClaim())
        gate.exit(SessionPromptGate.Blocker.Onboarding)
        assertFalse(gate.hasPrompted)
        assertTrue(gate.tryClaim())
    }

    @Test fun unbalancedExitDoesNotUnderflow() {
        val gate = SessionPromptGate()
        gate.exit(SessionPromptGate.Blocker.Capture)
        gate.enter(SessionPromptGate.Blocker.Capture)
        assertTrue(gate.isBlocked)
    }

    @Test fun concurrentClaimsYieldExactlyOneWinner() {
        val gate = SessionPromptGate()
        val wins = AtomicInteger()
        val pool = Executors.newFixedThreadPool(8)
        val start = CountDownLatch(1)
        repeat(64) { pool.execute { start.await(); if (gate.tryClaim()) wins.incrementAndGet() } }
        start.countDown()
        pool.shutdown()
        pool.awaitTermination(10, TimeUnit.SECONDS)
        assertEquals(1, wins.get())
    }
}

class QuietHoursTest {
    private val zone = ZoneId.of("Europe/Berlin")
    private fun at(h: Int, m: Int = 0) = LocalTime.of(h, m)

    @Test fun sameDayWindow() {
        val q = QuietHours(at(13), at(15))
        assertTrue(at(13) in q)
        assertTrue(at(14, 59) in q)
        assertFalse(at(15) in q)
        assertFalse(at(12, 59) in q)
    }

    @Test fun windowWrappingMidnight() {
        val q = QuietHours(at(22), at(7))
        assertTrue(at(23) in q)
        assertTrue(at(0) in q)
        assertTrue(at(6, 59) in q)
        assertFalse(at(7) in q)
        assertFalse(at(21, 59) in q)
    }

    @Test fun equalBoundsMeansNoQuietHours() {
        val q = QuietHours(at(9), at(9))
        assertTrue(q.isEmpty)
        assertFalse(at(9) in q)
    }

    @Test fun usesThePersonsTimeZone() {
        val q = QuietHours(at(22), at(7))
        val instant = ZonedDateTime.of(2026, 3, 1, 23, 30, 0, 0, zone).toInstant()
        assertTrue(q.isQuietAt(instant, zone))
        assertFalse(q.isQuietAt(instant, ZoneId.of("America/New_York")))
    }

    @Test fun endOfQuiet() {
        val q = QuietHours(at(22), at(7))
        val evening = ZonedDateTime.of(2026, 3, 1, 23, 0, 0, 0, zone).toInstant()
        assertEquals(ZonedDateTime.of(2026, 3, 2, 7, 0, 0, 0, zone).toInstant(), q.endOfQuiet(evening, zone))
        val morning = ZonedDateTime.of(2026, 3, 2, 5, 0, 0, 0, zone).toInstant()
        assertEquals(ZonedDateTime.of(2026, 3, 2, 7, 0, 0, 0, zone).toInstant(), q.endOfQuiet(morning, zone))
        val noon = ZonedDateTime.of(2026, 3, 2, 12, 0, 0, 0, zone).toInstant()
        assertNull(q.endOfQuiet(noon, zone))
    }
}

@OptIn(ExperimentalCoroutinesApi::class)
class CountdownStateTest {
    private val closesAt = Instant.parse("2026-10-15T12:02:00Z")

    @Test fun remainingFromServerClosesAt() {
        val s = CountdownState.at(closesAt, Instant.parse("2026-10-15T12:00:00.250Z"))
        assertTrue(s is CountdownState.Open)
        s as CountdownState.Open
        assertEquals(Duration.ofMillis(119_750), s.remaining)
        assertEquals(120, s.remainingSeconds)
    }

    @Test fun closedAtAndAfterClosesAt() {
        assertEquals(CountdownState.Closed(closesAt), CountdownState.at(closesAt, closesAt))
        assertEquals(CountdownState.Closed(closesAt), CountdownState.at(closesAt, closesAt.plusSeconds(5)))
    }

    @Test fun serverClockCorrectsDeviceSkew() {
        val deviceNow = Instant.parse("2026-10-15T12:00:30Z") // device runs 30 s fast
        val clock = ServerClock.fromServerTime(Instant.parse("2026-10-15T12:00:00Z"), deviceNow) { deviceNow }
        assertEquals(Instant.parse("2026-10-15T12:00:00Z"), clock.now())
        val s = CountdownState.at(closesAt, clock.now()) as CountdownState.Open
        assertEquals(120, s.remainingSeconds)
    }

    @Test fun ticksOncePerDisplayedSecondThenCloses() = runTest {
        val start = closesAt.minusMillis(2_500)
        val states = CountdownState.ticks(closesAt) { start.plusMillis(currentTime) }.toList()
        val seconds = states.map { (it as? CountdownState.Open)?.remainingSeconds }
        assertEquals(listOf(3L, 2L, 1L, null), seconds)
        assertTrue(states.last() is CountdownState.Closed)
        assertEquals(2_500, currentTime)
    }
}
