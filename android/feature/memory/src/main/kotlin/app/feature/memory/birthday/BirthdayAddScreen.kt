// Surface: birthday.add — design/surfaces/birthday.add.md (composition of Retro components C-33, C-12, C-05, C-08, C-14, C-10, C-29)
// References: references/auto/retro/lazyweb/retro-lazyweb-20251119-social.png (LAND), references/auto/retro/lazyweb/retro-lazyweb-20251020-week43-dark.png (H43),
// references/auto/retro/store/editorial/retro-appstore-story-1854931006-week3-albums.png (ED-W3).
package app.feature.memory.birthday

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.paddingFrom
import androidx.compose.foundation.layout.statusBars
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.rememberScrollState
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
import androidx.compose.ui.layout.FirstBaseline
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextAlign
import app.designsystem.R
import app.designsystem.generated.Tokens
import app.feature.memory.common.MemoryFormats
import app.ui.components.EmptyState
import app.ui.components.GroupedRowSpec
import app.ui.components.GroupedSection
import app.ui.components.GroupedTrailing
import app.ui.components.LoadingState
import app.ui.components.OnboardingTitle
import app.ui.components.PlatformToast
import app.ui.components.PrimaryButton
import app.ui.components.PushedHeader
import app.ui.components.TextLink
import app.ui.foundation.PageRoles
import app.ui.foundation.endAtLastBaseline
import app.ui.system.SystemAlertDialog
import app.ui.text.CapTop
import app.ui.text.TextRoles
import app.ui.text.capTopAt

/** Test tags (flow tests). */
object BirthdayAddTags {
    const val ROOT = "birthday.add"
    const val CONFIRM = "birthday.add.confirm"
    const val REMOVE = "birthday.add.remove"
}

/**
 * Add your birthday (not opted in) or manage it (opted in), pushed from the settings row, on the page
 * (`color.global.background.android`, follows the appearance) under the C-02 header "Birthday".
 *
 * Not opted in — the C-27-placed block centred in the free space above the bottom controls: the C-33 headline
 * (`displayMedium`, display serif), `size.global.emptyIconToTitle` below its baseline the detail (`body`, secondary
 * text), `size.global.listGap` below the privacy line, `size.global.emptyTitleToAction` below the auth.agegate date
 * field (C-12); pinned to the bottom the C-05 capsule (disabled until the date is complete; busy while saving; "Try
 * Again" after an error) and the C-08 "Maybe later" link. Manage — C-14: the "Birthday" row with the day and month,
 * the detail as the section's footer, then the C-10 "Remove Birthday" row → native confirmation (C-29).
 */
@Composable
fun BirthdayAddScreen(
    state: BirthdayAddState,
    pattern: DateEntryPattern,
    onDigits: (String) -> Unit,
    onAdd: () -> Unit,
    onRemove: () -> Unit,
    onLater: () -> Unit,
    onBack: () -> Unit,
    onDismissToast: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val context = LocalContext.current
    val toast = when (state.toast) {
        BirthdayAddState.Toast.Added -> stringResource(R.string.birthday_add_added)
        BirthdayAddState.Toast.Removed -> stringResource(R.string.birthday_add_removed)
        null -> null
    }
    // C-26: the platform toast; "Added" then closes the screen (the view model decides).
    LaunchedEffect(toast) {
        if (toast != null) {
            PlatformToast.show(context, toast)
            onDismissToast()
        }
    }
    Column(
        modifier
            .fillMaxSize()
            .background(PageRoles.page)
            .windowInsetsPadding(WindowInsets.statusBars)
            .imePadding()
            .testTag(BirthdayAddTags.ROOT),
    ) {
        // birthday.add has no back label of its own: the platform "Back" of the memory group (copy gap, reported).
        PushedHeader(stringResource(R.string.birthday_add_manage_title), onBack, stringResource(R.string.onthisday_a11y_back))
        when {
            state.loading -> LoadingState(null, Modifier.weight(1f))
            state.optedIn -> Manage(state, onRemove)
            else -> AddForm(state, pattern, onDigits, onAdd, onLater)
        }
    }
}

