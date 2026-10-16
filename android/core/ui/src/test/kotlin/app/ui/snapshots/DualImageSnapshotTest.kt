package app.ui.snapshots

import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.ui.Modifier
import app.designsystem.generated.Tokens
import app.testing.SamplePhotos
import app.ui.media.DualImage
import org.junit.Test

/** daily.dualimage (app.ui.media): the host-corner variants, single camera and loading, in light and dark. */
class DualImageSnapshotTest(appearance: Appearance) : SnapshotTest(appearance) {
    private val selfie get() = SamplePhotos.painter("selfie-two-friends-1x1", 3, 4)

    @Test fun viewfinderHost() = snap("dualimage", "viewfinder-host", surface = Surface.Media) {
        DualImage(portrait(0), selfie, "Back and front photos from Ana", Modifier.fillMaxWidth().padding(horizontal = Tokens.Sizes.globalScreenMargin), cornerRadius = Tokens.Radii.globalViewfinder)
    }

    @Test fun viewerHost() = snap("dualimage", "viewer-host", surface = Surface.Media) {
        DualImage(portrait(4), selfie, "Back and front photos from Ana", Modifier.fillMaxWidth(), cornerRadius = Tokens.Radii.globalPhoto)
    }

    @Test fun singleCamera() = snap("dualimage", "single-camera", surface = Surface.Media) {
        DualImage(portrait(2), null, "Back and front photos from Ana", Modifier.fillMaxWidth().padding(horizontal = Tokens.Sizes.globalScreenMargin), cornerRadius = Tokens.Radii.globalViewfinder)
    }

    @Test fun loadingOnPage() = snap("dualimage", "loading-page", surface = Surface.Page) {
        DualImage(null, null, null, Modifier.fillMaxWidth().padding(horizontal = Tokens.Sizes.globalScreenMargin), cornerRadius = Tokens.Radii.globalCard, loadingFill = Tokens.Colors.globalControl)
    }
}
