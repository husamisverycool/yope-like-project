package app.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.sizeIn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.RectangleShape
import androidx.compose.ui.graphics.Shape
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.TextStyle
import app.designsystem.generated.Tokens

/**
 * Yope's Loading HUD (V-mthu t50.60): a square box centred over the screen with the platform
 * spinner (`easing.global.native` activityIndicator) and a label.
 *
 * Tokens: fill `groups.create.color.hud`, side `groups.create.size.hud` (grows with large text),
 * label `groups.create.fontSize.hudLabel` in `color.global.textPrimary` (copy
 * `groups.create.hud.loading`). The HUD corner radius is not measured (groups.create Gaps), so the
 * default [shape] is square; a surface with a measured HUD radius passes its own shape. No scrim
 * (`color.global.scrim` BLOCKED). [HudOverlay] also blocks input underneath while it shows.
 */
@Composable
fun LoadingHud(label: String, modifier: Modifier = Modifier, shape: Shape = RectangleShape) {
    Column(
        modifier
            .sizeIn(minWidth = Tokens.Sizes.groupsCreateSizeHud, minHeight = Tokens.Sizes.groupsCreateSizeHud)
            .background(Tokens.Colors.groupsCreateColorHud, shape)
            .semantics { liveRegion = LiveRegionMode.Polite },
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.SpaceEvenly,
    ) {
        CircularProgressIndicator(color = Tokens.Colors.globalTextPrimary)
        Text(
            label,
            // Size only: the label's weight was not measured (platform default).
            style = TextStyle(fontSize = Tokens.FontSizes.groupsCreateFontSizeHudLabel),
            color = Tokens.Colors.globalTextPrimary,
            textAlign = TextAlign.Center,
        )
    }
}

/** [LoadingHud] centred over its parent, swallowing touches while [visible]. */
@Composable
fun HudOverlay(visible: Boolean, label: String, modifier: Modifier = Modifier) {
    if (!visible) return
    val interaction = remember { MutableInteractionSource() }
    Box(
        modifier.fillMaxSize().clickable(interactionSource = interaction, indication = null, onClick = {}),
        contentAlignment = Alignment.Center,
    ) {
        LoadingHud(label)
    }
}

/** A rounded HUD shape for surfaces that measured one (e.g. `collage.view.layout.hud` cornerRadius). */
fun hudShape(cornerRadius: androidx.compose.ui.unit.Dp): Shape = RoundedCornerShape(cornerRadius)
