// Surface: chat.thread (with chat.composer, chat.voice, chat.reactions) — Retro comment rows in Messages / WhatsApp's order.
// Reference images: listed in design/surfaces/chat.thread.md (docs/SURFACES.md); built in
// Features/Social/UI/ChatThreadView.swift with Tokens.* / Copy.*.
import AppData
import SwiftUI

/// Group chat; `messageID` is the message to scroll to (`DeepLink.chatMessage`).
struct ChatScreen: View {
    let groupID: String
    let messageID: String?
    @State private var model: ChatThreadModel

    init(groupID: String, messageID: String?) {
        self.groupID = groupID
        self.messageID = messageID
        _model = State(initialValue: ChatThreadModel(
            groupID: GroupID(groupID),
            focusMessageID: messageID.map { MessageID($0) },
            data: SocialServices.shared.data,
            linkPreviews: SocialServices.shared.linkPreviews
        ))
    }

    var body: some View {
        ChatThreadView(model: model)
    }
}
