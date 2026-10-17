// groups.screen — the order of the birthday request rows and the plans block (design/surfaces/plans.list.md "Entry on
// groups.screen"; MERGE FV-1): date order, soonest first, as Apple Invites' "Upcoming" leads with "your next event"
// (support.apple.com/guide/apple-invites/view-your-events-dev18a008ffb/ios). The group screen owns both entries' models,
// reads their days and lays the entries out in `GroupEntryOrder.order` with stable identities (a `ForEach`), so a change
// of order moves the rows instead of rebuilding them.
import AppData
import Foundation

/// The entries of groups.screen placed by date.
enum GroupEntrySlot: Hashable {
    /// The birthday request rows (birthday.request entry).
    case birthday
    /// The plans block (the "Plans" label and the plan row).
    case plans
}

/// An entry's day: the birthday being celebrated, or the next plan's day; nil = no date (the "Make a Plan" row).
struct GroupEntryDay: Equatable {
    let day: LocalDate?

    init(_ day: LocalDate?) {
        self.day = day
    }
}

enum GroupEntryOrder {
    /// The slots in their declared order (birthday rows, then plans), as shown before any day is known.
    static let declared: [GroupEntrySlot] = [.birthday, .plans]

    /// Soonest day first; an entry without a day after every dated one; the same day (or no days) keeps the declared
    /// order, so the birthday rows lead.
    static func order(_ days: [GroupEntrySlot: GroupEntryDay]) -> [GroupEntrySlot] {
        declared.enumerated().sorted { lhs, rhs in
            let left = days[lhs.element]?.day
            let right = days[rhs.element]?.day
            switch (left, right) {
            case let (left?, right?) where left != right:
                return left < right
            case (.some, nil):
                return true
            case (nil, .some):
                return false
            default:
                return lhs.offset < rhs.offset
            }
        }.map(\.element)
    }
}
