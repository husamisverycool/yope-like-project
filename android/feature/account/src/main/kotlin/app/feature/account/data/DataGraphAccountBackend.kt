package app.feature.account.data

import app.data.DataGraph
import app.data.error.DataError
import app.data.error.DataException
import app.data.model.Block
import app.data.model.Group
import app.data.model.GroupInvite
import app.data.model.GroupKind
import app.data.model.GroupMember
import app.data.model.Media
import app.data.model.NotificationSettings
import app.data.model.Post
import app.data.model.Profile
import app.data.model.PublicAppConfig
import app.data.model.ReportTargetKind
import app.data.offline.CacheKey
import app.data.offline.DataState
import app.data.realtime.GroupEvent
import app.data.remote.Tables
import app.data.repo.AuthState
import app.data.repo.CoverChange
import app.data.repo.Member
import io.github.jan.supabase.auth.auth
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.emptyFlow
import kotlinx.coroutines.flow.flow
import kotlinx.coroutines.flow.flowOf
import kotlinx.serialization.builtins.ListSerializer
import java.io.File
import java.time.Instant
import java.time.LocalDate
import java.time.LocalTime

/** [AccountBackend] over the app's [DataGraph] (core:data repositories, cache, realtime, connectivity). */
class DataGraphAccountBackend(private val graph: DataGraph) : AccountBackend {
    override val authState: StateFlow<AuthState> get() = graph.auth.authState
    override val currentUserId: String? get() = graph.auth.currentUserId
    override val online: Flow<Boolean> get() = graph.connectivity.online

    override suspend fun requestOtp(phone: String) = graph.auth.requestOtp(phone)
    override suspend fun verifyOtp(phone: String, code: String): String = graph.auth.verifyOtp(phone, code)
    override suspend fun signOut() = graph.auth.signOut()

    override suspend fun accountStatus(): AccountStatus {
        val private = graph.profiles.privateProfile()
        val me = graph.profiles.me()
        return AccountStatus(ageConfirmed = private?.ageConfirmedAt != null, hasName = me.displayName.isNotBlank())
    }

    override suspend fun publicConfig(): PublicAppConfig = graph.appConfig.publicConfig()
    override suspend fun confirmAge(birthdate: LocalDate) {
        graph.profiles.confirmAge(birthdate)
    }

    override suspend fun setBirthday(birthday: LocalDate, optIn: Boolean) {
        graph.profiles.setBirthday(birthday, optIn)
    }

    override suspend fun me(): Profile = graph.profiles.me()
    override suspend fun updateDisplayName(name: String): Profile = graph.profiles.updateProfile(displayName = name)
    override suspend fun setAvatar(jpeg: File): Profile = graph.profiles.setAvatar(jpeg)
    override suspend fun removeAvatar(): Profile = graph.profiles.updateProfile(clearAvatar = true)
    override suspend fun birthday(): LocalDate? = graph.profiles.privateProfile()?.takeIf { it.birthdayOptIn }?.birthday
    override fun currentPhone(): String? = graph.client.auth.currentUserOrNull()?.phone?.takeIf { it.isNotBlank() }?.let { if (it.startsWith("+")) it else "+$it" }

    override suspend fun signedUrls(paths: Collection<String>): Map<String, String> = graph.signedUrls.urls(paths)
    override suspend fun profiles(ids: Collection<String>): List<Profile> = graph.profiles.profiles(ids)

    override fun observeMyGroups(): Flow<DataState<List<Group>>> = graph.groups.observeMyGroups()

    override suspend fun newestPost(groupId: String): Post? = try {
        graph.posts.feed(groupId, limit = 1).firstOrNull()
    } catch (e: DataException) {
        if (e.error != DataError.Network) throw e
        graph.cache.get(CacheKey.feed(groupId), ListSerializer(Post.serializer()))?.value?.firstOrNull() ?: throw e
    }

    override suspend fun group(groupId: String): Group? = graph.groups.group(groupId)
    override suspend fun uploadCover(jpeg: File): String = graph.groups.uploadCover(jpeg)
    override suspend fun createGroup(name: String, kind: GroupKind, timeZone: String, coverPath: String?): Group =
        graph.groups.createGroup(name, kind, timeZone, coverPath)

    override suspend fun updateGroup(groupId: String, name: String?, kind: GroupKind?, cover: CoverChange): Group =
        graph.groups.updateGroup(groupId, name = name, kind = kind, cover = cover)

    override fun observeMembers(groupId: String): Flow<DataState<List<Member>>> = graph.groups.observeMembers(groupId)

    override suspend fun myMemberships(): List<GroupMember> {
        val uid = graph.api.requireUserId()
        return graph.api.select(Tables.GROUP_MEMBERS, GroupMember.serializer()) { filter { eq("user_id", uid) } }
    }

    override suspend fun activeInvites(groupId: String): List<GroupInvite> = graph.groups.activeInvites(groupId)
    override suspend fun createInvite(groupId: String): GroupInvite = graph.groups.createInvite(groupId)
    override suspend fun revokeInvite(token: String) = graph.groups.revokeInvite(token)
    override suspend fun joinGroup(token: String): Group = graph.groups.joinGroup(token)
    override suspend fun leaveGroup(groupId: String) = graph.groups.leaveGroup(groupId)
    override suspend fun removeMember(groupId: String, userId: String) = graph.groups.removeMember(groupId, userId)
    override suspend fun setMuted(groupId: String, muted: Boolean) = graph.groups.setMuted(groupId, muted)
    override suspend fun setInvitationHours(groupId: String, start: LocalTime?, end: LocalTime?): Group = graph.groups.setInvitationHours(groupId, start, end)
    override suspend fun setInvitationPaused(groupId: String, paused: Boolean): Group = graph.groups.setInvitationPaused(groupId, paused)

