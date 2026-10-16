// Surface: viewer.selfiereaction — design/surfaces/viewer.selfiereaction.md (inside photo.viewer).
// References: references/auto/bereal/frames/appstore-preview-2026_t12.47s_instant-realmoji-capture.png (AP-375: circle, border,
// hint, target ring, second hint), …_t13.47s_instant-realmoji-armed.png (AP-405: armed ring), …_t14.20s_realmoji-stack.png
// (AP-427: stack position, order, z-order), references/auto/bereal/help/help-21088572284317_realpeople-realmoji-comments-3x.png
// (H-RP: face border, insets), references/auto/retro/press/tc-2023-07-retro-2b.jpg phone 2 (TC-2B: Retro's white viewer
// ring), references/auto/retro/store/retro-store-03.png (ST-03: C-09 pill / C-11 circle on media). Mechanics BeReal's
// Instant RealMoji; every visual value Retro's (MERGE_DECISIONS SR-1 … SR-9).
package app.feature.social.viewer

import android.Manifest
import android.content.Intent
import android.net.Uri
import android.provider.Settings
import androidx.activity.compose.BackHandler
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.camera.compose.CameraXViewfinder
import androidx.compose.animation.core.animateDpAsState
import androidx.compose.animation.core.snap
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.gestures.awaitEachGesture
import androidx.compose.foundation.gestures.awaitFirstDown
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.Stable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.key
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.input.pointer.PointerEventPass
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.layout.LayoutCoordinates
import androidx.compose.ui.layout.boundsInRoot
import androidx.compose.ui.layout.findRootCoordinates
import androidx.compose.ui.layout.layout
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.layout.positionInRoot
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.CustomAccessibilityAction
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.customActions
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.rememberTextMeasurer
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.max
import androidx.compose.ui.unit.min
import androidx.lifecycle.compose.LocalLifecycleOwner
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import app.data.model.SelfieReaction
import app.designsystem.R
import app.designsystem.generated.Tokens
import app.feature.social.common.Formats
import app.feature.social.common.photoModel
import app.feature.social.common.stringRes
import app.feature.social.reactions.ReactionsSheetRow
import app.media.MediaPermission
import app.media.MediaPermissions
import app.ui.components.ActivityIndicator
import app.ui.components.Avatar
import app.ui.components.EmptyState
import app.ui.components.EmptyStateAction
import app.ui.foundation.DsMotion
import app.ui.foundation.FadeVisibility
import app.ui.foundation.PageRoles
import app.ui.foundation.reduceMotion
import app.ui.foundation.tapClickable
import app.ui.foundation.tapLongPressable
import app.ui.haptics.rememberHaptics
import app.ui.system.DsDropdownMenu
import app.ui.system.DsMenuItem
import app.ui.text.CapTop
import app.ui.text.TextRoles
import app.ui.text.capTopAt
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.launch
import java.io.File
import java.time.Instant

/** One selfie reaction as shown: who, the selfie, when. Never a count. */
data class SelfieEntry(
    /** `selfie_reactions.id` (the report target); null while yours is being sent. */
    val id: String?,
    val userId: String,
    /** Storage path (`u/<uid>/selfies/<uuid>.jpg`); null while yours is being sent. */
    val imagePath: String?,
    /** `created_at`; null while yours is being sent (the newest). */
    val createdAt: Instant?,
    /** The still you just took, shown while it uploads and after (optimistic, as `chat.reactions`). */
    val localFile: File? = null,
) {
    companion object {
        fun of(row: SelfieReaction) = SelfieEntry(row.id, row.userId, row.imagePath, row.createdAt)
    }
}

/** How the capture layer was opened: hold and slide (the add-reaction glyph), or the single-pointer path (WCAG 2.2 SC 2.5.7). */
enum class SelfieMode { Hold, Tap }

/** The front camera inside the layer. */
enum class SelfieCameraPhase { Starting, Live, Denied }

/**
 * The finger of a hold that opened the layer (hold mode): its position in root coordinates while it moves, and [ended]
 * once it lifts (or the gesture is cancelled: [released] false).
 */
@Stable
class SelfieHold {
    var pointer by mutableStateOf<Offset?>(null)
    var ended by mutableStateOf(false)
    var released by mutableStateOf(false)

    /** Where the held glyph is (its positions are turned into root coordinates); not state, read by the gesture only. */
    internal var anchor: LayoutCoordinates? = null

