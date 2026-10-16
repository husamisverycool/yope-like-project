// Pieces shared by the capture screens on Retro's media surface (camera.capture, camera.sendto,
// daily.capture, daily.dualimage, collage.view): compositions of the core:ui components (C-05, C-06,
// C-09, C-11, C-27, C-28) plus the controls Retro has no component for (the Locket shutter, the
// recording outline, the BeReal dual image). Decisions: design/MERGE_DECISIONS.md RC-1 … RC-13.
// References: references/auto/retro/store/retro-store-03.png (ST-03: header, circles on media, pill on a
// photo, white capsule), references/auto/retro/press/tc-2025-12-rewind-device-a.png (C-35 control row).
package app.feature.capture.ui

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.Crossfade
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.gestures.awaitEachGesture
import androidx.compose.foundation.gestures.awaitFirstDown
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.gestures.waitForUpOrCancellation
import androidx.compose.foundation.indication
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.PressInteraction
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.asPaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.paddingFrom
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.material3.ripple
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.PathMeasure
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.painter.Painter
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.layout.FirstBaseline
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.CustomAccessibilityAction
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.customActions
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.onClick
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.max
import app.designsystem.generated.Tokens
import app.ui.components.EmptyState
import app.ui.components.EmptyStateAction
import app.ui.foundation.DsMotion
import app.ui.foundation.centreAt
import app.ui.foundation.tapClickable
import app.ui.haptics.rememberHaptics
import app.ui.text.CapTop
import app.ui.text.TextRoles
import app.ui.theme.AppTheme
import kotlinx.coroutines.delay

/**
 * Media surfaces are black in both appearances and "themed tokens used on media take their dark value"
 * (MERGE_DECISIONS RC-1, `layout.global.appearance.media`). Components without an on-media variant (C-27
 * [EmptyState], C-29 check circle, C-05 disabled capsule, C-23 placeholder fill) are drawn inside this scope,
 * where every colour token resolves to its dark value. Sheets and alerts opened from a media screen stay
 * outside it and follow the appearance.
 */
@Composable
internal fun OnMedia(content: @Composable () -> Unit) = AppTheme(dark = true, content = content)

/**
 * Media screens show light status- and navigation-bar content in both appearances (camera.capture → Structure:
 * "status bar light content"; the app's edge-to-edge style otherwise follows the appearance). Restores the
 * previous style when the screen leaves.
 */
@Composable
internal fun MediaSystemBars() {
    val view = androidx.compose.ui.platform.LocalView.current
    androidx.compose.runtime.DisposableEffect(view) {
        var context = view.context
        while (context is android.content.ContextWrapper && context !is android.app.Activity) context = context.baseContext
        val window = (context as? android.app.Activity)?.window ?: return@DisposableEffect onDispose { }
        val bars = androidx.core.view.WindowCompat.getInsetsController(window, view)
        val status = bars.isAppearanceLightStatusBars
        val navigation = bars.isAppearanceLightNavigationBars
        bars.isAppearanceLightStatusBars = false
        bars.isAppearanceLightNavigationBars = false
        onDispose {
            bars.isAppearanceLightStatusBars = status
            bars.isAppearanceLightNavigationBars = navigation
        }
    }
}

/** OpenType tabular figures: the countdown's and durations' monospaced digits. */
internal const val TABULAR_DIGITS = "tnum" // provenance-ok: OpenType feature tag, not a design value

/** The space a bottom-anchored element keeps from the screen bottom: [token] (measured on iPhone) but never under the navigation bar. */
@Composable
internal fun bottomClearance(token: Dp): Dp = max(token, WindowInsets.navigationBars.asPaddingValues().calculateBottomPadding())

/**
 * The sheet header on the black composer (`camera.sendto.layout.header`, shared by daily.capture): the
 * circles' centre line `centreBelowSafeArea` (25.8) below the safe-area top; [title] centred with its cap
 * middle on that line; [trailing] / [leading] C-11 circles on media (`size.global.circleButton`,
 * `color.global.controlOnDeep`), centres 37.7 from the edges. The element ends at the circles' bottom edge
 * (the content below adds `camera.sendto.layout.preview.topBelowHeaderCircle`).
 */
