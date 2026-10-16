// The recap preview's bottom row without its media page — birthday.tribute (design/surfaces/birthday.tribute.md B.3:
// "Retro recap preview, as year.story"; references/auto/retro/store/retro-store-04.png). The full recap preview
// (year.story) is core:ui's `app.ui.recap.RecapPreviewScreen`; this row uses the same tokens, pill and lift rule.
package app.feature.memory.common

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.asPaddingValues
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.max
import app.designsystem.generated.Tokens
import app.ui.recap.RecapPill
import app.ui.recap.RecapPillButton

/**
 * Centre of the recap preview's bottom row above the screen bottom (`collage.view.layout.screen`
 * `bottomRowCentreFromScreenBottom`, 59.2), lifted — as `RecapPreviewScreen` does — only when a tall navigation
 * bar would cover the pill.
 */
@Composable
fun recapRowCentre(): Dp {
    val navBar = WindowInsets.navigationBars.asPaddingValues().calculateBottomPadding()
    return max(Dp(Tokens.Layouts.CollageViewLayoutScreen.bottomRowCentreFromScreenBottom), navBar + Dp(Tokens.Layouts.CollageShareLayoutPill.height) / 2)
}

/**
 * The recap preview's bottom row: [leading] (a C-11 circle on media) at `size.global.buttonMarginH`, the light
 * [pill] (`collage.share.layout.pill`) at `size.global.buttonMarginH` from the trailing edge, centred
 * [recapRowCentre] above the screen bottom. Align it to the bottom of a full-screen box.
 */
@Composable
fun RecapBottomRow(leading: (@Composable () -> Unit)?, pill: RecapPill?, modifier: Modifier = Modifier) {
    Box(modifier.fillMaxWidth().height(recapRowCentre() * 2)) {
        if (leading != null) Box(Modifier.align(Alignment.CenterStart).padding(start = Tokens.Sizes.globalButtonMarginH)) { leading() }
        if (pill != null) RecapPillButton(pill, Modifier.align(Alignment.CenterEnd).padding(end = Tokens.Sizes.globalButtonMarginH))
    }
}
