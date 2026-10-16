// Surface: settings.blocked — blocked people. Visual reference: Retro Settings rows
// (references/auto/retro/video/ig-DJXvmqRv2_N-referrals-sheet-f042-059.png, VID-SET), Retro's people rows with capsule
// actions (references/auto/retro/press/tc-2023-07-retro-1b.webp, TC-1B), the C-27 block
// (references/auto/retro/lazyweb/retro-lazyweb-20251020-week43-dark.png, H43) and Retro's one-line list error
// ("Error loading friends. Tap here to try again."); composition of C-14, C-16, C-06, C-27
// (design/surfaces/settings.blocked.md).
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

    private static let rowFade = DSAnimation.timing(duration: Tokens.Durations.globalFade, easing: Tokens.Easings.globalStandard)

    var body: some View {
        content
            .settingsPage(title: Copy.settingsBlockedTitle)
            .task { await model.load() }
            .onChange(of: dependencies.network.isOffline) { wasOffline, isOffline in
                if wasOffline, !isOffline, model.phase == .error { Task { await model.load() } }
            }
            .dsHaptic(Tokens.Haptics.globalSuccess, trigger: model.successCount)
            .dsHaptic(Tokens.Haptics.globalError, trigger: model.errorCount)
            .formErrorAlert(Copy.safetyBlockError, trigger: model.errorCount)
            .accessibilityIdentifier("settings.blocked")
    }

    @ViewBuilder
    private var content: some View {
        switch model.phase {
        case .loading:
            SettingsList {
                SettingsGroup(rows: [SettingsRow("", kind: .busy).asSettingsRow()])
                    .accessibilityLabel(Text(Copy.globalA11yLoading))
            }
        case .loaded where model.rows.isEmpty:
            EmptyStateView(icon: Tokens.Icons.globalPerson, title: Copy.settingsBlockedEmptyTitle, detail: Copy.settingsBlockedEmptyMessage)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityIdentifier("settings.blocked.empty")
        case .loaded:
            SettingsList {
                SettingsGroup(rows: model.rows.map { row($0).asSettingsRow() })
                    .dsAnimation(Self.rowFade, value: model.rows)
            }
        case .error:
            // Retro's list error: one tappable line (tap = retry); offline reads the same and retries when back online.
            Button {
                Task { await model.load() }
            } label: {
                Text(Copy.settingsBlockedError)
                    .dsTextStyle(TextRole.body)
                    .foregroundStyle(Tokens.Colors.globalTextSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Tokens.Sizes.globalScreenMargin)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("settings.blocked.error")
        }
    }

    /// C-16 in a C-14 row: avatar `size.global.avatarPicker` (C-23 fallback when you no longer share a group), the first
    /// name (`listTitle`) or `settings.blocked.unknown` (grey), and the hugging outline capsule "Unblock" (its label
    /// includes the name for VoiceOver). Unblocking needs no confirmation (reversible): the row fades out.
    private func row(_ row: SettingsBlockedModel.Row) -> some View {
        let known = row.profile?.displayName.isEmpty == false
        let firstName = row.profile?.firstName ?? row.name
        return SettingsCustomRow {
            HStack {
                AvatarView(path: row.profile?.avatarPath, diameter: Tokens.Sizes.globalAvatarPicker)
                Text(known ? firstName : row.name)
                    .dsTextStyle(TextRole.listTitle)
                    .foregroundStyle(known ? Tokens.Colors.globalTextPrimary : Tokens.Colors.globalTextSecondary)
                Spacer(minLength: 0)
                CapsuleButton(Copy.settingsBlockedUnblock, style: .outline) {
                    Task {
                        if await model.unblock(row) {
                            dependencies.toasts.show(Copy.safetyBlockUndone(firstName: firstName))
                        }
                    }
                }
                .fixedSize()
                .disabled(dependencies.network.isOffline)
                .accessibilityLabel(Text([Copy.settingsBlockedUnblock, firstName].joined(separator: " "))) // provenance-ok: joins copy and a name
            }
        }
        .accessibilityIdentifier("settings.blocked.row")
    }
}
