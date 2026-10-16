// Surface: tagging — state and behaviour of the self-tag ("I'm in this" / "with {names}") (design/surfaces/tagging.md).
// Only ever tags the caller (`tag_self` / `untag_self`); no face recognition, no counts, nobody is notified. Tags are
// visible to the group's members (docs/API.md 5.11), in tag order.
import AppData
import DesignSystem
import Foundation
import Observation

@MainActor
@Observable
final class TagRunModel {
    /// A member tagged in the photo.
    struct Person: Identifiable, Equatable, Sendable {
        let id: UserID
        let firstName: String
        let avatarURL: URL?
    }

    /// The messages of `tagging` (C-26: iOS announces them; the reverted run is the visible part).
    enum Message: Equatable {
        case addFailed
        case removeFailed
        case notFound
        case offline

        var text: String {
            switch self {
            case .addFailed: return Copy.taggingError
            case .removeFailed: return Copy.taggingRemoveError
            case .notFound: return Copy.taggingNotFound
            case .offline: return Copy.taggingOffline
            }
        }
    }

    /// Tagged members in tag order (yours included).
    private(set) var people: [Person] = []
    /// The caller; known once loaded.
    private(set) var me: Person?
    /// One call in flight per photo; taps are ignored meanwhile.
    private(set) var isPending = false
    /// False until the tags are known (read from `post_tags` when the host did not pass them).
    private(set) var isKnown: Bool
    /// The last failure (the host may show it); set again for every failure.
    var message: Message?
    /// The photo is gone (`post_not_found`): the viewer closes it.
    private(set) var isGone = false

    let postID: PostID
    private let hostUserIDs: [UserID]?
    private let dependencies: MemoryDependencies

    /// - Parameter taggedUserIDs: the post's tags in tag order from the host's `post_tags` read; nil = read them here.
    init(postID: PostID, taggedUserIDs: [UserID]? = nil, dependencies: MemoryDependencies) {
        self.postID = postID
        hostUserIDs = taggedUserIDs
        isKnown = taggedUserIDs != nil
        self.dependencies = dependencies
    }

    var isTagged: Bool {
        guard let me else { return false }
        return people.contains { $0.id == me.id }
    }

    /// `tagging.with` names: the tagged members' first names, joined by the platform list formatter.
    var namesText: String {
        MemoryFormat.names(people.map(\.firstName))
    }

    /// Resolves names and avatars (and the tags themselves when the host did not pass them).
    func load() async {
        guard let data = dependencies.data else { return }
        do {
            let ids: [UserID]
            if let hostUserIDs {
                ids = hostUserIDs
            } else {
                ids = try await data.tags(postID: postID).map(\.userID)
            }
            let current = await data.currentUser()
            let wanted = Array(Set(ids + [current].compactMap { $0 }))
            let profiles = try await data.profiles(ids: wanted)
            let urls = try await data.signedURLs(paths: profiles.compactMap(\.avatarPath))
            let byID = Dictionary(profiles.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
            func person(_ id: UserID) -> Person {
                let profile = byID[id]
                return Person(id: id, firstName: profile?.firstName ?? "", avatarURL: profile?.avatarPath.flatMap { urls[$0] })
            }
            me = current.map(person)
            // A tag whose profile is hidden by a block is not shown (RLS drops the profile).
            people = ids.filter { byID[$0] != nil }.map(person)
            isKnown = true
        } catch {
            if MemoryFailure(error) == .notFound { isGone = true }
        }
    }

    /// The run, untagged: "I'm in this" tags you at once (optimistic) and calls `tag_self`.
    func tag() async {
        guard !isTagged else { return }
        await change(adding: true)
    }

    /// "Remove tag" on your row: untagged at once and `untag_self`; your row leaves the list.
    func untag() async {
        guard isTagged else { return }
        await change(adding: false)
    }

    private func change(adding: Bool) async {
        guard !isPending, !isGone else { return }
        guard let data = dependencies.data, let me else {
            fail(adding ? .addFailed : .removeFailed)
            return
        }
        if await data.networkStatus() == .offline {
            fail(.offline)
            return
        }
        let previous = people
        if adding {
            people.append(me)
        } else {
            people.removeAll { $0.id == me.id }
        }
        isPending = true
        dependencies.haptics(Tokens.Haptics.globalSelect)
        defer { isPending = false }
        do {
            if adding {
                try await data.tagSelf(postID: postID)
            } else {
                try await data.untagSelf(postID: postID)
            }
        } catch {
            people = previous
            switch MemoryFailure(error) {
            case .notFound:
                isGone = true
                fail(.notFound)
            case .offline:
                fail(.offline)
            default:
                fail(adding ? .addFailed : .removeFailed)
            }
        }
    }

    private func fail(_ message: Message) {
        dependencies.haptics(Tokens.Haptics.globalError)
        dependencies.toasts.show(message.text)
        self.message = nil
        self.message = message
    }
}
