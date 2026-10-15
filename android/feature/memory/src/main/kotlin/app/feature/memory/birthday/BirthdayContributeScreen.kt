// Surface: birthday.contribute — design/surfaces/birthday.contribute.md
// References: references/auto/tribute/web/tribute-web-testimonials-upload-step1-info.png (+ computed styles),
// references/auto/vidday/frames/vidday-tour-t102-phone.png; Tribute / VidDay help-centre step sequences.
package app.feature.memory.birthday

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.asPaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.GridItemSpan
import androidx.compose.foundation.lazy.grid.LazyGridScope
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.selection.selectable
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicText
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Icon
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.style.TextAlign
import app.designsystem.R
import app.designsystem.generated.Tokens
import app.feature.memory.common.MemoryFormats
import app.feature.memory.common.MemoryImage
import app.feature.memory.common.MessageBlock
import app.feature.memory.common.PlatformSpinner
import app.feature.memory.common.heading
import app.feature.memory.common.roleStyle

/** Test tags used by flow tests. */
object ContributeTags {
    const val ROOT = "birthday.contribute"
    const val FIELD = "birthday.contribute.line"
    fun cell(postId: String) = "birthday.contribute.photo.$postId"
}

private val margin get() = Tokens.Sizes.birthdayContributeMargin

/** One contribute step (Photo, Message, Done) under the stepper. */
@Composable
fun BirthdayContributeScreen(
    page: RequestPage,
    info: RequestInfo,
    state: ContributeState,
    onSelect: (String) -> Unit,
    onUsePhoto: () -> Unit,
    onLine: (String) -> Unit,
    onSubmit: () -> Unit,
    onRetake: () -> Unit,
    onDone: () -> Unit,
    onBack: () -> Unit,
    onRetryPhotos: () -> Unit,
    onOpenGroup: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val step = when (page) {
        RequestPage.Message -> 1
        RequestPage.Done -> 2
        else -> 0
    }
    Column(modifier.fillMaxSize().background(Tokens.Colors.globalBackgroundDeep).imePadding().testTag(ContributeTags.ROOT)) {
        if (page == RequestPage.Message) {
            LeadingHeaderCircle(Tokens.Icons.globalBack, stringResource(R.string.birthday_contribute_a11y_close), onBack)
        } else {
            LeadingHeaderCircle(Tokens.Icons.globalClose, stringResource(R.string.birthday_contribute_a11y_close), if (page == RequestPage.Done) onDone else onBack)
        }
        Stepper(step)
        Box(Modifier.fillMaxWidth().weight(1f)) {
            when {
                state.closed -> MessageBlock(stringResource(R.string.birthday_contribute_closed, info.honoreeName), null, Modifier.fillMaxSize())
                page == RequestPage.Message -> MessageStep(info, state, onLine, onSubmit, onRetake)
                page == RequestPage.Done -> DoneStep(state, onDone)
                else -> PhotoStep(info, state, onSelect, onUsePhoto, onRetryPhotos, onOpenGroup)
            }
        }
    }
}

private val headingStyle @Composable get() = roleStyle(Tokens.FontSizes.birthdayContributeHeading, Tokens.FontWeights.fontWeightBirthdayContributeHeading, family = Tokens.Fonts.birthday)
    .copy(color = Tokens.Colors.globalTextPrimary, textAlign = TextAlign.Center)

private val inlineStyle @Composable get() = roleStyle(Tokens.FontSizes.globalListSubtitle, Tokens.FontWeights.fontWeightGlobalListSubtitle)
    .copy(color = Tokens.Colors.globalTextSecondary, textAlign = TextAlign.Center)

private fun LazyGridScope.full(content: @Composable () -> Unit) = item(span = { GridItemSpan(maxLineSpan) }) { content() }

