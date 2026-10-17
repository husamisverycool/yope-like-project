package app.ui.components

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.paddingFrom
import androidx.compose.foundation.lazy.LazyListState
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.Immutable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.layout.LastBaseline
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.Dp
import app.designsystem.generated.Tokens
import app.ui.foundation.DsImage
import app.ui.foundation.GlyphInk
import app.ui.foundation.PageRoles
import app.ui.foundation.overlayCentred
import app.ui.foundation.tapClickable
import app.ui.foundation.tapLongPressable
import app.ui.system.DsDropdownMenu
import app.ui.system.DsMenuItem
import app.ui.text.CapTop
import app.ui.text.TextRoles
import app.ui.text.capTopAt

/**
 * C-20 Section header ("Week 27  Jul 3 - 9"): two runs on one baseline, one space apart — [title] in text role
 * `sectionLabel` (15 semibold, `color.global.textPrimary`), [range] in `listSubtitle` (15 regular, secondary
 * text; null for the current week without photos) — then "•••" (`icon.global.more`, `color.global.textPrimary`)
 * with its ink at the right margin, opening the native menu [menu] (C-29; Retro's week menu contents are not
 * captured — Gap). Content below starts `size.global.sectionHeaderToContent` under the baseline; with
 * [afterContent] the header's cap top sits `size.global.sectionGap` below the previous content. Header trait,
 * read as one element ([accessibilityLabel] from copy, "Week 27, July 3 to 9"). The range on white fails
 * contrast (CONTRAST failure 1).
 */
@Composable
fun SectionHeader(
    title: String,
    modifier: Modifier = Modifier,
    range: String? = null,
    accessibilityLabel: String? = null,
    menu: List<DsMenuItem> = emptyList(),
    moreContentDescription: String? = null,
    afterContent: Boolean = false,
) {
    val style = TextRoles.sectionLabel
    val secondary = PageRoles.secondaryText()
    // The rhythm paddings go on the row, so the "•••" centres on the text line, not on the padded box.
    Row(
        modifier
            .fillMaxWidth()
            .capTopAt(if (afterContent) Tokens.Sizes.globalSectionGap else Dp.Unspecified, CapTop.height(style))
            .paddingFrom(LastBaseline, after = Tokens.Sizes.globalSectionHeaderToContent)
            .padding(horizontal = Tokens.Sizes.globalScreenMargin),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            buildAnnotatedString {
                append(title)
                if (range != null) {
                    append(' ')
                    withStyle(TextRoles.listSubtitle.toSpanStyle().copy(color = secondary)) { append(range) }
                }
            },
            style = style,
            color = Tokens.Colors.globalTextPrimary,
            modifier = Modifier
                .weight(1f)
                .semantics(mergeDescendants = true) {
                    heading()
                    if (accessibilityLabel != null) contentDescription = accessibilityLabel
                },
        )
        if (menu.isNotEmpty() && moreContentDescription != null) {
            var open by remember { mutableStateOf(false) }
            val more = Tokens.Icons.globalMore
            // The glyph's ink sits on the margin: shift the hit area out by its padding around the ink.
            val outset = GlyphInk.trailing(more, Tokens.Sizes.globalIcon) + (headerHit - Tokens.Sizes.globalIcon) / 2
            Box(Modifier.overlayCentred().offset(x = outset)) {
                HeaderIconButton(more, moreContentDescription, { open = true })
                DsDropdownMenu(expanded = open, onDismissRequest = { open = false }, items = menu)
            }
        }
    }
}

/**
 * A photo cell of a C-21 grid: [accessibilityLabel] (copy) names its date / person; [menu] is its long-press menu (C-29);
 * [batch]: it stands for photos posted together — the batch marker (`layout.global.batchMarker`).
 */
@Immutable
data class GridCell(val key: Any, val image: Any?, val accessibilityLabel: String, val onClick: (() -> Unit)? = null, val menu: List<DsMenuItem> = emptyList(), val batch: Boolean = false)

/**
 * C-21 photo grid: [columns] square cells (`radius.global.photo`, 0), `size.global.stripGap` apart, full width
 * inside [contentPadding] (`size.global.screenMargin` for the dated album grid, TC-J1). Use 3 columns for the
 * album grid and 4 for the composer picker (VID-COMP; its ≈1–2 pt gap uses `size.global.stripGap`). Not lazy:
 * one section at a time (put each dated section in its own lazy item). Each cell is a button labelled from copy.
 */