    fun reset() {
        pointer = null
        ended = false
        released = false
    }
}

/** A selfie's image model: the still you just took, or the stored selfie through a signed URL (tests: sample photos). */
@Composable
internal fun selfieImage(entry: SelfieEntry): Any? = entry.localFile ?: photoModel(entry.imagePath)

/** Faces in stack order: newest leading (`chat.reactions.layout.clusterOrder`), at most `chat.reactions.count.clusterMaxVisible`. */
fun stackFaces(selfies: List<SelfieEntry>): List<SelfieEntry> =
    selfies.sortedWith(newestFirst { it.createdAt }).take(Tokens.Counts.chatReactionsCountClusterMaxVisible)

/** Newest first by [time]; null (still being sent) counts as the newest. Stable for equal times. */
internal fun <T> newestFirst(time: (T) -> Instant?): Comparator<T> = Comparator { a, b ->
    val x = time(a)
    val y = time(b)
    when {
        x == null && y == null -> 0
        x == null -> -1
        y == null -> 1
        else -> y.compareTo(x)
    }
}

/**
 * The faces on the photo (`viewer.selfiereaction.layout.stack`): circles of `size.global.avatarHeader` (ring included), the
 * selfie aspect-filled inside a `color.global.textOnMedia` ring `photo.viewer.layout.avatarRing.strokeWidth` wide (C-23 white
 * stack ring); newest leading, each trailing face drawn over the one before it, `size.global.avatarStackOverlap` apart; no
 * "+N" and no number. One button ([label]: the names shown, never a count) → the Reactions sheet; a tap never advances the
 * photo. A face enters with `spring.global.playful` and the stack shifts with it; a removed face fades out
 * (`duration.global.fade`) while the others settle with the spring; Reduce Motion cross-fades (`duration.global.crossfade`).
 */
@Composable
fun SelfieStack(faces: List<SelfieEntry>, label: String, onClick: () -> Unit, modifier: Modifier = Modifier) {
    if (faces.isEmpty()) return
    val size = Tokens.Sizes.globalAvatarHeader
    val step = size - Tokens.Sizes.globalAvatarStackOverlap
    val reduce = reduceMotion()
    val width = size + step * (faces.size - 1)
    val stackWidth by animateDpAsState(width, if (reduce) snap() else Tokens.Springs.globalPlayful.spec(), label = "stackWidth")
    // Faces already there when the photo opens do not animate in.
    val initial = remember { faces.map { it.userId }.toSet() }
    // Faces that just left stay drawn where they were while they fade out.
    val last = remember { arrayOf(faces) }
    val leaving = remember(faces) {
        val ids = faces.map { it.userId }.toSet()
        last[0].withIndex().filter { it.value.userId !in ids }.map { it.value to step * it.index }.also { last[0] = faces }
    }
    Box(
        modifier
            .size(stackWidth.coerceAtLeast(size), size)
            .tapClickable(onClick = onClick)
            .clearAndSetSemantics {
                contentDescription = label
                role = Role.Button
            }
            .testTag("viewer.selfies"),
    ) {
        leaving.forEach { (face, x) ->
            key("leaving:" + face.userId) {
                val fade = remember { androidx.compose.animation.core.Animatable(1f) }
                LaunchedEffect(Unit) { fade.animateTo(0f, tween(if (reduce) Tokens.Durations.globalCrossfade else Tokens.Durations.globalFade, easing = Tokens.Easings.globalStandard)) }
                Avatar(
                    selfieImage(face),
                    size,
                    Modifier
                        .offset(x = x)
                        .alpha(fade.value)
                        .border(Tokens.Layouts.PhotoViewerLayoutAvatarRing.strokeWidth.dp, Tokens.Colors.globalTextOnMedia, CircleShape),
                )
            }
        }
        faces.forEachIndexed { index, face ->
            key(face.userId) {
                val x by animateDpAsState(step * index, if (reduce) snap() else Tokens.Springs.globalPlayful.spec(), label = "faceX")
                var shown by remember { mutableStateOf(face.userId in initial) }
                LaunchedEffect(Unit) { shown = true }
                val enter by androidx.compose.animation.core.animateFloatAsState(
                    if (shown) 1f else 0f,
                    if (reduce) tween(Tokens.Durations.globalCrossfade) else Tokens.Springs.globalPlayful.spec(),
                    label = "faceIn",
                )
                Avatar(
                    selfieImage(face),
                    size,
                    Modifier
                        .offset(x = x)
                        .alpha(enter.coerceIn(0f, 1f))
                        .then(if (reduce) Modifier else Modifier.scale(enter))
                        .border(Tokens.Layouts.PhotoViewerLayoutAvatarRing.strokeWidth.dp, Tokens.Colors.globalTextOnMedia, CircleShape),
                )
            }
        }
    }
}

