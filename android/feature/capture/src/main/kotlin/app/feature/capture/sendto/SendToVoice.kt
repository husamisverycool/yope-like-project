// Surface: camera.sendto (voice capsule, recording capsule, note capsule), recorded with the chat.voice recorder
// (`chat.voice.layout.recording`: WhatsApp's press-and-hold, slide to cancel, lock for hands-free; `chat.voice.layout.locked`:
// pause, preview the draft, continue, delete, keep) and drawn with the C-36 voice waveform (owner decision 16) —
// design/surfaces/camera.sendto.md, chat.voice.md. Reference images: references/auto/retro/store/retro-store-03.png (ST-03:
// capsules on the photo), references/auto/whatsapp/help/faq-657157755756612-send-voice-iphone.png (mechanics),
// references/auto/whatsapp/blog/whatsapp-blog-2022-03-voice-updates.png (locked recording and draft preview order),
// references/auto/imessage/apple-support/messages-audio-message-ios27.png (play · waveform · duration). Mirrors iOS
// SendToVoice.swift. Everything here sits on the photo of the black composer (C-06 fill and C-11 circles on media:
// `color.global.controlOnDeep` with `color.global.textOnMedia` glyphs).
package app.feature.capture.sendto

import android.content.Context
import android.net.Uri
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.awaitEachGesture
import androidx.compose.foundation.gestures.awaitFirstDown
import androidx.compose.foundation.gestures.waitForUpOrCancellation
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.layout
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.CustomAccessibilityAction
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.customActions
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.onClick
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.IntOffset
import app.designsystem.R
import app.designsystem.generated.Tokens
import app.feature.capture.ui.TABULAR_DIGITS
import app.feature.capture.ui.VoiceGestures
import app.feature.capture.ui.spokenDuration
import app.feature.capture.ui.voiceDuration
import app.ui.components.CircleButtonStyle
import app.ui.components.CircleIconButton
import app.ui.components.VoiceWaveform
import app.ui.foundation.tapClickable
import app.ui.foundation.tapLongPressable
import app.ui.haptics.rememberHaptics
import app.ui.text.TextRoles
import app.voice.VoiceNote
import app.voice.VoicePlayer
import app.voice.VoiceRecorder
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import java.io.File
import kotlin.math.roundToInt

/** The playing file (the attached note, or the paused draft's preview) and 0…1 of it. */
data class VoicePlay(val file: File? = null, val isPlaying: Boolean = false, val progress: Float = 0f)

/**
 * The send-to composer's recorder and player (core:voice [VoiceRecorder] / [VoicePlayer]); [SendToViewModel] drives it.
 * [elapsedMs] and [levels] are the recording's length and waveform (100 levels of 0…31) so far.
 */
interface SendToVoice {
    val elapsedMs: StateFlow<Long>
    val levels: StateFlow<List<Int>>
    val playback: StateFlow<VoicePlay>

    /** Starts recording (RECORD_AUDIO granted); throws when the recorder cannot start. */
    fun start()
    fun pause()
    fun resume()

    /** The paused draft as one playable file. */
    suspend fun draftFile(): File

    /** Stops and returns the recording, or null when nothing usable. */
    suspend fun finish(): VoiceNote?
    fun cancel()

    /** Plays [file] (from where it was paused, or from its start), or pauses it while it plays. */
    fun toggle(file: File)
    fun stopPlayback()
    fun release()
}

/** [SendToVoice] on the device's microphone and Media3. */
class PlatformSendToVoice(context: Context) : SendToVoice {
    private val recorder = VoiceRecorder(context.applicationContext)
    private val player = VoicePlayer(context.applicationContext, progressIntervalMs = PLAYBACK_TICK_MS)
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    private val play = MutableStateFlow(VoicePlay())
    private var file: File? = null

