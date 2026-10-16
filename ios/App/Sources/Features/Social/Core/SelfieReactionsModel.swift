// Surface: viewer.selfiereaction — react to a photo in photo.viewer with a live selfie (mechanics BeReal's Instant
// RealMoji, components Retro's). Spec: design/surfaces/viewer.selfiereaction.md ("Faces on the photo", "Rows in the
// Reactions sheet", "States", "Data & actions"; MERGE_DECISIONS SR-1 … SR-9); docs/API.md §14.1.
// The selfies of the viewer's photos: read, live updates, send (optimistic), remove. Foundation + Observation +
// AppData only; the capture layer, the faces and the sheet rows are SelfieReactionViews.swift.
import AppData
import AppModels
import Foundation
import Observation

/// The selfie reactions on one post: one per person (a new one replaces theirs), newest first by `created_at` — who
/// reacted, never how many (`viewer.selfiereaction.layout.stack`: no "+N", no number). Deliberately has no count API.
struct SelfieSummary: Equatable, Sendable {
    /// Newest first (`chat.reactions.layout.clusterOrder` for the faces, `chat.reactions.layout.listOrder` for the
    /// sheet); a row with the same time as another keeps the later-inserted one first.
    private(set) var rows: [SelfieReaction]

    init(_ rows: [SelfieReaction] = []) {
        self.rows = []
        for row in rows.sorted(by: { $0.createdAt < $1.createdAt }) { upsert(row) }
    }

    var isEmpty: Bool { rows.isEmpty }

    /// The faces drawn on the photo: the newest `limit` (`chat.reactions.count.clusterMaxVisible`), newest leading.
    func faces(limit: Int) -> [SelfieReaction] {
        Array(rows.prefix(max(0, limit)))
    }

    func selfie(by userID: UserID) -> SelfieReaction? {
        rows.first { $0.userID == userID }
    }

    /// Adds a selfie, replacing the person's earlier one (one per person and post).
    mutating func upsert(_ selfie: SelfieReaction) {
        rows.removeAll { $0.userID == selfie.userID }
        let index = rows.firstIndex { $0.createdAt <= selfie.createdAt } ?? rows.endIndex
        rows.insert(selfie, at: index)
    }

    mutating func remove(userID: UserID) {
        rows.removeAll { $0.userID == userID }
    }

    /// Groups rows by post.
    static func byPost(_ rows: [SelfieReaction]) -> [PostID: SelfieSummary] {
        var grouped: [PostID: [SelfieReaction]] = [:]
        for row in rows { grouped[row.postID, default: []].append(row) }
        return grouped.mapValues { SelfieSummary($0) }
    }
}

/// One row of the Reactions sheet: an emoji reaction or a selfie. Selfie rows sit among the emoji rows by time
/// (viewer.selfiereaction §4), newest first (`chat.reactions.layout.listOrder`).
enum ReactionsSheetEntry: Equatable, Sendable {
    case emoji(Reaction)
    case selfie(SelfieReaction)

    var createdAt: Date {
        switch self {
        case let .emoji(reaction): return reaction.createdAt
        case let .selfie(selfie): return selfie.createdAt
        }
    }

    /// Merges two lists that are each newest first; at the same time the emoji row comes first.
    static func merged(emoji: [Reaction], selfies: [SelfieReaction]) -> [ReactionsSheetEntry] {
        var result: [ReactionsSheetEntry] = []
        var emojiIndex = 0
        var selfieIndex = 0
        while emojiIndex < emoji.count || selfieIndex < selfies.count {
            let takeSelfie = emojiIndex >= emoji.count
                || (selfieIndex < selfies.count && selfies[selfieIndex].createdAt > emoji[emojiIndex].createdAt)
            if takeSelfie {
                result.append(.selfie(selfies[selfieIndex]))
                selfieIndex += 1
            } else {
                result.append(.emoji(emoji[emojiIndex]))
                emojiIndex += 1
            }
        }
        return result
    }
}

/// How a selfie call ended (the viewer marks a photo gone on `notFound`).
enum SelfieOutcome: Equatable, Sendable {
    case done
    case failed
    /// `post_not_found`: the photo was deleted or is hidden.
    case notFound
}

@MainActor
@Observable
final class SelfieReactionsModel {
    @ObservationIgnored private let data: any SocialDataSource

    private(set) var byPost: [PostID: SelfieSummary] = [:]
    /// The JPEG of selfies sent from this device, by row id: drawn instead of the stored file, so a face never blanks
    /// while its signed URL loads (`sending`: "your face appears at the leading end of the stack at once").
    private(set) var sentImages: [SelfieReactionID: Data] = [:]
    /// ≤ one send per photo in flight.
    private(set) var sending: Set<PostID> = []
    private(set) var signals = SocialSignals()

