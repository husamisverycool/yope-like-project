// Surface: year.story — the group-screen entry (A in design/surfaces/year.story.md; placed by groups.screen item 8).
import AppData
import DesignSystem
import SwiftUI

/// The "Year in Photos" feed cards for `groups.screen` (`year.story.entry.title`, `.entry.subtitle` "{year} Recap",
/// `.entry.button` "View memories", `icon.global.recap`, the story's cover): one per ready year story, newest first, side
/// by side in the feed pager (`size.global.cardGap` apart, as the pager's own cards).
///
/// A story appears once it is ready (from December 1) and stays for good (owner decision 31); a tap opens
/// `YearStoryScreen` full screen for that year. The look defaults to `MemoryEntryFeedCard` (groups.screen item 8); pass
/// your own row to restyle it:
///
///     YearStoryEntry(groupID: group.id) { content in MyCard(content) }
///
/// While there is no ready story it is an empty zero-size stack; it refreshes when it appears.
@MainActor
struct YearStoryEntry<Row: View>: View {
    @State private var model: YearStoryEntryModel
    @State private var presented: PresentedYear?
    private let row: (MemoryEntryContent) -> Row
    private let groupID: String

    init(groupID: String, model: YearStoryEntryModel? = nil, @ViewBuilder row: @escaping (MemoryEntryContent) -> Row) {
        self.groupID = groupID
        _model = State(initialValue: model ?? YearStoryEntryModel(groupID: GroupID(groupID), dependencies: .current))
        self.row = row
    }

    var body: some View {
        HStack(alignment: .top, spacing: Tokens.Sizes.globalCardGap) {
            ForEach(model.entries) { entry in
                Button {
                    presented = PresentedYear(year: entry.year)
                } label: {
                    row(entry.content)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier(entry.year == model.year ? "year.story.entry" : "year.story.entry.\(entry.year)")
            }
        }
        .task { await model.refresh() }
        .fullScreenCover(item: $presented) { presented in
            YearStoryScreen(groupID: groupID, year: presented.year)
        }
    }
}

extension YearStoryEntry where Row == MemoryEntryFeedCard {
    init(groupID: String, model: YearStoryEntryModel? = nil) {
        self.init(groupID: groupID, model: model) { MemoryEntryFeedCard(content: $0) }
    }
}

/// The year story a tapped card opens (full screen).
private struct PresentedYear: Identifiable {
    let year: Int
    var id: Int { year }
}
