// Surface: birthday.request — the group-screen entry ("Entry on the group screen" in design/surfaces/birthday.request.md;
// placed by groups.screen item 6).
import AppData
import SwiftUI

/// One row per open birthday request in this group (`birthday.request.title` + `birthday.request.due`, the honoree's
/// avatar), for `groups.screen`.
///
/// Shows nothing when there is no open request. The honoree never gets a row about themselves. There is no "you haven't
/// contributed" badge or state. A tap opens `BirthdayRequestScreen` full screen. The look defaults to `MemoryEntryRequestRow`
/// (groups.screen item 6: C-14 + C-16); pass your own row to restyle it:
///
///     BirthdayRequestsEntry(groupID: group.id) { content in MyRow(content) }
///
/// While hidden it is an empty zero-size stack; it refreshes when it appears and after the request closes.
@MainActor
struct BirthdayRequestsEntry<Row: View>: View {
    @State private var model: BirthdayRequestsEntryModel
    @State private var presented: PresentedRequest?
    private let row: (MemoryEntryContent) -> Row
    private let groupID: String

    private struct PresentedRequest: Identifiable {
        let id: String
    }

    init(groupID: String, model: BirthdayRequestsEntryModel? = nil, @ViewBuilder row: @escaping (MemoryEntryContent) -> Row) {
        self.groupID = groupID
        _model = State(initialValue: model ?? BirthdayRequestsEntryModel(groupID: GroupID(groupID), dependencies: .current))
        self.row = row
    }

    var body: some View {
        VStack(spacing: 0) {
            ForEach(model.items) { item in
                Button {
                    presented = PresentedRequest(id: item.requestID.rawValue)
                } label: {
                    row(item.content)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("birthday.request.entry")
            }
        }
        .task { await model.refresh() }
        .fullScreenCover(item: $presented, onDismiss: {
            Task { await model.refresh() }
        }) { request in
            BirthdayRequestScreen(requestID: request.id, groupID: groupID)
        }
    }
}

extension BirthdayRequestsEntry where Row == MemoryEntryRequestRow {
    init(groupID: String, model: BirthdayRequestsEntryModel? = nil) {
        self.init(groupID: groupID, model: model) { MemoryEntryRequestRow(content: $0) }
    }
}
