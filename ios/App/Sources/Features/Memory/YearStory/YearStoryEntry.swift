// Surface: year.story — the group-screen entry (A in design/surfaces/year.story.md).
import AppData
import SwiftUI

/// The "It's time for your {year} story" row for `groups.screen` (`year.story.entry.title`,
/// `.subtitle`, `.button`).
///
/// Shown only while this year's story (group-local year) is ready, i.e. from December 1; a tap
/// opens `YearStoryScreen` full screen. The row's look is the caller's:
///
///     YearStoryEntry(groupID: group.id) { content in
///         MyGroupRow(title: content.title, subtitle: content.subtitle, button: content.buttonTitle)
///     }
///
/// While hidden it is an empty zero-height stack; it refreshes when it appears.
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

extension YearStoryEntry where Row == MemoryEntryPlainRow {
    init(groupID: String, model: YearStoryEntryModel? = nil) {
        self.init(groupID: groupID, model: model) { MemoryEntryPlainRow(content: $0) }
    }
}
