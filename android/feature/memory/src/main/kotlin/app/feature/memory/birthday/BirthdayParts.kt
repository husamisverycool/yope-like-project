package app.feature.memory.birthday

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBars
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicText
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.layout.Layout
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.CollectionInfo
import androidx.compose.ui.semantics.CollectionItemInfo
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.collectionInfo
import androidx.compose.ui.semantics.collectionItemInfo
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import app.designsystem.R
import app.designsystem.generated.Tokens
import app.feature.memory.common.FilledButton
import app.feature.memory.common.HeaderCircleButton
import app.feature.memory.common.roleStyle
import app.feature.memory.common.touchOutset

/** A header row with one circle at the leading edge, in the safe area (foundations header). */
@Composable
fun LeadingHeaderCircle(icon: ImageVector, contentDescription: String, onClick: () -> Unit, modifier: Modifier = Modifier) {
    Box(modifier.fillMaxWidth().windowInsetsPadding(WindowInsets.statusBars)) {
        HeaderCircleButton(
            icon,
            contentDescription,
            onClick,
            Modifier.padding(start = Tokens.Sizes.globalHeaderInset - touchOutset(Tokens.Sizes.globalHeaderButton)),
        )
    }
}

/**
 * "Message Ideas" (Tribute prompts block with VidDay's prompts): header bar with top corners, then
 * the two prompts as a bulleted list on the page colour (Tribute's white card is a light-appearance
 * value, dropped — MERGE memory M-8).
 */
@Composable
fun MessageIdeas(honoreeName: String, modifier: Modifier = Modifier) {
    val radius = Tokens.Radii.birthdayRequestPrompts
    val promptStyle = roleStyle(Tokens.FontSizes.birthdayRequestPrompt, Tokens.FontWeights.fontWeightGlobalListSubtitle, Tokens.LineHeights.birthdayRequestPrompt, Tokens.Fonts.birthday)
        .copy(color = Tokens.Colors.globalTextPrimary)
    Column(modifier.fillMaxWidth()) {
        Box(
            Modifier
                .fillMaxWidth()
                .height(Tokens.Sizes.birthdayRequestPromptsHeaderHeight)
                .clip(RoundedCornerShape(topStart = radius, topEnd = radius))
                .background(Tokens.Colors.birthdayRequestPromptsHeader)
                .padding(start = Tokens.Sizes.birthdayRequestPromptsHeaderPadding, end = Tokens.Sizes.birthdayRequestPromptsHeaderPadding),
            contentAlignment = Alignment.CenterStart,
        ) {
            BasicText(
                stringResource(R.string.birthday_request_prompts_title),
                style = roleStyle(Tokens.FontSizes.birthdayRequestPromptsHeader, Tokens.FontWeights.fontWeightBirthdayRequestPromptsHeader, family = Tokens.Fonts.birthday)
                    .copy(color = Tokens.Colors.globalTextPrimary),
            )
        }
        Spacer(Modifier.size(Tokens.Sizes.birthdayRequestPromptTop))
        Column(Modifier.semantics { collectionInfo = CollectionInfo(rowCount = 2, columnCount = 1) }) {
            val prompts = listOf(
                stringResource(R.string.birthday_request_prompt_appreciate, honoreeName),
                stringResource(R.string.birthday_request_prompt_impact, honoreeName),
            )
            prompts.forEachIndexed { index, prompt ->
                if (index > 0) Spacer(Modifier.size(Tokens.Sizes.birthdayRequestPromptGap))
                Row(Modifier.semantics(mergeDescendants = true) { collectionItemInfo = CollectionItemInfo(index, 1, 0, 1) }) {
                    // The list marker sits in the indent, at the header label's start (Tribute <ul>).
                    Box(Modifier.width(Tokens.Sizes.birthdayRequestPromptIndent).clearAndSetSemantics { }) {
                        BasicText(BULLET, Modifier.padding(start = Tokens.Sizes.birthdayRequestPromptsHeaderPadding), style = promptStyle)
                    }
                    BasicText(prompt, style = promptStyle)
                }
            }
        }
    }
}

/** Typographic list marker of a bulleted list (not copy). */
private const val BULLET = "•"

/** Tribute's secondary button (Download / Share / Retake / Remove): white fill, dark label. */
@Composable
fun TributeSecondaryButton(text: String, onClick: () -> Unit, modifier: Modifier = Modifier, icon: ImageVector? = null, enabled: Boolean = true) =
    FilledButton(
        text = text,
        onClick = onClick,
        modifier = modifier.fillMaxWidth(),
        height = Tokens.Sizes.birthdayTributeButtonHeight,
        shape = RoundedCornerShape(Tokens.Radii.birthdayTributeButton),
        fill = Tokens.Colors.globalSurfaceLight,
        label = Tokens.Colors.birthdayTributeButtonLabel,
        textStyle = roleStyle(Tokens.FontSizes.birthdayTributeButton, Tokens.FontWeights.fontWeightBirthdayTributeButton, family = Tokens.Fonts.birthday),
        enabled = enabled,
        leading = icon,
    )

