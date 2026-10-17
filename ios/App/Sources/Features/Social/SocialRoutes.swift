// Navigation for the social feature group (surface specs in design/surfaces/).
// Owned by the social screens pass: add cases here and their screens below; RootView and AppRouter
// delegate to this file, so other groups never edit it.
//
// The `AppRoute` cases `.chat`, `.post` and `.recap` (Screens/ChatScreen, PhotoViewerScreen; `.recap` is built by the shell's RouteDestination) are
// social surfaces too (`.recap` = one recap's preview). Entry points other groups use:
//   walls.mine    .social(.wallMine)                         (profile tab)
//   walls.browse  .social(.wallsBrowse(groupID: nil))        (Friends tab; with a group id: that group's members)
//   walls.member  .social(.wallMember(userID:))              (groups.settings member row)
//   week.history  .social(.weekHistory(groupID:))            (groups.screen: the group's weeks)
//   albums.list   .social(.albums(groupID:))                 (groups.screen albums entry)
//   search.photos .social(.search(groupID:))                 (groups.list search glyph: nil = all groups; groups.screen: that group)
//   week.recap    AppModal.social(.recaps(groupID:))         (groups.screen recaps entry → the recap list, a page sheet;
//                                                             label `week.recap.open`)
//   week.edit     .social(.weekEdit(groupID:recapID:))       (modal; normally opened from week.recap's thumbnail)
// `SocialModal.presentsAsSheet` says which modals the specs present as page sheets (the shell's
// `AppModal.presentation` decides — account group).
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
    /// `search.photos`: in one group (groups.screen) or, nil, all your groups (groups.list).
    case search(groupID: String?)
    /// `collage.view` by the collage's id (a widget showing the group's collage of the day): resolves its invitation,
    /// then shows capture's collage screen.
    case collage(groupID: String, collageID: String)
}

/// Screens of the social group presented over the navigation stack.
enum SocialModal: Hashable {
    /// `week.recap` list (`week.recap.layout.list`).
    case recaps(groupID: String)
    /// `week.edit` (recap editor).
    case weekEdit(groupID: String, recapID: String)
    /// `week.edit`'s album sheet with one week's photos selected (`week.history` "Save as Album").
    case albumFromWeek(groupID: String, weekStart: String)

    /// The specs present all three as page sheets (C-29): `week.recap.layout.list.presentation`,
    /// `week.edit.layout.composition.presentation`, week.edit "Album sheet".
    var presentsAsSheet: Bool { true }
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
        case let .collage(groupID, collageID):
            CollageLinkScreen(groupID: groupID, collageID: CollageID(collageID))
        case let .search(groupID):
            SearchPhotosScreen(groupID: groupID)
        }
    }
}

struct SocialModalDestination: View {
    let modal: SocialModal

    var body: some View {
        switch modal {
        case let .recaps(groupID):
            WeekRecapListScreen(groupID: groupID)
        case let .weekEdit(groupID, recapID):
            WeekEditScreen(groupID: groupID, mode: .recap(RecapID(recapID)))
        case let .albumFromWeek(groupID, weekStart):
            if let date = LocalDate(weekStart) {
                WeekEditScreen(groupID: groupID, mode: .album(weekStart: date))
            }
        }
    }
}

/// `week.edit` presented as an app modal (`SocialModal`), outside `week.recap` / `week.history`: it hosts its
/// own confirmations (C-26), the way those screens do for the sheet they present.
struct WeekEditScreen: View {
    let groupID: String
    let mode: WeekEditModel.Mode
    @State private var toasts = ToastCenter()

    var body: some View {
        WeekEditView(groupID: GroupID(groupID), mode: mode, toasts: toasts)
            .toastHost(toasts)
    }
}
