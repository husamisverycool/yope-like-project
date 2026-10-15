package app.feature.account.blocked

import android.content.Context
import app.designsystem.R

/**
 * DEBUG builds only: BLOCKED strings (`strings_blocked.xml`, generated in core:designsystem's debug
 * source set) so their layouts can be reviewed. They are BLOCKED because they contain `{app_name}`
 * (config/app.json `displayName` is not set) or a BLOCKED value. `{app_name}` itself has no value, so
 * it is shown as the literal placeholder. The release counterpart returns null for every one and the
 * element is omitted. When the owner sets the name, designgen moves these strings into the main
 * `strings.xml` without the `app_name` argument: replace the call sites with `R.string.*` then.
 */
object BlockedCopy {
    private const val APP_NAME = "{app_name}"

    const val available: Boolean = true

    fun ageGateUnderAgeTitle(context: Context, minAge: String): String? = context.getString(R.string.auth_agegate_underage_title, minAge, APP_NAME)
    fun inviteLinkMessage(context: Context, groupName: String, link: String): String? = context.getString(R.string.groups_invite_link_message, groupName, APP_NAME, link)
    fun widgetStepAndroid3(context: Context): String? = context.getString(R.string.onboarding_widget_step_android_3, APP_NAME)
    fun paywallTitle(context: Context): String? = context.getString(R.string.paywall_title, APP_NAME)
    fun paywallSubtitle(context: Context): String? = context.getString(R.string.paywall_subtitle, APP_NAME)
    fun paywallCta(context: Context): String? = context.getString(R.string.paywall_cta, APP_NAME)
    fun paywallLegalOptional(context: Context): String? = context.getString(R.string.paywall_legal_optional, APP_NAME)
    fun paywallPlansTitle(context: Context): String? = context.getString(R.string.paywall_plans_title, APP_NAME)
    fun paywallWelcomeBody(context: Context): String? = context.getString(R.string.paywall_welcome_body, APP_NAME)

    /** `paywall.perk.history.emoji` is BLOCKED itself (no sourced emoji): no value even in debug. */
    fun paywallHistoryEmoji(context: Context): String? = null

    fun reportExplanation(context: Context): String? = context.getString(R.string.safety_report_explanation, APP_NAME)
    fun notificationsOffFooter(context: Context): String? = context.getString(R.string.settings_notifications_off_footer, APP_NAME)
    fun premiumRowTitle(context: Context): String? = context.getString(R.string.settings_root_premium_title, APP_NAME)
    fun premiumRowSubtitle(context: Context): String? = context.getString(R.string.settings_root_premium_subtitle, APP_NAME)
    fun rationaleCameraMessage(context: Context): String? = context.getString(R.string.system_permissions_rationale_camera_message, APP_NAME)
    fun rationaleContactsMessage(context: Context): String? = context.getString(R.string.system_permissions_rationale_contacts_message, APP_NAME)
    fun rationaleMicrophoneMessage(context: Context): String? = context.getString(R.string.system_permissions_rationale_microphone_message, APP_NAME)
    fun rationaleNotificationsMessage(context: Context): String? = context.getString(R.string.system_permissions_rationale_notifications_message, APP_NAME)
}