/** Step 1: greeting, thanks, the eligible photos (posted by you or you're in), Use Photo. */
@Composable
private fun PhotoStep(
    info: RequestInfo,
    state: ContributeState,
    onSelect: (String) -> Unit,
    onUsePhoto: () -> Unit,
    onRetry: () -> Unit,
    onOpenGroup: () -> Unit,
) {
    val photos = state.photos
    Column(Modifier.fillMaxSize()) {
        LazyVerticalGrid(
            columns = GridCells.Fixed(Tokens.Counts.wallsMineCountGridColumns),
            modifier = Modifier.fillMaxWidth().weight(1f),
            contentPadding = PaddingValues(horizontal = margin),
            horizontalArrangement = Arrangement.spacedBy(Tokens.Sizes.wallsMineDimensionGridGap),
            verticalArrangement = Arrangement.spacedBy(Tokens.Sizes.wallsMineDimensionGridGap),
        ) {
            full {
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Spacer(Modifier.size(Tokens.Sizes.birthdayContributeHeadingGap))
                    BasicText(stringResource(R.string.birthday_contribute_greeting, info.honoreeName), Modifier.heading(), style = headingStyle)
                    Spacer(Modifier.size(Tokens.Sizes.birthdayContributeSubheadingGap))
                    BasicText(
                        stringResource(R.string.birthday_contribute_thanks),
                        style = roleStyle(Tokens.FontSizes.birthdayContributeSubheading, Tokens.FontWeights.fontWeightGlobalListSubtitle, family = Tokens.Fonts.birthday)
                            .copy(color = Tokens.Colors.globalTextPrimary.copy(alpha = Tokens.Opacities.birthdayContributeSubheading), textAlign = TextAlign.Center),
                    )
                    if (state.inline == ContributeState.Inline.NotEligible) {
                        Spacer(Modifier.size(Tokens.Sizes.globalListGap))
                        BasicText(stringResource(R.string.birthday_contribute_noteligible), style = inlineStyle)
                    }
                    Spacer(Modifier.size(Tokens.Sizes.birthdayContributeGroupGap))
                }
            }
            when (photos) {
                PhotosState.Loading -> full {
                    Column(Modifier.fillMaxWidth(), horizontalAlignment = Alignment.CenterHorizontally) {
                        PlatformSpinner()
                        Spacer(Modifier.size(Tokens.Sizes.globalListGap))
                        BasicText(stringResource(R.string.birthday_contribute_loading), style = inlineStyle)
                    }
                }
                PhotosState.Empty -> full {
                    MessageBlock(
                        stringResource(R.string.birthday_contribute_picker_empty_title, info.groupName),
                        stringResource(R.string.birthday_contribute_picker_empty_detail),
                        Modifier.fillMaxWidth(),
                        action = stringResource(R.string.birthday_contribute_picker_empty_action),
                        onAction = onOpenGroup,
                    )
                }
                is PhotosState.Failed -> full {
                    MessageBlock(
                        stringResource(if (photos.offline) R.string.birthday_contribute_offline else R.string.birthday_contribute_error_title),
                        if (photos.offline) null else stringResource(R.string.birthday_contribute_error_detail),
                        Modifier.fillMaxWidth(),
                        action = stringResource(R.string.birthday_contribute_error_retry),
                        onAction = onRetry,
                    )
                }
                is PhotosState.Loaded -> items(photos.photos, key = { it.postId }) { photo ->
                    PhotoCell(photo, selected = photo.postId == state.selected, onClick = { onSelect(photo.postId) })
                }
            }
        }
        if (photos is PhotosState.Loaded) {
            StepButton(
                stringResource(R.string.birthday_contribute_review_use),
                onUsePhoto,
                Modifier.windowInsetsPadding(WindowInsets.navigationBars).padding(start = margin, end = margin, top = margin, bottom = margin),
                enabled = state.selectedPhoto != null,
            )
        }
    }
}

/** A Yope wall-grid tile with the global selection check in its top-right corner. */
@Composable
private fun PhotoCell(photo: EligiblePhoto, selected: Boolean, onClick: () -> Unit) {
    val label = stringResource(R.string.birthday_contribute_a11y_photo, MemoryFormats.spokenDate(photo.date))
    Box(
        Modifier
            .aspectRatio(Tokens.AspectRatios.wallsMineAspectRatioGridTile)
            .clip(RoundedCornerShape(Tokens.Radii.globalPhoto))
            .background(Tokens.Colors.globalControl)
            .selectable(selected = selected, role = Role.RadioButton, onClick = onClick)
            .semantics { contentDescription = label }
            .testTag(ContributeTags.cell(photo.postId)),
    ) {
        MemoryImage(photo.thumbUrl, null, Modifier.fillMaxSize(), ContentScale.Crop)
        Icon(
            if (selected) Tokens.Icons.globalCheck else Tokens.Icons.globalUncheck,
            contentDescription = null,
            tint = if (selected) Tokens.Colors.globalSelection else Tokens.Colors.globalTextPrimary,
            modifier = Modifier.align(Alignment.TopEnd).padding(Tokens.Sizes.wallsMineDimensionGridGap).size(Tokens.Sizes.globalCheckCircle),
        )
    }
}

