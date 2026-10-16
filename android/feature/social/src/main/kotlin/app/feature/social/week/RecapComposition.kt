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
import app.feature.memory.yearstory.RecapCard
import app.feature.memory.yearstory.RecapCardMetrics
import app.feature.memory.yearstory.RecapCardPhoto
import app.feature.memory.yearstory.RecapGridShape
import app.ui.text.TextRoles
import kotlin.math.floor
import kotlin.math.sqrt

/*
 * week.recap's preview composes three groups' definitions (lead decision, MERGE RS-17 / L-4):
 *  - the chrome: core:ui `app.ui.recap.RecapPreviewScreen` (capture group, `collage.view.layout.screen`);
 *  - the pages: the memory group's `app.feature.memory.yearstory.RecapCard` / `RecapCardPage` / `RecapCoverPage`
 *    (`layout.year.story.recapCard`, white in both appearances, and the full-bleed cover);
 *  - this surface's own parts: the note under the card (`week.recap.layout.note`) and the select-photos thumbnail.
 */

/**
 * The card's grid for [count] photos (`week.recap.layout.gridFill`, Retro's cards with 1, 9 and 24 photos): ⌊√n⌋
 * columns (1 … `maxColumns`), ⌈n ÷ columns⌉ rows (at most `maxRows`), sharing a photo area as wide as the card minus
 * its padding and that width ÷ `areaAspect` tall; null without photos.
 */
fun recapGrid(count: Int): RecapGridShape? {
    if (count <= 0) return null
    val fill = Tokens.Layouts.WeekRecapLayoutGridFill
    val columns = floor(sqrt(count.toDouble())).toInt().coerceIn(1, fill.maxColumns.toInt())
    val rows = ((count + columns - 1) / columns).coerceAtMost(fill.maxRows.toInt())
    return RecapGridShape(columns, rows, fill.areaAspect)
}

/** How many of [count] photos the card draws: all of them up to the grid's places (the rest stay in the recap and the viewer). */
fun recapCardCells(count: Int): Int = recapGrid(count)?.let { minOf(count, it.columns * it.rows) } ?: 0

/**
 * Page 1 with a note: the memory group's [RecapCard] at `widthRatio` of the page and, `week.recap.dimension.noteGap`
 * under it, the note box the card's width — the two centred together in the page (`week.recap.layout.note`).
 */
@Composable
fun BoxScope.RecapCardWithNote(photos: List<RecapCardPhoto>, title: String, name: String, detail: String, shown: Int, grid: RecapGridShape?, note: RecapNote) {
    BoxWithConstraints(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
        val width = RecapCardMetrics.width(maxWidth)
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            RecapCard(photos, title, Modifier.width(width), name = name, detail = detail, shown = shown, grid = grid)
            Spacer(Modifier.height(Tokens.Sizes.weekRecapDimensionNoteGap))
            NoteBox(note, Modifier.width(width))
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
