package app.feature.account.blocked

import androidx.compose.ui.graphics.Color

/**
 * Every BLOCKED design value the account screens reference, behind one accessor each (BLOCKED copy
 * is in [BlockedCopy]). Each is null while the token is BLOCKED in `design/tokens/<group>.json` and the
 * element it styles is omitted; when research fills the token, `tools/designgen.mjs` emits it in
 * `Tokens` and the accessor becomes a one-line switch to that constant.
 */
object BlockedValues {
    /** `groups.list.color.headerCircleOverPhoto`: the "+" circle over the cover photo (omitted while null). */
    val groupsListHeaderCircleOverPhoto: Color? = null

    /**
     * `auth.phone.layout.inlineError`: how auth.*, groups.create and safety errors are presented. While
     * BLOCKED the error is kept in each screen's state (and plays `haptic.global.error`) but not drawn.
     */
    val inlineErrorPresentation: Boolean = false

    /** `auth.phone.layout.countryCode`: the country-code selector (omitted; the field takes "+" and the code as text). */
    val countryCodeSelector: Boolean = false

    /** `safety.report.layout.reasons`: the report reason list (omitted; the details field is the reason). */
    val reportReasons: List<String>? = null

    /** `paywall.layout.iconTileArt`: the paywall icon tile (omitted until the app icon exists). */
    val paywallIconTile: Boolean = false
}
