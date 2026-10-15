package app.feature.social

import android.content.Context
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
import app.testing.SamplePhotos
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import java.io.File
import java.util.Locale
import java.util.TimeZone

/**
 * Real photos for snapshots (fixtures/photos/, :core:testing `SamplePhotos`), one per storage path:
 * avatars (`avatars/<user>/…`) from the square portraits, the group cover, collages as a grid of photos, and
 * every rendition of a media (`u/<owner>/<media>/…`) the same photo, cropped to the fake media's 3:4.
 * Numbered media (`md-w-3`, `md-wall-u-me-5`) take consecutive photos, so a grid never repeats one.
 */
object TestPhotos {
    private val cache = HashMap<String, Painter>()

    /** Media whose caption names what the picture shows. */
    private val named = mapOf(
        "md-p-1" to "friends-coffee-highfive-3x4",
        "md-v-1" to "sunset-lake-9x16",
        "md-v-2" to "dinner-pizza-cheers-3x4",
    )

    /** Me (Sam), Ana, Ben, and the walls browser's Chloe, Dev, "Our band group", Femi. */
    private val people = mapOf(
        FakeSocialData.ME to "avatar-02", FakeSocialData.ANA to "avatar-01", FakeSocialData.BEN to "avatar-06",
        "u-x0" to "avatar-05", "u-x1" to "avatar-04", "u-x2" to "avatar-09", "u-x3" to "avatar-10",
    )

    fun painter(path: String): Painter = cache.getOrPut(path) {
        val parts = path.split('/')
        when {
            parts[0] == "avatars" -> SamplePhotos.painter(people[parts[1]] ?: SamplePhotos.avatarForKey(parts[1]))
            "covers" in parts -> SamplePhotos.painter("dinner-long-table-3x4", 1, 1)
            "collages" in parts -> BitmapPainter(SamplePhotos.collage(COLLAGE_W, COLLAGE_H, (0 until 4).map { SamplePhotos.pick(it + 9) }, columns = 2).asImageBitmap())
            parts[0] == "u" && parts.size >= 3 -> SamplePhotos.painter(photoFor(parts[2]), 3, 4)
            else -> SamplePhotos.painter(SamplePhotos.forKey(path), 3, 4)
        }
    }

    private fun photoFor(media: String): String {
        named[media]?.let { return it }
        val number = Regex("(\\d+)$").find(media)?.value?.toIntOrNull() ?: return SamplePhotos.forKey(media)
        return SamplePhotos.pick(Math.floorMod(media.substringBeforeLast('-').hashCode(), PORTRAIT_OFFSETS) + number)
    }

    private const val COLLAGE_W = 900
    private const val COLLAGE_H = 1200
    private const val PORTRAIT_OFFSETS = 7
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

/** A social screen as the app shows it, with test data, sample photos (fixtures/photos/) and fake services. */
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
