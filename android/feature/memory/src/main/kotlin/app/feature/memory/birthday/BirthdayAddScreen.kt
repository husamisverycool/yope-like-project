// Surface: birthday.add — design/surfaces/birthday.add.md
// References: references/auto/yope/frames/a-chuongxetank-7694968408424582452-t7.73-posted-toast-contacts-card.png,
// references/auto/yope/frames/a-virgi-7686278541255642390-t31.23-signup-es.png,
// references/auto/yope/frames/a-itsmthuyope-7644974799302823175-t45.23-new-group-empty.png; https://www.yope.tv/legal.
package app.feature.memory.birthday

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBars
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.BasicText
import androidx.compose.foundation.verticalScroll
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.style.TextAlign
import app.designsystem.R
import app.designsystem.generated.Tokens
import app.feature.memory.common.HeaderCircleButton
import app.feature.memory.common.LightPill
import app.feature.memory.common.LimeButton
import app.feature.memory.common.MemoryFormats
import app.feature.memory.common.MemoryToast
import app.feature.memory.common.PlatformSpinner
import app.feature.memory.common.toastsShown
import app.feature.memory.common.heading
import app.feature.memory.common.roleStyle
import app.feature.memory.common.touchOutset

/**
 * Add your birthday (not opted in) or manage it (opted in). Yope onboarding-step layout on
 * `color.global.backgroundDeep`; buttons pinned to the bottom; the content scrolls when the title
 * wraps at large text sizes.
 */
@Composable
fun BirthdayAddScreen(
    state: BirthdayAddState,
    pattern: DateEntryPattern,
    onDigits: (String) -> Unit,
    onAdd: () -> Unit,
    onRemove: () -> Unit,
    onLater: () -> Unit,
    onClose: () -> Unit,
    onDismissToast: () -> Unit,
    modifier: Modifier = Modifier,
) {
    // Added: close after the toast; while the toast dwell is BLOCKED there is no toast, so close at once.
    val toasts = toastsShown()
    LaunchedEffect(state.finished, toasts) { if (state.finished && !toasts) onClose() }
    val text = Tokens.Colors.globalTextPrimary
    val secondary = roleStyle(Tokens.FontSizes.globalListSubtitle, Tokens.FontWeights.fontWeightGlobalListSubtitle)
        .copy(color = Tokens.Colors.globalTextSecondary, textAlign = TextAlign.Center)
    Box(modifier.fillMaxSize().background(Tokens.Colors.globalBackgroundDeep).testTag("birthday.add")) {
        Column(Modifier.fillMaxSize().imePadding()) {
            Box(Modifier.fillMaxWidth().windowInsetsPadding(WindowInsets.statusBars)) {
                HeaderCircleButton(
                    Tokens.Icons.globalClose,
                    stringResource(R.string.birthday_add_a11y_close),
                    onClose,
                    Modifier.padding(start = Tokens.Sizes.globalHeaderInset - touchOutset(Tokens.Sizes.globalHeaderButton)),
                )
            }
            if (state.loading) {
                Box(Modifier.fillMaxWidth().weight(1f), contentAlignment = Alignment.Center) { PlatformSpinner() }
                return@Column
            }
            Column(
                Modifier
                    .fillMaxWidth()
                    .weight(1f)
                    .verticalScroll(rememberScrollState())
                    .padding(horizontal = Tokens.Sizes.globalButtonMarginH),
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                if (state.optedIn) {
                    BasicText(
                        stringResource(R.string.birthday_add_manage_title),
                        Modifier.heading(),
                        style = roleStyle(Tokens.FontSizes.globalSheetTitle, Tokens.FontWeights.fontWeightGlobalSheetTitle).copy(color = text, textAlign = TextAlign.Center),
                    )
                    Spacer(Modifier.size(Tokens.Sizes.globalListGap))
                    BasicText(
                        MemoryFormats.dayMonth(state.saved!!),
                        style = roleStyle(Tokens.FontSizes.globalListTitle, Tokens.FontWeights.fontWeightGlobalListTitle).copy(color = text, textAlign = TextAlign.Center),
                    )
                    Spacer(Modifier.size(Tokens.Sizes.globalListGap))
                    BasicText(stringResource(R.string.birthday_add_detail), style = secondary)
                } else {
                    BasicText(
                        stringResource(R.string.birthday_add_title),
                        Modifier.heading(),
                        style = roleStyle(Tokens.FontSizes.globalOnboardingTitle, Tokens.FontWeights.fontWeightGlobalOnboardingTitle)
                            .copy(color = text, textAlign = TextAlign.Center),
                    )
                    Spacer(Modifier.size(Tokens.Sizes.globalListGap))
                    BasicText(stringResource(R.string.birthday_add_detail), style = secondary)
                    Spacer(Modifier.size(Tokens.Sizes.globalListGap))
                    BasicText(stringResource(R.string.birthday_add_privacy), style = secondary)
                    Spacer(Modifier.size(Tokens.Sizes.globalListGap))
                    BirthdayDateField(state.digits, onDigits, Modifier.fillMaxWidth(), enabled = !state.busy, pattern = pattern)
                }
                state.inline?.let { inline ->
                    Spacer(Modifier.size(Tokens.Sizes.globalListGap))
                    BasicText(
                        stringResource(if (inline == BirthdayAddState.Inline.Invalid) R.string.birthday_add_invalid else R.string.birthday_add_offline),
                        style = secondary,
                    )
                }
            }
            Column(
                Modifier
                    .fillMaxWidth()
                    .windowInsetsPadding(WindowInsets.navigationBars)
                    .padding(start = Tokens.Sizes.globalButtonMarginH, end = Tokens.Sizes.globalButtonMarginH, bottom = Tokens.Sizes.globalButtonMarginH),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(Tokens.Sizes.globalListGap),
            ) {
                if (state.error) {
                    BasicText(
                        stringResource(R.string.birthday_add_error_title),
                        style = roleStyle(Tokens.FontSizes.globalEmptyTitle, Tokens.FontWeights.fontWeightGlobalEmptyTitle).copy(color = text, textAlign = TextAlign.Center),
                    )
                    BasicText(
                        stringResource(R.string.birthday_add_error_detail),
                        style = roleStyle(Tokens.FontSizes.globalEmptyDetail, Tokens.FontWeights.fontWeightGlobalListSubtitle)
                            .copy(color = Tokens.Colors.globalTextSecondary, textAlign = TextAlign.Center, fontStyle = androidx.compose.ui.text.font.FontStyle.Italic),
                    )
                }
                if (state.optedIn) {
                    LightPill(stringResource(R.string.birthday_add_manage_remove), onRemove, Modifier.fillMaxWidth(), enabled = !state.busy)
                } else {
                    LimeButton(
                        stringResource(if (state.error) R.string.birthday_add_error_retry else R.string.birthday_add_confirm),
                        onAdd,
                        Modifier.fillMaxWidth(),
                        enabled = pattern.parse(state.digits) != null,
                        busy = state.busy,
                    )
                    LightPill(stringResource(R.string.birthday_add_later), onLater, Modifier.fillMaxWidth(), enabled = !state.busy)
                }
            }
        }
        MemoryToast(
            message = when (state.toast) {
                BirthdayAddState.Toast.Added -> stringResource(R.string.birthday_add_added)
                BirthdayAddState.Toast.Removed -> stringResource(R.string.birthday_add_removed)
                null -> null
            },
            onDismiss = onDismissToast,
        )
    }
}
