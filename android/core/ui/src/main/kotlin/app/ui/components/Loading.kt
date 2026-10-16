package app.ui.components

import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.semantics
import app.ui.foundation.PageRoles

/*
 * C-28 Loading states. Retro shows no skeleton screens; its loading forms are C-17 placeholder tiles
 * ([DayTile.Placeholder]) where photos will appear, a progress line as a toast ([PlatformToast], copy
 * `retro.voice.progress`: "Updating…"), and the platform activity indicator below. Loaded content fades in
 * with `duration.global.fade` (`app.ui.foundation.FadeVisibility`).
 */

/**
 * C-28 activity indicator: the platform's `CircularProgressIndicator` (`easing.global.native.activityIndicator`,
 * PLATFORM; Retro's own spinner not captured — Gap) in secondary text (on media `color.global.textSecondary`), or
 * [color] where a surface spec names another token (the paywall's plan card: `paywall.color.planTextTertiary`).
 * Announced politely with [contentDescription] (copy, "Loading").
 */
@Composable
fun ActivityIndicator(contentDescription: String?, modifier: Modifier = Modifier, onMedia: Boolean = false, color: Color? = null) {
    CircularProgressIndicator(
        color = color ?: PageRoles.secondaryText(onMedia),
        modifier = modifier.semantics {
            liveRegion = LiveRegionMode.Polite
            if (contentDescription != null) this.contentDescription = contentDescription
        },
    )
}

/** C-28 loading state of a whole area: the [ActivityIndicator] centred in the space it is given. */
@Composable
fun LoadingState(contentDescription: String?, modifier: Modifier = Modifier, onMedia: Boolean = false) {
    Box(modifier.fillMaxSize(), contentAlignment = Alignment.Center) { ActivityIndicator(contentDescription, onMedia = onMedia) }
}

/**
 * C-28 busy overlay (a save, a send): while [visible], the [ActivityIndicator] centred over its parent and
 * touches underneath swallowed. No box or scrim behind it (Retro shows the platform indicator on the page).
 */
@Composable
fun BusyOverlay(visible: Boolean, contentDescription: String?, modifier: Modifier = Modifier) {
    if (!visible) return
    val interaction = remember { MutableInteractionSource() }
    Box(
        modifier.fillMaxSize().clickable(interactionSource = interaction, indication = null, onClick = {}),
        contentAlignment = Alignment.Center,
    ) {
        ActivityIndicator(contentDescription)
    }
}
