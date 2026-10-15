// Surface: onthisday — design/surfaces/onthisday.md
// References: references/auto/timehop/store/timehop-store-01.png, -02.png, -03.png, -05.png;
// references/auto/timehop/play/timehop-play-01.png, -02.png, -05.png;
// references/auto/timehop/help/th-help-2023-04-memory-view-hide.png (progress bar, meta row, close).
package app.feature.memory.onthisday

import androidx.compose.animation.Crossfade
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.asPaddingValues
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.paddingFromBaseline
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBars
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.lazy.staggeredgrid.LazyVerticalStaggeredGrid
import androidx.compose.foundation.lazy.staggeredgrid.StaggeredGridCells
import androidx.compose.foundation.lazy.staggeredgrid.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.text.BasicText
import androidx.compose.material3.Icon
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.layout.layout
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.CustomAccessibilityAction
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.customActions
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.platform.LocalContext
import app.designsystem.R
import app.designsystem.generated.Tokens
import app.feature.memory.common.HeaderCircleButton
import app.feature.memory.common.MemoryBlocked
import app.feature.memory.common.PreloadImages
import app.feature.memory.common.MemoryFormats
import app.feature.memory.common.MemoryImage
import app.feature.memory.common.MessageBlock
import app.feature.memory.common.PlatformSpinner
import app.feature.memory.common.roleStyle
import app.feature.memory.common.touchOutset
import java.time.ZoneId

/** Test tags of the day's parts (flow tests). */
object OnThisDayTags {
    const val ROOT = "onthisday"
    const val CONTENT = "onthisday.content"
    const val LABEL = "onthisday.label"
}

/**
 * The day, full screen: banner with progress bar, years-ago label and close; then one photo or the
 * two-column masonry grid. Taps on the right / left half move to the older / newer year.
 */
@Composable
fun OnThisDayScreen(
    state: OnThisDayState,
    onNext: () -> Unit,
    onPrevious: () -> Unit,
    onRetry: () -> Unit,
    onClose: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Box(modifier.fillMaxSize().background(Tokens.Colors.globalBackground).testTag(OnThisDayTags.ROOT)) {
        when (state) {
            OnThisDayState.Loading -> Loading()
            is OnThisDayState.Failed -> MessageBlock(
                title = stringResource(if (state.offline) R.string.onthisday_offline_title else R.string.onthisday_error_title),
                detail = stringResource(if (state.offline) R.string.onthisday_offline_detail else R.string.onthisday_error_detail),
                action = stringResource(R.string.onthisday_error_retry),
                onAction = onRetry,
                modifier = Modifier.fillMaxSize(),
            )
            is OnThisDayState.Day -> Day(state, onNext, onPrevious, onClose)
            OnThisDayState.Finished -> Unit
        }
    }
}

@Composable
private fun Loading() {
    Column(Modifier.fillMaxSize()) {
        Box(Modifier.fillMaxWidth().height(Tokens.Sizes.onthisdayBannerHeight).background(Tokens.Colors.onthisdayBanner))
        Column(
            Modifier.fillMaxSize(),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center,
        ) {
            PlatformSpinner()
            Spacer(Modifier.size(Tokens.Sizes.globalListGap))
            BasicText(
                stringResource(R.string.onthisday_loading),
                style = roleStyle(Tokens.FontSizes.globalListSubtitle, Tokens.FontWeights.fontWeightGlobalListSubtitle)
                    .copy(color = Tokens.Colors.globalTextSecondary),
            )
        }
    }
}

@Composable
private fun Day(state: OnThisDayState.Day, onNext: () -> Unit, onPrevious: () -> Unit, onClose: () -> Unit) {
    val resources = LocalContext.current.resources
    val next by rememberUpdatedState(onNext)
    val previous by rememberUpdatedState(onPrevious)
    val olderLabel = stringResource(R.string.onthisday_a11y_next)
    val backLabel = stringResource(R.string.onthisday_a11y_previous)
    Column(Modifier.fillMaxSize()) {
        Banner(MemoryFormats.yearsAgo(resources, state.year.yearsAgo), state.progress, onClose)
        Box(
            Modifier
                .fillMaxWidth()
                .weight(1f)
                .testTag(OnThisDayTags.CONTENT)
                // layout.onthisday.navigation: right half → older, left half → newer; no other tap target.
                .pointerInput(Unit) {
                    detectTapGestures { offset -> if (offset.x >= size.width / 2f) next() else previous() }
                }
                .semantics {
                    customActions = buildList {
                        add(CustomAccessibilityAction(olderLabel) { next(); true })
                        if (!state.isNewest) add(CustomAccessibilityAction(backLabel) { previous(); true })
                    }
                },
        ) {
            // `duration.onthisday.memoryChange` is BLOCKED: the year changes without animation until it is sourced.
            val change = MemoryBlocked.onThisDayMemoryChangeMs
            if (change == null) {
                YearContent(state.year, state.zone)
            } else {
                Crossfade(state.index, animationSpec = tween(change), label = "memoryChange") { index -> YearContent(state.years[index], state.zone) } // provenance-ok: animation inspector label, never shown
            }
        }
        // The next year's photos load before the tap, so they are on screen at once.
        PreloadImages(state.years.getOrNull(state.index + 1)?.photos.orEmpty().mapNotNull { photo -> if (state.years[state.index + 1].photos.size == 1) photo.displayUrl else photo.thumbUrl })
    }
}

@Composable
private fun YearContent(year: MemoryYear, zone: ZoneId) {
    if (year.photos.size == 1) SinglePhoto(year.photos.first(), zone) else Grid(year.photos, zone)
}

