package app.feature.social.common

/**
 * The social values that are still BLOCKED (design/BLOCKED.md, MERGE "Redesign — Social" → BLOCKED items), in
 * one place. While an entry is false its element follows the release rule (nothing that depends on the value
 * is drawn); debug builds show the development approximation the spec names ([BuildApproximations], read
 * through [shows] / [LocalApproximations]). When a value is captured and generated into `Tokens`, its entry
 * leaves this object and the call site reads the generated constant.
 *
 * Closed by the redesign (now read from `Tokens`): `chat.reactions.count.clusterMaxVisible`,
 * `photo.viewer.layout.voiceNote`, `week.history.layout.weekMenu`.
 */
object SocialBlocked {
    /** `chat.reactions.layout.listOrder` — release: the rows in the order the data layer returns them. */
    const val reactionListOrder: Boolean = false

    /** `photo.viewer.layout.backZone` — release: no back zone (every tap advances; "Previous photo" stays a TalkBack action). */
    const val viewerBackZone: Boolean = false

    /** `walls.browse.layout.rowOrder` — release: the order the memberships arrive in. */
    const val browseRowOrder: Boolean = false

    /** `week.recap.layout.gridFill` — release: the card shows only complete rows of four (no partial row is drawn). */
    const val recapGridFill: Boolean = false

    /** `week.edit.layout.selectionMark` — release: no in / out mark on the grid cells (the value is announced). */
    const val editSelectionMark: Boolean = false

    /** `albums.view.shadow.cover` — the cover is drawn flat in every build (BLOCKED.md: until captured). */
    const val albumCoverShadow: Boolean = false
}
