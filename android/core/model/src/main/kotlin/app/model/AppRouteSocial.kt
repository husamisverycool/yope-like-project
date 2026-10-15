package app.model

import kotlinx.serialization.Serializable

/*
 * Routes added by the social screens pass (same package, so they join the sealed [AppRoute]).
 * The base routes of the social group (Chat, PhotoViewer, WallMine, WallMember, WallsBrowse,
 * WeekRecap, WeekEdit, WeekHistory, AlbumsList, AlbumView) are in AppRoute.kt.
 */

/** Where the photos a viewer swipes through come from (design/surfaces/photo.viewer.md → Data: "Context list comes from the opener"). */
@Serializable
enum class PhotoContext {
    /** The group chat's photos, chronological; `contextId` = group id. */
    Chat,

    /** A person's wall, in wall order; `contextId` = user id. */
    Wall,

    /** One history week's photos, chronological; `contextId` = group id, `weekStart` = ISO date. */
    Week,

    /** A recap's items in recap order; `contextId` = recap id. */
    Recap,

    /** An album's items in album order; `contextId` = album id. */
    Album,

    /** Only the opened photo (deep links). */
    Single,
}

/** `photo.viewer` opened with the opener's photo list. [AppRoute.PhotoViewer] (deep links) shows the single photo. */
@Serializable
data class PhotoViewerIn(
    val groupId: String,
    val postId: String,
    val context: PhotoContext,
    val contextId: String,
    val weekStart: String? = null,
) : AppRoute {
    override val surface get() = "photo.viewer"
}

/** `week.recap` showing the group's newest ready recap (or its empty state when there is none yet). */
@Serializable
data class WeekRecapLatest(val groupId: String) : AppRoute {
    override val surface get() = "week.recap"
}

/**
 * `week.edit`'s "save as album" sheet opened straight from a `week.history` week menu, with that
 * week's photos checked ([weekStart] = ISO date of the week's Monday, group time zone).
 */
@Serializable
data class WeekAlbum(val groupId: String, val weekStart: String) : AppRoute {
    override val surface get() = "week.edit"
}

/**
 * Hand-off keys set on the destination's `SavedStateHandle` when the social screens open another
 * group's route that has no argument for them (the other group reads them; nothing else changes).
 */
object SocialHandoff {
    /**
     * Set on the [AppRoute.Camera] entry when `photo.viewer` opens the camera to reply to a photo
     * with a photo: the replied post id, for `create_post`'s `p_reply_to_post_id`
     * (core:data `NewPost.replyToPostId` / `PostOptions.replyToPostId`).
     */
    const val REPLY_TO_POST_ID = "replyToPostId"
}
