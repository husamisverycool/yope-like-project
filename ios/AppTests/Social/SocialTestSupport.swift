// Helpers for the social view-model tests (ios/AppTests/Social/Social*Tests.swift).
@testable import App
import AppData
import AppModels
import Foundation
import XCTest

/// Waits (polling the main actor) until `condition` holds or `timeout` passes.
@MainActor
func socialEventually(timeout: TimeInterval = 3, _ condition: @MainActor () -> Bool) async -> Bool {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
        if condition() { return true }
        try? await Task.sleep(nanoseconds: 5_000_000)
    }
    return condition()
}

/// A photo saver that records what it saved, or refuses like a denied add-only permission.
final class RecordingPhotoSaver: SocialPhotoSaving, @unchecked Sendable {
    private let lock = NSLock()
    private var saved: [(MediaKind, URL, URL?)] = []
    let denied: Bool

    init(denied: Bool = false) {
        self.denied = denied
    }

    var savedCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return saved.count
    }

    var lastMotionURL: URL? {
        lock.lock()
        defer { lock.unlock() }
        return saved.last?.2
    }

    func save(kind: MediaKind, fileURL: URL, motionURL: URL?) async throws {
        if denied { throw SocialSaveFailure.notAuthorized }
        record(kind, fileURL, motionURL)
    }

    private func record(_ kind: MediaKind, _ fileURL: URL, _ motionURL: URL?) {
        lock.lock()
        saved.append((kind, fileURL, motionURL))
        lock.unlock()
    }
}

/// Fresh `UserDefaults` per test (coach flags, recent emoji).
func socialTestFlags(_ name: String = #function) -> SocialFlags {
    let suite = "social.tests." + name
    let defaults = UserDefaults(suiteName: suite)!
    defaults.removePersistentDomain(forName: suite)
    return SocialFlags(defaults: defaults)
}

extension String {
    /// True when the string contains a decimal digit (tenet: no counts anywhere).
    var socialContainsDigit: Bool { unicodeScalars.contains { CharacterSet.decimalDigits.contains($0) } }
}
