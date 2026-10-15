// Account group — AgeGateModel: state and actions of the screen in AgeGateScreen.swift.
import AppData
import AppModels
import DesignSystem
import Observation
import SwiftUI
import UIKit

@MainActor
@Observable
final class AgeGateModel {
    enum Phase: Equatable {
        case form
        /// `age_gate_not_configured`: sign-up is not open yet (min_age_years null).
        case notConfigured
        case offline
    }

    let entry: BirthdayEntry
    private(set) var text = ""
    var optIn = false
    private(set) var phase: Phase = .form
    private(set) var isChecking = false
    /// "invalid date" (presentation BLOCKED; announced to VoiceOver).
    private(set) var invalidDate = false
    private(set) var successCount = 0
    private(set) var errorCount = 0

    private let data: AccountDataSource

    init(data: AccountDataSource, entry: BirthdayEntry = BirthdayEntry()) {
        self.data = data
        self.entry = entry
    }

    /// `auth.agegate.field.placeholder` with the locale's pattern ({date_format}).
    var placeholder: String { Copy.authAgegateFieldPlaceholder(dateFormat: entry.placeholderFormat) }

    var canContinue: Bool { entry.isComplete(text) && !isChecking }

    func setText(_ newValue: String) {
        text = entry.edit(from: text, to: newValue)
    }

    enum Outcome: Equatable {
        case confirmed
        /// `under_minimum_age`; carries `public_app_config.min_age_years` for `{min_age}`.
        case underAge(minAge: Int?)
        case stay
    }

    /// `confirm_age(p_birthdate)`, then `set_birthday(p_birthday, true)` when opted in.
    func confirm() async -> Outcome {
        guard canContinue else { return .stay }
        invalidDate = false
        guard let birthdate = entry.date(from: text) else {
            failInvalid()
            return .stay
        }
        isChecking = true
        defer { isChecking = false }
        do {
            try await data.confirmAge(birthdate: birthdate)
            if optIn {
                try await data.setBirthday(birthdate, optIn: true)
            }
            successCount += 1
            return .confirmed
        } catch {
            switch DataError.from(error) {
            case .api(.ageGateNotConfigured, _):
                phase = .notConfigured
                errorCount += 1
            case .api(.underMinimumAge, _):
                errorCount += 1
                let minAge = try? await data.publicConfig().minAgeYears
                return .underAge(minAge: minAge)
            case .api(.invalidBirthdate, _), .api(.invalidBirthday, _):
                failInvalid()
            case .offline:
                phase = .offline
            default:
                // Not in the spec's States table (e.g. set_birthday failed after the age was confirmed): the person
                // stays on the step and can try again (confirm_age keeps the first confirmation).
                errorCount += 1
            }
            return .stay
        }
    }

    private func failInvalid() {
        invalidDate = true
        errorCount += 1
        UIAccessibility.post(notification: .announcement, argument: Copy.authAgegateErrorInvalidDate)
    }

    /// Retry pill of the not-open / offline states.
    func retry() {
        phase = .form
    }
}