/** The stack's TalkBack label: `viewer.selfiereaction.a11y.stack` with the first names of the people shown (never a count). */
@Composable
fun selfieStackLabel(faces: List<SelfieEntry>, firstName: (String) -> String): String =
    stringRes(R.string.viewer_selfiereaction_a11y_stack, Formats.nameList(faces.map { firstName(it.userId) }.filter { it.isNotBlank() }))

/**
 * The hold of the add-reaction glyph (`viewer.selfiereaction` §1, Android `detectDragGesturesAfterLongPress` semantics): a
 * press that lifts or slides away before the long-press timeout stays a tap (the emoji picker); held past it, [onStart]
 * opens the layer (`haptic.global.longPressStart`), the finger's position goes to [hold] in root coordinates and every
 * later event is consumed (so the tap does not fire), and lifting ends it.
 */
fun Modifier.selfieHoldGesture(enabled: Boolean, hold: SelfieHold, onStart: () -> Unit): Modifier {
    if (!enabled) return this
    return onGloballyPositioned { hold.anchor = it }.pointerInput(hold) {
        awaitEachGesture {
            val down = awaitFirstDown(requireUnconsumed = false, pass = PointerEventPass.Initial)
            // Lifted, slid away (a scroll) or taken by someone else before the timeout: not a hold.
            val shortPress = withTimeoutOrNull(viewConfiguration.longPressTimeoutMillis) {
                var over = false
                while (!over) {
                    val event = awaitPointerEvent(PointerEventPass.Initial)
                    val change = event.changes.firstOrNull { it.id == down.id }
                    over = change == null || !change.pressed || change.isConsumed ||
                        (change.position - down.position).getDistance() > viewConfiguration.touchSlop
                }
                true
            }
            if (shortPress != null) return@awaitEachGesture
            hold.reset()
            hold.pointer = hold.anchor?.localToRoot(down.position)
            onStart()
            var released = false
            try {
                while (true) {
                    val event = awaitPointerEvent(PointerEventPass.Initial)
                    val change = event.changes.firstOrNull { it.id == down.id }
                    event.changes.forEach { it.consume() }
                    if (change == null) break
                    if (!change.pressed) {
                        released = true
                        break
                    }
                    hold.pointer = hold.anchor?.localToRoot(change.position)
                }
            } catch (e: CancellationException) {
                hold.released = false
                hold.ended = true
                throw e
            }
            hold.released = released
            hold.ended = true
        }
    }
}

/** Where the layer's targets are on screen (root coordinates), for the hold's armed test. */
private class SelfieTargets {
    var circle by mutableStateOf<Rect?>(null)
    var ring by mutableStateOf<Rect?>(null)

    /** The finger is inside the target ring or the circle (a round hit test on each). */
    fun contains(point: Offset?): Boolean {
        if (point == null) return false
        return listOfNotNull(circle, ring).any { r -> (point - r.center).getDistance() <= r.width / 2 }
    }
}

/**
 * The capture layer as the viewer shows it: the front camera (camera permission asked here at first use, as
 * `camera.capture` does), the hold's armed state (`haptic.global.select` when the finger enters a target), release /
 * tap → one still → [onCaptured] (the layer closes; nothing is sent from outside the targets). Back closes it.
 */
