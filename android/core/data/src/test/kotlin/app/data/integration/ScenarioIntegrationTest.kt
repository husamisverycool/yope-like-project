package app.data.integration

import android.content.Context
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.work.WorkInfo
import app.data.DataGraph
import app.data.error.ApiError
import app.data.error.DataError
import app.data.media.upload.NewPost
import app.data.media.upload.UploadOutcome
import app.data.media.upload.UploadProgress
import app.data.media.upload.UploadWorker
import app.data.model.DevicePlatform
import app.data.model.Group
import app.data.model.GroupKind
import app.data.model.Media
import app.data.model.MediaKind
import app.data.model.MemberRole
import app.data.model.Message
import app.data.model.MessageKind
import app.data.model.Post
import app.data.model.ReportTargetKind
import app.data.model.WallItemKind
import app.data.repo.AuthState
import app.data.repo.ReactionEntry
import app.data.repo.PostOptions
import app.model.QuietHours
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.runBlocking
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.put
import kotlinx.serialization.json.putJsonObject
import org.junit.After
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import org.junit.runner.RunWith
import java.io.File
import java.time.DayOfWeek
import java.time.Instant
import java.time.LocalDate
import java.time.LocalTime
import java.time.ZoneId
import java.time.ZonedDateTime
import java.time.temporal.TemporalAdjusters
import kotlin.time.Duration.Companion.seconds

/**
 * The whole data layer against the real local stack, as two members (Ana, admin; Rui) and an
 * outsider (Olga): create group → invite → join → upload a JPEG (WorkManager) → create_post to 2
 * groups → list → react → reply → tag → wall → history weeks → on this day → album → recap →
 * collage → daily invitation → birthdays → year story → settings → delete media → verify gone
 * everywhere. Every user and group is unique to this run and deleted afterwards.
 */
@RunWith(AndroidJUnit4::class)
class ScenarioIntegrationTest {
    @get:Rule val tmp = TemporaryFolder()

    private val context: Context = ApplicationProvider.getApplicationContext()
    private lateinit var admin: Admin
    private lateinit var graphs: Graphs
    private val signedIn = mutableListOf<DataGraph>()

    @Before fun setUp() {
        LocalStack.assumeReachable()
        initTestWorkManager(context)
        admin = Admin()
        graphs = Graphs(context, tmp.newFolder("graphs"))
    }

    @After fun tearDown() = runBlocking {
        if (!::admin.isInitialized) return@runBlocking
        DataGraph.override(null)
        for (graph in signedIn) runCatching { if (graph.auth.currentUserId != null) graph.account.deleteAccount() }
        for (account in admin.created) runCatching { admin.deleteUser(account.id) }
        graphs.close()
        admin.close()
    }

    // Shared state of the phases below (one scenario, split so no method exceeds the JVM limit).
    private lateinit var tag: String
    private lateinit var files: File
    private val paris: ZoneId = ZoneId.of("Europe/Paris")
    private lateinit var today: LocalDate
    private lateinit var ana: TestAccount
    private lateinit var rui: TestAccount
    private lateinit var olga: TestAccount
    private lateinit var a: DataGraph
    private lateinit var b: DataGraph
    private lateinit var c: DataGraph
    private lateinit var signedOut: DataGraph
    private lateinit var g1: Group
    private lateinit var g2: Group
    private lateinit var p1: Post
    private lateinit var p1g2: Post
    private lateinit var p2: Post
    private lateinit var pVideo: Post
    private lateinit var pOld: String
    private lateinit var m1: Media
    private lateinit var photo: File
    private lateinit var voice: File
    private lateinit var reply: Message
    private lateinit var voiceMessage: Message
    private lateinit var photoReply: Post
    private lateinit var albumId: String
    private lateinit var recapId: String
    private lateinit var collageId: String
    private lateinit var requestId: String

