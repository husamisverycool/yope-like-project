// The Jolt demo (`DemoMode`): a photo sent from the camera joins its groups in the demo world, as the backend would
// save it — on the group screen's feed (account data) and in the chat, the viewer and the walls (social data), with
// the photo message the backend adds to the chat.
#if DEBUG
import AppData
import AppModels
import Foundation

@MainActor
enum DemoSentPosts {
    static func add(_ draft: PostDraft) {
        guard DemoMode.isOn else { return }
        let path = DemoPhotos.sentPrefix + draft.mediaID.rawValue
        guard DemoPhotos.keepSent(draft.original.url, path: path) != nil else { return }
        let now = Date()
        let me = SocialDemo.me
        let media = Media(
            id: draft.mediaID, ownerID: me, kind: draft.kind, originalPath: path, displayPath: path, thumbPath: path,
            width: draft.width, height: draft.height, renditionsReadyAt: now, createdAt: now
        )
        let account = AppEnvironment.shared.accountDependencies.data as? InMemoryAccountData
        let social = SocialServices.shared.data as? FakeSocialData
        for groupID in draft.groupIDs {
            let post = Post(
                id: PostID(UUID().uuidString.lowercased()), mediaID: draft.mediaID, groupID: groupID, authorID: me,
                caption: draft.caption, createdAt: now
            )
            let item = PostWithMedia(post: post, media: media)
            let message = Message(
                id: MessageID(UUID().uuidString.lowercased()), groupID: groupID, authorID: me, kind: .photo, postID: post.id,
                createdAt: now
            )
            account?.postsByGroup[groupID, default: []].insert(item, at: 0)
            account?.emit(.postInserted(post), groupID: groupID)
            social?.update { state in
                state.posts.append(item)
                state.messages.append(message)
            }
            social?.emit(.postInserted(post), groupID: groupID)
            social?.emit(.messageInserted(message), groupID: groupID)
        }
    }
}
#endif
