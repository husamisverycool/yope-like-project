package app.feature.social.common

import android.content.Context
import android.icu.text.MeasureFormat
import android.icu.util.Measure
import android.icu.util.MeasureUnit
import android.text.format.DateUtils
import app.designsystem.generated.Tokens
import java.time.DayOfWeek
import java.time.Instant
import java.time.LocalDate
import java.time.LocalTime
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.time.format.TextStyle
import java.time.temporal.IsoFields
import java.time.temporal.TemporalAdjusters
import java.util.Locale

/** Formats named by tokens (patterns are the tokens' own values). */
object Formats {
    private fun locale(): Locale = Locale.getDefault()

    /** `chat.thread.layout.timeFormat` ("10:00 PM") in the device zone. */
    fun overlayTime(at: Instant, zone: ZoneId = ZoneId.systemDefault()): String =
        DateTimeFormatter.ofPattern(Tokens.Layouts.ChatThreadLayoutTimeFormat.pattern, locale()).format(at.atZone(zone))

    /** `chat.voice.layout.durationFormat` ("00:38"). */
    fun voiceDuration(durationMs: Int): String {
        val seconds = (durationMs.coerceAtLeast(0) / MS_PER_SECOND).toLong()
        return DateTimeFormatter.ofPattern(Tokens.Layouts.ChatVoiceLayoutDurationFormat.pattern, locale()).format(LocalTime.ofSecondOfDay(seconds.coerceAtMost(LAST_SECOND_OF_DAY)))
    }

    /** A duration spoken as minutes and seconds (`chat.voice.a11y.*` `{duration}`), by the platform's measure format. */
    fun spokenDuration(durationMs: Int): String {
        val total = durationMs.coerceAtLeast(0) / MS_PER_SECOND
        val minutes = total / SECONDS_PER_MINUTE
        val seconds = total % SECONDS_PER_MINUTE
        val format = MeasureFormat.getInstance(locale(), MeasureFormat.FormatWidth.WIDE)
        return if (minutes > 0) format.formatMeasures(Measure(minutes, MeasureUnit.MINUTE), Measure(seconds, MeasureUnit.SECOND))
        else format.formatMeasures(Measure(seconds, MeasureUnit.SECOND))
    }

    /** `photo.viewer.layout.dateFormat` ("Oct 30 2025"). */
    fun viewerDate(at: Instant, zone: ZoneId = ZoneId.systemDefault()): String =
        DateTimeFormatter.ofPattern(Tokens.Layouts.PhotoViewerLayoutDateFormat.pattern, locale()).format(at.atZone(zone))

    /**
     * `week.recap.layout.weekFormat` title form: "d MMM-d MMM", lowercase, bare hyphen
     * ("18 aug-24 aug"); [label] = the uppercase form ("18 AUG-24 AUG").
     */
    fun recapWeek(weekStart: LocalDate, label: Boolean = false): String {
        val day = DateTimeFormatter.ofPattern(RECAP_DAY, locale())
        val text = day.format(weekStart) + WEEK_SEPARATOR + day.format(weekStart.plusDays(DAYS_IN_WEEK - 1))
        return if (label) text.uppercase(locale()) else text.lowercase(locale())
    }

    /** ISO-8601 week number of [weekStart] (`week.history.layout.weeks`). */
    fun isoWeek(weekStart: LocalDate): Int = weekStart.get(IsoFields.WEEK_OF_WEEK_BASED_YEAR)

    /** The locale's Monday–Sunday interval ("Apr 29 – May 5", "10–16 Aug"; `week.history` header range). */
    fun weekRange(context: Context, weekStart: LocalDate, zone: ZoneId): String {
        val start = weekStart.atStartOfDay(zone).toInstant().toEpochMilli()
        // DateUtils treats an end at midnight as exclusive: the day after Sunday shows Monday–Sunday.
        val end = weekStart.plusDays(DAYS_IN_WEEK).atStartOfDay(zone).toInstant().toEpochMilli()
        return DateUtils.formatDateRange(context, java.util.Formatter(StringBuilder(), locale()), start, end, DateUtils.FORMAT_SHOW_DATE or DateUtils.FORMAT_ABBREV_MONTH or DateUtils.FORMAT_NO_YEAR, zone.id).toString()
    }

    /** "Mon" (`week.history` weekday on a tile, `EEE`). */
    fun weekdayShort(date: LocalDate): String = date.dayOfWeek.getDisplayName(TextStyle.SHORT, locale())

    /** Full weekday and date for accessibility labels. */
    fun weekdayLong(date: LocalDate): String = date.dayOfWeek.getDisplayName(TextStyle.FULL, locale())

    fun spokenDate(date: LocalDate): String = DateTimeFormatter.ofLocalizedDate(java.time.format.FormatStyle.LONG).withLocale(locale()).format(date)

    /** The Monday starting the week of [date] (`week_start_isodow` = 1). */
    fun weekStartOf(date: LocalDate): LocalDate = date.with(TemporalAdjusters.previousOrSame(DayOfWeek.MONDAY))

    private const val MS_PER_SECOND = 1000
    private const val SECONDS_PER_MINUTE = 60
    private const val LAST_SECOND_OF_DAY = 86_399L
    const val DAYS_IN_WEEK = 7L
    private const val RECAP_DAY = "d MMM"
    private const val WEEK_SEPARATOR = "-"
}

/** Emoji system names (Unicode character names, lowercased), for labels and picker search. */
object EmojiNames {
    private const val ZWJ = 0x200D
    private const val VS16 = 0xFE0F
    private val SKIN_TONES = 0x1F3FB..0x1F3FF

    fun name(emoji: String): String {
        val parts = emoji.codePoints().toArray()
            .filter { it != ZWJ && it != VS16 && it !in SKIN_TONES }
            .mapNotNull { cp -> Character.getName(cp)?.lowercase(Locale.ROOT) }
        return parts.joinToString(" ").ifEmpty { emoji }
    }
}
