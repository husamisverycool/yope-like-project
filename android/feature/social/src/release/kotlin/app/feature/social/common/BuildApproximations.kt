package app.feature.social.common

/** Release builds omit every element whose spec value is BLOCKED (docs/SCREENS_BRIEF.md rule 1). */
internal object BuildApproximations {
    const val ENABLED: Boolean = false

    /** `photo.viewer.layout.backZone` is BLOCKED: no back zone in release. */
    const val BACK_ZONE_FRACTION: Float = 0f
}
