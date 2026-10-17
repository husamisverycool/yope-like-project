// Account group — SettingsHiddenModel: state and actions of the screen in SettingsHiddenScreen.swift (settings.hidden).
import AppData
import AppModels
import DesignSystem
import Foundation
import Observation

@MainActor
@Observable
final class SettingsHiddenModel {
    struct Row: Identifiable, Equatable {
        let memory: HiddenMemory
        var id: MemoryHideID { memory.id }
        var isDay: Bool { memory.isDay }

        /// The row's title (`layout.onthisday.dateFormat`, "Jul 22, 2022"): the hidden day, or the day the photo was posted
        /// (this device's zone: the list spans groups, so no one group's zone applies).
        func title(timeZone: TimeZone = .current) -> String {
            if let day = memory.day {
                return MemoryFormat.memoryDate(MemoryFormat.calendarDate(day), timeZone: MemoryFormat.utc)
            }
            guard let takenAt = memory.takenAt else { return "" }
            return MemoryFormat.memoryDate(takenAt, timeZone: timeZone)
        }

        /// A hidden day says what it covers (`settings.hidden.day.detail`); a photo's row shows its thumbnail instead.
        var subtitle: String? { isDay ? Copy.settingsHiddenDayDetail : nil }
    }

    enum Phase: Equatable {
        case loading
        case loaded
        case error
    }

    private(set) var rows: [Row] = []
    private(set) var phase: Phase = .loading
    private(set) var successCount = 0
    /// Failed unhides: the message-only alert `settings.hidden.unhideError`.
    private(set) var errorCount = 0

    private let data: AccountDataSource

    init(data: AccountDataSource) {
        self.data = data
    }

    /// `my_hidden_memories`, newest hide first. Error / offline: the list already shown stays; else the tappable line.
    func load() async {
        do {
            rows = try await data.hiddenMemories().map(Row.init(memory:))
            phase = .loaded
        } catch {
            if rows.isEmpty || phase != .loaded { phase = .error }
        }
    }

    /// `unhide_memory`: no confirmation (it only shows a memory again); the row goes at once and comes back if the request
    /// fails. The photo or day is in On This Day and the Memories widget again from their next read.
    @discardableResult
    func unhide(_ row: Row) async -> Bool {
        guard let index = rows.firstIndex(of: row) else { return false }
        rows.remove(at: index)
        do {
            try await data.unhideMemory(id: row.id)
            successCount += 1
            return true
        } catch {
            rows.insert(row, at: min(index, rows.count))
            errorCount += 1
            return false
        }
    }

    func seed(rows: [Row], phase: Phase) {
        self.rows = rows
        self.phase = phase
    }
}
