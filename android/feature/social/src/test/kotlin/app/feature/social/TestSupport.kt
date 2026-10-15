package app.feature.social

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.LinearGradient
import android.graphics.Paint
import android.graphics.Shader
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.graphics.painter.BitmapPainter
import androidx.compose.ui.graphics.painter.Painter
import app.designsystem.LocalReduceMotionOverride
import app.feature.social.common.LocalApproximations
import app.feature.social.common.LocalPhotoOverride
import app.feature.social.common.LocalSocialData
import app.feature.social.common.LocalSocialServices
import app.feature.social.common.SocialRoot
import app.feature.social.data.GallerySaver
import app.feature.social.data.RecordedVoice
import app.feature.social.data.SocialData
import app.feature.social.data.SocialServices
import app.feature.social.data.VoicePlayback
import app.feature.social.data.VoiceServices
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import java.io.File
import java.util.Locale
import java.util.TimeZone

/**
 * Synthetic photos for snapshots: a two-colour diagonal gradient per storage path (no reference
 * content). Colours are test data, not design values.
 */
object TestPhotos {
    private val cache = HashMap<String, Painter>()
    private val palettes = listOf(
        0xFF8E6E53.toInt() to 0xFF2D3A4A.toInt(),
        0xFFB5838D.toInt() to 0xFF3B2F2F.toInt(),
        0xFF6D8A96.toInt() to 0xFF1F2A30.toInt(),
        0xFFA3B18A.toInt() to 0xFF344E41.toInt(),
        0xFFD4A373.toInt() to 0xFF5E503F.toInt(),
        0xFF9A8C98.toInt() to 0xFF22223B.toInt(),
    )

    fun painter(path: String): Painter = cache.getOrPut(path) {
        val (a, b) = palettes[Math.floorMod(path.hashCode(), palettes.size)]
        val bitmap = Bitmap.createBitmap(WIDTH, HEIGHT, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        val paint = Paint().apply { shader = LinearGradient(0f, 0f, WIDTH.toFloat(), HEIGHT.toFloat(), a, b, Shader.TileMode.CLAMP) }
        canvas.drawRect(0f, 0f, WIDTH.toFloat(), HEIGHT.toFloat(), paint)
        BitmapPainter(bitmap.asImageBitmap())
    }

    private const val WIDTH = 120
    private const val HEIGHT = 160
}

/** Voice without hardware: records "levels", plays instantly, synthetic envelopes. */
class FakeVoice : VoiceServices {
    override val levels = MutableStateFlow(listOf(0.2f, 0.6f, 0.9f, 0.4f, 0.7f))
    override val playback = MutableStateFlow(VoicePlayback(null, false))
    var recording = false
    val played = ArrayList<String>()

    override fun startRecording() {
        recording = true
    }

    override fun stopRecording(): RecordedVoice? {
        recording = false
        return RecordedVoice(File.createTempFile("voice", ".m4a"), DURATION_MS)
    }

    override fun cancelRecording() {
        recording = false
    }

    override fun play(key: String, url: String) {
        played += key
        playback.value = VoicePlayback(key, true, PROGRESS)
    }

    override fun pause() {
        playback.value = playback.value.copy(isPlaying = false)
    }

    override suspend fun envelope(key: String, url: String, bars: Int): List<Float> = List(bars) { i -> ((i * 37) % 100) / 100f }
    override fun release() = Unit

    companion object {
        const val DURATION_MS = 4_000
        const val PROGRESS = 0.4f
    }
}

class FakeGallery(private val needs: Boolean = false) : GallerySaver {
    val saved = ArrayList<String>()
    override fun needsPermission(context: Context) = needs
    override suspend fun save(context: Context, bytes: ByteArray, mimeType: String, extension: String): Boolean {
        saved += mimeType
        return true
    }
}

val testVoice = FakeVoice()
val testServices = SocialServices(voice = { testVoice }, gallery = FakeGallery())

/** Deterministic formatting for snapshots and assertions. */
fun fixLocale() {
    Locale.setDefault(Locale.US)
    TimeZone.setDefault(TimeZone.getTimeZone("UTC"))
}

/** A social screen as the app shows it, with test data, synthetic photos and fake services. */
@Composable
fun TestScreen(
    data: SocialData,
    approximations: Boolean = true,
    services: SocialServices = testServices,
    content: @Composable () -> Unit,
) {
    CompositionLocalProvider(
        LocalSocialData provides data,
        LocalSocialDataOverride provides data,
        LocalPhotoOverride provides TestPhotos::painter,
        LocalSocialServices provides services,
        LocalApproximations provides approximations,
        LocalReduceMotionOverride provides false,
        app.feature.social.reactions.LocalRainRandom provides kotlin.random.Random(RAIN_SEED),
        // The memory group's "i'm in this" control reads tags through its own backend: the fake's, here.
        app.feature.memory.common.LocalMemoryBackend provides TagBackend(data),
        app.feature.memory.tagging.LocalCoachStore provides NoCoach,
    ) {
        SocialRoot(content)
    }
}

private const val RAIN_SEED = 7

/** Ensures [StateFlow] values are read after the view model settled. */
fun <T> StateFlow<T>.now(): T = value

/** The memory group's backend over [SocialData] for the tagging control (other calls are not used by the viewer). */
class TagBackend(private val data: SocialData) : app.feature.memory.common.MemoryBackend by app.feature.memory.common.UnconfiguredMemoryBackend {
    override val currentUserId: String? get() = data.currentUserId()
    override fun isOnline(): Boolean = (data as? FakeSocialData)?.offline != true
    override suspend fun isTagged(postId: String): Boolean = data.isTaggedByMe(postId)
    override suspend fun tagSelf(postId: String) = data.tagSelf(postId)
    override suspend fun untagSelf(postId: String) = data.untagSelf(postId)
}

/** The tagging coach counts as seen (tests that want it set `ViewerUiState(coach = true)`). */
object NoCoach : app.feature.memory.tagging.CoachStore {
    override fun dismissed(userId: String) = true
    override fun dismiss(userId: String) = Unit
}
