// Surface: tagging — state and behaviour of the "i'm in this" self-tag (design/surfaces/tagging.md).
// Only ever tags the caller (`tag_self` / `untag_self`); no face recognition, no counts, nobody is notified.
import AppData
import DesignSystem
import Foundation
import Observation

@MainActor
@Observable
final class SelfTagModel {
    /// The toast lines of `tagging` (`tagging.error`, `.notFound`, `.offline`).
    enum Message: Equatable {
        case error
        case notFound
        case offline

        var text: String {
            switch self {
            case .error: return Copy.taggingError
            case .notFound: return Copy.taggingNotFound
            case .offline: return Copy.taggingOffline
            }
        }
    }

    private(set) var isOn: Bool
    /// One call in flight per photo; taps are ignored meanwhile.
    private(set) var isPending = false
    /// False until the state is known (read from `post_tags` when the host did not pass it).
    private(set) var isKnown: Bool
    private(set) var coachVisible = false
    /// The last toast line (the host shows it); set again for every failure.
    var message: Message?
    /// The photo is gone (`post_not_found`): the viewer closes it.
    private(set) var isGone = false

    let postID: PostID
    /// The coach appears on photos someone else posted, once per account.
    let isOthersPhoto: Bool
    private let dependencies: MemoryDependencies

    init(postID: PostID, isTagged: Bool?, isOthersPhoto: Bool, dependencies: MemoryDependencies) {
        self.postID = postID
        self.isOn = isTagged ?? false
        self.isKnown = isTagged != nil
        self.isOthersPhoto = isOthersPhoto
        self.dependencies = dependencies
    }

    static func coachKey(_ user: UserID) -> String {
        "memory.tagging.coachSeen." + user.rawValue // provenance-ok: defaults key, not UI text
    }

    func loadIfNeeded() async {
        guard let data = dependencies.data else { return }
        if isOthersPhoto, let me = await data.currentUser(), !dependencies.defaults.bool(forKey: Self.coachKey(me)) {
            coachVisible = true
        }
        guard !isKnown else { return }
        if let value = try? await data.isTagged(postID: postID) {
            isOn = value
            isKnown = true
        }
    }

    /// ✕ on the coach, or any tap on the toggle: gone for good on this account.
    func dismissCoach() async {
        guard coachVisible else { return }
        coachVisible = false
        if let me = await dependencies.data?.currentUser() {
            dependencies.defaults.set(true, forKey: Self.coachKey(me))
        }
    }

    /// Optimistic: flips at once, calls `tag_self` / `untag_self`, reverts on failure.
    func toggle() async {
        guard !isPending, !isGone else { return }
        await dismissCoach()
        guard let data = dependencies.data else {
            fail(.error)
            return
        }
        if await data.networkStatus() == .offline {
            fail(.offline)
            return
        }
        let previous = isOn
        isOn.toggle()
        isKnown = true
        isPending = true
        dependencies.haptics(Tokens.Haptics.globalSelect)
        defer { isPending = false }
        do {
            if previous {
                try await data.untagSelf(postID: postID)
            } else {
                try await data.tagSelf(postID: postID)
            }
        } catch {
            isOn = previous
            switch MemoryFailure(error) {
            case .notFound:
                isGone = true
                fail(.notFound)
            case .offline:
                fail(.offline)
            default:
                fail(.error)
            }
        }
    }

    private func fail(_ message: Message) {
        dependencies.haptics(Tokens.Haptics.globalError)
        self.message = nil
        self.message = message
    }
}
