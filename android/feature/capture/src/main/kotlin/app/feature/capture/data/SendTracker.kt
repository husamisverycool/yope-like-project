package app.feature.capture.data

import app.data.error.DataError
import app.data.media.upload.UploadProgress
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asSharedFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.launch

/**
 * Follows posts sent from the capture screens after their sheet closed (`camera.sendto` →
 * States: sending / sent / error / offline) and tells the toast host what to show.
 *
 * - [failure]: the error toast with retry (`camera.sendto.error.sendFailed` / `.offline`),
 *   shown until the draft is sent; the capture, caption and voice note stay in the draft.
 * - [sent]: one event per sent post (`create_post` succeeded) for `haptic.global.send`, and for
 *   the "posted in …" toast once its visible duration is sourced (BLOCKED).
 */
class SendTracker(private val data: CaptureData, private val scope: CoroutineScope) {

    /** One post that was queued: its draft and the names of the groups it goes to. */
    data class Sent(val draftId: String, val groupNames: List<String>)

    sealed interface Failure {
        val draftId: String
        data class SendFailed(override val draftId: String, val error: DataError) : Failure
        data class Offline(override val draftId: String) : Failure
    }

    private val failures = MutableStateFlow<Failure?>(null)
    val failure: StateFlow<Failure?> = failures.asStateFlow()

    private val sentEvents = MutableSharedFlow<Sent>(extraBufferCapacity = EVENT_BUFFER)
    val sent: SharedFlow<Sent> = sentEvents.asSharedFlow()

    private val jobs = mutableMapOf<String, Job>()

    fun track(draftId: String, groupNames: List<String>) {
        jobs[draftId]?.cancel()
        jobs[draftId] = scope.launch {
            combine(data.progress(draftId), data.online) { progress, online -> progress to online }.collect { (progress, online) ->
                when (progress) {
                    is UploadProgress.Done -> {
                        clear(draftId)
                        sentEvents.tryEmit(Sent(draftId, groupNames))
                        jobs.remove(draftId)?.cancel()
                    }
                    is UploadProgress.Failed -> failures.value = Failure.SendFailed(draftId, progress.error)
                    UploadProgress.Queued, UploadProgress.Waiting, is UploadProgress.Running ->
                        if (!online) failures.value = Failure.Offline(draftId) else clear(draftId)
                }
            }
        }
    }

    /** The toast's "try again": queue the draft again. */
    fun retry(draftId: String) {
        clear(draftId)
        runCatching { data.retry(draftId) }
    }

    private fun clear(draftId: String) {
        if (failures.value?.draftId == draftId) failures.value = null
    }

    private companion object {
        const val EVENT_BUFFER = 8
    }
}
