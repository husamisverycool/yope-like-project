package app.feature.memory.yearstory

import androidx.compose.runtime.Composable
import androidx.compose.runtime.key
import androidx.compose.runtime.produceState
import androidx.compose.ui.res.stringResource
import app.data.model.RenderStatus
import app.designsystem.R
import app.feature.memory.common.MemoryBackend
import app.feature.memory.common.MemoryCache
import app.feature.memory.common.attempt
import app.feature.memory.common.rememberMemoryBackend

/**
 * The year-story entry cards for `groups.screen` (design/surfaces/year.story.md, A): one per `ready` story of the group,
 * newest year first. A story appears once it is ready (from December 1, `year_story_release_month_day`) and stays for
 * good (owner decision 31: kept in the group's memories), so last year's card does not go on 1 January. No ready story —
 * or loading, an error, offline — composes nothing. The card component (a Retro feed card), its position and tokens
 * belong to the `groups.screen` pass; this composable supplies the copy and the action to [card], once per story:
 * - `title` = `year.story.entry.title` ("Year in Photos"),
 * - `subtitle` = `year.story.entry.subtitle` ("{year} Recap"),
 * - `button` = `year.story.entry.button` ("View memories"),
 * - `onClick` = [onOpen] with that story's year (open `AppRoute.YearStory(groupId, year)`).
 */
@Composable
fun YearStoryEntry(
    groupId: String,
    onOpen: (year: Int) -> Unit,
    card: @Composable (title: String, subtitle: String, button: String, onClick: () -> Unit) -> Unit,
) {
    val backend = rememberMemoryBackend()
    // Cached first, so the cards do not pop in on every visit; the read confirms or removes them.
    val cacheKey = MemoryCache.key(backend, "entry.yearstories", groupId)
    val years = produceState(MemoryCache.shared.get<List<Int>>(cacheKey).orEmpty(), groupId, backend) {
        readyStoryYears(backend, groupId)?.let { found ->
            value = found
            if (found.isEmpty()) MemoryCache.shared.remove(cacheKey) else MemoryCache.shared.put(cacheKey, found)
        }
    }.value
    for (year in years) {
        key(year) {
            card(
                stringResource(R.string.year_story_entry_title),
                stringResource(R.string.year_story_entry_subtitle, year.toString()),
                stringResource(R.string.year_story_entry_button),
            ) { onOpen(year) }
        }
    }
}

/** The years of the group's ready stories, newest first; null when they could not be read (the cards stay as they were). */
internal suspend fun readyStoryYears(backend: MemoryBackend, groupId: String): List<Int>? = attempt {
    backend.yearStories(groupId)
        .filter { it.status == RenderStatus.Ready && YearStoryData.parse(it.data) != null }
        .map { it.year }
        .distinct()
        .sortedDescending()
}.getOrNull()
