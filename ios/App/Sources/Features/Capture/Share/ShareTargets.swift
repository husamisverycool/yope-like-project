// Surface: share.in — the share sheet's suggestion row (design/surfaces/share.in.md "Per-group targets"). Mechanics:
// Apple "Supporting suggestions in your app's share extension" (https://developer.apple.com/documentation/foundation/app_extension_support/supporting_suggestions_in_your_app_s_share_extension):
// the app donates an outgoing `INSendMessageIntent` per group — the group as the conversation (`speakableGroupName` =
// its name, `conversationIdentifier` = its id) — when the person posts to it or opens it; the share sheet offers the
// recent ones next to the app. Picking one opens the Share Extension with that intent (Info.plist `IntentsSupported`),
// which hands the group id through the App Group inbox; send-to opens with that group preselected.
// The donations of a group the person left are deleted (`SessionHooks.keepShareTargets`, after each group-list
// refresh), and every one at sign-out.
import Foundation
import Intents

enum ShareTargetDonations {
    /// A group as the share sheet shows it: its name (the person's own data, not copy) and id.
    struct Group: Hashable, Sendable {
        let id: String
        let name: String
    }

    /// The group ids donated on this device (INInteraction cannot list its donations).
    static let donatedKey = "shareTargets.donatedGroupIDs" // provenance-ok: UserDefaults key, not copy

    static func intent(for group: Group) -> INSendMessageIntent {
        INSendMessageIntent(
            recipients: nil,
            outgoingMessageType: .outgoingMessageText,
            content: nil,
            speakableGroupName: INSpeakableString(spokenPhrase: group.name),
            conversationIdentifier: group.id,
            serviceName: nil,
            sender: nil,
            attachments: nil
        )
    }

    /// Donates one interaction per group (posted to, or opened). Groups without an id or a name are skipped.
    static func donate(_ groups: [Group]) async {
        let valid = groups.filter { !$0.id.isEmpty && !$0.name.isEmpty }
        guard !valid.isEmpty else { return }
        record(donated().union(valid.map(\.id)))
        for group in valid {
            let interaction = INInteraction(intent: intent(for: group), response: nil)
            interaction.direction = .outgoing
            interaction.groupIdentifier = group.id
            try? await interaction.donate()
        }
    }

    /// Deletes the donations of every group not in `current` (the person's groups now); nil deletes all (sign-out).
    static func keep(only current: Set<String>?) async {
        guard let current else {
            record([])
            try? await INInteraction.deleteAll()
            return
        }
        let donated = donated()
        let gone = donated.subtracting(current)
        guard !gone.isEmpty else { return }
        record(donated.intersection(current))
        for id in gone {
            try? await INInteraction.delete(with: id)
        }
    }

    private static func donated() -> Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: donatedKey) ?? [])
    }

    private static func record(_ ids: Set<String>) {
        UserDefaults.standard.set(ids.sorted(), forKey: donatedKey)
    }
}
