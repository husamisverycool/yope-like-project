// Surface: birthday.tribute — the group-screen entry ("Entry on the group screen" in design/surfaces/birthday.tribute.md;
// placed by groups.screen item 8, MERGE FV-3).
import AppData
import DesignSystem
import Observation
import SwiftUI

/// The birthday video cards of one group: one per delivered video the caller may watch (`group_tributes`: their own,
/// and the ones they contributed to — RLS, migration 0034), newest delivery first. Kept for good, as the year story's
/// cards (owner decision 31), so the honoree finds their video in the group's memories after the day — muted group or
/// not, since a card asks for nothing and sends nothing.
@MainActor
@Observable
final class TributeEntryModel {
    struct Entry: Equatable, Identifiable {
        let tributeID: TributeID
        let content: MemoryEntryContent
        var id: TributeID { tributeID }
    }

    private(set) var entries: [Entry] = []
    let groupID: GroupID
    private let dependencies: MemoryDependencies

    init(groupID: GroupID, dependencies: MemoryDependencies) {
        self.groupID = groupID
        self.dependencies = dependencies
    }

    private struct Cached {
        let entries: [Entry]
    }

    /// The card of one video: `birthday.tribute.title` ("Your birthday video") for the honoree,
    /// `birthday.tribute.title.member` ("{name}'s birthday video") for a contributor; the line is the birthday in the
    /// memory date format (`layout.onthisday.dateFormat`, the year shown: the card stays); the pill
    /// `birthday.tribute.entry.button` ("Play"); `icon.global.video`; the video's poster (its title card).
    static func content(_ tribute: GroupTribute, honoreeName: String, locale: Locale = .current) -> MemoryEntryContent {
        MemoryEntryContent(
            title: tribute.forMe ? Copy.birthdayTributeTitle : Copy.birthdayTributeTitleMember(name: honoreeName),
            subtitle: MemoryFormat.memoryDate(MemoryFormat.calendarDate(tribute.birthdayDate), timeZone: MemoryFormat.utc, locale: locale),
            buttonTitle: Copy.birthdayTributeEntryButton,
            icon: Tokens.Icons.globalVideo,
            photoPath: tribute.posterPath
        )
    }

    func refresh() async {
        guard let data = dependencies.data else {
            entries = []
            return
        }
        let me = await data.currentUser()
        let cacheKey = "tribute.entries." + groupID.rawValue // provenance-ok: cache key
        if entries.isEmpty, let cached = dependencies.cache.value(Cached.self, key: cacheKey, user: me) {
            entries = cached.entries
        }
        do {
            let tributes = try await data.groupTributes(groupID: groupID)
            let others = Array(Set(tributes.filter { !$0.forMe }.map(\.honoreeID)))
            let names = others.isEmpty ? [:] : Dictionary(
                try await data.profiles(ids: others).map { ($0.id, $0.firstName) }, uniquingKeysWith: { first, _ in first }
            )
            let fresh = tributes.map { tribute in
                Entry(tributeID: tribute.id, content: Self.content(tribute, honoreeName: names[tribute.honoreeID] ?? ""))
            }
            entries = fresh
            if fresh.isEmpty {
                dependencies.cache.remove(key: cacheKey)
            } else {
                dependencies.cache.set(Cached(entries: fresh), key: cacheKey, user: me)
            }
        } catch {
            // A memory card only: on failure it stays as it was (loading, error and offline show nothing new).
        }
    }
}

/// The birthday video feed cards for `groups.screen`, side by side in the feed pager (`size.global.cardGap` apart, as
/// the pager's own cards); a tap opens `TributeScreen` full screen. The look defaults to `MemoryEntryFeedCard`; pass your
/// own row to restyle it:
///
///     TributeEntry(groupID: group.id) { content in MyCard(content) }
///
/// While there is no video to show it is an empty zero-size stack; it refreshes when it appears.
@MainActor
struct TributeEntry<Row: View>: View {
    @State private var model: TributeEntryModel
    @State private var presented: PresentedTribute?
    private let row: (MemoryEntryContent) -> Row
    private let groupID: String

    init(groupID: String, model: TributeEntryModel? = nil, @ViewBuilder row: @escaping (MemoryEntryContent) -> Row) {
        self.groupID = groupID
        _model = State(initialValue: model ?? TributeEntryModel(groupID: GroupID(groupID), dependencies: .current))
        self.row = row
    }

    var body: some View {
        HStack(alignment: .top, spacing: Tokens.Sizes.globalCardGap) {
            ForEach(model.entries) { entry in
                Button {
                    presented = PresentedTribute(id: entry.tributeID.rawValue)
                } label: {
                    row(entry.content)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("birthday.tribute.entry")
            }
        }
        .task { await model.refresh() }
        .fullScreenCover(item: $presented) { presented in
            TributeScreen(tributeID: presented.id, groupID: groupID)
        }
    }
}

extension TributeEntry where Row == MemoryEntryFeedCard {
    init(groupID: String, model: TributeEntryModel? = nil) {
        self.init(groupID: groupID, model: model) { MemoryEntryFeedCard(content: $0) }
    }
}

/// The video a tapped card opens (full screen).
private struct PresentedTribute: Identifiable {
    let id: String
}