    @Test fun membersShareGroupsPhotosChatAndMemoriesAndDeletionReachesEverything() = runBlocking {
        tag = uniqueTag()
        files = tmp.newFolder("files")
        today = LocalDate.now(paris)
        ana = admin.createUser("Ana Lima $tag")
        rui = admin.createUser("Rui Costa $tag")
        olga = admin.createUser("Olga Outsider $tag")
        a = graphs.signIn(ana).also(signedIn::add)
        b = graphs.signIn(rui).also(signedIn::add)
        c = graphs.signIn(olga).also(signedIn::add)
        signedOut = graphs.create("anon-$tag")
        assertEquals(AuthState.SignedIn(ana.id), a.auth.authState.value)

        profile()
        groupsAndInvites()
        uploadAndList()
        reactions()
        chat()
        tags()
        browse()
        albums()
        recap()
        invitationAndCollage()
        birthdays()
        yearStory()
        settings()
        safety()
        deleteMediaEverywhere()
        deletePostsMembersAndLeave()
        accountDeletion()
    }

    private suspend fun profile() {
        assertEquals("Ana Lima $tag", a.profiles.me().displayName)
        assertEquals("Ana Lima", a.profiles.updateProfile(displayName = "Ana Lima").displayName)
        val withAvatar = a.profiles.setAvatar(tinyJpegFile(files, "avatar.jpg"))
        assertTrue(withAvatar.avatarPath!!.startsWith("avatars/${ana.id}/"))
        assertTrue(a.profiles.setBirthday(LocalDate.of(1990, 5, 17), optIn = true).birthdayOptIn)
    }

    private suspend fun groupsAndInvites() {
        val cover = a.groups.uploadCover(tinyJpegFile(files, "cover.jpg"))
        g1 = a.groups.createGroup("it-$tag one", GroupKind.Family, "Europe/Paris", coverPath = cover)
        g2 = a.groups.createGroup("it-$tag two", GroupKind.Friends, "Europe/Paris")
        assertEquals(cover, g1.coverPath)
        assertEquals(listOf(g1.id, g2.id), a.groups.myGroups().map { it.id })
        assertEquals(setOf(g1.id, g2.id), a.groups.myGroupIds.value)
        assertEquals("it-$tag family", a.groups.updateGroup(g1.id, name = "it-$tag family").name)

        val invite = a.groups.createInvite(g1.id)
        val preview = signedOut.groups.invitePreview(invite.token)
        assertEquals("it-$tag family", preview.groupName)
        assertEquals(GroupKind.Family, preview.groupKind)
        assertEquals("Ana", preview.inviterFirstName)
        assertEquals(listOf("Ana"), preview.members.map { it.firstName })
        assertEquals(g1.id, b.groups.joinGroup(invite.token).id)
        assertEquals(g1.id, b.groups.joinGroup(invite.token).id) // idempotent
        b.groups.joinGroup(a.groups.createInvite(g2.id).token)
        val members = b.groups.members(g1.id)
        assertEquals(listOf(ana.id, rui.id), members.map { it.member.userId })
        assertEquals(listOf(MemberRole.Admin, MemberRole.Member), members.map { it.member.role })
        assertEquals("Ana Lima", members.first().profile?.displayName)
        assertTrue(b.groups.activeInvites(g1.id).any { it.token == invite.token })
        val spare = a.groups.createInvite(g1.id)
        a.groups.revokeInvite(spare.token)
        expectApi(ApiError.InviteRevoked) { c.groups.joinGroup(spare.token) }
        expectApi(ApiError.InviteNotFound) { c.groups.joinGroup("no-such-token-$tag-xxxxxxxx") }
        expectApi(ApiError.InviteRevoked) { signedOut.groups.invitePreview(spare.token) }
    }

