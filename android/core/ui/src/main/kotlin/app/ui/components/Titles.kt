package app.ui.components

import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.Dp
import app.designsystem.generated.Tokens
import app.ui.text.CapTop
import app.ui.text.TextRoles
import app.ui.text.capTopAt

/**
 * The onboarding / sign-up big title: text role `onboardingTitle` (`fontSize.global.onboardingTitle`
 * 40 heavy) in `color.global.textPrimary`, centred, a heading for TalkBack. Wraps at large font sizes.
 * [capTop]: when specified, the first line's cap top sits that far below the top of this element (the
 * specs place titles by cap top, e.g. `groups.create.size.sheetTopToTitle`).
 */
@Composable
fun OnboardingTitle(text: String, modifier: Modifier = Modifier, capTop: Dp = Dp.Unspecified) {
    val style = TextRoles.onboardingTitle
    Text(
        text,
        style = style,
        color = Tokens.Colors.globalTextPrimary,
        textAlign = TextAlign.Center,
        modifier = modifier.fillMaxWidth().capTopAt(capTop, CapTop.height(style)).semantics { heading() },
    )
}

/**
 * A two-line title whose second part is lime (`groups.create.layout.titleAccent`): line 1 in
 * `color.global.textPrimary`, line 2 in `color.global.accent`, text role `onboardingTitle`, centred.
 * Read as one sentence by TalkBack. [capTop] as in [OnboardingTitle].
 */
@Composable
fun AccentTitle(line1: String, line2: String, modifier: Modifier = Modifier, capTop: Dp = Dp.Unspecified) {
    val text = buildAnnotatedString {
        withStyle(SpanStyle(color = Tokens.Colors.globalTextPrimary)) { append(line1) }
        append('\n')
        withStyle(SpanStyle(color = Tokens.Colors.globalAccent)) { append(line2) }
    }
    val style = TextRoles.onboardingTitle
    Text(text, style = style, textAlign = TextAlign.Center, modifier = modifier.fillMaxWidth().capTopAt(capTop, CapTop.height(style)).semantics { heading() })
}

/** Splits a one-string title into the two lines of [AccentTitle] around a placeholder value. */
object TitleSplit {
    /**
     * For a template whose placeholder is the accent ("add friends to {group_name}"): [formatted] is
     * the template formatted with [accent]; line 1 is what precedes it (trimmed), line 2 is [accent].
     */
    fun aroundAccent(formatted: String, accent: String): Pair<String, String> {
        val at = formatted.lastIndexOf(accent)
        return if (at < 0) formatted to "" else formatted.substring(0, at).trim() to accent
    }

    /**
     * For a title with no placeholder ("create your first group", whose copy note names the second
     * part): split at the word boundary nearest the middle of the text, so the two lines balance.
     */
    fun atMiddleWord(text: String): Pair<String, String> {
        val spaces = text.indices.filter { text[it] == ' ' }
        if (spaces.isEmpty()) return text to ""
        val middle = text.length / 2.0
        val at = spaces.minBy { kotlin.math.abs(it - middle) }
        return text.substring(0, at) to text.substring(at + 1)
    }
}
