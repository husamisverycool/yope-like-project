// Surface: safety.report — report a post, message, person or group. Visual reference: Retro's report flow in native
// menus and action sheets (references/auto/retro/press/tc-2025-12-rewind-panels.png, TC-RWP: native menu with red
// destructive items; strings references/auto/retro/apk/retro-android-2026.10.1150-strings.txt `media_viewer_report_*`,
// `profile_report_*`); Apple HIG action sheets, App Review 1.2 (design/surfaces/safety.report.md; MERGE RA-12).
import AppData
import AppModels
import DesignSystem
import Observation
import SwiftUI
import UIKit

extension View {
    /// The report flow for `target` (`safety.report.layout.flow`): a native action sheet titled with Retro's question
    /// (`confirmationDialog`, visible title), one button per reason, Cancel last. Choosing a reason files the report at
    /// once (the sheet closes; the request runs in the background) and confirms `safety.report.sent.title` (C-26: an
    /// accessibility announcement on iOS). "I don't like it" files nothing and opens "Next Steps": "Leave the group"
    /// (the groups.settings leave alert, then `safety.report.left`) and "Block {first_name}" (safety.block). Failures:
    /// the titled alert `safety.report.error.*` / the message-only `safety.report.error.notFound`.
    ///
    /// Other surfaces present it with `router.modal = .account(.report(target))` (the shell shows it over the current
    /// screen) or attach this modifier with their own binding.
    func reportFlow(target: Binding<ReportTarget?>, dependencies: AccountDependencies, onLeft: (@MainActor () -> Void)? = nil) -> some View {
        modifier(ReportFlowModifier(target: target, dependencies: dependencies, onLeft: onLeft))
    }
}

private struct ReportFlowModifier: ViewModifier {
    @Binding var target: ReportTarget?
    let dependencies: AccountDependencies
    let onLeft: (@MainActor () -> Void)?

    @State private var nextSteps: ReportTarget?
    @State private var leaving: ReportTarget?
    @State private var blockTarget: BlockTarget?
    @State private var failure: ReportModel.Failure?
    @State private var successCount = 0
    @State private var errorCount = 0
    @State private var warningCount = 0

    func body(content: Content) -> some View {
        content
            .background {
                Color.clear
                    .confirmationDialog(
                        Text(target.map { ReportModel(target: $0, data: dependencies.data).title } ?? ""),
                        isPresented: Binding(get: { target != nil }, set: { if !$0 { target = nil } }),
                        titleVisibility: .visible,
                        presenting: target
                    ) { reported in
                        ForEach(ReportReason.reasons(for: reported.kind)) { reason in
                            Button(reason.title) { choose(reason, for: reported) }
                        }
                        Button(Copy.safetyReportCancel, role: .cancel) { target = nil }
                    }
            }
            .background {
                Color.clear
                    .confirmationDialog(
                        Text(Copy.safetyReportNextStepsTitle),
                        isPresented: Binding(get: { nextSteps != nil }, set: { if !$0 { nextSteps = nil } }),
                        titleVisibility: .visible,
                        presenting: nextSteps
                    ) { reported in
                        if reported.groupID != nil {
                            Button(Copy.safetyReportNextStepsLeave, role: .destructive) { leaving = reported }
                        }
                        if let person = reported.person {
                            Button(Copy.safetyReportNextStepsBlock(firstName: person.firstName), role: .destructive) { blockTarget = person }
                        }
                        Button(Copy.safetyReportCancel, role: .cancel) {}
                    }
            }
            .background {
                Color.clear
                    .alert(
                        Text(Copy.groupsSettingsLeaveTitle(groupName: leaving?.groupName ?? "")),
                        isPresented: Binding(get: { leaving != nil }, set: { if !$0 { leaving = nil } }),
                        presenting: leaving
                    ) { reported in
                        Button(Copy.groupsSettingsAlertCancel, role: .cancel) {}
                        Button(Copy.groupsSettingsLeaveConfirm, role: .destructive) { leave(reported) }
                    } message: { _ in
                        Text(Copy.groupsSettingsLeaveMessage)
                    }
            }
            .background {
                Color.clear
                    .alert(
                        Text(failure == .failed ? Copy.safetyReportErrorTitle : ""),
                        isPresented: Binding(get: { failure != nil }, set: { if !$0 { failure = nil } }),
                        presenting: failure
                    ) { _ in
                        Button(Copy.authPhoneErrorDismiss, role: .cancel) {}
                    } message: { shown in
                        Text(shown == .notFound ? Copy.safetyReportErrorNotFound : Copy.safetyReportErrorDetail)
                    }
            }
            .blockConfirmation(target: $blockTarget, toasts: dependencies.toasts) { person in
                try await dependencies.data.block(userID: UserID(person.userID))
            }
            .dsHaptic(Tokens.Haptics.globalSuccess, trigger: successCount)
            .dsHaptic(Tokens.Haptics.globalError, trigger: errorCount)
            .dsHaptic(Tokens.Haptics.globalWarning, trigger: warningCount)
    }

