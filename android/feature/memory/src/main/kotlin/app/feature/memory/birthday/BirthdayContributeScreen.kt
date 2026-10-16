// Surface: birthday.contribute — design/surfaces/birthday.contribute.md (Retro screens 30, 17, 18 in Tribute / VidDay's order)
// References: references/auto/retro/video/ig-DDbA_F7x-j7-composer-f130-147-f188-197.png (VID-COMP), references/auto/retro/store/retro-store-03.png (ST-03),
// references/auto/retro/press/tc-2023-12-retro3.png phone 3 (TC-R3, "Add a Message").
package app.feature.memory.birthday

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.paddingFrom
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.layout.LastBaseline
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.min
import app.designsystem.R
import app.designsystem.generated.Tokens
import app.feature.memory.common.FadeInItem
import app.feature.memory.common.MediaAppearance
import app.feature.memory.common.MemoryFormats
import app.feature.memory.common.MemoryImage
import app.ui.components.CircleButtonStyle
import app.ui.components.CircleIconButton
import app.ui.components.EmptyState
import app.ui.components.EmptyStateAction
import app.ui.components.EmptyStateFill
import app.ui.components.HeaderIconButton
import app.ui.components.HeaderTextButton
import app.ui.components.MediaPill
import app.ui.components.MediaPillStyle
import app.ui.components.PrimaryButton
import app.ui.foundation.PageRoles
import app.ui.foundation.endAtLastBaseline
import app.ui.foundation.tapClickable
import app.ui.system.SheetHeader
import app.ui.system.SheetTextAction
import app.ui.text.TextRoles

/** Test tags (flow tests). */
object ContributeTags {
    const val GRID = "birthday.contribute.grid"
    const val NEXT = "birthday.contribute.next"
    const val PILL = "birthday.contribute.pill"
    const val SUBMIT = "birthday.contribute.submit"
    const val FIELD = "birthday.contribute.field"
    const val DONE = "birthday.contribute.done"
    const val PHOTO = "birthday.contribute.photo"
    fun cell(postId: String) = "birthday.contribute.cell.$postId"
}

/**
 * **Step 1 — Choose a Photo** (Retro's "Add to Your Week" composer, VID-COMP; follows the appearance): the native
 * toolbar (C-29: "Cancel" / title / "Next", system tint; Next disabled until a photo is chosen), the grey line, and
 * the C-21 picker grid — 4 columns, square cells, `size.global.stripGap` apart, full width, `radius.global.photo` —
 * of the photos you posted or are in, newest first. One choice: the chosen cell shows the filled check
 * (`icon.global.check`, `color.global.selection`, `size.global.checkCircle`) `size.global.badgeInset` from its
 * top-right corner (PLATFORM picker mark). States: placeholder cells while loading (C-17 / C-28), the C-27 empty
 * block with "View {group}", the error / offline block, the not-eligible line.
 */
@Composable
fun ChoosePhotoStep(
    info: RequestInfo,
    state: ContributeState,
    onSelect: (String) -> Unit,
    onNext: () -> Unit,
    onCancel: () -> Unit,
    onRetry: () -> Unit,
    onOpenGroup: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val secondary = PageRoles.secondaryText()
    Column(modifier.fillMaxSize().background(PageRoles.page)) {
        SheetHeader(
            stringResource(R.string.birthday_contribute_picker_title),
            leading = SheetTextAction(stringResource(R.string.birthday_contribute_picker_cancel), onCancel),
            trailing = SheetTextAction(stringResource(R.string.birthday_contribute_picker_next), onNext, enabled = state.selectedPhoto != null),
        )
        Text(
            stringResource(R.string.birthday_contribute_picker_subtitle),
            style = TextRoles.body,
            color = secondary,
            modifier = Modifier.padding(horizontal = Tokens.Sizes.globalScreenMargin).paddingFrom(LastBaseline, after = Tokens.Sizes.globalSectionHeaderToContent),
        )
        if (state.inline == ContributeState.Inline.NotEligible) {
            Text(
                stringResource(R.string.birthday_contribute_noteligible),
                style = TextRoles.meta,
                color = Tokens.Colors.globalDestructive,
                modifier = Modifier
                    .padding(horizontal = Tokens.Sizes.globalScreenMargin)
                    .paddingFrom(LastBaseline, after = Tokens.Sizes.globalSectionHeaderToContent)
                    .semantics { liveRegion = LiveRegionMode.Polite },
            )
        }
        when (val photos = state.photos) {
            PhotosState.Loading -> PickerGrid(List(PLACEHOLDER_CELLS) { null }, null, onSelect, loadingLabel = stringResource(R.string.birthday_contribute_loading))
            PhotosState.Empty -> EmptyStateFill(Modifier.weight(1f)) {
                EmptyState(
                    stringResource(R.string.birthday_contribute_picker_empty_title),
                    stringResource(R.string.birthday_contribute_picker_empty_detail, info.groupName),
                    action = EmptyStateAction(stringResource(R.string.birthday_contribute_picker_empty_action, info.groupName), onOpenGroup),
                )
            }
            is PhotosState.Failed -> EmptyStateFill(Modifier.weight(1f)) {
                EmptyState(
                    stringResource(if (photos.offline) R.string.birthday_request_offline_title else R.string.birthday_request_error_title),
                    stringResource(if (photos.offline) R.string.birthday_contribute_offline else R.string.birthday_request_error_detail),
                    action = EmptyStateAction(stringResource(R.string.birthday_contribute_error_retry), onRetry),
                )
            }
            is PhotosState.Loaded -> PickerGrid(photos.photos, state.selected, onSelect)
        }
    }
}

