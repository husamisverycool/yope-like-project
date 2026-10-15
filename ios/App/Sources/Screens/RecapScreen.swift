// Surface: week.recap — reference app: Yope recaps (organized by week per Retro).
// Reference images: listed in design/surfaces/week.recap.md (docs/SURFACES.md); built in
// Features/Social/UI/WeekViews.swift with Tokens.* / Copy.*.
import SwiftUI

/// Sunday recap of the group's week.
struct RecapScreen: View {
    let groupID: String
    let recapID: String

    var body: some View {
        WeekRecapView(groupID: groupID, recapID: recapID)
    }
}
