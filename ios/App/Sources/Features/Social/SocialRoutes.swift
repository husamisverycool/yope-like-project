// Navigation for the social feature group (surface specs in design/surfaces/).
// Owned by the social screens pass: add cases here and their screens below; RootView and AppRouter
// delegate to this file, so other groups never edit it.
//
// The `AppRoute` cases `.chat`, `.post` and `.recap` (Screens/ChatScreen, PhotoViewerScreen, RecapScreen) are
// social surfaces too. Entry points other groups use:
//   walls.mine    .social(.wallMine)                         (tab bar "me")
//   walls.browse  .social(.wallsBrowse(groupID: nil))        (tab bar "walls"; groupID = groups.screen "wall" segment)
//   walls.member  .social(.wallMember(userID:))              (groups.settings member row)
//   week.history  .social(.weekHistory(groupID:))            (group header calendar circle, profile "recaps")
//   albums.list   .social(.albums(groupID:))                 (groups.screen albums entry)
//   week.edit     .social(.weekEdit(groupID:recapID:))       (modal; normally opened from week.recap's pencil)
import AppData
import SwiftUI

/// Screens of the social group pushed on the main navigation stack.
enum SocialRoute: Hashable {
    /// `walls.mine`
    case wallMine
    /// `walls.member`
    case wallMember(userID: String)
    /// `walls.browse`; with a group id, only that group's members (groups.screen profile "wall" segment).
    case wallsBrowse(groupID: String?)
    /// `week.history`
    case weekHistory(groupID: String)
    /// `albums.list`
    case albums(groupID: String)
    /// `albums.view`
    case album(groupID: String, albumID: String)
}

/// Screens of the social group presented over the navigation stack.
enum SocialModal: Hashable {
    /// `week.edit` (recap editor).
    case weekEdit(groupID: String, recapID: String)
    /// `week.edit`'s album sheet with one week's photos checked (`week.history` "Save as album").
    case albumFromWeek(groupID: String, weekStart: String)
}

struct SocialDestination: View {
    let route: SocialRoute

    var body: some View {
        switch route {
        case .wallMine:
            WallMineScreen()
        case let .wallMember(userID):
            WallMemberScreen(userID: userID)
        case let .wallsBrowse(groupID):
            WallsBrowseScreen(groupID: groupID)
        case let .weekHistory(groupID):
            WeekHistoryScreen(groupID: groupID)
        case let .albums(groupID):
            AlbumsListScreen(groupID: groupID)
        case let .album(groupID, albumID):
            AlbumScreen(groupID: groupID, albumID: albumID)
        }
    }
}

struct SocialModalDestination: View {
    let modal: SocialModal

    var body: some View {
        switch modal {
        case let .weekEdit(groupID, recapID):
            WeekEditScreen(groupID: groupID, mode: .recap(RecapID(recapID)))
        case let .albumFromWeek(groupID, weekStart):
            if let date = LocalDate(weekStart) {
                WeekEditScreen(groupID: groupID, mode: .album(weekStart: date))
            }
        }
    }
}
