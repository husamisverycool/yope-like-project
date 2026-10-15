package app.model

import java.time.Instant
import java.time.LocalDate
import java.time.LocalTime
import java.time.ZoneId
import java.time.ZonedDateTime

/**
 * A daily quiet window in the person's own time zone, `[start, end)`. A window whose end is
 * before its start wraps past midnight (e.g. 22:00–07:00). `start == end` means no quiet hours.
 *
 * During quiet hours alerts arrive silently; nothing is dropped (tenet "Nothing gets lost").
 */
data class QuietHours(val start: LocalTime, val end: LocalTime) {

    val isEmpty: Boolean get() = start == end

    operator fun contains(time: LocalTime): Boolean = when {
        isEmpty -> false
        start < end -> time >= start && time < end
        else -> time >= start || time < end
    }

    fun isQuietAt(instant: Instant, zone: ZoneId): Boolean =
        instant.atZone(zone).toLocalTime() in this

    /** When the quiet window containing [instant] ends; null when [instant] is not quiet. */
    fun endOfQuiet(instant: Instant, zone: ZoneId): Instant? {
        if (!isQuietAt(instant, zone)) return null
        val local = instant.atZone(zone)
        val date: LocalDate = if (start < end || local.toLocalTime() < end) local.toLocalDate() else local.toLocalDate().plusDays(1)
        // atZone resolves a gap (DST spring-forward) by moving later, which is the right side.
        return ZonedDateTime.of(date, end, zone).toInstant()
    }
}
