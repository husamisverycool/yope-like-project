// Account group — ReportModel: state and actions of the screen in ReportSheet.swift.
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
