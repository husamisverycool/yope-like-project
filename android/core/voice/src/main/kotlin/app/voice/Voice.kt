package app.voice

import android.content.Context
import android.media.MediaMetadataRetriever
import android.media.MediaRecorder
import android.net.Uri
import android.os.Build
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
import java.io.File
import kotlin.math.max

/** A finished recording. */
data class VoiceNote(val file: File, val durationMs: Long, val waveform: List<Float>)

/** Waveform math: raw MediaRecorder amplitudes → 0…1 levels → a fixed number of bars. */
object Waveform {
    /** [MediaRecorder.getMaxAmplitude] is a 16-bit PCM peak. */
    const val MAX_AMPLITUDE = 32767

    fun level(amplitude: Int): Float = (amplitude.coerceIn(0, MAX_AMPLITUDE).toFloat() / MAX_AMPLITUDE)

    /** Resamples [levels] into [count] bars (peak per bucket), so any length draws in a fixed width. */
    fun bars(levels: List<Float>, count: Int): List<Float> {
        require(count > 0)
        if (levels.isEmpty()) return List(count) { 0f }
        return List(count) { i ->
            val start = i * levels.size / count
            val end = max(start + 1, (i + 1) * levels.size / count)
            levels.subList(start, end.coerceAtMost(levels.size)).max()
        }
    }
}

/**
 * Records AAC audio into an `.m4a` file, sampling the input level for the live waveform.
 * Encoding settings are speech-oriented transport choices, not design values.
 */
class VoiceRecorder(
    private val context: Context,
    private val clock: () -> Long = SystemClock::elapsedRealtime,
    private val newRecorder: (Context) -> MediaRecorder = ::platformRecorder,
) {
    private var recorder: MediaRecorder? = null
    private var file: File? = null
    private var startedAt = 0L
    private var sampling: Job? = null
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    private val samples = MutableStateFlow<List<Float>>(emptyList())

    /** Levels (0…1) sampled so far in this recording. */
    val levels: StateFlow<List<Float>> = samples.asStateFlow()

    val isRecording: Boolean get() = recorder != null

    /**
     * Starts recording into [output]. Requires RECORD_AUDIO. [samplingIntervalMs] sets how often the
     * level is read (the waveform's resolution); [maxDurationMs] stops recording automatically.
     */
    fun start(output: File, samplingIntervalMs: Long, maxDurationMs: Int? = null) {
        check(recorder == null) { "already recording" }
        require(samplingIntervalMs > 0)
        output.parentFile?.mkdirs()
        val r = newRecorder(context).apply {
            setAudioSource(MediaRecorder.AudioSource.MIC)
            setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
            setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
            setAudioChannels(CHANNELS)
            setAudioSamplingRate(SAMPLE_RATE_HZ)
            setAudioEncodingBitRate(BIT_RATE)
            maxDurationMs?.let(::setMaxDuration)
            setOutputFile(output.absolutePath)
            prepare()
            start()
        }
        recorder = r
        file = output
        startedAt = clock()
        samples.value = emptyList()
        sampling = scope.launch {
            while (isActive) {
                samples.value = samples.value + Waveform.level(runCatching { r.maxAmplitude }.getOrDefault(0))
                delay(samplingIntervalMs)
            }
        }
    }

    /** Stops and returns the note, or null when it was too short for the encoder to finalize. */
    fun stop(): VoiceNote? {
        val r = recorder ?: return null
        val out = file ?: return null
        sampling?.cancel()
        val duration = clock() - startedAt
        val ok = runCatching { r.stop() }.isSuccess
        r.release()
        recorder = null
        file = null
        if (!ok) {
            out.delete()
            return null
        }
        return VoiceNote(out, duration, samples.value)
    }

    fun cancel() {
        val out = file
        sampling?.cancel()
        recorder?.let { runCatching { it.stop() }; it.release() }
        recorder = null
        file = null
        out?.delete()
        samples.value = emptyList()
    }

    fun release() {
        cancel()
        scope.cancel()
    }

    private companion object {
        const val CHANNELS = 1
        const val SAMPLE_RATE_HZ = 44_100
        const val BIT_RATE = 64_000

        fun platformRecorder(context: Context): MediaRecorder =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) MediaRecorder(context) else @Suppress("DEPRECATION") MediaRecorder()
    }
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
