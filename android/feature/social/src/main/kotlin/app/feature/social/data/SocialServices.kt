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
import app.voice.VoiceLevels
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

/** A finished recording ready to send, with its waveform (100 levels of 0…31, C-36; null when none). */
data class RecordedVoice(val file: File, val durationMs: Int, val levels: List<Int>? = null)

/** What plays now: [key] = the voice path of the playing message (null = nothing); [progress] 0…1 of it. */
data class VoicePlayback(val key: String?, val isPlaying: Boolean, val progress: Float = 0f)

/**
 * Voice messages: record (core:voice `VoiceRecorder`: start, pause, continue, a playable draft, stop) and play (core:voice
 * `VoicePlayer`). The paused draft plays under [DRAFT_KEY] (`chat.voice.layout.locked` preview).
 */
interface VoiceServices {
    /** The running recording's waveform so far (100 levels of 0…31, C-36). */
    val levels: StateFlow<List<Int>>

    /** The running recording's length so far, in ms. */
    val elapsedMs: StateFlow<Long>
    val playback: StateFlow<VoicePlayback>

    /** Starts recording (RECORD_AUDIO granted). Throws when the recorder cannot start. */
    fun startRecording()

    /** Recording → paused (`chat.voice.a11y.pauseRecording`). */
    fun pauseRecording()

    /** Paused → recording at the end of the draft (`chat.voice.a11y.resumeRecording`). Throws when it cannot continue. */
    fun resumeRecording()

    /** Paused: plays / pauses the draft from its start (playback key [DRAFT_KEY]). */
    suspend fun toggleDraftPreview()

    /** Stops and returns the recording (segments joined), or null when nothing usable was recorded. */
    suspend fun stopRecording(): RecordedVoice?
    fun cancelRecording()

    /** Plays [url] for the message whose voice path is [key]; only one plays at a time. */
    fun play(key: String, url: String)
    fun pause()

    /**
     * `chat.voice.layout.scrub`: moves the note [key] (playing or paused part-way) to [fraction] (0…1) of its length; a
     * playing note plays on from there, a paused one stays paused. Any other key: nothing.
     */
    fun seek(key: String, fraction: Float)

    /**
     * The waveform of the audio file [key] (its storage path) at [url] for a note stored without one (C-36 fallback):
     * 100 levels of 0…31, or null when it cannot be decoded. Computed once per file and kept.
     */
    suspend fun levels(key: String, url: String): List<Int>?
    fun release()

    companion object {
        /** The playback key of the paused draft's preview. */
        const val DRAFT_KEY = "voice-draft"
    }
}

/** Saves an original to the photo library. */
interface GallerySaver {
    /** API 26–28 need WRITE_EXTERNAL_STORAGE; 29+ need nothing (MediaStore insert). */
    fun needsPermission(context: Context): Boolean

    /** Inserts [bytes] ([mimeType]: an image or video type) into the library; false when it failed. */
    suspend fun save(context: Context, bytes: ByteArray, mimeType: String, extension: String): Boolean
}

/** The services the screens use; tests replace them. */
class SocialServices(val voice: (Context) -> VoiceServices, val gallery: GallerySaver) {
    companion object {
        val Default = SocialServices(voice = ::PlatformVoiceServices, gallery = MediaStoreGallerySaver)
    }
}

/**
 * core:voice-backed [VoiceServices]. The recorder samples the input level every 30 ms (the live and draft waveforms);
 * the player's progress ticks move the played / unplayed split (`layout.global.waveform.progress`), at least once per
 * bar of a short message.
 */
class PlatformVoiceServices(private val context: Context) : VoiceServices {
    private val recorder = VoiceRecorder(context)
    private val player = VoicePlayer(context, progressIntervalMs = PLAYER_TICK_MS)
    private val state = MutableStateFlow(VoicePlayback(null, false))
    private var playingKey: String? = null
    private var draftUri: String? = null
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)

    init {
        scope.launch {
            player.state.collect { s ->
                val duration = s.durationMs?.takeIf { it > 0 }
                state.value = VoicePlayback(playingKey, s.isPlaying, if (duration != null) (s.positionMs.toFloat() / duration).coerceIn(0f, 1f) else 0f)
            }
        }
    }

    override val levels: StateFlow<List<Int>> get() = recorder.levels
    override val elapsedMs: StateFlow<Long> get() = recorder.elapsedMs
    override val playback: StateFlow<VoicePlayback> = state.asStateFlow()

    override fun startRecording() {
        stopPlayback()
        recorder.start()
    }

    override fun pauseRecording() = recorder.pause()

    override fun resumeRecording() {
        stopDraft()
        recorder.resume()
    }

    override suspend fun toggleDraftPreview() {
        if (playingKey == VoiceServices.DRAFT_KEY && state.value.isPlaying) {
            pause()
            return
        }
        val uri = draftUri ?: Uri.fromFile(recorder.draftFile()).toString().also { draftUri = it }
        play(VoiceServices.DRAFT_KEY, uri)
    }

    override suspend fun stopRecording(): RecordedVoice? {
        stopDraft()
        return recorder.finish()?.let { note ->
            if (note.durationMs <= 0) null else RecordedVoice(note.file, note.durationMs.toInt(), note.levels.takeIf(VoiceLevels::isValid))
        }
    }

    override fun cancelRecording() {
        stopDraft()
        recorder.cancel()
    }

    override fun play(key: String, url: String) {
        playingKey = key
        player.play(Uri.parse(url))
        state.value = VoicePlayback(key, true)
    }

    override fun pause() {
        player.pause()
        state.value = VoicePlayback(playingKey, false, state.value.progress)
    }

    override fun seek(key: String, fraction: Float) {
        if (key != playingKey) return
        val duration = player.state.value.durationMs?.takeIf { it > 0 } ?: return
        player.seekTo((fraction.coerceIn(0f, 1f) * duration).toLong())
    }

    override suspend fun levels(key: String, url: String): List<Int>? = AudioLevels.cached(key, url)

    override fun release() {
        scope.cancel()
        recorder.release()
        player.release()
    }

    private fun stopPlayback() {
        if (state.value.isPlaying) player.pause()
        playingKey = null
        state.value = VoicePlayback(null, false)
    }

    /** The draft changes (continue, send, delete): its preview stops and its file is made again next time. */
    private fun stopDraft() {
        draftUri = null
        if (playingKey == VoiceServices.DRAFT_KEY) stopPlayback()
    }

    private companion object {
        const val PLAYER_TICK_MS = 50L
    }
}

