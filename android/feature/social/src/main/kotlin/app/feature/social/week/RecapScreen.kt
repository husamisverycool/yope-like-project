// Surface: week.recap — design/surfaces/week.recap.md
// References: references/auto/retro/press/tc-2023-12-recaps.png phone 1 ("Create Recap" month cards: cover, serif month,
// year, chevron), references/auto/retro/store/retro-store-04.png (2026 recap preview: media page, close, select-photos
// thumbnail, page dots, light pill), references/auto/retro/web/retro.app-42b38811bebcd07d.css (journal note box).
@file:OptIn(androidx.compose.material3.ExperimentalMaterial3Api::class)

package app.feature.social.week

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.paddingFromBaseline
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextAlign
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import app.data.model.RenderStatus
import app.designsystem.R
import app.designsystem.generated.Tokens
import app.feature.social.common.Formats
import app.feature.social.common.MediaAppearance
import app.feature.social.common.RemotePhoto
import app.feature.social.common.photoModel
import app.feature.memory.yearstory.RecapCardMetrics
import app.feature.memory.yearstory.RecapCardPage
import app.feature.memory.yearstory.RecapCardPhoto
import app.feature.memory.yearstory.RecapCoverPage
import app.feature.social.common.stringRes
import app.feature.social.walls.ErrorLine
import app.ui.components.CircleButtonStyle
import app.ui.components.CircleIconButton
import app.ui.components.EmptyState
import app.ui.components.EmptyStateAction
import app.ui.foundation.PageRoles
import app.ui.foundation.endAtLastBaseline
import app.ui.foundation.tapClickable
import app.ui.recap.RecapDots
import app.ui.recap.MediaReportMenu
import app.ui.recap.RecapPill
import app.ui.recap.RecapPillLabel
import app.ui.recap.RecapPreviewScreen
import app.ui.system.DsBottomSheet
import app.ui.text.CapTop
import app.ui.text.TextRoles
import app.ui.text.capTopAt

/** Where `week.recap` leads. */
data class RecapNav(
    val back: () -> Unit,
    /** List → one recap's preview. */
    val open: (recapId: String) -> Unit,
    /** The select-photos thumbnail → `week.edit`. */
    val edit: (recapId: String) -> Unit,
    /** "Save as Album" → `week.edit`'s album sheet with the recap's photos. */
    val saveAsAlbum: (recapId: String) -> Unit,
    val cardPhoto: (recapId: String, postId: String) -> Unit,
    val camera: () -> Unit,
    /** "Report Recap" (safety.report, kind `recap`, MERGE FV-4). */
    val report: (recapId: String) -> Unit = {},
    /** A collage page → `collage.view` (by its invitation). */
    val collage: (invitationId: String) -> Unit = {},
)

@Composable
fun WeekRecapListSheet(vm: RecapListViewModel, nav: RecapNav) {
    val state by vm.state.collectAsStateWithLifecycle()
    DsBottomSheet(onDismissRequest = nav.back) { RecapListContent(state, nav, vm::retry) }
}

/**
 * The recap list (`week.recap.layout.list`, Retro's "Create Recap"): the C-11 close circle at the leading margin and the
 * centred `week.recap.list.title`; week cards newest first inside `size.global.screenMargin`, `size.global.cardGap`
 * apart, `size.global.titleToContent` below the header.
 */
