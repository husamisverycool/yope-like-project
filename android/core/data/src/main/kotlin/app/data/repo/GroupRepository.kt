package app.data.repo

import app.data.media.MediaStorage
import app.data.media.StoragePaths
import app.data.model.Group
import app.data.model.GroupInvite
import app.data.model.GroupKind
import app.data.model.GroupMember
import app.data.model.GroupMute
import app.data.model.InvitePreview
import app.data.model.MemberRole
import app.data.model.Profile
import app.data.offline.CacheKey
import app.data.offline.DataState
import app.data.offline.OfflineCache
import app.data.offline.cachedFlow
import app.data.remote.Api
import app.data.remote.Rpc
import app.data.remote.Tables
import io.github.jan.supabase.postgrest.query.Order
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.onEach
import kotlinx.serialization.Serializable
import kotlinx.serialization.builtins.ListSerializer
import java.io.File
import java.time.Clock
import java.time.LocalTime
import java.util.UUID

/** A member with their profile (null only if the profile is not visible, which RLS should not allow). */
@Serializable
data class Member(val member: GroupMember, val profile: Profile?)

/** `update_group`'s `p_cover_path`: null = unchanged, `""` = remove. */
sealed interface CoverChange {
    data object Keep : CoverChange
    data object Remove : CoverChange
    data class Set(val path: String) : CoverChange
}

/**
 * Groups, members, invites, joining and leaving, per-group mute and invitation hours
 * (docs/API.md §5.3–§5.5, §6.1). [myGroupIds] tracks the group list the person last loaded (the
 * session glue keeps the widget store in line with it).
 */
