// Surface: settings.blocked — blocked people. Reference: Apple HIG (lists and tables; ContentUnavailableView; system
// surface; design/surfaces/settings.blocked.md).
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

struct SettingsBlockedScreen: View {
    @Environment(AccountDependencies.self) private var dependencies

    var body: some View {
        SettingsBlockedView(model: SettingsBlockedModel(data: dependencies.data))
    }
}

struct SettingsBlockedView: View {
    @State private var model: SettingsBlockedModel
    @Environment(AccountDependencies.self) private var dependencies

    init(model: SettingsBlockedModel) {
        _model = State(initialValue: model)
    }

    var body: some View {
        content
            .navigationTitle(Text(Copy.settingsBlockedTitle))
            .navigationBarTitleDisplayMode(.inline)
            .task { await model.load() }
            .dsHaptic(Tokens.Haptics.globalSuccess, trigger: model.successCount)
            .accessibilityIdentifier("settings.blocked")
    }

    @ViewBuilder
    private var content: some View {
        switch model.phase {
        case .loading:
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .loaded where model.rows.isEmpty:
            // `settings.blocked.layout.empty`
            ContentUnavailableView {
                Text(Copy.settingsBlockedEmptyTitle)
            } description: {
                Text(Copy.settingsBlockedEmptyMessage)
            }
        case .loaded, .error:
            List {
                Section {
                    ForEach(model.rows) { row in
                        HStack {
                            AvatarView(path: row.profile?.avatarPath, diameter: Tokens.Sizes.globalAvatarPicker)
                            Text(row.name)
                            Spacer(minLength: 0)
                            Button(Copy.settingsBlockedUnblock) {
                                Task {
                                    if await model.unblock(row) {
                                        dependencies.toasts.show(Copy.safetyBlockUndone(firstName: row.profile?.firstName ?? row.name))
                                    }
                                }
                            }
                            .buttonStyle(.borderless)
                            .disabled(dependencies.network.isOffline)
                        }
                    }
                } footer: {
                    if model.phase == .error {
                        VStack(alignment: .leading) {
                            Text(Copy.settingsBlockedError)
                            Button(Copy.settingsBlockedRetry) { Task { await model.load() } }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .animation(.default, value: model.rows) // provenance-ok: list default row-removal animation (easing.global.native)
        }
    }
}