    private func choose(_ reason: ReportReason, for reported: ReportTarget) {
        target = nil
        guard reason.filesReport else {
            nextSteps = reported
            return
        }
        let model = ReportModel(target: reported, data: dependencies.data)
        let toasts = dependencies.toasts
        Task { @MainActor in
            if await model.submit(reason) {
                successCount += 1
                toasts.show(Copy.safetyReportSentTitle)
            } else {
                errorCount += 1
                failure = model.failure
            }
        }
    }

    /// "Leave the group" confirmed: `leave_group`, then `safety.report.left`; the screen goes back to groups.list.
    private func leave(_ reported: ReportTarget) {
        guard let groupID = reported.groupID else { return }
        let data = dependencies.data
        let toasts = dependencies.toasts
        let router = dependencies.router
        Task { @MainActor in
            do {
                try await data.leaveGroup(id: GroupID(groupID))
                warningCount += 1
                toasts.show(Copy.safetyReportLeft)
                if let onLeft {
                    onLeft()
                } else {
                    router.modal = nil
                    ShellState.active?.presentedRoute = nil
                    router.path = []
                }
            } catch {
                errorCount += 1
                failure = .failed
            }
        }
    }
}

/// The report flow in a sheet, for a surface that presents `ReportSheet(target:)` in its own `.sheet` (kept so those
/// call sites compile; prefer `.reportFlow(target:dependencies:)`, which shows Retro's native action sheets). The same
/// content as the action sheets in M3's sheet form (safety.report Platform notes): the sheet title (C-29, text role
/// `sheetTitle`), the reasons as C-14 rows, then "Next Steps" for "I don't like it".
struct ReportSheet: View {
    let target: ReportTarget
    @Environment(AccountDependencies.self) private var dependencies
    @Environment(\.dismiss) private var dismiss
    @State private var showsNextSteps = false
    @State private var blockTarget: BlockTarget?
    @State private var confirmLeave = false

    var body: some View {
        VStack(spacing: Tokens.Sizes.globalTitleToContent) {
            SheetHeader(
                title: showsNextSteps ? Copy.safetyReportNextStepsTitle : ReportModel(target: target, data: dependencies.data).title,
                closeAccessibilityLabel: Copy.safetyReportCancel,
                onClose: { dismiss() }
            )
            if showsNextSteps {
                SettingsGroup(rows: nextStepRows)
            } else {
                SettingsGroup(rows: ReportReason.reasons(for: target.kind).map { reason in
                    SettingsRow(reason.title, kind: .navigation { choose(reason) }).asSettingsRow()
                })
            }
            Spacer(minLength: 0)
        }
        .padding(.top, Tokens.Sizes.globalScreenMargin)
        .background(Tokens.Colors.globalBackground.ignoresSafeArea())
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .dsSheetBackground()
        .blockConfirmation(target: $blockTarget, toasts: dependencies.toasts) { person in
            try await dependencies.data.block(userID: UserID(person.userID))
        } onBlocked: { _ in
            dismiss()
        }
        .alert(Text(Copy.groupsSettingsLeaveTitle(groupName: target.groupName ?? "")), isPresented: $confirmLeave) {
            Button(Copy.groupsSettingsAlertCancel, role: .cancel) {}
            Button(Copy.groupsSettingsLeaveConfirm, role: .destructive) { leave() }
        } message: {
            Text(Copy.groupsSettingsLeaveMessage)
        }
        .accessibilityIdentifier("safety.report")
    }

    private var nextStepRows: [AnyView] {
        var rows: [AnyView] = []
        if target.groupID != nil {
            rows.append(SettingsRow(Copy.safetyReportNextStepsLeave, kind: .destructive { confirmLeave = true }).asSettingsRow())
        }
        if let person = target.person {
            rows.append(SettingsRow(Copy.safetyReportNextStepsBlock(firstName: person.firstName), kind: .destructive { blockTarget = person }).asSettingsRow())
        }
        return rows
    }

    private func choose(_ reason: ReportReason) {
        guard reason.filesReport else {
            showsNextSteps = true
            return
        }
        let model = ReportModel(target: target, data: dependencies.data)
        let toasts = dependencies.toasts
        dismiss()
        Task { @MainActor in
            if await model.submit(reason) { toasts.show(Copy.safetyReportSentTitle) }
        }
    }

    /// "Leave the group" confirmed: `leave_group`, `safety.report.left`, back to groups.list.
    private func leave() {
        guard let groupID = target.groupID else { return }
        let router = dependencies.router
        let data = dependencies.data
        let toasts = dependencies.toasts
        dismiss()
        Task { @MainActor in
            if (try? await data.leaveGroup(id: GroupID(groupID))) != nil {
                toasts.show(Copy.safetyReportLeft)
                router.modal = nil
                router.path = []
            }
        }
    }
}
