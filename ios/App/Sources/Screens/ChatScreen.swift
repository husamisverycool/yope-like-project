// Surface: chat.thread — reference app: Yope.
// Reference images: listed in design/surfaces/chat.thread.md (docs/SURFACES.md).
// Container only: the screens pass builds this surface from its spec, with Tokens.* / Copy.*.
import SwiftUI

/// Group chat; `messageID` is the message to scroll to.
struct ChatScreen: View {
    let groupID: String
    let messageID: String?

    var body: some View {
        ScreenContainer(surface: "chat.thread")
    }
}
