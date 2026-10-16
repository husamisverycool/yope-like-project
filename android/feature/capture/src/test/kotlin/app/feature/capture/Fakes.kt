package app.feature.capture

import androidx.camera.core.SurfaceRequest
import app.data.error.DataError
import app.data.error.DataException
import app.data.media.upload.NewPost
import app.data.media.upload.UploadProgress
import app.data.model.Collage
import app.data.model.DailyInvitation
import app.data.model.Group
import app.data.model.GroupKind
import app.data.model.InvitationStatus
import app.data.model.RenderStatus
import app.data.offline.DataState
import app.data.repo.Member
import app.feature.capture.camera.CameraController
import app.feature.capture.camera.VideoRecording
import app.feature.capture.camera.VideoStartResult
import app.feature.capture.data.CaptureData
import app.feature.capture.data.NewestForWidget
import app.media.DualCaptureMode
import app.media.Lens
import app.testing.SamplePhotos
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import java.io.File
import java.time.Instant
import java.time.LocalDate

val T0: Instant = Instant.parse("2026-10-15T12:00:00Z")

fun group(id: String, name: String, cover: String? = null) = Group(
    id = id, name = name, kind = GroupKind.Friends, coverPath = cover, timeZone = "UTC",
    wakingStart = null, wakingEnd = null, invitationPaused = false, createdBy = null, createdAt = T0, updatedAt = T0,
)

fun invitation(id: String = "inv1", groupId: String = "g1", firesAt: Instant = T0, closesAt: Instant = T0.plusSeconds(120)) = DailyInvitation(
    id = id, groupId = groupId, localDate = LocalDate.of(2026, 5, 26), firesAt = firesAt, closesAt = closesAt,
    status = InvitationStatus.Fired, createdAt = T0,
)

fun collage(
    id: String = "c1",
    status: RenderStatus = RenderStatus.Ready,
    pages: Int = 1,
    share: Boolean = true,
    folder: String = "g/g1/collages/c1/v1",
) = Collage(
    id = id, groupId = "g1", invitationId = "inv1", option = "B", postIds = listOf("p1"),
    imagePath = if (status == RenderStatus.Ready) "$folder/display-1.jpg" else null,
    widgetPath = "$folder/widget.jpg", sharePath = if (share && status == RenderStatus.Ready) "$folder/share-1.jpg" else null,
    status = status, composedAt = T0, createdAt = T0, pageCount = pages,
)

/** A [CaptureData] whose answers the test sets. */
class FakeCaptureData : CaptureData {
    val groupsFlow = MutableStateFlow(DataState<List<Group>>(null, DataState.Source.None, null, refreshing = true, error = null))
    var premium = false
    val enqueued = mutableListOf<NewPost>()
    var enqueueError: DataError? = null
    val progressFlows = mutableMapOf<String, MutableStateFlow<UploadProgress>>()
    val onlineFlow = MutableStateFlow(true)
    var invitation: DailyInvitation? = null
    var groupById = mutableMapOf<String, Group>()
    var collage: Collage? = null
    var collageError: DataError? = null
    var newest: NewestForWidget? = null
    var members: List<Member> = emptyList()
    val downloads = mutableListOf<String>()
    var downloadError: DataError? = null
    val retried = mutableListOf<String>()

    fun loaded(vararg groups: Group, source: DataState.Source = DataState.Source.Network, refreshing: Boolean = false) {
        groupsFlow.value = DataState(groups.toList(), source, T0, refreshing = refreshing, error = null)
    }

