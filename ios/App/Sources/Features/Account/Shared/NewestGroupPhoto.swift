// Account group — the newest photo across the person's groups: the onboarding.widget preview tile and the paywall's
// benefit media card and backdrop (MERGE RA-18: real content, never Retro's graphics). Data only through
// `AccountDataSource` (docs/SCREENS_BRIEF.md rule 5).
import AppData
import AppModels
import Foundation

/// A photo from the person's groups and its sender's first name.
struct NewestGroupPhoto: Equatable {
    /// Storage path of the display rendition (signed through `StorageImage`).
    let path: String
    /// The sender's first name (nil when the profile is not readable).
    let firstName: String?

    /// The newest post with a photo across `data`'s groups (cached groups first, then the server's); nil when there is
    /// none or nothing could be read.
    @MainActor
    static func load(from data: AccountDataSource) async -> NewestGroupPhoto? {
        var groups = await data.cachedGroups() ?? []
        if let fresh = try? await data.myGroups() { groups = fresh }
        var newest: PostWithMedia?
        for group in groups {
            guard let post = try? await data.newestPost(groupID: group.id), post.media?.imagePath(for: .display) != nil else { continue }
            if newest.map({ post.post.createdAt > $0.post.createdAt }) ?? true { newest = post }
        }
        guard let newest, let path = newest.media?.imagePath(for: .display) else { return nil }
        let name = (try? await data.profiles(ids: [newest.post.authorID]))?.first?.firstName
        return NewestGroupPhoto(path: path, firstName: name)
    }
}
