// Social group — every BLOCKED value the social screens depend on, behind one accessor (design/BLOCKED.md).
//
// Each accessor returns nil / false while its token is BLOCKED; the screens omit (or, where a spec gives one, use
// the approximation for) the part that needs it. When a value is filled, `tools/designgen.mjs` moves it from the
// DEBUG-only `BlockedTokens` into `Tokens`: replace that accessor's `nil` / `false` with the token — one line each.
// Layout tokens (descriptions of behaviour) also need their behaviour built; their accessors say what is waiting.
import DesignSystem
import SwiftUI

enum SocialBlocked {
    // MARK: Values (one line each when filled)

    /// `chat.thread.dimension.bubbleMaxWidth` — until filled, bubbles are bounded by the opposite side's inset.
    static var bubbleMaxWidth: CGFloat? { nil }
    /// `chat.thread.count.emojiOnlyMax` — until filled, emoji-only messages are drawn as text bubbles.
    static var emojiOnlyMax: Int? { nil }
    /// `chat.thread.radius.loadingHud` — the shared `LoadingHUD` (account pass) draws square corners meanwhile.
    static var loadingHudRadius: CGFloat? { nil }
    /// `color.global.scrim` — the caption box fill (thread and viewer); drawn without a fill meanwhile.
    static var scrim: Color? { nil }
    /// `chat.composer.dimension.bottomInset` — the composer / reply row sit on the bottom safe area meanwhile.
    static var composerBottomInset: CGFloat? { nil }
    /// `chat.voice.color.bubbleTheirs` — another member's voice bubble is drawn without a fill meanwhile.
    static var voiceBubbleTheirs: Color? { nil }
    /// `chat.voice.color.waveformPlayed` — the played part of the waveform (playing state).
    static var waveformPlayed: Color? { nil }
    /// `chat.voice.icon.pause` — the play circle keeps ▶ while playing meanwhile.
    static var pauseIcon: String? { nil }
    /// `chat.reactions.easing.rain` — the emoji rain's speed curve; release builds do not play the rain meanwhile.
    static var rainEasing: DSEasing? { nil }
    /// `chat.reactions.duration.flyToCluster` — a new sticker is inserted without animation meanwhile.
    static var flyToCluster: TimeInterval? { nil }
    /// `chat.reactions.count.clusterMaxVisible` — every distinct emoji shows (clipped by the photo) meanwhile.
    static var clusterMaxVisible: Int? { nil }
    /// `photo.viewer.dimension.pageGap` — pages touch (platform paging) meanwhile.
    static var viewerPageGap: CGFloat? { nil }
    /// `week.recap.dimension.shortRowHeight` (with `week.recap.layout.shortRowSplit`) — the card's leftover row.
    static var recapShortRowHeight: CGFloat? { nil }
    /// `week.history.color.emptyTile` — add tile and empty-day tiles; omitted meanwhile.
    static var historyEmptyTile: Color? { nil }
    /// `week.history.color.emptyTileText`.
    static var historyEmptyTileText: Color? { nil }

    // MARK: Layouts (behaviour to build when filled)

    /// `chat.composer.layout.typingState` — the send control; the keyboard's return key sends meanwhile.
    static var hasTypingState: Bool { false }
    /// `chat.voice.layout.recording` — the recording UI; release builds have no mic circle meanwhile
    /// (DEBUG: tap to record, tap to send, no recording UI).
    static var hasRecordingLayout: Bool { false }
    /// `chat.thread.layout.failedMessage` — a failed message is taken back, its text returns to the field and
    /// `chat.thread.sendFailed` is announced meanwhile.
    static var hasFailedMessageLayout: Bool { false }
    /// `chat.voice.layout.widthRule` — every voice bubble uses the observed width meanwhile.
    static var hasVoiceWidthRule: Bool { false }
    /// `chat.reactions.layout.clusterOrder` — the data's order (first reacted first) meanwhile.
    static var hasClusterOrder: Bool { false }
    /// `chat.reactions.layout.activitySheet` — native list rows in the data's order meanwhile.
    static var hasActivitySheetLayout: Bool { false }
    /// `chat.reactions.layout.unreact` — taking a reaction back is not offered meanwhile.
    static var hasUnreact: Bool { false }
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
    /// `week.edit.layout.reorder` — DEBUG builds only: long-press drag among checked tiles.
    static var hasReorder: Bool { false }
    /// `week.edit.layout.recapText` — the spec's approximation (field under the grid) meanwhile.
    static var hasRecapTextLayout: Bool { false }
    /// `week.history.layout.weekMenu` — our two product items meanwhile.
    static var hasWeekMenuLayout: Bool { false }
    /// `albums.list.layout.yopeAlbums` — the home-card composition (S-14) meanwhile.
    static var hasYopeAlbums: Bool { false }

    /// The week.edit dark secondary "save as album" button: the spec names `camera.sendto` tokens for Yope's compact
    /// "more friends" + "send" pair, but design/tokens has none (that variant is do-not-copy in camera.sendto). The
    /// button is not drawn until its tokens exist; "Save as album" stays reachable from week.history's week menu.
    static var hasSaveAsAlbumButton: Bool { false }
}
