package app.data.repo

import app.data.error.dataCall
import app.data.model.Album
import app.data.model.AlbumItem
import app.data.model.Collage
import app.data.model.DailyInvitation
import app.data.model.FavoritePhoto
import app.data.model.FavoriteRow
import app.data.model.GroupCollage
import app.data.model.GroupTribute
import app.data.model.HiddenMemory
import app.data.model.HistoryWeek
import app.data.model.InstantSerializer
import app.data.model.MemoryHide
import app.data.model.OnThisDayItem
import app.data.model.Post
import app.data.model.RenderStatus
import app.data.model.Tribute
import app.data.model.TributeContribution
import app.data.model.TributeRequest
import app.data.model.WallItem
import app.data.model.WeeklyRecap
import app.data.model.YearStory
import app.data.offline.CacheKey
import app.data.offline.DataState
import app.data.offline.OfflineCache
import app.data.offline.cachedFlow
import app.data.remote.Api
import app.data.remote.Rpc
import app.data.remote.Tables
import io.github.jan.supabase.postgrest.from
import io.github.jan.supabase.postgrest.query.Order
import kotlinx.coroutines.flow.Flow
import kotlinx.serialization.builtins.ListSerializer
import java.time.Clock
import java.time.Instant
import java.time.LocalDate

/** Walls, history weeks and "on this day" (docs/API.md §6.4). */
class BrowseRepository(private val api: Api, private val cache: OfflineCache, private val clock: Clock = Clock.systemUTC()) {

    /**
     * A person's photos as you see them (only groups you share; one entry per photo), plus collages
     * containing them. Newest first; page with [before] = the last `created_at`. Your own: your id.
     */
    suspend fun wall(userId: String, before: Instant? = null, limit: Int = WALL_PAGE): List<WallItem> =
        api.rpcList(Rpc.Wall, WallItem.serializer()) {
            put("p_user_id", userId)
            opt("p_before", before)
            put("p_limit", limit)
        }

    fun observeWall(userId: String): Flow<DataState<List<WallItem>>> =
        cachedFlow(cache, CacheKey.wall(userId), ListSerializer(WallItem.serializer()), clock) { wall(userId) }

    /** Weeks with posts, newest first; page with [beforeWeek] = the last `week_start` (exclusive). */
    suspend fun historyWeeks(groupId: String, beforeWeek: LocalDate? = null, limit: Int = HISTORY_PAGE): List<HistoryWeek> =
        api.rpcList(Rpc.GroupHistoryWeeks, HistoryWeek.serializer()) {
            put("p_group_id", groupId)
            opt("p_before_week", beforeWeek)
            put("p_limit", limit)
        }

    fun observeHistory(groupId: String): Flow<DataState<List<HistoryWeek>>> =
        cachedFlow(cache, CacheKey.history(groupId), ListSerializer(HistoryWeek.serializer()), clock) { historyWeeks(groupId) }

    /** The group's ready same-moment collages whose day (group-local) is in [from]…[to], newest first (migration 0033). */
    suspend fun groupCollages(groupId: String, from: LocalDate? = null, to: LocalDate? = null): List<GroupCollage> =
        api.rpcList(Rpc.GroupCollages, GroupCollage.serializer()) {
            put("p_group_id", groupId)
            opt("p_from", from)
            opt("p_to", to)
        }

    /** Posts from the same month and day (group time zone) in earlier years, newest first. */
    suspend fun onThisDay(groupId: String, localDate: LocalDate): List<OnThisDayItem> =
        api.rpcList(Rpc.OnThisDay, OnThisDayItem.serializer()) {
            put("p_group_id", groupId)
            put("p_local_date", localDate)
        }

    /**
     * `hide_memory` (migration 0038): one photo ([mediaId], by media, so every group it was sent to) or one calendar day
     * ([day]) leaves your memories (On This Day, the Memories widget, the shuffle), for you only. Exactly one of the two.
     * Idempotent: hiding again returns the existing row.
     */
    suspend fun hideMemory(mediaId: String? = null, day: LocalDate? = null): MemoryHide {
        require((mediaId == null) != (day == null)) { "hide_memory: a photo or a day" }
        return api.rpc(Rpc.HideMemory, MemoryHide.serializer()) {
            opt("p_media_id", mediaId)
            opt("p_day", day)
        }
    }