@Composable
internal fun MediaSheetHeader(
    modifier: Modifier = Modifier,
    leading: (@Composable () -> Unit)? = null,
    trailing: (@Composable () -> Unit)? = null,
    title: @Composable (capMiddleTop: Dp) -> Unit,
) {
    val centre = Dp(Tokens.Layouts.CameraSendtoLayoutHeader.centreBelowSafeArea)
    val circle = Tokens.Sizes.globalCircleButton
    // "close circle centre 37.7 pt from the trailing edge" (ST-03): the trailing text of the token.
    val edgeToCentre = Dp(Tokens.Layouts.CollageViewLayoutScreen.closeCentreFromTrailing)
    Box(modifier.fillMaxWidth().heightIn(min = centre + circle / 2)) {
        Box(Modifier.align(Alignment.TopCenter).padding(horizontal = edgeToCentre + circle / 2)) { title(centre) }
        if (leading != null) Box(Modifier.align(Alignment.TopStart).padding(start = edgeToCentre - circle / 2).centreAt(centre)) { leading() }
        if (trailing != null) Box(Modifier.align(Alignment.TopEnd).padding(end = edgeToCentre - circle / 2).centreAt(centre)) { trailing() }
    }
}

/** A single-line title whose cap middle sits [capMiddle] below the top of its slot (text role `sheetTitle`). */
@Composable
internal fun SheetTitleText(text: String, capMiddle: Dp, color: Color, modifier: Modifier = Modifier, style: TextStyle = TextRoles.sheetTitle) {
    Text(
        text,
        style = style,
        color = color,
        textAlign = TextAlign.Center,
        maxLines = 1,
        modifier = modifier
            .paddingFrom(FirstBaseline, before = capMiddle + CapTop.height(style) / 2)
            .semantics { heading() },
    )
}

/**
 * C-11 64-pt circle on media (camera.capture library / flip, daily.capture flash / flip):
 * `size.global.circleButtonLarge`, fill `color.global.controlOnDeep`, glyph `color.global.textOnMedia` in the
 * `size.global.icon` box. core:ui's [app.ui.components.CircleButtonStyle] has 64 only as glass (reported gap),
 * so the same anatomy is composed here. [stateDescription]: on / off for the flash. Glyph changes cross-fade
 * (`duration.global.crossfade`). Pressed: platform default + `haptic.global.tap`.
 */
@Composable
internal fun MediaControlCircle(
    icon: ImageVector,
    contentDescription: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    stateDescription: String? = null,
) {
    Box(
        modifier
            .size(Tokens.Sizes.globalCircleButtonLarge)
            .clip(CircleShape)
            .background(Tokens.Colors.globalControlOnDeep, CircleShape)
            .tapClickable(onClick = onClick)
            .semantics {
                this.contentDescription = contentDescription
                if (stateDescription != null) this.stateDescription = stateDescription
            },
        contentAlignment = Alignment.Center,
    ) {
        Crossfade(icon, animationSpec = DsMotion.crossfade(), label = "circleGlyph") { glyph ->
            Icon(glyph, contentDescription = null, tint = Tokens.Colors.globalTextOnMedia, modifier = Modifier.size(Tokens.Sizes.globalIcon))
        }
    }
}

/**
 * The C-35 control row (`camera.capture.layout.controlRow`): [centre] (the shutter) horizontally centred,
 * [leading] / [trailing] each centred in the free space between the screen edge and the shutter's outer
 * edge (Retro's Rewind rule: 76.8 pt from the edge on 393).
 */
@Composable
internal fun ControlRow(
    modifier: Modifier = Modifier,
    leading: (@Composable () -> Unit)? = null,
    trailing: (@Composable () -> Unit)? = null,
    centre: @Composable () -> Unit,
) {
    BoxWithConstraints(modifier.fillMaxWidth(), contentAlignment = Alignment.Center) {
        val side = (maxWidth - Tokens.Sizes.cameraCaptureSizeShutterOuter) / 2
        centre()
        if (leading != null) Box(Modifier.align(Alignment.CenterStart).width(side), contentAlignment = Alignment.Center) { leading() }
        if (trailing != null) Box(Modifier.align(Alignment.CenterEnd).width(side), contentAlignment = Alignment.Center) { trailing() }
    }
}

