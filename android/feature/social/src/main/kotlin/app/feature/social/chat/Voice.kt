// Surface: chat.voice — design/surfaces/chat.voice.md (C-36 voice waveform: owner decision 16)
// References: references/auto/retro/lazyweb/retro-lazyweb-20251020-week43-dark.png (C-07 anatomy),
// references/auto/imessage/apple-support/messages-audio-message-ios27.png (play · waveform · duration),
// references/auto/whatsapp/blog/whatsapp-blog-2022-03-voice-updates.png (locked recording, draft preview),
// references/auto/retro/store/retro-store-02.png (C-06 medium capsules), references/auto/retro/lazyweb/retro-lazyweb-20260529-paywall.png
// ("1:00" duration format), references/auto/whatsapp/help/faq-657157755756612-send-voice-iphone.png (record gestures),
// references/auto/telegram/store/telegram-store-03.png (recording row, lock).
package app.feature.social.chat

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.awaitEachGesture
import androidx.compose.foundation.gestures.awaitFirstDown
import androidx.compose.foundation.gestures.awaitHorizontalTouchSlopOrCancellation
import androidx.compose.foundation.gestures.horizontalDrag
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.semantics.ProgressBarRangeInfo
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.SemanticsPropertyReceiver
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.onClick
import androidx.compose.ui.semantics.progressBarRangeInfo
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.setProgress
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.unit.LayoutDirection
import app.designsystem.R
import app.designsystem.generated.Tokens
import app.feature.social.common.Formats
import app.feature.social.common.stringRes
import app.ui.components.ActivityIndicator
import app.ui.components.VoiceWaveform
import app.ui.foundation.DsMotion
import app.ui.foundation.PageRoles
import app.ui.foundation.tapClickable
import app.ui.text.TextRoles

/** Voice recording (`chat.voice.layout.recording`: WhatsApp's press-and-hold, slide-to-cancel and lock; `.locked`). */
sealed interface Recording {
    /** Recording while the finger holds the mic glyph: lift sends, slide left cancels, slide up locks. */
    data object Holding : Recording

    /**
     * Hands-free after sliding onto the lock (or started from TalkBack's "Record" action): the live waveform in the field;
     * delete · pause · send under it.
     */
    data object Locked : Recording

    /** Locked and paused: the draft's waveform and preview; delete · continue · send. */
    data object Paused : Recording
}

/** Hands-free: the field shows the waveform and the controls row shows (`chat.voice.layout.locked`). */
val Recording?.isLocked: Boolean get() = this == Recording.Locked || this == Recording.Paused

/** What a voice capsule shows (`chat.voice.layout.playback`). */
enum class VoiceState { Idle, Loading, Playing, Paused, Error }

/** Tabular digits for durations ("monospaced", `chat.voice.layout.durationFormat`). */
internal const val TABULAR_DIGITS = "tnum"

/**
 * The voice message (`chat.voice.layout.capsule`): C-06 fill capsule with C-07's anatomy, hugging its content —
 * `size.global.pillPaddingLeading` → `icon.global.play` / `icon.global.pause` at `size.global.iconSmall` →
 * `size.global.pillIconGap` → the C-36 waveform ([levels], `chat.voice.dimension.waveform` long; played bars up to
 * [progress]) → `size.global.pillIconGap` → the duration (`chat.voice.layout.durationFormat`, tabular digits, text role
 * `pill`) → `size.global.pillPaddingTrailing`; height `size.global.pillHeight` (grows with the font),
 * `radius.global.capsule`. Fill `color.global.surfaceSecondary.android` on a page, `color.global.controlOnDeep` on media
 * ([onMedia]). The label shows the total while idle and the elapsed time while playing or paused mid-way. Loading: the
 * platform activity indicator in the glyph's place; error: `chat.voice.error.play` in `color.global.destructive` in the
 * waveform's and label's place (tap retries). Play ↔ pause cross-fades (`duration.global.crossfade`). One button: [label]
 * (`chat.voice.a11y.message` / `.messageMine`), action `chat.voice.a11y.play` / `.pause`; the waveform is decorative.
 *
 * [onSeek] (`chat.voice.layout.scrub`): while playing or paused part-way, a horizontal drag that starts on the capsule
 * seeks to the finger's place along the waveform (a tap still plays / pauses; vertical drags pass to the list), and
 * TalkBack adjusts the position by `stepMs` ([voiceScrubSemantics]). Null: no seeking.
 */
