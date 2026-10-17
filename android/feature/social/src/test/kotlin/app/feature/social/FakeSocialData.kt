package app.feature.social

import app.data.error.ApiError
import app.data.error.DataError
import app.data.error.DataException
import app.data.model.Album
import app.data.model.AlbumItem
import app.data.model.ChatTyping
import app.data.model.Collage
import app.data.model.Group
import app.data.model.GroupKind
import app.data.model.GroupMember
import app.data.model.HistoryWeek
import app.data.model.Media
import app.data.model.MediaKind
import app.data.model.MemberRole
import app.data.model.Message
import app.data.model.MessageKind
import app.data.model.Post
import app.data.model.PostTag
import app.data.model.Profile
import app.data.model.PublicAppConfig
import app.data.model.RenderStatus
import app.data.model.SelfieReaction
import app.data.model.WallItem
import app.data.model.WallItemKind
import app.data.model.WeeklyRecap
import app.data.offline.DataState
import app.data.realtime.GroupEvent
import app.data.repo.Member
import app.data.repo.ReactionEntry
import app.feature.social.data.SocialData
import kotlinx.coroutines.channels.BufferOverflow
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.flow
import kotlinx.serialization.KSerializer
import kotlinx.serialization.json.Json
import java.io.File
import java.time.Instant
import java.time.LocalDate

/**
 * In-memory [SocialData] for view-model, snapshot and flow tests. Made-up people; photos are sample photos (TestPhotos).
 * [offline] makes every network call fail with [DataError.Network]; [failNext] makes the named call
 * fail once; [calls] records writes.
 */
class FakeSocialData(var me: String = ME) : SocialData {
    val groups = LinkedHashMap<String, Group>()
    val members = LinkedHashMap<String, MutableList<Member>>()
    val profiles = LinkedHashMap<String, Profile>()
    val messages = ArrayList<Message>()
    val posts = LinkedHashMap<String, Post>()
    val media = LinkedHashMap<String, Media>()
    val reactions = LinkedHashMap<String, MutableList<ReactionEntry>>()
    /** `message_reactions`: message id → rows, oldest first (one per person; `react_to_message` replaces). */
    val messageReactions = LinkedHashMap<String, MutableList<ReactionEntry>>()
    /** `chat_typing` rows of every group. */
    val typingRows = ArrayList<ChatTyping>()
    /** Each `set_typing` value sent, in order (kept apart from [calls]). */
    val typingCalls = ArrayList<Boolean>()
    /** `public_app_config`: nothing set by default (no Edit item, no typing calls). */
    var config = PublicAppConfig(invitationWindowSeconds = null, maxGroupMembers = null, weekStartIsodow = null, freeHistoryDays = null, minAgeYears = null)
    /** The time the fake's `chat_typing` read compares `until` with. */
    var typingNow: Instant = BASE
    /** `selfie_reactions`: post id → rows, oldest first (one per person). */
    val selfies = LinkedHashMap<String, MutableList<SelfieReaction>>()
    /** `post_tags`: post id → who said "I'm in this", in tag order. */
    val tagRows = LinkedHashMap<String, MutableList<String>>()
    val walls = LinkedHashMap<String, MutableList<WallItem>>()
    val collages = LinkedHashMap<String, Collage>()
    val weeks = LinkedHashMap<String, MutableList<HistoryWeek>>()
    val recaps = LinkedHashMap<String, WeeklyRecap>()
    val albums = LinkedHashMap<String, Album>()
    val albumItems = LinkedHashMap<String, MutableList<AlbumItem>>()
    val cache = HashMap<String, String>()
    val chatCache = HashMap<String, List<Message>>()
    val wallCache = HashMap<String, List<WallItem>>()
    val historyCache = HashMap<String, List<HistoryWeek>>()

    var offline = false
    val failNext = HashSet<String>()
    val calls = ArrayList<String>()
    /** When set, writes suspend until it completes (to observe optimistic states). */
    var gate: kotlinx.coroutines.CompletableDeferred<Unit>? = null
    /** When set, message page reads suspend until it completes (to observe cached-first rendering). */
    var readGate: kotlinx.coroutines.CompletableDeferred<Unit>? = null

