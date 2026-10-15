// Surface: camera.sendto.
// References: references/auto/yope/frames/a-chuongxetank-7694968408424582452-t6.73-sendto-voice-tooltip.png (header, preview
// card, message field + mic, voice coach, recipient rows, 'send ⓝ'); a-savannahclooney-7683341732695592206-t5.73-sendto-caption-keyboard.png
// (caption on the photo, keyboard); a-jacob-7691153057177931039-t4.73-sendto-voice-tooltip.png;
// a-virgi-7686278541255642390-t56.23-sendto-three-selected-es.png; a-chuongxetank-…-t7.73-posted-toast-contacts-card.png (toast).
package app.feature.capture.sendto

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.selection.toggleable
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicText
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.foundation.gestures.awaitEachGesture
import androidx.compose.foundation.gestures.awaitFirstDown
import androidx.compose.foundation.gestures.waitForUpOrCancellation
import androidx.compose.foundation.layout.Column
import androidx.compose.material.icons.rounded.ExpandLess
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.semantics.onClick
import app.feature.capture.ui.glyphTopToBaseline
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.isTraversalGroup
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.traversalIndex
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import app.data.model.Group
import app.feature.capture.Blocked
import app.designsystem.R
import app.designsystem.generated.Tokens
import app.feature.capture.ui.CaptureText
import app.feature.capture.ui.CapsuleShape
import app.feature.capture.ui.CircleIconButton
import app.feature.capture.ui.CoachTooltip
import app.feature.capture.ui.EmptyStateBlock
import app.feature.capture.ui.Glyph
import app.feature.capture.ui.LimeToast
import app.feature.capture.ui.MinTouchTargets
import app.feature.capture.ui.haptic
import app.ui.components.Avatar
import app.ui.components.CheckCircle
import app.ui.components.HeaderCircleButton
import app.ui.components.HeaderCircleFill
import java.io.File
import kotlin.math.max

/** Everything the stateless screen needs besides the view model's state. */
data class SendToChrome(
    /** The capture as an image (photo, or a video's frame). */
    val preview: ImageBitmap?,
    /** `camera.capture.hourOverlay` text. */
    val hourText: String,
    /** Signed cover URLs by group id (rows show `icon.global.group` without one). */
    val covers: Map<String, Any?> = emptyMap(),
)

/**
 * The send-to screen (stateless). Full height on `color.global.backgroundDeep`; positions from
 * the screen top per `camera.sendto.layout.*`.
 */