    /** `unhide_memory`: a hidden photo or day shows in your memories again (your own rows only; unknown ids: no-op). */
    suspend fun unhideMemory(hideId: String) = api.rpcUnit(Rpc.UnhideMemory) { put("p_id", hideId) }

    /** `my_hidden_memories`: hidden days and the hidden photos you can still see, newest hide first (Settings). */
    suspend fun hiddenMemories(): List<HiddenMemory> = api.rpcList(Rpc.MyHiddenMemories, HiddenMemory.serializer())

    companion object {
        const val WALL_PAGE = 50
        const val HISTORY_PAGE = 8
    }
}

/** Weekly recaps (docs/API.md §5.14, `update_recap`). */
class RecapRepository(private val api: Api, private val cache: OfflineCache, private val clock: Clock = Clock.systemUTC()) {

    /** Recaps of the group, newest week first. */
    suspend fun recaps(groupId: String, limit: Int = 12): List<WeeklyRecap> = api.select(Tables.WEEKLY_RECAPS, WeeklyRecap.serializer()) {
        filter { eq("group_id", groupId) }
        order("week_start", Order.DESCENDING)
        limit(limit.toLong())
    }

    fun observeRecaps(groupId: String): Flow<DataState<List<WeeklyRecap>>> =
        cachedFlow(cache, CacheKey.recaps(groupId), ListSerializer(WeeklyRecap.serializer()), clock) { recaps(groupId) }

    suspend fun recap(recapId: String): WeeklyRecap? =
        api.selectSingleOrNull(Tables.WEEKLY_RECAPS, WeeklyRecap.serializer()) { filter { eq("id", recapId) } }

    suspend fun recapForWeek(groupId: String, weekStart: LocalDate): WeeklyRecap? =
        api.selectSingleOrNull(Tables.WEEKLY_RECAPS, WeeklyRecap.serializer()) {
            filter {
                eq("group_id", groupId)
                eq("week_start", weekStart.toString())
            }
        }

    /**
     * Any member, once `ready`. [items] = the new order (null = unchanged); [text] null = unchanged,
     * `""` clears it.
     */
    suspend fun updateRecap(recapId: String, items: List<String>? = null, text: String? = null, collageIds: List<String>? = null): WeeklyRecap =
        api.rpc(Rpc.UpdateRecap, WeeklyRecap.serializer()) {
            put("p_recap_id", recapId)
            opt("p_items", items)
            opt("p_text", text)
            opt("p_collage_ids", collageIds)
        }
}

/** Albums: named selections visible to the whole group (docs/API.md §5.15, §6.4). */
class AlbumRepository(private val api: Api, private val cache: OfflineCache, private val clock: Clock = Clock.systemUTC()) {

    suspend fun albums(groupId: String): List<Album> = api.select(Tables.ALBUMS, Album.serializer()) {
        filter { eq("group_id", groupId) }
        order("created_at", Order.DESCENDING)
    }

    fun observeAlbums(groupId: String): Flow<DataState<List<Album>>> =
        cachedFlow(cache, CacheKey.albums(groupId), ListSerializer(Album.serializer()), clock) { albums(groupId) }

    /** The album's items in order (items whose post you cannot see are not returned). */
    suspend fun items(albumId: String): List<AlbumItem> = api.select(Tables.ALBUM_ITEMS, AlbumItem.serializer()) {
        filter { eq("album_id", albumId) }
        order("position", Order.ASCENDING)
    }

    /** Distinct visible posts of the group, kept in the given order. */
    suspend fun saveAlbum(groupId: String, name: String, postIds: List<String>): Album = api.rpc(Rpc.SaveAlbum, Album.serializer()) {
        put("p_group_id", groupId)
        put("p_name", name)
        put("p_post_ids", postIds)
    }

    suspend fun renameAlbum(albumId: String, name: String): Album = api.rpc(Rpc.RenameAlbum, Album.serializer()) {
        put("p_album_id", albumId)
        put("p_name", name)
    }

    /** The creator or a group admin. */
    suspend fun deleteAlbum(albumId: String) = api.rpcUnit(Rpc.DeleteAlbum) { put("p_album_id", albumId) }

    /**
     * `add_to_album` (any member, migration 0039): visible posts of the album's group, after its last item in this order;
     * photos already there are skipped. Errors: `album_not_found`, `invalid_items`.
     */
    suspend fun addToAlbum(albumId: String, postIds: List<String>): Album = api.rpc(Rpc.AddToAlbum, Album.serializer()) {
        put("p_album_id", albumId)
        put("p_post_ids", postIds)
    }