/** Placeholder cells while the grid loads (three rows of the 4-column grid). */
private const val PLACEHOLDER_CELLS = 12

@Composable
private fun PickerGrid(photos: List<EligiblePhoto?>, selected: String?, onSelect: (String) -> Unit, loadingLabel: String? = null) {
    val gap = Tokens.Sizes.globalStripGap
    LazyVerticalGrid(
        columns = GridCells.Fixed(PICKER_COLUMNS),
        horizontalArrangement = Arrangement.spacedBy(gap),
        verticalArrangement = Arrangement.spacedBy(gap),
        modifier = Modifier
            .fillMaxWidth()
            .testTag(ContributeTags.GRID)
            .then(if (loadingLabel != null) Modifier.semantics { contentDescription = loadingLabel; liveRegion = LiveRegionMode.Polite } else Modifier),
    ) {
        items(photos.size, key = { i -> photos[i]?.postId ?: "placeholder-$i" }) { i ->
            val photo = photos[i]
            if (photo == null) {
                Box(Modifier.aspectRatio(1f).background(Tokens.Colors.globalControl))
            } else {
                PickerCell(photo, photo.postId == selected) { onSelect(photo.postId) }
            }
        }
    }
}

/** C-21 composer picker: 4 columns (VID-COMP). */
private const val PICKER_COLUMNS = 4

@Composable
private fun PickerCell(photo: EligiblePhoto, selected: Boolean, onClick: () -> Unit) {
    val label = stringResource(R.string.birthday_contribute_a11y_photo, MemoryFormats.spokenDate(photo.date))
    Box(
        Modifier
            .aspectRatio(1f)
            .clip(RoundedCornerShape(Tokens.Radii.globalPhoto))
            .testTag(ContributeTags.cell(photo.postId))
            .tapClickable(role = Role.RadioButton, onClick = onClick)
            .clearAndSetSemantics {
                contentDescription = label
                this.selected = selected
                role = Role.RadioButton
            },
    ) {
        MemoryImage(photo.thumbUrl, null, Modifier.fillMaxSize(), placeholder = Tokens.Colors.globalControl)
        if (selected) {
            // Top-right corner, inset `size.global.badgeInset` (spec: where Retro places a marker on a photo, C-24).
            Box(Modifier.align(Alignment.TopEnd)) {
                FadeInItem(photo.postId) {
                    Icon(
                        Tokens.Icons.globalCheck,
                        contentDescription = null,
                        tint = Tokens.Colors.globalSelection,
                        modifier = Modifier
                            .padding(Tokens.Sizes.globalBadgeInset)
                            .size(Tokens.Sizes.globalCheckCircle)
                            // Material Symbols draw the circle in the 20-unit live area of a 24-unit grid: the visible circle is the token.
                            .graphicsLayer { scaleX = GLYPH_TO_LIVE_AREA; scaleY = GLYPH_TO_LIVE_AREA },
                    )
                }
            }
        }
    }
}

/** Material icon grid / live area = 24 / 20 (PLATFORM: Material Design "Designing icons"), as core:ui `CheckCircle`. */
private const val GLYPH_TO_LIVE_AREA = 24f / 20f // provenance-ok: Material icon grid 24 over live area 20 (PLATFORM)

/**
 * **Step 2 — the composer** (Retro's postcard composer, ST-03; dark in both appearances): the sheet header on media
 * (back, centred "Birthday Video" in `sheetTitle`, the close circle C-11 on media); the chosen photo
 * `dimension.birthday.contribute.titleToPhoto` below the title's baseline, fitted in a `photoWidth` × `photoMaxHeight`
 * box with corners `radius.birthday.contribute.photo`; on it the dark C-09 pill ("Add a message" / "Edit message",
 * `icon.global.edit`) `pillBottom` above the photo's bottom; your line under the photo; the C-05 capsule on media
 * "Add to video" pinned to the bottom (disabled until the line has text; busy while sending). States: offline /
 * not-eligible lines and the error block under the photo; the closed block replaces the content.
 */