    val onlineState = MutableStateFlow(true)
    private val eventFlows = HashMap<String, MutableSharedFlow<GroupEvent>>()

    fun eventsOf(groupId: String) = eventFlows.getOrPut(groupId) { MutableSharedFlow(extraBufferCapacity = 64, onBufferOverflow = BufferOverflow.DROP_OLDEST) }
    suspend fun emit(event: GroupEvent) = eventsOf(event.groupId).emit(event)

    private fun net(name: String) {
        if (offline) throw DataException(DataError.Network)
        if (failNext.remove(name)) throw DataException(DataError.Api(ApiError.Unknown, "test", 500, null))
    }

    private suspend fun write(name: String) {
        calls += name
        gate?.await()
        net(name)
    }

    override fun currentUserId(): String = me
    override val online: Flow<Boolean> get() = onlineState
    override fun events(groupId: String): Flow<GroupEvent> = eventsOf(groupId)

    override suspend fun group(groupId: String): Group? { net("group"); return groups[groupId] }
    override suspend fun myGroups(): List<Group> { net("myGroups"); return groups.values.toList() }
    override suspend fun members(groupId: String): List<Member> { net("members"); return members[groupId].orEmpty() }
    override suspend fun profiles(ids: Collection<String>): List<Profile> { net("profiles"); return ids.mapNotNull(profiles::get) }

    override fun observeMessages(groupId: String): Flow<DataState<List<Message>>> = cachedFlow(chatCache, groupId) { messages(groupId, null) }

    override suspend fun messages(groupId: String, before: Instant?): List<Message> {
        readGate?.await()
        net("messages")
        return messages.filter { it.groupId == groupId && (before == null || it.createdAt.isBefore(before)) }.sortedByDescending { it.createdAt }.take(PAGE)
    }

    override suspend fun message(messageId: String): Message? { net("message"); return messages.firstOrNull { it.id == messageId } }

    override suspend fun sendText(groupId: String, body: String, replyToPostId: String?, replyToMessageId: String?): Message {
        write("sendText:$body:${replyToPostId ?: ""}${replyToMessageId?.let { ":m=$it" } ?: ""}")
        val m = message("m-sent-${messages.size}", groupId, me, MessageKind.Text, body = body, replyToPostId = replyToPostId, at = clock()).copy(replyToMessageId = replyToMessageId)
        messages += m
        return m
    }

    override suspend fun replies(groupId: String, postId: String): List<Message> {
        net("replies")
        return messages.filter { it.groupId == groupId && it.replyToPostId == postId }.sortedBy { it.createdAt }
    }

    /** The waveform sent with each voice message. */
    val sentVoiceLevels = ArrayList<List<Int>?>()

    override suspend fun sendVoice(groupId: String, audio: File, durationMs: Int, levels: List<Int>?): Message {
        write("sendVoice:$durationMs")
        sentVoiceLevels += levels
        val m = message("m-voice-${messages.size}", groupId, me, MessageKind.Voice, voicePath = "u/$me/voice/v${messages.size}.m4a", voiceMs = durationMs, at = clock())
            .copy(voiceLevels = levels)
        messages += m
        return m
    }

    override suspend fun deleteMessage(messageId: String) {
        write("deleteMessage:$messageId")
        messages.removeAll { it.id == messageId }
        messageReactions.remove(messageId)
    }

    /** Like `edit_message`: your own text message gets the body and `edited_at`; `message_not_found` otherwise. */
    override suspend fun editMessage(messageId: String, body: String): Message {
        write("editMessage:$messageId:$body")
        val i = messages.indexOfFirst { it.id == messageId && it.authorId == me && it.kind == MessageKind.Text }
        if (i < 0) throw DataException(DataError.Api(ApiError.MessageNotFound, "message_not_found", 404, null))
        val edited = if (messages[i].body == body) messages[i] else messages[i].copy(body = body, editedAt = clock())
        messages[i] = edited
        return edited
    }

    override suspend fun publicConfig(): PublicAppConfig { net("publicConfig"); return config }

