package app.model

import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flow
import java.time.Duration
import java.time.Instant

/**
 * Time left in a daily invitation window, computed from the server's `closesAt`. The server is
 * the authority on the window; the device only counts down to it.
 */
sealed interface CountdownState {
    /** The window is open; [remaining] is always positive. */
    data class Open(val closesAt: Instant, val remaining: Duration) : CountdownState {
        /** Whole seconds left, rounded up, so the display never shows 0 while still open. */
        val remainingSeconds: Long
            get() = (remaining.toMillis() + MILLIS_PER_SECOND - 1) / MILLIS_PER_SECOND
    }

    /** The window has closed. Answering later still posts normally (tenet 5: no "late" label). */
    data class Closed(val closesAt: Instant) : CountdownState

    companion object {
        private const val MILLIS_PER_SECOND = 1000L

        fun at(closesAt: Instant, now: Instant): CountdownState {
            val remaining = Duration.between(now, closesAt)
            return if (remaining.isNegative || remaining.isZero) Closed(closesAt) else Open(closesAt, remaining)
        }

        /**
         * Emits the state now and again each time the whole-second value changes, then
         * [Closed] once, and completes.
         *
         * @param now the current time on the server's clock (see [ServerClock]).
         */
        fun ticks(closesAt: Instant, now: () -> Instant): Flow<CountdownState> = flow {
            while (true) {
                val state = at(closesAt, now())
                emit(state)
                if (state !is Open) return@flow
                // Sleep until the displayed whole-second value changes.
                val toNextSecond = state.remaining.toMillis() % MILLIS_PER_SECOND
                delay(if (toNextSecond == 0L) MILLIS_PER_SECOND else toNextSecond)
            }
        }
    }
}

/**
 * The server's clock as seen from this device: `device time + offset`. The offset comes from a
 * server timestamp (e.g. a push's `sent_at` or an API response `Date`), so a device whose clock is
 * wrong still counts down to the same moment as everyone else.
 */
class ServerClock(val offset: Duration = Duration.ZERO, private val deviceNow: () -> Instant = Instant::now) {
    fun now(): Instant = deviceNow().plus(offset)

    companion object {
        fun fromServerTime(serverNow: Instant, deviceNow: Instant, device: () -> Instant = Instant::now): ServerClock =
            ServerClock(Duration.between(deviceNow, serverNow), device)
    }
}
