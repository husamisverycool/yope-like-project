// Account group — copy that is BLOCKED until the owner names the app (`{app_name}`, config/app.json displayName,
// owner decision 0.1) or picks a value (`paywall.perk.history.emoji`).
//
// Release builds get nil and omit the element (docs/SCREENS_BRIEF.md rule 1: never substitute a value). DEBUG builds
// render the generated `BlockedCopy` text with the placeholder left visible, so layouts can be reviewed. When the owner
// names the app, `tools/designgen.mjs` moves these strings into `Copy` and only this file changes.
import DesignSystem
import Foundation

enum AccountBlockedCopy {
    #if DEBUG
    /// The unresolved placeholder itself, shown verbatim so the gap is visible in DEBUG builds.
    private static let appName = "{app_name}" // provenance-ok: BLOCKED placeholder rendered verbatim in DEBUG builds
    #endif

    /// `auth.agegate.underAge.title` ({min_age}, {app_name}).
    static func ageGateUnderAgeTitle(minAge: Int?) -> String? {
        #if DEBUG
        return BlockedCopy.authAgegateUnderAgeTitle(minAge: minAge.map(String.init) ?? "{min_age}", appName: appName) // provenance-ok: BLOCKED placeholder
        #else
        return nil
        #endif
    }

    /// `groups.invite.link.message` ({group_name}, {app_name}, {link}): the text shared with an invite link.
    static func inviteLinkMessage(groupName: String, link: String) -> String? {
        #if DEBUG
        return BlockedCopy.groupsInviteLinkMessage(groupName: groupName, appName: appName, link: link)
        #else
        return nil
        #endif
    }

    /// `onboarding.widget.step.ios.4` ({app_name}).
    static var widgetStepIOS4: String? {
        #if DEBUG
        return BlockedCopy.onboardingWidgetStepIos4(appName: appName)
        #else
        return nil
        #endif
    }

    /// `paywall.title` ({app_name}).
    static var paywallTitle: String? {
        #if DEBUG
        return BlockedCopy.paywallTitle(appName: appName)
        #else
        return nil
        #endif
    }

    /// `paywall.subtitle` ({app_name}).
    static var paywallSubtitle: String? {
        #if DEBUG
        return BlockedCopy.paywallSubtitle(appName: appName)
        #else
        return nil
        #endif
    }

    /// `paywall.cta` ({app_name}).
    static var paywallCTA: String? {
        #if DEBUG
        return BlockedCopy.paywallCta(appName: appName)
        #else
        return nil
        #endif
    }

    /// `paywall.legal.optional` ({app_name}).
    static var paywallLegalOptional: String? {
        #if DEBUG
        return BlockedCopy.paywallLegalOptional(appName: appName)
        #else
        return nil
        #endif
    }

    /// `paywall.plans.title` ({app_name}).
    static var paywallPlansTitle: String? {
        #if DEBUG
        return BlockedCopy.paywallPlansTitle(appName: appName)
        #else
        return nil
        #endif
    }

    /// `paywall.welcome.body` ({app_name}).
    static var paywallWelcomeBody: String? {
        #if DEBUG
        return BlockedCopy.paywallWelcomeBody(appName: appName)
        #else
        return nil
        #endif
    }

    /// `paywall.perk.history.emoji` (level BLOCKED: owner picks one emoji, or none).
    static var paywallHistoryEmoji: String? {
        #if DEBUG
        return BlockedCopy.paywallPerkHistoryEmoji(historyEmoji: "{history_emoji}") // provenance-ok: BLOCKED placeholder
        #else
        return nil
        #endif
    }

    /// `safety.report.explanation` ({app_name}).
    static var reportExplanation: String? {
        #if DEBUG
        return BlockedCopy.safetyReportExplanation(appName: appName)
        #else
        return nil
        #endif
    }

    /// `settings.notifications.off.footer` ({app_name}).
    static var notificationsOffFooter: String? {
        #if DEBUG
        return BlockedCopy.settingsNotificationsOffFooter(appName: appName)
        #else
        return nil
        #endif
    }

    /// `settings.root.premium.title` ({app_name}).
    static var premiumRowTitle: String? {
        #if DEBUG
        return BlockedCopy.settingsRootPremiumTitle(appName: appName)
        #else
        return nil
        #endif
    }

    /// `settings.root.premium.subtitle` ({app_name}).
    static var premiumRowSubtitle: String? {
        #if DEBUG
        return BlockedCopy.settingsRootPremiumSubtitle(appName: appName)
        #else
        return nil
        #endif
    }
}
