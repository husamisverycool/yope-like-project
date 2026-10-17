// Surface: settings.hidden — Hidden Memories (design/surfaces/settings.hidden.md). Visual reference: Retro Settings rows
// (references/auto/retro/video/ig-DJXvmqRv2_N-referrals-sheet-f042-059.png, VID-SET), Retro's rows with a capsule action
// (references/auto/retro/press/tc-2023-07-retro-1b.webp, TC-1B), the C-27 block
// (references/auto/retro/lazyweb/retro-lazyweb-20251020-week43-dark.png, H43) and Retro's one-line list error; the list
// itself after Timehop's hidden-memory settings with "UNHIDE" (T help/th-help-2024-02-settings-hidden-memory.jpg) and
// Google Photos' hidden dates (support.google.com/photos/answer/9454489). Composition of C-14, C-16, C-06, C-27 as
// settings.blocked.
import AppData
import AppModels
import DesignSystem
import Observation
import SwiftUI

struct SettingsHiddenScreen: View {
    @Environment(AccountDependencies.self) private var dependencies

    var body: some View {
        SettingsHiddenView(model: SettingsHiddenModel(data: dependencies.data))
    }
}

struct SettingsHiddenView: View {
    @State private var model: SettingsHiddenModel
    @Environment(AccountDependencies.self) private var dependencies

    init(model: SettingsHiddenModel) {
        _model = State(initialValue: model)
    }

    private static let rowFade = DSAnimation.timing(duration: Tokens.Durations.globalFade, easing: Tokens.Easings.globalStandard)

    var body: some View {
        content
            .settingsPage(title: Copy.settingsHiddenTitle)
            .task { await model.load() }
            .onChange(of: dependencies.network.isOffline) { wasOffline, isOffline in
                if wasOffline, !isOffline, model.phase == .error { Task { await model.load() } }
            }
            .dsHaptic(Tokens.Haptics.globalSuccess, trigger: model.successCount)
            .dsHaptic(Tokens.Haptics.globalError, trigger: model.errorCount)
            .formErrorAlert(Copy.settingsHiddenUnhideError, trigger: model.errorCount)
            .accessibilityIdentifier("settings.hidden")
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
            EmptyStateView(icon: Tokens.Icons.globalHide, title: Copy.settingsHiddenEmptyTitle, detail: Copy.settingsHiddenEmptyMessage)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityIdentifier("settings.hidden.empty")
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
                Text(Copy.settingsHiddenError)
                    .dsTextStyle(TextRole.body)
                    .foregroundStyle(Tokens.Colors.globalTextSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Tokens.Sizes.globalScreenMargin)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("settings.hidden.error")
        }
    }

    /// C-16 in a C-14 row: a hidden photo's thumbnail (`size.global.avatarPicker` square, `radius.global.thumbnail`) or, for
    /// a hidden day, the C-23 circle with `icon.global.calendar`; the date (`listTitle`, `layout.onthisday.dateFormat`) with
    /// `settings.hidden.day.detail` under a day (`listSubtitle`, grey); the hugging outline capsule "Unhide" (its label
    /// includes the date for VoiceOver). Unhiding needs no confirmation: the row fades out.
    private func row(_ row: SettingsHiddenModel.Row) -> some View {
        let title = row.title()
        return SettingsCustomRow {
            HStack(spacing: Tokens.Sizes.globalRowThumbGap) {
                if row.isDay {
                    AvatarView(path: nil, diameter: Tokens.Sizes.globalAvatarPicker, placeholderIcon: Tokens.Icons.globalCalendar)
                } else {
                    PhotoView(source: row.memory.thumbPath.map(PhotoSource.storage))
                        .frame(width: Tokens.Sizes.globalAvatarPicker, height: Tokens.Sizes.globalAvatarPicker)
                        .clipShape(DSShape.rounded(Tokens.Radii.globalThumbnail))
                        .accessibilityHidden(true)
                }
                VStack(alignment: .leading) {
                    Text(title)
                        .dsTextStyle(TextRole.listTitle)
                        .foregroundStyle(Tokens.Colors.globalTextPrimary)
                    if let subtitle = row.subtitle {
                        Text(subtitle)
                            .dsTextStyle(TextRole.listSubtitle)
                            .foregroundStyle(Tokens.Colors.globalTextSecondary)
                    }
                }
                .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
                CapsuleButton(Copy.settingsHiddenUnhide, style: .outline) {
                    Task { await model.unhide(row) }
                }
                .fixedSize()
                .disabled(dependencies.network.isOffline)
                .accessibilityLabel(Text([Copy.settingsHiddenUnhide, title].joined(separator: " "))) // provenance-ok: joins copy and a date
            }
        }
        .accessibilityIdentifier("settings.hidden.row")
    }
}