    /**
     * `remove_from_album` (migration 0039): photos you added; the album's creator and group admins remove any. The photos
     * stay in the group. Errors: `album_not_found`, `not_allowed` (403).
     */
    suspend fun removeFromAlbum(albumId: String, postIds: List<String>) = api.rpcUnit(Rpc.RemoveFromAlbum) {
        put("p_album_id", albumId)
        put("p_post_ids", postIds)
    }
}

/**
 * Private favorites (migration 0038, docs/API.md §6.4): a heart only you see, on any photo you can see. Nobody else reads
 * them; never a count. Not cached on disk (a deleted photo must not survive on the device).
 */
class FavoriteRepository(private val api: Api) {

    /** `set_favorite`: [on] adds (idempotent), false removes. Errors: `media_not_found`. */
    suspend fun setFavorite(mediaId: String, on: Boolean) = api.rpcUnit(Rpc.SetFavorite) {
        put("p_media_id", mediaId)
        put("p_on", on)
    }

    /** `my_favorites`: newest favorite first; page with [before] = the last `favorited_at`; [limit] 1–200. */
    suspend fun myFavorites(before: Instant? = null, limit: Int = PAGE): List<FavoritePhoto> =
        api.rpcList(Rpc.MyFavorites, FavoritePhoto.serializer()) {
            opt("p_before", before)
            put("p_limit", limit)
        }

    /** Which of [mediaIds] you favorited (your own `favorites` rows: what the viewer's menu says). */
    suspend fun favoriteMediaIds(mediaIds: Collection<String>): Set<String> {
        if (mediaIds.isEmpty()) return emptySet()
        return api.select(Tables.FAVORITES, FavoriteRow.serializer()) {
            filter { isIn("media_id", mediaIds.distinct()) }
        }.mapTo(HashSet()) { it.mediaId }
    }

    companion object {
        /** `favorites`: `my_favorites(p_limit: 60)`. */
        const val PAGE = 60
    }
}

/** The December year story (docs/API.md §5.19). */
class YearStoryRepository(private val api: Api) {

    suspend fun yearStories(groupId: String): List<YearStory> = api.select(Tables.YEAR_STORIES, YearStory.serializer()) {
        filter { eq("group_id", groupId) }
        order("year", Order.DESCENDING)
    }

    suspend fun yearStory(groupId: String, year: Int): YearStory? =
        api.selectSingleOrNull(Tables.YEAR_STORIES, YearStory.serializer()) {
            filter {
                eq("group_id", groupId)
                eq("year", year)
            }
        }
}

/** Daily same-moment invitations and their collages (docs/API.md §5.12, §5.13, recipe 9.5). */
class InvitationRepository(private val api: Api, private val clock: Clock = Clock.systemUTC()) {

    /** The group's open invitation (fired, `closes_at` not passed), or null. */
    suspend fun currentInvitation(groupId: String, now: Instant = clock.instant()): DailyInvitation? =
        api.select(Tables.DAILY_INVITATIONS, DailyInvitation.serializer()) {
            filter {
                eq("group_id", groupId)
                gte("closes_at", InstantSerializer.format(now))
            }
            order("fires_at", Order.DESCENDING)
            limit(1)
        }.firstOrNull()?.takeIf { it.isOpen(now) }

    suspend fun invitation(invitationId: String): DailyInvitation? =
        api.selectSingleOrNull(Tables.DAILY_INVITATIONS, DailyInvitation.serializer()) { filter { eq("id", invitationId) } }

    /**
     * `open_invitations` (migration 0035): your groups' invitations open now by the server's clock, soonest to close
     * first ([groupIds] null = all of your groups). The group screen and the camera's send-to show them with their
     * countdown; an answer from there counts like one from the notification.
     */
    suspend fun openInvitations(groupIds: List<String>? = null): List<DailyInvitation> =
        api.rpcList(Rpc.OpenInvitations, DailyInvitation.serializer()) { opt("p_group_ids", groupIds) }

    /** Your posts made inside that invitation's window ("my answer"); empty if none. */
    suspend fun myAnswer(invitationId: String): List<Post> = api.select(Tables.POSTS, Post.serializer()) {
        filter {
            eq("invitation_id", invitationId)
            eq("author_id", api.requireUserId())
        }
        order("created_at", Order.ASCENDING)
    }