    override suspend fun messageReactions(messageIds: Collection<String>): Map<String, List<ReactionEntry>> {
        net("messageReactions")
        return messageIds.associateWith { messageReactions[it].orEmpty().toList() }
    }

    override suspend fun reactToMessage(messageId: String, emoji: String) {
        write("reactToMessage:$messageId:$emoji")
        messageReactions.getOrPut(messageId) { ArrayList() }.apply {
            removeAll { it.userId == me }
            add(ReactionEntry(me, emoji, clock()))
        }
    }

    override suspend fun unreactToMessage(messageId: String) {
        write("unreactToMessage:$messageId")
        messageReactions[messageId]?.removeAll { it.userId == me }
    }

    override suspend fun typing(groupId: String): List<ChatTyping> {
        net("typing")
        return typingRows.filter { it.groupId == groupId && it.until.isAfter(typingNow) }
    }

    override suspend fun setTyping(groupId: String, typing: Boolean) {
        typingCalls += typing
        net("setTyping")
    }

    override suspend fun feed(groupId: String, before: Instant?): List<Post> {
        net("feed")
        return posts.values.filter { it.groupId == groupId && (before == null || it.createdAt.isBefore(before)) }.sortedByDescending { it.createdAt }.take(FEED)
    }

    override suspend fun posts(ids: Collection<String>): List<Post> { net("posts"); return ids.mapNotNull(posts::get) }
    override suspend fun revealedWith(post: Post): List<String> {
        net("revealedWith")
        val at = post.revealedAt ?: return emptyList()
        return posts.values.filter { it.groupId == post.groupId && it.revealedAt == at }.sortedWith(compareBy({ it.createdAt }, { it.id })).map { it.id }
    }
    override suspend fun media(ids: Collection<String>): List<Media> { net("media"); return ids.mapNotNull(media::get) }

    override suspend fun deleteMedia(mediaId: String) {
        write("deleteMedia:$mediaId")
        posts.values.removeAll { it.mediaId == mediaId }
    }

    override suspend fun reactions(postIds: Collection<String>): Map<String, List<ReactionEntry>> {
        net("reactions")
        return postIds.associateWith { reactions[it].orEmpty().toList() }
    }

    override suspend fun react(postId: String, emoji: String) {
        write("react:$postId:$emoji")
        reactions.getOrPut(postId) { ArrayList() }.add(ReactionEntry(me, emoji))
    }

    override suspend fun unreact(postId: String, emoji: String) {
        write("unreact:$postId:$emoji")
        reactions[postId]?.removeAll { it.userId == me && it.emoji == emoji }
    }

    override suspend fun selfieReactions(postIds: Collection<String>): Map<String, List<SelfieReaction>> {
        net("selfies")
        return postIds.associateWith { selfies[it].orEmpty().toList() }
    }

    override suspend fun reactWithSelfie(postId: String, file: File): SelfieReaction {
        write("reactWithSelfie:$postId")
        val row = SelfieReaction(id = "s-$me-$postId-${tick}", postId = postId, userId = me, groupId = GROUP, imagePath = "u/$me/selfies/${file.nameWithoutExtension}.jpg", createdAt = clock())
        selfies.getOrPut(postId) { ArrayList() }.apply { removeAll { it.userId == me }; add(row) }
        return row
    }

    override suspend fun removeSelfieReaction(postId: String, userId: String?) {
        write("removeSelfie:$postId:${userId ?: ""}")
        selfies[postId]?.removeAll { it.userId == (userId ?: me) }
    }

    override suspend fun isTaggedByMe(postId: String): Boolean { net("tags"); return tagRows[postId].orEmpty().contains(me) }
    override suspend fun tags(postId: String): List<PostTag> {
        net("tags")
        return tagRows[postId].orEmpty().mapIndexed { i, u -> PostTag(postId, u, GROUP, BASE.plusSeconds(i.toLong())) }
    }
    override suspend fun tagSelf(postId: String) { write("tagSelf:$postId"); tagRows.getOrPut(postId) { ArrayList() }.let { if (me !in it) it += me } }
    override suspend fun untagSelf(postId: String) { write("untagSelf:$postId"); tagRows[postId]?.remove(me) }

