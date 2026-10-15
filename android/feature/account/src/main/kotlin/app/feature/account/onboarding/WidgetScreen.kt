// Surface: onboarding.widget — guided add-the-widget step. Spec: design/surfaces/onboarding.widget.md.
// References: references/auto/locket/lazyweb/locket-lazyweb-20260821-cap-welcome.png (LW),
// references/owner/locket-add-widget-steps.jpg (LT), https://help.locket.com/en/articles/7914857 (HC),
// Locket Android 1.243.0 string table (APK), references/auto/locket/lazyweb/locket-lazyweb-20260821-cap-personalization-3.png (LP3).
package app.feature.account.onboarding

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawing
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextAlign
import androidx.navigation.NavController
import app.designsystem.R
import app.designsystem.dsTextStyle
import app.designsystem.generated.Tokens
import app.feature.account.LocalAccountEnvironment
import app.feature.account.blocked.BlockedCopy
import app.feature.account.common.AccountEvent
import app.feature.account.common.navigateAccount
import app.feature.account.shell.AccountFlow
import app.ui.text.CapTop
import app.ui.text.capTopAt

@Composable
fun WidgetRoute(nav: NavController) {
    val env = LocalAccountEnvironment.current
    val context = LocalContext.current
    val steps = listOfNotNull(
        context.getString(R.string.onboarding_widget_step_android_1),
        context.getString(R.string.onboarding_widget_step_android_2),
        // BLOCKED ({app_name}): omitted in release builds.
        BlockedCopy.widgetStepAndroid3(context),
    )
    WidgetScreen(steps) { nav.navigateAccount(AccountEvent.Navigate(AccountFlow.finishOnboarding(env), clearStack = true)) }
}

/**
 * Background gradient `onboarding.widget.color.backgroundTop` → `.backgroundBottom`; title
 * `onboarding.widget.fontSize.title` / `.fontWeight.title` / `.color.title`; numbered steps
 * `onboarding.widget.fontSize.step` / `.fontWeight.step` / `.lineHeight.step` / `.color.step`, one line
 * pitch apart, side margins `paywall.size.perkMarginH`; then `onboarding.widget.done`; the CTA capsule
 * at the bottom. No pin request (spec Platform notes: Locket's use of `requestPinAppWidget` was not
 * observed, so it is not part of this surface).
 */
@Composable
fun WidgetScreen(steps: List<String>, onContinue: () -> Unit) {
    val stepStyle = dsTextStyle(Tokens.FontSizes.onboardingWidgetFontSizeStep, Tokens.FontWeights.onboardingWidgetFontWeightStep, lineHeight = Tokens.LineHeights.onboardingWidgetLineHeightStep)
    Column(
        Modifier
            .fillMaxSize()
            .background(Brush.verticalGradient(listOf(Tokens.Colors.onboardingWidgetColorBackgroundTop, Tokens.Colors.onboardingWidgetColorBackgroundBottom)))
            .windowInsetsPadding(WindowInsets.safeDrawing),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Column(
            Modifier.weight(1f).fillMaxWidth().verticalScroll(rememberScrollState()).padding(horizontal = Tokens.Sizes.paywallSizePerkMarginH),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            val titleStyle = dsTextStyle(Tokens.FontSizes.onboardingWidgetFontSizeTitle, Tokens.FontWeights.onboardingWidgetFontWeightTitle)
            Text(
                stringResource(R.string.onboarding_widget_title),
                style = titleStyle,
                color = Tokens.Colors.onboardingWidgetColorTitle,
                textAlign = TextAlign.Center,
                // Cap top `groups.create.size.sheetTopToTitle` below the safe area (Structure 2).
                modifier = Modifier.capTopAt(Tokens.Sizes.groupsCreateSizeSheetTopToTitle, CapTop.height(titleStyle)).semantics { heading() },
            )
            Spacer(Modifier.height(Tokens.Sizes.groupsCreateSizeTitleToContent))
            Column(verticalArrangement = Arrangement.spacedBy(with(androidx.compose.ui.platform.LocalDensity.current) { Tokens.LineHeights.onboardingWidgetLineHeightStep.toDp() })) {
                steps.forEachIndexed { index, step ->
                    val number = (index + 1).toString()
                    val label = stringResource(R.string.onboarding_widget_stepnumber_accessibilitylabel, number)
                    val numbered = numberedStep(number, step)
                    // TalkBack: "step {number}" then the text, as one element (platform merge).
                    Box(Modifier.fillMaxWidth().semantics(mergeDescendants = true) {}) {
                        Box(Modifier.matchParentSize().semantics { contentDescription = label })
                        Text(
                            numbered,
                            style = stepStyle,
                            color = Tokens.Colors.onboardingWidgetColorStep,
                            textAlign = TextAlign.Center,
                            modifier = Modifier.fillMaxWidth().clearAndSetSemantics { contentDescription = step },
                        )
                    }
                }
                Text(
                    stringResource(R.string.onboarding_widget_done),
                    style = stepStyle,
                    color = Tokens.Colors.onboardingWidgetColorStep,
                    textAlign = TextAlign.Center,
                    modifier = Modifier.fillMaxWidth(),
                )
            }
        }
        WidgetCta(stringResource(R.string.onboarding_widget_continue), onContinue)
        Spacer(Modifier.height(Tokens.Sizes.groupsCreateSizeFieldToButton))
    }
}

/** "1." + space + text: numeral and period as in LT ("1. Edit Home Screen"). */
private fun numberedStep(number: String, text: String): String = number + STEP_SEPARATOR + text

private const val STEP_SEPARATOR = ". "

/**
 * The yellow CTA capsule: height `onboarding.widget.size.ctaHeight`, fill `.color.cta`, label
 * `.fontSize.ctaLabel` bold in `.color.ctaLabel`, trailing arrow `.icon.ctaArrow` (width
 * `.size.ctaArrow`) after `.size.ctaArrowGap`, padding `.size.ctaPaddingH`, capsule; content width.
 */
@Composable
private fun WidgetCta(text: String, onClick: () -> Unit) {
    Row(
        Modifier
            .heightIn(min = Tokens.Sizes.onboardingWidgetSizeCtaHeight)
            .clip(CircleShape)
            .background(Tokens.Colors.onboardingWidgetColorCta, CircleShape)
            .clickable(role = Role.Button, onClick = onClick)
            .padding(horizontal = Tokens.Sizes.onboardingWidgetSizeCtaPaddingH),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(Tokens.Sizes.onboardingWidgetSizeCtaArrowGap),
    ) {
        Text(
            text,
            style = dsTextStyle(Tokens.FontSizes.onboardingWidgetFontSizeCtaLabel, Tokens.FontWeights.onboardingWidgetFontWeightTitle),
            color = Tokens.Colors.onboardingWidgetColorCtaLabel,
        )
        Icon(Tokens.Icons.onboardingWidgetIconCtaArrow, contentDescription = null, tint = Tokens.Colors.onboardingWidgetColorCtaLabel, modifier = Modifier.width(Tokens.Sizes.onboardingWidgetSizeCtaArrow))
    }
}