/**
 * The shutter (mechanics: Locket; colours Retro — RC-3): outer `camera.capture.size.shutterOuter` (86), ring
 * `.shutterRing` (4.5) in `color.global.surfaceLight`, the gap in `color.global.backgroundDeep`, disc
 * `.shutterDisc` (70) in `color.global.surfaceLight`. The gap token (3) does not add up with the other three
 * (86 − 2 × 4.5 − 70 = 7 → 3.5 a side): outer, ring and disc are honoured.
 */
@Composable
internal fun ShutterDisc(modifier: Modifier = Modifier) {
    val outer = Tokens.Sizes.cameraCaptureSizeShutterOuter
    Box(modifier.size(outer), contentAlignment = Alignment.Center) {
        Box(
            Modifier
                .size(outer)
                .clip(CircleShape)
                .background(Tokens.Colors.globalBackgroundDeep)
                .border(Tokens.Sizes.cameraCaptureSizeShutterRing, Tokens.Colors.globalSurfaceLight, CircleShape),
        )
        Box(Modifier.size(Tokens.Sizes.cameraCaptureSizeShutterDisc).clip(CircleShape).background(Tokens.Colors.globalSurfaceLight))
    }
}

/**
 * The shutter as a control: tap → [onTap]; with [onHoldStart] a hold records until release ([onHoldEnd]).
 * Press = platform default (ripple, RC-3 "no custom scale"); `haptic.global.shutter` is none (camera rule).
 * TalkBack: [label] button; [holdActionLabel] adds the custom action that starts / stops a recording.
 */
@Composable
internal fun Shutter(
    label: String,
    onTap: () -> Unit,
    modifier: Modifier = Modifier,
    onHoldStart: (() -> Unit)? = null,
    onHoldEnd: (() -> Unit)? = null,
    holdActionLabel: String? = null,
    holding: Boolean = false,
) {
    val interaction = remember { MutableInteractionSource() }
    Box(
        modifier
            .size(Tokens.Sizes.cameraCaptureSizeShutterOuter)
            .indication(interaction, ripple(bounded = false, radius = Tokens.Sizes.cameraCaptureSizeShutterOuter / 2))
            .pointerInput(onHoldStart != null) {
                detectTapGestures(
                    onPress = { offset ->
                        val press = PressInteraction.Press(offset)
                        interaction.emit(press)
                        val released = tryAwaitRelease()
                        interaction.emit(if (released) PressInteraction.Release(press) else PressInteraction.Cancel(press))
                        onHoldEnd?.invoke()
                    },
                    onTap = { onTap() },
                    onLongPress = if (onHoldStart != null) ({ onHoldStart() }) else null,
                )
            }
            .semantics {
                contentDescription = label
                role = Role.Button
                onClick { onTap(); true }
                if (holdActionLabel != null && onHoldStart != null) {
                    customActions = listOf(
                        CustomAccessibilityAction(holdActionLabel) {
                            if (holding) onHoldEnd?.invoke() else onHoldStart()
                            true
                        },
                    )
                }
            },
    ) {
        ShutterDisc()
    }
}

/**
 * The recording outline (`camera.capture.size.recordingOutline` 6 in `color.global.surfaceLight`): a progress
 * stroke tracing the viewfinder's rounded outline (`radius.global.viewfinder`) from empty to full, linearly over
 * `camera.capture.duration.videoMax` (progress, so unchanged under Reduce Motion). Starts after the top-leading
 * corner and runs clockwise, inside the edge.
 */
@Composable
internal fun RecordingOutline(recording: Boolean, modifier: Modifier = Modifier) {
    val progress = remember { androidx.compose.animation.core.Animatable(0f) }
    LaunchedEffect(recording) {
        progress.snapTo(0f)
        if (recording) {
            progress.animateTo(1f, androidx.compose.animation.core.tween(Tokens.Durations.cameraCaptureDurationVideoMax, easing = androidx.compose.animation.core.LinearEasing))
        }
    }
    if (!recording) return
    val color = Tokens.Colors.globalSurfaceLight
    Canvas(modifier.fillMaxSize().testTag("camera.recordingOutline")) {
        val stroke = Tokens.Sizes.cameraCaptureSizeRecordingOutline.toPx()
        val path = roundedOutline(size.width, size.height, Tokens.Radii.globalViewfinder.toPx(), stroke / 2)
        val measure = PathMeasure().apply { setPath(path, false) }
        val traced = Path()
        // At least a hairline of progress so the start is visible in the first frame.
        measure.getSegment(0f, measure.length * progress.value.coerceAtLeast(MIN_PROGRESS), traced, true)
        drawPath(traced, color, style = Stroke(width = stroke))
    }
}