    override fun observeWall(userId: String): Flow<DataState<List<WallItem>>> = cachedFlow(wallCache, userId) { wall(userId, null, PAGE) }
    override suspend fun wall(userId: String, before: Instant?, limit: Int): List<WallItem> {
        net("wall")
        return walls[userId].orEmpty().filter { before == null || it.createdAt.isBefore(before) }.sortedByDescending { it.createdAt }.take(limit)
    }

    override suspend fun collages(ids: Collection<String>): List<Collage> { net("collages"); return ids.mapNotNull(collages::get) }

    override fun observeHistory(groupId: String): Flow<DataState<List<HistoryWeek>>> = cachedFlow(historyCache, groupId) { historyWeeks(groupId, null, 8) }
    override suspend fun historyWeeks(groupId: String, beforeWeek: LocalDate?, limit: Int): List<HistoryWeek> {
        net("history")
        return weeks[groupId].orEmpty().filter { beforeWeek == null || it.weekStart.isBefore(beforeWeek) }.sortedByDescending { it.weekStart }.take(limit)
    }

    override suspend fun recaps(groupId: String): List<WeeklyRecap> { net("recaps"); return recaps.values.filter { it.groupId == groupId }.sortedByDescending { it.weekStart } }
    override suspend fun recap(recapId: String): WeeklyRecap? { net("recap"); return recaps[recapId] }
    override suspend fun updateRecap(recapId: String, items: List<String>, text: String): WeeklyRecap {
        write("updateRecap:${items.joinToString(",")}:$text")
        val r = recaps.getValue(recapId).copy(items = items, text = text.ifEmpty { null })
        recaps[recapId] = r
        return r
    }

    override suspend fun albums(groupId: String): List<Album> { net("albums"); return albums.values.filter { it.groupId == groupId }.sortedByDescending { it.createdAt } }
    override suspend fun albumItems(albumId: String): List<AlbumItem> { net("albumItems"); return albumItems[albumId].orEmpty() }
    override suspend fun saveAlbum(groupId: String, name: String, postIds: List<String>): Album {
        write("saveAlbum:$name:${postIds.joinToString(",")}")
        val a = Album("a-${albums.size + 1}", groupId, name, me, clock(), clock())
        albums[a.id] = a
        albumItems[a.id] = postIds.mapIndexed { i, p -> AlbumItem(a.id, p, i) }.toMutableList()
        return a
    }
    override suspend fun renameAlbum(albumId: String, name: String): Album {
        write("renameAlbum:$name")
        val a = albums.getValue(albumId).copy(name = name)
        albums[albumId] = a
        return a
    }
    override suspend fun deleteAlbum(albumId: String) { write("deleteAlbum:$albumId"); albums.remove(albumId) }

    override suspend fun signedUrls(paths: Collection<String>): Map<String, String> = paths.associateWith { "https://test.invalid/$it" }
    override suspend fun download(path: String): ByteArray { net("download"); return byteArrayOf(1, 2, 3) }

    override suspend fun <T> cacheGet(key: String, serializer: KSerializer<T>): T? = cache[key]?.let { Json.decodeFromString(serializer, it) }
    override suspend fun <T> cachePut(key: String, serializer: KSerializer<T>, value: T) { cache[key] = Json.encodeToString(serializer, value) }

    private fun <T> cachedFlow(store: HashMap<String, T>, key: String, fetch: suspend () -> T): Flow<DataState<T>> = flow {
        val cached = store[key]
        emit(DataState(cached, if (cached != null) DataState.Source.Cache else DataState.Source.None, null, refreshing = true, error = null))
        val fresh = try {
            fetch()
        } catch (e: DataException) {
            emit(DataState(cached, if (cached != null) DataState.Source.Cache else DataState.Source.None, null, refreshing = false, error = e.error))
            return@flow
        }
        store[key] = fresh
        emit(DataState(fresh, DataState.Source.Network, null, refreshing = false, error = null))
    }

    private var tick = 0L
    /** A clock moving forward one minute per write, after [BASE]. */
    fun clock(): Instant = BASE.plusSeconds(3600 + 60 * tick++)