@Composable
fun SelfieCaptureRoute(mode: SelfieMode, hold: SelfieHold, onCaptured: (File) -> Unit, onFailed: () -> Unit, onClose: () -> Unit, modifier: Modifier = Modifier) {
    val context = LocalContext.current
    val owner = LocalLifecycleOwner.current
    val haptics = rememberHaptics()
    val scope = rememberCoroutineScope()
    val camera = remember(owner) { SelfieCameras.factory(context, owner) }
    var granted by remember { mutableStateOf(MediaPermissions.isGranted(context, MediaPermission.Camera)) }
    var asked by remember { mutableStateOf(false) }
    var failed by remember { mutableStateOf(false) }
    var capturing by remember { mutableStateOf(false) }
    val permission = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { ok ->
        MediaPermissions.markRequested(context, MediaPermission.Camera)
        asked = true
        granted = ok
    }
    LaunchedEffect(Unit) { if (!granted) permission.launch(Manifest.permission.CAMERA) }
    LaunchedEffect(granted) {
        if (!granted) return@LaunchedEffect
        try {
            camera.start()
        } catch (e: CancellationException) {
            throw e
        } catch (_: Exception) {
            failed = true
        }
    }
    DisposableEffect(camera) {
        // The screen's scope may be cancelled here; CameraX also closes with the lifecycle.
        onDispose { kotlinx.coroutines.MainScope().launch { runCatching { camera.stop() } } }
    }
    val preview by camera.preview.collectAsStateWithLifecycle()
    val phase = when {
        !granted && asked -> SelfieCameraPhase.Denied
        granted && preview != null && !failed -> SelfieCameraPhase.Live
        else -> SelfieCameraPhase.Starting
    }
    val close by rememberUpdatedState(onClose)
    val capture: () -> Unit = {
        if (!capturing && phase == SelfieCameraPhase.Live) {
            capturing = true
            scope.launch {
                val dir = File(context.cacheDir, SELFIE_DIR).apply { mkdirs() }
                val file = runCatching { camera.capture(File(dir, "selfie-${System.currentTimeMillis()}.jpg")) }.getOrNull() // provenance-ok: file name, not copy
                close()
                if (file != null && file.isFile) onCaptured(file) else onFailed()
            }
        }
    }
    val targets = remember { SelfieTargets() }
    val armed = mode == SelfieMode.Hold && phase == SelfieCameraPhase.Live && targets.contains(hold.pointer)
    LaunchedEffect(armed) { if (armed) haptics.tick() }
    LaunchedEffect(hold.ended) {
        if (mode != SelfieMode.Hold || !hold.ended) return@LaunchedEffect
        // Release inside the circle or the ring captures; anywhere else sends nothing.
        if (hold.released && targets.contains(hold.pointer) && phase == SelfieCameraPhase.Live) capture() else close()
    }
    BackHandler(onBack = onClose)
    SelfieCaptureLayer(
        mode = mode,
        phase = phase,
        armed = armed,
        preview = { preview?.let { CameraXViewfinder(surfaceRequest = it, modifier = Modifier.fillMaxSize(), contentScale = ContentScale.Crop) } },
        onCapture = capture,
        onClose = onClose,
        onOpenSettings = {
            context.startActivity(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.fromParts("package", context.packageName, null)).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        },
        onTargets = { circle, ring ->
            targets.circle = circle
            targets.ring = ring
        },
        modifier = modifier,
    )
}

private const val SELFIE_DIR = "selfies" // provenance-ok: cache folder name

/**
 * The capture layer (stateless; `viewer.selfiereaction` §2), below the viewer header, to the bottom of the screen:
 * 1. the panel in `color.global.controlOnDeep` (corners `radius.global.photo`: square), hiding photo, footer and field;
 * 2. the live circle `viewer.selfiereaction.layout.captureCircle` — screen width less 2 × `size.global.screenMargin`, centred
 *    on the screen's vertical middle (it shrinks, centred on the panel's middle, when the panel cannot hold circle, ring and
 *    hint), aspect-fill front preview in a circular clip, its `viewer.selfiereaction.size.captureBorder` border in
 *    `color.global.backgroundDeep` outside the clip; filled `color.global.backgroundDeep` with the C-28 indicator until the
 *    first frame;
 * 3. the C-09 hint pill on the circle's centre (`coach.slideHere` / `coach.tapRing`);
 * 4. the target ring on the circle's bottom edge: `camera.capture.size.shutterOuter`, stroke `.shutterRing`, no disc,
 *    `color.global.textSecondary` (dark value); a button in tap mode;
 * 5. hold mode: `coach.slideToSend` (`meta`, secondary), its cap top `size.global.screenMargin` below the ring;
 * 6. [armed]: the `color.global.textOnMedia` ring `photo.viewer.layout.avatarRing.strokeWidth` wide, its outer edge
 *    `photo.viewer.layout.avatarRing.gap` inside the circle (cross-fade `duration.global.crossfade`).
 * Denied: the C-27 block (`camera.capture.denied.*`) where the circle is, no ring, no hints. Tap mode: a tap on the panel
 * outside the circle closes; focus starts on the ring.
 */
