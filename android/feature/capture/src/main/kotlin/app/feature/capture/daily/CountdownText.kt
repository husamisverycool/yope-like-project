package app.feature.capture.daily

import android.text.format.DateUtils
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.text.BasicText
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp
import app.designsystem.R
import app.designsystem.dsEnterTransition
import app.designsystem.dsExitTransition
import app.designsystem.rememberReduceMotion
import app.designsystem.generated.Tokens
import app.feature.capture.ui.CaptureText
import app.feature.capture.ui.springWithResponse
import app.model.CountdownState
import java.util.Locale
import kotlin.math.roundToInt

/** MM:SS of [seconds] through the copy pattern `daily.capture.countdown` ("{mm}:{ss}"). */
@Composable
internal fun countdownText(seconds: Long): String {
    val m = seconds / SECONDS_PER_MINUTE
    val s = seconds % SECONDS_PER_MINUTE
    return stringResource(R.string.daily_capture_countdown, String.format(Locale.ROOT, TWO_DIGITS, m), String.format(Locale.ROOT, TWO_DIGITS, s))
}

private const val SECONDS_PER_MINUTE = 60L // provenance-ok: unit conversion
private const val TWO_DIGITS = "%02d" // provenance-ok: MM:SS digit format of the copy pattern

/**
 * The countdown (`daily.capture.layout.countdownTick`): only changed digits move — the old digit
 * slides up `travel` and fades out (`digitOut`), the new one rises from `travel` below
 * (`digitIn`) and fades in (`digitFadeIn`); the colon never moves. Reduce Motion: changed digits
 * cross-fade. At `closes_at` the whole label leaves with the digit-out motion (C-18). Weight
 * `daily.capture.fontWeight.countdown`.
 *
 * TalkBack reads the remaining time as the platform's elapsed-time string, no label words.
 */
@Composable
internal fun CountdownText(countdown: CountdownState.Open?, modifier: Modifier = Modifier) {
    val weight = Tokens.FontWeights.dailyCaptureFontWeightCountdown
    val tick = Tokens.Layouts.DailyCaptureLayoutCountdownTick
    val reduce by rememberReduceMotion()
    val travelPx = with(androidx.compose.ui.platform.LocalDensity.current) { tick.travel.dp.toPx().roundToInt() }
    val style = CaptureText.style(Tokens.FontSizes.dailyCaptureFontSizeCountdown, weight, tabularDigits = true)
        .merge(TextStyle(color = Tokens.Colors.dailyCaptureColorText))
    val outFade = remember { springWithResponse(tick.digitOut).spec<Float>() }
    val outSlide = remember { springWithResponse(tick.digitOut).spec<IntOffset>() }
    val inFade = remember { springWithResponse(tick.digitFadeIn).spec<Float>() }
    val inSlide = remember { springWithResponse(tick.digitIn).spec<IntOffset>() }
    AnimatedVisibility(
        visible = countdown != null,
        enter = dsEnterTransition(reduce, inFade, inSlide) { IntOffset(0, travelPx) },
        exit = dsExitTransition(reduce, outFade, outSlide) { IntOffset(0, -travelPx) },
        modifier = modifier.testTag("daily.countdown"),
    ) {
        val seconds = countdown?.remainingSeconds ?: 0L
        val text = countdownText(seconds)
        val spoken = DateUtils.formatElapsedTime(seconds)
        Row(Modifier.clearAndSetSemantics { stateDescription = spoken }) {
            text.forEachIndexed { index, char ->
                AnimatedContent(
                    targetState = char,
                    transitionSpec = {
                        dsEnterTransition(reduce, inFade, inSlide) { IntOffset(0, travelPx) } togetherWith
                            dsExitTransition(reduce, outFade, outSlide) { IntOffset(0, -travelPx) }
                    },
                    label = "digit$index", // provenance-ok: animation debug label (tooling only)
                ) { c -> BasicText(c.toString(), style = style) }
            }
        }
    }
}
