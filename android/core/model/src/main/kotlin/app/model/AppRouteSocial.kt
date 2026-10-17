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

    /** Only the opened photo. */
    Single,

    /**
     * The answers to a group week's question (`question.weekly` → the card opens them), oldest first; `contextId` =
     * question id (`question_answers`, docs/API.md §14.4).
     */
    Question,

    /**
     * A link to one photo (deep links, pushes, `groups.screen`'s strip, `plans.page`): the photo alone, or — when it
     * developed overnight — every photo of its group revealed with it, oldest first (`revealed_at`, camera.overnight C:
     * the reveal push names the first); `contextId` = the post id.
     */
    Reveal,

    /**
     * Your private favorites (`favorites`, `my_favorites`), newest favorite first; `contextId` = your user id. The header
     * names each photo's group, as from a wall.
     */
    Favorites,
     * The results of a `search.photos` search, in their order (newest first); `contextId` = the key the search page kept
     * them under (`SearchResults`); when they are gone (a new process), the opened photo alone.
     */
    Search,
}

/**
 * `photo.viewer` opened with the opener's photo list. [AppRoute.PhotoViewer] (links) shows the linked photo with the
 * photos revealed with it ([PhotoContext.Reveal]).
 */
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

/** `favorites`: your private favorites (walls.mine's heart capsule; owner decision 34). */
@Serializable
data object FavoritesRoute : AppRoute {
    override val surface get() = "favorites"
}

/**
 * `week.recap`'s recap list (`week.recap.layout.list`, a page sheet over the group): every ready / pending recap of the
 * group, newest first. [AppRoute.WeekRecap] opens one recap's preview. Entries: `groups.screen` recaps entry,
 * `albums.list` empty action.
 */
@Serializable
data class WeekRecapList(val groupId: String) : AppRoute {
    override val surface get() = "week.recap"
}

/** `week.edit`'s album sheet opened from a recap preview's "Save as Album" pill, with the recap's photos selected. */
@Serializable
data class WeekRecapAlbum(val groupId: String, val recapId: String) : AppRoute {
    override val surface get() = "week.edit"
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
 * `search.photos` (owner decision 34, research #6): search the photos by caption or chat, member ("I'm in this") and date
 * — in [groupId] (from `groups.screen`), or in all your groups when null (from `groups.list`).
 */
@Serializable
data class SearchPhotos(val groupId: String? = null) : AppRoute {
    override val surface get() = "search.photos"
}

/**
 * `settings.downloads` (owner decisions 29 and 34, research #2): every photo you shared ([albumId] null; settings.root →
 * Privacy → Download My Photos, free) or one album's photos (albums.view "•••" → Download Album, premium), saved to the photo
 * library page by page. An album's download starts at once.
 */
@Serializable
data class DownloadsRoute(val albumId: String? = null) : AppRoute {
    override val surface get() = "settings.downloads"
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
