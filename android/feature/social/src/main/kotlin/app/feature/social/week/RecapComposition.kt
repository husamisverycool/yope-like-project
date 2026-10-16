// Surface: week.recap preview pages — design/surfaces/week.recap.md (Structure B), year.story.md (C: recap card, cover)
// References: references/auto/retro/press/tc-2023-12-recaps.png phones 2–3 (white card on the blurred page, full-bleed
// cover), references/auto/retro/press/tc-2023-12-retro-header.png (card footer), references/auto/retro/store/retro-store-04.png
// (2026 preview chrome — drawn by core:ui `app.ui.recap.RecapPreviewScreen`).
package app.feature.social.week

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.paddingFrom
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.layout.LastBaseline
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.Dp
import app.designsystem.generated.Tokens
import app.feature.social.common.PersonAvatar
import app.feature.social.common.RemotePhoto
import app.ui.foundation.PhotoScrimOverlay
import app.ui.foundation.tapClickable
import app.ui.text.TextRoles

/*
 * week.recap's preview composes three groups' definitions (lead decision, MERGE RS-17 / L-4):
 *  - the chrome: core:ui `app.ui.recap.RecapPreviewScreen` (capture group, `collage.view.layout.screen`) — used directly;
 *  - the pages: the memory group's recap card and cover styles (`layout.year.story.recapCard`, `dimension.year.story.*`).
 *    `:feature:memory` has not published them yet, so they are drawn here from year.story.md — this file is the one
 *    place to switch to the memory group's composables.
 */

/** A cell of the recap card: a photo, its label (copy) and tap. */
data class RecapCell(val key: String, val path: String?, val label: String, val onClick: () -> Unit)

/**
 * How many of [count] photos the card draws (4 columns × up to 6 rows, `layout.year.story.recapCard`). The fill rule
 * for counts that do not fill a row is `week.recap.layout.gridFill` (BLOCKED): with [approximation] the development
 * approximation (row by row, empty cells left blank, beyond 24 not drawn); otherwise the year card's own rule (only
 * full rows).
 */
fun recapCardCells(count: Int, approximation: Boolean): Int {
    val card = Tokens.Layouts.YearStoryRecapCard
    val columns = card.columns.toInt()
    val max = columns * card.maxRows.toInt()
    return if (approximation) count.coerceAtMost(max) else (count / columns * columns).coerceAtMost(max)
}

/**
 * Page 1 — the recap card (`layout.year.story.recapCard`, white in both appearances — L-4): laid out in a 9:16 box as
 * wide as the media page and centred in it; the card `widthRatio` of the page, corners `cornerRadiusRatio` of its
 * width, padding `paddingRatio`; 4 columns of `cellAspect` cells `size.global.stripGap` apart; footer `footerHeightRatio`
 * of its width — "Week {n}" (`font.global.display`, `headerTitle`, `color.global.onSurfaceLight`) bottom-leading, the group
 * name (`listTitle`, `color.global.onSurfaceLight`) over the date range (`meta`, `color.global.textSecondary`) trailing.
 * Under it, when the recap has text, the note (`week.recap.layout.note`). [loading]: cells as `color.global.control`
 * placeholders.
 */
@Composable
fun BoxScope.RecapCardPage(
    cells: List<RecapCell>,
    shown: Int,
    title: String,
    groupName: String,
    range: String,
    cardLabel: String,
    note: RecapNote?,
    loading: Boolean = false,
) {
    val spec = Tokens.Layouts.YearStoryRecapCard
    val columns = spec.columns.toInt()
    BoxWithConstraints(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
        val frame = Tokens.Layouts.YearStoryFrame
        val boxHeight = maxWidth * (frame.aspectHeight / frame.aspectWidth)
        val cardWidth = maxWidth * spec.widthRatio
        val padding = cardWidth * spec.paddingRatio
        val corner = cardWidth * spec.cornerRadiusRatio
        val footer = cardWidth * spec.footerHeightRatio
        val gap = Tokens.Sizes.globalStripGap
        Column(Modifier.height(boxHeight.coerceAtMost(maxHeight)), verticalArrangement = Arrangement.Center, horizontalAlignment = Alignment.CenterHorizontally) {
            Column(
                Modifier
                    .width(cardWidth)
                    .clip(RoundedCornerShape(corner))
                    .background(Tokens.Colors.globalSurfaceLight)
                    .padding(start = padding, top = padding, end = padding)
                    .semantics(mergeDescendants = false) { contentDescription = cardLabel },
                verticalArrangement = Arrangement.spacedBy(gap),
            ) {
                val rows = (if (loading) List(columns * 2) { null } else cells.take(shown)).chunked(columns)
                rows.forEach { row ->
                    Row(horizontalArrangement = Arrangement.spacedBy(gap)) {
                        row.forEach { cell ->
                            val m = Modifier.weight(1f).aspectRatio(spec.cellAspect)
                            if (cell == null) Box(m.background(Tokens.Colors.globalControl))
                            else RemotePhoto(
                                cell.path,
                                null,
                                m.tapClickable(onClick = cell.onClick).clearAndSetSemantics {
                                    contentDescription = cell.label
                                    role = Role.Button
                                },
                            )
                        }
                        repeat(columns - row.size) { Spacer(Modifier.weight(1f)) }
                    }
                }
                CardFooter(title, groupName, range, footer, padding)
            }
            if (note != null) {
                Spacer(Modifier.height(Tokens.Sizes.weekRecapDimensionNoteGap))
                NoteBox(note, Modifier.width(cardWidth))
            }
        }
    }
}

