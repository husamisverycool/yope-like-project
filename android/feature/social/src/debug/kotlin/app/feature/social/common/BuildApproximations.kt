package app.feature.social.common

import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp

/**
 * Debug builds: elements whose spec value is BLOCKED show the development approximation design/BLOCKED.md
 * names (docs/SCREENS_BRIEF.md rule 1). The release source set turns them off.
 */
internal object BuildApproximations {
    const val ENABLED: Boolean = true

    /** `photo.viewer.layout.backZone` approximation: the leading third of the photo goes back (BLOCKED.md). */
    const val BACK_ZONE_FRACTION: Float = 1f / 3f // provenance-ok: BLOCKED development approximation (design/BLOCKED.md), debug builds only

    /** `week.edit.layout.selectionMark` approximation: the check circle's inset from the cell's top-right corner. */
    val SELECTION_MARK_INSET: Dp = 6.dp // provenance-ok: BLOCKED development approximation of week.edit.layout.selectionMark ("6 pt in", design/BLOCKED.md), debug builds only
}
