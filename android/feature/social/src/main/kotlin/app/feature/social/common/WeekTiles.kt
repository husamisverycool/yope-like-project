package app.feature.social.common

import android.content.Context
import androidx.compose.runtime.Composable
import androidx.compose.ui.platform.LocalContext
import app.data.model.Media
import app.data.model.MediaKind
import app.designsystem.R
import app.ui.components.DayTile
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId

/**
 * A photo of a week strip: [path] = its thumbnail, [label] = its TalkBack label (copy); [videoDurationMs] = a video's length
 * (its marker, `layout.global.videoMarker`).
 */
data class StripPhoto(val key: String, val path: String?, val at: Instant, val label: String, val onClick: (() -> Unit)?, val videoDurationMs: Long? = null)

/** A video's length for its marker and label (`layout.global.videoMarker`); null for photos and Live Photos. */
val Media.videoDurationMs: Long? get() = if (kind == MediaKind.Video) (durationMs ?: 0).toLong() else null

/** [label], then `chat.thread.a11y.video` ("Video, 10 seconds") for a video. */
fun withVideoLabel(context: Context, label: String, videoDurationMs: Long?): String =
    if (videoDurationMs == null) label else label + ", " + context.getString(R.string.chat_thread_a11y_video, Formats.spokenDuration(videoDurationMs))

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
        DayTile.Photo(p.key, photoModel(p.path), Formats.weekdayShort(p.at.atZone(zone).toLocalDate()), withVideoLabel(context, p.label, p.videoDurationMs), p.onClick, videoDurationMs = p.videoDurationMs)
    }
    if (!current) return photoTiles
    if (photoTiles.isEmpty()) return listOfNotNull(add) + emptyDays(context, weekStart)
    val photoDays = photos.map { it.at.atZone(zone).toLocalDate() }.toSet()
    val placeholders = (0 until Formats.DAYS_IN_WEEK.toInt()).map { weekStart.plusDays(it.toLong()) }.filter { it !in photoDays }
        .map { day -> DayTile.Placeholder("placeholder-$day", emptyDayLabel(context, day)) }
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
