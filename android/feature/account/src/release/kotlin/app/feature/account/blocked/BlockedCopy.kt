package app.feature.account.blocked

import android.content.Context

/**
 * Release builds: every BLOCKED string is absent, so the elements that use them are omitted (docs/SCREENS_BRIEF.md
 * rule 1). See the debug counterpart for the list and the reason.
 */
object BlockedCopy {
    const val available: Boolean = false

    fun appName(): String? = null
    fun inviteLinkMessage(context: Context, groupName: String, link: String): String? = null
    fun widgetStepAndroid3(context: Context): String? = null
    fun paywallTitle(context: Context): String? = null
    fun paywallLegalOptional(context: Context): String? = null
    fun premiumRowTitle(context: Context): String? = null
}
