// Surface: onthisday — the group-screen entry (A in design/surfaces/onthisday.md).
import AppData
import SwiftUI

/// The "{group}'s Day in History" row for `groups.screen`.
///
/// Renders nothing unless the group has photos from today's month and day in earlier years
/// (`on_this_day`, group-local day rolling over at 05:00); a tap opens `OnThisDayScreen` full screen
/// at the newest year. The row's look is the caller's:
///
///     OnThisDayEntry(groupID: group.id) { content in
///         MyGroupRow(title: content.title, subtitle: content.subtitle)
///     }
///
/// `OnThisDayEntry(groupID:)` without a builder uses `MemoryEntryPlainRow`. The entry refreshes
/// when it appears; while hidden it is an empty zero-height stack.
@MainActor
struct OnThisDayEntry<Row: View>: View {
    @State private var model: OnThisDayEntryModel
    @State private var isPresented = false
    private let row: (MemoryEntryContent) -> Row
    private let groupID: String

    init(groupID: String, model: OnThisDayEntryModel? = nil, @ViewBuilder row: @escaping (MemoryEntryContent) -> Row) {
        self.groupID = groupID
        _model = State(initialValue: model ?? OnThisDayEntryModel(groupID: GroupID(groupID), dependencies: .current))
        self.row = row
    }

    var body: some View {
        // A stack (not a Group) so the refresh runs while the row is hidden; it has no size then.
        VStack(spacing: 0) {
            if let content = model.content {
                Button {
                    isPresented = true
                } label: {
                    row(MemoryEntryContent(title: content.title, subtitle: content.subtitle))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("onthisday.entry")
            }
        }
        .task { await model.refresh() }
        .fullScreenCover(isPresented: $isPresented) {
            OnThisDayScreen(groupID: groupID)
        }
    }
}

extension OnThisDayEntry where Row == MemoryEntryPlainRow {
    init(groupID: String, model: OnThisDayEntryModel? = nil) {
        self.init(groupID: groupID, model: model) { MemoryEntryPlainRow(content: $0) }
    }
}
