// Navigation for the memory feature group (surface specs in design/surfaces/).
// Owned by the memory screens pass: add cases here and their screens below; RootView and AppRouter
// delegate to this file, so other groups never edit it.
import SwiftUI

/// Screens of the memory group pushed on the main navigation stack.
enum MemoryRoute: Hashable {
    /// `onthisday`
    case onThisDay(groupID: String)
}

/// Screens of the memory group presented over the navigation stack.
enum MemoryModal: Hashable {
    /// `birthday.contribute`
    case birthdayContribute(requestID: String)
}

struct MemoryDestination: View {
    let route: MemoryRoute

    var body: some View {
        switch route {
        case .onThisDay:
            ScreenContainer(surface: "onthisday")
        }
    }
}

struct MemoryModalDestination: View {
    let modal: MemoryModal

    var body: some View {
        switch modal {
        case .birthdayContribute:
            ScreenContainer(surface: "birthday.contribute")
        }
    }
}
