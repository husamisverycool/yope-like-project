// Social group — every value the social screens need that is still BLOCKED (design/BLOCKED.md), behind one accessor.
//
// Each accessor returns nil / false while its token is BLOCKED; the screens omit (or, where a spec gives one, use the
// approximation for) the part that needs it. When a value is filled, `tools/designgen.mjs` moves it from the DEBUG-only
// `BlockedTokens` into `Tokens`: replace that accessor's `nil` / `false` with the token (one line), or build the
// behaviour a layout token describes. The 19 values sourced by the social gap fill (MERGE_DECISIONS "Gap fill (social)",
// G-1…G-17) and `color.global.scrim` (gap fill G2) are read from `Tokens` directly at their use sites.
import DesignSystem
import SwiftUI

enum SocialBlocked {
    // MARK: Values (one line each when filled)

    /// `chat.reactions.count.clusterMaxVisible` — every distinct emoji shows (clipped by the photo) meanwhile.
    static var clusterMaxVisible: Int? { nil }
    /// `week.recap.dimension.shortRowHeight` (with `week.recap.layout.shortRowSplit`) — the card's leftover row; those
    /// photos stay in the pics grid meanwhile.
    static var recapShortRowHeight: CGFloat? { nil }

    // MARK: Layouts (behaviour to build when filled)

    /// `chat.voice.layout.widthRule` — every voice bubble uses the observed width meanwhile.
    static var hasVoiceWidthRule: Bool { false }
    /// `chat.reactions.layout.activitySheet` — native list rows in the data's order meanwhile.
    static var hasActivitySheetLayout: Bool { false }
    /// `photo.viewer.layout.voiceNote` — the spec's approximation (under the photo, `size.global.screenMargin`).
    static var hasViewerVoiceNoteLayout: Bool { false }
    /// `walls.mine.layout.freeformWall` / `.mosaic` — the uniform grid (S-11) meanwhile.
    static var hasFreeformWall: Bool { false }
    /// `walls.browse.layout.selection` — the selected person is marked for VoiceOver only meanwhile.
    static var hasBrowseSelection: Bool { false }
    /// `walls.browse.layout.rowOrder` — the spec's approximation (newest wall item first) meanwhile.
    static var hasBrowseRowOrder: Bool { false }
    /// `week.recap.layout.scrim` — the card label is drawn without a scrim meanwhile.
    static var hasRecapScrim: Bool { false }
    /// `week.recap.layout.page2` — one page, dots hidden meanwhile.
    static var hasRecapPage2: Bool { false }
    /// `week.edit.layout.recapText` — the spec's approximation (field under the grid) meanwhile.
    static var hasRecapTextLayout: Bool { false }
    /// `week.history.layout.weekMenu` — our two product items meanwhile.
    static var hasWeekMenuLayout: Bool { false }

    /// The week.edit dark secondary "save as album" button: the spec names `camera.sendto` tokens for Yope's compact
    /// "more friends" + "send" pair, but design/tokens has none (that variant is do-not-copy in camera.sendto). The
    /// button is not drawn until its tokens exist; "Save as album" stays reachable from week.history's week menu.
    static var hasSaveAsAlbumButton: Bool { false }
}
