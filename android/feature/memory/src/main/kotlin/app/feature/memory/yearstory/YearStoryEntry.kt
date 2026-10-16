package app.feature.memory.yearstory

import androidx.compose.runtime.Composable
import androidx.compose.runtime.produceState
import androidx.compose.ui.res.stringResource
import app.data.model.RenderStatus
import app.designsystem.R
import app.feature.memory.common.MemoryBackend
import app.feature.memory.common.MemoryCache
import app.feature.memory.common.attempt
import app.feature.memory.common.rememberMemoryBackend
import java.time.Clock
import java.time.ZoneId

/**
 * The year-story entry card for `groups.screen` (design/surfaces/year.story.md, A). Shown while the group's story
 * for the current year (group time zone) is `ready` — from December 1 (`year_story_release_month_day`); a `pending`
 * story or none composes nothing, as do loading, errors and offline. The card component (a Retro feed card), its
 * position and tokens belong to the `groups.screen` pass; this composable supplies the copy and the action to [card]:
 * - `title` = `year.story.entry.title` ("Year in Photos"),
 * - `subtitle` = `year.story.entry.subtitle` ("{year} Recap"),
 * - `button` = `year.story.entry.button` ("View memories"),
 * - `onClick` = [onOpen] with the year (open `AppRoute.YearStory(groupId, year)`).
 */
@Composable
fun YearStoryEntry(
    groupId: String,
    onOpen: (year: Int) -> Unit,
    card: @Composable (title: String, subtitle: String, button: String, onClick: () -> Unit) -> Unit,
) {
    val backend = rememberMemoryBackend()
    // Cached first, so the row does not pop in on every visit; the read confirms or removes it.
    val key = MemoryCache.key(backend, "entry.yearstory", groupId)
    val year = produceState(MemoryCache.shared.get<Int>(key), groupId, backend) {
        value = readyStoryYear(backend, groupId).also { if (it == null) MemoryCache.shared.remove(key) else MemoryCache.shared.put(key, it) }
    }.value ?: return
    card(
        stringResource(R.string.year_story_entry_title),
        stringResource(R.string.year_story_entry_subtitle, year.toString()),
        stringResource(R.string.year_story_entry_button),
    ) { onOpen(year) }
}

/** The current group-local year when its story is ready, else null. */
internal suspend fun readyStoryYear(backend: MemoryBackend, groupId: String, clock: Clock = Clock.systemUTC()): Int? = attempt {
    val group = backend.group(groupId) ?: return@attempt null
    val zone = runCatching { ZoneId.of(group.timeZone) }.getOrDefault(ZoneId.of("UTC"))
    val year = clock.instant().atZone(zone).year
    backend.yearStory(groupId, year)?.takeIf { it.status == RenderStatus.Ready && it.data != null }?.year
}.getOrNull()