    init {
        scope.launch {
            player.state.collect { s ->
                val duration = s.durationMs?.takeIf { it > 0 }
                play.value = VoicePlay(file, s.isPlaying && file != null, if (duration != null && file != null) (s.positionMs.toFloat() / duration).coerceIn(0f, 1f) else 0f)
            }
        }
    }

    override val elapsedMs: StateFlow<Long> get() = recorder.elapsedMs
    override val levels: StateFlow<List<Int>> get() = recorder.levels
    override val playback: StateFlow<VoicePlay> = play.asStateFlow()

    override fun start() = recorder.start()
    override fun pause() = recorder.pause()
    override fun resume() = recorder.resume()
    override suspend fun draftFile(): File = recorder.draftFile()
    override suspend fun finish(): VoiceNote? = recorder.finish()
    override fun cancel() = recorder.cancel()

    override fun toggle(file: File) {
        if (this.file == file && play.value.isPlaying) {
            player.pause()
            return
        }
        if (this.file != file) {
            this.file = file
            play.value = VoicePlay(file)
        }
        player.play(Uri.fromFile(file))
    }

    override fun stopPlayback() {
        if (play.value.isPlaying) player.pause()
        file = null
        play.value = VoicePlay()
    }

    override fun release() {
        scope.cancel()
        recorder.release()
        player.release()
    }

    private companion object {
        /** How often the played bars move while a note plays. */
        const val PLAYBACK_TICK_MS = 50L // provenance-ok: progress redraw interval (transport), as feature:social's player
    }
}

/** The recorder's and player's live values for the stateless screen. */
data class VoiceLive(
    /** The recording's length so far (holding, locked) or the paused draft's length. */
    val elapsedMs: Long = 0,
    /** The live / paused draft's waveform (C-36). */
    val levels: List<Int> = emptyList(),
    val play: VoicePlay = VoicePlay(),
)

/**
 * The voice capsule after the message pill (C-06 icon-only capsule on media: `size.global.iconPillWidth` ×
 * `size.global.pillHeight`, `color.global.controlOnDeep`, `icon.global.mic` at `size.global.iconSmall` in
 * `color.global.textOnMedia`). Press and hold records, lift keeps the note, slide left past half of [rowWidth] cancels,
 * slide up `size.global.pillHeight` locks (the lock circle shows above it while holding); locked or paused it shows
 * `icon.global.send` and a tap keeps the note. With a note attached it stays the mic: a new recording replaces the
 * note. TalkBack cannot hold: activating records hands-free, then keeps the note ([onA11y]).
 */
