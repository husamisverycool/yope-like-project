package app.ui.components

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.LinkAnnotation
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.TextLinkStyles
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.text.withLink
import androidx.compose.ui.unit.Dp
import app.designsystem.generated.Tokens
import app.ui.foundation.DsMotion
import app.ui.foundation.PageRoles
import app.ui.foundation.reduceMotion
import app.ui.text.CapTop
import app.ui.text.TextRoles
import app.ui.text.capTopAt

/**
 * C-33 onboarding page title: a conversational headline in `font.global.display`, text role `displayMedium`
 * (32 regular — Retro's Android onboarding headlines are Roslindale Display Narrow), `color.global.textPrimary`,
 * centred (onboarding pages are not captured as images — C-33 Gap), header trait; wraps at large font sizes.
 * [capTop]: when specified, the first line's cap top sits that far below the top of this element.
 */
@Composable
fun OnboardingTitle(text: String, modifier: Modifier = Modifier, capTop: Dp = Dp.Unspecified) {
    val style = TextRoles.displayMedium
    Text(
        text,
        style = style,
        color = Tokens.Colors.globalTextPrimary,
        textAlign = TextAlign.Center,
        modifier = modifier.fillMaxWidth().capTopAt(capTop, CapTop.height(style)).semantics { heading() },
    )
}

/** C-33 landing line ("Friends Only"): text role `onboardingTitle` (30 regular) in secondary text, centred. */
@Composable
fun LandingLine(text: String, modifier: Modifier = Modifier) {
    Text(text, style = TextRoles.onboardingTitle, color = PageRoles.secondaryText(), textAlign = TextAlign.Center, modifier = modifier.fillMaxWidth())
}

/**
 * Fine print with tappable links (C-33): [text] (copy) in which each `links` key (also copy, e.g. "Terms",
 * "Privacy Policy") becomes an underlined link opening its action. Style comes from [FinePrint].
 */
fun finePrintText(text: String, links: List<Pair<String, () -> Unit>>): AnnotatedString = buildAnnotatedString {
    var cursor = 0
    val spans = links.mapNotNull { (label, action) -> text.indexOf(label, cursor.coerceAtMost(text.length)).takeIf { it >= 0 }?.let { Triple(it, label, action) } }
        .sortedBy { it.first }
    for ((at, label, action) in spans) {
        if (at < cursor) continue
        append(text.substring(cursor, at))
        withLink(LinkAnnotation.Clickable(label, TextLinkStyles(SpanStyle(textDecoration = TextDecoration.Underline))) { action() }) { append(label) }
        cursor = at + label.length
    }
    append(text.substring(cursor))
}

/** C-33 fine print: text role `caption` (14, line `lineHeight.global.caption` 21.7) in secondary text, centred; links underlined (each a button for TalkBack). */
@Composable
fun FinePrint(text: AnnotatedString, modifier: Modifier = Modifier) {
    Text(text, style = TextRoles.caption, color = PageRoles.secondaryText(), textAlign = TextAlign.Center, modifier = modifier.fillMaxWidth())
}

/**
 * C-33 Landing hero (LAND): the page with [mark] at the top (the owner's mark — Retro's wordmark is not copied),
 * the [line] under it ([LandingLine]), and at the bottom the C-05 primary capsule ([primaryText], white on the
 * dark page, black on the light one) at `size.global.buttonMarginH`, the C-08 secondary [linkText] under it, and
 * the [finePrint] at the bottom. The vertical gaps between capsule, link and fine print are not tokens (LAND reads
 * ≈16.3 and ≈21.7): `size.global.screenMargin` apart (Gap). The caller applies the system-bar insets.
 */
@Composable
fun LandingHero(
    line: String,
    primaryText: String,
    onPrimary: () -> Unit,
    modifier: Modifier = Modifier,
    mark: (@Composable ColumnScope.() -> Unit)? = null,
    linkText: String? = null,
    onLink: (() -> Unit)? = null,
    finePrint: AnnotatedString? = null,
) {
    val gap = Tokens.Sizes.globalScreenMargin
    Column(modifier.fillMaxSize(), horizontalAlignment = Alignment.CenterHorizontally) {
        Column(Modifier.weight(1f).fillMaxWidth().padding(horizontal = Tokens.Sizes.globalScreenMargin), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.Center) {
            mark?.invoke(this)
            LandingLine(line)
        }
        Column(Modifier.fillMaxWidth(), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(gap)) {
            PrimaryButton(primaryText, onPrimary, Modifier.padding(horizontal = Tokens.Sizes.globalButtonMarginH))
            if (linkText != null && onLink != null) TextLink(linkText, onLink)
            if (finePrint != null) FinePrint(finePrint, Modifier.padding(horizontal = Tokens.Sizes.globalButtonMarginH))
        }
    }
}

/**
 * C-33 onboarding pages: [page] changes with fade + expand / fade + shrink over `duration.global.pageTransition`
 * (500 ms, APK-X); under Reduce Motion only the fades run.
 */
@Composable
fun OnboardingPages(page: Int, modifier: Modifier = Modifier, content: @Composable (Int) -> Unit) {
    val reduce = reduceMotion()
    AnimatedContent(
        targetState = page,
        modifier = modifier,
        transitionSpec = { DsMotion.pageEnter(reduce) togetherWith DsMotion.pageExit(reduce) },
        label = "onboardingPage",
    ) { target -> Box(Modifier.fillMaxSize()) { content(target) } }
}
