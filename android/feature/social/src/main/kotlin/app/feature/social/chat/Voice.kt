// Surface: chat.voice — voice message playback bubble (recording is BLOCKED).
// References: references/auto/yope/store/yope-store-05.png (mine, 0:38),
// references/auto/yope/frames/a-chuongxetank-7694968408424582452-t7.73-posted-toast-contacts-card.png (permission card).
package app.feature.social.chat

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.produceState
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.Dp
import app.designsystem.R
import app.designsystem.generated.Tokens
import app.feature.social.common.Formats
import app.feature.social.common.InkGlyph
import app.feature.social.common.SocialBlocked
import app.feature.social.common.Line
import app.feature.social.common.LocalSocialData
import app.feature.social.common.Type
import app.feature.social.common.stringRes
import app.feature.social.data.VoiceServices

/** How many waveform bars fit [width] (`chat.voice.dimension.barWidth` at `.barPitch`). */
fun barCount(width: Dp): Int {
    val pitch = Tokens.Sizes.chatVoiceDimensionBarPitch
    val bar = Tokens.Sizes.chatVoiceDimensionBarWidth
    if (width < bar) return 0
    return ((width - bar) / pitch).toInt() + 1
}

/** Waveform bars: rounded, centred on the line, heights between `barMinHeight` and `barMaxHeight` from [levels] (0…1). */
@Composable
fun WaveformBars(levels: List<Float>?, count: Int, modifier: Modifier = Modifier, progress: Float = 0f) {
    val played = SocialBlocked.waveformPlayed
    val min = Tokens.Sizes.chatVoiceDimensionBarMinHeight
    val maxH = Tokens.Sizes.chatVoiceDimensionBarMaxHeight
    val gap = Tokens.Sizes.chatVoiceDimensionBarPitch - Tokens.Sizes.chatVoiceDimensionBarWidth
    Row(modifier.clearAndSetSemantics { }, horizontalArrangement = Arrangement.spacedBy(gap), verticalAlignment = Alignment.CenterVertically) {
        for (i in 0 until count) {
            val level = levels?.getOrNull(i)?.coerceIn(0f, 1f) ?: 0f
            Box(
                Modifier
                    .width(Tokens.Sizes.chatVoiceDimensionBarWidth)
                    .height(min + (maxH - min) * level)
                    .clip(RoundedCornerShape(Tokens.Sizes.chatVoiceDimensionBarWidth))
                    // The played part's colour is BLOCKED (`chat.voice.color.waveformPlayed`): drawn only once unblocked.
                    .background(if (played != null && count > 0 && i < progress * count) played else Tokens.Colors.chatVoiceColorWaveform),
            )
        }
    }
}

/**
 * The voice bubble (`chat.voice.*`): play circle, waveform, duration. [fill] null = another
 * member's bubble, whose fill is BLOCKED (`chat.voice.color.bubbleTheirs`) and is not drawn. The
 * playing state's glyph and progress colour are BLOCKED: only the TalkBack label changes.
 */
@Composable
fun VoiceBubble(
    path: String,
    durationMs: Int,
    fill: Color?,
    label: String,
    playing: Boolean,
    voice: VoiceServices?,
    onToggle: () -> Unit,
    modifier: Modifier = Modifier,
    progress: Float = 0f,
) {
    val duration = Formats.voiceDuration(durationMs)
    val buttonLabel = playLabel(playing, durationMs)
    val shape = RoundedCornerShape(Tokens.Radii.chatVoiceRadiusBubble)
    Row(
        modifier
            .width(Tokens.Sizes.chatVoiceDimensionWidth)
            .heightIn(min = Tokens.Sizes.chatVoiceDimensionHeight)
            .clip(shape)
            .let { if (fill != null) it.background(fill) else it }
            .semantics { contentDescription = label },
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Spacer(Modifier.width(Tokens.Sizes.chatVoiceDimensionPlayInsetLeading))
        Box(
            Modifier
                .size(Tokens.Sizes.chatVoiceDimensionPlayButton)
                .clip(CircleShape)
                .background(Tokens.Colors.chatVoiceColorPlayButton)
                .clickable(role = Role.Button, onClick = onToggle)
                .clearAndSetSemantics {
                    contentDescription = buttonLabel
                    role = Role.Button
                },
            contentAlignment = Alignment.Center,
        ) {
            // The playing glyph is BLOCKED (`chat.voice.icon.pause`): ▶ stays until it is unblocked.
            val pause = SocialBlocked.pauseIcon
            if (playing && pause != null) InkGlyph(pause, Tokens.Colors.globalTextPrimary, inkWidth = Tokens.Sizes.chatVoiceDimensionPlayGlyph)
            else InkGlyph(Tokens.Icons.globalPlay, Tokens.Colors.globalTextPrimary, inkWidth = Tokens.Sizes.chatVoiceDimensionPlayGlyph)
        }
        Spacer(Modifier.width(Tokens.Sizes.chatVoiceDimensionPlayToWaveform))
        BoxWithConstraints(Modifier.weight(1f), contentAlignment = Alignment.CenterStart) {
            val count = barCount(maxWidth)
            val data = LocalSocialData.current
            val levels by produceState(app.feature.social.data.AudioEnvelope.peek(path, count), path, count, voice) {
                if (voice != null && count > 0 && value == null) {
                    val url = runCatching { data.signedUrls(listOf(path))[path] }.getOrNull()
                    value = url?.let { voice.envelope(path, it, count) }
                }
            }
            WaveformBars(levels, count, progress = if (playing) progress else 0f)
        }
        Spacer(Modifier.width(Tokens.Sizes.chatVoiceDimensionWaveformToDuration))
        Line(duration, Type.caption(), Tokens.Colors.chatVoiceColorDuration, Modifier.clearAndSetSemantics { })
        Spacer(Modifier.width(Tokens.Sizes.chatVoiceDimensionDurationTrailing))
    }
}

/** The play button's label: `chat.voice.a11y.play` with the spoken duration, or `.pause` while playing. */
@Composable
fun playLabel(playing: Boolean, durationMs: Int): String =
    if (playing) stringRes(R.string.chat_voice_a11y_pause) else stringRes(R.string.chat_voice_a11y_play, Formats.spokenDuration(durationMs))