    init(data: any SocialDataSource) {
        self.data = data
    }

    func summary(for postID: PostID) -> SelfieSummary {
        byPost[postID] ?? SelfieSummary()
    }

    /// Everyone with a selfie on the loaded photos (their names are read for the rows and labels).
    var reactors: [UserID] {
        byPost.values.flatMap { $0.rows.map(\.userID) }.socialUnique()
    }

    /// Never on my own photo ("You cannot react to your own BeReal", HC 7536240858653).
    func canReact(to post: PostWithMedia, me: UserID?) -> Bool {
        guard let me else { return false }
        return post.post.authorID != me
    }

    // MARK: Reading

    /// The photos' selfies (viewer open, `reactions_changed`, back online). A selfie being sent keeps its place.
    func load(postIDs: [PostID]) async {
        guard !postIDs.isEmpty, let rows = try? await data.selfieReactions(postIDs: postIDs) else { return }
        let summaries = SelfieSummary.byPost(rows)
        for id in postIDs where !sending.contains(id) {
            byPost[id] = summaries[id] ?? SelfieSummary()
        }
    }

    func handle(_ event: GroupEvent) async {
        switch event {
        case let .selfieReactionUpserted(selfie):
            guard byPost[selfie.postID] != nil else { return }
            byPost[selfie.postID]?.upsert(selfie)
        case let .reactionsChanged(postID):
            // A removal names no one: read the post's selfies again.
            guard byPost[postID] != nil else { return }
            await load(postIDs: [postID])
        case .resubscribed:
            await load(postIDs: Array(byPost.keys))
        case let .postDeleted(postID, _):
            byPost[postID] = nil
        default:
            break
        }
    }

    // MARK: Sending (`react_with_selfie`)

    /// Sends a selfie: my face joins the leading end of the stack at once (replacing my earlier one) and is taken back
    /// out if the upload or the call fails (`viewer.selfiereaction.error`, `haptic.global.error`). Sent: the
    /// announcement `viewer.selfiereaction.a11y.sent`; no haptic (owner decision 15).
    @discardableResult
    func send(_ jpeg: Data, to post: PostWithMedia, me: UserID, now: Date = Date()) async -> SelfieOutcome {
        let postID = post.id
        guard canReact(to: post, me: me), !sending.contains(postID) else { return .failed }
        let before = summary(for: postID)
        let pending = SelfieReaction(
            id: before.selfie(by: me)?.id ?? SelfieReactionID(UUID()), postID: postID, userID: me,
            groupID: post.post.groupID, imagePath: "", createdAt: now
        )
        byPost[postID, default: SelfieSummary()].upsert(pending)
        sentImages[pending.id] = jpeg
        sending.insert(postID)
        defer { sending.remove(postID) }
        do {
            let stored = try await data.reactWithSelfie(postID: postID, jpeg: jpeg)
            if stored.id != pending.id { sentImages[pending.id] = nil }
            sentImages[stored.id] = jpeg
            byPost[postID, default: SelfieSummary()].upsert(stored)
            signals.post(.selfieSent)
            return .done
        } catch {
            sentImages[pending.id] = nil
            byPost[postID] = before
            signals.emit(.failed)
            signals.post(.selfieFailed)
            return SocialFailure(error) == .notFound ? .notFound : .failed
        }
    }

    /// The camera failed to take the selfie: nothing is sent (`viewer.selfiereaction.error`, `haptic.global.error`).
    func captureFailed() {
        signals.emit(.failed)
        signals.post(.selfieFailed)
    }

    // MARK: Removing (`remove_selfie_reaction`)

    /// Tap on my row in the Reactions sheet (`chat.reactions.layout.unreact`): my selfie goes at once and comes back if
    /// the call fails.
    @discardableResult
    func removeMine(from postID: PostID, me: UserID) async -> SelfieOutcome {
        await remove(userID: me, from: postID, asAuthor: false)
    }

    /// "Remove" on someone's selfie on my own photo, after the confirmation (`haptic.global.warning`).
    @discardableResult
    func removeFromMyPhoto(userID: UserID, postID: PostID) async -> SelfieOutcome {
        signals.emit(.warning)
        return await remove(userID: userID, from: postID, asAuthor: true)
    }

    private func remove(userID: UserID, from postID: PostID, asAuthor: Bool) async -> SelfieOutcome {
        let before = summary(for: postID)
        guard before.selfie(by: userID) != nil else { return .failed }
        byPost[postID]?.remove(userID: userID)
        do {
            try await data.removeSelfieReaction(postID: postID, userID: asAuthor ? userID : nil)
            return .done
        } catch {
            if SocialFailure(error) == .notFound { return .notFound }
            byPost[postID] = before
            signals.emit(.failed)
            return .failed
        }
    }
}
