// Account group — ReportModel: Retro's report flow (safety.report; ReportFlow.swift): the reason lists per target kind
// (`safety.report.layout.reasons`, MERGE RA-12), one tap files `report(kind, id, reason)`; "I don't like it" files
// nothing and opens the next steps.
import AppData
import AppModels
import DesignSystem
import Observation
import SwiftUI
import UIKit

/// A report reason (`safety.report.reason.*`).
enum ReportReason: String, CaseIterable, Identifiable {
    case dontLike
    case nudity
    case other
    case impersonation
    case inappropriate

    var id: String { rawValue }

    /// The button's text.
    var title: String {
        switch self {
        case .dontLike: return Copy.safetyReportReasonDontLike
        case .nudity: return Copy.safetyReportReasonNudity
        case .other: return Copy.safetyReportReasonOther
        case .impersonation: return Copy.safetyReportReasonImpersonation
        case .inappropriate: return Copy.safetyReportReasonInappropriate
        }
    }

    /// "I don't like it" files nothing: it opens the next steps.
    var filesReport: Bool { self != .dontLike }

    /// The reasons offered for a target kind, in Retro's order: posts, messages and selfie reactions "I don't like it ·
    /// Nudity or sexual activity · Other" (a selfie is photo content: its list holds the post reasons, MERGE SR-10),
    /// people and groups "It's impersonating someone · It's inappropriate · Other".
    static func reasons(for kind: ReportTarget.Kind) -> [ReportReason] {
        switch kind {
        case .post, .message, .selfie: return [.dontLike, .nudity, .other]
        case .user, .group: return [.impersonation, .inappropriate, .other]
        }
    }

    /// `p_reason`: the reason's English text from `safety.report.layout.reasons` (`.sent`: "the reason's English text is
    /// sent as p_reason"), by its position in the kind's list.
    func wireValue(for kind: ReportTarget.Kind) -> String {
        let list: String
        switch kind {
        case .post: list = Tokens.Layouts.SafetyReportLayoutReasons.post
        case .message: list = Tokens.Layouts.SafetyReportLayoutReasons.message
        case .selfie: list = Tokens.Layouts.SafetyReportLayoutReasons.selfie
        case .user: list = Tokens.Layouts.SafetyReportLayoutReasons.user
        case .group: list = Tokens.Layouts.SafetyReportLayoutReasons.group
        }
        let entries = list.components(separatedBy: " · ") // provenance-ok: the token's list separator
        guard let index = Self.reasons(for: kind).firstIndex(of: self), entries.indices.contains(index) else { return rawValue }
        return entries[index]
    }
}

@MainActor
@Observable
final class ReportModel {
    /// A failed report: the titled error alert, or "no longer available" (`target_not_found`).
    enum Failure: Equatable {
        case failed
        case notFound
    }

    let target: ReportTarget
    private(set) var isSending = false
    private(set) var failure: Failure?
    /// The reason last filed (tests, the confirmation).
    private(set) var filedReason: ReportReason?
    private(set) var successCount = 0
    private(set) var errorCount = 0

    private let data: AccountDataSource

    init(target: ReportTarget, data: AccountDataSource) {
        self.target = target
        self.data = data
    }

    /// `safety.report.title.*` by target kind (Retro's question with the kind's noun).
    var title: String {
        switch target.kind {
        case .post: return Copy.safetyReportTitlePost
        case .message: return Copy.safetyReportTitleMessage
        case .selfie: return Copy.safetyReportTitleSelfie
        case .user: return Copy.safetyReportTitleUser
        case .group: return Copy.safetyReportTitleGroup
        }
    }

    var reasons: [ReportReason] { ReportReason.reasons(for: target.kind) }

    /// `report(p_target_kind, p_target_id, p_reason)` with the reason's English text. Returns true when filed.
    @discardableResult
    func submit(_ reason: ReportReason) async -> Bool {
        guard reason.filesReport, !isSending else { return false }
        failure = nil
        isSending = true
        defer { isSending = false }
        do {
            try await data.report(
                kind: ReportTargetKind(rawValue: target.kind.rawValue) ?? .unknown,
                targetID: target.id,
                reason: reason.wireValue(for: target.kind)
            )
            filedReason = reason
            successCount += 1
            return true
        } catch {
            failure = DataError.from(error).apiCode == .targetNotFound ? .notFound : .failed
            errorCount += 1
            return false
        }
    }
}