@Composable
fun SendToScreen(
    state: SendToViewModel.UiState,
    chrome: SendToChrome,
    onClose: () -> Unit,
    onSave: () -> Unit,
    onCaption: (String) -> Unit,
    onMic: () -> Unit,
    onVoiceCoachClose: () -> Unit,
    onToggle: (String) -> Unit,
    onSend: () -> Unit,
    onCreateGroup: () -> Unit,
    onRetryGroups: () -> Unit,
    modifier: Modifier = Modifier,
    videoPreview: (@Composable () -> Unit)? = null,
    voiceGestures: VoiceGestures = VoiceGestures.None,
    now: () -> Long = android.os.SystemClock::elapsedRealtime,
) = MinTouchTargets {
    val view = LocalView.current
    var captionFocused by remember { mutableStateOf(false) }
    val captionFocus = remember { FocusRequester() }
    val preview = Tokens.Layouts.CameraSendtoLayoutPreview
    val header = Tokens.Sizes.globalHeaderButton
    // The header circles' centre line sits gapBelowHeader above the card.
    val headerTop = preview.top.dp - preview.gapBelowHeader.dp - header

    BoxWithConstraints(
        modifier
            .fillMaxSize()
            .background(Tokens.Colors.globalBackgroundDeep)
            .semantics { isTraversalGroup = true }
            .testTag("camera.sendto"),
    ) {
        val width = maxWidth
        // Header: ✕ · title · download.
        Box(Modifier.fillMaxWidth().padding(top = headerTop).height(header)) {
            HeaderCircleButton(
                icon = Tokens.Icons.globalClose,
                contentDescription = stringResource(R.string.camera_sendto_a11y_close),
                onClick = onClose,
                fill = HeaderCircleFill.OnDeep,
                modifier = Modifier.align(Alignment.CenterStart).padding(start = Tokens.Sizes.globalHeaderInset).semantics { traversalIndex = 0f }.testTag("sendto.close"),
            )
            BasicText(
                stringResource(R.string.camera_sendto_title),
                style = CaptureText.sheetTitle.merge(TextStyle(color = Tokens.Colors.globalTextPrimary)),
                modifier = Modifier.align(Alignment.Center).semantics { traversalIndex = 1f }.testTag("sendto.title"),
            )
            HeaderCircleButton(
                icon = Tokens.Icons.globalDownload,
                contentDescription = stringResource(R.string.camera_sendto_a11y_save),
                onClick = onSave,
                fill = HeaderCircleFill.OnDeep,
                modifier = Modifier.align(Alignment.CenterEnd).padding(end = Tokens.Sizes.globalHeaderInset).semantics { traversalIndex = 2f }.testTag("sendto.save"),
            )
        }

        // Preview card.
        val cardW = preview.width.dp
        val cardH = preview.height.dp
        Box(
            Modifier
                .offset(x = (width - cardW) / 2, y = preview.top.dp)
                .size(cardW, cardH)
                .clip(RoundedCornerShape(Tokens.Radii.globalPhoto))
                .background(Tokens.Colors.globalBackgroundDeep)
                .testTag("sendto.preview"),
        ) {
            if (videoPreview != null) {
                Box(Modifier.fillMaxSize().clearAndSetSemantics { }) { videoPreview() }
            } else if (chrome.preview != null) {
                // The member's own photo: decorative in this flow.
                Image(chrome.preview, contentDescription = null, contentScale = ContentScale.Crop, modifier = Modifier.fillMaxSize())
            }
            CaptionOverlay(
                hourText = chrome.hourText,
                caption = state.caption,
                onCaption = onCaption,
                focusRequester = captionFocus,
                onFocus = { captionFocused = it },
                placeholder = stringResource(R.string.camera_sendto_caption_placeholder),
            )
            // Bottom row: message field + mic (fill camera.sendto.color.messageField is BLOCKED: no fill).
            if (!captionFocused) {
                MessageRow(
                    state = state,
                    onField = { captionFocus.requestFocus() },
                    onLockedFinish = onMic,
                    gestures = voiceGestures,
                    now = now,
                )
            }
        }
        if (state.voiceCoachVisible && state.micAvailable && !captionFocused) {
            VoiceCoach(cardLeft = (width - cardW) / 2, cardTop = preview.top.dp, onClose = onVoiceCoachClose)
        }

        // Recipients.
        val row = Tokens.Layouts.CameraSendtoLayoutRecipientRow
        val listTop = preview.top.dp + cardH + row.firstRowCenterBelowPreview.dp - row.pitch.dp / 2
        val buttonArea = Tokens.Sizes.globalButtonHeightSheet + Tokens.Sizes.cameraSendtoSizeSendButtonBottom
        Box(Modifier.fillMaxSize().padding(top = listTop, bottom = buttonArea)) {
            when (val groups = state.groups) {
                SendToViewModel.Groups.Loading -> CircularProgressIndicator(
                    color = Tokens.Colors.globalTextPrimary,
                    modifier = Modifier.align(Alignment.Center).testTag("sendto.loading"),
                )
                SendToViewModel.Groups.Empty -> EmptyStateBlock(
                    title = stringResource(R.string.camera_sendto_empty_title),
                    detail = stringResource(R.string.camera_sendto_empty_detail),
                    buttonLabel = stringResource(R.string.camera_sendto_empty_button),
                    onButton = onCreateGroup,
                    modifier = Modifier.align(Alignment.Center),
                )
                is SendToViewModel.Groups.Failed -> Unit // the error toast below carries "try again"
                is SendToViewModel.Groups.Loaded -> LazyColumn(Modifier.fillMaxSize().testTag("sendto.rows"), contentPadding = PaddingValues()) {
                    items(state.visibleGroups, key = { it.id }) { group ->
                        RecipientRow(
                            group = group,
                            cover = chrome.covers[group.id],
                            selected = group.id in state.selected,
                            onToggle = {
                                view.haptic(Tokens.Haptics.globalSelect)
                                onToggle(group.id)
                            },
                        )
                    }
                }
            }
        }

        // Send button.
        if (state.sendVisible) {
            SendButton(
                count = state.selected.size,
                onClick = onSend,
                modifier = Modifier
                    .align(Alignment.BottomCenter)
                    .padding(
                        start = Tokens.Sizes.globalButtonMarginHSheet,
                        end = Tokens.Sizes.globalButtonMarginHSheet,
                        bottom = Tokens.Sizes.cameraSendtoSizeSendButtonBottom,
                    )
                    .semantics { traversalIndex = 10f },
            )
        }

        // Errors that keep the capture: queueing failed, or the group list could not load.
        val failedGroups = state.groups as? SendToViewModel.Groups.Failed
        if (state.sendError != null || failedGroups != null) {
            val offline = failedGroups?.offline == true || state.sendError == app.data.error.DataError.Network
            Box(Modifier.fillMaxWidth().padding(top = Tokens.Layouts.CameraSendtoLayoutToast.top.dp).testTag("sendto.error")) {
                LimeToast(
                    text = stringResource(if (offline) R.string.camera_sendto_error_offline else R.string.camera_sendto_error_sendfailed),
                    actionLabel = stringResource(R.string.camera_sendto_error_retry),
                    onAction = if (failedGroups != null) onRetryGroups else onSend,
                    modifier = Modifier.testTag("sendto.toast"),
                )
            }
        }
    }
}

