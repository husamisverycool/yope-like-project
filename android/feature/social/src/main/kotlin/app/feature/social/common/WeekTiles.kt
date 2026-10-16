package app.feature.social.common

import android.content.Context
import androidx.compose.runtime.Composable
import androidx.compose.ui.platform.LocalContext
import app.designsystem.R
import app.ui.components.DayTile
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId

/** A photo of a week strip: [path] = its thumbnail, [label] = its TalkBack label (copy). */
data class StripPhoto(val key: String, val path: String?, val at: Instant, val label: String, val onClick: (() -> Unit)?)

/**
 * The C-17 tiles of one week (`week.history.layout.weeks` / `.currentWeek`, `walls.mine.layout.weeks`):
 *
 * - a past week: one photo tile per photo in time order, weekday label from its time;
 * - the current week without photos: the add tile ([add]; none where you cannot post — `readOnly`), then seven
 *   dated empty-day tiles Monday → Sunday;
 * - the current week with photos: the photo tiles, the add tile, then one blank placeholder per day of the week
 *   that has no photo.
 */
@Composable
fun weekStripTiles(weekStart: LocalDate, photos: List<StripPhoto>, current: Boolean, add: DayTile.Add?, zone: ZoneId): List<DayTile> {
    val context = LocalContext.current
    val photoTiles = photos.sortedBy { it.at }.map { p ->
        DayTile.Photo(p.key, photoModel(p.path), Formats.weekdayShort(p.at.atZone(zone).toLocalDate()), p.label, p.onClick)
    }
    if (!current) return photoTiles
    if (photoTiles.isEmpty()) return listOfNotNull(add) + emptyDays(context, weekStart)
    val daysWithPhotos = photos.map { it.at.atZone(zone).toLocalDate() }.distinct().size
    val placeholders = (0 until (Formats.DAYS_IN_WEEK.toInt() - daysWithPhotos).coerceAtLeast(0)).map { i -> DayTile.Placeholder("placeholder-$weekStart-$i", emptyDayLabel(context, weekStart.plusDays((daysWithPhotos + i).toLong()))) }
    return photoTiles + listOfNotNull(add) + placeholders
}

/** Seven dated empty-day tiles (month / day / weekday, `color.global.emptyTileText`). */
fun emptyDays(context: Context, weekStart: LocalDate): List<DayTile> = (0 until Formats.DAYS_IN_WEEK.toInt()).map { i ->
    val day = weekStart.plusDays(i.toLong())
    DayTile.Empty("empty-$day", Formats.monthShort(day), Formats.dayNumber(day), Formats.weekdayShort(day), emptyDayLabel(context, day))
}

/** Seven grey placeholder tiles (loading, C-28 / VID-COMP placeholders). */
fun placeholderDays(weekStart: LocalDate): List<DayTile> = (0 until Formats.DAYS_IN_WEEK.toInt()).map { i -> DayTile.Placeholder("loading-$weekStart-$i") }

/** `week.history.a11y.emptyDay` ("Monday, October 12, 2026, no photos"). */
fun emptyDayLabel(context: Context, day: LocalDate): String =
    context.getString(R.string.week_history_a11y_emptyday, Formats.weekdayLong(day), Formats.spokenDate(day))
