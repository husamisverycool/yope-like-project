// Surface: week.history (the calendar) — design/surfaces/week.history.md "Calendar — jump to a date"
// (`week.history.layout.calendar`). Mechanics: BeReal's Memories calendar (https://help.bereal.com/hc/en-us/articles/7531349180829:
// past posts reached from a month grid, only the days with one open); drawn with Retro's components (C-29 sheet, C-11
// close circle, C-06 fill, text roles). Owner decision 34 (research #21). No count anywhere.
// Also onthisday's "Pick a date…" (design/surfaces/onthisday.md E): the same sheet, a day picks itself.
// It lives in feature:memory so both feature:social (which depends on this module) and onthisday use one calendar.
@file:OptIn(androidx.compose.material3.ExperimentalMaterial3Api::class)

package app.feature.memory.common

import android.text.format.DateFormat
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextAlign
import app.data.model.HistoryMonth
import app.designsystem.R
import app.designsystem.generated.Tokens
import app.ui.components.CircleButtonStyle
import app.ui.components.CircleIconButton
import app.ui.foundation.PageRoles
import app.ui.foundation.tapClickable
import app.ui.system.DsBottomSheet
import app.ui.text.TextRoles
import java.time.DayOfWeek
import java.time.LocalDate
import java.time.format.DateTimeFormatter
import java.time.format.FormatStyle
import java.time.format.TextStyle
import java.util.Locale

/** Days in a week: the calendar's columns. */
private const val DAYS_IN_WEEK = 7

/**
 * One month of the calendar as grid cells, Monday first: nulls before the 1st, then every day of the month, then nulls
 * to fill the last row.
 */
fun calendarCells(month: LocalDate): List<LocalDate?> {
    val first = month.withDayOfMonth(1)
    val blanks = first.dayOfWeek.value - 1 // ISO: Monday = 1
    val days = (0 until first.lengthOfMonth()).map { first.plusDays(it.toLong()) }
    val cells: List<LocalDate?> = List(blanks) { null } + days
    val tail = (DAYS_IN_WEEK - cells.size % DAYS_IN_WEEK) % DAYS_IN_WEEK
    return cells + List(tail) { null }
}

/**
 * The calendar as a page sheet (C-29): the C-11 close circle and the centred "Memories" title, then the months newest
 * first, `size.global.sectionGap` apart — the month and year (`sectionLabel`; with [onSelectMonth] a button, else a plain
 * heading) over a seven-column grid, Monday first (weekday initials, `meta`); a day with something is its number (`pill`)
 * on the C-06 fill circle of `size.global.pillHeight` and calls [onSelectDay] with that day; other days are tertiary
 * numbers that do nothing. week.history passes the day's week and the month's newest week; onthisday ("Pick a date…")
 * takes the day itself and has no month action.
 */
@Composable
fun HistoryCalendarSheet(
    months: List<HistoryMonth>,
    onSelectDay: (LocalDate) -> Unit,
    onClose: () -> Unit,
    onSelectMonth: ((HistoryMonth) -> Unit)? = null,
) {
    DsBottomSheet(onDismissRequest = onClose) {
        HistoryCalendarContent(months, onSelectDay, onClose, onSelectMonth)
    }
}

@Composable
fun HistoryCalendarContent(
    months: List<HistoryMonth>,
    onSelectDay: (LocalDate) -> Unit,
    onClose: () -> Unit,
    onSelectMonth: ((HistoryMonth) -> Unit)? = null,
) {
    val margin = Tokens.Sizes.globalScreenMargin
    Column(Modifier.fillMaxWidth().testTag("week.history.calendar")) {
        Box(Modifier.fillMaxWidth().heightIn(min = Tokens.Sizes.globalMinTouchTargetAndroid).padding(horizontal = margin), contentAlignment = Alignment.Center) {
            CircleIconButton(Tokens.Icons.globalClose, stringResource(R.string.week_history_calendar_a11y_close), onClose, Modifier.align(Alignment.CenterStart), style = CircleButtonStyle.OnPage)
            Text(stringResource(R.string.week_history_calendar_title), style = TextRoles.sheetTitle, color = Tokens.Colors.globalTextPrimary, modifier = Modifier.semantics { heading() })
        }
        LazyColumn(
            contentPadding = PaddingValues(start = margin, end = margin, top = Tokens.Sizes.globalSectionHeaderToContent, bottom = Tokens.Sizes.globalSectionGap),
            verticalArrangement = Arrangement.spacedBy(Tokens.Sizes.globalSectionGap),
        ) {
            items(months, key = { it.month.toString() }) { month -> MonthGrid(month, onSelectDay, onSelectMonth) }
        }
    }
}

