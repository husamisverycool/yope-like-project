package app.feature.social.common

import androidx.compose.ui.unit.Dp

/**
 * Every value the social screens depend on that is still BLOCKED (design/BLOCKED.md), in one place.
 * While a value is null / false its element is omitted in release builds (debug builds may show the
 * development approximation, [BuildApproximations]). When a token is unblocked and generated into
 * `Tokens` (`node tools/designgen.mjs`), its entry leaves this object and the call site reads the
 * generated constant (the release path).
 *
 * Unblocked by the social gap fill (design/MERGE_DECISIONS.md § "Gap fill (social)", G-1…G-17) and now
 * read straight from `Tokens`: `chat.thread.dimension.bubbleMaxWidth`, `.count.emojiOnlyMax`,
 * `.radius.loadingHud`, `.layout.failedMessage`; `chat.composer.dimension.bottomInset`,
 * `.layout.typingState`; `chat.voice.color.bubbleTheirs`, `.color.waveformPlayed`, `.icon.pause`,
 * `.layout.recording`; `chat.reactions.layout.clusterOrder`, `.easing.rain`, `.duration.flyToCluster`,
 * `.layout.unreact`; `photo.viewer.dimension.pageGap`; `week.history.color.emptyTile`, `.emptyTileText`;
 * `week.edit.layout.reorder`; `albums.list.layout.yopeAlbums`; and by the second global pass (G2):
 * `color.global.scrim` (the caption box fill) and the toast dwell `camera.sendto.duration.toastVisible`.
 */
object SocialBlocked {
    // chat.voice
    /** `chat.voice.layout.widthRule` → true once built (until then: the observed width for every duration). */
    const val voiceWidthRule: Boolean = false

    // chat.reactions
    /** `chat.reactions.count.clusterMaxVisible` → `Tokens.Counts.chatReactionsCountClusterMaxVisible` (until then every sticker is drawn; the photo clips them). */
    val clusterMaxVisible: Int? = null
    /** `chat.reactions.layout.activitySheet` → true once `Tokens.Layouts.ChatReactionsLayoutActivitySheet` is built (enables the sheet in release). */
    const val activitySheet: Boolean = false

    // photo.viewer
    /** `photo.viewer.layout.voiceNote` → true once built (until then: under the photo at `size.global.screenMargin`). */
    const val viewerVoiceNote: Boolean = false

    // walls
    /** `walls.mine.layout.freeformWall` / `.mosaic` → true once built (until then: the profile grid, S-11). */
    const val freeformWall: Boolean = false
    /** `walls.browse.layout.rowOrder` → true once built (until then: newest wall item first). */
    const val browseRowOrder: Boolean = false
    /** `walls.browse.layout.selection` → true once `Tokens.Layouts.WallsBrowseLayoutSelection` is built (the selected marking). */
    const val browseSelection: Boolean = false

    // week.recap
    /** `week.recap.dimension.shortRowHeight` → `Tokens.Sizes.weekRecapDimensionShortRowHeight`. */
    val recapShortRowHeight: Dp? = null
    /** `week.recap.layout.shortRowSplit` → true once built (with [recapShortRowHeight], the leftover 1–2 photos are drawn). */
    const val recapShortRowSplit: Boolean = false
    /** `week.recap.layout.scrim` → true once built. */
    const val recapScrim: Boolean = false
    /** `week.recap.layout.page2` → true once built (page dots then show). */
    const val recapPage2: Boolean = false

    // week.edit
    /** `week.edit.layout.recapText` → true once built (until then: the field under the grid, the spec's approximation). */
    const val recapTextPosition: Boolean = false
    /**
     * week.edit's dark "save as album" button: the `camera.sendto` pair tokens the spec names do not
     * exist (the compact "more friends" + "send" pair was not measured) → true once they are generated.
     */
    const val saveAsAlbumPair: Boolean = false

    // week.history
    /** `week.history.layout.weekMenu` → true once built (until then: our two product actions). */
    const val weekMenu: Boolean = false
}
