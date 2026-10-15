import Foundation

/// Decides whether the premium prompt may be shown: at most once per app session, and never
/// while capturing or during onboarding (surface `paywall`).
///
/// The app decides what a session is by calling `startSession()`; the gate itself only counts.
public struct SessionPromptGate: Hashable, Sendable {
    /// Activities during which the prompt must not appear.
    public enum Blocker: Hashable, Sendable, CaseIterable {
        case capture
        case onboarding
    }

    public private(set) var sessionNumber = 0
    public private(set) var hasPromptedInSession = false

    public init() {}

    /// Begins a new session; the prompt becomes available again.
    public mutating func startSession() {
        sessionNumber += 1
        hasPromptedInSession = false
    }

    public func canPrompt(activeBlockers: Set<Blocker>) -> Bool {
        sessionNumber > 0 && !hasPromptedInSession && activeBlockers.isEmpty
    }

    /// Returns true (and records the prompt) when the prompt may be shown now.
    public mutating func consumePrompt(activeBlockers: Set<Blocker>) -> Bool {
        guard canPrompt(activeBlockers: activeBlockers) else { return false }
        hasPromptedInSession = true
        return true
    }
}
