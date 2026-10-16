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

    private(set) var phase: Phase = .idle
    /// The date field's text (`auth.agegate` entry rules: digits in the locale's order, separators inserted).
    private(set) var dateText = ""
    private(set) var inline: Inline?
    /// The save failed: the C-27 error block above the capsule; the capsule retries.
    private(set) var showsError = false
    private(set) var isSaving = false
    /// "Remove Birthday" asks first (C-29 confirmation).
    var showsRemoveConfirmation = false
    /// Set when the screen should close.
    private(set) var outcome: Outcome?

    /// The `auth.agegate` date entry (account group's `BirthdayEntry`: `auth.agegate.layout.dateEntry`).
    let entry: BirthdayEntry
    private let dependencies: MemoryDependencies

    init(dependencies: MemoryDependencies, entry: BirthdayEntry = BirthdayEntry()) {
        self.dependencies = dependencies
        self.entry = entry
    }

    /// `auth.agegate.field.placeholder` with the locale's pattern ({date_format}), as the age gate shows it.
    var placeholder: String { Copy.authAgegateFieldPlaceholder(dateFormat: entry.placeholderFormat) }

    /// The field's edit rules (`BirthdayEntry.edit`); a new edit clears the inline line.
    func setText(_ newValue: String) {
        let formatted = entry.edit(from: dateText, to: newValue)
        if formatted != dateText, inline == .invalid { inline = nil }
        dateText = formatted
    }

    /// The typed day, when complete and valid.
    var typedDate: LocalDate? { entry.date(from: dateText) }

    /// "disabled until the field holds a complete date".
    var canConfirm: Bool { entry.isComplete(dateText) && !isSaving }

    private static let cacheKey = "birthday.add" // provenance-ok: cache key

    /// The saved opt-in, cached for the session (`.some(nil)` = not opted in).
    private struct Cached {
        let birthday: LocalDate?
    }

    func loadIfNeeded() async {
        guard phase == .idle else { return }
        guard let data = dependencies.data else {
            phase = .add
            return
        }
        let me = await data.currentUser()
        if let cached = dependencies.cache.value(Cached.self, key: Self.cacheKey, user: me) {
            phase = cached.birthday.map(Phase.manage) ?? .add
        } else {
            phase = .loading
        }
        do {
            let row = try await data.myPrivateProfile()
            let saved = row.flatMap { $0.birthdayOptIn ? $0.birthday : nil }
            dependencies.cache.set(Cached(birthday: saved), key: Self.cacheKey, user: me)
            if !isSaving { phase = saved.map(Phase.manage) ?? .add }
        } catch {
            // The opt-in can still be added (set_birthday overwrites); offline is said under the field.
            if phase == .loading { phase = .add }
            if MemoryFailure(error) == .offline { inline = .offline }
        }
    }

    private func store(_ birthday: LocalDate?) async {
        let me = await dependencies.data?.currentUser()
        dependencies.cache.set(Cached(birthday: birthday), key: Self.cacheKey, user: me)
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
            await store(date)
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

    /// "Remove Birthday": the native confirmation first.
    func requestRemove() {
        guard case .manage = phase, !isSaving else { return }
        showsRemoveConfirmation = true
    }

    /// "Yes, remove" (`haptic.global.warning`). Optimistic: the add form shows at once; on failure the saved birthday comes
    /// back with the error. Removing deletes requests about you that are not yet due (`set_birthday`).
    func remove() async {
        guard case let .manage(saved) = phase, !isSaving else { return }
        dependencies.haptics(Tokens.Haptics.globalWarning)
        showsError = false
        isSaving = true
        defer { isSaving = false }
        guard let data = dependencies.data else {
            fail(.generic)
            return
        }
        dateText = ""
        phase = .add
        do {
            _ = try await data.setBirthday(saved, optIn: false)
            dependencies.haptics(Tokens.Haptics.globalSuccess)
            await store(nil)
            dependencies.toasts.show(Copy.birthdayAddRemoved)
        } catch {
            phase = .manage(saved)
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
