// Navigation for the memory feature group (surface specs in design/surfaces/).
// Owned by the memory screens pass: add cases here and their screens below; RootView and AppRouter
// delegate to this file, so other groups never edit it.
//
// The memory screens on `AppRoute` (owned here, built in Features/Memory):
//   .birthdayRequest → BirthdayRequestScreen (birthday.request, full screen)
//   .tribute         → TributeScreen (birthday.tribute, full screen)
//   .yearStory       → YearStoryScreen (year.story, full screen)
// Entries for groups.screen: OnThisDayEntry and YearStoryEntry (feed cards, `MemoryEntryFeedCard`), BirthdayRequestsEntry
// (`MemoryEntryRequestRow`).
// For photo.viewer: the tag run (`TagRunControl`, or `TagRun` / `TagRunLine` + `TaggingSheet`; Tagging/TagRun.swift).
// For week.recap: the recap card (`RecapCard`, `RecapFooter`; Shared/RecapCard.swift) inside capture's `RecapPreviewScreen`.
import SwiftUI

/// Screens of the memory group pushed on the main navigation stack.
enum MemoryRoute: Hashable {
    /// `onthisday`: pushed on the group's stack (onthisday.md platform notes: system bar hidden, C-02 back chevron,
    /// interactive pop kept).
    case onThisDay(groupID: String)
    /// `birthday.add`: pushed from the settings "Birthday" row (settings.account pass).
    case birthdayAdd
}

/// Screens of the memory group presented over the navigation stack.
enum MemoryModal: Hashable {
    /// `birthday.contribute` (opened from `birthday.request` as a page sheet; this case is for links / UI tests).
    case birthdayContribute(requestID: String)
    /// `onthisday` presented full screen (kept for the shell's link handling; the entry pushes `MemoryRoute.onThisDay`).
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
