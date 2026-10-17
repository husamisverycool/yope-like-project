// Navigation for the plans feature group (surface specs design/surfaces/plans.create.md, plans.page.md).
// Owned by the plans pass: add cases here and their screens below; RootView and AppRouter delegate to this file.
// Entry points other groups use:
//   plans.page    .plans(.page(planID:groupID:))       (groups.screen plan row, `DeepLink.plan`, pushes `notifications.push.plan*`)
//   plans.list    .plans(.list(groupID:))              (groups.screen plans block header)
//   plans.create  AppModal.plans(.create(groupID:))    (the plan row's "+", a page sheet — C-29)
import SwiftUI

/// Screens of the plans group pushed on the main navigation stack.
enum PlanRoute: Hashable {
    /// `plans.page`
    case page(planID: String, groupID: String?)
    /// `plans.list`: every plan of the group.
    case list(groupID: String)
}

/// Screens of the plans group presented over the navigation stack.
enum PlanModal: Hashable {
    /// `plans.create` (create mode) for a group.
    case create(groupID: String)

    /// plans.create: a page sheet (C-29, `spring.global.sheetPresent`).
    var presentsAsSheet: Bool { true }
}

struct PlansDestination: View {
    let route: PlanRoute

    var body: some View {
        switch route {
        case let .page(planID, groupID):
            PlanPageScreen(planID: planID, groupID: groupID)
        case let .list(groupID):
            PlansListScreen(groupID: groupID)
        }
    }
}

struct PlansModalDestination: View {
    let modal: PlanModal

    var body: some View {
        switch modal {
        case let .create(groupID):
            PlanCreateScreen(groupID: groupID, editing: nil)
        }
    }
}
