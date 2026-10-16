package app.feature.memory.birthday

import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.TextRange
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.TextFieldValue
import app.designsystem.R
import app.ui.components.FormTextField
import java.time.LocalDate
import java.time.chrono.IsoChronology
import java.time.format.DateTimeFormatterBuilder
import java.time.format.FormatStyle
import java.util.Locale

/**
 * The locale's numeric date order for free entry (`auth.agegate.layout.dateEntry` format: the
 * locale's short-date pattern order, four-digit year). [fields] is e.g. `[M, d, y]`.
 */
data class DateEntryPattern(val fields: List<Char>, val separator: Char) {
    /** Digits a complete entry has (two for day and month, four for the year). */
    val length: Int get() = fields.sumOf(::width)

    /** "MM/DD/YYYY" for the placeholder (`auth.agegate.field.placeholder` `{date_format}`, as the copy's note shows it). */
    val display: String get() = fields.joinToString(separator.toString()) { f -> f.uppercaseChar().toString().repeat(width(f)) }

    /** [digits] with separators inserted in the locale's order as the person types. */
    fun format(digits: String): String = buildString {
        var i = 0
        for ((n, field) in fields.withIndex()) {
            val w = width(field)
            if (i >= digits.length) break
            if (n > 0) append(separator)
            append(digits, i, minOf(digits.length, i + w))
            i += w
        }
    }

    /** The date of a complete entry, or null (incomplete or not a real date). */
    fun parse(digits: String): LocalDate? {
        if (digits.length != length || !digits.all(Char::isDigit)) return null
        var i = 0
        var day = 0
        var month = 0
        var year = 0
        for (field in fields) {
            val w = width(field)
            val v = digits.substring(i, i + w).toInt()
            when (field) {
                'd' -> day = v
                'M' -> month = v
                'y' -> year = v
            }
            i += w
        }
        return runCatching { LocalDate.of(year, month, day) }.getOrNull()
    }

    private fun width(field: Char): Int = if (field == 'y') YEAR_DIGITS else 2

    companion object {
        private const val YEAR_DIGITS = 4

        /** From the locale's SHORT date pattern (field order and its first separator). */
        fun forLocale(locale: Locale = Locale.getDefault()): DateEntryPattern {
            val pattern = DateTimeFormatterBuilder.getLocalizedDateTimePattern(FormatStyle.SHORT, null, IsoChronology.INSTANCE, locale)
            val fields = pattern.filter { it == 'd' || it == 'M' || it == 'y' }.toList().distinct()
            val separator = pattern.firstOrNull { !it.isLetter() && it != '\'' && !it.isWhitespace() } ?: '/'
            return if (fields.size == 3) DateEntryPattern(fields, separator) else DateEntryPattern(listOf('M', 'd', 'y'), separator)
        }
    }
}

/**
 * The `auth.agegate` birthday field (owned by the auth pass, design/surfaces/auth.agegate.md; drawn with the same
 * component and copy): C-12 `FormTextField` (fill `color.global.control`, `size.global.fieldHeight`,
 * `radius.global.field`, text role `placeholder`), numeric keyboard, separators inserted in the locale's order
 * (`auth.agegate.layout.dateEntry`), the locale's format as the placeholder (`auth.agegate.field.placeholder`), empty
 * by default, no default year. [error]: the C-12 inline error under the field.
 */
@Composable
fun BirthdayDateField(
    digits: String,
    onDigitsChange: (String) -> Unit,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
    error: String? = null,
    pattern: DateEntryPattern = remember { DateEntryPattern.forLocale() },
) {
    val formatted = pattern.format(digits)
    FormTextField(
        value = TextFieldValue(formatted, TextRange(formatted.length)),
        onValueChange = { new -> onDigitsChange(new.text.filter(Char::isDigit).take(pattern.length)) },
        placeholder = stringResource(R.string.auth_agegate_field_placeholder, pattern.display),
        accessibilityLabel = stringResource(R.string.auth_agegate_field_accessibilitylabel),
        modifier = modifier,
        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number, imeAction = ImeAction.Done),
        enabled = enabled,
        error = error,
    )
}
