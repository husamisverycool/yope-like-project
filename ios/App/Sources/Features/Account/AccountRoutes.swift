// Navigation for the account feature group (surface specs in design/surfaces/).
// Owned by the account screens pass: add cases here and their screens below; RootView and AppRouter
// delegate to this file, so other groups never edit it.
import AppData
import SwiftUI

/// Screens of the account group on the main navigation stack. `settings` and `groupSettings` are page sheets with their
/// own navigation (`settings.root.layout.list.sheet`): a push of either is presented as a sheet by the shell
/// (`PresentedRoute`); the settings sub-pages push inside those sheets.
enum AccountRoute: Hashable {
    /// `settings.root` (opened from `walls.mine`'s settings capsule) — a sheet.
    case settings
    /// `settings.notifications`
    case settingsNotifications
    /// `settings.account`
    case settingsAccount
    /// `settings.account` → Edit Full Name.
    case settingsName
    /// `settings.blocked`
    case settingsBlocked
    /// `settings.hidden` (Hidden Memories: the photos and days you hid from your memories).
    case settingsHidden
    /// `onboarding.widget` opened from settings.root → Widgets.
    case settingsWidgets
    /// The Yope-era group profile page, gone in the redesign (MERGE RA-9): chat.thread's header still opens it; it shows
    /// groups.settings (members first) as a sheet.
    case groupProfile(groupID: String)
    /// `groups.settings` — a sheet.
    case groupSettings(groupID: String)
}

/// Screens of the account group presented over the navigation stack.
enum AccountModal: Hashable {
    /// `paywall` (full screen). Locked features open it through `AppRouter.presentPaywallForLockedFeature`.
    case paywall
    /// `groups.create` from step A (sheet, large detent).
    case groupCreate
    /// `groups.create` at step B with the kind chosen on a groups.list template row.
    case groupCreateKind(GroupKind)
    /// `groups.create` in edit mode (from `groups.settings`, admins).
    case groupEdit(groupID: String)
    /// `groups.invite` (sheet).
    case groupInvite(groupID: String)
    /// `safety.report`: native action sheets over the current screen (`safety.report.layout.flow`). Other surfaces
    /// (photo.viewer, chat.thread, walls.member) present it with `router.modal = .account(.report(…))`.
    case report(ReportTarget)

    /// Sheet or full screen when the shell presents it (`AppModal.presentation`; `.report` is shown as action sheets).
    var presentsAsSheet: Bool {
        switch self {
        case .paywall, .report: return false
        case .groupCreate, .groupCreateKind, .groupEdit, .groupInvite: return true
        }
    }
}

/// What is being reported (`report(p_target_kind, p_target_id, p_reason)`).
struct ReportTarget: Hashable, Identifiable {
    enum Kind: String, Hashable {
        case post
        case message
        case user
        case group
        /// A selfie reaction (`report('selfie', <selfie_reactions.id>, reason)`, viewer.selfiereaction).
        case selfie
        /// Another member's plan (`plans.id`, plans.page).
        case plan
        /// A birthday video (`tributes.id`, birthday.tribute).
        case tribute
        /// A group's year story (`year_stories.id`, year.story).
        case yearStory = "year_story"
        /// A same-moment collage (`collages.id`, collage.view).
        case collage
        /// A weekly recap (`weekly_recaps.id`, week.recap).
        case recap
    }

    let kind: Kind
    /// The post / message / user / group id.
    let id: String
    /// The person's first name (user) or the group's name (group); Retro's report titles no longer show it.
    var name: String?
    /// The person behind the content (post / message author, or the user): "Block {first_name}" in the next steps.
    var person: BlockTarget?
    /// The group the content is in (and the group itself for `.group`): "Leave the group" in the next steps.
    var groupID: String?
    /// `{group_name}` of the leave alert.
    var groupName: String?
}

extension AppRouter {
    /// The paywall entry for a locked feature (video, widget styles, weeks beyond the free window, full-quality
    /// export): opens it at most once per session, never during capture or onboarding (`SessionPromptGate`), and
    /// never for premium members. Returns true when it was opened; otherwise the control keeps showing its
    /// "Premium" badge (`paywall.layout.promptRule`).
    /// The camera tab is left first (the prompt never shows over capture).
    @discardableResult
    func presentPaywallForLockedFeature(isPremium: Bool) -> Bool {
        guard !isPremium, consumePremiumPrompt() else { return false }
        ShellState.active?.leaveCamera()
        modal = .account(.paywall)
        return true
    }
}

struct AccountDestination: View {
    let route: AccountRoute

    var body: some View {
        switch route {
        case .settings:
            SettingsRootScreen()
        case .settingsNotifications:
            SettingsNotificationsScreen()
        case .settingsAccount:
            SettingsAccountScreen()
        case .settingsName:
            SettingsNameScreen()
        case .settingsBlocked:
            SettingsBlockedScreen()
        case .settingsHidden:
            SettingsHiddenScreen()
        case .settingsWidgets:
            SettingsWidgetsPage()
        case let .groupProfile(groupID), let .groupSettings(groupID):
            GroupSettingsScreen(groupID: groupID)
        }
    }
}

struct AccountModalDestination: View {
    let modal: AccountModal

    var body: some View {
        switch modal {
        case .paywall:
            PaywallScreen()
        case .groupCreate:
            GroupCreateScreen(editingGroupID: nil)
        case let .groupCreateKind(kind):
            GroupCreateScreen(editingGroupID: nil, kind: kind)
        case let .groupEdit(groupID):
            GroupCreateScreen(editingGroupID: groupID)
        case let .groupInvite(groupID):
            GroupInviteScreen(groupID: groupID)
        case let .report(target):
            // Shown by the shell as native action sheets (`reportFlow`); a surface that hosts this destination in its
            // own sheet gets the same flow in sheet form.
            ReportSheet(target: target)
        }
    }
}

/// Destinations owned by other feature groups that account screens open. A case the owning pass has not added to
/// its route enum yet resolves to nil, and the account control that leads there does nothing until it is wired
/// (reported to the lead).
enum CrossGroupRoutes {
    /// `walls.browse` (tab bar "walls").
    static func wallsBrowse(groupID: String?) -> AppRoute? { .social(.wallsBrowse(groupID: groupID)) }
    /// `walls.mine` (tab bar "me").
    static var wallsMine: AppRoute? { .social(.wallMine) }
    /// `walls.member` (a member row in groups.settings, pushed inside its sheet).
    static func wallMember(userID: String) -> AppRoute? { .social(.wallMember(userID: userID)) }
    /// `week.history` (groups.screen week header, the "Recaps" capsule when there is no recap yet).
    static func weekHistory(groupID: String) -> AppRoute? { .social(.weekHistory(groupID: groupID)) }
    /// `birthday.add` (settings.account "Birthday" row, pushed inside the Settings sheet; birthday.add.md B). Built by
    /// `RouteDestination` with the "birthday added" confirmation.
    static var birthdayAdd: AppRoute? { .memory(.birthdayAdd) }
}
