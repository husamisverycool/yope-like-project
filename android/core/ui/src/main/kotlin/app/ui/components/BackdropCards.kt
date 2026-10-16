package app.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.blur
import androidx.compose.ui.draw.clipToBounds
import androidx.compose.ui.draw.BlurredEdgeTreatment
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.Dp
import app.designsystem.blurRadiusForSigma
import app.designsystem.generated.Tokens
import app.ui.foundation.DsImage
import app.ui.foundation.PageRoles
import app.ui.text.TextRoles

/**
 * C-34 backdrop: the photo full-bleed with a mild Gaussian blur of standard deviation [sigma]
 * (`size.global.backdropBlur`, 1.8 pt) under a black layer (`color.global.backdropDim`, 22 %), both fitted on
 * Retro's recap preview ST-04 (design/MERGE_DECISIONS.md L-5) — not a frosted material. The blur is the platform's
 * RenderEffect (API 31+; earlier versions show the photo unblurred, still dimmed).
 */
@Composable
fun BlurredBackdrop(photo: Any?, sigma: Dp = Tokens.Sizes.globalBackdropBlur, modifier: Modifier = Modifier) {
    val radius = with(LocalDensity.current) { blurRadiusForSigma(sigma.toPx()).toDp() }
    Box(modifier.fillMaxSize().clipToBounds()) {
        DsImage(photo, null, Modifier.fillMaxSize().blur(radius, BlurredEdgeTreatment.Rectangle), placeholder = Tokens.Colors.globalBackgroundDeep)
        Box(Modifier.fillMaxSize().background(Tokens.Colors.globalBackdropDim))
    }
}

/**
 * A photo blurred to a colour field (`layout.global.colourFieldBackdrop`, MERGE L-9): Gaussian σ = [sigmaToWidth] × the
 * frame width (edges clamped, so no bleed is needed), under `color.global.backdropDim`. Used where Retro shows a
 * structure-free wash (paywall, invite card) — not the recap's mild blur ([BlurredBackdrop], L-5).
 */
@Composable
fun ColourFieldBackdrop(
    photo: Any?,
    modifier: Modifier = Modifier,
    sigmaToWidth: Float = Tokens.Layouts.GlobalColourFieldBackdrop.blurSigmaToWidth,
) {
    BoxWithConstraints(modifier.fillMaxSize()) {
        BlurredBackdrop(photo, sigma = maxWidth * sigmaToWidth)
    }
}

/**
 * C-34 recap card: `color.global.surfaceElevated` (#FFFFFF / #181818); [photos] in a [columns]-column grid of
 * square cells with `radius.global.thumbnail` corners, `size.global.stripGap` apart; footer: [year] in
 * `font.global.display` text role `headerTitle` (the recap card's measured title, RM-8), [name] text role `listTitle`,
 * [domain] text role `meta` in
 * secondary text. The card's corners (≈ 4.5–5 % of its width, TC-H) have no token (Gap): [cornerRadius] comes
 * from the caller; its inner padding is not measured either — `size.global.screenMargin` (Gap).
 */
@Composable
fun RecapCard(
    photos: List<Any?>,
    columns: Int,
    cornerRadius: Dp,
    modifier: Modifier = Modifier,
    year: String? = null,
    name: String? = null,
    domain: String? = null,
) {
    val gap = Tokens.Sizes.globalStripGap
    val cell = RoundedCornerShape(Tokens.Radii.globalThumbnail)
    Column(
        modifier
            .clip(RoundedCornerShape(cornerRadius))
            .background(Tokens.Colors.globalSurfaceElevated)
            .padding(Tokens.Sizes.globalScreenMargin)
            .semantics(mergeDescendants = true) {},
        verticalArrangement = Arrangement.spacedBy(gap),
    ) {
        photos.chunked(columns.coerceAtLeast(1)).forEach { row ->
            Row(horizontalArrangement = Arrangement.spacedBy(gap)) {
                row.forEach { DsImage(it, null, Modifier.weight(1f).aspectRatio(1f).clip(cell)) }
                repeat(columns - row.size) { Spacer(Modifier.weight(1f)) }
            }
        }
        if (year != null || name != null || domain != null) {
            Row(Modifier.fillMaxWidth().padding(top = Tokens.Sizes.globalScreenMargin), verticalAlignment = Alignment.Bottom) {
                if (year != null) Text(year, style = TextRoles.headerTitle, color = Tokens.Colors.globalTextPrimary, modifier = Modifier.weight(1f))
                Column(horizontalAlignment = Alignment.End) {
                    if (name != null) Text(name, style = TextRoles.listTitle, color = Tokens.Colors.globalTextPrimary)
                    if (domain != null) Text(domain, style = TextRoles.meta, color = PageRoles.secondaryText())
                }
            }
        }
    }
}

/**
 * C-34 plan card (paywall): `color.global.surfaceElevated` (opaque — the APK value; iOS's translucent white alpha
 * is not derivable, Gap), corners `radius.global.cardLarge`, padding `size.global.planCardPadding` around
 * [content]; its C-05 capsule ([actionText]) sits `size.global.screenMargin` (16) from the card's sides and bottom.
 */
@Composable
fun PlanCard(
    actionText: String,
    onAction: () -> Unit,
    modifier: Modifier = Modifier,
    actionEnabled: Boolean = true,
    actionLoading: Boolean = false,
    content: @Composable ColumnScope.() -> Unit,
) {
    val shape = RoundedCornerShape(Tokens.Radii.globalCardLarge)
    Column(modifier.clip(shape).background(Tokens.Colors.globalSurfaceElevated, shape)) {
        Column(Modifier.fillMaxWidth().padding(Tokens.Sizes.globalPlanCardPadding), content = content)
        PrimaryButton(
            actionText,
            onAction,
            Modifier.padding(start = Tokens.Sizes.globalScreenMargin, end = Tokens.Sizes.globalScreenMargin, bottom = Tokens.Sizes.globalScreenMargin),
            enabled = actionEnabled,
            loading = actionLoading,
        )
    }
}

/**
 * C-34 plan card pager: each card is the screen width − 2 × `size.global.buttonMarginH`, starting at
 * `size.global.buttonMarginH`; the next card peeks after `size.global.planCardGap`; a fling settles on a card's leading
 * edge. [state] lets the caller follow the visible card (the paywall's billing line).
 */
@Composable
fun PlanCardPager(
    count: Int,
    modifier: Modifier = Modifier,
    state: androidx.compose.foundation.lazy.LazyListState = rememberLazyListState(),
    card: @Composable (index: Int, width: Dp) -> Unit,
) {
    val margin = Tokens.Sizes.globalButtonMarginH
    BoxWithConstraints(modifier.fillMaxWidth()) {
        val width = maxWidth - margin * 2
        LazyRow(
            state = state,
            flingBehavior = androidx.compose.foundation.gestures.snapping.rememberSnapFlingBehavior(state, androidx.compose.foundation.gestures.snapping.SnapPosition.Start),
            contentPadding = PaddingValues(horizontal = margin),
            horizontalArrangement = Arrangement.spacedBy(Tokens.Sizes.globalPlanCardGap),
        ) {
            itemsIndexed(List(count) { it }) { index, _ -> Box(Modifier.width(width)) { card(index, width) } }
        }
    }
}
