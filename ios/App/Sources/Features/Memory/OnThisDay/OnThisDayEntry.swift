// Surface: onthisday — the group-screen entry (A in design/surfaces/onthisday.md; placed by groups.screen item 8).
import AppData
import DesignSystem
import SwiftUI

/// The On This Day feed card for `groups.screen`: `onthisday.entry.title` ("On this day"), `.entry.subtitle` ("Revisit
/// memories from July 5 over the years", today as `layout.birthday.add.dateFormat`), `.entry.button` ("View memories"),
/// the glyph `icon.global.rewind` and the newest memory's photo.
///
/// Renders nothing unless the group has photos from today's month and day in earlier years (`on_this_day`, group-local
/// day rolling over at 05:00); a tap pushes `onthisday` at the newest memory. The look defaults to `MemoryEntryFeedCard`
/// (groups.screen item 8); pass your own row to restyle it:
///
///     OnThisDayEntry(groupID: group.id) { content in MyCard(content) }
///
/// While hidden it is an empty zero-size stack; it refreshes when it appears.
@MainActor
struct OnThisDayEntry<Row: View>: View {
    @State private var model: OnThisDayEntryModel
    private let row: (MemoryEntryContent) -> Row

    init(groupID: String, model: OnThisDayEntryModel? = nil, @ViewBuilder row: @escaping (MemoryEntryContent) -> Row) {
        _model = State(initialValue: model ?? OnThisDayEntryModel(groupID: GroupID(groupID), dependencies: .current))
        self.row = row
    }

    var body: some View {
        // A stack (not a Group) so the refresh runs while the entry is hidden; it has no size then.
        VStack(spacing: 0) {
            if let content = model.content {
                Button {
                    model.open()
                } label: {
                    row(content)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("onthisday.entry")
            }
        }
        .task { await model.refresh() }
    }
}

extension OnThisDayEntry where Row == MemoryEntryFeedCard {
    init(groupID: String, model: OnThisDayEntryModel? = nil) {
        self.init(groupID: groupID, model: model) { MemoryEntryFeedCard(content: $0) }
    }
}
