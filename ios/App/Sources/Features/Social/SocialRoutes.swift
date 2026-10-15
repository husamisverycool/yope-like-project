// Navigation for the social feature group (surface specs in design/surfaces/).
// Owned by the social screens pass: add cases here and their screens below; RootView and AppRouter
// delegate to this file, so other groups never edit it.
import SwiftUI

/// Screens of the social group pushed on the main navigation stack.
enum SocialRoute: Hashable {
    /// `walls.mine`
    case wallMine
}

/// Screens of the social group presented over the navigation stack.
enum SocialModal: Hashable {
    /// `week.edit`
    case weekEdit(groupID: String, recapID: String)
}

struct SocialDestination: View {
    let route: SocialRoute

    var body: some View {
        switch route {
        case .wallMine:
            ScreenContainer(surface: "walls.mine")
        }
    }
}

struct SocialModalDestination: View {
    let modal: SocialModal

    var body: some View {
        switch modal {
        case .weekEdit:
            ScreenContainer(surface: "week.edit")
        }
    }
}
