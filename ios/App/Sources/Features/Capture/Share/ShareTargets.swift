// Surface: share.in — the share sheet's suggestion row (design/surfaces/share.in.md "Per-group targets"). Mechanics:
// Apple "Supporting suggestions in your app's share extension" (https://developer.apple.com/documentation/foundation/app_extension_support/supporting_suggestions_in_your_app_s_share_extension):
// the app donates an outgoing `INSendMessageIntent` per group — the group as the conversation (`speakableGroupName` =
// its name, `conversationIdentifier` = its id) — when the person posts to it or opens it; the share sheet offers the
// recent ones next to the app. Picking one opens the Share Extension with that intent (Info.plist `IntentsSupported`),
// which hands the group id through the App Group inbox; send-to opens with that group preselected.
// The donations of a group the person left are deleted (`SessionHooks.keepShareTargets`, after each group-list
// refresh), and every one at sign-out.
// Each donation carries the group's image for the suggestion (`setImage(_:forParameterNamed: \.speakableGroupName)`): its
// cover when a decoded copy is already on the device (ImagePipeline's memory cache — no download at donation), else its
// initials on `color.global.control` in `color.global.textSecondary`, drawn as Android's share-target icon is
// (feature/capture/share/ShareTargets.kt).
import DesignSystem
import Foundation
import Intents
import SwiftUI
import UIKit

enum ShareTargetDonations {
    /// A group as the share sheet shows it: its name (the person's own data, not copy), id and cover (storage path).
    struct Group: Hashable, Sendable {
        let id: String
        let name: String
        var coverPath: String? = nil
    }

    /// The group ids donated on this device (INInteraction cannot list its donations).
    static let donatedKey = "shareTargets.donatedGroupIDs" // provenance-ok: UserDefaults key, not copy

    static func intent(for group: Group, image: INImage? = nil) -> INSendMessageIntent {
        let intent = INSendMessageIntent(
            recipients: nil,
            outgoingMessageType: .outgoingMessageText,
            content: nil,
            speakableGroupName: INSpeakableString(spokenPhrase: group.name),
            conversationIdentifier: group.id,
            serviceName: nil,
            sender: nil,
            attachments: nil
        )
        // The suggestion's picture is the conversation's (the group's) image.
        if let image {
            intent.setImage(image, forParameterNamed: \.speakableGroupName)
        }
        return intent
    }

    /// Donates one interaction per group (posted to, or opened), each with the group's image. Groups without an id or
    /// a name are skipped.
    static func donate(_ groups: [Group]) async {
        let valid = groups.filter { !$0.id.isEmpty && !$0.name.isEmpty }
        guard !valid.isEmpty else { return }
        record(donated().union(valid.map(\.id)))
        for group in valid {
            let image = await imageData(for: group).map { INImage(imageData: $0) }
            let interaction = INInteraction(intent: intent(for: group, image: image), response: nil)
            interaction.direction = .outgoing
            interaction.groupIdentifier = group.id
            try? await interaction.donate()
        }
    }

    /// Deletes the donations of every group not in `current` (the person's groups now); nil deletes all (sign-out).
    /// The Intents deletions run on their own and are not awaited: sign-out (`SessionCoordinator.clearLocalData`) and
    /// the group refresh wait for this hook, and `INInteraction`'s delete calls can stay unanswered (seen on the CI
    /// simulator: sign-out never reached auth.phone).
    static func keep(only current: Set<String>?) async {
        guard let current else {
            record([])
            Task.detached { try? await INInteraction.deleteAll() }
            return
        }
        let donated = donated()
        let gone = donated.subtracting(current)
        guard !gone.isEmpty else { return }
        record(donated.intersection(current))
        Task.detached {
            for id in gone {
                try? await INInteraction.delete(with: id)
            }
        }
    }

    // MARK: Images

