// Shared helpers for the account group's tests (AppTests/Account): in-memory data with a signed-in member, a session
// rig, and a wait for work the models start in their own tasks.
@testable import App
import AppData
import AppModels
import DesignSystem
import Foundation
import UIKit
import XCTest

/// People and groups used across the account tests (fixture data, not user-facing).
@MainActor
struct AccountFixture {
    let data: InMemoryAccountData
    let me: Profile
    let rui: Profile

    /// A signed-in, onboarded member ("Ana Lima") and a second person ("Rui Costa").
    init() {
        let data = InMemoryAccountData()
        let me = data.addProfile("Ana Lima")
        let rui = data.addProfile("Rui Costa")
        data.currentUserID = me.id
        data.privateProfile = ProfilePrivate(
            userID: me.id, birthday: nil, birthdayOptIn: false,
            ageConfirmedAt: Date(timeIntervalSince1970: 1_790_000_000), updatedAt: Date(timeIntervalSince1970: 1_790_000_000)
        )
        self.data = data
        self.me = me
        self.rui = rui
    }

    /// A group Ana created with Rui in it.
    @discardableResult
    func familyGroup(posts: Int = 0) -> PhotoGroup {
        let group = data.addGroup("Lima family", kind: .family, createdBy: me.id, members: [me, rui])
        for index in 0..<posts {
            data.addPost(groupID: group.id, author: index.isMultiple(of: 2) ? rui.id : me.id, minutesAgo: 5 + index * 10)
        }
        return group
    }
}

/// `AccountSession` with in-memory records, a fixed notification answer and a fresh router.
@MainActor
final class AccountSessionRig {
    let data: InMemoryAccountData
    let router = AppRouter(parser: .init(universalLinkHosts: []))
    let refusals = InMemoryAgeGateRefusalStore()
    let defaults: UserDefaults
    let onboarding: OnboardingRecord
    let notifications: StaticNotificationAuthorizer
    let toasts = ToastCenter()
    let shell = ShellState()
    let session: AccountSession

    init(data: InMemoryAccountData? = nil, notificationStatus: PermissionStatus = .notDetermined) {
        let data = data ?? InMemoryAccountData()
        self.data = data
        let suite = "account.tests." + UUID().uuidString
        defaults = UserDefaults(suiteName: suite) ?? .standard
        onboarding = OnboardingRecord(defaults: defaults)
        notifications = StaticNotificationAuthorizer(status: notificationStatus)
        session = AccountSession(
            data: data, router: router, refusals: refusals, onboarding: onboarding,
            notifications: notifications, toasts: toasts, shell: shell
        )
    }
}

/// Waits (on the main actor) until `condition` holds; fails after `timeout`.
@MainActor
func waitUntil(
    timeout: TimeInterval = 2,
    file: StaticString = #filePath,
    line: UInt = #line,
    _ condition: () -> Bool
) async {
    let deadline = Date().addingTimeInterval(timeout)
    while !condition() {
        if Date() > deadline {
            XCTFail("condition not met within \(timeout) s", file: file, line: line)
            return
        }
        try? await Task.sleep(nanoseconds: 5_000_000)
    }
}

private final class RecordingFlag {
    var isSet = false
}

/// Records every distinct value `read` takes while `work` runs (the phases a screen goes through).
@MainActor
func recordStates<Value: Equatable>(of read: @escaping () -> Value, during work: @escaping () async -> Void) async -> [Value] {
    var states = [read()]
    let finished = RecordingFlag()
    let task = Task { @MainActor in
        await work()
        finished.isSet = true
    }
    while !finished.isSet {
        let value = read()
        if value != states.last { states.append(value) }
        await Task.yield()
    }
    _ = await task.value
    let value = read()
    if value != states.last { states.append(value) }
    return states
}

/// Real sample photos (fixtures/photos/, `SamplePhotos`) for the account screens' avatars, group covers and posts.
///
/// `StorageImage` / `AvatarView` draw on their first frame only what the app's `ImagePipeline` already holds (a
/// snapshot does not wait for loads), so `prepare` gives every person an avatar and every group a cover, then decodes
/// each storage path's photo into the pipeline at the pixel buckets the screens ask for (frames below, at 2× and 3×).
@MainActor
enum AccountSamplePhotos {
    /// People and groups of the account fixtures by name; anyone else gets a photo picked from their id.
    static let people = ["Ana Lima": "avatar-01", "Rui Costa": "avatar-06", "Marta Lima": "avatar-03", "Sam Lee": "avatar-02"]
    static let groups = ["Lima family": "grandma-hug-4x3", "Sunday dinners": "dinner-long-table-3x4"]

