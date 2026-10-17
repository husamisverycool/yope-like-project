package app.feature.account.testing

import app.data.error.DataError
import app.data.error.DataException
import app.data.model.Block
import app.data.model.Group
import app.data.model.GroupInvite
import app.data.model.GroupKind
import app.data.model.GroupMember
import app.data.model.HiddenMemory
import app.data.model.Media
import app.data.model.MediaKind
import app.data.model.MemberRole
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
import app.feature.account.data.AccountBackend
import app.feature.account.data.AccountStatus
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.flow
import java.io.File
import java.time.Instant
import java.time.LocalDate
import java.time.LocalTime

/**
 * DEBUG builds only: an in-memory [AccountBackend] for view-model tests, snapshot tests and flow
 * tests (feature:account and :app debug unit tests). Every call can be made to fail with a typed
 * [DataError] ([failures]) or to wait for a gate ([gates]) so in-flight states can be observed.
 */
class FakeAccountBackend(val now: Instant = Instant.parse("2026-10-15T17:00:00Z")) : AccountBackend {
    val auth = MutableStateFlow<AuthState>(AuthState.SignedOut)
    override val authState: StateFlow<AuthState> = auth
    override val currentUserId: String? get() = (auth.value as? AuthState.SignedIn)?.userId
    val onlineState = MutableStateFlow(true)
    override val online: Flow<Boolean> = onlineState

    /** Method name → the error its next calls throw. */
    val failures = HashMap<String, DataError>()
    /** Method name → a gate the call waits on (complete it to let the call finish). */
    val gates = HashMap<String, CompletableDeferred<Unit>>()
    val calls = mutableListOf<String>()

    // Data ------------------------------------------------------------------------------------------
    var meId = "u-me"
    var phone = "+14155550100"
    var validCode = "123456"
    val profiles = LinkedHashMap<String, Profile>()
    var ageConfirmed = false
    var birthday: Pair<LocalDate, Boolean>? = null
    var config = PublicAppConfig(invitationWindowSeconds = 120, maxGroupMembers = 30, weekStartIsodow = 1, freeHistoryDays = null, minAgeYears = 13)
    val groups = LinkedHashMap<String, Group>()
    val members = LinkedHashMap<String, MutableList<GroupMember>>()
    val posts = LinkedHashMap<String, MutableList<Post>>()
    val media = LinkedHashMap<String, Media>()
    val invites = mutableListOf<GroupInvite>()
    val blocks = mutableListOf<Block>()
    var notificationSettings: NotificationSettings? = null
    val reports = mutableListOf<Triple<ReportTargetKind, String, String>>()
    val events = MutableSharedFlow<GroupEvent>(extraBufferCapacity = 16)
    /** Pages served from "cache" first by the observe* flows (null = nothing cached). */
    var cachedGroups: List<Group>? = null
    var accountDeleted = false
    var premium = false
    private var nextId = 1

    private suspend fun call(name: String) {
        calls += name
        gates[name]?.await()
        failures[name]?.let { throw DataException(it) }
    }

    fun id(prefix: String) = prefix + "-" + (nextId++)

    fun profile(id: String, name: String, avatar: String? = null): Profile =
        Profile(id, name, avatar, now, now).also { profiles[id] = it }

    fun group(id: String, name: String, kind: GroupKind = GroupKind.Friends, createdBy: String = meId, cover: String? = null, createdAt: Instant = now): Group =
        Group(id, name, kind, cover, "UTC", null, null, false, createdBy, createdAt, createdAt).also { groups[id] = it }

    fun member(groupId: String, userId: String, role: MemberRole = MemberRole.Member, joinedAt: Instant = now, muted: Boolean = false) {
        members.getOrPut(groupId) { mutableListOf() } += GroupMember(groupId, userId, role, muted, joinedAt)
    }