    /// The adaptive-icon canvas Android draws its share-target icon on (108 dp) and the safe zone its initials stay in
    /// (72 dp), so both platforms draw the same picture; rendered at `renderScale` pixels per point.
    private static let canvas: CGFloat = 108 // provenance-ok: Android's adaptive icon canvas (PLATFORM), as ShareTargets.kt
    private static let safeZone: CGFloat = 72 // provenance-ok: Android's adaptive icon safe zone (PLATFORM), as ShareTargets.kt
    private static let renderScale: CGFloat = 3 // provenance-ok: pixels per point of the largest iPhone screens

    /// The group's image (PNG): its cover if decoded on the device, else its initials. Nil when it cannot be encoded.
    @MainActor
    static func imageData(for group: Group) -> Data? {
        let picture = group.coverPath.flatMap { ImagePipeline.shared.largestCachedImage(path: $0) }.map(squareCover)
            ?? initialsImage(name: group.name, style: systemStyle())
        return picture.pngData()
    }

    /// The system Light / Dark setting (the share sheet follows it, as Android's `DsAppearance.pickSystem`).
    @MainActor
    private static func systemStyle() -> UIUserInterfaceStyle {
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        return scene?.traitCollection.userInterfaceStyle == .dark ? .dark : .light
    }

    @MainActor
    private static func renderer() -> UIGraphicsImageRenderer {
        let format = UIGraphicsImageRendererFormat()
        format.scale = renderScale
        format.opaque = true
        return UIGraphicsImageRenderer(size: CGSize(width: canvas, height: canvas), format: format)
    }

    /// The cover's centre square, aspect-filled (as the avatar's crop and Android's icon).
    @MainActor
    private static func squareCover(_ cover: UIImage) -> UIImage {
        let side = min(cover.size.width, cover.size.height)
        guard side > 0 else { return cover }
        let scale = canvas / side
        let drawn = CGSize(width: cover.size.width * scale, height: cover.size.height * scale)
        return renderer().image { _ in
            cover.draw(in: CGRect(x: (canvas - drawn.width) / 2, y: (canvas - drawn.height) / 2, width: drawn.width, height: drawn.height))
        }
    }

    /// The name's initials on `color.global.control` in `color.global.textSecondary` (system font, half the safe zone's
    /// width, shrunk to fit it), centred — Android's `initialsBitmap`.
    @MainActor
    static func initialsImage(name: String, style: UIUserInterfaceStyle) -> UIImage {
        let traits = UITraitCollection(userInterfaceStyle: style)
        let background = UIColor(Tokens.Colors.globalControl).resolvedColor(with: traits)
        let ink = UIColor(Tokens.Colors.globalTextSecondary).resolvedColor(with: traits)
        let text = initials(name)
        return renderer().image { context in
            background.setFill()
            context.fill(CGRect(x: 0, y: 0, width: canvas, height: canvas))
            guard !text.isEmpty else { return }
            var font = UIFont.systemFont(ofSize: safeZone / 2) // provenance-ok: two letters fill the safe zone's width (as Android)
            var size = (text as NSString).size(withAttributes: [.font: font])
            if size.width > safeZone {
                font = font.withSize(font.pointSize * safeZone / max(size.width, 1))
                size = (text as NSString).size(withAttributes: [.font: font])
            }
            // Centred on the glyphs' ascent and descent, as Android's baseline (size / 2 − (descent + ascent) / 2).
            let baseline = canvas / 2 + (font.ascender + font.descender) / 2
            let origin = CGPoint(x: (canvas - size.width) / 2, y: baseline - font.ascender)
            (text as NSString).draw(at: origin, withAttributes: [.font: font, .foregroundColor: ink])
        }
    }

    /// The first letter or digit of the name's first two words, upper-cased ("Book club" → "BC"), as Android's.
    static func initials(_ name: String) -> String {
        name.split(whereSeparator: \.isWhitespace).prefix(2)
            .compactMap { word in word.first(where: { $0.isLetter || $0.isNumber }).map(String.init) }
            .joined()
            .uppercased(with: .current)
    }

    private static func donated() -> Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: donatedKey) ?? [])
    }

    private static func record(_ ids: Set<String>) {
        UserDefaults.standard.set(ids.sorted(), forKey: donatedKey)
    }
}