    private suspend fun uploadAndList() {
        // The WorkManager path: enqueue, constraints met, the worker uploads and posts to two groups.
        DataGraph.override(a)
        photo = tinyJpegFile(files, "photo.jpg", padTo = 256 * 1024)
        voice = File(files, "note.m4a").apply { writeBytes(ByteArray(2048) { it.toByte() }) }
        val draftId = a.uploads.enqueue(
            NewPost(
                kind = MediaKind.Photo, original = photo, width = 1, height = 1,
                front = tinyJpegFile(files, "front.jpg"), frontWidth = 1, frontHeight = 1,
                voice = voice, voiceDurationMs = 1200,
                groupIds = listOf(g1.id, g2.id), caption = "first light $tag",
            ),
        )
        val work = runUploadWork(context, draftId)
        assertEquals(work.outputData.getString(UploadWorker.KEY_ERROR), WorkInfo.State.SUCCEEDED, work.state)
        val progress = a.uploads.progress(draftId).first()
        assertTrue("$progress", progress is UploadProgress.Done)
        val firstPostIds = (progress as UploadProgress.Done).postIds
        assertEquals(2, firstPostIds.size)
        p1 = b.posts.posts(firstPostIds).single { it.groupId == g1.id }
        p1g2 = b.posts.posts(firstPostIds).single { it.groupId == g2.id }
        assertEquals("first light $tag", p1.caption)
        assertEquals(1200, p1.voiceDurationMs)
        assertEquals(p1.mediaId, p1g2.mediaId)
        assertFalse(p1.inWindow)

        m1 = b.posts.mediaOf(p1)!!
        assertEquals(MediaKind.Photo, m1.kind)
        assertEquals("u/${ana.id}/${m1.id}/original.jpg", m1.originalPath)
        assertEquals("u/${ana.id}/${m1.id}/front.jpg", m1.frontOriginalPath)
        assertEquals(m1.originalPath, m1.imagePath(Media.Rendition.Display)) // no renditions yet

        // Signed URLs: members read, cached until expiry; outsiders get nothing.
        val url = b.signedUrls.url(m1.originalPath)!!
        assertArrayEquals(photo.readBytes(), download(url))
        assertEquals(url, b.signedUrls.url(m1.originalPath))
        assertNotNull(b.signedUrls.url(p1.voicePath!!))
        assertNull(c.signedUrls.url(m1.originalPath))

        // A second photo straight through the uploader, then a page of one and the next page.
        val draft2 = a.uploads.enqueue(NewPost(kind = MediaKind.Photo, original = tinyJpegFile(files, "p2.jpg"), groupIds = listOf(g1.id)))
        p2 = b.posts.post((a.uploader.run(draft2) as UploadOutcome.Done).postIds.single())!!
        val page = b.posts.feed(g1.id, limit = 1)
        assertEquals(listOf(p2.id), page.map { it.id })
        assertEquals(listOf(p1.id), b.posts.feed(g1.id, before = page.last().createdAt, limit = 1).map { it.id })

        // Video needs premium (typed), then works once the entitlement exists.
        val video = File(files, "clip.mp4").apply { writeBytes(ByteArray(4096) { 7 }) }
        val videoDraft = b.uploads.enqueue(NewPost(kind = MediaKind.Video, original = video, durationMs = 1500, groupIds = listOf(g1.id)))
        val refused = b.uploader.run(videoDraft) as UploadOutcome.Failed
        assertEquals(ApiError.PremiumRequired, (refused.error as DataError.Api).code)
        assertFalse(b.entitlements.isPremium())
        admin.upsert("entitlements", buildJsonObject { put("user_id", rui.id); put("entitlement", "premium"); put("source", "test") }, "user_id,entitlement")
        assertTrue(b.entitlements.isPremium())
        pVideo = b.posts.post((b.uploader.run(videoDraft) as UploadOutcome.Done).postIds.single())!!
        assertEquals(MediaKind.Video, b.posts.mediaOf(pVideo)!!.kind)
    }