/** The step buttons of the contribute flow (Use Photo, Submit, Done): Tribute geometry, app lime. */
@Composable
fun StepButton(text: String, onClick: () -> Unit, modifier: Modifier = Modifier, enabled: Boolean = true, busy: Boolean = false, primary: Boolean = true) =
    FilledButton(
        text = text,
        onClick = onClick,
        modifier = modifier.fillMaxWidth(),
        height = Tokens.Sizes.birthdayContributeButtonHeight,
        shape = RoundedCornerShape(Tokens.Radii.birthdayContributeButton),
        fill = if (primary) Tokens.Colors.globalAccent else Tokens.Colors.globalSurfaceLight,
        label = if (primary) Tokens.Colors.globalOnAccent else Tokens.Colors.globalOnSurfaceLight,
        textStyle = roleStyle(Tokens.FontSizes.birthdayContributeButton, Tokens.FontWeights.fontWeightBirthdayContributeButton, family = Tokens.Fonts.birthday),
        enabled = enabled,
        busy = busy,
    )

/** The first number in a token's description (`layout.birthday.contribute.stepper` distribution: "11 pt"). */
internal fun firstNumber(text: String): Float = Regex("[0-9]+(\\.[0-9]+)?").find(text)?.value?.toFloat() ?: 0f

/**
 * The three-step indicator (`layout.birthday.contribute.stepper`): circles with numbers, captions
 * below; the first and last circle inside the margins by the token's distribution, the middle one
 * centred. One accessibility element whose label is the current step's caption; not interactive.
 */
@Composable
fun Stepper(current: Int, modifier: Modifier = Modifier) {
    val captions = listOf(
        stringResource(R.string.birthday_contribute_step_photo),
        stringResource(R.string.birthday_contribute_step_message),
        stringResource(R.string.birthday_contribute_step_done),
    )
    val circle = Tokens.Sizes.birthdayContributeStepperCircle
    val edgeInset: Dp = firstNumber(Tokens.Layouts.BirthdayContributeStepper.distribution).dp
    val labelGap: Dp = Tokens.Layouts.BirthdayContributeStepper.labelGap.dp
    Layout(
        modifier = modifier
            .fillMaxWidth()
            .padding(horizontal = Tokens.Sizes.birthdayContributeMargin)
            .clearAndSetSemantics { contentDescription = captions[current] },
        content = {
            captions.forEachIndexed { index, caption ->
                val active = index == current
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Box(
                        Modifier
                            .size(circle)
                            .clip(CircleShape)
                            .background(if (active) Tokens.Colors.birthdayContributeStepperActive else Tokens.Colors.birthdayContributeStepperInactive),
                        contentAlignment = Alignment.Center,
                    ) {
                        BasicText(
                            (index + 1).toString(),
                            style = roleStyle(Tokens.FontSizes.birthdayContributeStepperNumber, Tokens.FontWeights.fontWeightBirthdayContributeStepperNumber, family = Tokens.Fonts.birthday)
                                .copy(color = if (active) Tokens.Colors.globalTextPrimary else Tokens.Colors.birthdayContributeStepperInactiveLabel),
                        )
                    }
                    Spacer(Modifier.size(labelGap))
                    BasicText(
                        caption,
                        style = roleStyle(
                            Tokens.FontSizes.birthdayContributeStepperLabel,
                            if (active) Tokens.FontWeights.fontWeightBirthdayContributeStepperLabelActive else Tokens.FontWeights.fontWeightBirthdayContributeStepperLabel,
                            family = Tokens.Fonts.birthday,
                        ).copy(
                            color = if (active) Tokens.Colors.globalTextPrimary else Tokens.Colors.birthdayContributeStepperInactiveLabel,
                            textAlign = TextAlign.Center,
                        ),
                    )
                }
            }
        },
    ) { measurables, constraints ->
        val placeables = measurables.map { it.measure(constraints.copy(minWidth = 0, minHeight = 0)) }
        val width = constraints.maxWidth
        val circlePx = circle.roundToPx()
        val first = edgeInset.roundToPx() + circlePx / 2
        val last = width - edgeInset.roundToPx() - circlePx / 2
        val centres = List(placeables.size) { i -> if (placeables.size == 1) width / 2 else first + (last - first) * i / (placeables.size - 1) }
        val height = placeables.maxOf { it.height }
        layout(width, height) {
            placeables.forEachIndexed { i, p -> p.place(centres[i] - p.width / 2, 0) }
        }
    }
}
