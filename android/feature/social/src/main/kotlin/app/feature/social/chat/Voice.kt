// Surface: chat.voice — design/surfaces/chat.voice.md
// References: references/auto/retro/lazyweb/retro-lazyweb-20251020-week43-dark.png (C-07 anatomy),
// references/auto/retro/store/retro-store-02.png (C-06 medium capsules), references/auto/retro/lazyweb/retro-lazyweb-20260529-paywall.png
// ("1:00" duration format), references/auto/whatsapp/help/faq-657157755756612-send-voice-iphone.png (record gestures),
// references/auto/telegram/store/telegram-store-03.png (recording row, lock).
package app.feature.social.chat

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.CustomAccessibilityAction
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.customActions
import androidx.compose.ui.semantics.onClick
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.stateDescription
import app.designsystem.R
import app.designsystem.generated.Tokens
import app.feature.social.common.Formats
import app.feature.social.common.stringRes
import app.ui.foundation.DsMotion
import app.ui.foundation.PageRoles
import app.ui.foundation.tapClickable
import app.ui.text.TextRoles

/** Voice recording (`chat.voice.layout.recording`: WhatsApp's press-and-hold, slide-to-cancel and lock). */
sealed interface Recording {
    val startedAt: Long

    /** Recording while the finger holds the mic glyph: lift sends, slide left cancels, slide up locks. */
    data class Holding(override val startedAt: Long) : Recording

    /** Hands-free after sliding onto the lock (or started from TalkBack's "Record" action): trash discards, send sends. */
    data class Locked(override val startedAt: Long) : Recording
}

/** What a voice capsule shows (`chat.voice.layout.playback`). */
enum class VoiceState { Idle, Loading, Playing, Paused, Error }

/** Tabular digits for durations ("monospaced", `chat.voice.layout.durationFormat`). */
internal const val TABULAR_DIGITS = "tnum"

/**
 * The voice message (`chat.voice.layout.capsule`): C-06 fill capsule with C-07's anatomy, hugging its content —
 * `size.global.pillPaddingLeading` → `icon.global.play` / `icon.global.pause` at `size.global.iconSmall` →
 * `size.global.pillIconGap` → the duration (`chat.voice.layout.durationFormat`, tabular digits, text role `pill`) →
 * `size.global.pillPaddingTrailing`; height `size.global.pillHeight` (grows with the font), `radius.global.capsule`.
 * Fill `color.global.surfaceSecondary.android` on a page, `color.global.controlOnDeep` on media ([onMedia]).
 * The label shows the total while idle and the elapsed time while playing or paused mid-way. Loading: the platform
 * activity indicator in the glyph's place; error: `chat.voice.error.play` in `color.global.destructive` (tap retries).
 * Play ↔ pause cross-fades (`duration.global.crossfade`). One button: [label] (`chat.voice.a11y.message` /
 * `.messageMine`), action `chat.voice.a11y.play` / `.pause`.
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
) {
    val fill = if (onMedia) Tokens.Colors.globalControlOnDeep else PageRoles.secondarySurface
    val ink = Tokens.Colors.globalTextPrimary
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
            .tapClickable(onClick = onClick)
            .clearAndSetSemantics {
                contentDescription = label
                role = Role.Button
                if (state == VoiceState.Error) stateDescription = errorText
                onClick(action) { onClick(); true }
            }
            .padding(PaddingValues(start = Tokens.Sizes.globalPillPaddingLeading, end = Tokens.Sizes.globalPillPaddingTrailing)),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(Modifier.size(Tokens.Sizes.globalIconSmall), contentAlignment = Alignment.Center) {
            AnimatedContent(state, transitionSpec = { fadeIn(DsMotion.crossfade()) togetherWith fadeOut(DsMotion.crossfade()) }, label = "voiceGlyph") { s ->
                when (s) {
                    VoiceState.Loading -> CircularProgressIndicator(color = PageRoles.secondaryText(onMedia), strokeWidth = Tokens.Sizes.globalStripGap, modifier = Modifier.size(Tokens.Sizes.globalIconSmall))
                    VoiceState.Playing -> Icon(Tokens.Icons.globalPause, contentDescription = null, tint = ink, modifier = Modifier.size(Tokens.Sizes.globalIconSmall))
                    else -> Icon(Tokens.Icons.globalPlay, contentDescription = null, tint = ink, modifier = Modifier.size(Tokens.Sizes.globalIconSmall))
                }
            }
        }
        Spacer(Modifier.width(Tokens.Sizes.globalPillIconGap))
        if (state == VoiceState.Error) {
            Text(errorText, style = TextRoles.pill, color = Tokens.Colors.globalDestructive, maxLines = 1)
        } else {
            Text(Formats.voiceDuration(shown), style = TextRoles.pill.copy(fontFeatureSettings = TABULAR_DIGITS), color = ink, maxLines = 1)
        }
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

/** Custom TalkBack action helper for the recording's discard (`chat.voice.a11y.discard`). */
internal fun discardAction(label: String, onDiscard: () -> Unit) = CustomAccessibilityAction(label) { onDiscard(); true }

/** Unused-import guard for semantics helpers shared with the composer. */
@Suppress("unused")
private val keepCustomActions = Modifier.clearAndSetSemantics { customActions = emptyList() }
