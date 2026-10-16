// Surface: question.weekly E — turning the weekly question on or off for the group: a switch in groups.settings
// (`question.weekly.settings.row` / `.rowDetail`), the C-14 row + native switch of the other group settings
// (references/auto/retro/video/ig-DJXvmqRv2_N-referrals-sheet-f042-059.png, VID-SET) (design/surfaces/question.weekly.md;
// MERGE WQ-4: the default for new groups is BLOCKED and stays the server's — off).
import AppData
import AppModels
import DesignSystem
import Observation
import SwiftUI

@MainActor
@Observable
final class QuestionSettingModel {
    let groupID: GroupID
    private(set) var isOn = false
    private(set) var isAdmin = false
    private(set) var isLoaded = false
    private(set) var errorCount = 0

    private let services: PlansServices

    init(groupID: GroupID, services: PlansServices) {
        self.groupID = groupID
        self.services = services
    }

    func load() async {
        guard let setting = try? await services.questions.weeklyQuestionSetting(groupID: groupID) else { return }
        isOn = setting.isOn
        isAdmin = setting.isAdmin
        isLoaded = true
    }

    /// `set_group_weekly_question`; the switch moves at once and returns on failure.
    func set(_ on: Bool) async {
        let previous = isOn
        isOn = on
        do {
            try await services.questions.setWeeklyQuestion(groupID: groupID, on: on)
            services.didChange()
        } catch {
            isOn = previous
            errorCount += 1
        }
    }
}

/// The groups.settings section with the weekly question's switch: the title `question.weekly.settings.row`, the detail
/// `.rowDetail` under it (`meta`, grey — the C-14 row's subtitle), the native switch (tint `color.global.selection`).
/// Only the group's admins change it (`set_group_weekly_question`: `not_group_admin`), so the section shows for them
/// only. Renders nothing until loaded.
@MainActor
struct QuestionSettingsSection: View {
    @State private var model: QuestionSettingModel
    var isOffline = false

    init(groupID: String, isOffline: Bool = false, model: QuestionSettingModel? = nil) {
        _model = State(initialValue: model ?? QuestionSettingModel(groupID: GroupID(groupID), services: .shared))
        self.isOffline = isOffline
    }

    var body: some View {
        VStack(spacing: 0) {
            if model.isLoaded, model.isAdmin {
                SettingsGroup(rows: [
                    SettingsRow(
                        Copy.questionWeeklySettingsRow,
                        subtitle: Copy.questionWeeklySettingsRowDetail,
                        kind: .toggle(Binding(get: { model.isOn }, set: { value in Task { await model.set(value) } })),
                        isEnabled: !isOffline
                    )
                    .accessibilityIdentifier("groups.settings.weeklyQuestion")
                    .asSettingsRow(),
                ])
            }
        }
        .dsHaptic(Tokens.Haptics.globalError, trigger: model.errorCount)
        .task { await model.load() }
    }
}
