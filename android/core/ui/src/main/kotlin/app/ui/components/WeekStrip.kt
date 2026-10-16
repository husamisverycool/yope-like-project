package app.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.paddingFrom
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyListState
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.Immutable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.RectangleShape
import androidx.compose.ui.graphics.Shape
import androidx.compose.ui.layout.LastBaseline
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.unit.Dp
import app.designsystem.generated.Tokens
import app.ui.foundation.DsImage
import app.ui.foundation.DsMotion
import app.ui.foundation.PageRoles
import app.ui.foundation.PhotoScrimOverlay
import app.ui.foundation.reduceMotion
import app.ui.foundation.tapClickable
import app.ui.foundation.tapLongPressable
import app.ui.system.DsDropdownMenu
import app.ui.system.DsMenuItem
import app.ui.text.TextRoles

/** A tile of the C-17 week strip. [accessibilityLabel] (copy) carries the full date and content ("Monday, June 26, photo by Ana"). */
@Immutable
sealed interface DayTile {
    val key: Any
    val accessibilityLabel: String?

    /**
     * A day with a photo: aspect-fill photo, bottom scrim, [weekday] label ("Mon"). [menu]: the long-press menu (native
     * C-29 menu; also TalkBack custom actions), e.g. "Report Post" / "Block {first_name}" on someone else's photo.
     */
    data class Photo(
        override val key: Any,
        val image: Any?,
        val weekday: String,
        override val accessibilityLabel: String,
        val onClick: (() -> Unit)? = null,
        val menu: List<DsMenuItem> = emptyList(),
    ) : DayTile

    /** A day without photos: [month] / [day] / [weekday] lines on the fill. */
    data class Empty(
        override val key: Any,
        val month: String,
        val day: String,
        val weekday: String,
        override val accessibilityLabel: String,
        val onClick: (() -> Unit)? = null,
    ) : DayTile

    /** The add tile ("+"). */
    data class Add(override val accessibilityLabel: String, val onClick: () -> Unit, override val key: Any = ADD_KEY) : DayTile

    /**
     * A grey placeholder (loading, composer slot) — decorative. With [label]: the word centred in text role `tileLabel`,
     * secondary text (the developing tile, `camera.overnight.layout.developingTile`); not a button either way.
     */
    data class Placeholder(override val key: Any, override val accessibilityLabel: String? = null, val label: String? = null) : DayTile

    companion object {
        /** Stable key of the add tile. */
        const val ADD_KEY = "day-tile-add"
    }
}

/** Where the add tile goes (C-17: first when the week is empty, last otherwise — H22 / ST-01). */
object WeekStripOrder {
    fun withAdd(days: List<DayTile>, add: DayTile.Add): List<DayTile> =
        if (days.none { it is DayTile.Photo }) listOf(add) + days else days + add
}

/**
 * Corners of the [index]th of [count] tiles: only the strip's outer corners round (`radius.global.card`,
 * 18; inner corners `radius.global.photo`, 0) — the first tile's leading corners, the last tile's trailing ones.
 */
fun stripTileShape(index: Int, count: Int, radius: Dp = Tokens.Radii.globalCard): Shape {
    val inner = Tokens.Radii.globalPhoto
    val first = index == 0
    val last = index == count - 1
    if (!first && !last) return if (inner.value == 0f) RectangleShape else RoundedCornerShape(inner)
    return RoundedCornerShape(
        topStart = if (first) radius else inner,
        bottomStart = if (first) radius else inner,
        topEnd = if (last) radius else inner,
        bottomEnd = if (last) radius else inner,
    )
}

/**
 * C-17 Week strip: a horizontal scroller of 3:4 tiles `size.global.stripTileWidth` × `.stripTileHeight`
 * (84 × 112), `size.global.stripGap` (2) apart with the page showing through, leading inset
 * `size.global.screenMargin` and no trailing inset; only the strip's outer corners round ([stripTileShape]).
 * Order the add tile with [WeekStripOrder]. A new tile fades in (`duration.global.fade`) and the others shift
 * with `duration.global.stripInsert` / `easing.global.standard` (VM §D; the ≤ 0.875 start scale has no token —
 * Gap, not drawn); under Reduce Motion the shift snaps and the fade stays. The strip is a horizontally
 * scrolling list for TalkBack; every tile is a button labelled with its [DayTile.accessibilityLabel]
 * (the empty-tile text and photo labels fail contrast — CONTRAST failures 3 and 8 — so the label carries it).
 */
