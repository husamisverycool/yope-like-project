// Surface: safety.report — report flow. Reference: Apple HIG (menus, sheets; App Review 1.2) with Yope voice for the
// title and explanation (F-21; design/surfaces/safety.report.md). Reference: HIG menus / action sheets / sheets.
import AppData
import AppModels
import DesignSystem
import Observation
import SwiftUI
import UIKit

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