/** Hour overlay centred on the card and, under it, the caption as typed (wraps within the card). */
@Composable
private fun CaptionOverlay(
    hourText: String,
    caption: String,
    onCaption: (String) -> Unit,
    focusRequester: FocusRequester,
    onFocus: (Boolean) -> Unit,
    placeholder: String,
) {
    val overlayStyle = CaptureText.overlayTimeCamera.merge(TextStyle(color = Tokens.Colors.globalTextPrimary, textAlign = TextAlign.Center))
    val captionStyle = CaptureText.style(Tokens.FontSizes.cameraSendtoFontSizeCaption, Tokens.FontWeights.cameraSendtoFontWeightCaption)
        .merge(TextStyle(color = Tokens.Colors.globalTextPrimary, textAlign = TextAlign.Center))
    Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
        BasicText(hourText, style = overlayStyle, modifier = Modifier.clearAndSetSemantics { })
        // Caption baseline camera.sendto.size.captionBaselineOffset below the overlay baseline.
        BasicTextField(
            value = caption,
            onValueChange = onCaption,
            textStyle = captionStyle,
            cursorBrush = SolidColor(Tokens.Colors.globalTextPrimary),
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = Tokens.Layouts.CameraSendtoLayoutMessageField.insetLeading.dp)
                .offset(y = Tokens.Sizes.cameraSendtoSizeCaptionBaselineOffset)
                .focusRequester(focusRequester)
                .onFocusChanged { onFocus(it.isFocused) }
                .semantics { contentDescription = placeholder }
                .testTag("sendto.caption"),
        )
    }
}

/**
 * The voice-note gestures of the mic circle (`chat.voice.layout.recording`): press and hold
 * records, lifting the finger keeps the note for the post, sliding left cancels, sliding up onto
 * the lock continues hands-free.
 */
interface VoiceGestures {
    fun down()
    fun release()
    fun cancel()
    fun lock()

    companion object {
        val None = object : VoiceGestures {
            override fun down() = Unit
            override fun release() = Unit
            override fun cancel() = Unit
            override fun lock() = Unit
        }
    }
}