    private suspend fun reactions() {
        b.reactions.react(p1.id, "🌅")
        b.reactions.react(p1.id, "🌅") // idempotent
        b.reactions.react(p1.id, "👍🏽")
        assertEquals(listOf(ReactionEntry(rui.id, "🌅"), ReactionEntry(rui.id, "👍🏽")), a.reactions.reactions(p1.id))
        b.reactions.unreact(p1.id, "👍🏽")
        assertEquals(mapOf(p1.id to listOf(ReactionEntry(rui.id, "🌅"))), a.reactions.reactionsFor(listOf(p1.id, p2.id)))
        expectApi(ApiError.InvalidEmoji) { b.reactions.react(p1.id, "abc") }
    }

    private suspend fun chat() {
        val thread = b.chat.messages(g1.id)
        assertTrue(thread.any { it.kind == MessageKind.Photo && it.postId == p1.id })
        reply = b.chat.replyToPhoto(g1.id, p1.id, "so good")
        assertEquals(p1.id, reply.replyToPostId)
        val answer = a.chat.sendText(g1.id, "thanks", replyToMessageId = reply.id)
        assertEquals(reply.id, answer.replyToMessageId)
        voiceMessage = b.chat.sendVoice(g1.id, voice, 900)
        assertEquals(MessageKind.Voice, voiceMessage.kind)
        assertTrue(voiceMessage.voicePath!!.startsWith("u/${rui.id}/voice/"))
        assertNotNull(a.signedUrls.url(voiceMessage.voicePath!!))
        expectApi(ApiError.MessageNotFound) { a.chat.deleteMessage(reply.id) }
        expectApi(ApiError.InvalidBody) { b.chat.sendText(g1.id, "   ") }
        val photoReplyDraft = b.uploads.enqueue(NewPost(kind = MediaKind.Photo, original = tinyJpegFile(files, "reply.jpg"), groupIds = listOf(g1.id), replyToPostId = p1.id))
        photoReply = b.posts.post((b.uploader.run(photoReplyDraft) as UploadOutcome.Done).postIds.single())!!
        assertEquals(p1.id, photoReply.replyToPostId)
        assertEquals(listOf(photoReply.id), a.posts.replies(p1.id).map { it.id })
        expectApi(ApiError.ReplyGroupMismatch) {
            b.posts.createPost(pVideo.mediaId, listOf(g2.id), PostOptions(replyToPostId = p1.id))
        }
    }

    private suspend fun tags() {
        b.tags.tagSelf(p1.id)
        assertEquals(listOf(rui.id), a.tags.tags(p1.id).map { it.userId })
        b.tags.untagSelf(p1.id)
        assertTrue(a.tags.tags(p1.id).isEmpty())
        b.tags.tagSelf(p1.id)
        assertEquals(listOf(p1.id), b.tags.myTags(g1.id).map { it.postId })
    }

    private suspend fun browse() {
        val wallEntry = b.browse.wall(ana.id).single { it.mediaId == m1.id }
        assertEquals(WallItemKind.Post, wallEntry.itemKind)
        assertEquals(setOf(g1.id, g2.id), wallEntry.groupIds.toSet())
        assertTrue(a.browse.wall(ana.id).any { it.mediaId == m1.id })
        val weeks = b.browse.historyWeeks(g1.id)
        assertTrue(weeks.first().postIds.containsAll(listOf(p1.id, p2.id)))

        val oldDraft = a.uploads.enqueue(NewPost(kind = MediaKind.Photo, original = tinyJpegFile(files, "old.jpg"), groupIds = listOf(g1.id)))
        pOld = (a.uploader.run(oldDraft) as UploadOutcome.Done).postIds.single()
        val lastYear = ZonedDateTime.now(paris).minusYears(1)
        admin.update("posts", "id=eq.$pOld", buildJsonObject { put("created_at", lastYear.toInstant().toString()) })
        val memories = b.browse.onThisDay(g1.id, today)
        assertEquals(1, memories.single { it.postId == pOld }.yearsAgo)
    }