@Composable
fun ComposerStep(
    info: RequestInfo,
    state: ContributeState,
    onBack: () -> Unit,
    onClose: () -> Unit,
    onEditMessage: () -> Unit,
    onSubmit: () -> Unit,
    modifier: Modifier = Modifier,
) {
    MediaAppearance {
        Column(modifier.fillMaxSize().background(Tokens.Colors.globalBackgroundDeep)) {
            // The header ends at the title's baseline: the photo's top is measured from it (`titleToPhoto`, ST-03).
            MediaSheetHeader(stringResource(R.string.birthday_contribute_composer_title), onBack, onClose, Modifier.endAtLastBaseline())
            if (state.closed) {
                EmptyStateFill(Modifier.weight(1f)) { EmptyState(stringResource(R.string.birthday_contribute_closed, info.honoreeName), null) }
                return@Column
            }
            val photo = state.selectedPhoto
            Column(Modifier.weight(1f).fillMaxWidth().verticalScroll(rememberScrollState()), horizontalAlignment = Alignment.CenterHorizontally) {
                if (photo != null) {
                    Box(Modifier.padding(top = Tokens.Sizes.birthdayContributeTitleToPhoto)) {
                        val (w, h) = fitted(photo.aspectRatio, Tokens.Sizes.birthdayContributePhotoWidth, Tokens.Sizes.birthdayContributePhotoMaxHeight)
                        MemoryImage(
                            photo.displayUrl,
                            null,
                            Modifier.size(w, h).clip(RoundedCornerShape(Tokens.Radii.birthdayContributePhoto)).testTag(ContributeTags.PHOTO),
                            contentScale = ContentScale.Crop,
                        )
                        MediaPill(
                            stringResource(if (state.line.isBlank()) R.string.birthday_contribute_message_add else R.string.birthday_contribute_message_edit),
                            onEditMessage,
                            Modifier.align(Alignment.BottomCenter).padding(bottom = Tokens.Sizes.birthdayContributePillBottom).testTag(ContributeTags.PILL),
                            style = MediaPillStyle.Dark,
                            icon = Tokens.Icons.globalEdit,
                        )
                    }
                }
                if (state.line.isNotBlank()) {
                    Text(
                        state.line,
                        style = TextRoles.body,
                        color = Tokens.Colors.globalTextOnMedia,
                        textAlign = TextAlign.Center,
                        modifier = Modifier.fillMaxWidth().padding(horizontal = Tokens.Sizes.globalButtonMarginH).padding(top = Tokens.Sizes.globalListGap),
                    )
                }
                when (state.inline) {
                    ContributeState.Inline.Offline -> InlineLine(stringResource(R.string.birthday_contribute_offline), Tokens.ColorsDark.globalTextSecondary)
                    ContributeState.Inline.NotEligible -> InlineLine(stringResource(R.string.birthday_contribute_noteligible), Tokens.ColorsDark.globalDestructive)
                    ContributeState.Inline.Error -> Box(Modifier.padding(top = Tokens.Sizes.globalListGap)) {
                        EmptyState(stringResource(R.string.birthday_contribute_error_title), stringResource(R.string.birthday_contribute_error_detail))
                    }
                    null -> Unit
                }
            }
            PrimaryButton(
                stringResource(if (state.inline == ContributeState.Inline.Error) R.string.birthday_contribute_error_retry else R.string.birthday_contribute_submit),
                onSubmit,
                Modifier
                    .padding(horizontal = Tokens.Sizes.globalButtonMarginH)
                    .windowInsetsPadding(WindowInsets.navigationBars)
                    .padding(bottom = Tokens.Sizes.globalScreenMargin)
                    .testTag(ContributeTags.SUBMIT),
                enabled = state.line.isNotBlank(),
                loading = state.sending,
                onMedia = true,
            )
        }
    }
}

/** A line under the photo (text role `meta`): offline in secondary text, not eligible in `color.global.destructive`. */
@Composable
private fun InlineLine(text: String, color: androidx.compose.ui.graphics.Color) {
    Text(
        text,
        style = TextRoles.meta,
        color = color,
        textAlign = TextAlign.Center,
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = Tokens.Sizes.globalButtonMarginH)
            .padding(top = Tokens.Sizes.globalListGap)
            .semantics { liveRegion = LiveRegionMode.Polite },
    )
}

/** [aspect] (width / height) fitted in a [maxWidth] × [maxHeight] box: the photo's own aspect, never cropped. */
internal fun fitted(aspect: Float, maxWidth: Dp, maxHeight: Dp): Pair<Dp, Dp> {
    val a = if (aspect > 0f) aspect else 1f
    val w = min(maxWidth, maxHeight * a)
    return w to w / a
}