/** The card footer: "Week {n}" bottom-leading at the card padding; name over range trailing, right-aligned. */
@Composable
private fun CardFooter(title: String, groupName: String, range: String, height: Dp, padding: Dp) {
    Row(Modifier.fillMaxWidth().height(height).padding(bottom = padding), verticalAlignment = Alignment.Bottom) {
        Text(title, style = TextRoles.headerTitle, color = Tokens.Colors.globalOnSurfaceLight, maxLines = 1, modifier = Modifier.weight(1f).clearAndSetSemantics { })
        Column(horizontalAlignment = Alignment.End, modifier = Modifier.clearAndSetSemantics { }) {
            Text(groupName, style = TextRoles.listTitle, color = Tokens.Colors.globalOnSurfaceLight, maxLines = 1, overflow = TextOverflow.Ellipsis, textAlign = TextAlign.End)
            Text(range, style = TextRoles.meta, color = Tokens.Colors.globalTextSecondary, maxLines = 1, textAlign = TextAlign.End)
        }
    }
}

/** The recap text and its last editor (`week.recap.layout.note`). */
data class RecapNote(val text: String, val editorName: String?, val editorAvatar: String?)

/**
 * Retro's journal note (`week.recap.layout.note`): a box the card's width, corners `week.recap.radius.note`, padding
 * `week.recap.dimension.notePaddingV` / `.notePaddingH`, fill `color.global.controlOnDeep`; the last editor's avatar
 * (`size.global.avatarComment`) and name (`listTitle`) lead the first line, then the text (`body`, `color.global.textOnMedia`).
 */
@Composable
private fun NoteBox(note: RecapNote, modifier: Modifier) {
    Row(
        modifier
            .clip(RoundedCornerShape(Tokens.Radii.weekRecapRadiusNote))
            .background(Tokens.Colors.globalControlOnDeep)
            .padding(horizontal = Tokens.Sizes.weekRecapDimensionNotePaddingH, vertical = Tokens.Sizes.weekRecapDimensionNotePaddingV)
            .semantics(mergeDescendants = true) { },
        verticalAlignment = Alignment.Top,
    ) {
        if (note.editorName != null) {
            PersonAvatar(note.editorAvatar, Tokens.Sizes.globalAvatarComment)
            Spacer(Modifier.width(Tokens.Sizes.chatThreadDimensionRowAvatarToText))
        }
        Text(
            buildAnnotatedString {
                if (note.editorName != null) {
                    withStyle(TextRoles.listTitle.toSpanStyle().copy(color = Tokens.Colors.globalTextOnMedia)) { append(note.editorName) }
                    append(' ')
                }
                append(note.text)
            },
            style = TextRoles.body,
            color = Tokens.Colors.globalTextOnMedia,
        )
    }
}

/**
 * Page 2 — the cover (`week.recap.layout.pages` page2, year.story full-bleed style): the first item fills the page
 * (aspect fill) under `layout.global.photoScrim`; "Week {n}" (`headerTitle` serif) leading and the name / range stack
 * trailing, at `dimension.year.story.frame.padding`, baselines `dimension.year.story.footer.baseline` above the bottom.
 */
@Composable
fun BoxScope.RecapCoverPage(coverPath: String?, title: String, groupName: String, range: String, label: String) {
    RemotePhoto(coverPath, null, Modifier.fillMaxSize().clearAndSetSemantics { contentDescription = label }, placeholder = Tokens.Colors.globalControlOnDeep)
    PhotoScrimOverlay()
    Row(
        Modifier
            .align(Alignment.BottomStart)
            .fillMaxWidth()
            .padding(horizontal = Tokens.Sizes.yearStoryFramePadding)
            .paddingFrom(LastBaseline, after = Tokens.Sizes.yearStoryFooterBaseline)
            .clearAndSetSemantics { },
        verticalAlignment = Alignment.Bottom,
    ) {
        Text(title, style = TextRoles.headerTitle, color = Tokens.Colors.globalTextOnMedia, maxLines = 1, modifier = Modifier.weight(1f))
        Column(horizontalAlignment = Alignment.End) {
            Text(groupName, style = TextRoles.listTitle, color = Tokens.Colors.globalTextOnMedia, maxLines = 1, overflow = TextOverflow.Ellipsis)
            Text(range, style = TextRoles.meta, color = Tokens.Colors.globalTextOnMedia, maxLines = 1)
        }
    }
}

/**
 * The select-photos thumbnail (`week.recap.dimension.selectThumb` square, corners `week.recap.radius.selectThumb`,
 * `week.recap.dimension.selectThumbBorder` border in `color.global.surfaceLight`, the recap's first item, aspect fill)
 * at `size.global.buttonMarginH` → `week.edit`. No count badge.
 */
@Composable
fun SelectPhotosThumb(path: String?, label: String, onClick: () -> Unit) {
    val shape = RoundedCornerShape(Tokens.Radii.weekRecapRadiusSelectThumb)
    Box(
        Modifier
            .padding(start = Tokens.Sizes.globalButtonMarginH)
            .size(Tokens.Sizes.weekRecapDimensionSelectThumb)
            .clip(shape)
            .background(Tokens.Colors.globalSurfaceLight, shape)
            .padding(Tokens.Sizes.weekRecapDimensionSelectThumbBorder)
            .clip(RoundedCornerShape(Tokens.Radii.weekRecapRadiusSelectThumb - Tokens.Sizes.weekRecapDimensionSelectThumbBorder))
            .tapClickable(onClick = onClick)
            .clearAndSetSemantics {
                contentDescription = label
                role = Role.Button
            },
    ) {
        RemotePhoto(path, null, Modifier.fillMaxSize(), placeholder = Tokens.Colors.globalControlOnDeep)
    }
}