@Composable
fun SelfieCaptureLayer(
    mode: SelfieMode,
    phase: SelfieCameraPhase,
    armed: Boolean,
    preview: @Composable () -> Unit,
    onCapture: () -> Unit,
    onClose: () -> Unit,
    onOpenSettings: () -> Unit,
    modifier: Modifier = Modifier,
    onTargets: (circle: Rect, ring: Rect) -> Unit = { _, _ -> },
) {
    val density = LocalDensity.current
    var panelTop by remember { mutableStateOf<Dp?>(null) }
    var rootHeight by remember { mutableStateOf<Dp?>(null) }
    val tapMode = mode == SelfieMode.Tap
    val measurer = rememberTextMeasurer()
    var circleBounds by remember { mutableStateOf(Rect.Zero) }
    var ringBounds by remember { mutableStateOf(Rect.Zero) }
    LaunchedEffect(circleBounds, ringBounds) { onTargets(circleBounds, ringBounds) }
    BoxWithConstraints(
        modifier
            .fillMaxSize()
            .clip(androidx.compose.foundation.shape.RoundedCornerShape(Tokens.Radii.globalPhoto))
            .background(Tokens.Colors.globalControlOnDeep)
            .onGloballyPositioned { c ->
                with(density) {
                    panelTop = c.positionInRoot().y.toDp()
                    rootHeight = c.findRootCoordinates().size.height.toDp()
                }
            }
            // Tap mode: a tap on the panel outside the circle closes (the circle and the ring take their own taps).
            .then(if (tapMode) Modifier.pointerInput(Unit) { detectTapGestures(onTap = { onClose() }) } else Modifier)
            .testTag("selfie.layer"),
    ) {
        val margin = Tokens.Sizes.globalScreenMargin
        val ring = Tokens.Sizes.cameraCaptureSizeShutterOuter
        val hintStyle = TextRoles.meta
        val slideToSend = stringRes(R.string.viewer_selfiereaction_coach_slidetosend)
        val hintHeight = with(density) { measurer.measure(slideToSend, hintStyle).size.height.toDp() }
        val below = ring / 2 + if (tapMode) 0.dp else margin + hintHeight
        val full = maxWidth - margin * 2
        val wanted = rootHeight?.let { root -> panelTop?.let { top -> root / 2 - top } } ?: (maxHeight / 2)
        val fits = wanted - full / 2 >= 0.dp && wanted + full / 2 + below <= maxHeight
        val centre = if (fits) wanted else maxHeight / 2
        val diameter = if (fits) full else max(0.dp, min(full, min(centre, maxHeight - centre - below) * 2))
        val border = Tokens.Sizes.viewerSelfiereactionSizeCaptureBorder
        val centreX = maxWidth / 2

        if (phase == SelfieCameraPhase.Denied) {
            Box(Modifier.fillMaxWidth().offset(y = centre).layoutCentredVertically(), contentAlignment = Alignment.Center) {
                EmptyState(
                    title = stringRes(R.string.camera_capture_denied_title),
                    detail = stringRes(R.string.camera_capture_denied_detail),
                    action = EmptyStateAction(stringRes(R.string.camera_capture_denied_button), onOpenSettings),
                )
            }
            return@BoxWithConstraints
        }

        // 2. Live circle with its border outside the clip.
        val previewLabel = stringRes(R.string.viewer_selfiereaction_a11y_preview)
        Box(
            Modifier
                .offset(x = centreX - diameter / 2 - border, y = centre - diameter / 2 - border)
                .size(diameter + border * 2)
                .background(Tokens.Colors.globalBackgroundDeep, CircleShape),
        )
        Box(
            Modifier
                .offset(x = centreX - diameter / 2, y = centre - diameter / 2)
                .size(diameter)
                .clip(CircleShape)
                .background(Tokens.Colors.globalBackgroundDeep)
                .onGloballyPositioned { circleBounds = it.boundsInRoot() }
                // Not a button (`viewer.selfiereaction.a11y.preview`); in tap mode a pointer tap on it sends, as its hint says.
                .clearAndSetSemantics { contentDescription = previewLabel }
                .then(if (tapMode && phase == SelfieCameraPhase.Live) Modifier.pointerInput(Unit) { detectTapGestures(onTap = { onCapture() }) } else Modifier)
                .testTag("selfie.circle"),
            contentAlignment = Alignment.Center,
        ) {
            FadeVisibility(visible = phase == SelfieCameraPhase.Live, modifier = Modifier.fillMaxSize()) { Box(Modifier.fillMaxSize()) { preview() } }
            if (phase == SelfieCameraPhase.Starting) ActivityIndicator(stringRes(R.string.global_a11y_loading), onMedia = true)
            // 6. Armed ring, in and out over `duration.global.crossfade`.
            androidx.compose.animation.AnimatedVisibility(
                visible = armed,
                modifier = Modifier.fillMaxSize(),
                enter = androidx.compose.animation.fadeIn(DsMotion.crossfade()),
                exit = androidx.compose.animation.fadeOut(DsMotion.crossfade()),
            ) {
                val ringSpec = Tokens.Layouts.PhotoViewerLayoutAvatarRing
                Canvas(Modifier.fillMaxSize().testTag("selfie.armed")) {
                    val stroke = ringSpec.strokeWidth.dp.toPx()
                    drawCircle(Tokens.Colors.globalTextOnMedia, radius = size.minDimension / 2 - ringSpec.gap.dp.toPx() - stroke / 2, style = Stroke(stroke))
                }
            }
        }

        // 3. Hint pill on the circle's centre.
        val hint = stringRes(if (tapMode) R.string.viewer_selfiereaction_coach_tapring else R.string.viewer_selfiereaction_coach_slidehere)
        Box(Modifier.fillMaxWidth().offset(y = centre).layoutCentredVertically(), contentAlignment = Alignment.Center) {
            SelfieHintPill(hint)
        }

        // 4. Target ring on the circle's bottom edge.
        val ringTop = centre + diameter / 2 - ring / 2
        val captureLabel = stringRes(R.string.viewer_selfiereaction_a11y_capture)
        val focus = remember { FocusRequester() }
        Box(
            Modifier
                .offset(x = centreX - ring / 2, y = ringTop)
                .size(ring)
                .onGloballyPositioned { ringBounds = it.boundsInRoot() }
                .then(
                    if (tapMode) {
                        Modifier
                            .focusRequester(focus)
                            .clip(CircleShape)
                            .tapClickable(enabled = phase == SelfieCameraPhase.Live, onClick = onCapture)
                            .semantics { contentDescription = captureLabel }
                    } else {
                        Modifier.clearAndSetSemantics { }
                    },
                )
                .testTag("selfie.ring"),
        ) {
            Canvas(Modifier.fillMaxSize()) {
                val stroke = Tokens.Sizes.cameraCaptureSizeShutterRing.toPx()
                drawCircle(Tokens.ColorsDark.globalTextSecondary, radius = size.minDimension / 2 - stroke / 2, style = Stroke(stroke))
            }
        }
        if (tapMode) LaunchedEffect(Unit) { runCatching { focus.requestFocus() } }

        // 5. Second hint (hold mode only).
        if (!tapMode) {
            Text(
                slideToSend,
                style = hintStyle,
                color = Tokens.ColorsDark.globalTextSecondary,
                textAlign = TextAlign.Center,
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = margin)
                    .capTopAt(ringTop + ring + margin, CapTop.height(hintStyle)),
            )
        }
    }
}

