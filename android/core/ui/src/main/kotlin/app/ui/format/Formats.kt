package app.ui.format

import android.icu.text.DateIntervalFormat
import android.icu.text.DisplayContext
import android.icu.text.MeasureFormat
import android.icu.text.RelativeDateTimeFormatter
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
import java.time.temporal.ChronoUnit
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

    /**
     * A day and a clock time inside a sentence ("…develop for these groups tomorrow, 9:00 AM."): the platform's relative
     * day with middle-of-sentence capitalization (ICU `RelativeDateTimeFormatter`, style long,
     * `DisplayContext.CAPITALIZATION_FOR_MIDDLE_OF_SENTENCE`) — today / tomorrow / yesterday, "in N days" / "N days ago"
     * within a week (the span `DateUtils.getRelativeDateTimeString` words), else the locale's medium date — joined to
     * [time] (the caller's platform-formatted clock time) by ICU's own `combineDateAndTime`. PLATFORM: nothing typed here.
     */
    fun dayAndTimeInSentence(
        at: Instant,
        time: String,
        zone: ZoneId = ZoneId.systemDefault(),
        now: Instant = Instant.now(),
        locale: Locale = Locale.getDefault(),
    ): String {
        val formatter = RelativeDateTimeFormatter.getInstance(
            ULocale.forLocale(locale),
            null,
            RelativeDateTimeFormatter.Style.LONG,
            DisplayContext.CAPITALIZATION_FOR_MIDDLE_OF_SENTENCE,
        )
        val days = ChronoUnit.DAYS.between(now.atZone(zone).toLocalDate(), at.atZone(zone).toLocalDate())
        val day = when {
            days == 0L -> formatter.format(RelativeDateTimeFormatter.Direction.THIS, RelativeDateTimeFormatter.AbsoluteUnit.DAY)
            days == 1L -> formatter.format(RelativeDateTimeFormatter.Direction.NEXT, RelativeDateTimeFormatter.AbsoluteUnit.DAY)
            days == -1L -> formatter.format(RelativeDateTimeFormatter.Direction.LAST, RelativeDateTimeFormatter.AbsoluteUnit.DAY)
            days in 2 until DAYS_PER_WEEK -> formatter.format(days.toDouble(), RelativeDateTimeFormatter.Direction.NEXT, RelativeDateTimeFormatter.RelativeUnit.DAYS)
            days in -DAYS_PER_WEEK + 1..-2 -> formatter.format((-days).toDouble(), RelativeDateTimeFormatter.Direction.LAST, RelativeDateTimeFormatter.RelativeUnit.DAYS)
            else -> date(at, zone, locale)
        }
        return formatter.combineDateAndTime(day, time)
    }

    /** ICU skeleton: abbreviated month + day. */
    private const val MONTH_DAY_SKELETON = "MMMd"
    private const val DAYS_PER_WEEK = 7L
}
