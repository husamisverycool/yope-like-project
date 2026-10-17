package app.feature.account.data

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
import app.data.offline.DataState
import app.data.realtime.GroupEvent
import app.data.repo.AuthState
import app.data.repo.CoverChange
import app.data.repo.Member
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.StateFlow
import java.io.File
import java.time.Instant
import java.time.LocalDate
import java.time.LocalTime

/** What sign-up needs to know about an account to pick the next step (docs/API.md §2, §9.1). */
data class AccountStatus(val ageConfirmed: Boolean, val hasName: Boolean)

/**
 * Everything the account screens read or write, as one seam over `core:data` (docs/SCREENS_BRIEF.md
 * rule 5: data only through the data layer). [DataGraphAccountBackend] is the real implementation;
 * view-model tests use fakes. Every failure is a `DataException` carrying a typed `DataError`.
 */
interface AccountBackend {
    // Session -----------------------------------------------------------------------------------
    val authState: StateFlow<AuthState>
    val currentUserId: String?

    /** Device connectivity (`Connectivity.online`): current state first, then changes. */
    val online: Flow<Boolean>

    // Sign-up / sign-in (§2) ---------------------------------------------------------------------
    suspend fun requestOtp(phone: String)
    suspend fun verifyOtp(phone: String, code: String): String
    suspend fun signOut()
    suspend fun accountStatus(): AccountStatus
    suspend fun publicConfig(): PublicAppConfig
    suspend fun confirmAge(birthdate: LocalDate)
    suspend fun setBirthday(birthday: LocalDate, optIn: Boolean)
    suspend fun me(): Profile
    suspend fun updateDisplayName(name: String): Profile
    suspend fun setAvatar(jpeg: File): Profile
    /** Clears `profiles.avatar_path` (settings.account "Remove Profile Photo"). */
    suspend fun removeAvatar(): Profile
    /** Your saved birthday (`profile_private.birthday` while opted in), for settings.account's Birthday row. */
    suspend fun birthday(): LocalDate?
    /** The signed-in phone number (E.164), for `settings.account`. */
    fun currentPhone(): String?

    // Files and people ----------------------------------------------------------------------------
    suspend fun signedUrls(paths: Collection<String>): Map<String, String>
    suspend fun profiles(ids: Collection<String>): List<Profile>

    /** The group's ready same-moment collages whose day (group-local) is in [from]…[to] (`group_collages`, migration 0033). */
    suspend fun groupCollages(groupId: String, from: LocalDate, to: LocalDate): List<app.data.model.GroupCollage> = emptyList()

    // Groups (§5.3–§5.5, §6.1) ---------------------------------------------------------------------
    fun observeMyGroups(): Flow<DataState<List<Group>>>
    /** The newest post of [groupId]; the cached feed's first post when offline. */
    suspend fun newestPost(groupId: String): Post?
    suspend fun group(groupId: String): Group?
    suspend fun uploadCover(jpeg: File): String
    suspend fun createGroup(name: String, kind: GroupKind, timeZone: String, coverPath: String?): Group
    suspend fun updateGroup(groupId: String, name: String?, kind: GroupKind?, cover: CoverChange): Group
    fun observeMembers(groupId: String): Flow<DataState<List<Member>>>
    /** Your own membership rows (muted per group). */
    suspend fun myMemberships(): List<GroupMember>
    suspend fun activeInvites(groupId: String): List<GroupInvite>
    suspend fun createInvite(groupId: String): GroupInvite
    suspend fun revokeInvite(token: String)
    suspend fun joinGroup(token: String): Group
    suspend fun leaveGroup(groupId: String)
    suspend fun removeMember(groupId: String, userId: String)
    suspend fun setMuted(groupId: String, muted: Boolean)
    suspend fun setInvitationHours(groupId: String, start: LocalTime?, end: LocalTime?): Group
    suspend fun setInvitationPaused(groupId: String, paused: Boolean): Group

    // Feed (§5.7, §5.8, §8) -----------------------------------------------------------------------
    fun observeFeed(groupId: String): Flow<DataState<List<Post>>>
    suspend fun feedPage(groupId: String, before: Instant): List<Post>
    suspend fun media(ids: Collection<String>): List<Media>
    suspend fun post(postId: String): Post?
    fun groupEvents(groupId: String): Flow<GroupEvent>

    // Settings (§5.21) ----------------------------------------------------------------------------
    suspend fun notificationSettings(): NotificationSettings?
    suspend fun setQuietHours(start: LocalTime?, end: LocalTime?, timeZone: String?): NotificationSettings
    /** §14.3 the reveal push of overnight photos (`set_overnight_alerts`; `notification_settings.overnight`, default on). */
    suspend fun setOvernightAlerts(on: Boolean): NotificationSettings

    // Safety (§5.6, §6.3) -------------------------------------------------------------------------
    suspend fun blocked(): List<Block>
    suspend fun block(userId: String)
    suspend fun unblock(userId: String)
    suspend fun report(kind: ReportTargetKind, targetId: String, reason: String): String

    // Account -------------------------------------------------------------------------------------
    suspend fun deleteAccount()
    suspend fun isPremium(): Boolean
}