    /** Ready collages of the group, newest first (show only `ready`, §5.13). */
    suspend fun collages(groupId: String, limit: Int = 30): List<Collage> = api.select(Tables.COLLAGES, Collage.serializer()) {
        filter {
            eq("group_id", groupId)
            eq("status", RenderStatus.Ready.wire)
        }
        order("created_at", Order.DESCENDING)
        limit(limit.toLong())
    }

    suspend fun collage(collageId: String): Collage? =
        api.selectSingleOrNull(Tables.COLLAGES, Collage.serializer()) { filter { eq("id", collageId) } }

    suspend fun collageForInvitation(invitationId: String): Collage? =
        api.selectSingleOrNull(Tables.COLLAGES, Collage.serializer()) { filter { eq("invitation_id", invitationId) } }
}

/**
 * Birthday tributes (docs/API.md §5.16–§5.18, `set_birthday`, `contribute_tribute`). Nobody sees
 * who else contributed; the honoree never sees requests about them.
 */
class BirthdayRepository(private val api: Api, private val profiles: ProfileRepository, private val clock: Clock = Clock.systemUTC()) {

    /** Opt in with a date to receive tributes (same as [ProfileRepository.setBirthday]). */
    suspend fun setBirthday(birthday: LocalDate?, optIn: Boolean) = profiles.setBirthday(birthday, optIn)

    /** Open requests visible to you (never about you), soonest due first. */
    suspend fun openRequests(now: Instant = clock.instant()): List<TributeRequest> =
        api.select(Tables.TRIBUTE_REQUESTS, TributeRequest.serializer()) {
            filter { gt("due_at", InstantSerializer.format(now)) }
            order("due_at", Order.ASCENDING)
        }.filter { it.isOpen(now) }

    suspend fun request(requestId: String): TributeRequest? =
        api.selectSingleOrNull(Tables.TRIBUTE_REQUESTS, TributeRequest.serializer()) { filter { eq("id", requestId) } }

    /** Your contribution to [requestId], if any (you can only ever read your own). */
    suspend fun myContribution(requestId: String): TributeContribution? =
        api.selectSingleOrNull(Tables.TRIBUTE_CONTRIBUTIONS, TributeContribution.serializer()) { filter { eq("request_id", requestId) } }

    /**
     * Contribute (or replace your photo and line until `due_at`). The photo must be from that group
     * and posted by you or one you are self-tagged in.
     */
    suspend fun contribute(requestId: String, postId: String, line: String): TributeContribution =
        api.rpc(Rpc.ContributeTribute, TributeContribution.serializer()) {
            put("p_request_id", requestId)
            put("p_post_id", postId)
            put("p_line", line)
        }

    /** Withdraw your contribution before `due_at` (direct DELETE, §5.0). */
    suspend fun withdraw(requestId: String) {
        val uid = api.requireUserId()
        dataCall {
            api.client.from(Tables.TRIBUTE_CONTRIBUTIONS).delete {
                filter {
                    eq("request_id", requestId)
                    eq("contributor_id", uid)
                }
            }
        }
    }

    /** Tributes made for you, once delivered (RLS hides them until then). */
    suspend fun tributesForMe(): List<Tribute> = api.select(Tables.TRIBUTES, Tribute.serializer()) {
        filter { eq("honoree_id", api.requireUserId()) }
        order("created_at", Order.DESCENDING)
    }

    suspend fun tribute(tributeId: String): Tribute? = api.selectSingleOrNull(Tables.TRIBUTES, Tribute.serializer()) { filter { eq("id", tributeId) } }

    /** Tributes in [groupId] you may see (once delivered: your own and the ones you contributed to; migration 0034). */
    suspend fun tributes(groupId: String): List<Tribute> = api.select(Tables.TRIBUTES, Tribute.serializer()) {
        filter { eq("group_id", groupId) }
        order("created_at", Order.DESCENDING)
    }

    /**
     * `group_tributes` (migration 0034): the group's delivered birthday videos you may watch — your own and the ones you
     * contributed to — newest delivery first (the group screen's cards).
     */
    suspend fun groupTributes(groupId: String): List<GroupTribute> =
        api.rpcList(Rpc.GroupTributes, GroupTribute.serializer()) { put("p_group_id", groupId) }
}
