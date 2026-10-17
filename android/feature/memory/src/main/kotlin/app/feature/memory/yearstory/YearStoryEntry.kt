package app.feature.memory.yearstory

import androidx.compose.runtime.Composable
import androidx.compose.runtime.key
import androidx.compose.runtime.produceState
import androidx.compose.ui.res.stringResource
import app.data.model.Media
import app.data.model.RenderStatus
import app.designsystem.R
import app.designsystem.generated.Tokens
import app.feature.memory.common.MemoryBackend
import app.feature.memory.common.MemoryCache
import app.feature.memory.common.attempt
import app.feature.memory.common.rememberMemoryBackend

/**
 * The year-story entry cards for `groups.screen` (design/surfaces/year.story.md, A): one per `ready` story of the group,
 * newest year first. A story appears once it is ready (from December 1, `year_story_release_month_day`) and stays for
 * good (owner decision 31: kept in the group's memories), so last year's card does not go on 1 January. No ready story —
 * or loading, an error, offline — composes nothing. The card component (a Retro feed card), its position and tokens
 * belong to the `groups.screen` pass; this composable supplies the copy, the photo and the action to [card], once per
 * story:
 * - `title` = `year.story.entry.title` ("Year in Photos"),
 * - `subtitle` = `year.story.entry.subtitle` ("{year} Recap"),
 * - `button` = `year.story.entry.button` ("View memories"),
 * - `photo` = the story's cover (signed display URL; as iOS `YearStoryEntryModel`, groups.screen item 8 "Card = the
 *   feature's newest photo"), null when none is visible,
 * - `onClick` = [onOpen] with that story's year (open `AppRoute.YearStory(groupId, year)`).
 */
@Composable
fun YearStoryEntry(
    groupId: String,
    onOpen: (year: Int) -> Unit,
    card: @Composable (title: String, subtitle: String, button: String, photo: Any?, onClick: () -> Unit) -> Unit,
) {
    val backend = rememberMemoryBackend()
    // Cached first, so the cards do not pop in on every visit; the read confirms or removes them.
    val cacheKey = MemoryCache.key(backend, "entry.yearstory.cards", groupId)
    val cards = produceState(MemoryCache.shared.get<List<YearStoryEntryCard>>(cacheKey).orEmpty(), groupId, backend) {
        readyStoryCards(backend, groupId)?.let { found ->
            value = found
            if (found.isEmpty()) MemoryCache.shared.remove(cacheKey) else MemoryCache.shared.put(cacheKey, found)
        }
    }.value
    for (entry in cards) {
        key(entry.year) {
            card(
                stringResource(R.string.year_story_entry_title),
                stringResource(R.string.year_story_entry_subtitle, entry.year.toString()),
                stringResource(R.string.year_story_entry_button),
                entry.coverUrl,
            ) { onOpen(entry.year) }
        }
    }
}

/** A ready story's card: its year and its cover photo (signed display URL). */
data class YearStoryEntryCard(val year: Int, val coverUrl: String?)

/**
 * The group's ready stories, newest year first, each with its cover — the first visible of its most-reacted posts, else
 * of its posts (the first `count.year.story.listLength` of each, as iOS); null when they could not be read.
 */
internal suspend fun readyStoryCards(backend: MemoryBackend, groupId: String): List<YearStoryEntryCard>? = attempt {
    val stories = backend.yearStories(groupId)
        .filter { it.status == RenderStatus.Ready && YearStoryData.parse(it.data) != null }
        .sortedByDescending { it.year }
        .distinctBy { it.year }
    stories.map { story ->
        val data = YearStoryData.parse(story.data)!!
        var cover: String? = null
        for (candidates in listOf(data.mostReacted, story.postIds)) {
            if (cover != null || candidates.isEmpty()) continue
            val ids = candidates.take(Tokens.Counts.yearStoryListLength)
            val posts = backend.posts(ids).associateBy { it.id }
            val media = backend.media(posts.values.map { it.mediaId }.distinct()).associateBy { it.id }
            cover = ids.firstNotNullOfOrNull { id -> posts[id]?.let { media[it.mediaId] }?.imagePath(Media.Rendition.Display) }
        }
        val url = cover?.let { path -> backend.signedUrls(listOf(path))[path] }
        YearStoryEntryCard(story.year, url)
    }
}.getOrNull()

/** The years of the group's ready stories, newest first; null when they could not be read (the cards stay as they were). */
internal suspend fun readyStoryYears(backend: MemoryBackend, groupId: String): List<Int>? = attempt {
    backend.yearStories(groupId)
        .filter { it.status == RenderStatus.Ready && YearStoryData.parse(it.data) != null }
        .map { it.year }
        .distinct()
        .sortedDescending()
}.getOrNull()
