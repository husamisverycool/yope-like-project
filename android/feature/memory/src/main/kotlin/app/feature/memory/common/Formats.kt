package app.feature.memory.common

import android.content.res.Resources
import app.designsystem.generated.Tokens
import app.designsystem.R
import java.text.NumberFormat
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.time.format.FormatStyle
import java.time.format.TextStyle
import java.util.Locale

/**
 * Date and number formats of the memory surfaces, each from its own reference (MERGE memory M-28).
 * Patterns come from `layout.*Format` tokens; localised forms from the platform.
 */
object MemoryFormats {
    /** `onthisday.banner.yearsAgo.one` / `.other` ("1 YEAR AGO", "3 YEARS AGO"). */
    fun yearsAgo(resources: Resources, years: Int, locale: Locale = Locale.getDefault()): String =
        if (years == 1) resources.getString(R.string.onthisday_banner_yearsago_one)
        else resources.getString(R.string.onthisday_banner_yearsago_other, NumberFormat.getIntegerInstance(locale).format(years))

    /** `onthisday.memory.meta` weekday ("TUE"), uppercase as the reference, in the group time zone. */
    fun metaWeekday(at: Instant, zone: ZoneId, locale: Locale = Locale.getDefault()): String =
        at.atZone(zone).dayOfWeek.getDisplayName(TextStyle.SHORT, locale).uppercase(locale).trimEnd('.')

    /** Spoken weekday for `onthisday.a11y.photo` ("Tuesday"). */
    fun spokenWeekday(at: Instant, zone: ZoneId, locale: Locale = Locale.getDefault()): String =
        at.atZone(zone).dayOfWeek.getDisplayName(TextStyle.FULL, locale)

    /** `onthisday.memory.meta` time ("10:34 PM"), the locale's short time, uppercase as the reference. */
    fun metaTime(at: Instant, zone: ZoneId, locale: Locale = Locale.getDefault()): String =
        DateTimeFormatter.ofLocalizedTime(FormatStyle.SHORT).withLocale(locale).format(at.atZone(zone)).uppercase(locale)

    /** `layout.birthday.request.dueDate`: the day before the birthday, full date ("Wednesday, December 31, 2025"). */
    fun dueDate(birthday: LocalDate, locale: Locale = Locale.getDefault()): String =
        DateTimeFormatter.ofLocalizedDate(FormatStyle.FULL).withLocale(locale).format(birthday.minusDays(1))

    /** `layout.birthday.add.dateFormat` ("26 May"): day and month only, never the year. */
    fun dayMonth(date: LocalDate, locale: Locale = Locale.getDefault()): String =
        DateTimeFormatter.ofPattern(Tokens.Layouts.BirthdayAddDateFormat.pattern, locale).format(date)

    /** `layout.year.story.dateFormat` ("February 25"), localised with the locale's month-day template. */
    fun storyDate(date: LocalDate, locale: Locale = Locale.getDefault()): String {
        val skeleton = Tokens.Layouts.YearStoryDateFormat.pattern.filterNot(Char::isWhitespace)
        val pattern = android.text.format.DateFormat.getBestDateTimePattern(locale, skeleton)
        return DateTimeFormatter.ofPattern(pattern, locale).format(date)
    }

    /** `layout.year.story.monthFormat` ("January"). */
    fun storyMonth(month: Int, locale: Locale = Locale.getDefault()): String =
        DateTimeFormatter.ofPattern(Tokens.Layouts.YearStoryMonthFormat.pattern, locale).format(LocalDate.of(2000, month, 1))

    /** A group-level number (`year.story.moments.count` `{count}`), grouped per locale. */
    fun number(value: Int, locale: Locale = Locale.getDefault()): String = NumberFormat.getIntegerInstance(locale).format(value)

    /** Spoken date for photo labels (`birthday.contribute.a11y.photo`, `year.story.a11y.collage`). */
    fun spokenDate(date: LocalDate, locale: Locale = Locale.getDefault()): String =
        DateTimeFormatter.ofLocalizedDate(FormatStyle.LONG).withLocale(locale).format(date)
}

/** width / height of the original image; 1 when the client did not record the size. */
fun app.data.model.Media.aspectRatio(): Float {
    val w = width ?: return 1f
    val h = height ?: return 1f
    return if (w > 0 && h > 0) w.toFloat() / h else 1f
}