/**
 * The waveform of a voice note stored without levels (C-36 fallback, Telegram Desktop's `countVoiceWaveform`): decodes
 * the AAC track to 16-bit PCM, takes the peak of every [VoiceLevels.SAMPLING_INTERVAL_MS] and reduces it like a
 * recording ([VoiceLevels.reduce]).
 */
object AudioLevels {
    private val cache = object : LinkedHashMap<String, List<Int>>(16, 0.75f, true) {
        override fun removeEldestEntry(eldest: MutableMap.MutableEntry<String, List<Int>>?): Boolean = size > CACHE_ENTRIES
    }

    /** From memory when this file was decoded before (keyed by storage path). */
    suspend fun cached(key: String, url: String): List<Int>? {
        synchronized(cache) { cache[key] }?.let { return it }
        return decode(url)?.also { synchronized(cache) { cache[key] = it } }
    }

    fun peek(key: String): List<Int>? = synchronized(cache) { cache[key] }

    suspend fun decode(url: String): List<Int>? = withContext(Dispatchers.IO) {
        runCatching { decodeBlocking(url) }.getOrNull()
    }

    private fun decodeBlocking(url: String): List<Int>? {
        val extractor = MediaExtractor()
        try {
            extractor.setDataSource(url)
            val track = (0 until extractor.trackCount).firstOrNull { extractor.getTrackFormat(it).getString(MediaFormat.KEY_MIME)?.startsWith("audio/") == true } ?: return null
            extractor.selectTrack(track)
            val format = extractor.getTrackFormat(track)
            val rate = if (format.containsKey(MediaFormat.KEY_SAMPLE_RATE)) format.getInteger(MediaFormat.KEY_SAMPLE_RATE) else DEFAULT_RATE
            val channels = if (format.containsKey(MediaFormat.KEY_CHANNEL_COUNT)) format.getInteger(MediaFormat.KEY_CHANNEL_COUNT) else 1
            val window = max(1L, rate * channels * VoiceLevels.SAMPLING_INTERVAL_MS / 1000).toInt()
            val codec = MediaCodec.createDecoderByType(format.getString(MediaFormat.KEY_MIME)!!)
            val peaks = ArrayList<Float>()
            var peak = 0
            var count = 0
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
                        while (out.hasRemaining()) {
                            peak = max(peak, abs(out.get().toInt()))
                            if (++count >= window) {
                                peaks += VoiceLevels.level(peak)
                                peak = 0
                                count = 0
                            }
                        }
                        codec.releaseOutputBuffer(outIndex, false)
                        if (info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) outputDone = true
                    }
                }
            } finally {
                runCatching { codec.stop() }
                codec.release()
            }
            if (count > 0) peaks += VoiceLevels.level(peak)
            return if (peaks.isEmpty()) null else VoiceLevels.reduce(peaks)
        } finally {
            extractor.release()
        }
    }

    private const val TIMEOUT_US = 10_000L
    private const val CACHE_ENTRIES = 256
    private const val DEFAULT_RATE = 44_100
}

/** MediaStore insert into Pictures (photo.viewer → Save; Android saves the still, PLATFORM_CONSTRAINTS §Summary). */
object MediaStoreGallerySaver : GallerySaver {
    override fun needsPermission(context: Context): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.Q &&
            context.checkSelfPermission(android.Manifest.permission.WRITE_EXTERNAL_STORAGE) != android.content.pm.PackageManager.PERMISSION_GRANTED

    override suspend fun save(context: Context, bytes: ByteArray, mimeType: String, extension: String): Boolean = withContext(Dispatchers.IO) {
        val resolver = context.contentResolver
        val video = mimeType.startsWith("video/")
        val values = ContentValues().apply {
            put(MediaStore.MediaColumns.DISPLAY_NAME, "${UUID.randomUUID()}.$extension")
            put(MediaStore.MediaColumns.MIME_TYPE, mimeType)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                put(MediaStore.MediaColumns.RELATIVE_PATH, if (video) Environment.DIRECTORY_MOVIES else Environment.DIRECTORY_PICTURES)
                put(MediaStore.MediaColumns.IS_PENDING, 1)
            }
        }
        val collection = if (video) MediaStore.Video.Media.EXTERNAL_CONTENT_URI else MediaStore.Images.Media.EXTERNAL_CONTENT_URI
        val uri = resolver.insert(collection, values) ?: return@withContext false
        val ok = runCatching { resolver.openOutputStream(uri)?.use { it.write(bytes) } != null }.getOrDefault(false)
        if (!ok) {
            resolver.delete(uri, null, null)
            return@withContext false
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            resolver.update(uri, ContentValues().apply { put(MediaStore.MediaColumns.IS_PENDING, 0) }, null, null)
        }
        true
    }
}
