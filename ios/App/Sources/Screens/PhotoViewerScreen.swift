// Surface: photo.viewer — Retro's media viewer.
// Reference images: listed in design/surfaces/photo.viewer.md (docs/SURFACES.md); built in
// Features/Social/UI/PhotoViewerView.swift with Tokens.* / Copy.*.
import AppData
import SwiftUI

/// Full photo opened by a link (`DeepLink.post`, push types `new_post` / `reaction`): caption, voice note, reactions,
/// comments, "I'm in this", delete, report, save. Social screens present the same viewer full screen over themselves
/// with their own photos to tap through.
struct PhotoViewerScreen: View {
    let groupID: String
    let postID: String

    var body: some View {
        PhotoViewerView(
            // A reveal push names the first overnight photo: the viewer holds all the photos revealed with it.
            context: PhotoViewerContext(postIDs: [PostID(postID)], start: PostID(postID), groupID: GroupID(groupID), opensReveal: true),
            presentation: .pushed
        )
    }
}
