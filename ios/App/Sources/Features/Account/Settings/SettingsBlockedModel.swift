// Account group — SettingsBlockedModel: state and actions of the screen in SettingsBlockedScreen.swift.
import AppData
import AppModels
import DesignSystem
import Observation
import SwiftUI

@MainActor
@Observable
final class SettingsBlockedModel {
    struct Row: Identifiable, Equatable {
        let block: Block
        let profile: Profile?
        var id: UserID { block.blockedID }
        /// `display_name`, or `settings.blocked.unknown` when the profile is no longer readable.
        var name: String {
            guard let name = profile?.displayName, !name.isEmpty else { return Copy.settingsBlockedUnknown }
            return name
        }
    }

    enum Phase: Equatable {
        case loading
        case loaded
        case error
    }

    private(set) var rows: [Row] = []
    private(set) var phase: Phase = .loading
    private(set) var successCount = 0

    private let data: AccountDataSource

    init(data: AccountDataSource) {
        self.data = data
    }

    func load() async {
        do {
            let blocks = try await data.blocked()
            let profiles = (try? await data.profiles(ids: blocks.map(\.blockedID))) ?? []
            let byID = Dictionary(profiles.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
            rows = blocks.map { Row(block: $0, profile: byID[$0.blockedID]) }
            phase = .loaded
        } catch {
            // Offline / error: the list already loaded stays (unblock disabled offline); else the error footer.
            if rows.isEmpty || phase != .loaded { phase = .error }
        }
    }

    /// `unblock_user`: the row goes at once and comes back if the request fails. Returns the first name for the toast.
    func unblock(_ row: Row) async -> Bool {
        guard let index = rows.firstIndex(of: row) else { return false }
        rows.remove(at: index)
        do {
            try await data.unblock(userID: row.id)
            successCount += 1
            return true
        } catch {
            rows.insert(row, at: min(index, rows.count))
            return false
        }
    }

    func seed(rows: [Row], phase: Phase) {
        self.rows = rows
        self.phase = phase
    }
}
