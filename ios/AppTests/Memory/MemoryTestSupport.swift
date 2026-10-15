// Shared helpers for the memory group's tests (AppTests/Memory).
@testable import App
import AppData
import DesignSystem
import Foundation
import UIKit
import XCTest

/// Fixture data, a test clock, a hand-driven sleep, recorded haptics and a private cache / defaults per test.
@MainActor
final class MemoryTestContext {
    let data: FixtureMemoryData
    /// The dependencies' clock; fixed unless a test moves it.
    let clock: MemoryTestClock
    /// The year story's card timer: its sleeps end only when a test fires them.
    let sleeper = MemoryTestSleeper()
    let cache = MemoryCache()
    let images = MemoryTestImages()
    let defaults: UserDefaults
    private(set) var haptics: [DSHaptic] = []
    private(set) var openedGroups: [String] = []

    /// 2026-10-15 12:00 UTC unless given.
    init(now: Date = MemoryTestContext.referenceNow, configure: (inout FixtureMemoryData.State) -> Void = { _ in }) {
        clock = MemoryTestClock(now)
        let data = FixtureMemoryData.scenario(now: now)
        data.update(configure)
        self.data = data
        let suite = "memory.tests." + UUID().uuidString
        defaults = UserDefaults(suiteName: suite) ?? .standard
    }

    nonisolated static let referenceNow = Date(timeIntervalSince1970: 1_792_065_600) // 2026-10-15T12:00:00Z

    var now: Date { clock.date }

    var dependencies: MemoryDependencies {
        let clock = self.clock
        let sleeper = self.sleeper
        return MemoryDependencies(
            data: data,
            images: images,
            now: { clock.date },
            haptics: { [weak self] haptic in self?.haptics.append(haptic) },
            defaults: defaults,
            openGroup: { [weak self] id in self?.openedGroups.append(id) },
            cache: cache,
            sleep: { try await sleeper.sleep($0) }
        )
    }

    /// Dependencies without a backend (config/app.json not provided).
    var unconfigured: MemoryDependencies {
        MemoryDependencies(data: nil, images: images, haptics: { _ in }, defaults: defaults, cache: cache)
    }

    func clearHaptics() {
        haptics.removeAll()
    }
}

/// Images by URL, synchronously available (no network in tests).
@MainActor
final class MemoryTestImages: MemoryImageLoading {
    var images: [URL: UIImage] = [:]
    private(set) var requested: [URL] = []

    func cachedImage(for url: URL) -> UIImage? {
        images[url]
    }

    func image(for url: URL, maxPixelSize: CGFloat?) async -> UIImage? {
        requested.append(url)
        return images[url]
    }
}

/// A clock tests move by hand.
final class MemoryTestClock: @unchecked Sendable {
    private let lock = NSLock()
    private var current: Date

    init(_ date: Date) {
        current = date
    }

    var date: Date {
        lock.lock()
        defer { lock.unlock() }
        return current
    }

    func advance(by seconds: TimeInterval) {
        lock.lock()
        current = current.addingTimeInterval(seconds)
        lock.unlock()
    }
}

/// Stands in for `Task.sleep`: every sleep waits until `fire()` (or its task is cancelled, which
/// throws `CancellationError` as `Task.sleep` does).
final class MemoryTestSleeper: @unchecked Sendable {
    private let lock = NSLock()
    private var waiters: [UUID: CheckedContinuation<Void, Error>] = [:]
    private var cancelled: Set<UUID> = []
    private var log: [TimeInterval] = []

    /// Every duration slept (not counting sleeps cancelled before they began), in order.
    var requested: [TimeInterval] {
        lock.lock()
        defer { lock.unlock() }
        return log
    }

    /// Sleeps not yet ended.
    var pending: Int {
        lock.lock()
        defer { lock.unlock() }
        return waiters.count
    }

    func sleep(_ seconds: TimeInterval) async throws {
        let id = UUID()
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                lock.lock()
                if cancelled.remove(id) != nil {
                    lock.unlock()
                    continuation.resume(throwing: CancellationError())
                } else {
                    log.append(seconds)
                    waiters[id] = continuation
                    lock.unlock()
                }
            }
        } onCancel: {
            lock.lock()
            let waiter = waiters.removeValue(forKey: id)
            if waiter == nil { cancelled.insert(id) }
            lock.unlock()
            waiter?.resume(throwing: CancellationError())
        }
    }

    /// Ends every pending sleep.
    func fire() {
        lock.lock()
        let all = Array(waiters.values)
        waiters.removeAll()
        lock.unlock()
        for waiter in all { waiter.resume() }
    }
}

/// Waits (yielding) until `condition` holds, for streams delivered on other tasks.
@MainActor
@discardableResult
func memoryEventually(_ condition: () -> Bool, attempts: Int = 200) async -> Bool {
    for _ in 0..<attempts {
        if condition() { return true }
        await Task.yield()
        try? await Task.sleep(nanoseconds: 1_000_000)
    }
    return condition()
}

enum MemoryIDs {
    static let me = MemoryFixtureIDs.me
    static let friend = MemoryFixtureIDs.friend
    static let other = MemoryFixtureIDs.other
    static let group = MemoryFixtureIDs.group
    static let request = MemoryFixtureIDs.request
    static let tribute = MemoryFixtureIDs.tribute
    static func post(_ number: Int) -> PostID { MemoryFixtureIDs.post(number) }
}
