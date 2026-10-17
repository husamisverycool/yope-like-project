package app.model

/**
 * The home-screen photo widgets' styles (design/surfaces/widget.styles.md; token `widget.styles.layout.styles`): Photo
 * (free, the widget as it has always been), Date and Frame (premium: the paywall's "Exclusive Widget Styles"). Every
 * photo widget (Group Updates, Friend Updates, Your Memories) records its style in its binding by [wire].
 */
enum class WidgetStyle(val wire: String, val isPremium: Boolean) {
    Photo("photo", isPremium = false),
    Date("date", isPremium = true),
    Frame("frame", isPremium = true);

    /** What the widget draws: a premium style without premium draws [Photo] (the free widget never stops working). */
    fun drawn(premium: Boolean): WidgetStyle = if (isLocked(premium)) Photo else this

    /** Chosen without premium: drawn as [Photo], and the widget's tap opens the paywall at the widgets perk first. */
    fun isLocked(premium: Boolean): Boolean = isPremium && !premium

    companion object {
        /** `widget.styles.layout.styles` default: photo. */
        val default: WidgetStyle = Photo

        fun fromWire(value: String?): WidgetStyle = entries.firstOrNull { it.wire == value } ?: default
    }
}
