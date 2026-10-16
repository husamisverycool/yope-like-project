// Surface: year.story — the group-screen entry (A in design/surfaces/year.story.md; placed by groups.screen item 8).
import AppData
import DesignSystem
import SwiftUI

/// The "Year in Photos" feed card for `groups.screen` (`year.story.entry.title`, `.entry.subtitle` "{year} Recap",
/// `.entry.button` "View memories", `icon.global.recap`, the story's cover).
///
/// Shown only while this year's story (group-local year) is ready, i.e. from December 1; a tap opens `YearStoryScreen`
/// full screen. The look defaults to `MemoryFeedCard` (groups.screen item 8); pass your own row to restyle it:
///
///     YearStoryEntry(groupID: group.id) { content in MyCard(content) }
///
/// While hidden it is an empty zero-size stack; it refreshes when it appears.
@MainActor
struct YearStoryEntry<Row: View>: View {
    @State private var model: YearStoryEntryModel
    @State private var isPresented = false
    private let row: (MemoryEntryContent) -> Row
    private let groupID: String

    init(groupID: String, model: YearStoryEntryModel? = nil, @ViewBuilder row: @escaping (MemoryEntryContent) -> Row) {
        self.groupID = groupID
        _model = State(initialValue: model ?? YearStoryEntryModel(groupID: GroupID(groupID), dependencies: .current))
        self.row = row
    }

    var body: some View {
        VStack(spacing: 0) {
            if let content = model.content, model.year != nil {
                Button {
                    isPresented = true
                } label: {
                    row(content)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("year.story.entry")
            }
        }
        .task { await model.refresh() }
        .fullScreenCover(isPresented: $isPresented) {
            if let year = model.year {
                YearStoryScreen(groupID: groupID, year: year)
            }
        }
    }
}

extension YearStoryEntry where Row == MemoryFeedCard {
    init(groupID: String, model: YearStoryEntryModel? = nil) {
        self.init(groupID: groupID, model: model) { MemoryFeedCard(content: $0) }
    }
}
