package app.feature.account.blocked

import android.content.Context
import app.designsystem.R

/**
 * DEBUG builds only: BLOCKED strings (`strings_blocked.xml`, generated in core:designsystem's debug source set) so their
 * layouts can be reviewed. They are BLOCKED because they contain `{app_name}` (config/app.json `displayName` is not set;
 * MERGE RA-22). `{app_name}` itself has no value, so it is shown as the literal placeholder. The release counterpart
 * returns null for every one and the element is omitted. When the owner sets the name, designgen moves these strings into
 * the main `strings.xml` without the `app_name` argument: replace the call sites with `R.string.*` then.
 */
object BlockedCopy {
    private const val APP_NAME = "{app_name}"

    const val available: Boolean = true

    /** The app's name itself (auth.phone landing wordmark) while `displayName` is BLOCKED. */
    fun appName(): String? = APP_NAME
    fun inviteLinkMessage(context: Context, groupName: String, link: String): String? = context.getString(R.string.groups_invite_link_message, groupName, APP_NAME, link)
    fun widgetStepAndroid3(context: Context): String? = context.getString(R.string.onboarding_widget_step_android_3, APP_NAME)
    fun paywallTitle(context: Context): String? = context.getString(R.string.paywall_title, APP_NAME)
    fun paywallLegalOptional(context: Context): String? = context.getString(R.string.paywall_legal_optional, APP_NAME)
    fun premiumRowTitle(context: Context): String? = context.getString(R.string.settings_root_premium_title, APP_NAME)
}