@Composable
fun RecapListContent(state: RecapListState, nav: RecapNav, onRetry: () -> Unit) {
    Column(Modifier.fillMaxWidth().testTag("week.recap")) {
        Box(Modifier.fillMaxWidth().heightIn(min = Tokens.Sizes.globalMinTouchTargetAndroid).padding(horizontal = Tokens.Sizes.globalScreenMargin), contentAlignment = Alignment.Center) {
            CircleIconButton(Tokens.Icons.globalClose, stringRes(R.string.week_recap_a11y_close), nav.back, Modifier.align(Alignment.CenterStart), style = CircleButtonStyle.OnPage)
            Text(stringRes(R.string.week_recap_list_title), style = TextRoles.sheetTitle, color = Tokens.Colors.globalTextPrimary, modifier = Modifier.semantics { heading() })
        }
        when (state.phase) {
            RecapListState.Phase.Loading -> CardColumn { repeat(2) { PlaceholderCard(null) } }
            RecapListState.Phase.Error, RecapListState.Phase.OfflineEmpty -> Column(Modifier.padding(top = Tokens.Sizes.globalTitleToContent)) {
                ErrorLine(stringRes(R.string.week_recap_error_title), onRetry)
                if (state.phase == RecapListState.Phase.OfflineEmpty) ErrorLine(stringRes(R.string.chat_thread_offline_detail), onRetry)
            }
            RecapListState.Phase.Empty -> Box(Modifier.fillMaxWidth().padding(vertical = Tokens.Sizes.globalButtonHeight), contentAlignment = Alignment.Center) {
                EmptyState(
                    stringRes(R.string.week_recap_empty_title),
                    stringRes(R.string.week_recap_empty_detail),
                    action = EmptyStateAction(stringRes(R.string.week_recap_empty_action), nav.camera, Tokens.Icons.globalAdd),
                    icon = Tokens.Icons.globalRecap,
                )
            }
            RecapListState.Phase.Ready -> LazyColumn(
                contentPadding = PaddingValues(start = Tokens.Sizes.globalScreenMargin, end = Tokens.Sizes.globalScreenMargin, top = Tokens.Sizes.globalTitleToContent, bottom = Tokens.Sizes.globalSectionGap),
                verticalArrangement = Arrangement.spacedBy(Tokens.Sizes.globalCardGap),
            ) {
                items(state.cards, key = { it.recap.id }) { card ->
                    if (card.recap.status == RenderStatus.Pending) PlaceholderCard(stringRes(R.string.week_recap_pending))
                    else WeekCard(card, state, nav)
                }
            }
        }
    }
}

@Composable
private fun CardColumn(content: @Composable () -> Unit) {
    Column(
        Modifier.fillMaxWidth().padding(start = Tokens.Sizes.globalScreenMargin, end = Tokens.Sizes.globalScreenMargin, top = Tokens.Sizes.globalTitleToContent, bottom = Tokens.Sizes.globalSectionGap),
        verticalArrangement = Arrangement.spacedBy(Tokens.Sizes.globalCardGap),
    ) { content() }
}

/** A recap still being made, or loading: a C-17-fill card (`color.global.control`) with [text] centred (`body`, secondary). */
@Composable
private fun PlaceholderCard(text: String?) {
    Box(
        Modifier
            .fillMaxWidth()
            .aspectRatio(Tokens.AspectRatios.weekRecapAspectRatioWeekCard)
            .clip(RoundedCornerShape(Tokens.Radii.weekRecapRadiusCard))
            .background(Tokens.Colors.globalControl),
        contentAlignment = Alignment.Center,
    ) {
        if (text != null) Text(text, style = TextRoles.body, color = PageRoles.secondaryText(), textAlign = TextAlign.Center)
    }
}

/**
 * A week card (Retro's month card): `week.recap.aspectRatio.weekCard`, corners `week.recap.radius.card`, the cover
 * aspect-fill; "Week {n}" (`displayTitle`, the title face — Retro's month cards are in its title cut, TC-2023-12 —
 * `color.global.textOnMedia`) with its cap top
 * `week.recap.dimension.weekCardTextTop` and ink `.weekCardTextInset` in, the range (`listSubtitle`) one
 * `.weekCardLinePitch` below its baseline, `icon.global.chevron` at the trailing top on the serif line's cap middle.
 */
