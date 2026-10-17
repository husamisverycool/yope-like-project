// Surface: week.history (the calendar) — design/surfaces/week.history.md "Calendar — jump to a date"
// (`week.history.layout.calendar`). Mechanics: BeReal's Memories calendar (https://help.bereal.com/hc/en-us/articles/7531349180829:
// past posts reached from a month grid, only the days with one open); drawn with Retro's components (C-29 sheet, C-11
// close circle, C-06 fill, text roles). Owner decision 34 (research #21). No count anywhere.
@file:OptIn(androidx.compose.material3.ExperimentalMaterial3Api::class)

package app.feature.social.week

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
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextAlign
import app.data.model.HistoryMonth
import app.designsystem.R
import app.designsystem.generated.Tokens
import app.feature.social.common.Formats
import app.feature.social.common.stringRes
import app.ui.components.CircleButtonStyle
import app.ui.components.CircleIconButton
import app.ui.foundation.PageRoles
import app.ui.foundation.tapClickable
import app.ui.system.DsBottomSheet
import app.ui.text.TextRoles
import java.time.LocalDate

/** Days in a week: the calendar's columns. */
private const val DAYS_IN_WEEK = 7

/**
 * One month of the calendar as grid cells, Monday first: nulls before the 1st, then every day of the month, then nulls
 * to fill the last row.
 */
internal fun calendarCells(month: LocalDate): List<LocalDate?> {
    val first = month.withDayOfMonth(1)
    val blanks = first.dayOfWeek.value - 1 // ISO: Monday = 1
    val days = (0 until first.lengthOfMonth()).map { first.plusDays(it.toLong()) }
    val cells: List<LocalDate?> = List(blanks) { null } + days
    val tail = (DAYS_IN_WEEK - cells.size % DAYS_IN_WEEK) % DAYS_IN_WEEK
    return cells + List(tail) { null }
}

/**
 * The calendar as a page sheet (C-29): the C-11 close circle and the centred "Memories" title, then the months newest
 * first, `size.global.sectionGap` apart — the month and year (`sectionLabel`, a button to the month's newest week) over a
 * seven-column grid, Monday first (weekday initials, `meta`); a day with something is its number (`pill`) on the C-06
 * fill circle of `size.global.pillHeight` and opens its week; other days are tertiary numbers that do nothing.
 */
@Composable
fun HistoryCalendarSheet(months: List<HistoryMonth>, onSelect: (LocalDate) -> Unit, onClose: () -> Unit) {
    DsBottomSheet(onDismissRequest = onClose) {
        HistoryCalendarContent(months, onSelect, onClose)
    }
}

@Composable
internal fun HistoryCalendarContent(months: List<HistoryMonth>, onSelect: (LocalDate) -> Unit, onClose: () -> Unit) {
    val margin = Tokens.Sizes.globalScreenMargin
    Column(Modifier.fillMaxWidth().testTag("week.history.calendar")) {
        Box(Modifier.fillMaxWidth().heightIn(min = Tokens.Sizes.globalMinTouchTargetAndroid).padding(horizontal = margin), contentAlignment = Alignment.Center) {
            CircleIconButton(Tokens.Icons.globalClose, stringRes(R.string.week_history_calendar_a11y_close), onClose, Modifier.align(Alignment.CenterStart), style = CircleButtonStyle.OnPage)
            Text(stringRes(R.string.week_history_calendar_title), style = TextRoles.sheetTitle, color = Tokens.Colors.globalTextPrimary, modifier = Modifier.semantics { heading() })
        }
        LazyColumn(
            contentPadding = PaddingValues(start = margin, end = margin, top = Tokens.Sizes.globalSectionHeaderToContent, bottom = Tokens.Sizes.globalSectionGap),
            verticalArrangement = Arrangement.spacedBy(Tokens.Sizes.globalSectionGap),
        ) {
            items(months, key = { it.month.toString() }) { month -> MonthGrid(month, onSelect) }
        }
    }
}

@Composable
private fun MonthGrid(month: HistoryMonth, onSelect: (LocalDate) -> Unit) {
    val active = month.days.toSet()
    val title = Formats.monthTitle(month.month)
    Column {
        Text(
            title,
            style = TextRoles.sectionLabel,
            color = Tokens.Colors.globalTextPrimary,
            modifier = Modifier
                .heightIn(min = Tokens.Sizes.globalMinTouchTargetAndroid)
                .tapClickable { onSelect(month.newestWeek) }
                .semantics { heading() },
        )
        Spacer(Modifier.height(Tokens.Sizes.globalSectionHeaderToContent))
        Row(Modifier.fillMaxWidth().clearAndSetSemantics { }) {
            Formats.weekdayInitials().forEach { initial ->
                Text(initial, style = TextRoles.meta, color = PageRoles.secondaryText(), textAlign = TextAlign.Center, modifier = Modifier.weight(1f))
            }
        }
        calendarCells(month.month).chunked(DAYS_IN_WEEK).forEach { week ->
            Row(Modifier.fillMaxWidth()) {
                week.forEach { day ->
                    Box(Modifier.weight(1f).heightIn(min = Tokens.Sizes.globalMinTouchTargetAndroid), contentAlignment = Alignment.Center) {
                        if (day != null) DayCell(day, day in active, onSelect)
                    }
                }
            }
        }
    }
}

/** One day: a button to its week when it has something (C-06 fill circle), else a tertiary number. */
@Composable
private fun DayCell(day: LocalDate, active: Boolean, onSelect: (LocalDate) -> Unit) {
    if (active) {
        val spoken = Formats.spokenFullDate(day)
        Box(
            Modifier
                .size(Tokens.Sizes.globalPillHeight)
                .background(PageRoles.secondarySurface, CircleShape)
                .clearAndSetSemantics { contentDescription = spoken }
                .tapClickable { onSelect(Formats.weekStartOf(day)) },
            contentAlignment = Alignment.Center,
        ) {
            Text(Formats.dayNumber(day), style = TextRoles.pill, color = Tokens.Colors.globalTextPrimary)
        }
    } else {
        val spoken = stringRes(R.string.week_history_a11y_emptyday, Formats.weekdayLong(day), Formats.spokenDate(day))
        Text(
            Formats.dayNumber(day),
            style = TextRoles.listSubtitle,
            color = Tokens.Colors.globalTextTertiary,
            modifier = Modifier.clearAndSetSemantics { contentDescription = spoken },
        )
    }
}