    /// Avatar and cover frames (points): the C-23 avatar sizes (`size.global.avatarSmall`, `.avatarList`, `.avatarComment`,
    /// `.avatarPicker`, `.avatarHeader`, `.avatarProfile`, `.avatarGrid` — the tab bar no longer shows an avatar) and
    /// `groups.screen.size.profileAvatar`.
    static var avatarFrames: [ClosedRange<CGFloat>] {
        [Tokens.Sizes.globalAvatarSmall, Tokens.Sizes.globalAvatarList, Tokens.Sizes.globalAvatarComment,
         Tokens.Sizes.globalAvatarPicker, Tokens.Sizes.globalAvatarHeader, Tokens.Sizes.globalAvatarProfile,
         Tokens.Sizes.globalAvatarGrid, Tokens.Sizes.groupsScreenSizeProfileAvatar].map { $0...$0 }
    }

    /// The groups.create cover (`groups.create.size.cover.width`, narrower screens keep the aspect).
    static var coverFrames: [ClosedRange<CGFloat>] {
        avatarFrames + [(Tokens.Sizes.groupsCreateSizeCoverWidth * 0.9)...Tokens.Sizes.groupsCreateSizeCoverWidth]
    }

    /// Longest side of the frames a post shows in: the groups.screen card and the groups.list cover (screen wide),
    /// the profile grid's tiles (a third of the screen, `walls.mine.aspectRatio.gridTile`).
    static let postFrames: [ClosedRange<CGFloat>] = [340...393, 150...180]

    /// Gives every profile without one an avatar and every group without one a cover (`sample/<photo>.jpg`).
    static func dress(_ data: InMemoryAccountData) {
        for (id, profile) in data.profilesByID where profile.avatarPath == nil {
            data.profilesByID[id]?.avatarPath = path(people[profile.displayName] ?? SamplePhotos.avatarName(forKey: id.rawValue))
        }
        for index in data.groups.indices where data.groups[index].coverPath == nil {
            let group = data.groups[index]
            data.groups[index].coverPath = path(groups[group.name] ?? SamplePhotos.name(forKey: group.id.rawValue))
        }
        for (groupID, members) in data.membersByGroup {
            data.membersByGroup[groupID] = members.map { member in
                var member = member
                if let id = member.profile?.id { member.profile = data.profilesByID[id] }
                return member
            }
        }
    }

    /// `dress`, then every avatar, cover and post photo of `data` into the image pipeline.
    static func prepare(_ data: InMemoryAccountData) async {
        dress(data)
        for profile in data.profilesByID.values {
            if let path = profile.avatarPath { await warm(path: path, frames: avatarFrames) }
        }
        for group in data.groups {
            if let path = group.coverPath { await warm(path: path, frames: coverFrames) }
        }
        for post in data.postsByGroup.values.flatMap({ $0 }) {
            guard let media = post.media else { continue }
            for path in Set([media.imagePath(for: .display), media.imagePath(for: .thumb)].compactMap { $0 }) {
                await warm(path: path, frames: postFrames)
            }
        }
    }

    /// The photo for a storage path: `sample/<photo>.jpg` names it; a post's media id (`…-<n>`, sequential in the
    /// in-memory data) picks the nth portrait, so a group's posts never repeat a photo.
    static func photo(for path: String) -> String {
        if path.hasPrefix(prefix) { return String(path.dropFirst(prefix.count).dropLast(4)) }
        let parts = path.split(separator: "/")
        if parts.count >= 3, let number = Int(parts[2].split(separator: "-").last ?? "") {
            return SamplePhotos.name(index: number)
        }
        return SamplePhotos.name(forKey: path)
    }

    /// Decodes the photo for `path` into `ImagePipeline.shared` at every pixel bucket a frame in `frames` (longest side,
    /// points) asks for at 2× and 3×.
    static func warm(path: String, frames: [ClosedRange<CGFloat>]) async {
        let url = SamplePhotos.url(named: photo(for: path))
        var buckets = Set<Int>()
        for frame in frames {
            for scale: CGFloat in [2, 3] {
                let low = Int((frame.lowerBound * scale).rounded(.up))
                let high = Int((frame.upperBound * scale).rounded(.up))
                for pixels in stride(from: low, through: high, by: 64) { buckets.insert(ImagePipeline.pixelBucket(pixels)) }
                buckets.insert(ImagePipeline.pixelBucket(high))
            }
        }
        for bucket in buckets.sorted() where ImagePipeline.shared.cachedImage(path: path, pixels: bucket) == nil {
            _ = await ImagePipeline.shared.image(path: path, url: url, pixels: bucket)
        }
    }

    private static let prefix = "sample/"

    private static func path(_ photo: String) -> String {
        prefix + photo + ".jpg"
    }
}
