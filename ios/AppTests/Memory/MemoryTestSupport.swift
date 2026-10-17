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
    /// C-26 confirmations (iOS: announced; the last one is kept).
    let toasts = ToastCenter()
    /// VoiceOver running (the year story starts paused).
    var isVoiceOverRunning = false
    private(set) var haptics: [DSHaptic] = []
    private(set) var openedGroups: [String] = []
    private(set) var openedOnThisDay: [String] = []
    private(set) var reports: [ReportTarget] = []

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
            openOnThisDay: { [weak self] id in self?.openedOnThisDay.append(id) },
            openReport: { [weak self] target in self?.reports.append(target) },
            toasts: toasts,
            isVoiceOverRunning: { [weak self] in self?.isVoiceOverRunning ?? false },
            cache: cache,
            sleep: { try await sleeper.sleep($0) }
        )
    }

    /// Dependencies without a backend (config/app.json not provided).
    var unconfigured: MemoryDependencies {
        MemoryDependencies(data: nil, images: images, haptics: { _ in }, defaults: defaults, toasts: toasts, cache: cache)
    }

    /// The last confirmation shown (C-26).
    var lastToast: String? { toasts.message }

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
    static func media(_ number: Int) -> MediaID { MemoryFixtureIDs.media(number) }
}

/// Real sample photos (fixtures/photos/, `SamplePhotos`) for the memory fixtures (`FixtureMemoryData.scenario`).
enum MemorySamplePhotos {
    /// The scenario's posts in order (shapes 3:4, 4:3, 3:4, 1:1, 3:4 this year; 3:4 a year ago at night; 4:3, 3:4, 3:5
    /// three years ago in the evening).
    static let posts = [
        "dinner-toast-candles-3x4", "family-dinner-4x3", "friends-stairs-laughing-3x4", "kids-bubbles-1x1",
        "hike-meadow-trail-3x4", "concert-confetti-3x4", "campfire-friends-3x2", "dinner-long-table-3x4", "sunset-sea-9x16",
    ]

    /// Longest side of the cropped photos, in pixels.
    static let longSide: CGFloat = 1080

    /// The `index`th post's photo cropped to `width` : `height`.
    static func photo(index: Int, width: Int, height: Int) -> UIImage {
        let name = posts.indices.contains(index) ? posts[index] : SamplePhotos.name(index: index)
        let aspect = CGFloat(max(width, 1)) / CGFloat(max(height, 1))
        let size = aspect >= 1
            ? CGSize(width: longSide, height: (longSide / aspect).rounded())
            : CGSize(width: (longSide * aspect).rounded(), height: longSide)
        return SamplePhotos.photo(named: name, size: size)
    }

    /// A member avatar of the scenario (`avatars/<uid>/a.jpg`), a real sample portrait.
    static func avatar(index: Int) -> UIImage {
        SamplePhotos.image(named: SamplePhotos.avatarName(index: index))
    }

    /// A square collage of the first photos (at least four, a full grid two across).
    static func collage(posts count: Int) -> UIImage {
        let tiles = count <= 4 ? 4 : 6
        return SamplePhotos.collage(size: CGSize(width: longSide, height: longSide), names: Array(posts.prefix(tiles)), columns: 2, gap: 8)
    }

    /// The tribute video's poster (16:9).
    static var poster: UIImage {
        SamplePhotos.photo(named: "baby-bow-blanket-4x5", size: CGSize(width: 1280, height: 720))
    }
}
