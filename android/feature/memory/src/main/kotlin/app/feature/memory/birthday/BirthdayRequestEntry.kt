package app.feature.memory.birthday

import androidx.compose.runtime.Composable
import androidx.compose.runtime.SideEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.produceState
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.ui.res.stringResource
import app.data.model.TributeRequest
import app.designsystem.R
import app.feature.memory.common.MemoryBackend
import app.feature.memory.common.MemoryCache
import app.feature.memory.common.MemoryFormats
import app.feature.memory.common.attempt
import app.feature.memory.common.rememberMemoryBackend
import java.time.Clock
import java.time.LocalDate

/** An open request shown on the group screen: who it is for (name, avatar URL), and its due date. */
data class OpenRequestEntry(val requestId: String, val honoreeName: String, val request: TributeRequest, val avatarUrl: String? = null)

/**
 * Entry rows for open birthday requests on `groups.screen` (design/surfaces/birthday.request.md,
 * "Entry on the group screen"). One row per open request of [groupId] visible to you: the honoree
 * never sees requests about them (RLS, and filtered here again), there is no reminder, badge or
 * "you haven't contributed" state. The row component and its tokens belong to the `groups.screen`
 * pass; this composable supplies the copy and the action to [row]:
 * - `title` = `birthday.request.title` ("Birthday Video for {name}!"),
 * - `subtitle` = `birthday.request.due` ("Submit by {date}", the day before the birthday),
 * - `avatar` = the honoree's avatar (signed URL; C-16 `size.global.avatarPicker`, as iOS),
 * - `onClick` = [onOpen] with the request id (open `AppRoute.BirthdayContribute(groupId, requestId)`,
 *   which shows the request first, `birthday.request`, then the contribute sheet — as iOS).
 * [onDay] gets the soonest birthday among the rows (null: none) for their place next to the plans block (date order,
 * MERGE FV-1).
 *
 * Composes nothing while loading, on error, offline, or with no open request.
 */
@Composable
fun BirthdayRequestEntries(
    groupId: String,
    onOpen: (requestId: String) -> Unit,
    onDay: (LocalDate?) -> Unit = {},
    row: @Composable (title: String, subtitle: String, avatar: Any?, onClick: () -> Unit) -> Unit,
) {
    val backend = rememberMemoryBackend()
    // Cached first, so rows do not pop in on every visit; the read confirms or replaces them.
    val key = MemoryCache.key(backend, "entry.requests", groupId)
    val entries = produceState(MemoryCache.shared.get<List<OpenRequestEntry>>(key).orEmpty(), groupId, backend) {
        value = (openRequestEntries(backend, groupId) ?: value).also { MemoryCache.shared.put(key, it) }
    }.value.filter { it.request.isOpen(java.time.Instant.now()) }
    val day by rememberUpdatedState(entries.minOfOrNull { it.request.birthdayDate })
    val report by rememberUpdatedState(onDay)
    SideEffect { report(day) }
    for (entry in entries) {
        row(
            stringResource(R.string.birthday_request_title, entry.honoreeName),
            stringResource(R.string.birthday_request_due, MemoryFormats.dueDate(entry.request.birthdayDate)),
            entry.avatarUrl,
        ) { onOpen(entry.requestId) }
    }
}

/** Open requests of [groupId], soonest due first, never about the current user; null when the read failed. */
internal suspend fun openRequestEntries(backend: MemoryBackend, groupId: String, clock: Clock = Clock.systemUTC()): List<OpenRequestEntry>? =
    attempt {
        val me = backend.currentUserId
        val requests = backend.openRequests().filter { it.groupId == groupId && it.honoreeId != me && it.isOpen(clock.instant()) }
        val profiles = backend.profiles(requests.map { it.honoreeId }.distinct()).associateBy { it.id }
        val avatars = profiles.values.mapNotNull { it.avatarPath }.takeIf { it.isNotEmpty() }?.let { backend.signedUrls(it) }.orEmpty()
        requests.map { request ->
            val profile = profiles[request.honoreeId]
            OpenRequestEntry(request.id, profile?.firstName.orEmpty(), request, profile?.avatarPath?.let(avatars::get))
        }
    }.getOrNull()