    private suspend fun albums() {
        val album = b.albums.saveAlbum(g1.id, "Summer $tag", listOf(p2.id, p1.id))
        albumId = album.id
        assertEquals(listOf(p2.id, p1.id), a.albums.items(album.id).map { it.postId })
        assertEquals("Summer!", a.albums.renameAlbum(album.id, "Summer!").name)
        assertTrue(a.albums.albums(g1.id).any { it.id == album.id })
        expectApi(ApiError.AlbumNotFound) { c.albums.renameAlbum(album.id, "nope") }
    }

    private suspend fun recap() {
        // The row is written by the worker; here by the service role.
        val weekStart = today.with(TemporalAdjusters.previousOrSame(DayOfWeek.MONDAY))
        val recapRow = admin.insert("weekly_recaps", buildJsonObject {
            put("group_id", g1.id); put("week_start", weekStart.toString()); put("status", "ready"); put("text", "A week")
            put("items", JsonArray(listOf(JsonPrimitive(p1.id), JsonPrimitive(p2.id)))); put("generated_at", Instant.now().toString())
        })
        recapId = recapRow["id"]!!.jsonPrimitive.content
        assertTrue(b.recaps.recaps(g1.id).any { it.id == recapId })
        val edited = b.recaps.updateRecap(recapId, items = listOf(p2.id, p1.id), text = "Edited")
        assertEquals(listOf(p2.id, p1.id), edited.items)
        assertEquals(rui.id, edited.editedBy)
        assertNull(b.recaps.updateRecap(recapId, text = "").text)
        assertEquals(recapId, a.recaps.recapForWeek(g1.id, weekStart)?.id)
        val pendingRecap = admin.insert("weekly_recaps", buildJsonObject { put("group_id", g1.id); put("week_start", weekStart.minusWeeks(1).toString()) })
        expectApi(ApiError.RecapNotReady) { b.recaps.updateRecap(pendingRecap["id"]!!.jsonPrimitive.content, text = "x") }
    }

    private suspend fun invitationAndCollage() {
        val now = Instant.now()
        val invitationRow = admin.upsert("daily_invitations", buildJsonObject {
            put("group_id", g1.id); put("local_date", today.toString()); put("status", "fired")
            put("fires_at", now.minusSeconds(5).toString()); put("closes_at", now.plusSeconds(115).toString())
        }, "group_id,local_date")
        val invitationId = invitationRow["id"]!!.jsonPrimitive.content
        assertEquals(invitationId, b.invitations.currentInvitation(g1.id)?.id)
        val answerDraft = b.uploads.enqueue(NewPost(kind = MediaKind.Photo, original = tinyJpegFile(files, "now.jpg"), groupIds = listOf(g1.id), invitationId = invitationId))
        val answerPost = b.posts.post((b.uploader.run(answerDraft) as UploadOutcome.Done).postIds.single())!!
        assertTrue(answerPost.inWindow)
        assertEquals(listOf(answerPost.id), b.invitations.myAnswer(invitationId).map { it.id })
        assertTrue(a.invitations.myAnswer(invitationId).isEmpty())
        val collageRow = admin.insert("collages", buildJsonObject {
            put("group_id", g1.id); put("invitation_id", invitationId); put("option", "B"); put("status", "ready")
            put("post_ids", JsonArray(listOf(JsonPrimitive(answerPost.id), JsonPrimitive(p1.id)))); put("composed_at", now.toString())
        })
        collageId = collageRow["id"]!!.jsonPrimitive.content
        assertEquals(collageId, a.invitations.collageForInvitation(invitationId)?.id)
        assertTrue(a.invitations.collages(g1.id).any { it.id == collageId })
    }