    companion object {
        const val ME = "u-me"
        const val ANA = "u-ana"
        const val BEN = "u-ben"
        const val GROUP = "g-1"
        const val PAGE = 50
        const val FEED = 30
        val BASE: Instant = Instant.parse("2026-10-12T20:00:00Z")

        fun profile(id: String, name: String, avatar: String? = "avatars/$id/a.jpg") = Profile(id, name, avatar, BASE, BASE)

        fun message(
            id: String,
            groupId: String,
            author: String,
            kind: MessageKind,
            body: String? = null,
            postId: String? = null,
            voicePath: String? = null,
            voiceMs: Int? = null,
            replyToPostId: String? = null,
            at: Instant,
        ) = Message(id, groupId, author, kind, body, postId, voicePath, voiceMs, replyToPostId, null, at)

        fun media(id: String, owner: String, w: Int = 1080, h: Int = 1440) = Media(
            id, owner, MediaKind.Photo, "u/$owner/$id/original.jpg", null, null,
            "u/$owner/$id/r/display.jpg", "u/$owner/$id/r/thumb.jpg", null, null, null, w, h, null, null, null, BASE, BASE,
        )

        fun post(id: String, groupId: String, author: String, mediaId: String, at: Instant, caption: String? = null, voicePath: String? = null, voiceMs: Int? = null, replyTo: String? = null) =
            Post(id, mediaId, groupId, author, caption, voicePath, voiceMs, null, false, replyTo, at)
    }

    /** A group with three members (me, Ana, Ben) and Ana as its creator. */
    fun seedGroup(groupId: String = GROUP, name: String = "Sunday dinners") {
        groups[groupId] = Group(groupId, name, GroupKind.Friends, "u/$ANA/covers/c.jpg", "UTC", null, null, false, ANA, BASE, BASE)
        val people = listOf(profile(ME, "Sam Rivera"), profile(ANA, "Ana Lima"), profile(BEN, "Ben Okafor", avatar = null))
        people.forEach { profiles[it.id] = it }
        members[groupId] = people.mapIndexed { i, p ->
            Member(GroupMember(groupId, p.id, if (p.id == ANA) MemberRole.Admin else MemberRole.Member, false, BASE.plusSeconds(i.toLong())), p)
        }.toMutableList()
    }

    /** Adds a photo post (and its media) to the group. */
    fun addPhoto(id: String, author: String, at: Instant, groupId: String = GROUP, caption: String? = null, voicePath: String? = null, voiceMs: Int? = null, replyTo: String? = null): Post {
        val m = media("md-$id", author)
        media[m.id] = m
        val p = post(id, groupId, author, m.id, at, caption, voicePath, voiceMs, replyTo)
        posts[id] = p
        return p
    }

    /** Makes [postId]'s photo a dual capture (daily.dualimage): a front photo of its author over the back one. */
    fun makeDual(postId: String) {
        val m = media.getValue(posts.getValue(postId).mediaId)
        media[m.id] = m.copy(
            frontOriginalPath = "u/${m.ownerId}/${m.id}/front/original.jpg",
            frontDisplayPath = "u/${m.ownerId}/${m.id}/front/display.jpg",
            frontThumbPath = "u/${m.ownerId}/${m.id}/front/thumb.jpg",
            frontWidth = m.width,
            frontHeight = m.height,
        )
    }

    /** Makes [postId]'s media a video of [durationMs] (`layout.global.videoMarker`, viewer playback). */
    fun makeVideo(postId: String, durationMs: Int) {
        val m = media.getValue(posts.getValue(postId).mediaId)
        media[m.id] = m.copy(kind = MediaKind.Video, originalPath = "u/${m.ownerId}/${m.id}/r/video.mp4", durationMs = durationMs)
    }

    /** Makes [postId]'s media a Live Photo (a still with its motion movie). */
    fun makeLive(postId: String) {
        val m = media.getValue(posts.getValue(postId).mediaId)
        media[m.id] = m.copy(kind = MediaKind.LivePhoto, motionPath = "u/${m.ownerId}/${m.id}/motion.mov", durationMs = 2_800)
    }