@Composable
internal fun SendToVoiceCapsule(
    phase: VoicePhase,
    rowWidth: Dp,
    enabled: Boolean,
    gestures: VoiceGestures,
    onSlide: (Float) -> Unit,
    onKeep: () -> Unit,
    onA11y: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val haptics = rememberHaptics()
    val showsSend = phase == VoicePhase.Locked || phase == VoicePhase.Paused
    val density = LocalDensity.current
    val cancelPx = with(density) { (rowWidth / 2).toPx() }
    val lockPx = with(density) { Tokens.Sizes.globalPillHeight.toPx() }
    val currentPhase = rememberUpdatedState(phase)
    val label = stringResource(if (showsSend) R.string.chat_composer_a11y_send else R.string.camera_sendto_a11y_voice)
    val recordingState = stringResource(R.string.camera_capture_a11y_recording)
    Box(modifier, contentAlignment = Alignment.TopCenter) {
        Box(
            Modifier
                .heightIn(min = Tokens.Sizes.globalPillHeight)
                .widthIn(min = Tokens.Sizes.globalIconPillWidth)
                .clip(CircleShape)
                .background(Tokens.Colors.globalControlOnDeep, CircleShape)
                .pointerInput(showsSend, enabled) {
                    if (!enabled) return@pointerInput
                    awaitEachGesture {
                        val down = awaitFirstDown()
                        haptics.tap()
                        if (showsSend) {
                            if (waitForUpOrCancellation() != null) onKeep()
                            return@awaitEachGesture
                        }
                        gestures.down()
                        // Cancel or lock settles the gesture: the rest of the drag does nothing more.
                        var settled = false
                        while (true) {
                            val event = awaitPointerEvent()
                            val change = event.changes.firstOrNull { it.id == down.id } ?: break
                            change.consume()
                            val dx = change.position.x - down.position.x
                            val dy = change.position.y - down.position.y
                            if (!settled && currentPhase.value == VoicePhase.Holding) {
                                onSlide(dx.coerceAtMost(0f))
                                if (cancelPx > 0 && dx < -cancelPx) {
                                    settled = true
                                    onSlide(0f)
                                    gestures.cancel()
                                } else if (dy < -lockPx) {
                                    settled = true
                                    onSlide(0f)
                                    gestures.lock()
                                }
                            }
                            if (!change.pressed) break
                        }
                        onSlide(0f)
                        gestures.release()
                    }
                }
                // The tag before clearAndSetSemantics (it clears what follows it).
                .testTag("sendto.voice")
                .clearAndSetSemantics {
                    contentDescription = label
                    role = Role.Button
                    if (phase == VoicePhase.Holding || phase == VoicePhase.Locked) stateDescription = recordingState
                    if (enabled) onClick { if (showsSend) onKeep() else onA11y(); true }
                },
            contentAlignment = Alignment.Center,
        ) {
            Icon(
                if (showsSend) Tokens.Icons.globalSend else Tokens.Icons.globalMic,
                contentDescription = null,
                tint = Tokens.Colors.globalTextOnMedia,
                modifier = Modifier.size(Tokens.Sizes.globalIconSmall),
            )
        }
        if (phase == VoicePhase.Holding) {
            // `chat.voice.layout.recording` lockCircle on media: C-11 `size.global.circleButton`, `size.global.pillGap` above
            // the capsule, centred over it; outside the row's layout (it covers the photo, not the pills).
            CircleIconButton(
                Tokens.Icons.globalLock,
                stringResource(R.string.chat_voice_a11y_lock),
                { gestures.lock() },
                Modifier.above(Tokens.Sizes.globalPillGap).testTag("sendto.voice.lock"),
                style = CircleButtonStyle.OnMedia,
            )
        }
    }
}

/** Places the content [gap] above the top of its parent, centred, without taking layout space. */
private fun Modifier.above(gap: Dp): Modifier = layout { measurable, constraints ->
    val placeable = measurable.measure(constraints.copy(minWidth = 0, minHeight = 0))
    layout(0, 0) { placeable.place(-placeable.width / 2, -placeable.height - gap.roundToPx()) }
}

/**
 * The recording capsule that takes the message pill's place while recording (`camera.sendto.layout.messageField`
 * `.recording`, `chat.voice.layout.locked` order inside one capsule): holding — `icon.global.mic` in
 * `color.global.destructive` · elapsed (`chat.voice.layout.durationFormat`, text role `pill`, tabular digits,
 * `color.global.textOnMedia`) · `icon.global.back` + `chat.voice.recording.slideToCancel` in `color.global.textSecondary`
 * following the finger ([slidePx]); locked — red mic · elapsed · C-36 live waveform · `icon.global.pause`
 * (`chat.voice.a11y.pauseRecording`); paused — `icon.global.trash` in red (`chat.voice.a11y.discard`) · the preview's
 * `icon.global.play` / `.pause` · the draft's waveform with the preview's progress · its length · `icon.global.mic` in red
 * (`chat.voice.a11y.resumeRecording`). Fill `color.global.controlOnDeep`, height `size.global.pillHeight`, C-07 paddings,
 * glyphs `size.global.iconSmall` `size.global.pillIconGap` apart; locked and paused the caller gives it a width and the
 * waveform takes what is left.
 */