@Composable
private fun MonthGrid(month: HistoryMonth, onSelectDay: (LocalDate) -> Unit, onSelectMonth: ((HistoryMonth) -> Unit)?) {
    val active = month.days.toSet()
    val title = CalendarFormats.monthTitle(month.month)
    Column {
        Text(
            title,
            style = TextRoles.sectionLabel,
            color = Tokens.Colors.globalTextPrimary,
            modifier = Modifier
                .heightIn(min = Tokens.Sizes.globalMinTouchTargetAndroid)
                .then(if (onSelectMonth != null) Modifier.tapClickable { onSelectMonth(month) } else Modifier)
                .semantics { heading() },
        )
        Spacer(Modifier.height(Tokens.Sizes.globalSectionHeaderToContent))
        Row(Modifier.fillMaxWidth().clearAndSetSemantics { }) {
            CalendarFormats.weekdayInitials().forEach { initial ->
                Text(initial, style = TextRoles.meta, color = PageRoles.secondaryText(), textAlign = TextAlign.Center, modifier = Modifier.weight(1f))
            }
        }
        calendarCells(month.month).chunked(DAYS_IN_WEEK).forEach { week ->
            Row(Modifier.fillMaxWidth()) {
                week.forEach { day ->
                    Box(Modifier.weight(1f).heightIn(min = Tokens.Sizes.globalMinTouchTargetAndroid), contentAlignment = Alignment.Center) {
                        if (day != null) DayCell(day, day in active, onSelectDay)
                    }
                }
            }
        }
    }
}

/** One day: a button when it has something (C-06 fill circle), else a tertiary number. */
@Composable
private fun DayCell(day: LocalDate, active: Boolean, onSelectDay: (LocalDate) -> Unit) {
    if (active) {
        val spoken = CalendarFormats.spokenFullDate(day)
        Box(
            Modifier
                .size(Tokens.Sizes.globalPillHeight)
                .background(PageRoles.secondarySurface, CircleShape)
                .clearAndSetSemantics { contentDescription = spoken }
                .tapClickable { onSelectDay(day) },
            contentAlignment = Alignment.Center,
        ) {
            Text(day.dayOfMonth.toString(), style = TextRoles.pill, color = Tokens.Colors.globalTextPrimary)
        }
    } else {
        val spoken = stringResource(R.string.week_history_a11y_emptyday, CalendarFormats.weekdayLong(day), MemoryFormats.spokenDate(day))
        Text(
            day.dayOfMonth.toString(),
            style = TextRoles.listSubtitle,
            color = Tokens.Colors.globalTextTertiary,
            modifier = Modifier.clearAndSetSemantics { contentDescription = spoken },
        )
    }
}

/** The calendar's date formats, localised by the platform. */
private object CalendarFormats {
    private fun locale(): Locale = Locale.getDefault()

    /** `week.history.layout.calendar`: a month's title in the locale's format ("October 2026"). */
    fun monthTitle(month: LocalDate): String =
        DateTimeFormatter.ofPattern(DateFormat.getBestDateTimePattern(locale(), MONTH_YEAR_SKELETON), locale()).format(month)

    /** A calendar day read in full ("Saturday, October 3, 2026"). */
    fun spokenFullDate(date: LocalDate): String = DateTimeFormatter.ofLocalizedDate(FormatStyle.FULL).withLocale(locale()).format(date)

    /** The locale's weekday initials, Monday first (the calendar's header row). */
    fun weekdayInitials(): List<String> = DayOfWeek.entries.map { it.getDisplayName(TextStyle.NARROW_STANDALONE, locale()) }

    fun weekdayLong(date: LocalDate): String = date.dayOfWeek.getDisplayName(TextStyle.FULL, locale())

    /** The month-and-year skeleton the locale turns into its pattern ("October 2026"). */
    private const val MONTH_YEAR_SKELETON = "yMMMM"
}
