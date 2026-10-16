package app.ui.snapshots

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import app.designsystem.generated.Tokens
import app.ui.components.CircleButtonStyle
import app.ui.components.CircleIconButton
import app.ui.components.VoiceWaveform
import org.junit.Test

/**
 * C-36 voice waveform (owner decision 16) in the 37-pt capsule's height, `chat.voice.dimension.waveform` long: idle
 * (every bar unplayed), playing part-way (played bars, the bar under the edge split), the dots fallback for a note
 * without levels, a short note's few levels; and C-11's primary / red-glyph circles of the locked recording.
 */
class VoiceSnapshotTest(appearance: Appearance) : SnapshotTest(appearance) {
    private val levels = listOf(
        23, 25, 26, 14, 10, 21, 22, 22, 23, 0, 15, 18, 12, 11, 3, 15, 31, 15, 4, 20, 31, 10, 16, 0, 31, 14, 21, 31, 1, 12, 15, 31,
        31, 7, 4, 24, 25, 31, 11, 0, 13, 22, 0, 19, 27, 31, 14, 0, 0, 24, 31, 14, 31, 31, 0, 27, 18, 12, 31, 0, 0, 16, 17, 27,
        0, 0, 21, 31, 30, 26, 0, 0, 0, 27, 29, 28, 0, 31, 20, 31, 22, 0, 0, 14, 16, 24, 9, 0, 28, 24, 21, 19, 0, 0, 0, 18,
        21, 31, 19, 0,
    )

    @Composable
    private fun InCapsule(onMedia: Boolean, content: @Composable () -> Unit) = Box(
        Modifier
            .padding(horizontal = Tokens.Sizes.globalScreenMargin)
            .height(Tokens.Sizes.globalPillHeight)
            .background(if (onMedia) Tokens.Colors.globalControlOnDeep else Tokens.Colors.globalSurfaceSecondaryAndroid, CircleShape)
            .padding(horizontal = Tokens.Sizes.globalPillPaddingLeading),
        contentAlignment = Alignment.Center,
    ) { content() }

    @Composable
    private fun States(onMedia: Boolean) = Stack {
        listOf<Pair<List<Int>?, Float?>>(levels to null, levels to 0.43f, null to null, listOf(4, 31, 12, 0, 22, 8) to 0.5f).forEach { (l, p) ->
            InCapsule(onMedia) {
                VoiceWaveform(l, Tokens.Sizes.globalPillHeight, Modifier.width(Tokens.Sizes.chatVoiceDimensionWaveform), progress = p, onMedia = onMedia)
            }
        }
    }

    @Test fun c36Page() = snap("c36-voice-waveform", "idle-playing-dots-short") { States(onMedia = false) }

    @Test fun c36Media() = snap("c36-voice-waveform", "on-media", surface = Surface.Media) { States(onMedia = true) }

    @Test fun c11LockedRecordingCircles() = snap("c11-icon-buttons", "primary-and-red-glyph") {
        Row(Modifier.padding(horizontal = Tokens.Sizes.globalScreenMargin)) {
            CircleIconButton(Tokens.Icons.globalPause, "Pause recording", {}, tint = Tokens.Colors.globalDestructive)
            CircleIconButton(Tokens.Icons.globalMic, "Continue recording", {}, Modifier.padding(start = Tokens.Sizes.globalPillGap), tint = Tokens.Colors.globalDestructive)
            CircleIconButton(Tokens.Icons.globalSend, "Send", {}, Modifier.padding(start = Tokens.Sizes.globalPillGap), style = CircleButtonStyle.Primary)
        }
    }
}
