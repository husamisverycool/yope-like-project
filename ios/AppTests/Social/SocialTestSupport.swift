// Helpers for the social view-model tests (ios/AppTests/Social/Social*Tests.swift).
@testable import App
import AppData
import AppModels
import Foundation
import UIKit
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

/// Snapshot images: real sample photos (fixtures/photos/, `SamplePhotos`) for the demo backend's storage paths
/// (`SocialDemo`: `fake/photo/<media>`, `fake/avatar/<person>`, `fake/cover/<group>`). Every rendition of a media is
/// the same picture, cropped to the demo media's 3:4.
enum SocialSamplePhotos {
    /// Posts by media suffix (p1–p6), matching what the demo chat and captions say.
    static let posts: [String: String] = [
        "01": "dinner-pizza-cheers-3x4", // Ben, after "who's cooking tonight?" / "i can do pasta"
        "02": "snow-forest-walk-3x4", // Ana: "first snow"
        "03": "hike-meadow-trail-3x4", // Sam, also sent to "climbing"
        "04": "dog-beach-run-3x4", // Cleo's Live Photo
        "05": "autumn-path-3x4", // Ana, last week
        "06": "picnic-spread-3x4", // Sam, last week: "picnic"
    ]

    /// People by user-id suffix: Sam Reed (me), Ana Lima, Ben Ortiz, Cleo Park, the stranger.
    static let people: [String: String] = ["01": "avatar-02", "02": "avatar-01", "03": "avatar-06", "04": "avatar-05", "09": "avatar-07"]

    /// Group covers by group-id suffix: "roommates", "climbing".
    static let covers: [String: String] = ["01": "movie-night-couch-4x3", "02": "hike-mountain-friends-3x4"]

    /// 3:4 at the photos' stored size.
    static let photoSize = CGSize(width: 810, height: 1080)
    static let coverSize = CGSize(width: 512, height: 512)

    static func image(for path: String) -> UIImage? {
        let parts = path.split(separator: "/").map(String.init)
        guard parts.count == 3, parts[0] == "fake" else {
            return SamplePhotos.photo(named: SamplePhotos.name(forKey: path), size: photoSize)
        }
        let key = parts[2]
        switch parts[1] {
        case "avatar": return SamplePhotos.image(named: people[key] ?? SamplePhotos.avatarName(forKey: key))
        case "cover": return SamplePhotos.photo(named: covers[key] ?? SamplePhotos.name(forKey: path), size: coverSize)
        case "photo": return SamplePhotos.photo(named: posts[key] ?? SamplePhotos.name(forKey: key), size: photoSize)
        default: return nil
        }
    }
}

extension SocialImageLoader {
    /// The snapshot tests' loader: `SocialSamplePhotos`, drawn synchronously like the DEBUG demo loader.
    static func samplePhotos() -> SocialImageLoader {
        SocialImageLoader { path in SocialSamplePhotos.image(for: path) }
    }
}
