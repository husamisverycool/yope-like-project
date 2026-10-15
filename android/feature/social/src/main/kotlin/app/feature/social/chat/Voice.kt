// Surface: chat.voice — voice message playback bubble and the recording row (`chat.voice.layout.recording`).
// References: references/auto/yope/store/yope-store-05.png (mine, 0:38),
// references/auto/yope/frames/a-chuongxetank-7694968408424582452-t7.73-posted-toast-contacts-card.png (permission card),
// references/auto/whatsapp + references/auto/telegram App Store panels (recording row; MERGE_DECISIONS Gap fill G-9).
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
import androidx.compose.material.icons.rounded.ExpandLess
import app.designsystem.R
import app.designsystem.generated.Tokens
import app.feature.social.common.Formats
import app.feature.social.common.Glyph
import app.feature.social.common.InkGlyph
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
    val played = Tokens.Colors.chatVoiceColorWaveformPlayed
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
                    // Bars up to the playhead in `chat.voice.color.waveformPlayed`, the rest `chat.voice.color.waveform` (G-8).
                    .background(if (count > 0 && i < progress * count) played else Tokens.Colors.chatVoiceColorWaveform),
            )
        }
    }
}

/**
 * The voice bubble (`chat.voice.*`): play circle, waveform, duration; [fill] `chat.voice.color.bubble`
 * (mine) or `.bubbleTheirs`. Playing: `chat.voice.icon.pause` in the circle and the bars up to the
 * playhead in `chat.voice.color.waveformPlayed`. Its width is the observed one for every duration
 * (`chat.voice.layout.widthRule` is BLOCKED).
 */
@Composable
fun VoiceBubble(
    path: String,
    durationMs: Int,
    fill: Color,
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
            .background(fill)
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
            InkGlyph(if (playing) Tokens.Icons.chatVoiceIconPause else Tokens.Icons.globalPlay, Tokens.Colors.globalTextPrimary, inkWidth = Tokens.Sizes.chatVoiceDimensionPlayGlyph)
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


/** Voice recording (`chat.voice.layout.recording`: WhatsApp gestures, WhatsApp / Telegram rows; Gap fill G-9). */
sealed interface Recording {
    /** Recording while the finger holds the mic circle: lift sends, slide left cancels, slide up locks. */
    data class Holding(val startedAt: Long) : Recording

    /** Hands-free after sliding onto the lock (or started from TalkBack): pause keeps the draft, send sends. */
    data class Locked(val startedAt: Long) : Recording

    /** Paused while locked: the draft plays like a voice message; send sends it. */
    data class Draft(val voice: app.feature.social.data.RecordedVoice, val levels: List<Float>) : Recording
}

/**
 * The composer row's leading part while recording. Holding: red dot (`color.global.destructive`),
 * elapsed time (`chat.voice.layout.durationFormat`, `color.global.textPrimary`), then the centred hint
 * `icon.global.back` + `chat.voice.recording.slideToCancel` (`color.global.textSecondary`). Locked:
 * the hint's place holds the pause control (`chat.voice.icon.pause`). Paused: the draft as a voice
 * bubble's insides (play circle, waveform from the recorded levels, duration). The dot's diameter
 * and the text roles of time and hint are not measured: the play glyph width, `body` and `placeholder`.
 */
@Composable
fun RecordingRow(
    recording: Recording,
    elapsedMs: Long,
    draftPlaying: Boolean,
    draftProgress: Float,
    onPause: () -> Unit,
    onPlayDraft: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Row(modifier.heightIn(min = Tokens.Sizes.chatComposerDimensionFieldHeight), verticalAlignment = Alignment.CenterVertically) {
        when (recording) {
            is Recording.Draft -> {
                val ms = recording.voice.durationMs
                PlayCircle(draftPlaying, playLabel(draftPlaying, ms), onPlayDraft)
                Spacer(Modifier.width(Tokens.Sizes.chatVoiceDimensionPlayToWaveform))
                BoxWithConstraints(Modifier.weight(1f), contentAlignment = Alignment.CenterStart) {
                    val count = barCount(maxWidth)
                    WaveformBars(app.voice.Waveform.bars(recording.levels.ifEmpty { listOf(0f) }, count.coerceAtLeast(1)), count, progress = if (draftPlaying) draftProgress else 0f)
                }
                Spacer(Modifier.width(Tokens.Sizes.chatVoiceDimensionWaveformToDuration))
                Line(Formats.voiceDuration(ms), Type.caption(), Tokens.Colors.chatVoiceColorDuration, Modifier.clearAndSetSemantics { })
            }
            else -> {
                Box(Modifier.size(Tokens.Sizes.chatVoiceDimensionPlayGlyph).clip(CircleShape).background(Tokens.Colors.globalDestructive))
                Spacer(Modifier.width(Tokens.Sizes.globalHeaderGap))
                Line(Formats.voiceDuration(elapsedMs.toInt()), Type.body(), Tokens.Colors.globalTextPrimary)
                Box(Modifier.weight(1f), contentAlignment = Alignment.Center) {
                    if (recording is Recording.Locked) {
                        PlayCircle(playing = true, label = stringRes(R.string.chat_voice_a11y_pause), onClick = onPause)
                    } else {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Glyph(Tokens.Icons.globalBack, Tokens.Colors.globalTextSecondary)
                            Line(stringRes(R.string.chat_voice_recording_slidetocancel), Type.placeholder(), Tokens.Colors.globalTextSecondary)
                        }
                    }
                }
            }
        }
    }
}

/** The voice play circle (`chat.voice.dimension.playButton`, `.color.playButton`): ▶ or `chat.voice.icon.pause`. */
@Composable
private fun PlayCircle(playing: Boolean, label: String, onClick: () -> Unit) {
    Box(
        Modifier
            .size(Tokens.Sizes.chatVoiceDimensionPlayButton)
            .clip(CircleShape)
            .background(Tokens.Colors.chatVoiceColorPlayButton)
            .clickable(role = Role.Button, onClick = onClick)
            .clearAndSetSemantics {
                contentDescription = label
                role = Role.Button
            },
        contentAlignment = Alignment.Center,
    ) {
        InkGlyph(if (playing) Tokens.Icons.chatVoiceIconPause else Tokens.Icons.globalPlay, Tokens.Colors.globalTextPrimary, inkWidth = Tokens.Sizes.chatVoiceDimensionPlayGlyph)
    }
}

/**
 * The lock shown above the mic circle while holding (`chat.voice.layout.recording`: `icon.global.lock`
 * over the lock hint chevron `Rounded.ExpandLess`, `lockHintGlyphAndroid`). Its capsule is not
 * measured: `chat.composer.dimension.sideButton` wide, two circles tall, `color.global.controlRaised`.
 */
@Composable
fun LockIndicator(modifier: Modifier = Modifier) {
    Column(
        modifier
            .width(Tokens.Sizes.chatComposerDimensionSideButton)
            .height(Tokens.Sizes.chatComposerDimensionSideButton * 2)
            .clip(CircleShape)
            .background(Tokens.Colors.globalControlRaised)
            .clearAndSetSemantics { },
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.SpaceEvenly,
    ) {
        Glyph(Tokens.Icons.globalLock, Tokens.Colors.globalTextPrimary)
        // `chat.voice.layout.recording.lockHintGlyphAndroid`.
        Glyph(androidx.compose.material.icons.Icons.Rounded.ExpandLess, Tokens.Colors.globalTextSecondary)
    }
}