    override fun groups(): Flow<DataState<List<Group>>> = groupsFlow
    override suspend fun signedUrls(paths: Collection<String>): Map<String, String> = paths.associateWith { "https://storage.example/$it" }
    override suspend fun isPremium(): Boolean = premium
    override fun enqueue(post: NewPost): String {
        enqueueError?.let { throw DataException(it) }
        enqueued += post
        val id = "draft${enqueued.size}"
        progressFlows[id] = MutableStateFlow(UploadProgress.Queued)
        return id
    }
    override fun progress(draftId: String): Flow<UploadProgress> = progressFlows.getOrPut(draftId) { MutableStateFlow(UploadProgress.Queued) }
    override fun retry(draftId: String) {
        retried += draftId
        // The real queue re-submits the work: the draft is queued again.
        progressFlows[draftId]?.value = UploadProgress.Queued
    }
    val discarded = mutableListOf<String>()
    override fun discardDraft(draftId: String) {
        discarded += draftId
    }
    override val online: Flow<Boolean> get() = onlineFlow
    override suspend fun invitation(invitationId: String): DailyInvitation? = invitation
    override suspend fun group(groupId: String): Group? = groupById[groupId]
    override suspend fun collageForInvitation(invitationId: String): Collage? {
        collageError?.let { throw DataException(it) }
        return collage
    }
    /** The first photo's display path (collage backdrop); null = the post is gone. */
    var firstPhotoPath: String? = "u/u1/m1/display.jpg"
    override suspend fun collageFirstPhotoPath(collage: Collage): String? = firstPhotoPath
    override suspend fun newestForWidget(groupId: String): NewestForWidget? = newest
    override suspend fun members(groupId: String): List<Member> = members
    var myName: String? = "Ana"
    override suspend fun myFirstName(): String? = myName

    override suspend fun download(url: String, target: File) {
        downloadError?.let { throw DataException(it) }
        downloads += url
        target.parentFile?.mkdirs()
        target.writeBytes(Images.jpeg())
    }
}

/** A camera without hardware: writes small JPEGs, records "videos" as files. */
class FakeCameraController(
    var mode: DualCaptureMode = DualCaptureMode.Concurrent,
    var frontFails: Boolean = false,
    var bindFails: Boolean = false,
    hasFlash: Boolean = true,
) : CameraController {
    override val preview: StateFlow<SurfaceRequest?> = MutableStateFlow(null)
    private val flash = MutableStateFlow(hasFlash)
    override val hasFlash: StateFlow<Boolean> = flash
    val binds = mutableListOf<Pair<Lens, Boolean>>()
    val photos = mutableListOf<Pair<File, Boolean>>()
    var finalize: ((Boolean) -> Unit)? = null
    var videoFile: File? = null

    override suspend fun bind(lens: Lens, withVideo: Boolean) {
        if (bindFails) error("camera in use")
        binds += lens to withVideo
    }

    override suspend fun capturePhoto(output: File, flash: Boolean): File {
        output.parentFile?.mkdirs()
        output.writeBytes(Images.jpeg())
        photos += output to flash
        return output
    }

    override fun startVideo(output: File, maxDurationMillis: Long, onFinalized: (Boolean) -> Unit): VideoStartResult {
        videoFile = output
        finalize = onFinalized
        return VideoStartResult.Started(VideoRecording {
            output.writeBytes(byteArrayOf(0, 0, 0, 24))
            onFinalized(true)
        })
    }

    override suspend fun dualMode(): DualCaptureMode = mode

    override suspend fun bindDual(main: Lens): DualCaptureMode {
        if (bindFails) error("camera in use")
        binds += main to false
        return mode
    }

    override suspend fun captureDual(dir: File, main: Lens, flash: Boolean, onFirstTaken: () -> Unit): CameraController.DualResult {
        val m = File(dir, "main.jpg").apply { parentFile?.mkdirs(); writeBytes(Images.jpeg()) }
        onFirstTaken()
        val other = if (frontFails) null else File(dir, "other.jpg").apply { writeBytes(Images.jpeg()) }
        return CameraController.DualResult(m, other, mode)
    }

    override suspend fun unbind() = Unit
}

/**
 * Fixture images: real sample photos (fixtures/photos/, :core:testing `SamplePhotos`) cropped and scaled
 * to the size each fixture declares, so dimensions in assertions still hold.
 */
object Images {
    /** Back-camera scenes and posted photos, by seed. */
    private val scenes = listOf(
        "friends-coffee-highfive-3x4",
        "dinner-pizza-cheers-3x4",
        "hike-mountain-friends-3x4",
        "picnic-spread-3x4",
        "dog-beach-run-3x4",
        "campfire-woods-3x4",
        "birthday-cake-candles-3x4",
        "beach-friends-run-4x3",
        "family-dinner-4x3",
        "snow-forest-walk-3x4",
        "concert-confetti-3x4",
        "coffee-latte-heart-3x4",
    )

