// Surface: birthday.add — view model. Spec: design/surfaces/birthday.add.md.
import AppData
import DesignSystem
import Foundation
import Observation

@MainActor
@Observable
final class BirthdayAddModel {
    enum Phase: Equatable {
        case idle
        /// Reading `profile_private` (opt-in state).
        case loading
        /// Not opted in: the add form.
        case add
        /// Opted in: the saved day and month with "remove my birthday".
        case manage(LocalDate)
    }

    /// Inline line under the date field (`birthday.add.invalid` / `birthday.add.offline`).
    enum Inline: Equatable {
        case invalid
        case offline
    }

    /// How the screen was left, for the presenter (e.g. to show its own toast).
    enum Outcome: Equatable {
        case added
        case dismissed
    }

    var phase: Phase = .idle
    var dateText = ""
    var inline: Inline?
    /// The save failed: error texts above the buttons; the primary button retries.
    var showsError = false
    var isSaving = false
    var toast: MemoryToastMessage?
    /// Set when the screen should close.
    var outcome: Outcome?

    let entry: BirthdayDateEntry
    private let dependencies: MemoryDependencies

    init(dependencies: MemoryDependencies, entry: BirthdayDateEntry = BirthdayDateEntry()) {
        self.dependencies = dependencies
        self.entry = entry
    }

    /// The typed day, when complete and valid.
    var typedDate: LocalDate? { entry.date(from: dateText) }

    /// "disabled until the field holds a complete date".
    var canConfirm: Bool { entry.isComplete(dateText) && !isSaving }

    func loadIfNeeded() async {
        guard phase == .idle else { return }
        phase = .loading
        guard let data = dependencies.data else {
            phase = .add
            return
        }
        do {
            if let row = try await data.myPrivateProfile(), row.birthdayOptIn, let birthday = row.birthday {
                phase = .manage(birthday)
            } else {
                phase = .add
            }
        } catch {
            // The opt-in can still be added (set_birthday overwrites); offline is said under the field.
            phase = .add
            if MemoryFailure(error) == .offline { inline = .offline }
        }
    }

    func confirm() async {
        guard canConfirm else { return }
        guard let date = typedDate else {
            inline = .invalid
            dependencies.haptics(Tokens.Haptics.globalError)
            return
        }
        inline = nil
        showsError = false
        isSaving = true
        defer { isSaving = false }
        guard let data = dependencies.data else {
            fail(.generic)
            return
        }
        do {
            _ = try await data.setBirthday(date, optIn: true)
            dependencies.haptics(Tokens.Haptics.globalSuccess)
            outcome = .added
        } catch {
            if case .api(.invalidBirthday, _) = DataError.from(error) {
                inline = .invalid
                dependencies.haptics(Tokens.Haptics.globalError)
            } else {
                fail(MemoryFailure(error))
            }
        }
    }

    func remove() async {
        guard case let .manage(saved) = phase, !isSaving else { return }
        showsError = false
        isSaving = true
        defer { isSaving = false }
        guard let data = dependencies.data else {
            fail(.generic)
            return
        }
        do {
            _ = try await data.setBirthday(saved, optIn: false)
            dependencies.haptics(Tokens.Haptics.globalSuccess)
            dateText = ""
            phase = .add
            toast = MemoryToastMessage(text: Copy.birthdayAddRemoved, showsCheckmark: true)
        } catch {
            fail(MemoryFailure(error))
        }
    }

    /// "maybe later": no call, close. The app never asks again on its own.
    func later() {
        outcome = .dismissed
    }

    private func fail(_ failure: MemoryFailure) {
        dependencies.haptics(Tokens.Haptics.globalError)
        if failure == .offline {
            inline = .offline
        } else {
            showsError = true
        }
    }
}