@Composable
internal fun SendToRecordingCapsule(
    phase: VoicePhase,
    live: VoiceLive,
    previewing: Boolean,
    previewProgress: Float?,
    slidePx: Float,
    onPause: () -> Unit,
    onResume: () -> Unit,
    onPreview: () -> Unit,
    onDiscard: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Row(
        modifier
            .heightIn(min = Tokens.Sizes.globalPillHeight)
            .background(Tokens.Colors.globalControlOnDeep, CircleShape)
            .testTag("sendto.voice.recording")
            .padding(PaddingValues(start = Tokens.Sizes.globalPillPaddingLeading, end = Tokens.Sizes.globalPillPaddingTrailing)),
        horizontalArrangement = Arrangement.spacedBy(Tokens.Sizes.globalPillIconGap),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        when (phase) {
            VoicePhase.Paused -> {
                GlyphButton(Tokens.Icons.globalTrash, stringResource(R.string.chat_voice_a11y_discard), Tokens.Colors.globalDestructive, onDiscard, "sendto.voice.discard")
                GlyphButton(
                    if (previewing) Tokens.Icons.globalPause else Tokens.Icons.globalPlay,
                    if (previewing) stringResource(R.string.chat_voice_a11y_pause) else stringResource(R.string.chat_voice_a11y_play, spokenDuration(live.elapsedMs)),
                    Tokens.Colors.globalTextOnMedia,
                    onPreview,
                    "sendto.voice.preview",
                )
                Waveform(live.levels, previewProgress)
                Elapsed(live.elapsedMs)
                GlyphButton(Tokens.Icons.globalMic, stringResource(R.string.chat_voice_a11y_resumerecording), Tokens.Colors.globalDestructive, onResume, "sendto.voice.pauseResume")
            }
            VoicePhase.Locked -> {
                RedMic()
                Elapsed(live.elapsedMs)
                Waveform(live.levels, null)
                GlyphButton(Tokens.Icons.globalPause, stringResource(R.string.chat_voice_a11y_pauserecording), Tokens.Colors.globalTextOnMedia, onPause, "sendto.voice.pauseResume")
            }
            VoicePhase.Holding, VoicePhase.Idle -> {
                RedMic()
                Elapsed(live.elapsedMs)
                Row(
                    Modifier.offset { IntOffset(slidePx.coerceAtMost(0f).roundToInt(), 0) },
                    horizontalArrangement = Arrangement.spacedBy(Tokens.Sizes.globalPillIconGap),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Icon(Tokens.Icons.globalBack, contentDescription = null, tint = Tokens.Colors.globalTextSecondary, modifier = Modifier.size(Tokens.Sizes.globalIconSmall))
                    Text(stringResource(R.string.chat_voice_recording_slidetocancel), style = TextRoles.pill, color = Tokens.Colors.globalTextSecondary, maxLines = 1)
                }
            }
        }
    }
}

@Composable
private fun RedMic() {
    Icon(Tokens.Icons.globalMic, contentDescription = null, tint = Tokens.Colors.globalDestructive, modifier = Modifier.size(Tokens.Sizes.globalIconSmall))
}

/** The recorder's elapsed time, or the paused draft's length (a polite live region, read as words). */
@Composable
private fun Elapsed(ms: Long) {
    val spoken = spokenDuration(ms)
    Text(
        voiceDuration(ms),
        style = TextRoles.pill.copy(fontFeatureSettings = TABULAR_DIGITS),
        color = Tokens.Colors.globalTextOnMedia,
        maxLines = 1,
        modifier = Modifier.clearAndSetSemantics {
            contentDescription = spoken
            liveRegion = LiveRegionMode.Polite
        },
    )
}

/** C-36 across the capsule's remaining width: the live recording, or the paused draft with its preview's progress. */
@Composable
private fun RowScope.Waveform(levels: List<Int>, progress: Float?) {
    VoiceWaveform(
        levels = levels,
        holderHeight = Tokens.Sizes.globalPillHeight,
        modifier = Modifier.weight(1f),
        progress = progress,
        onMedia = true,
    )
}

