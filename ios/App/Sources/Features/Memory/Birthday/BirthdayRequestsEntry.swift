// Surface: birthday.request — the group-screen entry ("Entry on the group screen" in
// design/surfaces/birthday.request.md).
import AppData
import SwiftUI

/// One row per open birthday request in this group (`birthday.request.title` + `birthday.request.due`),
/// for `groups.screen`.
///
/// Shows nothing when there is no open request. The honoree never gets a row about themselves.
/// There is no "you haven't contributed" badge or state. A tap opens `BirthdayRequestScreen` as a
/// sheet (`.presentationDetents([.large])`). The row's look is the caller's:
///
///     BirthdayRequestsEntry(groupID: group.id) { content in
///         MyGroupRow(title: content.title, subtitle: content.subtitle)
///     }
///
/// While hidden it is an empty zero-height stack; it refreshes when it appears and after the sheet closes.
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
        .sheet(item: $presented, onDismiss: {
            Task { await model.refresh() }
        }) { request in
            BirthdayRequestScreen(requestID: request.id, groupID: groupID)
                .presentationDetents([.large])
        }
    }
}

extension BirthdayRequestsEntry where Row == MemoryEntryPlainRow {
    init(groupID: String, model: BirthdayRequestsEntryModel? = nil) {
        self.init(groupID: groupID, model: model) { MemoryEntryPlainRow(content: $0) }
    }
}
