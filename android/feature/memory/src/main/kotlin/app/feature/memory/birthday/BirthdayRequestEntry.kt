package app.feature.memory.birthday

import androidx.compose.runtime.Composable
import androidx.compose.runtime.produceState
import androidx.compose.ui.res.stringResource
import app.data.model.TributeRequest
import app.designsystem.R
import app.feature.memory.common.MemoryBackend
import app.feature.memory.common.MemoryFormats
import app.feature.memory.common.attempt
import app.feature.memory.common.rememberMemoryBackend
import java.time.Clock

/** An open request shown on the group screen: who it is for, and its due date. */
data class OpenRequestEntry(val requestId: String, val honoreeName: String, val request: TributeRequest)

/**
 * Entry rows for open birthday requests on `groups.screen` (design/surfaces/birthday.request.md,
 * "Entry on the group screen"). One row per open request of [groupId] visible to you: the honoree
 * never sees requests about them (RLS, and filtered here again), there is no reminder, badge or
 * "you haven't contributed" state. The row component and its tokens belong to the `groups.screen`
 * pass; this composable supplies the copy and the action to [row]:
 * - `title` = `birthday.request.title` ("Birthday Video for {name}!"),
 * - `subtitle` = `birthday.request.due` ("Submit by {date}", the day before the birthday),
 * - `onClick` = [onOpen] with the request id (open `AppRoute.BirthdayContribute(groupId, requestId)`,
 *   which shows the request first).
 *
 * Composes nothing while loading, on error, offline, or with no open request.
 */
@Composable
fun BirthdayRequestEntries(
    groupId: String,
    onOpen: (requestId: String) -> Unit,
    row: @Composable (title: String, subtitle: String, onClick: () -> Unit) -> Unit,
) {
    val backend = rememberMemoryBackend()
    val entries = produceState(emptyList<OpenRequestEntry>(), groupId, backend) { value = openRequestEntries(backend, groupId) }.value
    for (entry in entries) {
        row(
            stringResource(R.string.birthday_request_title, entry.honoreeName),
            stringResource(R.string.birthday_request_due, MemoryFormats.dueDate(entry.request.birthdayDate)),
        ) { onOpen(entry.requestId) }
    }
}

/** Open requests of [groupId], soonest due first, never about the current user. */
internal suspend fun openRequestEntries(backend: MemoryBackend, groupId: String, clock: Clock = Clock.systemUTC()): List<OpenRequestEntry> =
    attempt {
        val me = backend.currentUserId
        val requests = backend.openRequests().filter { it.groupId == groupId && it.honoreeId != me && it.isOpen(clock.instant()) }
        val names = backend.profiles(requests.map { it.honoreeId }.distinct()).associate { it.id to it.firstName.orEmpty() }
        requests.map { OpenRequestEntry(it.id, names[it.honoreeId].orEmpty(), it) }
    }.getOrDefault(emptyList())