    private suspend fun birthdays() {
        // Request (never shown to the honoree), contribution (own only), tribute for me.
        val now = Instant.now()
        val request = admin.insert("tribute_requests", buildJsonObject {
            put("group_id", g1.id); put("honoree_id", ana.id); put("birthday_date", today.plusDays(7).toString())
            put("due_at", now.plusSeconds(7 * 86_400L).toString())
        })
        requestId = request["id"]!!.jsonPrimitive.content
        assertTrue(b.birthdays.openRequests().any { it.id == requestId })
        assertFalse(a.birthdays.openRequests().any { it.id == requestId })
        expectApi(ApiError.PostNotEligible) { b.birthdays.contribute(requestId, pOld, "Happy birthday") }
        val contribution = b.birthdays.contribute(requestId, p1.id, "Happy birthday")
        assertEquals(contribution.id, b.birthdays.myContribution(requestId)?.id)
        assertNull(a.birthdays.myContribution(requestId))
        b.birthdays.withdraw(requestId)
        assertNull(b.birthdays.myContribution(requestId))
        b.birthdays.contribute(requestId, p1.id, "Happy birthday!")
        val tribute = admin.insert("tributes", buildJsonObject {
            put("request_id", requestId); put("group_id", g1.id); put("honoree_id", ana.id); put("status", "ready")
            put("rendered_at", now.toString()); put("delivered_at", now.minusSeconds(60).toString())
        })
        assertEquals(listOf(tribute["id"]!!.jsonPrimitive.content), a.birthdays.tributesForMe().map { it.id })
        assertTrue(b.birthdays.tributes(g1.id).isNotEmpty())
    }

    private suspend fun yearStory() {
        admin.insert("year_stories", buildJsonObject {
            put("group_id", g1.id); put("year", today.year); put("status", "ready"); putJsonObject("data") { put("pages", JsonArray(emptyList())) }
            put("post_ids", JsonArray(listOf(JsonPrimitive(p1.id)))); put("generated_at", Instant.now().toString())
        })
        val story = b.yearStories.yearStory(g1.id, today.year)!!
        assertEquals(listOf(p1.id), story.postIds)
        assertNotNull(story.data)
        assertTrue(b.yearStories.yearStories(g1.id).isNotEmpty())
    }

    private suspend fun settings() {
        // Mute, invitation hours / pause, quiet hours, devices, public config.
        b.groups.setMuted(g1.id, true)
        assertTrue(a.groups.members(g1.id).single { it.member.userId == rui.id }.member.muted)
        assertEquals(LocalTime.of(9, 0), a.groups.setInvitationHours(g1.id, LocalTime.of(9, 0), LocalTime.of(21, 0)).wakingStart)
        expectApi(ApiError.NotGroupAdmin) { b.groups.setInvitationHours(g1.id, LocalTime.of(8, 0), LocalTime.of(20, 0)) }
        assertNull(a.groups.setInvitationHours(g1.id, null, null).wakingStart)
        assertTrue(a.groups.setInvitationPaused(g1.id, true).invitationPaused)
        assertFalse(a.groups.setInvitationPaused(g1.id, false).invitationPaused)
        b.settings.setQuietHours(LocalTime.of(22, 0), LocalTime.of(7, 0), "Europe/Paris")
        assertEquals(QuietHours(LocalTime.of(22, 0), LocalTime.of(7, 0)) to paris, b.settings.quietHours.value)
        assertEquals(LocalTime.of(22, 0), b.settings.notificationSettings()?.quietStart)
        b.settings.clearQuietHours()
        assertNull(b.settings.quietHours.value)
        val token = "it-fcm-$tag-${uniqueTag()}"
        assertEquals(DevicePlatform.Android, b.devices.register(token).platform)
        assertTrue(b.devices.devices().any { it.pushToken == token })
        b.devices.unregister(token)
        assertFalse(b.devices.devices().any { it.pushToken == token })
        val config = signedOut.appConfig.publicConfig()
        assertEquals(120, config.invitationWindowSeconds)
        assertEquals(30, config.maxGroupMembers)
    }

