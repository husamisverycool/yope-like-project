package app.feature.social.common

/**
 * Debug builds: elements whose spec value is BLOCKED are shown with the review approximation the
 * spec allows for development builds (docs/SCREENS_BRIEF.md rule 1). The release source set sets
 * this to false, so release builds omit them.
 */
internal object BuildApproximations {
    const val ENABLED: Boolean = true
}
