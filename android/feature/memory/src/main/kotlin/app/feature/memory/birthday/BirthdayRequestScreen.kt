// Surface: birthday.request — design/surfaces/birthday.request.md
// References: references/auto/tribute/web/tribute-web-testimonials-contribution-page-viewport.png (+ computed styles),
// references/auto/tribute/web/tribute-web-ayejaye-contribution-page-viewport.png,
// references/auto/tribute/mockups/tribute-home-phone-step-1-contribution-page.png,
// references/auto/vidday/store/vidday-store-01.png, references/auto/vidday/frames/vidday-tour-t064-phone.png.
package app.feature.memory.birthday

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.asPaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicText
import androidx.compose.foundation.verticalScroll
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.max
import app.designsystem.R
import app.designsystem.generated.Tokens
import app.feature.memory.common.FilledButton
import app.feature.memory.common.MemoryFormats
import app.feature.memory.common.MemoryImage
import app.feature.memory.common.MessageBlock
import app.feature.memory.common.PlatformSpinner
import app.feature.memory.common.heading
import app.feature.memory.common.roleStyle
import app.feature.memory.common.headerClearance

/** The private request: hero (honoree photo at 0.7, title, due line, message), action, Message Ideas. */
@Composable
fun BirthdayRequestScreen(
    state: RequestState,
    onAddPhoto: () -> Unit,
    onRetake: () -> Unit,
    onRemove: () -> Unit,
    onRetry: () -> Unit,
    onClose: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Box(modifier.fillMaxSize().background(Tokens.Colors.globalBackgroundDeep).testTag("birthday.request")) {
        when (state) {
            RequestState.NotFound -> MessageBlock(
                stringResource(R.string.birthday_request_notfound_title),
                stringResource(R.string.birthday_request_notfound_detail),
                Modifier.fillMaxSize(),
            )
            RequestState.Failed -> MessageBlock(
                stringResource(R.string.birthday_request_error_title),
                stringResource(R.string.birthday_request_error_detail),
                Modifier.fillMaxSize(),
                action = stringResource(R.string.birthday_request_error_retry),
                onAction = onRetry,
            )
            RequestState.Loading, RequestState.Offline -> Column(Modifier.fillMaxSize()) {
                Hero(info = null) {}
                if (state == RequestState.Offline) {
                    BasicText(
                        stringResource(R.string.birthday_request_offline),
                        Modifier.padding(Tokens.Sizes.birthdayRequestMargin),
                        style = roleStyle(Tokens.FontSizes.globalListSubtitle, Tokens.FontWeights.fontWeightGlobalListSubtitle).copy(color = Tokens.Colors.globalTextSecondary),
                    )
                } else {
                    Box(Modifier.fillMaxWidth().weight(1f), contentAlignment = Alignment.Center) { PlatformSpinner() }
                }
            }
            is RequestState.Ready -> Ready(state, onAddPhoto, onRetake, onRemove)
        }
        LeadingHeaderCircle(Tokens.Icons.globalClose, stringResource(R.string.birthday_request_a11y_close), onClose)
    }
}

private val messageStyle @Composable get() = roleStyle(
    Tokens.FontSizes.birthdayRequestMessage, Tokens.FontWeights.fontWeightGlobalListSubtitle, Tokens.LineHeights.birthdayRequestMessage, Tokens.Fonts.birthday,
).copy(color = Tokens.Colors.globalTextPrimary.copy(alpha = Tokens.Opacities.birthdayRequestMessage))

/** Hero band: black, honoree photo at `opacity.birthday.request.hero.image`, text from the title top. */
@Composable
private fun Hero(info: RequestInfo?, content: @Composable () -> Unit) {
    // Title top: `dimension.birthday.request.title.top`, or below the safe-area header when that is taller.
    val titleTop = max(Tokens.Sizes.birthdayRequestTitleTop, headerClearance())
    Box(Modifier.fillMaxWidth().heightIn(min = Tokens.Sizes.birthdayRequestHeroHeight).background(Tokens.Colors.globalBackgroundDeep)) {
        if (info?.honoreeAvatarUrl != null) {
            MemoryImage(
                info.honoreeAvatarUrl,
                contentDescription = null,
                modifier = Modifier.matchParentSize().alpha(Tokens.Opacities.birthdayRequestHeroImage),
                contentScale = ContentScale.Crop,
            )
        }
        Column(Modifier.fillMaxWidth().padding(start = Tokens.Sizes.birthdayRequestMargin, end = Tokens.Sizes.birthdayRequestMargin, top = titleTop)) {
            content()
        }
    }
}

