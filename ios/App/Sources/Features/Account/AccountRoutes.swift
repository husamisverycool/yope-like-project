// Navigation for the account feature group (surface specs in design/surfaces/).
// Owned by the account screens pass: add cases here and their screens below; RootView and AppRouter
// delegate to this file, so other groups never edit it.
import SwiftUI

/// Screens of the account group pushed on the main navigation stack.
enum AccountRoute: Hashable {
    /// `settings.root` (opened from `walls.mine`'s settings circle).
    case settings
    /// `settings.notifications`
    case settingsNotifications
    /// `settings.account`
    case settingsAccount
    /// `settings.blocked`
    case settingsBlocked
    /// `groups.screen` B — the group's profile page (tap on the header capsule).
    case groupProfile(groupID: String)
    /// `groups.settings`
    case groupSettings(groupID: String)
}

/// Screens of the account group presented over the navigation stack.
enum AccountModal: Hashable {
    /// `paywall` (full screen). Locked features open it through `AppRouter.presentPaywallForLockedFeature`.
    case paywall
    /// `groups.create` (sheet, large detent).
    case groupCreate
    /// `groups.create` in edit mode (from `groups.settings`, admins).
    case groupEdit(groupID: String)
    /// `groups.invite` (sheet).
    case groupInvite(groupID: String)
    /// `safety.report` (sheet, medium / large detents). Other surfaces (photo.viewer, chat.thread, walls.member)
    /// present it with `router.modal = .account(.report(…))`.
    case report(ReportTarget)

    var presentsAsSheet: Bool {
        switch self {
        case .paywall: return false
        case .groupCreate, .groupEdit, .groupInvite, .report: return true
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
    }

    let kind: Kind
    /// The post / message / user / group id.
    let id: String
    /// `{first_name}` (user) or `{group_name}` (group) in the title; unused for posts and messages.
    var name: String?
    /// The person behind the content (post / message author, or the user): offered "Block" after reporting.
    var person: BlockTarget?
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
        case .settingsBlocked:
            SettingsBlockedScreen()
        case let .groupProfile(groupID):
            GroupProfileScreen(groupID: groupID)
        case let .groupSettings(groupID):
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
        case let .groupEdit(groupID):
            GroupCreateScreen(editingGroupID: groupID)
        case let .groupInvite(groupID):
            GroupInviteScreen(groupID: groupID)
        case let .report(target):
            ReportSheet(target: target)
        }
    }
}

/// Destinations owned by other feature groups that account screens open. A case the owning pass has not added to
/// its route enum yet resolves to nil, and the account control that leads there does nothing until it is wired
/// (reported to the lead).
enum CrossGroupRoutes {
    /// `walls.browse` (tab bar "walls"; `groups.screen` profile "wall" segment scoped to a group).
    static func wallsBrowse(groupID: String?) -> AppRoute? { .social(.wallsBrowse(groupID: groupID)) }
    /// `walls.mine` (tab bar "me").
    static var wallsMine: AppRoute? { .social(.wallMine) }
    /// `walls.member` (member row in groups.settings).
    static func wallMember(userID: String) -> AppRoute? { .social(.wallMember(userID: userID)) }
    /// `week.history` (group header calendar circle, profile "recaps" segment).
    static func weekHistory(groupID: String) -> AppRoute? { .social(.weekHistory(groupID: groupID)) }
    /// `birthday.add` (settings.account "birthday" row, birthday.add.md B). Built by `RouteDestination` with the
    /// "birthday added" toast.
    static var birthdayAdd: AppRoute? { .memory(.birthdayAdd) }
}