private const val MIN_PROGRESS = 0.0001f // provenance-ok: avoids an empty path at t = 0, invisible

/** The viewfinder outline inset by [inset] (half the stroke), clockwise from the top edge's start. */
private fun roundedOutline(width: Float, height: Float, radius: Float, inset: Float): Path {
    val l = inset
    val t = inset
    val r = width - inset
    val b = height - inset
    val c = (radius - inset).coerceAtLeast(0f)
    val d = c * 2
    return Path().apply {
        moveTo(l + c, t)
        lineTo(r - c, t)
        arcTo(androidx.compose.ui.geometry.Rect(r - d, t, r, t + d), ARC_TOP, ARC_SWEEP, false)
        lineTo(r, b - c)
        arcTo(androidx.compose.ui.geometry.Rect(r - d, b - d, r, b), ARC_RIGHT, ARC_SWEEP, false)
        lineTo(l + c, b)
        arcTo(androidx.compose.ui.geometry.Rect(l, b - d, l + d, b), ARC_BOTTOM, ARC_SWEEP, false)
        lineTo(l, t + c)
        arcTo(androidx.compose.ui.geometry.Rect(l, t, l + d, t + d), ARC_LEFT, ARC_SWEEP, false)
        close()
    }
}

// Arc start angles (degrees, clockwise from 3 o'clock) for the four quarter-circle corners.
private const val ARC_TOP = 270f // provenance-ok: geometry (quarter-circle corner)
private const val ARC_RIGHT = 0f // provenance-ok: geometry (quarter-circle corner)
private const val ARC_BOTTOM = 90f // provenance-ok: geometry (quarter-circle corner)
private const val ARC_LEFT = 180f // provenance-ok: geometry (quarter-circle corner)
private const val ARC_SWEEP = 90f // provenance-ok: geometry (quarter-circle corner)

/** Moved to core:ui (`app.ui.media.DualImage`, shared with social's viewer and chat); this forwards to it. */
@Deprecated("Use app.ui.media.DualImage", ReplaceWith("app.ui.media.DualImage(main, inset, contentDescription, modifier, cornerRadius, loadingFill)"))
@Composable
internal fun DualImage(
    main: Painter?,
    inset: Painter?,
    contentDescription: String?,
    modifier: Modifier = Modifier,
    cornerRadius: Dp? = null,
    loadingFill: Color = Tokens.Colors.globalBackgroundDeep,
) = app.ui.media.DualImage(main, inset, contentDescription, modifier, cornerRadius, loadingFill)

/** [painter] aspect-filled, fading in with `duration.global.fade` when it arrives. */
@Composable
internal fun FadeImage(painter: Painter?, modifier: Modifier = Modifier) {
    androidx.compose.animation.AnimatedVisibility(visible = painter != null, enter = DsMotion.fadeIn, exit = DsMotion.fadeOut, modifier = modifier) {
        var last by remember { mutableStateOf(painter) }
        if (painter != null) last = painter
        last?.let { Image(it, contentDescription = null, contentScale = ContentScale.Crop, modifier = Modifier.fillMaxSize()) }
    }
}

/**
 * A C-09 dark pill used as a label (daily.capture audience pill: "not interactive"): the C-09 dark geometry
 * (`size.global.pillHeight`, `pillPaddingLeading` → `iconSmall` glyph → `pillIconGap` → label → `pillPaddingTrailing`,
 * fill `color.global.controlOnDeep`, text role `pill` in `color.global.textOnMedia`) without the button.
 * core:ui `MediaPill` is always a button (reported gap). Read as text.
 */
