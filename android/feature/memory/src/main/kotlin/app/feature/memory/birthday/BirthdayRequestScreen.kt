// Surface: birthday.request — design/surfaces/birthday.request.md (composition of Retro components C-34, C-11, C-05, C-10, C-29
// in Tribute / VidDay's order). References: references/auto/retro/lazyweb/retro-lazyweb-20260529-paywall.png (PAY),
// references/auto/retro/press/tc-2023-12-retro3.png phone 1, references/auto/vidday/store/vidday-store-01.png,
// references/auto/tribute/mockups/tribute-home-phone-step-1-contribution-page.png (mechanics).
package app.feature.memory.birthday

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBars
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.LineBreak
import androidx.compose.ui.text.style.TextAlign
import app.designsystem.R
import app.designsystem.dsTextStyle
import app.designsystem.generated.Tokens
import app.feature.memory.common.MediaAppearance
import app.feature.memory.common.MediaMessage
import app.feature.memory.common.MemoryFormats
import app.feature.memory.common.MemoryImage
import app.feature.memory.common.memoryModel
import app.feature.memory.common.MemoryBackdrop
import app.ui.components.Avatar
import app.ui.components.Capsule
import app.ui.components.CapsuleRowSpacing
import app.ui.components.CapsuleStyle
import app.ui.components.CircleButtonStyle
import app.ui.components.CircleIconButton
import app.ui.components.DestructiveTextButton
import app.ui.components.EmptyState
import app.ui.components.EmptyStateFill
import app.ui.components.LoadingState
import app.ui.components.PlanCard
import app.ui.components.PlatformToast
import app.ui.foundation.PageRoles
import app.ui.foundation.centreAt
import app.ui.foundation.endAtLastBaseline
import app.ui.system.SystemAlertDialog
import app.ui.text.CapTop
import app.ui.text.TextRoles
import app.ui.text.capTopAt

/** Test tags (flow tests). */
object BirthdayRequestTags {
    const val ROOT = "birthday.request"
    const val CTA = "birthday.request.cta"
    const val CHANGE = "birthday.request.change"
    const val REMOVE = "birthday.request.remove"
}

/** The request screen's actions. */
data class RequestActions(
    val onAddPhoto: () -> Unit = {},
    val onChangePhoto: () -> Unit = {},
    val onRemove: () -> Unit = {},
    val onRetry: () -> Unit = {},
    val onClose: () -> Unit = {},
    val onToastShown: () -> Unit = {},
)

/**
 * The private request (PAY composition): the honoree's photo blurred over the screen (C-34 backdrop, dark in both
 * appearances; no photo → `color.global.backgroundDeep`); the glass close circle (C-11 small) `close.inset` from the
 * right edge, centred `close.centerY` below the safe-area top; bottom-anchored above the safe-area bottom: the
 * honoree's avatar (C-23 `size.global.avatarProfile`), the serif headline, the invitation, the card (C-34 plan card,
 * follows the appearance) with "Message ideas", the detail, two numbered prompt rows and the C-05 "Add your photo" —
 * or your contribution (C-15 thumbnail + line, "Change photo" / "Remove") — and the due line under the card. The page
 * scrolls at large text sizes. [toast]: a confirmation to show once (C-26).
 */
@Composable
fun BirthdayRequestScreen(state: RequestState, actions: RequestActions, modifier: Modifier = Modifier, toast: FlowToast? = null) {
    val context = LocalContext.current
    val toastText = when (toast) {
        FlowToast.Added -> stringResource(R.string.birthday_contribute_done_title)
        FlowToast.Removed -> stringResource(R.string.birthday_request_removed)
        null -> null
    }
    LaunchedEffect(toastText) {
        if (toastText != null) {
            PlatformToast.show(context, toastText)
            actions.onToastShown()
        }
    }
    Box(modifier.fillMaxSize().background(Tokens.Colors.globalBackgroundDeep).testTag(BirthdayRequestTags.ROOT)) {
        when (state) {
            RequestState.Loading -> MediaAppearance { LoadingState(stringResource(R.string.birthday_request_loading), onMedia = true) }
            RequestState.NotFound -> MediaAppearance { EmptyStateFill { EmptyState(stringResource(R.string.birthday_request_notfound_title), null) } }
            RequestState.Failed -> MediaAppearance {
                EmptyStateFill {
                    MediaMessage(
                        stringResource(R.string.birthday_request_error_title),
                        stringResource(R.string.birthday_request_error_detail),
                        retry = stringResource(R.string.birthday_request_error_retry),
                        onRetry = actions.onRetry,
                    )
                }
            }
            RequestState.Offline -> MediaAppearance {
                EmptyStateFill {
                    MediaMessage(
                        stringResource(R.string.birthday_request_offline_title),
                        stringResource(R.string.birthday_request_offline),
                        retry = stringResource(R.string.birthday_request_error_retry),
                        onRetry = actions.onRetry,
                    )
                }
            }
            is RequestState.Ready -> Ready(state, actions)
        }
        Box(
            Modifier
                .align(Alignment.TopEnd)
                .windowInsetsPadding(WindowInsets.statusBars)
                .padding(end = Tokens.Sizes.birthdayRequestCloseInset)
                .centreAt(Tokens.Sizes.birthdayRequestCloseCenterY),
        ) {
            CircleIconButton(Tokens.Icons.globalClose, stringResource(R.string.birthday_request_a11y_close), actions.onClose, style = CircleButtonStyle.GlassSmall)
        }
    }
}