/** Places the element with its vertical centre on the offset it was given (its top would otherwise sit there). */
private fun Modifier.layoutCentredVertically(): Modifier = layout { measurable, constraints ->
    val placeable = measurable.measure(constraints.copy(minHeight = 0))
    layout(placeable.width, placeable.height) { placeable.place(0, -placeable.height / 2) }
}

/**
 * The C-09 coach pill on media (as `camera.capture`'s coach): fill `color.global.controlOnDeep`, text role `pill` in
 * `color.global.textOnMedia`, height `size.global.pillHeight`, paddings `size.global.pillPaddingLeading` /
 * `.pillPaddingTrailing`. Static: read as text.
 */
@Composable
private fun SelfieHintPill(text: String) {
    Row(
        Modifier
            .heightIn(min = Tokens.Sizes.globalPillHeight)
            .clip(CircleShape)
            .background(Tokens.Colors.globalControlOnDeep, CircleShape)
            .padding(start = Tokens.Sizes.globalPillPaddingLeading, end = Tokens.Sizes.globalPillPaddingTrailing),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(text, style = TextRoles.pill, color = Tokens.Colors.globalTextOnMedia, maxLines = 1)
    }
}

/**
 * The selfie rows of the Reactions sheet (`viewer.selfiereaction` §4), placed among the emoji rows by time: C-16 people
 * row with the selfie as the avatar (`size.global.avatarPicker`, circle), the line `viewer.selfiereaction.activity.row` /
 * `.activity.rowMine` (`listTitle`), your row adding `chat.reactions.list.removeHint`. Your row: tap → remove. Long press
 * (and TalkBack custom actions): on your own photo `viewer.selfiereaction.menu.remove` (→ the confirmation); on a row that is
 * not yours `viewer.selfiereaction.menu.report` (→ `safety.report`). Labels `viewer.selfiereaction.a11y.face` / `.faceMine`.
 */