@Composable
internal fun MediaLabelPill(text: String, icon: ImageVector, modifier: Modifier = Modifier) {
    Row(
        modifier
            .heightIn(min = Tokens.Sizes.globalPillHeight)
            .clip(CircleShape)
            .background(Tokens.Colors.globalControlOnDeep, CircleShape)
            .clearAndSetSemantics { contentDescription = text }
            .padding(PaddingValues(start = Tokens.Sizes.globalPillPaddingLeading, end = Tokens.Sizes.globalPillPaddingTrailing)),
        horizontalArrangement = Arrangement.spacedBy(Tokens.Sizes.globalPillIconGap),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(icon, contentDescription = null, tint = Tokens.Colors.globalTextOnMedia, modifier = Modifier.size(Tokens.Sizes.globalIconSmall))
        Text(text, style = TextRoles.pill, color = Tokens.Colors.globalTextOnMedia, maxLines = 1)
    }
}

/**
 * C-27 on media (camera denied / unavailable, send-to empty, collage empty): the [EmptyState] drawn with the
 * media colours (title `color.global.textOnMedia`, detail `color.global.textSecondary`, outline capsule border
 * and label `color.global.textOnMedia`).
 */
@Composable
internal fun MediaEmptyState(title: String, detail: String?, action: EmptyStateAction?, icon: ImageVector?, modifier: Modifier = Modifier) {
    OnMedia { EmptyState(title, detail, modifier, action = action, icon = icon) }
}

/**
 * C-28 + C-27 title on media (daily.capture "Taking the front photo…", collage.view "Creating your collage…"):
 * the platform activity indicator in `color.global.textOnMedia`, `size.global.emptyIconToTitle` to the line's
 * cap top, the line in text role `emptyTitle`, `color.global.textOnMedia`, centred. Announced politely.
 */
@Composable
internal fun MediaProgressBlock(text: String, modifier: Modifier = Modifier) {
    val style = TextRoles.emptyTitle
    Column(modifier.padding(horizontal = Tokens.Sizes.globalScreenMargin), horizontalAlignment = Alignment.CenterHorizontally) {
        CircularProgressIndicator(color = Tokens.Colors.globalTextOnMedia)
        Text(
            text,
            style = style,
            color = Tokens.Colors.globalTextOnMedia,
            textAlign = TextAlign.Center,
            modifier = Modifier
                .paddingFrom(FirstBaseline, before = Tokens.Sizes.globalEmptyIconToTitle + CapTop.height(style))
                .semantics { this.contentDescription = text },
        )
    }
}

/**
 * Text whose changed characters cross-fade (`duration.global.crossfade`) — the countdown's digits (monospaced,
 * so nothing shifts) and its hand-over to the group name (RC-13: Retro's house motion, not BeReal's digit roll).
 */
@Composable
internal fun CrossfadeText(text: String, style: TextStyle, color: Color, modifier: Modifier = Modifier) {
    Row(modifier) {
        text.forEachIndexed { index, char ->
            AnimatedContent(
                targetState = char,
                transitionSpec = { fadeIn(DsMotion.crossfade()) togetherWith fadeOut(DsMotion.crossfade()) },
                label = "char$index", // provenance-ok: animation debug label (tooling only)
            ) { c -> Text(c.toString(), style = style, color = color, maxLines = 1) }
        }
    }
}

/** Ticks [now] once a second while composed (recording timers). */
@Composable
internal fun rememberTicker(running: Boolean, now: () -> Long): Long {
    var value by remember { mutableLongStateOf(now()) }
    LaunchedEffect(running) {
        while (running) {
            value = now()
            delay(TICK_MS)
        }
    }
    return value
}

private const val TICK_MS = 1000L // provenance-ok: whole-second timer resolution

/** `chat.voice.layout.durationFormat` ("m:ss", "0:38"). */
internal fun voiceDuration(ms: Long): String {
    val seconds = (ms / MILLIS_PER_SECOND).coerceAtLeast(0)
    return String.format(java.util.Locale.ROOT, VOICE_DURATION_FORMAT, seconds / SECONDS_PER_MINUTE, seconds % SECONDS_PER_MINUTE)
}

private const val MILLIS_PER_SECOND = 1000L // provenance-ok: unit conversion
private const val SECONDS_PER_MINUTE = 60L // provenance-ok: unit conversion
private const val VOICE_DURATION_FORMAT = "%d:%02d" // provenance-ok: chat.voice.layout.durationFormat pattern m:ss

/** The hold gestures of [VoiceCapsule] (down starts, release keeps, cancel discards). */
interface VoiceGestures {
    fun down()
    fun release()
    fun cancel()

