package app.feature.memory.birthday

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicText
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.OffsetMapping
import androidx.compose.ui.text.input.TransformedText
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.text.style.TextAlign
import app.designsystem.R
import app.designsystem.generated.Tokens
import app.feature.memory.common.roleStyle
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

    /** "MM/dd/yyyy" for the placeholder (`auth.agegate.field.placeholder` `{date_format}`). */
    val display: String get() = fields.joinToString(separator.toString()) { f -> f.toString().repeat(width(f)) }

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

    /** Maps cursor offsets between the typed digits and the formatted text. */
    internal fun transformation(): VisualTransformation = VisualTransformation { text ->
        val formatted = format(text.text)
        val boundaries = fields.runningFold(0) { acc, f -> acc + width(f) }.drop(1).dropLast(1)
        val mapping = object : OffsetMapping {
            override fun originalToTransformed(offset: Int): Int = offset + boundaries.count { it < offset }
            override fun transformedToOriginal(offset: Int): Int {
                var digits = 0
                var seen = 0
                for (c in formatted) {
                    if (seen >= offset) break
                    if (c != separator) digits++
                    seen++
                }
                return digits.coerceAtMost(text.length)
            }
        }
        TransformedText(AnnotatedString(formatted), mapping)
    }

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
 * The `auth.agegate` birthday field (owned by the auth pass, rebuilt here from its tokens because
 * core:ui has no shared field): Yope form field, numeric keyboard, separators inserted in the
 * locale's order, empty by default, no default year.
 */
@Composable
fun BirthdayDateField(
    digits: String,
    onDigitsChange: (String) -> Unit,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
    pattern: DateEntryPattern = remember { DateEntryPattern.forLocale() },
) {
    val textStyle = roleStyle(Tokens.FontSizes.groupsCreateFontSizeFieldText, Tokens.FontWeights.groupsCreateFontWeightFieldText)
        .copy(color = Tokens.Colors.globalTextPrimary, textAlign = TextAlign.Center)
    val label = stringResource(R.string.auth_agegate_field_accessibilitylabel)
    val transformation = remember(pattern) { pattern.transformation() }
    BasicTextField(
        value = digits,
        onValueChange = { new -> onDigitsChange(new.filter(Char::isDigit).take(pattern.length)) },
        modifier = modifier.semantics { contentDescription = label },
        enabled = enabled,
        textStyle = textStyle,
        singleLine = true,
        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number, imeAction = ImeAction.Done),
        visualTransformation = transformation,
        // The platform text cursor in the dark scheme's primary role.
        cursorBrush = SolidColor(Tokens.Colors.globalSystemPrimary),
        decorationBox = { inner ->
            Box(
                Modifier
                    .fillMaxWidth()
                    .heightIn(min = Tokens.Sizes.globalFieldHeight)
                    .clip(RoundedCornerShape(Tokens.Radii.globalField))
                    .background(Tokens.Colors.groupsCreateColorField)
                    .padding(horizontal = Tokens.Sizes.globalScreenMargin),
                contentAlignment = Alignment.Center,
            ) {
                if (digits.isEmpty()) {
                    BasicText(
                        stringResource(R.string.auth_agegate_field_placeholder, pattern.display),
                        style = textStyle.copy(color = Tokens.Colors.globalTextSecondary),
                    )
                }
                inner()
            }
        },
    )
}