@Composable
fun WeekStrip(tiles: List<DayTile>, modifier: Modifier = Modifier, state: LazyListState = rememberLazyListState()) {
    val reduce = reduceMotion()
    LazyRow(
        modifier = modifier,
        state = state,
        contentPadding = PaddingValues(start = Tokens.Sizes.globalScreenMargin),
        horizontalArrangement = Arrangement.spacedBy(Tokens.Sizes.globalStripGap),
    ) {
        itemsIndexed(tiles, key = { _, tile -> tile.key }) { index, tile ->
            DayTileView(
                tile,
                stripTileShape(index, tiles.size),
                Modifier.animateItem(
                    fadeInSpec = DsMotion.fade(),
                    placementSpec = DsMotion.movement(DsMotion.stripInsert(), reduce),
                    fadeOutSpec = DsMotion.fade(),
                ),
            )
        }
    }
}

/**
 * One C-17 tile at `size.global.stripTileWidth` × `.stripTileHeight`, clipped to [shape].
 *
 * - Photo: aspect-fill, `layout.global.photoScrim`, weekday in text role `tileLabel` (13 semibold)
 *   `color.global.textOnMedia`, centred, baseline `size.global.tileLabelBaseline` above the bottom.
 * - Empty day: fill `color.global.control`; month (`tileMonth`), day number (`tileDay`, tabular digits),
 *   weekday (`tileMonth`) centred in `color.global.emptyTileText` (their 27 pt line pitch has no token —
 *   Gap: the roles' own line heights).
 * - Add: fill `color.global.control`, `icon.global.add` centred in `color.global.textPrimary` in the
 *   `size.global.icon` box (the 23 pt ink of H43 has no size token — Gap).
 * - Placeholder: fill `color.global.control`, nothing else; with a label, that word centred (`tileLabel`, secondary text).
 * Pressed: platform default + `haptic.global.tap`.
 */
@Composable
fun DayTileView(tile: DayTile, shape: Shape, modifier: Modifier = Modifier) {
    val onClick = when (tile) {
        is DayTile.Photo -> tile.onClick
        is DayTile.Empty -> tile.onClick
        is DayTile.Add -> tile.onClick
        is DayTile.Placeholder -> null
    }
    val label = tile.accessibilityLabel
    val menu = (tile as? DayTile.Photo)?.menu.orEmpty()
    var menuOpen by remember { mutableStateOf(false) }
    Box(
        modifier
            .size(Tokens.Sizes.globalStripTileWidth, Tokens.Sizes.globalStripTileHeight)
            .clip(shape)
            .then(if (tile is DayTile.Photo) Modifier else Modifier.background(Tokens.Colors.globalControl))
            .then(if (label != null) Modifier.clearAndSetSemantics { contentDescription = label } else Modifier.clearAndSetSemantics { })
            .then(
                when {
                    menu.isNotEmpty() -> Modifier.tapLongPressable(onClick, { menuOpen = true }, menu.map { it.text to it.onClick })
                    onClick != null -> Modifier.tapClickable(onClick = onClick)
                    else -> Modifier
                },
            ),
        contentAlignment = Alignment.Center,
    ) {
        if (menu.isNotEmpty()) DsDropdownMenu(expanded = menuOpen, onDismissRequest = { menuOpen = false }, items = menu)
        when (tile) {
            is DayTile.Photo -> {
                DsImage(tile.image, null, Modifier.fillMaxSize())
                PhotoScrimOverlay()
                Text(
                    tile.weekday,
                    style = TextRoles.tileLabel,
                    color = Tokens.Colors.globalTextOnMedia,
                    maxLines = 1,
                    modifier = Modifier.align(Alignment.BottomCenter).paddingFrom(LastBaseline, after = Tokens.Sizes.globalTileLabelBaseline),
                )
            }
            is DayTile.Empty -> Column(horizontalAlignment = Alignment.CenterHorizontally) {
                val color = Tokens.Colors.globalEmptyTileText
                Text(tile.month, style = TextRoles.tileMonth, color = color, maxLines = 1)
                Text(tile.day, style = TextRoles.tileDay, color = color, maxLines = 1)
                Text(tile.weekday, style = TextRoles.tileMonth, color = color, maxLines = 1)
            }
            is DayTile.Add -> Icon(Tokens.Icons.globalAdd, contentDescription = null, tint = Tokens.Colors.globalTextPrimary, modifier = Modifier.size(Tokens.Sizes.globalIcon))
            is DayTile.Placeholder -> if (tile.label != null) {
                Text(tile.label, style = TextRoles.tileLabel, color = PageRoles.secondaryText(), maxLines = 1)
            }
        }
    }
}