/**
 * A glyph at `size.global.iconSmall` that is a button; Compose expands its touch bounds to the minimum touch target
 * (`size.global.minTouchTarget.android`, set by `AppTheme`), so the capsule keeps its drawn height.
 */
@Composable
private fun GlyphButton(icon: ImageVector, label: String, tint: Color, onClick: () -> Unit, tag: String) {
    Box(
        Modifier
            .size(Tokens.Sizes.globalIconSmall)
            .tapClickable(onClick = onClick)
            .testTag(tag)
            .clearAndSetSemantics {
                contentDescription = label
                role = Role.Button
                onClick { onClick(); true }
            },
        contentAlignment = Alignment.Center,
    ) {
        Icon(icon, contentDescription = null, tint = tint, modifier = Modifier.size(Tokens.Sizes.globalIconSmall))
    }
}

/**
 * An attached voice note: the chat.voice capsule on media (`chat.voice.layout.capsule`, C-06 fill + C-07 anatomy + C-36):
 * `size.global.pillPaddingLeading` → `icon.global.play` / `.pause` at `size.global.iconSmall` → `size.global.pillIconGap`
 * → the waveform (`chat.voice.dimension.waveform`, played bars follow the playback) → `size.global.pillIconGap` → the
 * duration (`chat.voice.layout.durationFormat`, tabular digits, text role `pill`) → `size.global.pillPaddingTrailing`.
 * Centred `size.global.pillGap` above the pill pair (`camera.sendto.layout.messageField` `.note`). Tap plays / pauses;
 * a long press opens its menu ("Delete recording", also a TalkBack action).
 */
@Composable
internal fun SendToNoteCapsule(
    note: VoiceNoteFile,
    playing: Boolean,
    progress: Float?,
    enabled: Boolean,
    onToggle: () -> Unit,
    onMenu: () -> Unit,
    onDelete: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val label = if (playing) stringResource(R.string.chat_voice_a11y_pause) else stringResource(R.string.chat_voice_a11y_play, spokenDuration(note.durationMs.toLong()))
    val delete = stringResource(R.string.chat_voice_a11y_discard)
    Row(
        modifier
            .heightIn(min = Tokens.Sizes.globalPillHeight)
            .clip(CircleShape)
            .background(Tokens.Colors.globalControlOnDeep, CircleShape)
            .then(if (enabled) Modifier.tapLongPressable(onClick = onToggle, onLongClick = onMenu) else Modifier)
            .testTag("sendto.voice.attached")
            // One button: its play / pause label (the waveform is decorative, the duration is in the label).
            .clearAndSetSemantics {
                contentDescription = label
                role = Role.Button
                if (enabled) {
                    onClick { onToggle(); true }
                    customActions = listOf(CustomAccessibilityAction(delete) { onDelete(); true })
                }
            }
            .padding(PaddingValues(start = Tokens.Sizes.globalPillPaddingLeading, end = Tokens.Sizes.globalPillPaddingTrailing)),
        horizontalArrangement = Arrangement.spacedBy(Tokens.Sizes.globalPillIconGap),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(
            if (playing) Tokens.Icons.globalPause else Tokens.Icons.globalPlay,
            contentDescription = null,
            tint = Tokens.Colors.globalTextOnMedia,
            modifier = Modifier.size(Tokens.Sizes.globalIconSmall),
        )
        VoiceWaveform(
            levels = note.levels,
            holderHeight = Tokens.Sizes.globalPillHeight,
            modifier = Modifier.width(Tokens.Sizes.chatVoiceDimensionWaveform),
            progress = progress,
            onMedia = true,
        )
        Text(voiceDuration(note.durationMs.toLong()), style = TextRoles.pill.copy(fontFeatureSettings = TABULAR_DIGITS), color = Tokens.Colors.globalTextOnMedia, maxLines = 1)
    }
}
