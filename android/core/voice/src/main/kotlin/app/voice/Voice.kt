package app.voice

import android.content.Context
import android.media.MediaMetadataRetriever
import android.net.Uri
import android.os.SystemClock
import androidx.media3.common.MediaItem
import androidx.media3.common.Player
import androidx.media3.exoplayer.ExoPlayer
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.File
import java.util.UUID

/** A finished recording: the `.m4a`, its length and its waveform (100 levels of 0…31, [VoiceLevels]). */
data class VoiceNote(val file: File, val durationMs: Long, val levels: List<Int>)

/** Earlier waveform helpers (kept while callers move to [VoiceLevels]). */
object Waveform {
    const val MAX_AMPLITUDE = VoiceLevels.MAX_AMPLITUDE

    fun level(amplitude: Int): Float = VoiceLevels.level(amplitude)

    /** Resamples [levels] into [count] bars (peak per bucket). */
    fun bars(levels: List<Float>, count: Int): List<Float> {
        require(count > 0)
        return VoiceLevels.bucketPeaks(levels, count)
    }
}

/**
 * Records voice (`chat.voice.layout.recording` / `.locked`): start, pause, continue, a playable draft while paused, stop
 * (segments joined into one `.m4a`) or cancel. Samples the input's peak level every [VoiceLevels.SAMPLING_INTERVAL_MS]
 * while recording; [levels] is the live / draft waveform (C-36) and [elapsedMs] the recorded length.
 */
class VoiceRecorder(
    context: Context,
    clock: () -> Long = SystemClock::elapsedRealtime,
    private val engine: RecordingEngine = MediaRecorderEngine(context, clock),
    private val joiner: (List<File>, File) -> Unit = Mp4AudioJoiner::join,
    private val directory: File = voiceCacheDirectory(context),
) {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    private val session = RecordingSession(engine) { newFile() }
    private val currentState = MutableStateFlow(RecordingSession.State.Idle)
    private val currentLevels = MutableStateFlow<List<Int>>(emptyList())
    private val currentElapsed = MutableStateFlow(0L)
    private var sampling: Job? = null

    /** The joined draft of a multi-segment paused recording (for previews) and the segments it was made from. */
    private var draft: Pair<File, List<File>>? = null

    val state: StateFlow<RecordingSession.State> = currentState.asStateFlow()

    /** The waveform of what was recorded so far (100 levels of 0…31); empty when idle. */
    val levels: StateFlow<List<Int>> = currentLevels.asStateFlow()

    /** Recorded length so far, in ms. */
    val elapsedMs: StateFlow<Long> = currentElapsed.asStateFlow()

    /** A recording exists (recording or paused). */
    val isRecording: Boolean get() = session.state != RecordingSession.State.Idle

    /** Starts recording (RECORD_AUDIO granted); throws when the recorder cannot start. */
    fun start() {
        cancel()
        directory.mkdirs()
        session.start()
        startSampling()
        publish()
    }

    /** Recording → paused (`MediaRecorder.pause()`). */
    fun pause() {
        if (session.state != RecordingSession.State.Recording) return
        session.pause()
        stopSampling()
        publish()
    }

    /** Paused → recording, at the end of the draft (`MediaRecorder.resume()`, or a new segment after a preview). */
    fun resume() {
        session.resume()
        startSampling()
        publish()
    }

    /** The paused draft as one playable file: the open segment is finished first; several segments are joined. */
    suspend fun draftFile(): File {
        val segments = session.finishDraft()
        publish()
        segments.singleOrNull()?.let { return it }
        draft?.let { (file, from) -> if (from == segments) return file }
        discardDraft()
        val out = newFile()
        withContext(Dispatchers.IO) { joiner(segments, out) }
        draft = out to segments
        return out
    }

    /** Stops and returns the recording (one file; segments joined off the main thread), or null when nothing usable. */
    suspend fun finish(): VoiceNote? = finishWith { segments, out -> withContext(Dispatchers.IO) { joiner(segments, out) } }

    /**
     * Earlier callers' start: [output] and [samplingIntervalMs] are ignored (segments go to the recorder's directory, the
     * level is read every [VoiceLevels.SAMPLING_INTERVAL_MS]).
     */
    @Suppress("UNUSED_PARAMETER")
    fun start(output: File, samplingIntervalMs: Long) = start()

    /** Earlier callers' stop: [finish] with the segments joined on the calling thread. */
    fun stop(): VoiceNote? = kotlinx.coroutines.runBlocking { finishWith { segments, out -> joiner(segments, out) } }

    private suspend fun finishWith(join: suspend (List<File>, File) -> Unit): VoiceNote? {
        if (session.state == RecordingSession.State.Idle) return null
        stopSampling()
        val result = session.finish()
        publish()
        val segments = result.segments
        if (segments.isEmpty()) {
            discardDraft()
            return null
        }
        val joined = draft?.takeIf { it.second == segments }?.first
        val file = when {
            segments.size == 1 -> segments.first().also { discardDraft() }
            joined != null -> joined.also { draft = null }
            else -> {
                discardDraft()
                val out = newFile()
                val ok = runCatching { join(segments, out) }.isSuccess
                if (!ok) {
                    (segments + out).forEach(File::delete)
                    return null
                }
                out
            }
        }
        if (segments.size > 1) segments.forEach(File::delete)
        return VoiceNote(file, result.durationMs, result.levels)
    }

    /** Stops and deletes the recording. */
    fun cancel() {
        stopSampling()
        session.cancel()
        discardDraft()
        publish()
    }

    fun release() {
        cancel()
        scope.cancel()
    }

    private fun startSampling() {
        sampling?.cancel()
        sampling = scope.launch {
            while (isActive) {
                session.sample()
                publish()
                delay(VoiceLevels.SAMPLING_INTERVAL_MS)
            }
        }
    }

    private fun stopSampling() {
        sampling?.cancel()
        sampling = null
    }

    private fun publish() {
        currentState.value = session.state
        currentElapsed.value = session.elapsedMs
        currentLevels.value = if (session.state == RecordingSession.State.Idle) emptyList() else session.levels
    }

    private fun discardDraft() {
        draft?.first?.delete()
        draft = null
    }

    private fun newFile(): File = File(directory, "${UUID.randomUUID()}.m4a")
}

