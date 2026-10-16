package app.voice

import java.io.File

/**
 * What a voice recording drives: [MediaRecorderEngine] in the app, fakes in tests. A recording is one or more
 * **segments** (files): pausing uses the platform pause and keeps the segment open; a paused draft that is previewed
 * must be a finished file, so the preview closes the open segment and continuing starts a new one
 * (design/surfaces/chat.voice.md → Platform notes; owner decision 16).
 */
interface RecordingEngine {
    /** Starts recording a new segment into [file]; throws when the recorder cannot start. */
    fun startSegment(file: File)

    /** Pauses the open segment (`MediaRecorder.pause()`). */
    fun pauseSegment()

    /** Continues the open, paused segment (`MediaRecorder.resume()`); false when the platform refused. */
    fun resumeSegment(): Boolean

    /** Stops the open segment and finishes its file: its length in ms, or null when the file is unusable (deleted). */
    fun stopSegment(): Long?

    /** The open segment's recorded length so far, in ms (0 when none). */
    val segmentTimeMs: Long

    /** The input's peak level (0…1, linear) since the previous call. */
    fun samplePeak(): Float

    /** Removes a segment file. */
    fun deleteFile(file: File)
}

/**
 * One voice recording: start, pause, continue, finish the draft for a preview, finish or cancel (WhatsApp's locked
 * recording: "tap [pause] to pause recording and preview a draft … Tap [mic] to continue recording"). Samples the peak
 * level while recording (none while paused) for the waveform ([VoiceLevels]).
 */
class RecordingSession(private val engine: RecordingEngine, private val newFile: () -> File) {
    enum class State { Idle, Recording, Paused }

    /** A finished recording: its segment files in order, length and the 100 stored levels. */
    data class Result(val segments: List<File>, val durationMs: Long, val levels: List<Int>)

    var state: State = State.Idle
        private set

    private val samples = ArrayList<Float>()

    /** Peak levels sampled so far (0…1). */
    val peaks: List<Float> get() = samples.toList()

    private val finished = ArrayList<Pair<File, Long>>()
    private var open: File? = null

    /** Recorded length so far: the finished segments plus the open one. */
    val elapsedMs: Long get() = finished.sumOf { it.second } + (if (open != null) engine.segmentTimeMs else 0L)

    /** The stored-format levels of what was recorded so far (the live and draft waveforms). */
    val levels: List<Int> get() = VoiceLevels.reduce(samples)

    /** Segment files that are finished (a preview can play them). */
    val finishedSegments: List<File> get() = finished.map { it.first }

    /** Idle → recording. */
    fun start() {
        check(state == State.Idle) { "not idle" }
        val file = newFile()
        engine.startSegment(file)
        open = file
        samples.clear()
        finished.clear()
        state = State.Recording
    }

    /** Reads one level sample (every [VoiceLevels.SAMPLING_INTERVAL_MS] while recording; ignored otherwise). */
    fun sample() {
        if (state == State.Recording) samples += engine.samplePeak()
    }

    /** Recording → paused (the open segment pauses). */
    fun pause() {
        check(state == State.Recording) { "not recording" }
        engine.pauseSegment()
        state = State.Paused
    }

    /** Paused → recording: the open segment continues; after a preview closed it (or the platform refused), a new one starts. */
    fun resume() {
        check(state == State.Paused) { "not paused" }
        if (open != null && engine.resumeSegment()) {
            state = State.Recording
            return
        }
        closeOpenSegment()
        val file = newFile()
        engine.startSegment(file)
        open = file
        state = State.Recording
    }

    /** A paused draft's finished files, for a preview: closes the open segment first. */
    fun finishDraft(): List<File> {
        check(state == State.Paused) { "not paused" }
        closeOpenSegment()
        return finishedSegments
    }

    /** Recording / paused → idle: closes the open segment and returns the recording. */
    fun finish(): Result {
        check(state != State.Idle) { "not recording" }
        closeOpenSegment()
        val result = Result(finishedSegments, elapsedMs, levels)
        reset()
        return result
    }

    /** Any state → idle: deletes every segment file. */
    fun cancel() {
        if (state == State.Idle) return
        open?.let { engine.stopSegment() }
        (finished.map { it.first } + listOfNotNull(open)).forEach(engine::deleteFile)
        reset()
    }

    private fun closeOpenSegment() {
        val file = open ?: return
        val ms = engine.stopSegment()
        if (ms != null) finished += file to ms
        open = null
    }

    private fun reset() {
        open = null
        finished.clear()
        samples.clear()
        state = State.Idle
    }
}