/** Step 2: the chosen photo, "Your Message" field, Message Ideas, Submit, Retake. */
@Composable
private fun MessageStep(info: RequestInfo, state: ContributeState, onLine: (String) -> Unit, onSubmit: () -> Unit, onRetake: () -> Unit) {
    val photo = state.selectedPhoto
    val focus = LocalFocusManager.current
    val navigation = WindowInsets.navigationBars.asPaddingValues().calculateBottomPadding()
    val label = stringResource(R.string.birthday_contribute_line_label)
    val inputStyle = roleStyle(Tokens.FontSizes.birthdayContributeInput, Tokens.FontWeights.fontWeightGlobalListSubtitle, family = Tokens.Fonts.birthday)
        .copy(color = Tokens.Colors.birthdayContributeInputText)
    Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(horizontal = margin)) {
        Spacer(Modifier.size(Tokens.Sizes.birthdayContributeGroupGap))
        if (photo != null) {
            MemoryImage(photo.displayUrl, null, Modifier.fillMaxWidth().aspectRatio(photo.aspectRatio).clip(RoundedCornerShape(Tokens.Radii.globalPhoto)))
        }
        Spacer(Modifier.size(Tokens.Sizes.birthdayContributeGroupGap))
        BasicText(
            label,
            style = roleStyle(Tokens.FontSizes.birthdayContributeLabel, Tokens.FontWeights.fontWeightBirthdayContributeLabel, family = Tokens.Fonts.birthday)
                .copy(color = Tokens.Colors.globalTextPrimary),
        )
        Spacer(Modifier.size(Tokens.Sizes.birthdayContributeLabelGap))
        BasicTextField(
            value = state.line,
            onValueChange = onLine,
            modifier = Modifier.fillMaxWidth().semantics { contentDescription = label }.testTag(ContributeTags.FIELD),
            enabled = !state.sending,
            textStyle = inputStyle,
            keyboardOptions = KeyboardOptions(imeAction = ImeAction.Done),
            keyboardActions = KeyboardActions(onDone = { focus.clearFocus() }),
            cursorBrush = SolidColor(Tokens.Colors.globalSystemPrimary),
            decorationBox = { inner ->
                Box(
                    Modifier
                        .fillMaxWidth()
                        .heightIn(min = Tokens.Sizes.birthdayContributeInputHeight)
                        .clip(RoundedCornerShape(Tokens.Radii.birthdayContributeInput))
                        .background(Tokens.Colors.birthdayContributeInputFill)
                        .padding(Tokens.Sizes.birthdayContributeLabelGap),
                    contentAlignment = Alignment.CenterStart,
                ) { inner() }
            },
        )
        Spacer(Modifier.size(Tokens.Sizes.birthdayContributeGroupGap))
        MessageIdeas(info.honoreeName)
        Spacer(Modifier.size(Tokens.Sizes.birthdayContributeButtonGap))
        StepButton(
            stringResource(if (state.inline == ContributeState.Inline.Error) R.string.birthday_contribute_error_retry else R.string.birthday_contribute_submit),
            onSubmit,
            enabled = state.canSubmit,
            busy = state.sending,
        )
        when (state.inline) {
            ContributeState.Inline.Error -> {
                Spacer(Modifier.size(Tokens.Sizes.globalListGap))
                MessageBlock(stringResource(R.string.birthday_contribute_error_title), stringResource(R.string.birthday_contribute_error_detail), Modifier.fillMaxWidth())
            }
            ContributeState.Inline.Offline -> {
                Spacer(Modifier.size(Tokens.Sizes.globalListGap))
                BasicText(stringResource(R.string.birthday_contribute_offline), Modifier.fillMaxWidth(), style = inlineStyle)
            }
            else -> Unit
        }
        Spacer(Modifier.size(Tokens.Sizes.birthdayContributeGroupGap))
        StepButton(stringResource(R.string.birthday_contribute_review_retake), onRetake, primary = false, enabled = !state.sending)
        Spacer(Modifier.size(navigation + margin))
    }
}

/** Step 3: "Photo Upload Complete!", the photo and the line, Done. */
@Composable
private fun DoneStep(state: ContributeState, onDone: () -> Unit) {
    val photo = state.selectedPhoto
    val navigation = WindowInsets.navigationBars.asPaddingValues().calculateBottomPadding()
    Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(horizontal = margin), horizontalAlignment = Alignment.CenterHorizontally) {
        Spacer(Modifier.size(Tokens.Sizes.birthdayContributeHeadingGap))
        BasicText(stringResource(R.string.birthday_contribute_done_title), Modifier.heading(), style = headingStyle)
        Spacer(Modifier.size(Tokens.Sizes.birthdayContributeGroupGap))
        if (photo != null) {
            MemoryImage(photo.displayUrl, null, Modifier.fillMaxWidth().aspectRatio(photo.aspectRatio).clip(RoundedCornerShape(Tokens.Radii.globalPhoto)))
            Spacer(Modifier.size(Tokens.Sizes.birthdayContributeGroupGap))
        }
        BasicText(
            state.line.trim(),
            Modifier.fillMaxWidth(),
            style = roleStyle(Tokens.FontSizes.birthdayRequestMessage, Tokens.FontWeights.fontWeightGlobalListSubtitle, family = Tokens.Fonts.birthday)
                .copy(color = Tokens.Colors.globalTextPrimary),
        )
        Spacer(Modifier.size(Tokens.Sizes.birthdayContributeButtonGap))
        StepButton(stringResource(R.string.birthday_contribute_done_button), onDone)
        Spacer(Modifier.size(navigation + margin))
    }
}
