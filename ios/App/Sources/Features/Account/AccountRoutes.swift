// Navigation for the account feature group (surface specs in design/surfaces/).
// Owned by the account screens pass: add cases here and their screens below; RootView and AppRouter
// delegate to this file, so other groups never edit it.
import SwiftUI

/// Screens of the account group pushed on the main navigation stack.
enum AccountRoute: Hashable {
    /// `settings.root`
    case settings
}

/// Screens of the account group presented over the navigation stack.
enum AccountModal: Hashable {
    /// `paywall`
    case paywall
}

struct AccountDestination: View {
    let route: AccountRoute

    var body: some View {
        switch route {
        case .settings:
            ScreenContainer(surface: "settings.root")
        }
    }
}

struct AccountModalDestination: View {
    let modal: AccountModal

    var body: some View {
        switch modal {
        case .paywall:
            ScreenContainer(surface: "paywall")
        }
    }
}
