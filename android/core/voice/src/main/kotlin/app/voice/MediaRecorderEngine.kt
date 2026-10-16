package app.voice

import android.content.Context
import android.media.MediaRecorder
import android.os.Build
import java.io.File

/**
 * [RecordingEngine] on `MediaRecorder`: AAC in MPEG-4 (`.m4a`), mono, speech-oriented transport settings (not design
 * values). Pause / continue use `MediaRecorder.pause()` / `resume()` (API 24; minSdk 26); the level is
 * `getMaxAmplitude()` (the peak since the previous call).
 */
class MediaRecorderEngine(
    private val context: Context,
    private val clock: () -> Long,
    private val newRecorder: (Context) -> MediaRecorder = ::platformRecorder,
) : RecordingEngine {
    private var recorder: MediaRecorder? = null
    private var file: File? = null
    private var startedAt = 0L
    private var pausedAt: Long? = null
    private var pausedTotal = 0L

    override fun startSegment(file: File) {
        file.parentFile?.mkdirs()
        val r = newRecorder(context)
        try {
            r.setAudioSource(MediaRecorder.AudioSource.MIC)
            r.setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
            r.setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
            r.setAudioChannels(CHANNELS)
            r.setAudioSamplingRate(SAMPLE_RATE_HZ)
            r.setAudioEncodingBitRate(BIT_RATE)
            r.setOutputFile(file.absolutePath)
            r.prepare()
            r.start()
        } catch (e: Exception) {
            r.release()
            file.delete()
            throw e
        }
        recorder = r
        this.file = file
        startedAt = clock()
        pausedAt = null
        pausedTotal = 0L
    }

    override fun pauseSegment() {
        val r = recorder ?: return
        if (pausedAt != null) return
        runCatching { r.pause() }
        pausedAt = clock()
    }

    override fun resumeSegment(): Boolean {
        val r = recorder ?: return false
        val since = pausedAt ?: return true
        if (runCatching { r.resume() }.isFailure) return false
        pausedTotal += clock() - since
        pausedAt = null
        return true
    }

    override fun stopSegment(): Long? {
        val r = recorder ?: return null
        val out = file
        val ms = segmentTimeMs
        val ok = runCatching { r.stop() }.isSuccess
        r.release()
        recorder = null
        file = null
        pausedAt = null
        if (!ok) {
            out?.delete()
            return null
        }
        return ms
    }

    override val segmentTimeMs: Long
        get() = if (recorder == null) 0L else ((pausedAt ?: clock()) - startedAt - pausedTotal).coerceAtLeast(0L)

    override fun samplePeak(): Float = VoiceLevels.level(runCatching { recorder?.maxAmplitude ?: 0 }.getOrDefault(0))

    override fun deleteFile(file: File) {
        file.delete()
    }

    private companion object {
        const val CHANNELS = 1
        const val SAMPLE_RATE_HZ = 44_100
        const val BIT_RATE = 64_000

        fun platformRecorder(context: Context): MediaRecorder =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) MediaRecorder(context) else @Suppress("DEPRECATION") MediaRecorder()
    }
}
