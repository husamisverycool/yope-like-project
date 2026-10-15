// Navigation for the memory feature group (surface specs in design/surfaces/).
// Owned by the memory screens pass: add cases here and their screens below; RootView and AppRouter
// delegate to this file, so other groups never edit it.
//
// The memory screens on `AppRoute` (owned here, built in Features/Memory):
//   .birthdayRequest → BirthdayRequestScreen (birthday.request)
//   .tribute         → TributeScreen (birthday.tribute)
//   .yearStory       → YearStoryScreen (year.story)
// Entry rows for groups.screen: OnThisDayEntry, YearStoryEntry, BirthdayRequestsEntry.
// The "i'm in this" control for photo.viewer: SelfTagToggleControl / SelfTagToggle.
import SwiftUI

/// Screens of the memory group pushed on the main navigation stack.
enum MemoryRoute: Hashable {
    /// `onthisday` pushed (prefer `MemoryModal.onThisDay` / `OnThisDayEntry`: the day is full screen).
    case onThisDay(groupID: String)
    /// `birthday.add`: pushed from the settings "birthday" row (settings.account pass).
    case birthdayAdd
}

/// Screens of the memory group presented over the navigation stack (full screen).
enum MemoryModal: Hashable {
    /// `birthday.contribute`
    case birthdayContribute(requestID: String)
    /// `onthisday`, the day
    case onThisDay(groupID: String)
    /// `year.story`
    case yearStory(groupID: String, year: Int)
}

struct MemoryDestination: View {
    let route: MemoryRoute

    var body: some View {
        switch route {
        case let .onThisDay(groupID):
            OnThisDayScreen(groupID: groupID)
        case .birthdayAdd:
            BirthdayAddScreen()
        }
    }
}

struct MemoryModalDestination: View {
    let modal: MemoryModal

    var body: some View {
        switch modal {
        case let .birthdayContribute(requestID):
            BirthdayContributeScreen(requestID: requestID)
        case let .onThisDay(groupID):
            OnThisDayScreen(groupID: groupID)
        case let .yearStory(groupID, year):
            YearStoryScreen(groupID: groupID, year: year)
        }
    }
}