class GroupRepository(
    private val api: Api,
    private val storage: MediaStorage,
    private val cache: OfflineCache,
    private val clock: Clock = Clock.systemUTC(),
) {
    private val groupIds = MutableStateFlow<Set<String>?>(null)

    /** Ids of the groups you are in, as last loaded (null until the first load). */
    val myGroupIds: StateFlow<Set<String>?> = groupIds.asStateFlow()

    /** Every group you are a member of (RLS), oldest first. */
    suspend fun myGroups(): List<Group> = api.select(Tables.GROUPS, Group.serializer()) {
        order("created_at", Order.ASCENDING)
    }.also { groups -> groupIds.value = groups.mapTo(LinkedHashSet()) { it.id } }

    /** Cache-then-network group list for the home screen. */
    fun observeMyGroups(): Flow<DataState<List<Group>>> =
        cachedFlow(cache, CacheKey.Groups, ListSerializer(Group.serializer()), clock) { myGroups() }
            .onEach { state -> if (state.source == DataState.Source.Cache) state.value?.let { list -> if (groupIds.value == null) groupIds.value = list.mapTo(LinkedHashSet()) { it.id } } }

    suspend fun group(groupId: String): Group? = api.selectSingleOrNull(Tables.GROUPS, Group.serializer()) { filter { eq("id", groupId) } }

    /** Uploads a cover JPEG to `u/<uid>/covers/<uuid>.jpg` (before `create_group` / `update_group`). */
    suspend fun uploadCover(jpeg: File): String {
        val path = StoragePaths.cover(api.requireUserId(), UUID.randomUUID().toString())
        storage.upload(path, jpeg, "image/jpeg") { _, _ -> }
        return path
    }

    /** You become the only member, as admin. [timeZone] is the device's IANA zone. Waking hours: both or neither. */
    suspend fun createGroup(
        name: String,
        kind: GroupKind,
        timeZone: String,
        coverPath: String? = null,
        wakingStart: LocalTime? = null,
        wakingEnd: LocalTime? = null,
    ): Group = api.rpc(Rpc.CreateGroup, Group.serializer()) {
        put("p_name", name)
        put("p_kind", kind.wire)
        put("p_time_zone", timeZone)
        opt("p_cover_path", coverPath)
        opt("p_waking_start", wakingStart)
        opt("p_waking_end", wakingEnd)
    }.also(::remember)

    /** Admin only. Null = unchanged. Changing the time zone reschedules unfired invitations. */
    suspend fun updateGroup(
        groupId: String,
        name: String? = null,
        kind: GroupKind? = null,
        cover: CoverChange = CoverChange.Keep,
        timeZone: String? = null,
    ): Group = api.rpc(Rpc.UpdateGroup, Group.serializer()) {
        put("p_group_id", groupId)
        opt("p_name", name)
        opt("p_kind", kind?.wire)
        when (cover) {
            CoverChange.Keep -> Unit
            CoverChange.Remove -> put("p_cover_path", "")
            is CoverChange.Set -> put("p_cover_path", cover.path)
        }
        opt("p_time_zone", timeZone)
    }

    /**
     * `set_group_cover_from_post` (admins, update_group's rule; migration 0039): the photo's display rendition becomes the
     * cover. Errors: `not_group_admin`, `post_not_found`, `media_not_ready` (renditions not made yet).
     */
    suspend fun setCoverFromPost(groupId: String, postId: String): Group = api.rpc(Rpc.SetGroupCoverFromPost, Group.serializer()) {
        put("p_group_id", groupId)
        put("p_post_id", postId)
    }

    /** Members (joining order) with their profiles. */
    suspend fun members(groupId: String): List<Member> {
        val members = api.select(Tables.GROUP_MEMBERS, GroupMember.serializer()) {
            filter { eq("group_id", groupId) }
            order("joined_at", Order.ASCENDING)
        }
        if (members.isEmpty()) return emptyList()
        val profiles = api.select(Tables.PROFILES, Profile.serializer()) { filter { isIn("id", members.map { it.userId }) } }
            .associateBy { it.id }
        // Only your own mute is readable (group_mutes, own rows); everyone else reads as not muted.
        val me = api.requireUserId()
        val mutedHere = groupId in mutedGroupIds()
        return members.map { Member(if (it.userId == me) it.copy(muted = mutedHere) else it, profiles[it.userId]) }
    }

    /** Ids of the groups you muted (`group_mutes`, migration 0056; RLS returns your own rows only). */
    suspend fun mutedGroupIds(): Set<String> {
        val me = api.requireUserId()
        return api.select(Tables.GROUP_MUTES, GroupMute.serializer()) { filter { eq("user_id", me) } }.map { it.groupId }.toSet()
    }

    fun observeMembers(groupId: String): Flow<DataState<List<Member>>> =
        cachedFlow(cache, CacheKey.members(groupId), ListSerializer(Member.serializer()), clock) { members(groupId) }

    /** Invites of the group that still work (to share a link again). */
    suspend fun activeInvites(groupId: String): List<GroupInvite> {
        val now = clock.instant()
        return api.select(Tables.GROUP_INVITES, GroupInvite.serializer()) {
            filter { eq("group_id", groupId) }
            order("created_at", Order.DESCENDING)
        }.filter { it.isUsable(now) }
    }

    /** Any member. Build the link as `https://<domain>/i/<token>` (`DeepLink.Invite`). */
    suspend fun createInvite(groupId: String): GroupInvite = api.rpc(Rpc.CreateInvite, GroupInvite.serializer()) { put("p_group_id", groupId) }

    /** The invite's creator or a group admin. Idempotent. */
    suspend fun revokeInvite(token: String) = api.rpcUnit(Rpc.RevokeInvite) { put("p_token", token) }

    /** Works signed out (anon). Image paths need URLs signed by the web endpoint before joining (§6.1). */
    suspend fun invitePreview(token: String): InvitePreview = api.rpc(Rpc.InvitePreview, InvitePreview.serializer()) { put("p_token", token) }

    /** Idempotent; handles `group_full`, `invite_expired`, `invite_revoked` as typed errors. */
    suspend fun joinGroup(token: String): Group = api.rpc(Rpc.JoinGroup, Group.serializer()) { put("p_token", token) }.also(::remember)

    /** Admin only; not yourself. */
    suspend fun removeMember(groupId: String, userId: String) = api.rpcUnit(Rpc.RemoveMember) {
        put("p_group_id", groupId)
        put("p_user_id", userId)
    }

    /** `set_member_role` (migration 0054, admins). Errors: `not_group_admin`, `member_not_found`, `last_admin`. */
    suspend fun setMemberRole(groupId: String, userId: String, role: MemberRole) = api.rpcUnit(Rpc.SetMemberRole) {
        put("p_group_id", groupId)
        put("p_user_id", userId)
        put("p_role", role.wire)
    }

    /** The last member leaving deletes the group and all its content. */
    suspend fun leaveGroup(groupId: String) {
        api.rpcUnit(Rpc.LeaveGroup) { put("p_group_id", groupId) }
        forget(groupId)
    }

    /** Your own per-group push mute. */
    suspend fun setMuted(groupId: String, muted: Boolean) = api.rpcUnit(Rpc.SetGroupMuted) {
        put("p_group_id", groupId)
        put("p_muted", muted)
    }

    /** Admin only. Both null = the default window; `end <= start` wraps past midnight. */
    suspend fun setInvitationHours(groupId: String, start: LocalTime?, end: LocalTime?): Group =
        api.rpc(Rpc.SetGroupInvitationHours, Group.serializer()) {
            put("p_group_id", groupId)
            put("p_start", start)
            put("p_end", end)
        }

    /** Admin only. Pausing cancels the unfired invitation. */
    suspend fun setInvitationPaused(groupId: String, paused: Boolean): Group =
        api.rpc(Rpc.SetGroupInvitationPaused, Group.serializer()) {
            put("p_group_id", groupId)
            put("p_paused", paused)
        }

    /** After a removal is noticed elsewhere (e.g. realtime or a `not_group_member` error). */
    fun forget(groupId: String) {
        groupIds.value = groupIds.value?.minus(groupId)
    }

    /** Signed out: the list is unknown again. */
    fun reset() {
        groupIds.value = null
    }

    // Only adjusts a list that was loaded in full: a partial set would make the widget glue drop
    // the widgets of groups not loaded yet.
    private fun remember(group: Group) {
        groupIds.value = groupIds.value?.plus(group.id)
    }
}
