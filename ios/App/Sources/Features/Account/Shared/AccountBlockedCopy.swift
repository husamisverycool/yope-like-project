// Account group — copy that is BLOCKED until the owner names the app (`{app_name}`, config/app.json displayName,
// owner decision 0.1).
//
// Release builds get nil and omit the element (docs/SCREENS_BRIEF.md rule 1: never substitute a value). DEBUG builds
// render the generated `BlockedCopy` text with the placeholder left visible, so layouts can be reviewed. When the owner
// names the app, `tools/designgen.mjs` moves these strings into `Copy` and only this file changes. (`paywall.legal.optional`
// and `onboarding.widget.step.android.3` are Android-only.)
import DesignSystem
import Foundation

enum AccountBlockedCopy {
    #if DEBUG
    /// The unresolved placeholder itself, shown verbatim so the gap is visible in DEBUG builds.
    private static let appName = "{app_name}" // provenance-ok: BLOCKED placeholder rendered verbatim in DEBUG builds
    #endif

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

    /// `settings.root.premium.title` ({app_name}).
    static var premiumRowTitle: String? {
        #if DEBUG
        return BlockedCopy.settingsRootPremiumTitle(appName: appName)
        #else
        return nil
        #endif
    }
}