/** Playback state for a voice message, positions in ms. */
data class PlaybackState(val uri: Uri?, val isPlaying: Boolean, val positionMs: Long, val durationMs: Long?)

/** Media3 playback of voice messages (local files or signed URLs). */
class VoicePlayer(context: Context, private val progressIntervalMs: Long) {
    private val player: ExoPlayer = ExoPlayer.Builder(context.applicationContext).build()
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    private var ticker: Job? = null
    private val current = MutableStateFlow(PlaybackState(uri = null, isPlaying = false, positionMs = 0, durationMs = null))
    val state: StateFlow<PlaybackState> = current.asStateFlow()

    init {
        require(progressIntervalMs > 0)
        player.addListener(object : Player.Listener {
            override fun onIsPlayingChanged(isPlaying: Boolean) {
                publish()
                if (isPlaying) startTicker() else ticker?.cancel()
            }

            override fun onPlaybackStateChanged(playbackState: Int) {
                if (playbackState == Player.STATE_ENDED) {
                    player.pause()
                    player.seekTo(0)
                }
                publish()
            }
        })
    }

    fun play(uri: Uri) {
        if (current.value.uri != uri) {
            player.setMediaItem(MediaItem.fromUri(uri))
            player.prepare()
            current.value = current.value.copy(uri = uri, positionMs = 0, durationMs = null)
        }
        player.play()
    }

    fun pause() = player.pause()

    fun seekTo(positionMs: Long) {
        player.seekTo(positionMs)
        publish()
    }

    fun release() {
        scope.cancel()
        player.release()
    }

    private fun startTicker() {
        ticker?.cancel()
        ticker = scope.launch {
            while (isActive) {
                publish()
                delay(progressIntervalMs)
            }
        }
    }

    private fun publish() {
        val duration = player.duration.takeIf { it >= 0 }
        current.value = current.value.copy(isPlaying = player.isPlaying, positionMs = player.currentPosition, durationMs = duration)
    }
}

object VoiceDurations {
    /** Duration of an audio file in ms, or null when it cannot be read. */
    fun of(file: File): Long? {
        val retriever = MediaMetadataRetriever()
        return try {
            retriever.setDataSource(file.absolutePath)
            retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)?.toLongOrNull()
        } catch (_: RuntimeException) {
            null
        } finally {
            retriever.release()
        }
    }
}

/** Where recordings and drafts live until they are sent or discarded (emptied when a session ends). */
fun voiceCacheDirectory(context: Context): File = File(context.cacheDir, "voice")
