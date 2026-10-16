package app.feature.capture.data

import app.data.error.DataError
import app.data.error.DataException
import app.data.media.upload.NewPost
import app.data.media.upload.UploadProgress
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.launch

/**
 * One post sent while its sheet stays open (camera.sendto → send, daily.capture → send): the capsule is busy
 * and the title reads "Sending…" until `create_post` succeeded ([Status.Sent] → the sheet closes); a failure
 * keeps everything in the sheet and shows the native alert ([Status.Failed]: `camera.sendto.error.sendFailed`
 * with `.error.generic`, or `.error.offline` while the device is offline). "Try Again" ([retry]) re-queues the
 * same draft; "Cancel" ([cancel]) withdraws it, so the next Send starts over without a duplicate post.
 * Built on the upload queue (`uploads.enqueue`, docs/API.md 9.4), which copies the files and resumes.
 */
class PostSend(private val data: CaptureData, private val scope: CoroutineScope) {

    sealed interface Status {
        data object Idle : Status
        data object Sending : Status
        data class Sent(val postIds: List<String>) : Status
        data class Failed(val offline: Boolean) : Status
    }

    private val state = MutableStateFlow<Status>(Status.Idle)
    val status: StateFlow<Status> = state.asStateFlow()

    private var draftId: String? = null
    private var permanent = false
    private var job: Job? = null

    /** Queues [post] and follows it; false when it could not even be queued (status [Status.Failed]). */
    fun send(post: NewPost): Boolean {
        if (state.value == Status.Sending) return false
        state.value = Status.Sending
        val id = try {
            data.enqueue(post)
        } catch (e: DataException) {
            state.value = Status.Failed(offline = e.error == DataError.Network)
            return false
        }
        draftId = id
        follow(id)
        return true
    }

    /** "Try Again": the same draft once more. */
    fun retry() {
        val id = draftId ?: run { state.value = Status.Idle; return }
        state.value = Status.Sending
        if (permanent) runCatching { data.retry(id) }
        follow(id)
    }

    /** "Cancel": the draft is withdrawn; the sheet keeps the capture, message and choices. */
    fun cancel() {
        job?.cancel()
        draftId?.let { id -> runCatching { data.discardDraft(id) } }
        draftId = null
        state.value = Status.Idle
    }

    private fun follow(id: String) {
        job?.cancel()
        permanent = false
        job = scope.launch {
            combine(data.progress(id), data.online) { progress, online -> progress to online }.collect { (progress, online) ->
                when (progress) {
                    is UploadProgress.Done -> {
                        draftId = null
                        state.value = Status.Sent(progress.postIds)
                        job?.cancel()
                    }
                    is UploadProgress.Failed -> {
                        permanent = true
                        state.value = Status.Failed(offline = progress.error == DataError.Network || !online)
                    }
                    UploadProgress.Queued, UploadProgress.Waiting, is UploadProgress.Running ->
                        state.value = if (online) Status.Sending else Status.Failed(offline = true)
                }
            }
        }
    }
}