@Composable
private fun WeekCard(card: RecapCardUi, state: RecapListState, nav: RecapNav) {
    val context = LocalContext.current
    val week = card.recap.weekStart
    val number = Formats.isoWeek(week)
    val range = Formats.weekRange(context, week, state.zone)
    val label = stringRes(R.string.week_recap_a11y_card, number, Formats.spokenWeekRange(context, week, state.zone))
    val title = TextRoles.displayTitle
    val inset = Tokens.Sizes.weekRecapDimensionWeekCardTextInset
    val capHeight = CapTop.height(title)
    Box(
        Modifier
            .fillMaxWidth()
            .aspectRatio(Tokens.AspectRatios.weekRecapAspectRatioWeekCard)
            .clip(RoundedCornerShape(Tokens.Radii.weekRecapRadiusCard))
            .tapClickable { nav.open(card.recap.id) }
            .clearAndSetSemantics {
                contentDescription = label
                role = Role.Button
            },
    ) {
        RemotePhoto(card.coverPath, null, Modifier.fillMaxSize())
        Column(Modifier.padding(start = inset)) {
            Text(
                stringRes(R.string.photo_viewer_header_week, number),
                style = title,
                color = Tokens.Colors.globalTextOnMedia,
                maxLines = 1,
                modifier = Modifier.capTopAt(Tokens.Sizes.weekRecapDimensionWeekCardTextTop, capHeight).endAtLastBaseline(),
            )
            Text(range, style = TextRoles.listSubtitle, color = Tokens.Colors.globalTextOnMedia, maxLines = 1, modifier = Modifier.paddingFromBaseline(top = Tokens.Sizes.weekRecapDimensionWeekCardLinePitch))
        }
        Icon(
            Tokens.Icons.globalChevron,
            contentDescription = null,
            tint = Tokens.Colors.globalTextOnMedia,
            modifier = Modifier
                .align(Alignment.TopEnd)
                .padding(end = inset, top = Tokens.Sizes.weekRecapDimensionWeekCardTextTop + capHeight / 2 - Tokens.Sizes.globalIcon / 2)
                .size(Tokens.Sizes.globalIcon),
        )
    }
}

@Composable
fun WeekRecapScreen(vm: RecapViewModel, nav: RecapNav) {
    val state by vm.state.collectAsStateWithLifecycle()
    WeekRecapPreview(state, nav, onRetry = vm::load)
}

/**
 * One recap's preview (`week.recap.layout.preview`): core:ui's recap preview (dark in both appearances) with the two
 * pages (card, cover), dots `dimension.year.story.dots.offset` below the page, the select-photos thumbnail leading and
 * the "Save as Album" light pill (text role `pill`) trailing.
 */
