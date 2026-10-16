package app.feature.social.common

import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp

/** Release builds omit every element whose spec value is BLOCKED (docs/SCREENS_BRIEF.md rule 1). */
internal object BuildApproximations {
    const val ENABLED: Boolean = false

    /** `photo.viewer.layout.backZone` is BLOCKED: no back zone in release. */
    const val BACK_ZONE_FRACTION: Float = 0f

    /** `week.edit.layout.selectionMark` approximation: the check circle's inset from the cell's top-right corner. */
    val SELECTION_MARK_INSET: Dp = 0.dp
}