    companion object {
        val None = object : VoiceGestures {
            override fun down() = Unit
            override fun release() = Unit
            override fun cancel() = Unit
        }
    }
}

/**
 * The voice capsule on the photo (`camera.sendto.layout.messageField.voice`): C-06 icon-only geometry —
 * `size.global.iconPillWidth` × `size.global.pillHeight`, capsule, fill `color.global.controlOnDeep`,
 * `icon.global.mic` (`size.global.iconSmall`) in `color.global.textOnMedia`. Recording (`chat.voice` mechanics:
 * press and hold, release keeps it, slide left past one capsule width discards): the C-07 anatomy with the mic
 * in `color.global.destructive` and the elapsed time (`chat.voice.layout.durationFormat`, text role `pill`,
 * monospaced digits). With a note: the mic and its length in `color.global.textOnMedia`. TalkBack cannot hold:
 * activating starts a hands-free recording and activating again keeps it ([onA11yToggle]); [onNoteTap]
 * (a recorded note) opens the note's menu. core:ui `IconCapsule` has no on-media fill (reported gap).
 */
@Composable
internal fun VoiceCapsule(
    recording: Boolean,
    recordingStartedAt: Long?,
    noteDurationMs: Int?,
    label: String,
    gestures: VoiceGestures,
    onA11yToggle: () -> Unit,
    onNoteTap: () -> Unit,
    now: () -> Long,
    modifier: Modifier = Modifier,
) {
    val haptics = rememberHaptics()
    val tick = rememberTicker(recording, now)
    val elapsed = if (recording && recordingStartedAt != null) tick - recordingStartedAt else null
    val showsText = recording || noteDurationMs != null
    val density = androidx.compose.ui.platform.LocalDensity.current
    val threshold = with(density) { Tokens.Sizes.globalIconPillWidth.toPx() }
    Row(
        modifier
            .heightIn(min = Tokens.Sizes.globalPillHeight)
            .then(if (showsText) Modifier else Modifier.widthIn(min = Tokens.Sizes.globalIconPillWidth))
            .clip(CircleShape)
            .background(Tokens.Colors.globalControlOnDeep, CircleShape)
            .pointerInput(noteDurationMs != null && !recording) {
                awaitEachGesture {
                    val down = awaitFirstDown()
                    haptics.tap()
                    if (noteDurationMs != null && !recording) {
                        if (waitForUpOrCancellation() != null) onNoteTap()
                        return@awaitEachGesture
                    }
                    gestures.down()
                    var settled = false
                    while (true) {
                        val event = awaitPointerEvent()
                        val change = event.changes.firstOrNull { it.id == down.id } ?: break
                        change.consume()
                        if (!settled && change.position.x - down.position.x < -threshold) {
                            gestures.cancel()
                            settled = true
                        }
                        if (!change.pressed) {
                            if (!settled) gestures.release()
                            break
                        }
                    }
                }
            }
            .semantics {
                contentDescription = label
                role = Role.Button
                if (noteDurationMs != null) stateDescription = voiceDuration(noteDurationMs.toLong())
                onClick { if (noteDurationMs != null && !recording) onNoteTap() else onA11yToggle(); true }
            }
            .then(if (showsText) Modifier.padding(PaddingValues(start = Tokens.Sizes.globalPillPaddingLeading, end = Tokens.Sizes.globalPillPaddingTrailing)) else Modifier)
            .testTag(if (recording) "sendto.voice.recording" else if (noteDurationMs != null) "sendto.voice.attached" else "sendto.voice"),
        horizontalArrangement = Arrangement.spacedBy(Tokens.Sizes.globalPillIconGap, Alignment.CenterHorizontally),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(
            Tokens.Icons.globalMic,
            contentDescription = null,
            tint = if (recording) Tokens.Colors.globalDestructive else Tokens.Colors.globalTextOnMedia,
            modifier = Modifier.size(Tokens.Sizes.globalIconSmall),
        )
        if (showsText) {
            Text(
                voiceDuration(elapsed ?: noteDurationMs?.toLong() ?: 0L),
                style = TextRoles.pill.copy(fontFeatureSettings = TABULAR_DIGITS),
                color = Tokens.Colors.globalTextOnMedia,
                maxLines = 1,
            )
        }
    }
}
