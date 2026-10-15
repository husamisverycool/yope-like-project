package app.feature.social.common

import androidx.compose.animation.core.Easing
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.unit.Dp

/**
 * Every BLOCKED value the social screens depend on, in one place (design/BLOCKED.md). While a value
 * is null / false its element is omitted in release builds (debug builds may show the
 * development approximation, [BuildApproximations]). When a token is unblocked and generated into
 * `Tokens` (`node tools/designgen.mjs`), replace its `null` / `false` here with the generated
 * constant named in the comment — one line, nothing else changes.
 */
object SocialBlocked {
    // chat.thread
    /** `chat.thread.dimension.bubbleMaxWidth` → `Tokens.Sizes.chatThreadDimensionBubbleMaxWidth`. */
    val bubbleMaxWidth: Dp? = null
    /** `chat.thread.count.emojiOnlyMax` → `Tokens.Counts.chatThreadCountEmojiOnlyMax`. */
    val emojiOnlyMax: Int? = null
    /** `chat.thread.radius.loadingHud` → `Tokens.Radii.chatThreadRadiusLoadingHud`. */
    val loadingHudRadius: Dp? = null
    /** `chat.thread.layout.failedMessage` (layout) → true once `Tokens.Layouts.ChatThreadLayoutFailedMessage` exists and is built. */
    const val failedMessageLayout: Boolean = false
    /** `color.global.scrim` (caption box fill) → `Tokens.Colors.globalScrim`. */
    val scrim: Color? = null

    // chat.composer
    /** `chat.composer.dimension.bottomInset` → `Tokens.Sizes.chatComposerDimensionBottomInset`. */
    val composerBottomInset: Dp? = null
    /** `chat.composer.layout.typingState` (send control) → true once `Tokens.Layouts.ChatComposerLayoutTypingState` is built. */
    const val typingState: Boolean = false

    // chat.voice
    /** `chat.voice.color.bubbleTheirs` → `Tokens.Colors.chatVoiceColorBubbleTheirs`. */
    val voiceBubbleTheirs: Color? = null
    /** `chat.voice.color.waveformPlayed` → `Tokens.Colors.chatVoiceColorWaveformPlayed`. */
    val waveformPlayed: Color? = null
    /** `chat.voice.icon.pause` → `Tokens.Icons.chatVoiceIconPause`. */
    val pauseIcon: ImageVector? = null
    /** `chat.voice.layout.widthRule` → true once `Tokens.Layouts.ChatVoiceLayoutWidthRule` is built (until then: the observed width). */
    const val voiceWidthRule: Boolean = false
    /** `chat.voice.layout.recording` → true once `Tokens.Layouts.ChatVoiceLayoutRecording` is built (enables the mic circle in release). */
    const val voiceRecording: Boolean = false

    // chat.reactions
    /** `chat.reactions.layout.clusterOrder` → true once built (until then: data order, first reaction first). */
    const val clusterOrder: Boolean = false
    /** `chat.reactions.count.clusterMaxVisible` → `Tokens.Counts.chatReactionsCountClusterMaxVisible`. */
    val clusterMaxVisible: Int? = null
    /** `chat.reactions.easing.rain` → `Tokens.Easings.chatReactionsEasingRain` (enables the emoji rain in release). */
    val rainEasing: Easing? = null
    /** `chat.reactions.duration.flyToCluster` → `Tokens.Durations.chatReactionsDurationFlyToCluster`. */
    val flyToCluster: Int? = null
    /** `chat.reactions.layout.activitySheet` → true once `Tokens.Layouts.ChatReactionsLayoutActivitySheet` is built (enables the sheet in release). */
    const val activitySheet: Boolean = false
    /** `chat.reactions.layout.unreact` → true once built. */
    const val unreact: Boolean = false

    // photo.viewer
    /** `photo.viewer.dimension.pageGap` → `Tokens.Sizes.photoViewerDimensionPageGap`. */
    val viewerPageGap: Dp? = null
    /** `photo.viewer.layout.voiceNote` → true once built (until then: under the photo at `size.global.screenMargin`). */
    const val viewerVoiceNote: Boolean = false
    /**
     * `camera.sendto.duration.toastVisible` / `safety.block.duration.toast` → the toast dwell in ms
     * (core:ui `ToastDwell.millis`); null = no toast is drawn.
     */
    val toastDwellMs: Long? = app.ui.components.ToastDwell.millis

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
    /** `week.edit.layout.reorder` → true once built (enables drag reorder in release). */
    const val reorder: Boolean = false
    /** `week.edit.layout.recapText` → true once built (until then: the field under the grid, the spec's approximation). */
    const val recapTextPosition: Boolean = false

    /**
     * week.edit's dark "save as album" button: the `camera.sendto` pair tokens the spec names do not
     * exist (the compact "more friends" + "send" pair was not measured) → true once they are generated.
     */
    const val saveAsAlbumPair: Boolean = false

    // week.history
    /** `week.history.color.emptyTile` → `Tokens.Colors.weekHistoryColorEmptyTile`. */
    val emptyTile: Color? = null
    /** `week.history.color.emptyTileText` → `Tokens.Colors.weekHistoryColorEmptyTileText`. */
    val emptyTileText: Color? = null
    /** `week.history.layout.weekMenu` → true once built (until then: our two product actions). */
    const val weekMenu: Boolean = false

    // albums
    /** `albums.list.layout.yopeAlbums` → true once built (until then: composition from the home card, S-14). */
    const val yopeAlbums: Boolean = false
}
