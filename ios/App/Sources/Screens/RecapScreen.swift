// Surface: week.recap (one recap's preview) — Retro's recap preview (capture's chrome, memory's recap card).
// Reference images: listed in design/surfaces/week.recap.md (references/auto/retro/store/retro-store-04.png,
// references/auto/retro/press/tc-2023-12-recaps.png); built in Features/Social/UI/WeekRecapViews.swift with Tokens.* / Copy.*.
import SwiftUI

/// One weekly recap (`DeepLink.recap`, `week.history`'s "View recap"): the recap preview.
struct RecapScreen: View {
    let groupID: String
    let recapID: String

    var body: some View {
        WeekRecapPreviewScreen(groupID: groupID, recapID: recapID)
    }
}
