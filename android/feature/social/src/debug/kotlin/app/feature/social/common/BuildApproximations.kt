package app.feature.social.common

/**
 * Debug builds: elements whose spec value is BLOCKED show the development approximation design/BLOCKED.md
 * names (docs/SCREENS_BRIEF.md rule 1). The release source set turns them off.
 */
internal object BuildApproximations {
    const val ENABLED: Boolean = true

    /** `photo.viewer.layout.backZone` approximation: the leading third of the photo goes back (BLOCKED.md). */
    const val BACK_ZONE_FRACTION: Float = 1f / 3f // provenance-ok: BLOCKED development approximation (design/BLOCKED.md), debug builds only
}