@Composable
private fun MessageRow(
    state: SendToViewModel.UiState,
    onField: () -> Unit,
    onLockedFinish: () -> Unit,
    gestures: VoiceGestures,
    now: () -> Long,
) {
    val f = Tokens.Layouts.CameraSendtoLayoutMessageField
    val placeholder = stringResource(R.string.camera_sendto_caption_placeholder)
    val fieldText = CaptureText.style(Tokens.FontSizes.cameraSendtoFontSizeMessagePlaceholder, null).merge(TextStyle(color = Tokens.Colors.globalTextPrimary))
    Box(Modifier.fillMaxSize()) {
        Row(
            Modifier
                .align(Alignment.BottomStart)
                .padding(start = f.insetLeading.dp, end = f.insetTrailing.dp, bottom = f.insetBottom.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Box(
                Modifier
                    .weight(1f)
                    .height(f.height.dp)
                    .clip(CapsuleShape)
                    .then(Blocked.messageFieldFill?.let { Modifier.background(it) } ?: Modifier)
                    .clickable(enabled = !state.recordingVoice, onClick = onField)
                    .semantics { role = Role.Button; contentDescription = placeholder; traversalIndex = 3f }
                    .padding(horizontal = f.height.dp / 2)
                    .testTag("sendto.field"),
                contentAlignment = Alignment.CenterStart,
            ) {
                when {
                    state.recordingVoice -> RecordingRow(state.recordingStartedAt, fieldText, now)
                    state.voice != null -> BasicText(
                        voiceDuration(state.voice.durationMs.toLong()),
                        style = CaptureText.style(Tokens.FontSizes.globalCaption, Tokens.FontWeights.fontWeightGlobalCaption).merge(TextStyle(color = Tokens.Colors.chatVoiceColorDuration)),
                        modifier = Modifier.testTag("sendto.voice.attached"),
                    )
                    else -> BasicText(placeholder, style = fieldText, maxLines = 1, overflow = TextOverflow.Ellipsis)
                }
            }
            Spacer(Modifier.width(f.gapToMic.dp))
            if (state.micAvailable) {
                VoiceMic(state, gestures, onLockedFinish)
            } else {
                Spacer(Modifier.width(f.micDiameter.dp))
            }
        }
    }
}

/** While recording: red dot, elapsed time, and the slide-to-cancel glyph centred (its copy does not exist yet). */
@Composable
private fun RecordingRow(startedAt: Long?, style: TextStyle, now: () -> Long) {
    var elapsed by remember(startedAt) { mutableStateOf(0L) }
    LaunchedEffect(startedAt) {
        val start = startedAt ?: return@LaunchedEffect
        while (true) {
            elapsed = (now() - start).coerceAtLeast(0)
            kotlinx.coroutines.delay(VOICE_TIMER_TICK_MS)
        }
    }
    // The dot takes the timer's digit height (its size was not measured).
    val dot = glyphTopToBaseline(Tokens.FontSizes.cameraSendtoFontSizeMessagePlaceholder, null, "0")
    Row(Modifier.fillMaxWidth().testTag("sendto.voice.recording"), verticalAlignment = Alignment.CenterVertically) {
        Box(Modifier.size(dot).clip(CircleShape).background(Tokens.Colors.globalDestructive))
        Spacer(Modifier.width(dot / 2))
        BasicText(voiceDuration(elapsed), style = style)
        Box(Modifier.weight(1f), contentAlignment = Alignment.Center) {
            Glyph(Tokens.Icons.globalBack, Tokens.Colors.globalTextSecondary, null)
        }
    }
}

/** `chat.voice.layout.durationFormat` (mm:ss). */
private fun voiceDuration(ms: Long): String {
    val seconds = ms / MILLIS_PER_SECOND
    return String.format(java.util.Locale.ROOT, VOICE_DURATION_FORMAT, seconds / SECONDS_PER_MINUTE, seconds % SECONDS_PER_MINUTE)
}

private const val MILLIS_PER_SECOND = 1000L // provenance-ok: unit conversion
private const val SECONDS_PER_MINUTE = 60L // provenance-ok: unit conversion
private const val VOICE_DURATION_FORMAT = "%02d:%02d" // provenance-ok: chat.voice.layout.durationFormat pattern mm:ss
private const val VOICE_TIMER_TICK_MS = 1000L // provenance-ok: the timer shows whole seconds

@Composable
private fun VoiceMic(state: SendToViewModel.UiState, gestures: VoiceGestures, onLockedFinish: () -> Unit) {
    val f = Tokens.Layouts.CameraSendtoLayoutMessageField
    val mic = f.micDiameter.dp
    val label = stringResource(R.string.camera_sendto_a11y_voice)
    val density = androidx.compose.ui.platform.LocalDensity.current
    // A slide counts once it travels one mic diameter (gesture threshold, not a drawn size).
    val threshold = with(density) { mic.toPx() }
    val locked = state.voiceLocked
    Box(contentAlignment = Alignment.Center) {
        if (state.recordingVoice && !locked) {
            // The lock above the mic: chevron up over the lock glyph (capsule size not measured).
            Column(
                Modifier.align(Alignment.BottomCenter).offset(y = -mic).testTag("sendto.voice.lock"),
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                Glyph(androidx.compose.material.icons.Icons.Rounded.ExpandLess, Tokens.Colors.globalTextSecondary, null)
                Glyph(Tokens.Icons.globalLock, Tokens.Colors.globalTextSecondary, null)
            }
        }
        Box(
            Modifier
                .size(mic)
                .clip(CircleShape)
                .then(Blocked.messageFieldFill?.let { Modifier.background(it) } ?: Modifier)
                .pointerInput(locked) {
                    awaitEachGesture {
                        val down = awaitFirstDown()
                        if (locked) {
                            if (waitForUpOrCancellation() != null) onLockedFinish()
                            return@awaitEachGesture
                        }
                        gestures.down()
                        var settled = false
                        while (true) {
                            val event = awaitPointerEvent()
                            val change = event.changes.firstOrNull { it.id == down.id } ?: break
                            change.consume()
                            if (!settled) {
                                val d = change.position - down.position
                                when {
                                    d.x < -threshold -> { gestures.cancel(); settled = true }
                                    d.y < -threshold -> { gestures.lock(); settled = true }
                                }
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
                    traversalIndex = 4f
                    // TalkBack cannot hold: activating starts hands-free (locked) and again finishes.
                    onClick {
                        if (locked) onLockedFinish() else { gestures.down(); gestures.lock() }
                        true
                    }
                }
                .testTag(if (state.recordingVoice) "sendto.mic.recording" else "sendto.mic"),
            contentAlignment = Alignment.Center,
        ) {
            Glyph(if (locked) Tokens.Icons.globalSend else Tokens.Icons.globalMic, Tokens.Colors.globalTextPrimary, null)
        }
    }
}

/** The Yope coach pointing at the mic, wrapping to two lines within the card. */
@Composable
private fun VoiceCoach(cardLeft: Dp, cardTop: Dp, onClose: () -> Unit) {
    val f = Tokens.Layouts.CameraSendtoLayoutMessageField
    val p = Tokens.Layouts.CameraSendtoLayoutPreview
    val coach = Tokens.Layouts.CameraCaptureLayoutCoach
    val micTop = cardTop + p.height.dp - f.insetBottom.dp - (f.height.dp + f.micDiameter.dp) / 2
    val coachWidth = p.width.dp - f.insetLeading.dp - f.insetTrailing.dp
    val micCenterInCoach = coachWidth - f.micDiameter.dp / 2
    Box(Modifier.fillMaxWidth().height(micTop - coach.pointerToTarget.dp), contentAlignment = Alignment.BottomStart) {
        CoachTooltip(
            text = stringResource(R.string.camera_sendto_coach_voice),
            closeLabel = stringResource(R.string.camera_capture_a11y_close),
            onClose = onClose,
            pointerX = micCenterInCoach,
            maxLines = 2,
            modifier = Modifier.padding(start = cardLeft + f.insetLeading.dp).width(coachWidth),
        )
    }
}

@Composable
private fun RecipientRow(group: Group, cover: Any?, selected: Boolean, onToggle: () -> Unit) {
    val row = Tokens.Layouts.CameraSendtoLayoutRecipientRow
    val avatar = Tokens.Sizes.globalAvatarSmall
    Box(
        Modifier
            .fillMaxWidth()
            .height(row.pitch.dp)
            .toggleable(value = selected, role = Role.Checkbox, onValueChange = { onToggle() })
            .semantics(mergeDescendants = true) { traversalIndex = 5f }
            .testTag("sendto.row.${group.id}"),
    ) {
        Avatar(
            image = cover,
            size = avatar,
            fallbackIcon = Tokens.Icons.globalGroup,
            modifier = Modifier.align(Alignment.CenterStart).offset(x = row.avatarCenterInset.dp - avatar / 2).testTag("sendto.avatar.${group.id}"),
        )
        BasicText(
            group.name,
            style = CaptureText.headerTitle.merge(TextStyle(color = Tokens.Colors.globalTextPrimary)),
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
            modifier = Modifier
                .align(Alignment.CenterStart)
                .padding(start = row.nameInset.dp, end = row.checkTrailingInset.dp + Tokens.Sizes.globalCheckCircle)
                .testTag("sendto.name.${group.id}"),
        )
        CheckCircle(selected, Modifier.align(Alignment.CenterEnd).padding(end = row.checkTrailingInset.dp).testTag("sendto.check.${group.id}"))
    }
}

@Composable
private fun SendButton(count: Int, onClick: () -> Unit, modifier: Modifier) {
    val label = stringResource(R.string.camera_sendto_send)
    val disc = Tokens.Sizes.cameraSendtoSizeCountDisc
    Row(
        modifier
            .fillMaxWidth()
            .height(Tokens.Sizes.globalButtonHeightSheet)
            .clip(RoundedCornerShape(Tokens.Radii.globalButton))
            .background(Tokens.Colors.globalAccent)
            .clickable(onClick = onClick)
            .semantics(mergeDescendants = true) { role = Role.Button; contentDescription = label }
            .testTag("sendto.send"),
        horizontalArrangement = Arrangement.Center,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        BasicText(label, style = CaptureText.button.merge(TextStyle(color = Tokens.Colors.globalOnAccent)), modifier = Modifier.clearAndSetSemantics { })
        Spacer(Modifier.width(Tokens.Sizes.cameraSendtoSizeCountDiscGap))
        // The count disc is hidden from accessibility (the rows expose their selected state).
        Box(
            Modifier.size(disc).clip(CircleShape).background(Tokens.Colors.globalOnAccent).testTag("sendto.count").clearAndSetSemantics { },
            contentAlignment = Alignment.Center,
        ) {
            BasicText(
                count.toString(),
                style = CaptureText.style(Tokens.FontSizes.cameraSendtoFontSizeCountNumber, Tokens.FontWeights.cameraSendtoFontWeightCountNumber)
                    .merge(TextStyle(color = Tokens.Colors.globalAccent)),
            )
        }
    }
}

/** Decodes [file] sampled down to about [targetPx] on its short side (no full-size bitmap). */
internal fun decodePreview(file: File, targetPx: Int): ImageBitmap? {
    val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
    BitmapFactory.decodeFile(file.path, bounds)
    if (bounds.outWidth <= 0 || bounds.outHeight <= 0) return null
    var sample = 1
    while (minOf(bounds.outWidth, bounds.outHeight) / (sample * 2) >= max(1, targetPx)) sample *= 2
    val bitmap: Bitmap = BitmapFactory.decodeFile(file.path, BitmapFactory.Options().apply { inSampleSize = sample }) ?: return null
    val rotation = app.feature.capture.data.exifRotation(file)
    val rotated = if (rotation == 0) bitmap else {
        val m = android.graphics.Matrix().apply { postRotate(rotation.toFloat()) }
        Bitmap.createBitmap(bitmap, 0, 0, bitmap.width, bitmap.height, m, true)
    }
    return rotated.asImageBitmap()
}
