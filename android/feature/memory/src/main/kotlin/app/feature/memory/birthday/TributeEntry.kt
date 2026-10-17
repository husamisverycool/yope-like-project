package app.feature.memory.birthday

import androidx.compose.runtime.Composable
import androidx.compose.runtime.key
import androidx.compose.runtime.produceState
import androidx.compose.ui.res.stringResource
import app.designsystem.R
import app.feature.memory.common.MemoryBackend
import app.feature.memory.common.MemoryCache
import app.feature.memory.common.MemoryFormats
import app.feature.memory.common.attempt
import app.feature.memory.common.rememberMemoryBackend
import java.time.LocalDate

/** A birthday video card: whose it is, the birthday, and its poster (signed URL). */
data class TributeEntryCard(val tributeId: String, val forMe: Boolean, val honoreeName: String, val birthday: LocalDate, val posterUrl: String?)

/**
 * The birthday video cards for `groups.screen` (design/surfaces/birthday.tribute.md, "Entry on the group screen";
 * MERGE FV-3): one per delivered video of [groupId] you may watch (`group_tributes`: your own, and the ones you
 * contributed to — RLS, migration 0034), newest delivery first. Kept for good, as the year story's cards (owner decision
 * 31), so the honoree finds their video in the group's memories after the day — muted group or not, since a card asks
 * for nothing and sends nothing. Nothing to show — or loading, an error, offline — composes nothing. The card component
 * and its place belong to the `groups.screen` pass; this composable supplies, once per video:
 * - `title` = `birthday.tribute.title` ("Your birthday video") for the honoree, `birthday.tribute.title.member`
 *   ("{name}'s birthday video") for a contributor,
 * - `subtitle` = the birthday in the memory date format (`layout.onthisday.dateFormat`, the year shown: the card stays),
 * - `button` = `birthday.tribute.entry.button` ("Play"),
 * - `photo` = the video's poster (its title card),
 * - `onClick` = [onOpen] with the tribute id (open `AppRoute.Tribute(groupId, tributeId)`).
 */
@Composable
fun TributeEntries(
    groupId: String,
    onOpen: (tributeId: String) -> Unit,
    card: @Composable (title: String, subtitle: String, button: String, photo: Any?, onClick: () -> Unit) -> Unit,
) {
    val backend = rememberMemoryBackend()
    // Cached first, so the cards do not pop in on every visit; the read confirms or removes them.
    val cacheKey = MemoryCache.key(backend, "entry.tributes", groupId)
    val cards = produceState(MemoryCache.shared.get<List<TributeEntryCard>>(cacheKey).orEmpty(), groupId, backend) {
        tributeEntryCards(backend, groupId)?.let { found ->
            value = found
            if (found.isEmpty()) MemoryCache.shared.remove(cacheKey) else MemoryCache.shared.put(cacheKey, found)
        }
    }.value
    for (entry in cards) {
        key(entry.tributeId) {
            card(
                if (entry.forMe) stringResource(R.string.birthday_tribute_title) else stringResource(R.string.birthday_tribute_title_member, entry.honoreeName),
                MemoryFormats.memoryDate(entry.birthday),
                stringResource(R.string.birthday_tribute_entry_button),
                entry.posterUrl,
            ) { onOpen(entry.tributeId) }
        }
    }
}

/** The group's birthday video cards, newest delivery first; null when they could not be read (the cards stay as they were). */
internal suspend fun tributeEntryCards(backend: MemoryBackend, groupId: String): List<TributeEntryCard>? = attempt {
    val tributes = backend.groupTributes(groupId)
    val others = tributes.filterNot { it.forMe }.map { it.honoreeId }.distinct()
    val names = if (others.isEmpty()) emptyMap() else backend.profiles(others).associate { it.id to it.firstName.orEmpty() }
    val posterPaths = tributes.mapNotNull { it.posterPath }
    val posters = if (posterPaths.isEmpty()) emptyMap() else backend.signedUrls(posterPaths)
    tributes.map { TributeEntryCard(it.id, it.forMe, names[it.honoreeId].orEmpty(), it.birthdayDate, it.posterPath?.let(posters::get)) }
}.getOrNull()
