// Shared helpers for the memory group's tests (AppTests/Memory).
@testable import App
import AppData
import DesignSystem
import Foundation
import UIKit
import XCTest

/// Fixture data, a fixed clock, recorded haptics and a private cache / defaults per test.
@MainActor
final class MemoryTestContext {
    let data: FixtureMemoryData
    let now: Date
    let cache = MemoryCache()
    let images = MemoryTestImages()
    let defaults: UserDefaults
    private(set) var haptics: [DSHaptic] = []
    private(set) var openedGroups: [String] = []

    /// 2026-10-15 12:00 UTC unless given.
    init(now: Date = MemoryTestContext.referenceNow, configure: (inout FixtureMemoryData.State) -> Void = { _ in }) {
        self.now = now
        let data = FixtureMemoryData.scenario(now: now)
        data.update(configure)
        self.data = data
        let suite = "memory.tests." + UUID().uuidString
        defaults = UserDefaults(suiteName: suite) ?? .standard
    }

    nonisolated static let referenceNow = Date(timeIntervalSince1970: 1_792_065_600) // 2026-10-15T12:00:00Z

    var dependencies: MemoryDependencies {
        let now = self.now
        return MemoryDependencies(
            data: data,
            images: images,
            now: { now },
            haptics: { [weak self] haptic in self?.haptics.append(haptic) },
            defaults: defaults,
            openGroup: { [weak self] id in self?.openedGroups.append(id) },
            cache: cache
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

/// Waits (yielding) until `condition` holds, for streams delivered on other tasks.
@MainActor
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
