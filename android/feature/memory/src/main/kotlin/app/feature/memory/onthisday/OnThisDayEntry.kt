package app.feature.memory.onthisday

import androidx.compose.runtime.Composable
import androidx.compose.runtime.produceState
import androidx.compose.ui.res.stringResource
import app.designsystem.R
import app.feature.memory.common.MemoryBackend
import app.feature.memory.common.MemoryCache
import app.feature.memory.common.MemoryFormats
import app.feature.memory.common.attempt
import app.feature.memory.common.rememberMemoryBackend
import java.time.Clock
import java.time.LocalDate
import java.time.ZoneId

/**
 * The On This Day entry card for `groups.screen` (design/surfaces/onthisday.md A).
 *
 * Shown only while `on_this_day(group, localDate)` returns rows; while loading, on error, offline or with no rows it
 * composes nothing. The card component, its position and its tokens belong to the `groups.screen` pass (a Retro feed
 * card), so this composable only supplies the copy and the action and hands them to [card]:
 * - `title` = `onthisday.entry.title` ("On this day"),
 * - `subtitle` = `onthisday.entry.subtitle` ("Revisit memories from {date} over the years", `{date}` = today in the
 *   group's time zone as `layout.birthday.add.dateFormat`, "July 5"),
 * - `button` = `onthisday.entry.button` ("View memories"),
 * - `onClick` = [onOpen] (open the page at the newest memory, e.g. `navController.openOnThisDay(groupId)`).
 */
@Composable
fun OnThisDayEntry(
    groupId: String,
    onOpen: () -> Unit,
    card: @Composable (title: String, subtitle: String, button: String, onClick: () -> Unit) -> Unit,
) {
    val backend = rememberMemoryBackend()
    // Cached first, so the card does not pop in on every visit; the read confirms or removes it.
    val key = MemoryCache.key(backend, "entry.onthisday", groupId)
    val today = produceState(MemoryCache.shared.get<LocalDate>(key), groupId, backend) {
        value = entryDate(backend, groupId).also { if (it == null) MemoryCache.shared.remove(key) else MemoryCache.shared.put(key, it) }
    }.value ?: return
    card(
        stringResource(R.string.onthisday_entry_title),
        stringResource(R.string.onthisday_entry_subtitle, MemoryFormats.dayMonth(today)),
        stringResource(R.string.onthisday_entry_button),
        onOpen,
    )
}

/** Today's date (group-local, `layout.onthisday.dayBoundary`) when the group has memories of it, else null. */
internal suspend fun entryDate(backend: MemoryBackend, groupId: String, clock: Clock = Clock.systemUTC()): LocalDate? =
    attempt {
        val group = backend.group(groupId) ?: return@attempt null
        val zone = runCatching { ZoneId.of(group.timeZone) }.getOrDefault(ZoneId.of("UTC"))
        val date = OnThisDayViewModel.localDate(clock, zone)
        date.takeIf { backend.onThisDay(groupId, it).isNotEmpty() }
    }.getOrNull()
