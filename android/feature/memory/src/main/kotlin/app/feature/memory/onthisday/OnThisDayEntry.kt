package app.feature.memory.onthisday

import androidx.compose.runtime.Composable
import androidx.compose.runtime.produceState
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import app.designsystem.R
import app.feature.memory.common.MemoryBackend
import app.feature.memory.common.MemoryFormats
import app.feature.memory.common.attempt
import app.feature.memory.common.rememberMemoryBackend
import java.time.Clock
import java.time.ZoneId

/**
 * The "Day in History" entry for `groups.screen` (design/surfaces/onthisday.md, A).
 *
 * Shown only while `on_this_day(group, localDate)` returns at least one row; while loading, on
 * error, offline or with no rows it composes nothing. The row component, its position and its tokens
 * belong to the `groups.screen` pass, so this composable only supplies the copy and the action and
 * hands them to [row]:
 * - `title` = `onthisday.entry.title` ("{group}'s Day in History"),
 * - `subtitle` = the newest memory's banner label (`onthisday.banner.yearsAgo.one` / `.other`),
 * - `onClick` = [onOpen] (open the day, e.g. `navController.navigate(OnThisDayRoute(groupId))`).
 *
 * @param groupId the group whose day is checked.
 * @param groupName the group's name, for the title.
 */
@Composable
fun OnThisDayEntry(
    groupId: String,
    groupName: String,
    onOpen: () -> Unit,
    row: @Composable (title: String, subtitle: String, onClick: () -> Unit) -> Unit,
) {
    val backend = rememberMemoryBackend()
    val newest = produceState<Int?>(null, groupId, backend) { value = newestYearsAgo(backend, groupId) }.value ?: return
    val subtitle = MemoryFormats.yearsAgo(LocalContext.current.resources, newest)
    row(stringResource(R.string.onthisday_entry_title, groupName), subtitle, onOpen)
}

/** `years_ago` of the newest memory today, or null when the entry is hidden. */
internal suspend fun newestYearsAgo(backend: MemoryBackend, groupId: String, clock: Clock = Clock.systemUTC()): Int? =
    attempt {
        val group = backend.group(groupId) ?: return@attempt null
        val zone = runCatching { ZoneId.of(group.timeZone) }.getOrDefault(ZoneId.of("UTC"))
        backend.onThisDay(groupId, OnThisDayViewModel.localDate(clock, zone)).minOfOrNull { it.yearsAgo }
    }.getOrNull()
