package app.feature.account.blocked

import androidx.compose.ui.graphics.Color

/**
 * Every BLOCKED design value the account screens reference, behind one accessor each (BLOCKED copy
 * is in [BlockedCopy]). Each is null while the token is BLOCKED in `design/tokens/<group>.json` and the
 * element it styles is omitted; when research fills the token, `tools/designgen.mjs` emits it in
 * `Tokens` and the accessor becomes a one-line switch to that constant.
 */
object BlockedValues {
    /** `safety.report.layout.reasons`: the report reason list (omitted; the details field is the reason). */
    val reportReasons: List<String>? = null

    /** `paywall.layout.iconTileArt`: the paywall icon tile (omitted until the app icon exists). */
    val paywallIconTile: Boolean = false
}
