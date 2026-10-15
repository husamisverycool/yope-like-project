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
    }
    override val online: Flow<Boolean> get() = onlineFlow
    override suspend fun invitation(invitationId: String): DailyInvitation? = invitation
    override suspend fun group(groupId: String): Group? = groupById[groupId]
    override suspend fun collageForInvitation(invitationId: String): Collage? {
        collageError?.let { throw DataException(it) }
        return collage
    }
    override suspend fun newestForWidget(groupId: String): NewestForWidget? = newest
    override suspend fun members(groupId: String): List<Member> = members
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

/** Fixture images (test-only, synthetic). */
object Images {
    fun jpeg(w: Int = 30, h: Int = 40, argb: Int = 0xFF4A6FA5.toInt()): ByteArray {
        val bitmap = android.graphics.Bitmap.createBitmap(w, h, android.graphics.Bitmap.Config.ARGB_8888)
        val canvas = android.graphics.Canvas(bitmap)
        canvas.drawColor(argb)
        val out = java.io.ByteArrayOutputStream()
        bitmap.compress(android.graphics.Bitmap.CompressFormat.JPEG, 90, out)
        return out.toByteArray()
    }

    /** A synthetic "photo": a diagonal gradient with a few shapes, so crops and overlays read. */
    fun photo(w: Int, h: Int, seed: Int = 0): android.graphics.Bitmap {
        val bitmap = android.graphics.Bitmap.createBitmap(w, h, android.graphics.Bitmap.Config.ARGB_8888)
        val canvas = android.graphics.Canvas(bitmap)
        val palettes = listOf(
            intArrayOf(0xFF6A8CAF.toInt(), 0xFFE0B48A.toInt()),
            intArrayOf(0xFF3E6B4F.toInt(), 0xFFC9D6A3.toInt()),
            intArrayOf(0xFF7A4E6E.toInt(), 0xFFF2C6A0.toInt()),
            intArrayOf(0xFF2F3E5C.toInt(), 0xFF9FB8D8.toInt()),
        )
        val p = palettes[seed % palettes.size]
        val paint = android.graphics.Paint().apply {
            shader = android.graphics.LinearGradient(0f, 0f, w.toFloat(), h.toFloat(), p[0], p[1], android.graphics.Shader.TileMode.CLAMP)
        }
        canvas.drawRect(0f, 0f, w.toFloat(), h.toFloat(), paint)
        val shape = android.graphics.Paint(android.graphics.Paint.ANTI_ALIAS_FLAG).apply { color = 0x55FFFFFF }
        canvas.drawCircle(w * 0.3f, h * 0.35f, w * 0.18f, shape)
        canvas.drawRect(w * 0.55f, h * 0.55f, w * 0.9f, h * 0.85f, shape)
        return bitmap
    }

    fun photoFile(dir: File, name: String, w: Int = 300, h: Int = 400, seed: Int = 0): File {
        dir.mkdirs()
        val f = File(dir, name)
        f.outputStream().use { photo(w, h, seed).compress(android.graphics.Bitmap.CompressFormat.JPEG, 92, it) }
        return f
    }
}