    override fun observeFeed(groupId: String): Flow<DataState<List<Post>>> = graph.posts.observeFeed(groupId)
    override suspend fun feedPage(groupId: String, before: Instant): List<Post> = graph.posts.feed(groupId, before)
    override suspend fun media(ids: Collection<String>): List<Media> = graph.posts.media(ids)
    override suspend fun post(postId: String): Post? = graph.posts.post(postId)
    override fun groupEvents(groupId: String): Flow<GroupEvent> = graph.realtime.events(groupId)

    override suspend fun notificationSettings(): NotificationSettings? = graph.settings.notificationSettings()
    override suspend fun setQuietHours(start: LocalTime?, end: LocalTime?, timeZone: String?): NotificationSettings =
        graph.settings.setQuietHours(start, end, timeZone)

    override suspend fun blocked(): List<Block> = graph.safety.blocked()
    override suspend fun block(userId: String) = graph.safety.block(userId)
    override suspend fun unblock(userId: String) = graph.safety.unblock(userId)
    override suspend fun report(kind: ReportTargetKind, targetId: String, reason: String): String = graph.safety.report(kind, targetId, reason)

    override suspend fun deleteAccount() = graph.account.deleteAccount()
    override suspend fun isPremium(): Boolean = graph.entitlements.isPremium()
}

/**
 * The backend while `config/app.json` has no Supabase URL / key (core:data not configured): nobody
 * is signed in and every call fails with [DataError.NotConfigured], so screens show their error
 * states instead of crashing.
 */
class UnconfiguredAccountBackend : AccountBackend {
    private val state = MutableStateFlow<AuthState>(AuthState.SignedOut)
    override val authState: StateFlow<AuthState> = state.asStateFlow()
    override val currentUserId: String? = null
    override val online: Flow<Boolean> = flowOf(true)

    private fun fail(): Nothing = throw DataException(DataError.NotConfigured)

    override suspend fun requestOtp(phone: String) = fail()
    override suspend fun verifyOtp(phone: String, code: String): String = fail()
    override suspend fun signOut() = Unit
    override suspend fun accountStatus(): AccountStatus = fail()
    override suspend fun publicConfig(): PublicAppConfig = fail()
    override suspend fun confirmAge(birthdate: LocalDate) = fail()
    override suspend fun setBirthday(birthday: LocalDate, optIn: Boolean) = fail()
    override suspend fun me(): Profile = fail()
    override suspend fun updateDisplayName(name: String): Profile = fail()
    override suspend fun setAvatar(jpeg: File): Profile = fail()
    override suspend fun removeAvatar(): Profile = fail()
    override suspend fun birthday(): LocalDate? = fail()
    override fun currentPhone(): String? = null
    override suspend fun signedUrls(paths: Collection<String>): Map<String, String> = emptyMap()
    override suspend fun profiles(ids: Collection<String>): List<Profile> = fail()
    override fun observeMyGroups(): Flow<DataState<List<Group>>> =
        flow { emit(DataState(null, DataState.Source.None, null, refreshing = false, error = DataError.NotConfigured)) }
    override suspend fun newestPost(groupId: String): Post? = fail()
    override suspend fun group(groupId: String): Group? = fail()
    override suspend fun uploadCover(jpeg: File): String = fail()
    override suspend fun createGroup(name: String, kind: GroupKind, timeZone: String, coverPath: String?): Group = fail()
    override suspend fun updateGroup(groupId: String, name: String?, kind: GroupKind?, cover: CoverChange): Group = fail()
    override fun observeMembers(groupId: String): Flow<DataState<List<Member>>> =
        flow { emit(DataState(null, DataState.Source.None, null, refreshing = false, error = DataError.NotConfigured)) }
    override suspend fun myMemberships(): List<GroupMember> = fail()
    override suspend fun activeInvites(groupId: String): List<GroupInvite> = fail()
    override suspend fun createInvite(groupId: String): GroupInvite = fail()
    override suspend fun revokeInvite(token: String) = fail()
    override suspend fun joinGroup(token: String): Group = fail()
    override suspend fun leaveGroup(groupId: String) = fail()
    override suspend fun removeMember(groupId: String, userId: String) = fail()
    override suspend fun setMuted(groupId: String, muted: Boolean) = fail()
    override suspend fun setInvitationHours(groupId: String, start: LocalTime?, end: LocalTime?): Group = fail()
    override suspend fun setInvitationPaused(groupId: String, paused: Boolean): Group = fail()
    override fun observeFeed(groupId: String): Flow<DataState<List<Post>>> =
        flow { emit(DataState(null, DataState.Source.None, null, refreshing = false, error = DataError.NotConfigured)) }
    override suspend fun feedPage(groupId: String, before: Instant): List<Post> = fail()
    override suspend fun media(ids: Collection<String>): List<Media> = fail()
    override suspend fun post(postId: String): Post? = fail()
    override fun groupEvents(groupId: String): Flow<GroupEvent> = emptyFlow()
    override suspend fun notificationSettings(): NotificationSettings? = fail()
    override suspend fun setQuietHours(start: LocalTime?, end: LocalTime?, timeZone: String?): NotificationSettings = fail()
    override suspend fun blocked(): List<Block> = fail()
    override suspend fun block(userId: String) = fail()
    override suspend fun unblock(userId: String) = fail()
    override suspend fun report(kind: ReportTargetKind, targetId: String, reason: String): String = fail()
    override suspend fun deleteAccount() = fail()
    override suspend fun isPremium(): Boolean = false
}
