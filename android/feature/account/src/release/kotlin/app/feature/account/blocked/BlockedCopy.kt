package app.feature.account.blocked

import android.content.Context

/**
 * Release builds: every BLOCKED string is absent, so the elements that use them are omitted
 * (docs/SCREENS_BRIEF.md rule 1). See the debug counterpart for the list and the reason.
 */
object BlockedCopy {
    const val available: Boolean = false

    fun ageGateUnderAgeTitle(context: Context, minAge: String): String? = null
    fun inviteLinkMessage(context: Context, groupName: String, link: String): String? = null
    fun widgetStepAndroid3(context: Context): String? = null
    fun paywallTitle(context: Context): String? = null
    fun paywallSubtitle(context: Context): String? = null
    fun paywallCta(context: Context): String? = null
    fun paywallLegalOptional(context: Context): String? = null
    fun paywallPlansTitle(context: Context): String? = null
    fun paywallWelcomeBody(context: Context): String? = null
    fun paywallHistoryEmoji(context: Context): String? = null
    fun reportExplanation(context: Context): String? = null
    fun notificationsOffFooter(context: Context): String? = null
    fun premiumRowTitle(context: Context): String? = null
    fun premiumRowSubtitle(context: Context): String? = null
    fun rationaleCameraMessage(context: Context): String? = null
    fun rationaleContactsMessage(context: Context): String? = null
    fun rationaleMicrophoneMessage(context: Context): String? = null
    fun rationaleNotificationsMessage(context: Context): String? = null
}