@Composable
fun PhotoGrid(
    cells: List<GridCell>,
    columns: Int,
    modifier: Modifier = Modifier,
    contentPadding: Dp = Tokens.Sizes.globalScreenMargin,
) {
    val gap = Tokens.Sizes.globalStripGap
    Column(modifier.fillMaxWidth().padding(horizontal = contentPadding), verticalArrangement = Arrangement.spacedBy(gap)) {
        cells.chunked(columns.coerceAtLeast(1)).forEach { row ->
            Row(horizontalArrangement = Arrangement.spacedBy(gap)) {
                row.forEach { cell ->
                    var menuOpen by remember(cell.key) { mutableStateOf(false) }
                    Box(Modifier.weight(1f).aspectRatio(1f)) {
                        DsImage(
                            cell.image,
                            null,
                            Modifier
                                .matchParentSize()
                                .clearAndSetSemantics { contentDescription = cell.accessibilityLabel }
                                .then(
                                    when {
                                        cell.menu.isNotEmpty() -> Modifier.tapLongPressable(cell.onClick, { menuOpen = true }, cell.menu.map { it.text to it.onClick })
                                        cell.onClick != null -> Modifier.tapClickable(onClick = cell.onClick)
                                        else -> Modifier
                                    },
                                ),
                        )
                        if (cell.batch) BatchTileMarker()
                        if (cell.menu.isNotEmpty()) DsDropdownMenu(expanded = menuOpen, onDismissRequest = { menuOpen = false }, items = cell.menu)
                    }
                }
                repeat(columns - row.size) { Spacer(Modifier.weight(1f)) }
            }
        }
    }
}

/** A person of the C-21 people grid. */
@Immutable
data class PersonCell(val key: Any, val name: String, val avatar: Any?, val onClick: (() -> Unit)? = null)

/**
 * C-21 people grid: 3 equal columns inside `size.global.screenMargin` (Retro's 2023 column pitch 125 ≈ a third
 * of the width), each a `size.global.avatarGrid` (81) avatar with the name in text role `listTitle` centred
 * below; rows `size.global.listGap` apart (the grid's own row gap is not measured — Gap). Each person is one
 * button with the name as its label.
 */
@Composable
fun PeopleGrid(people: List<PersonCell>, modifier: Modifier = Modifier) {
    val columns = PEOPLE_COLUMNS
    Column(modifier.fillMaxWidth().padding(horizontal = Tokens.Sizes.globalScreenMargin), verticalArrangement = Arrangement.spacedBy(Tokens.Sizes.globalListGap)) {
        people.chunked(columns).forEach { row ->
            Row {
                row.forEach { person ->
                    Column(
                        Modifier
                            .weight(1f)
                            .then(if (person.onClick != null) Modifier.tapClickable(onClick = person.onClick) else Modifier)
                            .semantics(mergeDescendants = true) {},
                        horizontalAlignment = Alignment.CenterHorizontally,
                    ) {
                        Avatar(person.avatar, Tokens.Sizes.globalAvatarGrid)
                        Text(person.name, style = TextRoles.listTitle, color = Tokens.Colors.globalTextPrimary, textAlign = TextAlign.Center, maxLines = 1)
                    }
                }
                repeat(columns - row.size) { Spacer(Modifier.weight(1f)) }
            }
        }
    }
}

/** C-21: the people grid has 3 columns (TC-1B). */
private const val PEOPLE_COLUMNS = 3

/**
 * C-21 profile / history week section: a C-20 [SectionHeader] over a C-17 [WeekStrip], repeated down a list
 * (each section after the first passes [afterContent] = true for the `size.global.sectionGap` rhythm).
 */
@Composable
fun WeekSection(
    title: String,
    tiles: List<DayTile>,
    modifier: Modifier = Modifier,
    range: String? = null,
    accessibilityLabel: String? = null,
    menu: List<DsMenuItem> = emptyList(),
    moreContentDescription: String? = null,
    afterContent: Boolean = false,
    stripState: LazyListState = rememberLazyListState(),
) {
    Column(modifier.fillMaxWidth()) {
        SectionHeader(title, range = range, accessibilityLabel = accessibilityLabel, menu = menu, moreContentDescription = moreContentDescription, afterContent = afterContent)
        WeekStrip(tiles, state = stripState)
    }
}
