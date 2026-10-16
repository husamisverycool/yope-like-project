// The Jolt demo (`DemoMode`): selfie reactions (viewer.selfiereaction) in the demo world. Faces on a few "roommates"
// photos — Ana and Cleo on Ben's dinner, Ben and Cleo on Ana's first snow, all three on the demo member's own hike
// (so the author's Remove shows), Ben on Cleo's dog — drawn from the people's sample portraits (`DemoPhotos`,
// `fake/selfie/<person>`). A selfie the demo member sends (the fake camera's front still, `FakeCaptureCamera.demo()`)
// is kept for the session and joins the stack like any other.
#if DEBUG
import AppData
import AppModels
import Foundation

enum DemoSelfies {
    /// Seeds the demo world's selfies and keeps the demo member's own (the Jolt demo build only).
    static func install(in data: FakeSocialData) {
        guard DemoMode.isOn else { return }
        data.update { state in
            state.selfies += seeded
            state.selfieUpload = { jpeg in keep(jpeg) }
        }
    }

    static var seeded: [SelfieReaction] {
        let world = SocialDemo.self
        return [
            selfie(1, on: world.p1, by: world.ana, at: world.at(1.2 * world.hour)),
            selfie(2, on: world.p1, by: world.cleo, at: world.at(1.4 * world.hour)),
            selfie(3, on: world.p2, by: world.ben, at: world.at(1 * world.day + 10.5 * world.hour)),
            selfie(4, on: world.p2, by: world.cleo, at: world.at(1 * world.day + 11 * world.hour)),
            selfie(5, on: world.p3, by: world.ana, at: world.at(2 * world.day + 5 * world.hour)),
            selfie(6, on: world.p3, by: world.ben, at: world.at(2 * world.day + 6 * world.hour)),
            selfie(7, on: world.p3, by: world.cleo, at: world.at(2 * world.day + 7 * world.hour)),
            selfie(8, on: world.p4, by: world.ben, at: world.at(3 * world.day + 9 * world.hour)),
        ]
    }

    private static func selfie(_ n: Int, on post: PostID, by user: UserID, at date: Date) -> SelfieReaction {
        SelfieReaction(
            id: SelfieReactionID("00000000-0000-4000-8000-0000000b" + String(1000 + n).suffix(4)), // provenance-ok: demo data id
            postID: post, userID: user, groupID: SocialDemo.groupID,
            imagePath: "fake/selfie/\(user.rawValue.suffix(2))", // provenance-ok: demo storage path
            createdAt: date
        )
    }

    /// Keeps a selfie the demo member sent for the session (the face is drawn from it) and returns its storage path.
    static func keep(_ jpeg: Data) -> String {
        let name = "selfie-" + UUID().uuidString.lowercased() // provenance-ok: demo file name
        let path = DemoPhotos.sentPrefix + name
        let file = FileManager.default.temporaryDirectory.appendingPathComponent(name + ".jpg") // provenance-ok: demo file name
        if (try? jpeg.write(to: file)) != nil {
            _ = DemoPhotos.keepSent(file, path: path)
            try? FileManager.default.removeItem(at: file)
        }
        return path
    }
}
#endif