    fun post(groupId: String, authorId: String, at: Instant, caption: String? = null): Post {
        val mediaId = id("m")
        media[mediaId] = Media(mediaId, authorId, MediaKind.Photo, "u/$authorId/$mediaId/original.jpg", null, null, null, null, null, null, null, null, null, null, null, null, null, at)
        val p = Post(id("p"), mediaId, groupId, authorId, caption, null, null, null, false, null, at)
        posts.getOrPut(groupId) { mutableListOf() }.add(0, p)
        return p
    }

    fun signIn(uid: String = meId) {
        auth.value = AuthState.SignedIn(uid)
    }

    // Auth ------------------------------------------------------------------------------------------
    override suspend fun requestOtp(phone: String) = call("requestOtp")
    override suspend fun verifyOtp(phone: String, code: String): String {
        call("verifyOtp")
        if (code != validCode) throw DataException(DataError.Auth(app.data.error.AuthFailure.InvalidOrExpiredCode, null))
        if (profiles[meId] == null) profile(meId, "")
        signIn()
        return meId
    }

    override suspend fun signOut() {
        calls += "signOut"
        auth.value = AuthState.SignedOut
    }

    override suspend fun accountStatus(): AccountStatus {
        call("accountStatus")
        return AccountStatus(ageConfirmed, profiles[meId]?.displayName?.isNotBlank() == true)
    }

    override suspend fun publicConfig(): PublicAppConfig = config.also { call("publicConfig") }
    override suspend fun confirmAge(birthdate: LocalDate) {
        call("confirmAge")
        ageConfirmed = true
    }

    override suspend fun setBirthday(birthday: LocalDate, optIn: Boolean) {
        call("setBirthday")
        this.birthday = birthday to optIn
    }

    override suspend fun me(): Profile = (profiles[meId] ?: profile(meId, "")).also { call("me") }
    override suspend fun updateDisplayName(name: String): Profile {
        call("updateDisplayName")
        return profile(meId, name, profiles[meId]?.avatarPath)
    }

    override suspend fun setAvatar(jpeg: File): Profile {
        call("setAvatar")
        return profile(meId, profiles[meId]?.displayName.orEmpty(), "avatars/$meId/a.jpg")
    }

    override suspend fun removeAvatar(): Profile {
        call("removeAvatar")
        return profile(meId, profiles[meId]?.displayName.orEmpty(), null)
    }

    override suspend fun birthday(): LocalDate? = birthday?.takeIf { it.second }?.first.also { call("birthday") }

    override fun currentPhone(): String? = phone.takeIf { currentUserId != null }
    override suspend fun signedUrls(paths: Collection<String>): Map<String, String> = emptyMap()
    override suspend fun profiles(ids: Collection<String>): List<Profile> = ids.mapNotNull(profiles::get).also { call("profiles") }

    // Groups ----------------------------------------------------------------------------------------
    private fun myGroupList(): List<Group> = groups.values.filter { g -> members[g.id].orEmpty().any { it.userId == meId } }

    override fun observeMyGroups(): Flow<DataState<List<Group>>> = flow {
        val cached = cachedGroups
        emit(DataState(cached, if (cached != null) DataState.Source.Cache else DataState.Source.None, null, refreshing = true, error = null))
        try {
            call("myGroups")
            emit(DataState(myGroupList(), DataState.Source.Network, now, refreshing = false, error = null))
        } catch (e: DataException) {
            emit(DataState(cached, if (cached != null) DataState.Source.Cache else DataState.Source.None, null, refreshing = false, error = e.error))
        }
    }

    override suspend fun newestPost(groupId: String): Post? = posts[groupId]?.maxByOrNull { it.createdAt }.also { call("newestPost") }
    override suspend fun group(groupId: String): Group? = groups[groupId].also { call("group") }
    override suspend fun uploadCover(jpeg: File): String = "u/$meId/covers/c.jpg".also { call("uploadCover") }

    override suspend fun createGroup(name: String, kind: GroupKind, timeZone: String, coverPath: String?): Group {
        call("createGroup")
        val g = group(id("g"), name, kind, meId, coverPath)
        member(g.id, meId, MemberRole.Admin)
        return g
    }

