// Surface: settings.blocked — blocked people. Reference: Apple HIG (lists and tables; ContentUnavailableView; system
// surface; design/surfaces/settings.blocked.md).
import AppData
import AppModels
import DesignSystem
import Observation
import SwiftUI

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