    /** A thread with text, a reply to a photo, a photo with caption and reactions, and voice messages. */
    fun seedChat() {
        seedGroup()
        val t0 = BASE
        val photo = addPhoto("p-1", ANA, t0.plusSeconds(60), caption = "face masks night")
        reactions["p-1"] = mutableListOf(ReactionEntry(BEN, "😍"), ReactionEntry(ME, "🔥"), ReactionEntry(ANA, "😍"))
        messages += message("m-1", GROUP, ANA, MessageKind.Photo, postId = photo.id, at = t0.plusSeconds(60))
        messages += message("m-2", GROUP, BEN, MessageKind.Text, body = "strictly vibes only tonight", at = t0.plusSeconds(120))
        messages += message("m-3", GROUP, BEN, MessageKind.Text, body = "valid", at = t0.plusSeconds(130))
        messages += message("m-4", GROUP, ANA, MessageKind.Text, body = "obsessed", replyToPostId = "p-1", at = t0.plusSeconds(200))
        messages += message("m-5", GROUP, ME, MessageKind.Text, body = "no way", at = t0.plusSeconds(300))
        messages += message("m-6", GROUP, ME, MessageKind.Voice, voicePath = "u/$ME/voice/v1.m4a", voiceMs = 38_000, at = t0.plusSeconds(305))
        messages += message("m-7", GROUP, BEN, MessageKind.Voice, voicePath = "u/$BEN/voice/v2.m4a", voiceMs = 12_000, at = t0.plusSeconds(400))
        recaps["r-1"] = recap("r-1", LocalDate.parse("2026-10-05"), listOf("p-1"))
    }

    fun recap(id: String, weekStart: LocalDate, items: List<String>, status: RenderStatus = RenderStatus.Ready, text: String? = null) =
        WeeklyRecap(id, GROUP, weekStart, items, text, status, BASE, null, BASE, BASE)

    /** A week of seven photos (Mon 12 Oct 2026 …) with a ready recap of six of them. */
    fun seedWeek() {
        seedGroup()
        val monday = LocalDate.parse("2026-10-12")
        val ids = (1..7).map { i ->
            val author = listOf(ME, ANA, BEN)[i % 3]
            addPhoto("w-$i", author, monday.plusDays((i - 1).toLong()).atStartOfDay(java.time.ZoneOffset.UTC).toInstant().plusSeconds(43_200)).id
        }
        weeks[GROUP] = mutableListOf(HistoryWeek(monday, ids), HistoryWeek(monday.minusDays(7), listOf(addPhoto("w-0", ANA, monday.minusDays(5).atStartOfDay(java.time.ZoneOffset.UTC).toInstant()).id)))
        recaps["r-w"] = recap("r-w", monday, ids.take(6), text = "the best week")
    }

    /** Wall items for [userId]: photos from the group, newest first, plus one collage. */
    fun seedWall(userId: String, count: Int) {
        seedGroup()
        val items = (1..count).map { i ->
            val p = addPhoto("wall-$userId-$i", userId, BASE.minusSeconds(3600L * i))
            WallItem(WallItemKind.Post, p.id, p.mediaId, null, listOf(GROUP), p.createdAt)
        }.toMutableList()
        collages["c-1"] = Collage("c-1", GROUP, "inv-1", "A", items.take(3).mapNotNull { it.postId }, "g/$GROUP/collages/c-1/1/display-1.jpg", null, null, RenderStatus.Ready, BASE, BASE)
        items.add(1, WallItem(WallItemKind.Collage, null, null, "c-1", listOf(GROUP), BASE.minusSeconds(5400)))
        walls[userId] = items
    }

    /** Two albums of the group. */
    fun seedAlbums() {
        seedWeek()
        albums["a-1"] = Album("a-1", GROUP, "lake weekend", ANA, BASE.minusSeconds(100), BASE)
        albums["a-2"] = Album("a-2", GROUP, "birthday dinner", ME, BASE, BASE)
        albumItems["a-1"] = mutableListOf(AlbumItem("a-1", "w-2", 0), AlbumItem("a-1", "w-1", 1))
        albumItems["a-2"] = (1..7).map { AlbumItem("a-2", "w-$it", it - 1) }.toMutableList()
    }
}