    override suspend fun updateGroup(groupId: String, name: String?, kind: GroupKind?, cover: CoverChange): Group {
        call("updateGroup")
        val g = groups.getValue(groupId)
        return g.copy(name = name ?: g.name, kind = kind ?: g.kind).also { groups[groupId] = it }
    }

    override fun observeMembers(groupId: String): Flow<DataState<List<Member>>> = flow {
        try {
            call("members")
            emit(DataState(members[groupId].orEmpty().map { Member(it, profiles[it.userId]) }, DataState.Source.Network, now, false, null))
        } catch (e: DataException) {
            emit(DataState(null, DataState.Source.None, null, false, e.error))
        }
    }

    override suspend fun myMemberships(): List<GroupMember> = members.values.flatten().filter { it.userId == meId }.also { call("myMemberships") }
    override suspend fun activeInvites(groupId: String): List<GroupInvite> = invites.filter { it.groupId == groupId && it.isUsable(now) }.also { call("activeInvites") }

    override suspend fun createInvite(groupId: String): GroupInvite {
        call("createInvite")
        return GroupInvite(id("i"), groupId, "AbCdEfGhIjKlMnOpQrStUvWx", meId, now, null, null).also { invites += it }
    }

    override suspend fun revokeInvite(token: String) {
        call("revokeInvite")
        invites.replaceAll { if (it.token == token) it.copy(revokedAt = now) else it }
    }

    override suspend fun joinGroup(token: String): Group {
        call("joinGroup")
        val invite = invites.firstOrNull { it.token == token } ?: throw DataException(DataError.Api(app.data.error.ApiError.InviteNotFound, "invite_not_found", 404, null))
        member(invite.groupId, meId)
        return groups.getValue(invite.groupId)
    }

    override suspend fun leaveGroup(groupId: String) {
        call("leaveGroup")
        members[groupId]?.removeAll { it.userId == meId }
    }

    override suspend fun removeMember(groupId: String, userId: String) {
        call("removeMember")
        members[groupId]?.removeAll { it.userId == userId }
    }

    /** Like `set_member_role`: admins only; never leaves the group without an admin (`last_admin`). */
    override suspend fun setMemberRole(groupId: String, userId: String, role: MemberRole) {
        call("setMemberRole")
        val rows = members[groupId] ?: throw DataException(DataError.Api(app.data.error.ApiError.NotGroupMember, "not_group_member", 403, null))
        if (rows.none { it.userId == meId && it.role == MemberRole.Admin }) {
            throw DataException(DataError.Api(app.data.error.ApiError.NotGroupAdmin, "not_group_admin", 403, null))
        }
        if (rows.none { it.userId == userId }) throw DataException(DataError.Api(app.data.error.ApiError.MemberNotFound, "member_not_found", 404, null))
        if (role == MemberRole.Member && rows.none { it.userId != userId && it.role == MemberRole.Admin }) {
            throw DataException(DataError.Api(app.data.error.ApiError.LastAdmin, "last_admin", 409, null))
        }
        rows.replaceAll { if (it.userId == userId) it.copy(role = role) else it }
    }

    override suspend fun setMuted(groupId: String, muted: Boolean) {
        call("setMuted")
        members[groupId]?.replaceAll { if (it.userId == meId) it.copy(muted = muted) else it }
    }

    override suspend fun setInvitationHours(groupId: String, start: LocalTime?, end: LocalTime?): Group {
        call("setInvitationHours")
        return groups.getValue(groupId).copy(wakingStart = start, wakingEnd = end).also { groups[groupId] = it }
    }

    override suspend fun setInvitationPaused(groupId: String, paused: Boolean): Group {
        call("setInvitationPaused")
        return groups.getValue(groupId).copy(invitationPaused = paused).also { groups[groupId] = it }
    }

    // Feed ------------------------------------------------------------------------------------------
    override fun observeFeed(groupId: String): Flow<DataState<List<Post>>> = flow {
        try {
            call("feed")
            emit(DataState(posts[groupId].orEmpty().sortedByDescending { it.createdAt }, DataState.Source.Network, now, false, null))
        } catch (e: DataException) {
            emit(DataState(null, DataState.Source.None, null, false, e.error))
        }
    }

