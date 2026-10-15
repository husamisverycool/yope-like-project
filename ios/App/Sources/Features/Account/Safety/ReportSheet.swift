// Surface: safety.report — report flow. Reference: Apple HIG (menus, sheets; App Review 1.2) with Yope voice for the
// title and explanation (F-21; design/surfaces/safety.report.md). Reference: HIG menus / action sheets / sheets.
import AppData
import AppModels
import DesignSystem
import Observation
import SwiftUI
import UIKit

@MainActor
@Observable
final class ReportModel {
    enum Phase: Equatable {
        case form
        case sending
        case sent
        /// `target_not_found`.
        case notFound
    }

    let target: ReportTarget
    var details = ""
    private(set) var phase: Phase = .form
    /// Error / offline: inline footer under the field; the details are kept.
    private(set) var failed = false
    private(set) var successCount = 0
    private(set) var errorCount = 0

    /// `p_reason` is at most 1000 characters (docs/API.md §6.3).
    static let maxDetails = 1000

    private let data: AccountDataSource

    init(target: ReportTarget, data: AccountDataSource) {
        self.target = target
        self.data = data
    }

    /// `safety.report.title.*` by target kind.
    var title: String {
        switch target.kind {
        case .post: return Copy.safetyReportTitlePost
        case .message: return Copy.safetyReportTitleMessage
        case .user: return Copy.safetyReportTitleUser(firstName: target.name ?? target.person?.firstName ?? "")
        case .group: return Copy.safetyReportTitleGroup(groupName: target.name ?? "")
        }
    }

    /// The "report sent" message: with the person's first name, or the group variant.
    var sentMessage: String {
        if let person = target.person { return Copy.safetyReportSentMessage(firstName: person.firstName) }
        return Copy.safetyReportSentMessageGroup
    }

    func setDetails(_ text: String) {
        details = String(text.prefix(Self.maxDetails))
    }

    /// `report(p_target_kind, p_target_id, p_reason)`; empty details → `p_reason` = the target kind.
    func submit() async {
        guard phase == .form else { return }
        failed = false
        phase = .sending
        let trimmed = details.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            try await data.report(kind: ReportTargetKind(rawValue: target.kind.rawValue) ?? .unknown, targetID: target.id, reason: trimmed.isEmpty ? target.kind.rawValue : trimmed)
            phase = .sent
            successCount += 1
        } catch {
            errorCount += 1
            if DataError.from(error).apiCode == .targetNotFound {
                phase = .notFound
            } else {
                phase = .form
                failed = true
            }
        }
    }
}

/// Sheet with medium / large detents and a visible grabber (`safety.report.layout.flow`).
struct ReportSheet: View {
    let target: ReportTarget
    @Environment(AccountDependencies.self) private var dependencies

    var body: some View {
        ReportView(model: ReportModel(target: target, data: dependencies.data))
    }
}

struct ReportView: View {
    @State private var model: ReportModel
    @State private var blockTarget: BlockTarget?
    @Environment(AccountDependencies.self) private var dependencies

    init(model: ReportModel) {
        _model = State(initialValue: model)
    }

    var body: some View {
        NavigationStack {
            content
                .toolbar { toolbar }
                .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .interactiveDismissDisabled(model.phase == .sending)
        .dsHaptic(Tokens.Haptics.globalSuccess, trigger: model.successCount)
        .dsHaptic(Tokens.Haptics.globalError, trigger: model.errorCount)
        .blockConfirmation(target: $blockTarget, toasts: dependencies.toasts) { target in
            try await dependencies.data.block(userID: UserID(target.userID))
        } onBlocked: { _ in
            close()
        }
        .accessibilityIdentifier("safety.report")
    }

    @ViewBuilder
    private var content: some View {
        switch model.phase {
        case .form, .sending:
            Form {
                Section {
                    Text(model.title)
                        .font(.headline) // provenance-ok: system sheet text style (layout.global.system.typography)
                        .accessibilityAddTraits(.isHeader)
                    if let explanation = AccountBlockedCopy.reportExplanation {
                        Text(explanation)
                            .font(.subheadline) // provenance-ok: system sheet text style (layout.global.system.typography)
                    }
                }
                Section {
                    TextField(Copy.safetyReportDetailsPlaceholder, text: Binding(get: { model.details }, set: { model.setDetails($0) }), axis: .vertical)
                        .disabled(model.phase == .sending)
                        .accessibilityIdentifier("safety.report.details")
                } footer: {
                    if model.failed {
                        VStack(alignment: .leading) {
                            Text(Copy.safetyReportErrorTitle)
                            Text(Copy.safetyReportErrorDetail)
                        }
                    }
                }
            }
        case .sent:
            VStack(spacing: 0) {
                Form {
                    Section {
                        Text(Copy.safetyReportSentTitle)
                            .font(.headline) // provenance-ok: system sheet text style (layout.global.system.typography)
                            .accessibilityAddTraits(.isHeader)
                        Text(model.sentMessage)
                            .font(.subheadline) // provenance-ok: system sheet text style (layout.global.system.typography)
                    }
                    Section {
                        if let person = model.target.person {
                            Button(Copy.safetyReportSentBlock, role: .destructive) { blockTarget = person }
                        }
                        Button(Copy.safetyReportSentDone) { close() }
                            .accessibilityIdentifier("safety.report.done")
                    }
                }
            }
        case .notFound:
            Form {
                Section {
                    Text(Copy.safetyReportErrorNotFound)
                    Button(Copy.safetyReportSentDone) { close() }
                }
            }
        }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        if model.phase == .form || model.phase == .sending {
            ToolbarItem(placement: .cancellationAction) {
                Button(Copy.safetyReportCancel) { close() }
                    .disabled(model.phase == .sending)
            }
            ToolbarItem(placement: .confirmationAction) {
                if model.phase == .sending {
                    ProgressView()
                } else {
                    Button(Copy.safetyReportSubmit, role: .destructive) {
                        Task { await model.submit() }
                    }
                    .accessibilityIdentifier("safety.report.submit")
                }
            }
        }
    }

    private func close() {
        dependencies.router.modal = nil
    }
}
