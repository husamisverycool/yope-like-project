package app.feature.social.data

import android.content.ContentValues
import android.content.Context
import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import app.voice.VoicePlayer
import app.voice.VoiceRecorder
import app.voice.Waveform
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.withContext
import java.io.File
import java.nio.ByteOrder
import java.util.UUID
import kotlin.math.abs
import kotlin.math.max

/** A finished recording ready to send. */
data class RecordedVoice(val file: File, val durationMs: Int)

/** What plays now: [key] = the voice path of the playing message (null = nothing). */
data class VoicePlayback(val key: String?, val isPlaying: Boolean)

/** Voice messages: record (core:voice `VoiceRecorder`) and play (core:voice `VoicePlayer`). */
interface VoiceServices {
    /** Live input levels (0…1) of the running recording. */
    val levels: StateFlow<List<Float>>
    val playback: StateFlow<VoicePlayback>

    /** Starts recording (RECORD_AUDIO granted). Throws when the recorder cannot start. */
    fun startRecording()
    fun stopRecording(): RecordedVoice?
    fun cancelRecording()

    /** Plays [url] for the message whose voice path is [key]; only one plays at a time. */
    fun play(key: String, url: String)
    fun pause()

    /** The level envelope of an audio file at [url], as [bars] bars (0…1), or null when it cannot be decoded. */
    suspend fun envelope(url: String, bars: Int): List<Float>?
    fun release()
}

/** Saves an original to the photo library. */
interface GallerySaver {
    /** API 26–28 need WRITE_EXTERNAL_STORAGE; 29+ need nothing (MediaStore insert). */
    fun needsPermission(context: Context): Boolean
    suspend fun saveJpeg(context: Context, bytes: ByteArray): Boolean
}

/** The services the screens use; tests replace them. */
class SocialServices(val voice: (Context) -> VoiceServices, val gallery: GallerySaver) {
    companion object {
        val Default = SocialServices(voice = ::PlatformVoiceServices, gallery = MediaStoreGallerySaver)
    }
}

/**
 * core:voice-backed [VoiceServices]. The recorder samples the input level for the waveform; the
 * player's progress ticks are not displayed (the playing state's visuals are BLOCKED,
 * design/surfaces/chat.voice.md), so its interval only paces state updates.
 */
class PlatformVoiceServices(private val context: Context) : VoiceServices {
    private val recorder = VoiceRecorder(context)
    private val player = VoicePlayer(context, progressIntervalMs = PLAYER_TICK_MS)
    private val state = MutableStateFlow(VoicePlayback(null, false))
    private var playingKey: String? = null
    private var recording: File? = null
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)

    init {
        scope.launch { player.state.collect { s -> state.value = VoicePlayback(playingKey, s.isPlaying) } }
    }

    override val levels: StateFlow<List<Float>> get() = recorder.levels
    override val playback: StateFlow<VoicePlayback> = state.asStateFlow()

    override fun startRecording() {
        val file = File(context.cacheDir, "voice/${UUID.randomUUID()}.m4a")
        recording = file
        recorder.start(file, samplingIntervalMs = LEVEL_SAMPLE_MS)
    }

    override fun stopRecording(): RecordedVoice? = recorder.stop()?.let { note ->
        recording = null
        if (note.durationMs <= 0) null else RecordedVoice(note.file, note.durationMs.toInt())
    }

    override fun cancelRecording() {
        recorder.cancel()
        recording = null
    }

    override fun play(key: String, url: String) {
        playingKey = key
        player.play(Uri.parse(url))
        state.value = VoicePlayback(key, true)
    }

    override fun pause() {
        player.pause()
        state.value = VoicePlayback(playingKey, false)
    }

    override suspend fun envelope(url: String, bars: Int): List<Float>? = AudioEnvelope.decode(url, bars)

    override fun release() {
        scope.cancel()
        recorder.release()
        player.release()
    }

    private companion object {
        /** Level sampling of the recorder (waveform resolution before it is resampled to the bar count). */
        const val LEVEL_SAMPLE_MS = 50L
        const val PLAYER_TICK_MS = 250L
    }
}