/** Banner: fill from the screen top, progress bar below the status bar, label + close on one row. */
@Composable
private fun Banner(label: String, progress: Float, onClose: () -> Unit) {
    Column(
        Modifier
            .fillMaxWidth()
            .background(Tokens.Colors.onthisdayBanner)
            .heightIn(min = Tokens.Sizes.onthisdayBannerHeight),
        verticalArrangement = Arrangement.SpaceBetween,
    ) {
        Box(
            Modifier
                .windowInsetsPadding(WindowInsets.statusBars)
                .fillMaxWidth()
                .height(Tokens.Sizes.onthisdayProgressHeight)
                .background(Tokens.Colors.onthisdayProgressTrack)
                .clearAndSetSemantics { },
        ) {
            Box(Modifier.fillMaxHeight().fillMaxWidth(progress).background(Tokens.Colors.onthisdayProgressFill))
        }
        Box(Modifier.fillMaxWidth().paddingFromBaseline(bottom = Tokens.Sizes.onthisdayBannerLabelBaseline)) {
            BasicText(
                label,
                Modifier
                    .align(Alignment.Center)
                    .padding(horizontal = Tokens.Sizes.globalHeaderButton + Tokens.Sizes.globalHeaderInset)
                    .testTag(OnThisDayTags.LABEL)
                    .semantics {
                        heading()
                        liveRegion = LiveRegionMode.Polite
                    },
                style = roleStyle(Tokens.FontSizes.onthisdayBannerLabel, Tokens.FontWeights.fontWeightOnthisdayBannerLabel, family = Tokens.Fonts.onthisday)
                    .copy(color = Tokens.Colors.onthisdayBannerLabel, textAlign = TextAlign.Center),
            )
            HeaderCircleButton(
                icon = Tokens.Icons.globalClose,
                contentDescription = stringResource(R.string.onthisday_a11y_close),
                onClick = onClose,
                modifier = Modifier.align(Alignment.CenterEnd).padding(end = Tokens.Sizes.globalHeaderInset - touchOutset(Tokens.Sizes.globalHeaderButton)),
            )
        }
    }
}

@Composable
private fun photoLabel(photo: MemoryPhoto, zone: ZoneId): String = stringResource(
    R.string.onthisday_a11y_photo,
    photo.authorName,
    MemoryFormats.spokenWeekday(photo.createdAt, zone),
    MemoryFormats.metaTime(photo.createdAt, zone),
)

/** `layout.onthisday.photo.single`: banner bottom to screen bottom, aspect-fill, meta row over it. */
@Composable
private fun SinglePhoto(photo: MemoryPhoto, zone: ZoneId) {
    Box(Modifier.fillMaxSize()) {
        MemoryImage(photo.displayUrl, photoLabel(photo, zone), Modifier.fillMaxSize(), ContentScale.Crop)
        MetaRow(photo, zone)
    }
}

/** Avatar + "TUE 10:34 PM", centred `dimension.onthisday.meta.centerY` below the banner. */
@Composable
private fun MetaRow(photo: MemoryPhoto, zone: ZoneId) {
    val centerY = Tokens.Sizes.onthisdayMetaCenterY
    Row(
        Modifier
            .layout { measurable, constraints ->
                val placeable = measurable.measure(constraints)
                layout(placeable.width, placeable.height) { placeable.place(0, centerY.roundToPx() - placeable.height / 2) }
            }
            .padding(start = Tokens.Sizes.onthisdayMetaInset)
            .clearAndSetSemantics { },
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(
            Modifier.size(Tokens.Sizes.onthisdayMetaAvatar).clip(CircleShape).background(Tokens.Colors.globalControl),
            contentAlignment = Alignment.Center,
        ) {
            if (photo.avatarUrl != null) MemoryImage(photo.avatarUrl, null, Modifier.fillMaxSize())
            else Icon(Tokens.Icons.globalPerson, contentDescription = null, tint = Tokens.Colors.globalTextPrimary)
        }
        Spacer(Modifier.size(Tokens.Sizes.onthisdayMetaGap))
        BasicText(
            stringResource(R.string.onthisday_memory_meta, MemoryFormats.metaWeekday(photo.createdAt, zone), MemoryFormats.metaTime(photo.createdAt, zone)),
            style = roleStyle(Tokens.FontSizes.onthisdayMeta, Tokens.FontWeights.fontWeightOnthisdayMeta, family = Tokens.Fonts.onthisday)
                .copy(color = Tokens.Colors.onthisdayMetaText),
        )
    }
}

/** `layout.onthisday.grid`: two-column masonry, each photo at its own aspect, shorter column first. */
@Composable
private fun Grid(photos: List<MemoryPhoto>, zone: ZoneId) {
    val navigation = WindowInsets.navigationBars.asPaddingValues()
    LazyVerticalStaggeredGrid(
        columns = StaggeredGridCells.Fixed(Tokens.Layouts.OnthisdayGrid.columns.toInt()),
        modifier = Modifier.fillMaxSize().background(Tokens.Colors.globalBackground),
        contentPadding = PaddingValues(
            start = Tokens.Sizes.onthisdayGridMargin,
            end = Tokens.Sizes.onthisdayGridMargin,
            top = Tokens.Sizes.onthisdayGridTop,
            bottom = navigation.calculateBottomPadding(),
        ),
        verticalItemSpacing = Tokens.Sizes.onthisdayGridGutter,
        horizontalArrangement = Arrangement.spacedBy(Tokens.Sizes.onthisdayGridGutter),
    ) {
        items(photos, key = { it.postId }) { photo ->
            MemoryImage(photo.thumbUrl, photoLabel(photo, zone), Modifier.fillMaxWidth().aspectRatio(photo.aspectRatio), ContentScale.Crop)
        }
    }
}
