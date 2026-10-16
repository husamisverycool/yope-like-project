// The Jolt demo (`DemoMode`): a photo taken in the camera's 9 AM mode (camera.overnight) develops in the demo world as
// the backend would hold it — nobody sees it, the sender included; its groups show the developing tile (the plans
// fakes' `developing` state, read by camera.overnight B); `my_developing()` answers yes with the earliest reveal. It is
// revealed — added to its groups like a photo sent now (`DemoSentPosts`) — at its reveal time if the app is still
// running, or at once when the app was launched with `-overnight-demo-reveal` (`revealAll()` does the same on demand).
#if DEBUG
import AppData
import AppModels
import Foundation

@MainActor
enum DemoDevelopingPhotos {
    /// Reveals each 9 AM photo as soon as it is sent instead of at the next 09:00.
    static let revealNowArgument = "-overnight-demo-reveal" // provenance-ok: launch argument, not user-facing

    private struct Developing {
        var draft: PostDraft
        var revealAt: Date
    }

    private static var photos: [Developing] = []

    /// Whether the demo member has photos developing, and the earliest reveal (`my_developing()`).
    static var status: OvernightStatus {
        OvernightStatus(developing: !photos.isEmpty, revealAt: photos.map(\.revealAt).min())
    }

    static func add(_ draft: PostDraft, revealAt: Date) {
        guard DemoMode.isOn else { return }
        // The draft's own file is temporary: keep a copy until the reveal.
        let path = DemoPhotos.sentPrefix + "developing-" + draft.mediaID.rawValue // provenance-ok: demo storage path
        guard let kept = DemoPhotos.keepSent(draft.original.url, path: path) else { return }
        var held = draft
        held.original = PostDraft.File(url: kept, contentType: draft.original.contentType)
        photos.append(Developing(draft: held, revealAt: revealAt))
        markGroups(held.groupIDs)
        if DemoMode.launchArguments.contains(revealNowArgument) {
            revealAll()
            return
        }
        let wait = max(0, revealAt.timeIntervalSinceNow)
        let mediaID = held.mediaID
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(wait))
            reveal { $0.draft.mediaID == mediaID }
        }
    }

    /// Reveals every developing photo now.
    static func revealAll() {
        reveal { _ in true }
    }

    private static func reveal(_ matching: (Developing) -> Bool) {
        let due = photos.filter(matching)
        guard !due.isEmpty else { return }
        photos.removeAll(where: matching)
        for photo in due {
            var draft = photo.draft
            draft.overnight = nil
            DemoSentPosts.add(draft)
        }
        markGroups(due.flatMap(\.draft.groupIDs))
    }

    /// Each group's developing state before the demo member's 9 AM photos (other members' photos of the demo world).
    private static var baseline: [GroupID: OvernightStatus] = [:]

    /// The developing tile's state of each group (camera.overnight B reads it from the plans fakes): the demo world's,
    /// plus the demo member's photos still developing there.
    private static func markGroups(_ groupIDs: [GroupID]) {
        let fake = PlansServices.shared.questions as? FakePlansData
        for groupID in Set(groupIDs) {
            if baseline[groupID] == nil {
                baseline[groupID] = fake?.read { $0.developing[groupID] } ?? .notDeveloping
            }
            let before = baseline[groupID] ?? .notDeveloping
            let reveals = photos.filter { $0.draft.groupIDs.contains(groupID) }.map(\.revealAt) + [before.revealAt].compactMap { $0 }
            let developing = before.developing || photos.contains { $0.draft.groupIDs.contains(groupID) }
            fake?.update { state in
                state.developing[groupID] = developing ? OvernightStatus(developing: true, revealAt: reveals.min()) : .notDeveloping
            }
            fake?.notify(groupID: groupID)
        }
        PlansServices.shared.didChange()
    }
}
#endif
