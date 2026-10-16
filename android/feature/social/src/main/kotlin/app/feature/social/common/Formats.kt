package app.feature.social.common

import android.content.Context
import android.icu.text.ListFormatter
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
import java.time.format.FormatStyle
import java.time.format.TextStyle
import java.time.temporal.IsoFields
import java.time.temporal.TemporalAdjusters
import java.util.Locale

/** Formats named by the social tokens (patterns are the tokens' own values or the locale's, as the tokens say). */
object Formats {
    private fun locale(): Locale = Locale.getDefault()

    /** `chat.thread.layout.timeFormat`: the locale's short time ("10:00 PM" in en-US). */
    fun shortTime(at: Instant, zone: ZoneId = ZoneId.systemDefault()): String =
        DateTimeFormatter.ofLocalizedTime(FormatStyle.SHORT).withLocale(locale()).format(at.atZone(zone))

    /** `chat.voice.layout.durationFormat` ("0:38", pattern `m:ss`). */
    fun voiceDuration(durationMs: Long): String {
        val seconds = (durationMs.coerceAtLeast(0) / MS_PER_SECOND).coerceAtMost(LAST_SECOND_OF_HOUR)
        return DateTimeFormatter.ofPattern(Tokens.Layouts.ChatVoiceLayoutDurationFormat.pattern, locale()).format(LocalTime.ofSecondOfDay(seconds))
    }

    /** A duration spoken as minutes and seconds (`chat.voice.a11y.*` `{duration}`), by the platform's measure format. */
    fun spokenDuration(durationMs: Long): String {
        val total = durationMs.coerceAtLeast(0) / MS_PER_SECOND
        val minutes = total / SECONDS_PER_MINUTE
        val seconds = total % SECONDS_PER_MINUTE
        val format = MeasureFormat.getInstance(locale(), MeasureFormat.FormatWidth.WIDE)
        return if (minutes > 0) format.formatMeasures(Measure(minutes, MeasureUnit.MINUTE), Measure(seconds, MeasureUnit.SECOND))
        else format.formatMeasures(Measure(seconds, MeasureUnit.SECOND))
    }

    /** `photo.viewer.layout.dateFormat`: "Wednesday, July 5"; a photo from another year carries it ("…, 2025"). */
    fun viewerDate(at: Instant, zone: ZoneId = ZoneId.systemDefault(), today: LocalDate = LocalDate.now(zone)): String {
        val date = at.atZone(zone).toLocalDate()
        val f = Tokens.Layouts.PhotoViewerLayoutDateFormat
        return DateTimeFormatter.ofPattern(if (date.year == today.year) f.pattern else f.otherYear, locale()).format(date)
    }

    /**
     * `chat.thread.layout.timeFormat` → dayDividers: "Today" / "Yesterday" ([today] / [yesterday], copy) or the
     * date as "MMMM d, yyyy" (the locale's long date: "October 16, 2026" in en-US).
     */
    fun dayDivider(date: LocalDate, now: LocalDate, today: String, yesterday: String): String = when (date) {
        now -> today
        now.minusDays(1) -> yesterday
        else -> DateTimeFormatter.ofLocalizedDate(FormatStyle.LONG).withLocale(locale()).format(date)
    }

    /** ISO-8601 week number of [weekStart] (`week.history.layout.weeks`). */
    fun isoWeek(weekStart: LocalDate): Int = weekStart.get(IsoFields.WEEK_OF_WEEK_BASED_YEAR)

    /** The locale's Monday–Sunday interval ("Jul 3 – 9", "Apr 29 – May 5"; C-20 section header range). */
    fun weekRange(context: Context, weekStart: LocalDate, zone: ZoneId): String {
        val start = weekStart.atStartOfDay(zone).toInstant().toEpochMilli()
        // DateUtils treats an end at midnight as exclusive: the day after Sunday shows Monday–Sunday.
        val end = weekStart.plusDays(DAYS_IN_WEEK).atStartOfDay(zone).toInstant().toEpochMilli()
        return DateUtils.formatDateRange(context, java.util.Formatter(StringBuilder(), locale()), start, end, DateUtils.FORMAT_SHOW_DATE or DateUtils.FORMAT_ABBREV_MONTH or DateUtils.FORMAT_NO_YEAR, zone.id).toString()
    }

    /** The same interval spoken in full ("July 3 to 9" — the platform's reading of the range, accessibility labels). */
    fun spokenWeekRange(context: Context, weekStart: LocalDate, zone: ZoneId): String {
        val start = weekStart.atStartOfDay(zone).toInstant().toEpochMilli()
        val end = weekStart.plusDays(DAYS_IN_WEEK).atStartOfDay(zone).toInstant().toEpochMilli()
        return DateUtils.formatDateRange(context, java.util.Formatter(StringBuilder(), locale()), start, end, DateUtils.FORMAT_SHOW_DATE or DateUtils.FORMAT_NO_YEAR, zone.id).toString()
    }

    /** "Mon" (weekday label of a C-17 tile). */
    fun weekdayShort(date: LocalDate): String = date.dayOfWeek.getDisplayName(TextStyle.SHORT, locale())

    /** "Oct" (month line of a C-17 empty-day tile). */
    fun monthShort(date: LocalDate): String = date.month.getDisplayName(TextStyle.SHORT, locale())

    /** Full weekday for accessibility labels. */
    fun weekdayLong(date: LocalDate): String = date.dayOfWeek.getDisplayName(TextStyle.FULL, locale())

    /** The day number of an empty-day tile ("12"). */
    fun dayNumber(date: LocalDate): String = date.dayOfMonth.toString()

    fun spokenDate(date: LocalDate): String = DateTimeFormatter.ofLocalizedDate(FormatStyle.LONG).withLocale(locale()).format(date)

    /** The Monday starting the week of [date] (`week_start_isodow` = 1). */
    fun weekStartOf(date: LocalDate): LocalDate = date.with(TemporalAdjusters.previousOrSame(DayOfWeek.MONDAY))

    /** Names joined by the platform list formatter ("Ana, Ben and Sam" — `tagging.with` `{names}`). */
    fun nameList(names: List<String>): String = ListFormatter.getInstance(locale()).format(names)

    private const val MS_PER_SECOND = 1000L
    private const val SECONDS_PER_MINUTE = 60L
    private const val LAST_SECOND_OF_HOUR = 3_599L
    const val DAYS_IN_WEEK = 7L
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

    /** The emoji characters spelled out in a token's text ("🔥 then 💖, then …" → [🔥, 💖]). */
    fun inText(text: String): List<String> {
        val out = ArrayList<String>()
        val cps = text.codePoints().toArray()
        var i = 0
        while (i < cps.size) {
            val cp = cps[i]
            if (Character.getType(cp) == Character.OTHER_SYMBOL.toInt() && cp >= FIRST_PICTOGRAPH) {
                val sb = StringBuilder().appendCodePoint(cp)
                while (i + 1 < cps.size && (cps[i + 1] == VS16 || cps[i + 1] in SKIN_TONES)) sb.appendCodePoint(cps[++i])
                out += sb.toString()
            }
            i++
        }
        return out
    }

    /** Below this code point "other symbol" characters are arrows, dingbat punctuation and the like, not pictographs. */
    private const val FIRST_PICTOGRAPH = 0x1F000
}
