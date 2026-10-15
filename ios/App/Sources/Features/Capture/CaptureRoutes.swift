// Navigation for the capture feature group (surface specs in design/surfaces/).
// Owned by the capture screens pass: add cases here and their screens below; RootView and AppRouter
// delegate to this file, so other groups never edit it.
// The camera itself is `AppModal.camera(groupID:invitationID:)` → Screens/CameraScreen.swift
// (camera.capture, camera.fromwidget, daily.capture).
import SwiftUI

/// Screens of the capture group pushed on the main navigation stack.
enum CaptureRoute: Hashable {
    /// `collage.view` (with `collage.share`): the same-moment collage of one daily invitation.
    case collage(groupID: String, invitationID: String)
}

/// Screens of the capture group presented over the navigation stack.
enum CaptureModal: Hashable {
    /// `collage.share`: the collage presented on its own (e.g. from a notification), share pill included.
    case collageShare(groupID: String, invitationID: String)
}

struct CaptureDestination: View {
    let route: CaptureRoute

    var body: some View {
        switch route {
        case let .collage(groupID, invitationID):
            CollageScreen(groupID: groupID, invitationID: invitationID)
        }
    }
}

struct CaptureModalDestination: View {
    let modal: CaptureModal

    var body: some View {
        switch modal {
        case let .collageShare(groupID, invitationID):
            CollageScreen(groupID: groupID, invitationID: invitationID)
        }
    }
}
