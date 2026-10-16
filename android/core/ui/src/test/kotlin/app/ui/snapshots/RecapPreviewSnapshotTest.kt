package app.ui.snapshots

import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import app.designsystem.generated.Tokens
import app.ui.components.CircleButtonStyle
import app.ui.components.CircleIconButton
import app.ui.components.PositionPill
import app.ui.components.RecapCard
import app.ui.foundation.DsImage
import app.ui.recap.RecapDots
import app.ui.recap.RecapPill
import app.ui.recap.RecapPillLabel
import app.ui.recap.RecapPreviewDefaults
import app.ui.recap.RecapPreviewScreen
import org.junit.Test

/**
 * The shared recap preview (app.ui.recap, ST-04) as each caller uses it: collage.view (collage card, dots below
 * the page, Share), week.recap (recap card, dots below the page, thumbnail + "Save as Album"), year.story
 * (position pill, play circle, no dots), and the busy / no-backdrop states. Media surface: light and dark
 * render the same by design.
 */
class RecapPreviewSnapshotTest(appearance: Appearance) : SnapshotTest(appearance) {

    @Test fun collage() = snapScreen("recap-preview", "collage", surface = Surface.Media) {
        RecapPreviewScreen(
            backdrop = story(1),
            pageCount = 3,
            currentPage = 0,
            onPageChange = {},
            onClose = {},
            closeContentDescription = "Close",
            pill = RecapPill("Share", {}),
        ) { page ->
            val corner = Tokens.Layouts.CollageViewLayoutPage.outerRadiusRatio
            Box(Modifier.fillMaxSize().padding(RecapPreviewDefaults.collageCardPadding), contentAlignment = Alignment.Center) {
                Box(Modifier.aspectRatio(Tokens.Layouts.CollageViewLayoutPage.canvasAspect).clip(RoundedCornerShape(percent = (corner * 100).toInt()))) {
                    DsImage(story(page + 1), null, Modifier.fillMaxSize())
                }
            }
        }
    }

    @Test fun weekRecap() = snapScreen("recap-preview", "week-recap", surface = Surface.Media) {
        RecapPreviewScreen(
            backdrop = portrait(4),
            pageCount = 2,
            currentPage = 0,
            onPageChange = {},
            onClose = {},
            closeContentDescription = "Close",
            pill = RecapPill("Save as Album", {}, label = RecapPillLabel.Pill),
            dots = RecapDots.BelowPage(),
            bottomLeading = {
                DsImage(
                    square(5),
                    null,
                    Modifier
                        .padding(start = Tokens.Sizes.globalButtonMarginH)
                        .size(Tokens.Sizes.weekRecapDimensionSelectThumb)
                        .clip(RoundedCornerShape(Tokens.Radii.weekRecapRadiusSelectThumb))
                        .border(Tokens.Sizes.weekRecapDimensionSelectThumbBorder, Tokens.Colors.globalSurfaceLight, RoundedCornerShape(Tokens.Radii.weekRecapRadiusSelectThumb)),
                )
            },
        ) {
            Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                RecapCard(List(8) { square(it + 6) }, columns = 4, cornerRadius = Tokens.Radii.globalCard, modifier = Modifier.padding(horizontal = Tokens.Sizes.globalScreenMargin * 2), year = "Week 42", name = "Sunday dinners")
            }
        }
    }

    @Test fun storyBusy() = snapScreen("recap-preview", "story-busy", surface = Surface.Media) {
        RecapPreviewScreen(
            backdrop = null,
            pageCount = 1,
            currentPage = 0,
            onPageChange = {},
            onClose = {},
            closeContentDescription = "Close",
            pill = RecapPill("Share", {}, busy = true),
            dots = RecapDots.Hidden,
            topLeading = { PositionPill("3 of 12", modifier = Modifier.padding(start = Tokens.Sizes.globalScreenMargin)) },
            bottomLeading = {
                CircleIconButton(Tokens.Icons.globalPause, "Pause", {}, Modifier.padding(start = Tokens.Sizes.globalButtonMarginH), style = CircleButtonStyle.OnMedia)
            },
        ) {
            DsImage(story(7), null, Modifier.fillMaxSize())
        }
    }

    @Test fun noBackdrop() = snapScreen("recap-preview", "no-backdrop", surface = Surface.Media) {
        RecapPreviewScreen(
            backdrop = null,
            pageCount = 1,
            currentPage = 0,
            onPageChange = {},
            onClose = {},
            closeContentDescription = "Close",
        ) {}
    }

}