@Composable
private fun Ready(state: RequestState.Ready, onAddPhoto: () -> Unit, onRetake: () -> Unit, onRemove: () -> Unit) {
    val info = state.info
    val navigation = WindowInsets.navigationBars.asPaddingValues().calculateBottomPadding()
    Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState())) {
        Hero(info) {
            BasicText(
                stringResource(R.string.birthday_request_title, info.honoreeName),
                Modifier.heading(),
                style = roleStyle(Tokens.FontSizes.birthdayRequestTitle, Tokens.FontWeights.fontWeightBirthdayRequestTitle, Tokens.LineHeights.birthdayRequestTitle, Tokens.Fonts.birthday)
                    .copy(color = Tokens.Colors.globalTextPrimary),
            )
            if (!state.closed) {
                BasicText(stringResource(R.string.birthday_request_due, MemoryFormats.dueDate(info.birthdayDate)), style = messageStyle)
                Spacer(Modifier.size(Tokens.Sizes.birthdayRequestMessageGap))
                BasicText(
                    listOf(
                        stringResource(R.string.birthday_request_body, info.honoreeName),
                        stringResource(R.string.birthday_request_ease),
                        stringResource(R.string.birthday_request_thanks),
                    ).joinToString(" "),
                    style = messageStyle,
                )
            }
        }
        Column(Modifier.fillMaxWidth().padding(horizontal = Tokens.Sizes.birthdayRequestMargin)) {
            Spacer(Modifier.size(Tokens.Sizes.birthdayRequestCtaGap))
            when {
                state.closed -> MessageBlock(
                    stringResource(R.string.birthday_request_closed_title),
                    stringResource(R.string.birthday_request_closed_detail, info.honoreeName),
                    Modifier.fillMaxWidth(),
                )
                state.contribution != null -> OwnBlock(state.contribution, state.withdrawing, onRetake, onRemove)
                else -> FilledButton(
                    text = stringResource(R.string.birthday_request_cta),
                    onClick = onAddPhoto,
                    modifier = Modifier.fillMaxWidth(),
                    height = Tokens.Sizes.birthdayRequestCtaHeight,
                    shape = RoundedCornerShape(Tokens.Radii.birthdayRequestCta),
                    fill = Tokens.Colors.globalAccent,
                    label = Tokens.Colors.globalOnAccent,
                    textStyle = roleStyle(Tokens.FontSizes.birthdayRequestCta, Tokens.FontWeights.fontWeightBirthdayRequestCta, family = Tokens.Fonts.birthday),
                )
            }
            if (!state.closed) {
                Spacer(Modifier.size(Tokens.Sizes.birthdayRequestPromptsGap))
                MessageIdeas(info.honoreeName)
            }
            Spacer(Modifier.size(navigation + Tokens.Sizes.birthdayRequestMargin))
        }
    }
}

/** After contributing: "Your Photo", the photo, the line, then Retake and Remove. */
@Composable
private fun OwnBlock(own: OwnContribution, withdrawing: Boolean, onRetake: () -> Unit, onRemove: () -> Unit) {
    Column(Modifier.fillMaxWidth()) {
        BasicText(
            stringResource(R.string.birthday_request_contributed_title),
            Modifier.heading(),
            style = roleStyle(Tokens.FontSizes.birthdayContributeLabel, Tokens.FontWeights.fontWeightBirthdayContributeLabel, family = Tokens.Fonts.birthday)
                .copy(color = Tokens.Colors.globalTextPrimary),
        )
        Spacer(Modifier.size(Tokens.Sizes.globalListGap))
        BoxWithConstraints(Modifier.fillMaxWidth()) {
            MemoryImage(
                own.photoUrl,
                contentDescription = null,
                modifier = Modifier.fillMaxWidth().aspectRatio(own.aspectRatio).clip(RoundedCornerShape(Tokens.Radii.globalPhoto)),
            )
        }
        Spacer(Modifier.size(Tokens.Sizes.globalListGap))
        BasicText(own.line, style = roleStyle(Tokens.FontSizes.birthdayRequestMessage, Tokens.FontWeights.fontWeightGlobalListSubtitle, family = Tokens.Fonts.birthday).copy(color = Tokens.Colors.globalTextPrimary))
        Spacer(Modifier.size(Tokens.Sizes.birthdayRequestCtaGap))
        TributeSecondaryButton(stringResource(R.string.birthday_request_contributed_change), onRetake, enabled = !withdrawing)
        Spacer(Modifier.size(Tokens.Sizes.birthdayTributeButtonGap))
        TributeSecondaryButton(stringResource(R.string.birthday_request_contributed_remove), onRemove, enabled = !withdrawing)
    }
}