@Composable
fun selfieSheetRows(
    selfies: List<SelfieEntry>,
    me: String?,
    myPhoto: Boolean,
    firstName: (String) -> String,
    menuOpen: String?,
    onMenu: (String?) -> Unit,
    onRemoveMine: () -> Unit,
    onAskRemove: (String) -> Unit,
    onReport: (SelfieEntry) -> Unit,
): List<ReactionsSheetRow> {
    val remove = stringRes(R.string.viewer_selfiereaction_menu_remove)
    val report = stringRes(R.string.viewer_selfiereaction_menu_report)
    return selfies.map { entry ->
        ReactionsSheetRow(key = "selfie:" + entry.userId, at = entry.createdAt) {
            val mine = entry.userId == me
            val items = buildList {
                if (myPhoto && entry.id != null) add(DsMenuItem(remove, { onAskRemove(entry.userId) }, destructive = true))
                if (!mine && entry.id != null) add(DsMenuItem(report, { onReport(entry) }, Tokens.Icons.globalReport, destructive = true))
            }
            SelfieSheetRow(
                entry = entry,
                name = firstName(entry.userId),
                mine = mine,
                items = items,
                menuOpen = menuOpen == entry.userId,
                onTap = if (mine && entry.id != null) onRemoveMine else null,
                onMenu = { onMenu(entry.userId) },
                onDismissMenu = { onMenu(null) },
            )
        }
    }
}

@OptIn(ExperimentalFoundationApi::class)
@Composable
private fun SelfieSheetRow(
    entry: SelfieEntry,
    name: String,
    mine: Boolean,
    items: List<DsMenuItem>,
    menuOpen: Boolean,
    onTap: (() -> Unit)?,
    onMenu: () -> Unit,
    onDismissMenu: () -> Unit,
) {
    val line = if (mine) stringRes(R.string.viewer_selfiereaction_activity_rowmine) else stringRes(R.string.viewer_selfiereaction_activity_row, name)
    val label = if (mine) stringRes(R.string.viewer_selfiereaction_a11y_facemine) else stringRes(R.string.viewer_selfiereaction_a11y_face, name)
    Box {
        Row(
            Modifier
                .fillMaxWidth()
                .then(
                    if (onTap != null || items.isNotEmpty()) {
                        Modifier.tapLongPressable(onClick = onTap, onLongClick = { if (items.isNotEmpty()) onMenu() }, menuActions = items.map { it.text to it.onClick })
                    } else {
                        Modifier
                    },
                )
                .clearAndSetSemantics {
                    contentDescription = label
                    if (onTap != null) role = Role.Button
                    if (items.isNotEmpty()) customActions = items.map { i -> CustomAccessibilityAction(i.text) { i.onClick(); true } }
                }
                .padding(horizontal = Tokens.Sizes.globalScreenMargin)
                .testTag("selfie.row.${entry.userId}"),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Avatar(selfieImage(entry), Tokens.Sizes.globalAvatarPicker)
            Spacer(Modifier.width(Tokens.Sizes.chatThreadDimensionRowAvatarToText))
            Column(Modifier.weight(1f)) {
                Text(line, style = TextRoles.listTitle, color = Tokens.Colors.globalTextPrimary, maxLines = 1)
                if (mine) Text(stringRes(R.string.chat_reactions_list_removehint), style = TextRoles.listSubtitle, color = PageRoles.secondaryText())
            }
        }
        DsDropdownMenu(menuOpen, onDismissMenu, items)
    }
}