/**
 * Computes a voice message's level envelope on the receiving device (the API stores none,
 * design/surfaces/chat.voice.md → Platform notes): decodes the AAC track to 16-bit PCM and keeps
 * the peak per bar.
 */
object AudioEnvelope {
    suspend fun decode(url: String, bars: Int): List<Float>? = withContext(Dispatchers.IO) {
        runCatching { decodeBlocking(url, bars) }.getOrNull()
    }

    private fun decodeBlocking(url: String, bars: Int): List<Float>? {
        val extractor = MediaExtractor()
        try {
            extractor.setDataSource(url)
            val track = (0 until extractor.trackCount).firstOrNull { extractor.getTrackFormat(it).getString(MediaFormat.KEY_MIME)?.startsWith("audio/") == true } ?: return null
            extractor.selectTrack(track)
            val format = extractor.getTrackFormat(track)
            val codec = MediaCodec.createDecoderByType(format.getString(MediaFormat.KEY_MIME)!!)
            val peaks = ArrayList<Float>()
            try {
                codec.configure(format, null, null, 0)
                codec.start()
                val info = MediaCodec.BufferInfo()
                var inputDone = false
                var outputDone = false
                while (!outputDone) {
                    if (!inputDone) {
                        val inIndex = codec.dequeueInputBuffer(TIMEOUT_US)
                        if (inIndex >= 0) {
                            val buffer = codec.getInputBuffer(inIndex)!!
                            val size = extractor.readSampleData(buffer, 0)
                            if (size < 0) {
                                codec.queueInputBuffer(inIndex, 0, 0, 0, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
                                inputDone = true
                            } else {
                                codec.queueInputBuffer(inIndex, 0, size, extractor.sampleTime, 0)
                                extractor.advance()
                            }
                        }
                    }
                    val outIndex = codec.dequeueOutputBuffer(info, TIMEOUT_US)
                    if (outIndex >= 0) {
                        val out = codec.getOutputBuffer(outIndex)!!.order(ByteOrder.LITTLE_ENDIAN).asShortBuffer()
                        var peak = 0
                        while (out.hasRemaining()) peak = max(peak, abs(out.get().toInt()))
                        peaks += Waveform.level(peak)
                        codec.releaseOutputBuffer(outIndex, false)
                        if (info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) outputDone = true
                    }
                }
            } finally {
                runCatching { codec.stop() }
                codec.release()
            }
            return if (peaks.isEmpty()) null else Waveform.bars(peaks, bars)
        } finally {
            extractor.release()
        }
    }

    private const val TIMEOUT_US = 10_000L
}

/** MediaStore insert into Pictures (photo.viewer → Save; Android saves the still, PLATFORM_CONSTRAINTS §Summary). */
object MediaStoreGallerySaver : GallerySaver {
    override fun needsPermission(context: Context): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.Q &&
            context.checkSelfPermission(android.Manifest.permission.WRITE_EXTERNAL_STORAGE) != android.content.pm.PackageManager.PERMISSION_GRANTED

    override suspend fun saveJpeg(context: Context, bytes: ByteArray): Boolean = withContext(Dispatchers.IO) {
        val resolver = context.contentResolver
        val values = ContentValues().apply {
            put(MediaStore.Images.Media.DISPLAY_NAME, "${UUID.randomUUID()}.jpg")
            put(MediaStore.Images.Media.MIME_TYPE, "image/jpeg")
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                put(MediaStore.Images.Media.RELATIVE_PATH, Environment.DIRECTORY_PICTURES)
                put(MediaStore.Images.Media.IS_PENDING, 1)
            }
        }
        val uri = resolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values) ?: return@withContext false
        val ok = runCatching { resolver.openOutputStream(uri)?.use { it.write(bytes) } != null }.getOrDefault(false)
        if (!ok) {
            resolver.delete(uri, null, null)
            return@withContext false
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            resolver.update(uri, ContentValues().apply { put(MediaStore.Images.Media.IS_PENDING, 0) }, null, null)
        }
        true
    }
}
