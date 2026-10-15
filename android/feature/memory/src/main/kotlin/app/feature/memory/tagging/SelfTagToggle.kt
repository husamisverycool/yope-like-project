// Surface: tagging — design/surfaces/tagging.md
// References: references/auto/yope/frames/a-chuongxetank-7694968408424582452-t7.73-posted-toast-contacts-card.png,
// references/auto/yope/store/yope-store-04.png, references/auto/yope/frames/a-jacob-7691153057177931039-t3.73-camera-hold-to-record.png,
// references/auto/yope/frames/a-chuongxetank-7694968408424582452-t6.73-sendto-voice-tooltip.png.
package app.feature.memory.tagging

import android.content.Context
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.selection.toggleable
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.GenericShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicText
import androidx.compose.material3.Icon
import androidx.compose.runtime.Composable
import androidx.compose.runtime.Stable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.IntRect
import androidx.compose.ui.unit.IntSize
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.Popup
import androidx.compose.ui.window.PopupPositionProvider
import app.designsystem.Haptics
import app.designsystem.R
import app.designsystem.generated.Tokens
import app.feature.memory.common.Failure
import app.feature.memory.common.MemoryBackend
import app.feature.memory.common.MemoryToast
import app.feature.memory.common.attempt
import app.feature.memory.common.failureOf
import app.feature.memory.common.rememberMemoryBackend
import app.feature.memory.common.roleStyle
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.launch

/** Remembers whether the "i'm in this" coach was dismissed, per account (`tagging.coach`: once per account). */
interface CoachStore {
    fun dismissed(userId: String): Boolean
    fun dismiss(userId: String)
}

/** [CoachStore] in app-private SharedPreferences. */
class PrefsCoachStore(context: Context) : CoachStore {
    private val prefs = context.applicationContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
    override fun dismissed(userId: String): Boolean = prefs.getBoolean(KEY + userId, false)
    override fun dismiss(userId: String) = prefs.edit().putBoolean(KEY + userId, true).apply()

    private companion object {
        const val PREFS = "memory.tagging"
        const val KEY = "coachDismissed."
    }
}

/** Overrides the coach store below this point (tests). */
val LocalCoachStore = staticCompositionLocalOf<CoachStore?> { null }

/**
 * State and behaviour of the "i'm in this" control for one photo (design/surfaces/tagging.md):
 * optimistic — the toggle changes at once and `tag_self` / `untag_self` runs; on failure it returns
 * to its previous state with the spec's message. At most one call in flight per photo.
 */
@Stable
class SelfTagController(
    val postId: String,
    private val backend: MemoryBackend,
    private val scope: CoroutineScope,
    initiallyTagged: Boolean?,
    private val haptic: (Int) -> Unit = {},
    private val onPhotoGone: () -> Unit = {},
) {
    /** Your tag on this photo; null until known (the toggle is not drawn until then). */
    var tagged by mutableStateOf(initiallyTagged)
        private set

    /** A call is running: taps are ignored. */
    var pending by mutableStateOf(false)
        private set

    /** The message of the last failure (`tagging.error` / `.notFound` / `.offline`), until dismissed. */
    var message by mutableStateOf<Message?>(null)
        private set

    enum class Message { Error, NotFound, Offline }

    init {
        if (initiallyTagged == null) scope.launch { tagged = attempt { backend.isTagged(postId) }.getOrNull() }
    }

    /** Toggle (optimistic; reverted on failure). */
    fun toggle() {
        val before = tagged ?: return
        if (pending) return
        if (!backend.isOnline()) {
            haptic(Tokens.Haptics.globalError)
            message = Message.Offline
            return
        }
        tagged = !before
        pending = true
        message = null
        haptic(Tokens.Haptics.globalSelect)
        scope.launch {
            attempt { if (before) backend.untagSelf(postId) else backend.tagSelf(postId) }
                .onFailure { e ->
                    tagged = before
                    haptic(Tokens.Haptics.globalError)
                    when (failureOf(e)) {
                        Failure.NotFound -> {
                            message = Message.NotFound
                            onPhotoGone()
                        }
                        Failure.Offline -> message = Message.Offline
                        else -> message = Message.Error
                    }
                }
            pending = false
        }
    }

    fun dismissMessage() {
        message = null
    }
}