@Composable
private fun Ready(state: RequestState.Ready, actions: RequestActions) {
    val info = state.info
    var confirmRemove by remember { mutableStateOf(false) }
    if (info.honoreeAvatarUrl != null) MemoryBackdrop(info.honoreeAvatarUrl)
    BoxWithConstraints(Modifier.fillMaxSize()) {
        Column(
            Modifier
                .fillMaxWidth()
                .verticalScroll(rememberScrollState())
                .heightIn(min = maxHeight)
                .windowInsetsPadding(WindowInsets.statusBars)
                .windowInsetsPadding(WindowInsets.navigationBars),
            verticalArrangement = Arrangement.Bottom,
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Avatar(memoryModel(info.honoreeAvatarUrl), Tokens.Sizes.globalAvatarProfile)
            val headline = TextRoles.displayMedium.copy(lineBreak = LineBreak.Heading)
            Text(
                stringResource(R.string.birthday_request_title, info.honoreeName),
                style = headline,
                color = Tokens.Colors.globalTextOnMedia,
                textAlign = TextAlign.Center,
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = Tokens.Sizes.globalButtonMarginH)
                    .capTopAt(Tokens.Sizes.globalEmptyIconToTitle, CapTop.height(headline))
                    .endAtLastBaseline()
                    .semantics { heading() },
            )
            val body = TextRoles.textButton
            Text(
                stringResource(R.string.birthday_request_body, info.honoreeName),
                style = body,
                color = Tokens.Colors.globalTextOnMedia,
                textAlign = TextAlign.Center,
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = Tokens.Sizes.globalButtonMarginH)
                    .capTopAt(Tokens.Sizes.birthdayRequestHeadlineToMessage, CapTop.height(body)),
            )
            Spacer(Modifier.height(Tokens.Sizes.birthdayRequestMessageToCard))
            val cardModifier = Modifier.fillMaxWidth().padding(horizontal = Tokens.Sizes.globalButtonMarginH)
            when {
                state.closed -> RequestCard(cardModifier) {
                    EmptyState(stringResource(R.string.birthday_request_closed_title), stringResource(R.string.birthday_request_closed_detail, info.honoreeName), Modifier.fillMaxWidth())
                }
                state.contribution != null -> RequestCard(cardModifier) {
                    Contributed(state.contribution, actions.onChangePhoto) { confirmRemove = true }
                }
                else -> PlanCard(stringResource(R.string.birthday_request_cta), actions.onAddPhoto, cardModifier.testTag(BirthdayRequestTags.CTA)) {
                    Prompts(info.honoreeName)
                }
            }
            if (!state.closed) {
                val caption = TextRoles.caption
                Text(
                    stringResource(R.string.birthday_request_due, MemoryFormats.dueDate(info.birthdayDate)),
                    style = caption,
                    color = Tokens.Colors.globalTextOnMedia,
                    textAlign = TextAlign.Center,
                    modifier = Modifier.fillMaxWidth().padding(horizontal = Tokens.Sizes.globalButtonMarginH).capTopAt(Tokens.Sizes.birthdayRequestCardToFooter, CapTop.height(caption)),
                )
            } else {
                Spacer(Modifier.height(Tokens.Sizes.birthdayRequestCardToFooter))
            }
        }
    }
    if (confirmRemove) {
        SystemAlertDialog(
            title = stringResource(R.string.birthday_request_remove_title),
            text = stringResource(R.string.birthday_request_remove_message, info.honoreeName),
            confirmLabel = stringResource(R.string.birthday_request_remove_confirm),
            onConfirm = {
                confirmRemove = false
                actions.onRemove()
            },
            dismissLabel = stringResource(R.string.birthday_request_remove_cancel),
            onDismiss = { confirmRemove = false },
            destructive = true,
        )
    }
}

/**
 * The card's content while the request is open: "Message ideas" (`fontSize` / `fontWeight.birthday.request.cardTitle`,
 * `color.global.textPrimary`), `card.titleToDetail` below its baseline the detail (`body`, secondary text),
 * `card.blockGap` below the two numbered prompt rows (centres `card.rowPitch` apart: an accent marker
 * `card.marker` with the number in text role `badge`, `card.markerGap`, the prompt in `textButton`), then
 * `card.blockGap` to the capsule (the plan card's own padding plus the difference).
 */