    /** The front camera (daily inset): a selfie. */
    const val SELFIE = "selfie-two-friends-1x1"

    /** A camera still of [w] × [h] pixels (the fakes' default is a tiny one). */
    fun jpeg(w: Int = 30, h: Int = 40, seed: Int = 0): ByteArray = SamplePhotos.jpeg(scene(seed), w, h)

    /** The [seed]th scene cropped to [w] × [h] pixels. */
    fun photo(w: Int, h: Int, seed: Int = 0): android.graphics.Bitmap = SamplePhotos.bitmap(scene(seed), w, h)

    /** The front-camera selfie cropped to [w] × [h] pixels. */
    fun selfie(w: Int, h: Int): android.graphics.Bitmap = SamplePhotos.bitmap(SELFIE, w, h)

    /** The [seed]th scene as a JPEG file of [w] × [h] pixels. */
    fun photoFile(dir: File, name: String, w: Int = 300, h: Int = 400, seed: Int = 0): File =
        SamplePhotos.writeJpeg(File(dir, name), scene(seed), w, h)

    /** The [seed]th avatar portrait as a square JPEG file of [side] pixels. */
    fun avatarFile(dir: File, name: String, side: Int, seed: Int = 0): File =
        SamplePhotos.writeJpeg(File(dir, name), SamplePhotos.avatar(seed), side, side)

    /** A collage rendition: four scenes from the [seed]th in a 2 × 2 grid, as a JPEG file of [w] × [h] pixels. */
    fun collageFile(dir: File, name: String, w: Int, h: Int, seed: Int = 0): File {
        val file = File(dir, name).apply { parentFile?.mkdirs() }
        val grid = SamplePhotos.collage(w, h, (0 until 4).map { scene(seed + it) }, columns = 2, gap = COLLAGE_GAP)
        file.outputStream().use { grid.compress(android.graphics.Bitmap.CompressFormat.JPEG, 90, it) }
        return file
    }

    private fun scene(seed: Int) = scenes[Math.floorMod(seed, scenes.size)]
    private const val COLLAGE_GAP = 6
}


/** The send-to recorder and player without a microphone: records calls; [finish] returns a note of [noteMs]. */
class FakeSendToVoice(private val dir: File) : app.feature.capture.sendto.SendToVoice {
    val calls = mutableListOf<String>()
    var noteMs = 4_000L
    var startFails = false
    override val elapsedMs = MutableStateFlow(0L)
    override val levels = MutableStateFlow<List<Int>>(emptyList())
    override val playback = MutableStateFlow(app.feature.capture.sendto.VoicePlay())

    override fun start() {
        if (startFails) error("no microphone")
        calls += "start"
    }

    override fun pause() { calls += "pause" }
    override fun resume() { calls += "resume" }

    override suspend fun draftFile(): File {
        calls += "draft"
        return File(dir, "draft.m4a").apply { writeBytes(byteArrayOf(1)) }
    }

    override suspend fun finish(): app.voice.VoiceNote {
        calls += "finish"
        return app.voice.VoiceNote(File(dir, "note-${calls.size}.m4a").apply { writeBytes(byteArrayOf(1)) }, noteMs, LEVELS)
    }

    override fun cancel() { calls += "cancel" }

    override fun toggle(file: File) {
        calls += "toggle:${file.name}"
        val p = playback.value
        playback.value = if (p.file == file && p.isPlaying) p.copy(isPlaying = false) else app.feature.capture.sendto.VoicePlay(file, true, 0f)
    }

    override fun stopPlayback() {
        calls += "stopPlayback"
        playback.value = app.feature.capture.sendto.VoicePlay()
    }

    override fun release() { calls += "release" }

    companion object {
        /** 100 levels of 0…31 (C-36). */
        val LEVELS: List<Int> = List(100) { (it * 7) % 32 }
    }
}