/** A [SelfTagController] for [postId], remembered across recompositions. */
@Composable
fun rememberSelfTagController(postId: String, initiallyTagged: Boolean? = null, onPhotoGone: () -> Unit = {}): SelfTagController {
    val backend = rememberMemoryBackend()
    val scope = rememberCoroutineScope()
    val view = LocalView.current
    return remember(postId, backend) {
        SelfTagController(postId, backend, scope, initiallyTagged, haptic = { Haptics.perform(view, it) }, onPhotoGone = onPhotoGone)
    }
}

/** Test tags. */
object SelfTagTags {
    const val TOGGLE = "tagging.toggle"
    const val COACH = "tagging.coach"
}

/**
 * **"i'm in this" self-tag control** (design/surfaces/tagging.md) — reusable; the `photo.viewer`
 * pass embeds it in the viewer's action area and owns its position and size.
 *
 * A white capsule (`color.global.surfaceLight`, `radius.global.capsule`) with the state glyph
 * (`icon.global.uncheck` in `color.global.onSurfaceLight` when off, `icon.global.check` in
 * `color.global.selection` when on, `size.global.checkCircle`), `size.global.headerGap`, and the
 * label `tagging.toggle` in text role `button`. Tapping tags / untags **only yourself** at once
 * (optimistic, `haptic.global.select`) and calls `tag_self` / `untag_self`; a failure reverts it
 * (`haptic.global.error`, message `tagging.error` / `.notFound` / `.offline` as the lime toast once its
 * dwell time is sourced). TalkBack: a switch labelled `tagging.toggle` (on / off). No count of tags,
 * nobody else's tags, no face recognition, nobody is notified.
 *
 * The first time a member opens a photo someone else posted, the foundations coach tooltip
 * (`tagging.coach`) points at the toggle until its ✕ or the toggle is tapped (once per account).
 * Not for collages.
 *
 * @param postId the photo's post.
 * @param postAuthorId the photo's author: the coach shows only on other people's photos.
 * @param initiallyTagged your tag from the viewer's batch read of `post_tags`; null = read it here.
 * @param onPhotoGone called on `post_not_found` (the viewer closes the photo).
 * @param height minimum capsule height; default the Yope white pill (`groups.screen.size.lightPillHeight`).
 * @param contentPadding inside the capsule; default the shared white pill's (`size.global.buttonMarginH`).
 */
