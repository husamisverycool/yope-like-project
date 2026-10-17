package app.ui.format

import android.text.format.DateUtils
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.produceState
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.style.TextOverflow
import app.designsystem.R
import app.model.CountdownState
import app.ui.text.TextRoles
import java.time.Instant
import java.util.Locale

/**
 * An open daily invitation's countdown outside the daily capture (groups.screen's invitation row, camera.sendto's
 * rows; migration 0035): BeReal's MM:SS (`daily.capture.countdown`) to the window's `closes_at`.
 */
object InvitationCountdown {
    /**
     * Whole seconds left in the window closing at [closesAt], recomposed each time the shown value changes; null when
     * [closesAt] is null and once it passed — nothing is shown after the window (tenet 5: no "late").
     */
    @Composable
    fun rememberSeconds(closesAt: Instant?, now: () -> Instant = Instant::now): Long? {
        val state by produceState(closesAt?.let { CountdownState.at(it, now()) }, closesAt) {
            if (closesAt != null) CountdownState.ticks(closesAt, now).collect { value = it }
        }
        return (state as? CountdownState.Open)?.remainingSeconds
    }

    /** MM:SS of [seconds] through the copy pattern `daily.capture.countdown` ("{mm}:{ss}"). */
    @Composable
    fun text(seconds: Long): String = stringResource(
        R.string.daily_capture_countdown,
        String.format(Locale.ROOT, TWO_DIGITS, seconds / SECONDS_PER_MINUTE),
        String.format(Locale.ROOT, TWO_DIGITS, seconds % SECONDS_PER_MINUTE),
    )

    /** The spoken value (TalkBack state description): the platform's elapsed-time format, as the daily capture's. */
    fun spoken(seconds: Long): String = DateUtils.formatElapsedTime(seconds)

    private const val SECONDS_PER_MINUTE = 60L // provenance-ok: unit conversion
    private const val TWO_DIGITS = "%02d" // provenance-ok: MM:SS digit format of the copy pattern
}

/**
 * The countdown as a list subtitle: text role `listSubtitle` with tabular figures (the colon never moves), one line, in
 * [color] (`color.global.textSecondary` for the surface it sits on).
 */
@Composable
fun InvitationCountdownText(seconds: Long, color: Color, modifier: Modifier = Modifier) {
    Text(
        InvitationCountdown.text(seconds),
        style = TextRoles.listSubtitle.copy(fontFeatureSettings = TABULAR_FIGURES),
        color = color,
        maxLines = 1,
        overflow = TextOverflow.Clip,
        modifier = modifier,
    )
}

private const val TABULAR_FIGURES = "tnum" // provenance-ok: OpenType feature tag, not a design value
