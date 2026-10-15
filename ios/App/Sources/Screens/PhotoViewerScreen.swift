// Surface: photo.viewer — reference app: Yope + Locket.
// Reference images: listed in design/surfaces/photo.viewer.md (docs/SURFACES.md).
// Container only: the screens pass builds this surface from its spec, with Tokens.* / Copy.*.
import SwiftUI

/// Full photo: caption, voice note, reactions, reply, "I'm in this", delete, report, save.
struct PhotoViewerScreen: View {
    let groupID: String
    let postID: String

    var body: some View {
        ScreenContainer(surface: "photo.viewer")
    }
}
