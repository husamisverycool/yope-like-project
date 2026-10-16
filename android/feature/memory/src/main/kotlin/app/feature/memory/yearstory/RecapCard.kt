// Recap card and cover page — `layout.year.story.recapCard` (MERGE RM-8, lead L-4: white in both appearances).
// References: references/auto/retro/press/tc-2023-12-recaps.png phones 2–3 (TC-REC), press/tc-2023-12-retro-header.png (TC-H).
// Public: year.story's summary (memory) and week.recap's pages (social) draw the recap through these two composables.
package app.feature.memory.yearstory

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.paddingFrom
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.Immutable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.LastBaseline
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import app.designsystem.generated.Tokens
import app.ui.foundation.DsImage
import app.ui.foundation.PhotoScrimOverlay
import app.ui.foundation.tapClickable
import app.ui.text.TextRoles

/** One photo of a [RecapCard] grid: an image model (Painter, URL, Uri, File) and its label (copy); [onClick] makes it a button. */
@Immutable
data class RecapCardPhoto(val image: Any?, val accessibilityLabel: String, val onClick: (() -> Unit)? = null)

/** The recap card's geometry (`layout.year.story.recapCard`) for a card [width] wide. */
object RecapCardMetrics {
    private val card = Tokens.Layouts.YearStoryRecapCard

    /** Columns of the grid (4). */
    val columns: Int get() = card.columns.toInt()

    /** Most rows the grid shows (6); only full rows are shown. */
    val maxRows: Int get() = card.maxRows.toInt()

    /** The card's width inside a frame [frameWidth] wide (82.5 %). */
    fun width(frameWidth: Dp): Dp = frameWidth * card.widthRatio

    fun padding(width: Dp): Dp = width * card.paddingRatio
    fun corner(width: Dp): Dp = width * card.cornerRadiusRatio
    fun footerHeight(width: Dp): Dp = width * card.footerHeightRatio

    /** Photos the grid shows for [available] photos: whole rows of [columns], at most [maxRows] (0 under one row). */
    fun shown(available: Int): Int = (available / columns).coerceAtMost(maxRows) * columns

    /** Whether the card is offered at all (at least one full row). */
    fun offered(available: Int): Boolean = shown(available) > 0
}

/**
 * **Recap card** (`layout.year.story.recapCard`, C-34; white in both appearances — lead L-4): a card
 * `color.global.surfaceLight` with corners `cornerRadiusRatio` × its width and padding `paddingRatio` × its width,
 * holding a grid of [RecapCardMetrics.columns] columns × up to [RecapCardMetrics.maxRows] full rows of [photos]
 * (cells `cellAspect` 1.12:1 wide, aspect-fill, `size.global.stripGap` apart; the grid's outer corners follow the
 * card's, inset by its padding), then a footer `footerHeightRatio` × its width tall: [title] (the year, or "Week {n}")
 * in `font.global.display` text role `headerTitle`, `color.global.onSurfaceLight`, leading; trailing and
 * right-aligned [name] (text role [nameStyle], default `listTitle`, `color.global.onSurfaceLight`) over [detail]
 * (text role `meta`, `color.global.textSecondary` — the app line on the year card, the date range on a week recap).
 * Footer contents are centred in the footer's height (TC-REC).
 *
 * The card fills the width it is given ([modifier]); inside a recap frame give it [RecapCardMetrics.width] of the
 * frame width — or use [RecapCardPage]. Photos beyond the full rows are left out (only full rows: TC-REC); offer the
 * card only when [RecapCardMetrics.offered]. Read in order: each photo (its label; a button with [RecapCardPhoto.onClick]),
 * then the footer as one element. [image] draws one cell (default: core:ui `DsImage`, aspect fill, the
 * `color.global.control` light placeholder while loading); a share renderer passes its own software-decoded image.
 */