@Composable
fun SelfTagToggle(
    postId: String,
    postAuthorId: String?,
    modifier: Modifier = Modifier,
    initiallyTagged: Boolean? = null,
    onPhotoGone: () -> Unit = {},
    height: Dp = Tokens.Sizes.groupsScreenSizeLightPillHeight,
    contentPadding: PaddingValues = PaddingValues(horizontal = Tokens.Sizes.globalButtonMarginH),
    controller: SelfTagController = rememberSelfTagController(postId, initiallyTagged, onPhotoGone),
) {
    val tagged = controller.tagged ?: return
    val backend = rememberMemoryBackend()
    val context = LocalContext.current
    val store = LocalCoachStore.current ?: remember(context) { PrefsCoachStore(context) }
    val me = backend.currentUserId
    var coach by remember(postId, me) {
        mutableStateOf(me != null && postAuthorId != null && postAuthorId != me && !store.dismissed(me))
    }
    val dismissCoach: () -> Unit = {
        coach = false
        if (me != null) store.dismiss(me)
    }
    val label = stringResource(R.string.tagging_toggle)
    Box(modifier) {
        Row(
            Modifier
                .heightIn(min = height)
                .clip(CircleShape)
                .background(Tokens.Colors.globalSurfaceLight)
                .toggleable(value = tagged, enabled = !controller.pending, role = Role.Switch) {
                    if (coach) dismissCoach()
                    controller.toggle()
                }
                .semantics { contentDescription = label }
                .testTag(SelfTagTags.TOGGLE)
                .padding(contentPadding),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Icon(
                if (tagged) Tokens.Icons.globalCheck else Tokens.Icons.globalUncheck,
                contentDescription = null,
                tint = if (tagged) Tokens.Colors.globalSelection else Tokens.Colors.globalOnSurfaceLight,
                modifier = Modifier.size(Tokens.Sizes.globalCheckCircle),
            )
            Spacer(Modifier.size(Tokens.Sizes.globalHeaderGap))
            BasicText(label, style = roleStyle(Tokens.FontSizes.globalButton, Tokens.FontWeights.fontWeightGlobalButton).copy(color = Tokens.Colors.globalOnSurfaceLight))
        }
        if (coach) Popup(popupPositionProvider = AboveAnchor) { Coach(onDismiss = dismissCoach) }
    }
    controller.message?.let { message ->
        Popup(alignment = Alignment.TopCenter) {
            MemoryToast(
                message = stringResource(
                    when (message) {
                        SelfTagController.Message.Error -> R.string.tagging_error
                        SelfTagController.Message.NotFound -> R.string.tagging_notfound
                        SelfTagController.Message.Offline -> R.string.tagging_offline
                    },
                ),
                onDismiss = controller::dismissMessage,
                success = false,
            )
        }
    }
}

/** Places the coach centred above the toggle, its pointer `pointerToTarget` from the toggle's top. */
private object AboveAnchor : PopupPositionProvider {
    override fun calculatePosition(anchorBounds: IntRect, windowSize: IntSize, layoutDirection: LayoutDirection, popupContentSize: IntSize): IntOffset {
        val x = (anchorBounds.center.x - popupContentSize.width / 2).coerceIn(0, (windowSize.width - popupContentSize.width).coerceAtLeast(0))
        return IntOffset(x, anchorBounds.top - popupContentSize.height)
    }
}

/**
 * The foundations coach tooltip (Yope's "hold down to record", `camera.capture.layout.coach`): lime
 * box, text `tagging.coach` in `color.global.onAccent`, ✕, and a pointer at the toggle below.
 */
@Composable
private fun Coach(onDismiss: () -> Unit) {
    val coach = Tokens.Layouts.CameraCaptureLayoutCoach
    val pointer = GenericShape { size, _ ->
        moveTo(0f, 0f)
        lineTo(size.width, 0f)
        lineTo(size.width / 2, size.height)
        close()
    }
    Column(Modifier.padding(bottom = coach.pointerToTarget.dp).testTag(SelfTagTags.COACH), horizontalAlignment = Alignment.CenterHorizontally) {
        Row(
            Modifier
                .heightIn(min = coach.height.dp)
                .clip(RoundedCornerShape(coach.cornerRadius.dp))
                .background(Tokens.Colors.globalAccent)
                // One element: TalkBack reads the coach text; activating it (or the ✕) dismisses it.
                .clickable(role = Role.Button, onClick = onDismiss)
                .padding(horizontal = coach.paddingHorizontal.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            BasicText(
                stringResource(R.string.tagging_coach),
                style = roleStyle(Tokens.FontSizes.cameraCaptureFontSizeCoach, Tokens.FontWeights.cameraCaptureFontWeightCoach).copy(color = Tokens.Colors.globalOnAccent),
            )
            Spacer(Modifier.size(coach.textToCloseGap.dp))
            Icon(Tokens.Icons.globalClose, contentDescription = null, tint = Tokens.Colors.globalOnAccent, modifier = Modifier.size(coach.closeGlyph.dp))
        }
        Box(Modifier.size(coach.pointerWidth.dp, coach.pointerHeight.dp).background(Tokens.Colors.globalAccent, pointer))
    }
}
