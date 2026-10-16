package app.feature.social

import android.content.Context
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.graphics.painter.Painter
import app.designsystem.LocalReduceMotionOverride
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

    /** Every image keeps the intrinsic size of the generated ones it replaces (3:4, 120 × 160 px), so layouts match. */
    fun painter(path: String): Painter = cache.getOrPut(path) {
        val parts = path.split('/')
        when {
            parts[0] == "avatars" -> sized(people[parts[1]] ?: SamplePhotos.avatarForKey(parts[1]))
            "covers" in parts -> sized("dinner-long-table-3x4")
            "collages" in parts -> SamplePhotos.painter(
                SamplePhotos.collage(COLLAGE_W, COLLAGE_H, (0 until 4).map { SamplePhotos.pick(it + 9) }, columns = 2), WIDTH, HEIGHT,
            )
            parts[0] == "u" && "front" in parts -> sized(people[parts[1]] ?: SamplePhotos.avatarForKey(parts[1]))
            parts[0] == "u" && parts.size >= 3 -> sized(photoFor(parts[2]))
            else -> sized(SamplePhotos.forKey(path))
        }
    }

    private fun sized(name: String) = SamplePhotos.painter(name, 3, 4, WIDTH, HEIGHT)

    private fun photoFor(media: String): String {
        named[media]?.let { return it }
        val number = Regex("(\\d+)$").find(media)?.value?.toIntOrNull() ?: return SamplePhotos.forKey(media)
        return SamplePhotos.pick(Math.floorMod(media.substringBeforeLast('-').hashCode(), PORTRAIT_OFFSETS) + number)
    }

    private const val WIDTH = 120f
    private const val HEIGHT = 160f
    private const val COLLAGE_W = 900
    private const val COLLAGE_H = 1200
    private const val PORTRAIT_OFFSETS = 7
}

/** Voice without hardware: records "levels", plays instantly, synthetic envelopes. */
class FakeVoice : VoiceServices {
    override val levels = MutableStateFlow(listOf(6, 18, 27, 12, 21))
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

/** A social screen as the app shows it, with test data, sample photos (fixtures/photos/), fake services and the appearance under test. */
@Composable
fun TestScreen(
    data: SocialData,
    services: SocialServices = testServices,
    dark: Boolean = false,
    content: @Composable () -> Unit,
) {
    CompositionLocalProvider(
        LocalSocialData provides data,
        LocalSocialDataOverride provides data,
        LocalPhotoOverride provides TestPhotos::painter,
        LocalSocialServices provides services,
        LocalReduceMotionOverride provides false,
        // The memory group's tag run reads and writes tags through its own backend: the fake's, here.
        app.feature.memory.common.LocalMemoryBackend provides TagBackend(data),
    ) {
        SocialRoot(dark = dark, content = content)
    }
}

/** The memory group's backend over [SocialData] for the tag run (the only calls the viewer's run makes). */
class TagBackend(private val data: SocialData) : app.feature.memory.common.MemoryBackend by app.feature.memory.common.UnconfiguredMemoryBackend {
    override val currentUserId: String? get() = data.currentUserId()
    override fun isOnline(): Boolean = (data as? FakeSocialData)?.offline != true
    override suspend fun profiles(ids: List<String>) = data.profiles(ids)
    override suspend fun signedUrls(paths: Collection<String>) = data.signedUrls(paths)
    override suspend fun postTags(postId: String) = data.tags(postId)
    override suspend fun tagSelf(postId: String) = data.tagSelf(postId)
    override suspend fun untagSelf(postId: String) = data.untagSelf(postId)
}

/** Ensures [StateFlow] values are read after the view model settled. */
fun <T> StateFlow<T>.now(): T = value