/**
 * C-29 sheet header on media: back (`icon.global.back`, `color.global.textOnMedia`) at the leading margin, the centred
 * title (`sheetTitle`, `color.global.textOnMedia`), the close circle on media (C-11) at the trailing margin.
 */
@Composable
private fun MediaSheetHeader(title: String, onBack: () -> Unit, onClose: () -> Unit, modifier: Modifier = Modifier) {
    Box(modifier.fillMaxWidth().heightIn(min = Tokens.Sizes.globalMinTouchTargetAndroid).padding(horizontal = Tokens.Sizes.globalScreenMargin), contentAlignment = Alignment.Center) {
        HeaderIconButton(Tokens.Icons.globalBack, stringResource(R.string.onthisday_a11y_back), onBack, Modifier.align(Alignment.CenterStart), tint = Tokens.Colors.globalTextOnMedia)
        Text(title, style = TextRoles.sheetTitle, color = Tokens.Colors.globalTextOnMedia, textAlign = TextAlign.Center, modifier = Modifier.semantics { heading() })
        CircleIconButton(Tokens.Icons.globalClose, stringResource(R.string.birthday_contribute_a11y_close), onClose, Modifier.align(Alignment.CenterEnd), style = CircleButtonStyle.OnMedia)
    }
}

/**
 * **Step 2a — "Add a Message"** (TC-R3 phone 3; C-29 page sheet, follows the appearance): the centred title with the
 * app-drawn "Done" (C-08, `textButton`, `color.global.textPrimary`) `counterInset` from the edge; the free text (no
 * fill) inset `messageInset`, text role `placeholder`, the placeholder in secondary text; the counter "{count}/{max}"
 * bottom-right (monospaced digits, secondary text), its ink `counterInset` from the edge and its baseline
 * `counterAboveKeyboard` above the keyboard. Input stops at `layout.birthday.contribute.lineMax`.
 */
@Composable
fun MessageModal(line: String, onLine: (String) -> Unit, onDone: () -> Unit, modifier: Modifier = Modifier) {
    val focus = remember { FocusRequester() }
    LaunchedEffect(Unit) { runCatching { focus.requestFocus() } }
    val secondary = PageRoles.secondaryText()
    val style = TextRoles.placeholder.copy(color = Tokens.Colors.globalTextPrimary)
    val max = BirthdayRequestViewModel.LINE_MAX
    val counter = stringResource(R.string.birthday_contribute_message_counter, MemoryFormats.number(line.length), MemoryFormats.number(max))
    val title = stringResource(R.string.birthday_contribute_message_title)
    Column(modifier.fillMaxSize().background(PageRoles.page).imePadding()) {
        Box(Modifier.fillMaxWidth().heightIn(min = Tokens.Sizes.globalMinTouchTargetAndroid), contentAlignment = Alignment.Center) {
            Text(title, style = TextRoles.sheetTitle, color = Tokens.Colors.globalTextPrimary, modifier = Modifier.semantics { heading() })
            HeaderTextButton(
                stringResource(R.string.birthday_contribute_message_done),
                onDone,
                Modifier.align(Alignment.CenterEnd).padding(end = Tokens.Sizes.birthdayContributeCounterInset).testTag(ContributeTags.DONE),
            )
        }
        BasicTextField(
            value = line,
            onValueChange = onLine,
            textStyle = style,
            cursorBrush = SolidColor(Tokens.Colors.globalSystemPrimary),
            keyboardOptions = KeyboardOptions(capitalization = KeyboardCapitalization.Sentences),
            modifier = Modifier
                .weight(1f)
                .fillMaxWidth()
                .padding(horizontal = Tokens.Sizes.birthdayContributeMessageInset, vertical = Tokens.Sizes.globalScreenMargin)
                .focusRequester(focus)
                .semantics {
                    contentDescription = title
                    stateDescription = counter
                }
                .testTag(ContributeTags.FIELD),
            decorationBox = { inner ->
                Box {
                    if (line.isEmpty()) Text(stringResource(R.string.birthday_contribute_message_placeholder), style = style.copy(color = secondary))
                    inner()
                }
            },
        )
        Text(
            counter,
            style = TextRoles.placeholder.copy(fontFeatureSettings = TABULAR_DIGITS),
            color = secondary,
            textAlign = TextAlign.End,
            modifier = Modifier
                .align(Alignment.End)
                .padding(end = Tokens.Sizes.birthdayContributeCounterInset)
                .paddingFrom(LastBaseline, after = Tokens.Sizes.birthdayContributeCounterAboveKeyboard)
                .clearAndSetSemantics { },
        )
    }
}

/** OpenType feature: tabular (monospaced) digits for the counter (platform note: FontFeatureSettings "tnum"). */
private const val TABULAR_DIGITS = "tnum"
