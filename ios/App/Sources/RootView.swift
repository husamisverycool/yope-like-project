import SwiftUI

/// The navigation shell: a stack driven by `AppRouter.path` and one modal slot.
/// Presentation styles are part of the screens pass (surface specs).
struct RootView: View {
    @Bindable var router: AppRouter

    var body: some View {
        NavigationStack(path: $router.path) {
            GroupsHomeScreen()
                .navigationDestination(for: AppRoute.self) { route in
                    RouteDestination(route: route)
                }
        }
        .fullScreenCover(item: $router.modal) { modal in
            ModalDestination(modal: modal)
        }
    }
}

struct RouteDestination: View {
    let route: AppRoute

    var body: some View {
        switch route {
        case let .group(id):
            GroupScreen(groupID: id)
        case let .post(groupID, postID):
            PhotoViewerScreen(groupID: groupID, postID: postID)
        case let .chat(groupID, messageID):
            ChatScreen(groupID: groupID, messageID: messageID)
        case let .recap(groupID, recapID):
            RecapScreen(groupID: groupID, recapID: recapID)
        case let .birthdayRequest(requestID, groupID):
            BirthdayRequestScreen(requestID: requestID, groupID: groupID)
        case let .tribute(tributeID, groupID):
            TributeScreen(tributeID: tributeID, groupID: groupID)
        case let .yearStory(groupID, year):
            YearStoryScreen(groupID: groupID, year: year)
        }
    }
}

struct ModalDestination: View {
    let modal: AppModal

    var body: some View {
        switch modal {
        case let .camera(groupID, invitationID):
            CameraScreen(groupID: groupID, invitationID: invitationID)
        case let .invite(token):
            InviteScreen(token: token)
        }
    }
}

/// Body of a screen container until the screens pass builds the surface: renders nothing
/// visible and carries the surface id as its accessibility identifier (for UI tests).
struct ScreenContainer: View {
    let surface: String

    var body: some View {
        Color.clear
            .accessibilityIdentifier(surface)
    }
}