@Composable
fun WeekRecapPreview(state: RecapState, nav: RecapNav, onRetry: () -> Unit, initialPage: Int = 0) {
    val context = LocalContext.current
    var page by remember { mutableIntStateOf(initialPage) }
    val recap = state.recap
    val number = recap?.let { Formats.isoWeek(it.weekStart) }
    val title = number?.let { stringRes(R.string.photo_viewer_header_week, it) }.orEmpty()
    val range = recap?.let { Formats.weekRange(context, it.weekStart, state.zone) }.orEmpty()
    val cardLabel = recap?.let { stringRes(R.string.week_recap_a11y_card, number ?: 0, Formats.spokenWeekRange(context, it.weekStart, state.zone)) }.orEmpty()
    val groupName = state.group?.name.orEmpty()
    val cover = state.card.firstOrNull()?.thumbPath
    val ready = state.phase == RecapState.Phase.Ready && recap != null
    val photos = state.card.map { p ->
        val date = Formats.viewerDate(p.post.createdAt, state.zone)
        RecapCardPhoto(photoModel(p.thumbPath), stringRes(R.string.photo_viewer_a11y_photo, p.authorName.orEmpty(), date)) { recap?.let { nav.cardPhoto(it.id, p.post.id) } }
    }
    val note = recap?.text?.takeIf { it.isNotBlank() }?.let { RecapNote(it, state.editor?.firstName, state.editor?.avatarPath) }
    MediaAppearance {
        RecapPreviewScreen(
            backdrop = if (ready) photoModel(cover) else null,
            pageCount = if (ready) PAGES + state.collages.size else 1,
            currentPage = page,
            onPageChange = { page = it },
            onClose = nav.back,
            closeContentDescription = stringRes(R.string.week_recap_a11y_close),
            modifier = Modifier.testTag("week.recap.preview"),
            pill = if (ready) RecapPill(stringRes(R.string.week_recap_saveasalbum), { nav.saveAsAlbum(recap!!.id) }, label = RecapPillLabel.Pill) else null,
            dots = RecapDots.BelowPage(Tokens.Sizes.yearStoryDotsOffset),
            bottomLeading = if (ready) ({ SelectPhotosThumb(cover, stringRes(R.string.week_recap_a11y_edit)) { nav.edit(recap!!.id) } }) else null,
            beforeClose = if (ready) ({ MediaReportMenu(stringRes(R.string.safety_report_menuitem_recap), onReport = { nav.report(recap!!.id) }) }) else null,
        ) { index ->
            when {
                // Loading: the card's cells as `color.global.control` placeholders (two rows) until the images load.
                state.phase == RecapState.Phase.Loading -> RecapCardPage(List(RecapCardMetrics.columns * 2) { RecapCardPhoto(null, "") }, title)
                state.phase == RecapState.Phase.Pending -> FrameLine(stringRes(R.string.week_recap_pending), null)
                !ready -> FrameLine(stringRes(R.string.week_recap_error_title), onRetry)
                index == 0 -> {
                    // `week.recap.layout.gridFill`: the grid's shape follows the photo count and always fills the card's photo area.
                    val grid = recapGrid(photos.size)
                    val shown = recapCardCells(photos.size)
                    val labelled = Modifier.semantics { contentDescription = cardLabel }
                    if (note != null) Box(labelled) { RecapCardWithNote(photos, title, groupName, range, shown, grid, note) }
                    else RecapCardPage(photos, title, labelled, name = groupName, detail = range, shown = shown, grid = grid)
                }
                index == 1 -> RecapCoverPage(title, Modifier.semantics { contentDescription = cardLabel }, name = groupName, detail = range) {
                    RemotePhoto(cover, null, Modifier.fillMaxSize(), placeholder = Tokens.Colors.globalControlOnDeep)
                }
                // Pages 3…: the week's same-moment collages, each fitted whole (never cropped) on its own blurred page, its
                // day in the footer (as the year story's collage card); a tap opens it (`collage.view`).
                else -> state.collages.getOrNull(index - PAGES)?.let { c ->
                    val label = stringRes(R.string.collage_view_a11y_collage, groupName, Formats.spokenDate(c.localDate))
                    RecapCoverPage(
                        app.feature.memory.common.MemoryFormats.storyDate(c.localDate),
                        Modifier.semantics { contentDescription = label }.tapClickable { nav.collage(c.invitationId) },
                        titleStyle = TextRoles.displaySmall,
                    ) {
                        Box(Modifier.fillMaxSize()) {
                            app.ui.components.BlurredBackdrop(photoModel(c.imagePath), modifier = Modifier.fillMaxSize())
                            RemotePhoto(c.imagePath, null, Modifier.fillMaxSize(), contentScale = androidx.compose.ui.layout.ContentScale.Fit, placeholder = androidx.compose.ui.graphics.Color.Transparent)
                        }
                    }
                }
            }
        }
    }
}

/** One line centred in the frame (`body`, `color.global.textSecondary`): pending, or the error that reloads on tap. */
@Composable
private fun androidx.compose.foundation.layout.BoxScope.FrameLine(text: String, onTap: (() -> Unit)?) {
    Text(
        text,
        style = TextRoles.body,
        color = Tokens.ColorsDark.globalTextSecondary,
        textAlign = TextAlign.Center,
        modifier = Modifier
            .align(Alignment.Center)
            .padding(horizontal = Tokens.Sizes.globalScreenMargin)
            .then(if (onTap != null) Modifier.tapClickable(onClick = onTap) else Modifier),
    )
}

/** Page 1 the card, page 2 the cover (`week.recap.layout.pages`); the recap's collages follow, one page each. */
private const val PAGES = 2
