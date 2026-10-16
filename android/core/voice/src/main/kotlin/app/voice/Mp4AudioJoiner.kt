package app.voice

import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMuxer
import java.io.File
import java.nio.ByteBuffer

/**
 * Joins recording segments (AAC in MPEG-4, one audio track each, the same encoder settings) into one `.m4a` without
 * re-encoding: `MediaExtractor` reads each segment's samples, `MediaMuxer` writes them one after the other.
 */
object Mp4AudioJoiner {
    fun join(segments: List<File>, out: File) {
        require(segments.isNotEmpty()) { "nothing to join" }
        out.parentFile?.mkdirs()
        out.delete()
        val muxer = MediaMuxer(out.absolutePath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
        val buffer = ByteBuffer.allocate(BUFFER_BYTES)
        val info = MediaCodec.BufferInfo()
        var track = -1
        var offsetUs = 0L
        try {
            for (segment in segments) {
                val extractor = MediaExtractor()
                try {
                    extractor.setDataSource(segment.absolutePath)
                    val index = (0 until extractor.trackCount).firstOrNull {
                        extractor.getTrackFormat(it).getString(MediaFormat.KEY_MIME)?.startsWith("audio/") == true
                    } ?: continue
                    extractor.selectTrack(index)
                    val format = extractor.getTrackFormat(index)
                    if (track < 0) {
                        track = muxer.addTrack(format)
                        muxer.start()
                    }
                    val rate = if (format.containsKey(MediaFormat.KEY_SAMPLE_RATE)) format.getInteger(MediaFormat.KEY_SAMPLE_RATE) else DEFAULT_RATE
                    val frameUs = AAC_FRAME_SAMPLES * 1_000_000L / rate
                    var lastUs = -1L
                    while (true) {
                        val size = extractor.readSampleData(buffer, 0)
                        if (size < 0) break
                        lastUs = extractor.sampleTime
                        val flags = if (extractor.sampleFlags and MediaExtractor.SAMPLE_FLAG_SYNC != 0) MediaCodec.BUFFER_FLAG_KEY_FRAME else 0
                        info.set(0, size, offsetUs + lastUs, flags)
                        muxer.writeSampleData(track, buffer, info)
                        extractor.advance()
                    }
                    if (lastUs >= 0) offsetUs += lastUs + frameUs
                } finally {
                    extractor.release()
                }
            }
            check(track >= 0) { "no audio in the segments" }
        } finally {
            if (track >= 0) runCatching { muxer.stop() }
            muxer.release()
        }
    }

    private const val BUFFER_BYTES = 256 * 1024
    private const val AAC_FRAME_SAMPLES = 1024L
    private const val DEFAULT_RATE = 44_100
}