@Composable
fun VoiceCapsule(
    durationMs: Long,
    elapsedMs: Long,
    state: VoiceState,
    label: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    onMedia: Boolean = false,
    levels: List<Int>? = null,
    progress: Float? = null,
    onSeek: ((Float) -> Unit)? = null,
) {
    val fill = if (onMedia) Tokens.Colors.globalControlOnDeep else PageRoles.secondarySurface
    val ink = if (onMedia) Tokens.Colors.globalTextOnMedia else Tokens.Colors.globalTextPrimary
    val shown = when (state) {
        VoiceState.Playing, VoiceState.Paused -> elapsedMs
        else -> durationMs
    }
    val action = if (state == VoiceState.Playing) stringRes(R.string.chat_voice_a11y_pause)
    else stringRes(R.string.chat_voice_a11y_play, Formats.spokenDuration(durationMs))
    val errorText = stringRes(R.string.chat_voice_error_play)
    Row(
        modifier
            .heightIn(min = Tokens.Sizes.globalPillHeight)
            .background(fill, CircleShape)
            .voiceScrub(state, onSeek)
            .tapClickable(onClick = onClick)
            .clearAndSetSemantics {
                contentDescription = label
                role = Role.Button
                voiceScrubSemantics(state, durationMs, elapsedMs, progress, onSeek)
                if (state == VoiceState.Error) stateDescription = errorText
                onClick(action) { onClick(); true }
            }
            .padding(PaddingValues(start = Tokens.Sizes.globalPillPaddingLeading, end = Tokens.Sizes.globalPillPaddingTrailing)),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(Modifier.size(Tokens.Sizes.globalIconSmall), contentAlignment = Alignment.Center) {
            AnimatedContent(state, transitionSpec = { fadeIn(DsMotion.crossfade()) togetherWith fadeOut(DsMotion.crossfade()) }, label = "voiceGlyph") { s ->
                when (s) {
                    VoiceState.Loading -> ActivityIndicator(null, Modifier.size(Tokens.Sizes.globalIconSmall), onMedia = onMedia)
                    VoiceState.Playing -> Icon(Tokens.Icons.globalPause, contentDescription = null, tint = ink, modifier = Modifier.size(Tokens.Sizes.globalIconSmall))
                    else -> Icon(Tokens.Icons.globalPlay, contentDescription = null, tint = ink, modifier = Modifier.size(Tokens.Sizes.globalIconSmall))
                }
            }
        }
        Spacer(Modifier.width(Tokens.Sizes.globalPillIconGap))
        if (state == VoiceState.Error) {
            Text(errorText, style = TextRoles.pill, color = Tokens.Colors.globalDestructive, maxLines = 1)
        } else {
            VoiceWaveform(
                levels = levels,
                holderHeight = Tokens.Sizes.globalPillHeight,
                modifier = Modifier.width(Tokens.Sizes.chatVoiceDimensionWaveform),
                progress = progress?.takeIf { state == VoiceState.Playing || state == VoiceState.Paused },
                onMedia = onMedia,
            )
            Spacer(Modifier.width(Tokens.Sizes.globalPillIconGap))
            Text(Formats.voiceDuration(shown), style = TextRoles.pill.copy(fontFeatureSettings = TABULAR_DIGITS), color = ink, maxLines = 1)
        }
    }
}

/** `chat.voice.layout.scrub`: the note can be sought (playing or paused part-way) and the caller handles it. */
private fun scrubbable(state: VoiceState, onSeek: ((Float) -> Unit)?): Boolean =
    onSeek != null && (state == VoiceState.Playing || state == VoiceState.Paused)

/**
 * `chat.voice.layout.scrub` drag: once a pointer that went down on a scrubbable capsule passes the horizontal touch slop,
 * every move seeks to its place along the waveform (C-36: `size.global.pillPaddingLeading` + `size.global.iconSmall` +
 * `size.global.pillIconGap` in from the leading edge, `chat.voice.dimension.waveform` wide, drawn left to right) and is
 * consumed, so the tap and the list's scroll do not take it. An idle capsule does nothing.
 */