@Composable
private fun androidx.compose.foundation.layout.ColumnScope.AddForm(
    state: BirthdayAddState,
    pattern: DateEntryPattern,
    onDigits: (String) -> Unit,
    onAdd: () -> Unit,
    onLater: () -> Unit,
) {
    val secondary = PageRoles.secondaryText()
    val complete = pattern.parse(state.digits) != null
    // The block scrolls when the headline wraps; the capsule stays pinned.
    Box(Modifier.weight(1f).fillMaxWidth().verticalScroll(rememberScrollState()), contentAlignment = Alignment.Center) {
        Column(Modifier.fillMaxWidth().padding(horizontal = Tokens.Sizes.globalScreenMargin), horizontalAlignment = Alignment.CenterHorizontally) {
            OnboardingTitle(stringResource(R.string.birthday_add_title), Modifier.endAtLastBaseline())
            Text(
                stringResource(R.string.birthday_add_detail),
                style = TextRoles.body,
                color = secondary,
                textAlign = TextAlign.Center,
                modifier = Modifier.fillMaxWidth().capTopAt(Tokens.Sizes.globalEmptyIconToTitle, CapTop.height(TextRoles.body)).endAtLastBaseline(),
            )
            Text(
                stringResource(R.string.birthday_add_privacy),
                style = TextRoles.body,
                color = secondary,
                textAlign = TextAlign.Center,
                modifier = Modifier.fillMaxWidth().capTopAt(Tokens.Sizes.globalListGap, CapTop.height(TextRoles.body)),
            )
            Spacer(Modifier.height(Tokens.Sizes.globalEmptyTitleToAction))
            BirthdayDateField(
                digits = state.digits,
                onDigitsChange = onDigits,
                enabled = !state.busy,
                error = if (state.inline == BirthdayAddState.Inline.Invalid) stringResource(R.string.birthday_add_invalid) else null,
                pattern = pattern,
            )
            if (state.inline == BirthdayAddState.Inline.Offline) {
                // C-12 inline line under the field (text role `meta`, secondary text), inset like the field's error.
                Text(
                    stringResource(R.string.birthday_add_offline),
                    style = TextRoles.meta,
                    color = secondary,
                    modifier = Modifier.fillMaxWidth().padding(horizontal = Tokens.Radii.globalField).semantics { liveRegion = LiveRegionMode.Polite },
                )
            }
            if (state.error) {
                Spacer(Modifier.height(Tokens.Sizes.globalEmptyTitleToAction))
                EmptyState(stringResource(R.string.birthday_add_error_title), stringResource(R.string.birthday_add_error_detail))
            }
        }
    }
    Column(
        Modifier
            .fillMaxWidth()
            .windowInsetsPadding(WindowInsets.navigationBars)
            .padding(horizontal = Tokens.Sizes.globalButtonMarginH)
            .padding(bottom = Tokens.Sizes.globalScreenMargin),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(Tokens.Sizes.globalScreenMargin),
    ) {
        PrimaryButton(
            stringResource(if (state.error) R.string.birthday_add_error_retry else R.string.birthday_add_confirm),
            onAdd,
            Modifier.testTag(BirthdayAddTags.CONFIRM),
            enabled = complete,
            loading = state.busy,
        )
        TextLink(stringResource(R.string.birthday_add_later), onLater, enabled = !state.busy)
    }
}

@Composable
private fun Manage(state: BirthdayAddState, onRemove: () -> Unit) {
    var confirm by remember { mutableStateOf(false) }
    val saved = state.saved ?: return
    val secondary = PageRoles.secondaryText()
    Column(Modifier.fillMaxWidth().verticalScroll(rememberScrollState()).padding(top = Tokens.Sizes.globalTitleToContent)) {
        GroupedSection(
            listOf(GroupedRowSpec(stringResource(R.string.birthday_add_manage_title), trailing = GroupedTrailing.Value(MemoryFormats.dayMonth(saved)))),
        )
        // The section footer (C-14 footer: text role `meta`, secondary text), aligned with the rows' text.
        Text(
            stringResource(R.string.birthday_add_detail),
            style = TextRoles.meta,
            color = secondary,
            modifier = Modifier.padding(horizontal = Tokens.Sizes.globalScreenMargin * 2).paddingFrom(FirstBaseline, before = Tokens.Sizes.globalSectionHeaderToContent),
        )
        Spacer(Modifier.height(Tokens.Sizes.globalSectionGap))
        GroupedSection(
            listOf(
                GroupedRowSpec(
                    stringResource(R.string.birthday_add_manage_remove),
                    trailing = GroupedTrailing.None,
                    destructive = true,
                    enabled = !state.busy,
                    onClick = { confirm = true },
                ),
            ),
            Modifier.testTag(BirthdayAddTags.REMOVE),
        )
        if (state.inline == BirthdayAddState.Inline.Offline) {
            Text(
                stringResource(R.string.birthday_add_offline),
                style = TextRoles.meta,
                color = secondary,
                modifier = Modifier.padding(horizontal = Tokens.Sizes.globalScreenMargin * 2, vertical = Tokens.Sizes.globalSectionHeaderToContent),
            )
        }
        if (state.error) {
            Spacer(Modifier.height(Tokens.Sizes.globalEmptyTitleToAction))
            EmptyState(stringResource(R.string.birthday_add_error_title), stringResource(R.string.birthday_add_error_detail), Modifier.fillMaxWidth())
        }
    }
    if (confirm) {
        SystemAlertDialog(
            title = stringResource(R.string.birthday_add_remove_title),
            text = stringResource(R.string.birthday_add_remove_message),
            confirmLabel = stringResource(R.string.birthday_add_remove_confirm),
            onConfirm = {
                confirm = false
                onRemove()
            },
            dismissLabel = stringResource(R.string.birthday_add_remove_cancel),
            onDismiss = { confirm = false },
            destructive = true,
        )
    }
}
