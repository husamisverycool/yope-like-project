// Entry rows the account pass places on `groups.screen` for the memory surfaces
// (onthisday, year.story, birthday.request). The memory group supplies what a row says and what
// a tap opens; the row component, its position and tokens belong to the groups.screen pass
// (design/surfaces/onthisday.md "Entry", year.story.md "Entry", birthday.request.md "Entry").
import DesignSystem
import SwiftUI

/// What an entry row says.
struct MemoryEntryContent: Equatable {
    /// `onthisday.entry.title` / `year.story.entry.title` / `birthday.request.title`.
    let title: String
    /// `onthisday.banner.yearsAgo.*` / `year.story.entry.subtitle` / `birthday.request.due`.
    let subtitle: String
    /// `year.story.entry.button` ("Let's go"); nil for the other rows.
    var buttonTitle: String? = nil
}

/// The default row: the title and subtitle in the global list text roles (`listTitle`,
/// `listSubtitle`), no fill or decoration — pass your own row view to the entry instead to style it.
struct MemoryEntryPlainRow: View {
    let content: MemoryEntryContent

    var body: some View {
        VStack(alignment: .leading) {
            Text(content.title)
                .dsTextStyle(MemoryType.listTitle)
                .foregroundStyle(Tokens.Colors.globalTextPrimary)
            Text(content.subtitle)
                .dsTextStyle(MemoryType.listSubtitle)
                .foregroundStyle(Tokens.Colors.globalTextSecondary)
            if let buttonTitle = content.buttonTitle {
                Text(buttonTitle)
                    .dsTextStyle(MemoryType.button)
                    .foregroundStyle(Tokens.Colors.globalTextPrimary)
            }
        }
        .frame(maxWidth: .infinity, minHeight: Tokens.Sizes.globalMinTouchTargetIos, alignment: .leading)
        .contentShape(Rectangle())
    }
}