@Composable
private fun Modifier.voiceScrub(state: VoiceState, onSeek: ((Float) -> Unit)?): Modifier {
    val canScrub by rememberUpdatedState(scrubbable(state, onSeek))
    val seek by rememberUpdatedState(onSeek)
    val rtl = LocalLayoutDirection.current == LayoutDirection.Rtl
    val density = LocalDensity.current
    val insetPx = with(density) { (Tokens.Sizes.globalPillPaddingLeading + Tokens.Sizes.globalIconSmall + Tokens.Sizes.globalPillIconGap).toPx() }
    val waveformPx = with(density) { Tokens.Sizes.chatVoiceDimensionWaveform.toPx() }
    return pointerInput(rtl, insetPx, waveformPx) {
        awaitEachGesture {
            val down = awaitFirstDown(requireUnconsumed = false)
            if (!canScrub) return@awaitEachGesture
            val minX = VoiceScrub.waveformMinX(size.width.toFloat(), insetPx, waveformPx, rtl)
            val drag = awaitHorizontalTouchSlopOrCancellation(down.id) { change, _ -> change.consume() } ?: return@awaitEachGesture
            seek?.invoke(VoiceScrub.fraction(drag.position.x, minX, waveformPx))
            horizontalDrag(drag.id) { change ->
                change.consume()
                seek?.invoke(VoiceScrub.fraction(change.position.x, minX, waveformPx))
            }
        }
    }
}

/**
 * `chat.voice.layout.scrub` for TalkBack: while the note plays or is paused part-way, a progress range 0…[durationMs]
 * at [elapsedMs] whose adjust moves `stepMs` forward / back ([VoiceScrub.step]); the state reads the elapsed time.
 * For the capsule and for any parent that clears its semantics (the thread row).
 */
fun SemanticsPropertyReceiver.voiceScrubSemantics(state: VoiceState, durationMs: Long, elapsedMs: Long, progress: Float?, onSeek: ((Float) -> Unit)?) {
    if (!scrubbable(state, onSeek) || durationMs <= 0 || onSeek == null) return
    progressBarRangeInfo = ProgressBarRangeInfo(elapsedMs.coerceIn(0L, durationMs).toFloat(), 0f..durationMs.toFloat())
    stateDescription = Formats.spokenDuration(elapsedMs)
    setProgress { target ->
        onSeek(VoiceScrub.step(progress ?: 0f, durationMs, forward = target > elapsedMs))
        true
    }
}

/** `chat.voice.layout.scrub`: the positions a drag along the waveform and the accessibility steps seek to. Pure. */
object VoiceScrub {
    /** The waveform's left edge in the capsule: [leadingInset] from the leading edge (the right edge right to left). */
    fun waveformMinX(capsuleWidth: Float, leadingInset: Float, waveformWidth: Float, rightToLeft: Boolean): Float =
        if (rightToLeft) capsuleWidth - leadingInset - waveformWidth else leadingInset

    /** The note's position under the finger at [x]: its share of the waveform (drawn left to right), clamped to 0…1. */
    fun fraction(x: Float, waveformMinX: Float, waveformWidth: Float): Float =
        if (waveformWidth <= 0f) 0f else ((x - waveformMinX) / waveformWidth).coerceIn(0f, 1f)

    /** One step of [stepMs] forward or back from [progress] of a [durationMs] note, clamped to 0…1; unknown length: no move. */
    fun step(progress: Float, durationMs: Long, forward: Boolean, stepMs: Float = Tokens.Layouts.ChatVoiceLayoutScrub.stepMs): Float {
        if (durationMs <= 0) return progress
        val delta = stepMs / durationMs
        return (progress + if (forward) delta else -delta).coerceIn(0f, 1f)
    }
}

/** The voice state of the message whose voice path is [key], from the shared playback ([playingKey] / [isPlaying] / [progress] 0…1). */
fun voiceStateOf(key: String?, playingKey: String?, isPlaying: Boolean, progress: Float, loadingKey: String?, failedKeys: Set<String>): VoiceState = when {
    key == null -> VoiceState.Idle
    key in failedKeys -> VoiceState.Error
    key == loadingKey -> VoiceState.Loading
    key == playingKey && isPlaying -> VoiceState.Playing
    key == playingKey && progress > 0f && progress < 1f -> VoiceState.Paused
    else -> VoiceState.Idle
}