@Composable
private fun ColumnScope.Prompts(name: String) {
    CardTitle(stringResource(R.string.birthday_request_prompts_title))
    CardDetail(stringResource(R.string.birthday_request_card_detail))
    Spacer(Modifier.height(Tokens.Sizes.birthdayRequestCardBlockGap - (Tokens.Sizes.birthdayRequestCardRowPitch - CapTop.height(TextRoles.textButton)) / 2))
    Column(Modifier.semantics(mergeDescendants = false) {}) {
        PromptRow(1, stringResource(R.string.birthday_request_prompt_appreciate, name))
        PromptRow(2, stringResource(R.string.birthday_request_prompt_impact, name))
    }
    Spacer(Modifier.height((Tokens.Sizes.birthdayRequestCardBlockGap - Tokens.Sizes.globalPlanCardPadding).coerceAtLeastZero()))
}

@Composable
private fun CardTitle(text: String) {
    Text(
        text,
        style = dsTextStyle(Tokens.FontSizes.birthdayRequestCardTitle, Tokens.FontWeights.fontWeightBirthdayRequestCardTitle, Tokens.Fonts.globalFamily),
        color = Tokens.Colors.globalTextPrimary,
        modifier = Modifier.endAtLastBaseline().semantics { heading() },
    )
}

@Composable
private fun CardDetail(text: String) {
    val style = TextRoles.body
    Text(text, style = style, color = PageRoles.secondaryText(), modifier = Modifier.capTopAt(Tokens.Sizes.birthdayRequestCardTitleToDetail, CapTop.height(style)))
}

@Composable
private fun PromptRow(number: Int, text: String) {
    Row(Modifier.fillMaxWidth().heightIn(min = Tokens.Sizes.birthdayRequestCardRowPitch), verticalAlignment = Alignment.CenterVertically) {
        Box(
            Modifier
                .size(Tokens.Sizes.birthdayRequestCardMarker)
                .clip(CircleShape)
                .background(Tokens.Colors.globalAccent, CircleShape)
                .clearAndSetSemantics { },
            contentAlignment = Alignment.Center,
        ) {
            Text(MemoryFormats.position(number), style = TextRoles.badge, color = Tokens.Colors.globalOnAccent)
        }
        Spacer(Modifier.width(Tokens.Sizes.birthdayRequestCardMarkerGap))
        Text(text, style = TextRoles.textButton, color = Tokens.Colors.globalTextPrimary, modifier = Modifier.weight(1f))
    }
}

/** The plan-card look without its capsule (C-34): `color.global.surfaceElevated`, `radius.global.cardLarge`, `size.global.planCardPadding`. */
@Composable
private fun RequestCard(modifier: Modifier, content: @Composable ColumnScope.() -> Unit) {
    val shape = RoundedCornerShape(Tokens.Radii.globalCardLarge)
    Column(modifier.clip(shape).background(Tokens.Colors.globalSurfaceElevated, shape).padding(Tokens.Sizes.globalPlanCardPadding), content = content)
}

/**
 * Your contribution: "You added a photo"; your photo (C-15 thumbnail `size.global.rowThumbWidth` × `.rowThumbHeight`,
 * `radius.global.thumbnail`) with your line beside it (`body`, `size.global.rowThumbGap`); then the outline capsule
 * "Change photo" (C-06) and the destructive "Remove" (C-10), `size.global.pillGap` apart.
 */
@Composable
private fun ColumnScope.Contributed(contribution: OwnContribution, onChange: () -> Unit, onRemove: () -> Unit) {
    CardTitle(stringResource(R.string.birthday_request_contributed_title))
    Spacer(Modifier.height(Tokens.Sizes.birthdayRequestCardTitleToDetail))
    Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
        MemoryImage(
            contribution.photoUrl,
            null,
            Modifier.size(Tokens.Sizes.globalRowThumbWidth, Tokens.Sizes.globalRowThumbHeight).clip(RoundedCornerShape(Tokens.Radii.globalThumbnail)),
            placeholder = Tokens.Colors.globalControl,
        )
        Spacer(Modifier.width(Tokens.Sizes.globalRowThumbGap))
        Text(contribution.line, style = TextRoles.body, color = Tokens.Colors.globalTextPrimary, modifier = Modifier.weight(1f))
    }
    Spacer(Modifier.height(Tokens.Sizes.birthdayRequestCardBlockGap))
    Row(Modifier.fillMaxWidth(), horizontalArrangement = CapsuleRowSpacing, verticalAlignment = Alignment.CenterVertically) {
        Capsule(stringResource(R.string.birthday_request_contributed_change), onChange, Modifier.weight(1f).testTag(BirthdayRequestTags.CHANGE), style = CapsuleStyle.Outline)
        DestructiveTextButton(stringResource(R.string.birthday_request_contributed_remove), onRemove, Modifier.testTag(BirthdayRequestTags.REMOVE))
    }
}

private fun androidx.compose.ui.unit.Dp.coerceAtLeastZero() = if (value < 0f) androidx.compose.ui.unit.Dp(0f) else this