@Composable
fun RecapCard(
    photos: List<RecapCardPhoto>,
    title: String,
    modifier: Modifier = Modifier,
    name: String? = null,
    detail: String? = null,
    nameStyle: TextStyle = TextRoles.listTitle,
    image: @Composable (photo: RecapCardPhoto, modifier: Modifier) -> Unit = { photo, m -> DsImage(photo.image, null, m, placeholder = Tokens.ColorsLight.globalControl) },
) {
    BoxWithConstraints(modifier) {
        val width = maxWidth
        val padding = RecapCardMetrics.padding(width)
        val corner = RecapCardMetrics.corner(width)
        val gap = Tokens.Sizes.globalStripGap
        val columns = RecapCardMetrics.columns
        val shown = photos.take(RecapCardMetrics.shown(photos.size))
        val ink = Tokens.Colors.globalOnSurfaceLight
        Column(
            Modifier
                .width(width)
                .clip(RoundedCornerShape(corner))
                .background(Tokens.Colors.globalSurfaceLight)
                .padding(start = padding, top = padding, end = padding),
        ) {
            if (shown.isNotEmpty()) {
                Column(Modifier.fillMaxWidth().clip(RoundedCornerShape(corner - padding)), verticalArrangement = Arrangement.spacedBy(gap)) {
                    shown.chunked(columns).forEach { row ->
                        Row(horizontalArrangement = Arrangement.spacedBy(gap)) {
                            row.forEach { photo ->
                                image(
                                    photo,
                                    Modifier
                                        .weight(1f)
                                        .aspectRatio(Tokens.Layouts.YearStoryRecapCard.cellAspect)
                                        .then(if (photo.onClick != null) Modifier.tapClickable(onClick = photo.onClick) else Modifier)
                                        .clearAndSetSemantics { contentDescription = photo.accessibilityLabel },
                                )
                            }
                        }
                    }
                }
            }
            Row(
                Modifier.fillMaxWidth().height(RecapCardMetrics.footerHeight(width)).semantics(mergeDescendants = true) {},
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(title, style = TextRoles.headerTitle, color = ink, maxLines = 1)
                Column(Modifier.weight(1f), horizontalAlignment = Alignment.End) {
                    if (name != null) Text(name, style = nameStyle, color = ink, maxLines = 1, overflow = TextOverflow.Ellipsis, textAlign = TextAlign.End)
                    if (detail != null) Text(detail, style = TextRoles.meta, color = Tokens.Colors.globalTextSecondary, maxLines = 1, overflow = TextOverflow.Ellipsis, textAlign = TextAlign.End)
                }
            }
        }
    }
}

/**
 * Summary style 1 / week-recap page 1: [backdrop] (the cover photo blurred over the whole frame —
 * `layout.global.materials.backdrop`, drawn by the caller) with the [RecapCard] centred on it at
 * `widthRatio` × the frame's width. Fills the frame it is placed in.
 */
@Composable
fun RecapCardPage(
    photos: List<RecapCardPhoto>,
    title: String,
    modifier: Modifier = Modifier,
    name: String? = null,
    detail: String? = null,
    backdrop: @Composable () -> Unit = {},
    image: @Composable (photo: RecapCardPhoto, modifier: Modifier) -> Unit = { photo, m -> DsImage(photo.image, null, m, placeholder = Tokens.ColorsLight.globalControl) },
) {
    BoxWithConstraints(modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
        backdrop()
        RecapCard(photos, title, Modifier.width(RecapCardMetrics.width(maxWidth)), name = name, detail = detail, image = image)
    }
}

/**
 * Summary style 2 / week-recap page 2 (TC-REC phone 3): [cover] filling the frame (aspect fill) under
 * `layout.global.photoScrim`; footer at `dimension.year.story.frame.padding` from the sides with its last baselines
 * `dimension.year.story.footer.baseline` above the frame bottom: [title] leading in [titleStyle] (`headerTitle`
 * serif for the year / week; `displaySmall` for a photo card's date), [name] (text role `listTitle`) over [detail]
 * (text role `meta`) trailing and right-aligned — all `color.global.textOnMedia`. [cover] is drawn by the caller
 * (a photo, or a collage fitted on its own blurred backdrop).
 */
@Composable
fun RecapCoverPage(
    title: String,
    modifier: Modifier = Modifier,
    name: String? = null,
    detail: String? = null,
    titleStyle: TextStyle = TextRoles.headerTitle,
    titleColor: Color = Tokens.Colors.globalTextOnMedia,
    cover: @Composable () -> Unit,
) {
    Box(modifier.fillMaxSize()) {
        cover()
        PhotoScrimOverlay()
        RecapFooter(title, name, detail, titleStyle, titleColor, Modifier.align(Alignment.BottomCenter))
    }
}

/** The footer of [RecapCoverPage] and of the year story's photo / collage cards (TC-REC phone 3). */
@Composable
internal fun RecapFooter(title: String, name: String?, detail: String?, titleStyle: TextStyle, titleColor: Color, modifier: Modifier = Modifier) {
    val side = Tokens.Sizes.yearStoryFramePadding
    val baseline = Tokens.Sizes.yearStoryFooterBaseline
    Row(
        modifier.fillMaxWidth().padding(horizontal = side).semantics(mergeDescendants = true) {},
        horizontalArrangement = Arrangement.spacedBy(side),
        verticalAlignment = Alignment.Bottom,
    ) {
        // The title wraps when it is long ("Wednesday, February 25"); the trailing name keeps its width.
        Text(title, style = titleStyle, color = titleColor, modifier = Modifier.weight(1f).paddingFrom(LastBaseline, after = baseline))
        Column(Modifier.paddingFrom(LastBaseline, after = baseline), horizontalAlignment = Alignment.End) {
            if (name != null) Text(name, style = TextRoles.listTitle, color = Tokens.Colors.globalTextOnMedia, maxLines = 1, overflow = TextOverflow.Ellipsis, textAlign = TextAlign.End)
            if (detail != null) Text(detail, style = TextRoles.meta, color = Tokens.Colors.globalTextOnMedia, maxLines = 1, overflow = TextOverflow.Ellipsis, textAlign = TextAlign.End)
        }
    }
}