    private suspend fun safety() {
        assertTrue(b.safety.report(ReportTargetKind.Post, p1.id, "test report $tag").isNotBlank())
        b.safety.block(ana.id)
        assertEquals(listOf(ana.id), b.safety.blocked().map { it.blockedId })
        assertTrue(b.posts.feed(g1.id).none { it.authorId == ana.id })
        assertTrue(a.posts.feed(g1.id).none { it.authorId == rui.id })
        b.safety.unblock(ana.id)
        assertTrue(b.posts.feed(g1.id).any { it.id == p1.id })
        expectApi(ApiError.CannotTargetSelf) { b.safety.block(rui.id) }
    }

    private suspend fun deleteMediaEverywhere() {
        expectApi(ApiError.MediaNotFound) { b.posts.deleteMedia(m1.id) }
        a.posts.deleteMedia(m1.id)
        assertNull(b.posts.post(p1.id))
        assertNull(b.posts.post(p1g2.id))
        assertTrue(b.posts.feed(g1.id).none { it.mediaId == m1.id })
        assertTrue(b.posts.feed(g2.id).none { it.mediaId == m1.id })
        assertTrue(b.posts.media(listOf(m1.id)).isEmpty())
        assertTrue(a.posts.media(listOf(m1.id)).isEmpty())
        val chatAfter = b.chat.messages(g1.id)
        assertTrue(chatAfter.none { it.postId == p1.id })
        assertNull(chatAfter.single { it.id == reply.id }.replyToPostId) // the reply stays, detached
        assertNull(b.posts.post(photoReply.id)!!.replyToPostId)
        assertTrue(a.reactions.reactions(p1.id).isEmpty())
        assertTrue(a.tags.tags(p1.id).isEmpty())
        assertTrue(b.browse.wall(ana.id).none { it.mediaId == m1.id })
        assertTrue(b.browse.historyWeeks(g1.id).none { p1.id in it.postIds })
        assertEquals(listOf(p2.id), a.albums.items(albumId).map { it.postId })
        assertFalse(p1.id in b.recaps.recap(recapId)!!.items)
        assertNull(b.birthdays.myContribution(requestId))
        assertFalse(p1.id in a.invitations.collage(collageId)!!.postIds)
        assertFalse(p1.id in b.yearStories.yearStory(g1.id, today.year)!!.postIds)
        assertTrue(b.storage.sign(listOf(m1.originalPath, p1.voicePath!!), 60.seconds).isEmpty())
        assertTrue(c.storage.sign(listOf(m1.originalPath), 60.seconds).isEmpty())
    }

    private suspend fun deletePostsMembersAndLeave() {
        expectApi(ApiError.PostNotFound) { a.posts.deletePost(photoReply.id) }
        b.posts.deletePost(photoReply.id)
        assertNull(a.posts.post(photoReply.id))
        b.chat.deleteMessage(voiceMessage.id)
        assertTrue(a.chat.messages(g1.id).none { it.id == voiceMessage.id })
        expectApi(ApiError.CannotTargetSelf) { a.groups.removeMember(g2.id, ana.id) }
        expectApi(ApiError.NotGroupAdmin) { b.groups.removeMember(g1.id, ana.id) }
        expectApi(ApiError.MemberNotFound) { a.groups.removeMember(g1.id, olga.id) }
        a.groups.removeMember(g2.id, rui.id)
        assertEquals(listOf(g1.id), b.groups.myGroups().map { it.id })
        b.groups.leaveGroup(g1.id)
        assertTrue(b.groups.myGroups().isEmpty())
        assertEquals(emptySet<String>(), b.groups.myGroupIds.value)
        assertTrue(b.posts.feed(g1.id).isEmpty())
        expectApi(ApiError.NotGroupMember) { b.browse.historyWeeks(g1.id) }
    }

    private suspend fun accountDeletion() {
        c.account.deleteAccount()
        eventually { c.auth.authState.value == AuthState.SignedOut }
        assertEquals(DataError.NotSignedIn, expectDataError { c.profiles.me() })
    }
}