    override suspend fun feedPage(groupId: String, before: Instant): List<Post> = posts[groupId].orEmpty().filter { it.createdAt < before }.also { call("feedPage") }
    override suspend fun media(ids: Collection<String>): List<Media> = ids.mapNotNull(media::get)
    override suspend fun post(postId: String): Post? = posts.values.flatten().firstOrNull { it.id == postId }
    override fun groupEvents(groupId: String): Flow<GroupEvent> = events

    // Settings --------------------------------------------------------------------------------------
    override suspend fun notificationSettings(): NotificationSettings? = notificationSettings.also { call("notificationSettings") }
    override suspend fun setQuietHours(start: LocalTime?, end: LocalTime?, timeZone: String?): NotificationSettings {
        call("setQuietHours")
        return NotificationSettings(
            meId, start, end, timeZone, now, notificationSettings?.overnight ?: true, notificationSettings?.pausedUntil,
            notificationSettings?.memories ?: false, notificationSettings?.memoryTimeZone,
        )
            .also { notificationSettings = it }
    }
    override suspend fun setOvernightAlerts(on: Boolean): NotificationSettings {
        call("setOvernightAlerts")
        val current = notificationSettings ?: NotificationSettings(meId, null, null, null, now)
        return current.copy(overnight = on, updatedAt = now).also { notificationSettings = it }
    }
    /** Pause All until the next midnight of [timeZone] (the server's rule, migration 0037). */
    override suspend fun setNotificationsPaused(paused: Boolean, timeZone: String?): NotificationSettings {
        call("setNotificationsPaused")
        val zone = timeZone?.let(java.time.ZoneId::of) ?: java.time.ZoneOffset.UTC
        val until = if (paused) now.atZone(zone).toLocalDate().plusDays(1).atStartOfDay(zone).toInstant() else null
        val current = notificationSettings ?: NotificationSettings(meId, null, null, null, now)
        return current.copy(pausedUntil = until, updatedAt = now).also { notificationSettings = it }
    }
    /** The memory notification on in [timeZone] (required, as the server) or off (the last zone is kept). */
    override suspend fun setMemoryAlerts(on: Boolean, timeZone: String?): NotificationSettings {
        call("setMemoryAlerts")
        require(!on || timeZone != null) { "invalid_time_zone" }
        val current = notificationSettings ?: NotificationSettings(meId, null, null, null, now)
        return current.copy(memories = on, memoryTimeZone = if (on) timeZone else current.memoryTimeZone, updatedAt = now)
            .also { notificationSettings = it }
    }

    // Safety ----------------------------------------------------------------------------------------
    override suspend fun blocked(): List<Block> = blocks.toList().also { call("blocked") }
    override suspend fun block(userId: String) {
        call("block")
        blocks += Block(meId, userId, now)
    }

    override suspend fun unblock(userId: String) {
        call("unblock")
        blocks.removeAll { it.blockedId == userId }
    }

    override suspend fun report(kind: ReportTargetKind, targetId: String, reason: String): String {
        call("report")
        reports += Triple(kind, targetId, reason)
        return id("r")
    }

    // Hidden memories (migration 0038) -------------------------------------------------------------------
    /** Your hidden photos and days, newest hide first (as `my_hidden_memories`). */
    val hiddenRows = mutableListOf<HiddenMemory>()

    override suspend fun hiddenMemories(): List<HiddenMemory> {
        call("hiddenMemories")
        return hiddenRows.toList()
    }

    override suspend fun unhideMemory(hideId: String) {
        call("unhideMemory")
        hiddenRows.removeAll { it.id == hideId }
    }

    // Account ---------------------------------------------------------------------------------------
    override suspend fun deleteAccount() {
        call("deleteAccount")
        accountDeleted = true
        auth.value = AuthState.SignedOut
    }

    override suspend fun isPremium(): Boolean = premium
}
