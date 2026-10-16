package app.feature.memory.common

import android.text.format.DateFormat
import app.designsystem.generated.Tokens
import java.text.NumberFormat
import java.time.LocalDate
import java.time.format.DateTimeFormatter
import java.time.format.FormatStyle
import java.util.Locale

/**
 * Date and number formats of the memory surfaces (MERGE RM-14): Rewind 'Jul 22, 2022' (medium date), within the
 * year 'Wednesday, July 5', birthdays 'July 5', months 'December'. Each comes from its `layout.*Format` token and
 * is localised by the platform (`DateFormat.getBestDateTimePattern` with the token's skeleton).
 */
object MemoryFormats {
    /** `layout.onthisday.dateFormat`: the locale's medium date ("Jul 22, 2022"). */
    fun memoryDate(date: LocalDate, locale: Locale = Locale.getDefault()): String =
        DateTimeFormatter.ofLocalizedDate(FormatStyle.MEDIUM).withLocale(locale).format(date)

    /** `layout.birthday.add.dateFormat` ("July 5"): day and month only, never the year. */
    fun dayMonth(date: LocalDate, locale: Locale = Locale.getDefault()): String =
        skeleton(Tokens.Layouts.BirthdayAddDateFormat.pattern, date, locale)

    /** `layout.birthday.request.dueDate`: the day before the birthday ("Wednesday, July 5"; no year, never a countdown). */
    fun dueDate(birthday: LocalDate, locale: Locale = Locale.getDefault()): String =
        skeleton(Tokens.Layouts.BirthdayRequestDueDate.pattern, birthday.minusDays(1), locale)

    /** `layout.year.story.dateFormat` ("Wednesday, July 5"). */
    fun storyDate(date: LocalDate, locale: Locale = Locale.getDefault()): String =
        skeleton(Tokens.Layouts.YearStoryDateFormat.pattern, date, locale)

    /** `layout.year.story.monthFormat` ("December"), the stand-alone month name. */
    fun storyMonth(month: Int, locale: Locale = Locale.getDefault()): String =
        java.time.Month.of(month).getDisplayName(java.time.format.TextStyle.FULL_STANDALONE, locale)

    /** A group-level number (`year.story.moments.count` `{count}`), grouped per locale. */
    fun number(value: Int, locale: Locale = Locale.getDefault()): String = NumberFormat.getIntegerInstance(locale).format(value)

    /** A position ("2" of "5") in the locale's digits. */
    fun position(value: Int, locale: Locale = Locale.getDefault()): String = number(value, locale)

    /** Spoken date for photo labels (`birthday.contribute.a11y.photo`, `year.story.a11y.collage`). */
    fun spokenDate(date: LocalDate, locale: Locale = Locale.getDefault()): String =
        DateTimeFormatter.ofLocalizedDate(FormatStyle.LONG).withLocale(locale).format(date)

    /** A token's pattern ("EEEE, MMMM d") as a skeleton for the locale's best pattern (Android `getBestDateTimePattern`). */
    private fun skeleton(pattern: String, date: LocalDate, locale: Locale): String {
        val best = DateFormat.getBestDateTimePattern(locale, pattern.filter(Char::isLetter))
        return DateTimeFormatter.ofPattern(best, locale).format(date)
    }
}

/** width / height of the original image; 1 when the client did not record the size. */
fun app.data.model.Media.aspectRatio(): Float {
    val w = width ?: return 1f
    val h = height ?: return 1f
    return if (w > 0 && h > 0) w.toFloat() / h else 1f
}
