// Navigation for the capture feature group (surface specs in design/surfaces/).
// Owned by the capture screens pass: add cases here and their screens below; RootView and AppRouter
// delegate to this file, so other groups never edit it.
import SwiftUI

/// Screens of the capture group pushed on the main navigation stack.
enum CaptureRoute: Hashable {
    /// `collage.view`
    case collage(groupID: String, invitationID: String)
}

/// Screens of the capture group presented over the navigation stack.
enum CaptureModal: Hashable {
    /// `collage.share`
    case collageShare(groupID: String, invitationID: String)
}

struct CaptureDestination: View {
    let route: CaptureRoute

    var body: some View {
        switch route {
        case .collage:
            ScreenContainer(surface: "collage.view")
        }
    }
}

struct CaptureModalDestination: View {
    let modal: CaptureModal

    var body: some View {
        switch modal {
        case .collageShare:
            ScreenContainer(surface: "collage.share")
        }
    }
}
