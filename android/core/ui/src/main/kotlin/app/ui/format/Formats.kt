package app.ui.format

import android.icu.text.DateIntervalFormat
import android.icu.text.MeasureFormat
import android.icu.util.DateInterval
import android.icu.util.Measure
import android.icu.util.MeasureUnit
import android.icu.util.ULocale
import java.time.Duration
import java.time.Instant
import java.time.LocalDate
import java.time.LocalTime
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.time.format.FormatStyle
import java.util.Locale

/**
 * Dates and times in Retro's voice (`retro.voice.formats`, design/copy-patterns.md): everything by the
 * **locale formatter** — ranges with the month once inside a month ("Jul 3 – 9"), dated headers ("January 25,
 * 2024"), the Rewind date ("May 1, 2019"), terse relative times ("2h", "1d"). PLATFORM formatters (java.time,
 * ICU), so every locale gets its own order and punctuation.
 */
object Formats {
    /** A clock time in the locale's short style ("9:41 AM"). */
    fun time(instant: Instant, zone: ZoneId = ZoneId.systemDefault(), locale: Locale = Locale.getDefault()): String =
        DateTimeFormatter.ofLocalizedTime(FormatStyle.SHORT).withLocale(locale).format(instant.atZone(zone))

    fun time(time: LocalTime, locale: Locale = Locale.getDefault()): String =
        DateTimeFormatter.ofLocalizedTime(FormatStyle.SHORT).withLocale(locale).format(time)

    /** A date in the locale's medium style ("May 1, 2019" — the Rewind date title). */
    fun date(instant: Instant, zone: ZoneId = ZoneId.systemDefault(), locale: Locale = Locale.getDefault()): String =
        DateTimeFormatter.ofLocalizedDate(FormatStyle.MEDIUM).withLocale(locale).format(instant.atZone(zone))

    /** A date in the locale's long style ("January 25, 2024" — dated album headers). */
    fun longDate(date: LocalDate, locale: Locale = Locale.getDefault()): String =
        DateTimeFormatter.ofLocalizedDate(FormatStyle.LONG).withLocale(locale).format(date)

    /** A week's date range, the month written once inside a month ("Jul 3 – 9", "Apr 29 – May 5"). */
    fun weekRange(start: LocalDate, end: LocalDate, zone: ZoneId = ZoneId.systemDefault(), locale: Locale = Locale.getDefault()): String {
        val from = start.atStartOfDay(zone).toInstant().toEpochMilli()
        val to = end.atStartOfDay(zone).toInstant().toEpochMilli()
        val format = DateIntervalFormat.getInstance(MONTH_DAY_SKELETON, ULocale.forLocale(locale))
        format.timeZone = android.icu.util.TimeZone.getTimeZone(zone.id)
        return format.format(DateInterval(from, to))
    }

    /** Time since [from], terse and largest-unit ("2h", "1d", "3w" in English) — comment and activity timestamps. */
    fun elapsed(from: Instant, now: Instant = Instant.now(), locale: Locale = Locale.getDefault()): String {
        val d = Duration.between(from, now).coerceAtLeast(Duration.ZERO)
        val measure = when {
            d.toDays() >= DAYS_PER_WEEK -> Measure(d.toDays() / DAYS_PER_WEEK, MeasureUnit.WEEK)
            d.toDays() >= 1 -> Measure(d.toDays(), MeasureUnit.DAY)
            d.toHours() >= 1 -> Measure(d.toHours(), MeasureUnit.HOUR)
            else -> Measure(d.toMinutes().coerceAtLeast(1), MeasureUnit.MINUTE)
        }
        return MeasureFormat.getInstance(ULocale.forLocale(locale), MeasureFormat.FormatWidth.NARROW).format(measure)
    }

    /** ICU skeleton: abbreviated month + day. */
    private const val MONTH_DAY_SKELETON = "MMMd"
    private const val DAYS_PER_WEEK = 7L
}
