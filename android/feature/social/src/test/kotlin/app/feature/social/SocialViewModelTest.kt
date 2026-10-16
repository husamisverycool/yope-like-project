package app.feature.social

import app.data.model.MessageKind
import app.data.model.Reaction
import app.data.model.RenderStatus
import app.data.realtime.GroupEvent
import app.data.repo.ReactionEntry
import app.feature.social.FakeSocialData.Companion.ANA
import app.feature.social.FakeSocialData.Companion.BASE
import app.feature.social.FakeSocialData.Companion.BEN
import app.feature.social.FakeSocialData.Companion.GROUP
import app.feature.social.FakeSocialData.Companion.ME
import app.feature.social.albums.AlbumEffect
import app.feature.social.albums.AlbumViewModel
import app.feature.social.albums.AlbumsState
import app.feature.social.albums.AlbumsViewModel
import app.feature.social.chat.ChatEffect
import app.feature.social.chat.ChatState
import app.feature.social.chat.ChatViewModel
import app.feature.social.viewer.PhotoViewerViewModel
import app.feature.social.viewer.ViewerEffect
import app.feature.social.walls.BrowseViewModel
import app.feature.social.walls.WallState
import app.feature.social.walls.WallTile
import app.feature.social.walls.WallViewModel
import app.feature.social.week.EditError
import app.feature.social.week.EditState
import app.feature.social.week.HistoryViewModel
import app.feature.social.week.RecapEdits
import app.feature.social.week.RecapState
import app.feature.social.week.RecapViewModel
import app.feature.social.week.WeekEditViewModel
import app.model.PhotoContext
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.setMain
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import java.time.LocalDate
import java.time.ZoneOffset

/** View models over [FakeSocialData]: cache-then-network, realtime, pagination, optimistic writes, no counts. */
@OptIn(ExperimentalCoroutinesApi::class)
class SocialViewModelTest {
    private val effects = CoroutineScope(SupervisorJob() + UnconfinedTestDispatcher())

    @Before fun setUp() {
        Dispatchers.setMain(UnconfinedTestDispatcher())
        RecapEdits.pending.value = emptyMap()
    }

    @After fun tearDown() {
        effects.cancel()
        Dispatchers.resetMain()
    }

    private fun <T> collect(flow: kotlinx.coroutines.flow.Flow<T>): MutableList<T> {
        val out = ArrayList<T>()
        effects.launch { flow.collect { out += it } }
        return out
    }

    // ---- chat.thread ----

    @Test fun chatRendersTheCachedPageOfflineThenRefreshesOnReconnect() {
        val data = FakeSocialData().apply { seedChat() }
        data.chatCache[GROUP] = data.messages.filter { it.id in setOf("m-2", "m-3") }.sortedByDescending { it.createdAt }
        data.offline = true
        val vm = ChatViewModel(data, GROUP)
        val s = vm.state.value
        assertEquals(ChatState.Phase.Ready, s.phase)
        assertTrue(s.offline)
        assertEquals(listOf("m-2", "m-3"), s.rows.map { it.id })

        data.offline = false
        data.onlineState.value = false
        data.onlineState.value = true
        val fresh = vm.state.value
        assertFalse(fresh.offline)
        assertEquals(listOf("m-1", "m-2", "m-3", "m-4", "m-5", "m-6", "m-7"), fresh.rows.map { it.id })
    }

    @Test fun chatNeverFlashesLoadingOverCachedContent() {
        val data = FakeSocialData().apply { seedChat() }
        data.chatCache[GROUP] = data.messages.sortedByDescending { it.createdAt }.take(3)
        data.readGate = CompletableDeferred()
        val vm = ChatViewModel(data, GROUP)
        val states = collect(vm.state)
        data.readGate!!.complete(Unit)
        assertTrue(states.isNotEmpty())
        assertTrue("never the loading HUD", states.all { it.phase == ChatState.Phase.Ready })
        assertTrue("never an empty list", states.all { it.rows.isNotEmpty() })
        assertEquals(7, vm.state.value.rows.size)
    }

    @Test fun viewerShowsTheOpenedPhotoBeforeItsContext() {
        val data = FakeSocialData().apply { seedAlbums() }
        val vm = PhotoViewerViewModel(data, GROUP, "w-3", PhotoContext.Album, "a-2", null)
        assertEquals(app.feature.social.viewer.ViewerState.Phase.Ready, vm.state.value.phase)
    }

    @Test fun chatOfflineWithNothingCachedShowsTheOfflineState() {
        val data = FakeSocialData().apply { seedChat(); offline = true }
        assertEquals(ChatState.Phase.OfflineEmpty, ChatViewModel(data, GROUP).state.value.phase)
        data.offline = false
        data.failNext += "messages"
        assertEquals(ChatState.Phase.Error, ChatViewModel(data, GROUP).state.value.phase)
    }

    @Test fun chatHydratesPhotosRepliesAndReactionRows() {
        val data = FakeSocialData().apply { seedChat() }
        val s = ChatViewModel(data, GROUP).state.value
        val photo = s.rows.first { it.id == "m-1" }
        assertEquals("face masks night", photo.post?.caption)
        assertEquals("u/$ANA/md-p-1/r/thumb.jpg", photo.media?.thumbPath)
        // Rows (who, what), never a number.
        assertEquals(listOf(ReactionEntry(BEN, "😍"), ReactionEntry(ME, "🔥"), ReactionEntry(ANA, "😍")), photo.reactions)
        val reply = s.rows.first { it.id == "m-4" }.quote as app.feature.social.chat.Quote.Photo
        assertEquals("p-1", reply.postId)
        assertEquals("Ana", reply.posterName)
        // ISO week of the quoted post in the group's zone ("Week 42").
        assertEquals(42, reply.weekNumber)
    }

    @Test fun chatAppliesRealtimeInsertsUpdatesAndDeletions() = runBlocking {
        val data = FakeSocialData().apply { seedChat() }
        val vm = ChatViewModel(data, GROUP)
        val seen = collect(vm.effects)
        val incoming = FakeSocialData.message("m-8", GROUP, ANA, MessageKind.Text, body = "hi", at = BASE.plusSeconds(500))
        data.emit(GroupEvent.MessageInserted(GROUP, incoming))
        assertEquals("m-8", vm.state.value.rows.last().id)
        assertTrue(seen.any { it is ChatEffect.Incoming && it.row.id == "m-8" })

        data.emit(GroupEvent.MessageDeleted(GROUP, "m-8"))
        assertTrue(vm.state.value.rows.none { it.id == "m-8" })

        data.emit(GroupEvent.PostDeleted(GROUP, "p-1", "md-p-1"))
        val rows = vm.state.value.rows
        assertTrue("photo message removed", rows.none { it.id == "m-1" })
        assertNull("reply keeps its text, loses its quote", rows.first { it.id == "m-4" }.quote)

        data.emit(GroupEvent.Subscribed(GROUP, GroupEvent.Stream.Changes, resumed = true))
        assertTrue(vm.state.value.rows.isNotEmpty())
    }

    @Test fun chatReactionRealtimeKeepsRows() = runBlocking {
        val data = FakeSocialData().apply { seedChat() }
        val vm = ChatViewModel(data, GROUP)
        data.emit(GroupEvent.ReactionAdded(GROUP, Reaction("p-1", ANA, "🫶", GROUP, BASE)))
        assertEquals(ReactionEntry(ANA, "🫶"), vm.state.value.rows.first { it.id == "m-1" }.reactions.last())
        data.reactions["p-1"] = mutableListOf(ReactionEntry(BEN, "😂"))
        data.emit(GroupEvent.ReactionsChanged(GROUP, "p-1"))
        assertEquals(listOf(ReactionEntry(BEN, "😂")), vm.state.value.rows.first { it.id == "m-1" }.reactions)
    }

    @Test fun chatPaginatesOlderMessages() {
        val data = FakeSocialData().apply { seedGroup() }
        repeat(60) { i -> data.messages += FakeSocialData.message("x-$i", GROUP, BEN, MessageKind.Text, body = "m$i", at = BASE.plusSeconds(i.toLong())) }
        val vm = ChatViewModel(data, GROUP)
        assertEquals(50, vm.state.value.rows.size)
        assertFalse(vm.state.value.endReached)
        vm.loadOlder()
        assertEquals(60, vm.state.value.rows.size)
        assertEquals("x-0", vm.state.value.rows.first().id)
        assertTrue(vm.state.value.endReached)
    }

    @Test fun chatSendIsOptimisticKeepsItsKeyAndRollsBack() {
        val data = FakeSocialData().apply { seedChat() }
        val vm = ChatViewModel(data, GROUP)
        val seen = collect(vm.effects)
        data.gate = CompletableDeferred()
        vm.setDraft("on my way")
        vm.send()
        val pending = vm.state.value.rows.last()
        assertTrue(pending.pending)
        assertEquals("on my way", pending.message.body)
        assertEquals("", vm.state.value.draft)
        data.gate!!.complete(Unit)
        val confirmed = vm.state.value.rows.last()
        assertFalse(confirmed.pending)
        assertEquals("same list key: no scroll jump", pending.key, confirmed.key)
        assertTrue(seen.contains(ChatEffect.Sent))

        data.gate = null
        data.failNext += "sendText:nope:"
        vm.setDraft("nope")
        vm.send()
        val failed = vm.state.value.rows.single { it.message.body == "nope" }
        assertTrue("stays in the thread as failed (chat.thread.layout.failedMessage)", failed.failed)
        assertFalse(failed.pending)
        assertEquals("", vm.state.value.draft)
        assertTrue(seen.contains(ChatEffect.SendFailed))

        // A tap on the failed message sends it again; it keeps its list key.
        vm.retrySend(failed.id)
        val retried = vm.state.value.rows.single { it.message.body == "nope" }
        assertFalse(retried.failed)
        assertEquals(failed.key, retried.key)
        assertEquals(2, data.calls.count { it == "sendText:nope:" })
    }

    @Test fun chatFailedVoiceKeepsItsRecordingForRetryAndCanBeDeleted() {
        val data = FakeSocialData().apply { seedChat() }
        val vm = ChatViewModel(data, GROUP)
        val file = java.io.File.createTempFile("voice", ".m4a")
        data.failNext += "sendVoice:4000"
        vm.sendVoice(file, 4_000)
        val failed = vm.state.value.rows.last()
        assertTrue(failed.failed)
        assertTrue("the recording is kept for the retry", file.exists())
        vm.deleteMessage(failed.id)
        assertTrue("a never-sent message just goes", vm.state.value.rows.none { it.id == failed.id })
        assertFalse(data.calls.any { it.startsWith("deleteMessage:local-") })
        assertFalse(file.exists())
    }

    @Test fun chatUnreactIsOptimisticAndRollsBack() {
        val data = FakeSocialData().apply { seedChat() }
        val vm = ChatViewModel(data, GROUP)
        val seen = collect(vm.effects)
        vm.unreact("p-1", "🔥")
        assertFalse(vm.state.value.rows.first { it.id == "m-1" }.reactions.any { it.userId == ME && it.emoji == "🔥" })
        assertTrue(data.calls.contains("unreact:p-1:🔥"))
        vm.react("p-1", "🔥")
        data.failNext += "unreact:p-1:🔥"
        vm.unreact("p-1", "🔥")
        assertTrue("restored when unreact fails", vm.state.value.rows.first { it.id == "m-1" }.reactions.contains(ReactionEntry(ME, "🔥")))
        assertTrue(seen.contains(ChatEffect.ReactionFailed))
    }

    /** `chat.reactions.layout.clusterOrder`: newest distinct emoji first; a repeat keeps its place. */
    @Test fun clusterOrderIsNewestDistinctFirst() {
        val entries = listOf(ReactionEntry(BEN, "😍"), ReactionEntry(ME, "🔥"), ReactionEntry(ANA, "😍"), ReactionEntry(ANA, "😂"))
        assertEquals(listOf("😂", "🔥", "😍"), app.feature.social.reactions.clusterEmoji(entries))
    }

    @Test fun chatReactIsOptimisticAndRollsBack() {
        val data = FakeSocialData().apply { seedChat() }
        val vm = ChatViewModel(data, GROUP)
        val seen = collect(vm.effects)
        vm.react("p-1", "💖")
        assertTrue(vm.state.value.rows.first { it.id == "m-1" }.reactions.contains(ReactionEntry(ME, "💖")))
        data.failNext += "react:p-1:🤣"
        vm.react("p-1", "🤣")
        assertFalse(vm.state.value.rows.first { it.id == "m-1" }.reactions.contains(ReactionEntry(ME, "🤣")))
        assertTrue(seen.contains(ChatEffect.ReactionFailed))
    }

    @Test fun chatDeleteIsOptimisticAndRestoredOnFailure() {
        val data = FakeSocialData().apply { seedChat() }
        val vm = ChatViewModel(data, GROUP)
        vm.deleteMessage("m-5")
        assertTrue(vm.state.value.rows.none { it.id == "m-5" })
        data.failNext += "deleteMessage:m-6"
        vm.deleteMessage("m-6")
        assertTrue(vm.state.value.rows.any { it.id == "m-6" })
    }

    @Test fun chatVoiceIsSentOptimistically() {
        val data = FakeSocialData().apply { seedChat() }
        val vm = ChatViewModel(data, GROUP)
        val file = java.io.File.createTempFile("voice", ".m4a")
        vm.sendVoice(file, 4_000)
        assertTrue(data.calls.contains("sendVoice:4000"))
        assertEquals(MessageKind.Voice, vm.state.value.rows.last().kind)
        assertFalse(file.exists())
    }

    // ---- photo.viewer ----

    @Test fun viewerOpensOnThePhotoThenSplicesTheAlbumOrder() {
        val data = FakeSocialData().apply { seedAlbums() }
        val vm = PhotoViewerViewModel(data, GROUP, "w-3", PhotoContext.Album, "a-2", null)
        val s = vm.state.value
        assertEquals((1..7).map { "w-$it" }, s.photos.map { it.postId })
        assertEquals(2, s.index)
        assertTrue(s.current!!.loaded)
        assertEquals("Sunday dinners", s.current!!.groupName)
        vm.select(3)
        assertTrue(vm.state.value.photos[4].loaded)
    }

    @Test fun viewerChatContextIsChronological() {
        val data = FakeSocialData().apply { seedWeek() }
        val vm = PhotoViewerViewModel(data, GROUP, "w-5", PhotoContext.Chat, GROUP, null)
        val ids = vm.state.value.photos.map { it.postId }
        assertEquals(listOf("w-0") + (1..7).map { "w-$it" }, ids)
        assertEquals("w-5", vm.state.value.current?.postId)
    }

    @Test fun viewerDeletionWhileOpenShowsGoneAndDropsOthers() = runBlocking {
        val data = FakeSocialData().apply { seedAlbums() }
        val vm = PhotoViewerViewModel(data, GROUP, "w-3", PhotoContext.Album, "a-2", null)
        data.emit(GroupEvent.PostDeleted(GROUP, "w-3", null))
        assertTrue(vm.state.value.current!!.gone)
        data.emit(GroupEvent.PostDeleted(GROUP, "w-1", null))
        assertEquals(6, vm.state.value.photos.size)
        assertEquals("w-3", vm.state.value.current?.postId)
    }

    /** The memory group's tag control reports a deleted photo (`post_not_found`): the viewer shows it as gone. */
    @Test fun viewerLoadsYourTagAndMarksAPhotoGone() {
        val data = FakeSocialData().apply { seedAlbums() }
        val vm = PhotoViewerViewModel(data, GROUP, "w-2", PhotoContext.Single, "w-2", null)
        assertEquals("loaded with the photo: nobody tagged", emptyList<String>(), vm.state.value.current!!.tagged)
        vm.markGone("w-2")
        assertTrue(vm.state.value.current!!.gone)
    }

    @Test fun viewerDeleteEverywhereMovesOnThenCloses() {
        val data = FakeSocialData().apply { seedAlbums() }
        val vm = PhotoViewerViewModel(data, GROUP, "w-1", PhotoContext.Album, "a-1", null)
        assertEquals(listOf("w-2", "w-1"), vm.state.value.photos.map { it.postId })
        vm.deleteEverywhere()
        assertTrue(data.calls.contains("deleteMedia:md-w-1"))
        assertEquals(listOf("w-2"), vm.state.value.photos.map { it.postId })
        assertFalse(vm.state.value.closed)
        vm.deleteEverywhere()
        assertTrue(vm.state.value.closed)
    }

    @Test fun viewerReplySendsWithTheReplyTarget() {
        val data = FakeSocialData().apply { seedAlbums() }
        val vm = PhotoViewerViewModel(data, GROUP, "w-2", PhotoContext.Single, "w-2", null)
        vm.setDraft("love this")
        vm.sendReply()
        assertTrue(data.calls.contains("sendText:love this:w-2"))
        assertEquals("", vm.state.value.draft)

        // Optimistic: the field clears at once; a failure gives the text back.
        data.failNext += "sendText:again:w-2"
        vm.setDraft("again")
        vm.sendReply()
        assertEquals("again", vm.state.value.draft)
    }

    @Test fun viewerUnreactIsOptimisticAndRollsBack() {
        val data = FakeSocialData().apply { seedAlbums() }
        val vm = PhotoViewerViewModel(data, GROUP, "w-2", PhotoContext.Single, "w-2", null)
        vm.react("💖")
        assertTrue(vm.state.value.current!!.reactions.contains(ReactionEntry(ME, "💖")))
        vm.unreact("💖")
        assertFalse(vm.state.value.current!!.reactions.contains(ReactionEntry(ME, "💖")))
        vm.react("💖")
        data.failNext += "unreact:w-2:💖"
        vm.unreact("💖")
        assertTrue(vm.state.value.current!!.reactions.contains(ReactionEntry(ME, "💖")))
    }

    @Test fun viewerReactionRealtimeAndRollback() = runBlocking {
        val data = FakeSocialData().apply { seedAlbums() }
        val vm = PhotoViewerViewModel(data, GROUP, "w-2", PhotoContext.Single, "w-2", null)
        data.emit(GroupEvent.ReactionAdded(GROUP, Reaction("w-2", BEN, "🔥", GROUP, BASE)))
        assertEquals(listOf(ReactionEntry(BEN, "🔥")), vm.state.value.current!!.reactions)
        data.failNext += "react:w-2:💖"
        vm.react("💖")
        assertEquals(listOf(ReactionEntry(BEN, "🔥")), vm.state.value.current!!.reactions)
    }

    // ---- walls ----

    @Test fun wallPaginatesAndShowsReadyCollages() {
        val data = FakeSocialData().apply { seedWall(ME, 60) }
        val vm = WallViewModel(data, ME)
        val s = vm.state.value
        assertEquals(WallState.Phase.Ready, s.phase)
        assertEquals(50, s.tiles.size)
        assertTrue(s.tiles[1] is WallTile.CollageTile)
        vm.loader.loadMore()
        assertEquals(61, vm.state.value.tiles.size)
        assertTrue(vm.state.value.endReached)
    }

    @Test fun wallDropsDeletedPhotosAndShowsCachedOffline() = runBlocking {
        val data = FakeSocialData().apply { seedWall(ANA, 3) }
        val vm = WallViewModel(data, ANA)
        data.emit(GroupEvent.PostDeleted(GROUP, "wall-$ANA-1", null))
        assertTrue(vm.state.value.tiles.none { it.key == "p:wall-$ANA-1" })

        data.offline = true
        val cachedWall = WallViewModel(data, ANA).state.value
        assertEquals(WallState.Phase.Ready, cachedWall.phase)
        assertTrue(cachedWall.offline)
        val empty = WallViewModel(FakeSocialData().apply { offline = true }, BEN).state.value
        assertEquals(WallState.Phase.OfflineEmpty, empty.phase)
    }

    /** walls.browse: everyone sharing a group, never me; development order newest wall item first; search by name. */
    @Test fun browseListsOthersNewestWallFirstAndFilters() {
        val data = FakeSocialData().apply { seedWall(BEN, 2) }
        data.walls[ANA] = mutableListOf(app.data.model.WallItem(app.data.model.WallItemKind.Post, "x", "y", null, listOf(GROUP), BASE.plusSeconds(10_000)))
        val vm = BrowseViewModel(data, approximations = true)
        assertEquals(listOf(ANA, BEN), vm.state.value.people.map { it.id })
        vm.setQuery("ben")
        assertEquals(listOf(BEN), vm.state.value.shown.map { it.id })
        // Release: `walls.browse.layout.rowOrder` BLOCKED — the membership order.
        assertEquals(listOf(ANA, BEN), BrowseViewModel(data, approximations = false).state.value.people.map { it.id })
    }

    /** The thread's reply bar: replying to a message sends `p_reply_to_message_id`; to a photo, `p_reply_to_post_id`. */
    @Test fun chatRepliesToAMessageAndToAPhoto() {
        val data = FakeSocialData().apply { seedChat() }
        val vm = ChatViewModel(data, GROUP)
        vm.startReply(vm.state.value.rows.first { it.id == "m-2" })
        assertEquals("Ben", vm.state.value.replyTo?.name)
        vm.setDraft("same")
        vm.send()
        assertTrue(data.calls.contains("sendText:same::m=m-2"))
        assertEquals(null, vm.state.value.replyTo)
        val quote = vm.state.value.rows.last().quote as app.feature.social.chat.Quote.Text
        assertEquals("strictly vibes only tonight", quote.text)
        vm.startReply(vm.state.value.rows.first { it.id == "m-1" })
        vm.setDraft("love")
        vm.send()
        assertTrue(data.calls.contains("sendText:love:p-1"))
    }

    /** photo.viewer: comments are the photo's replies (oldest first); tags load with the photo; "I'm in this" is optimistic. */
    @Test fun viewerLoadsCommentsAndTagsAndTagsYouOptimistically() {
        val data = viewerData()
        val vm = PhotoViewerViewModel(data, GROUP, "v-1", PhotoContext.Album, "a-v", null)
        val photo = vm.state.value.current!!
        assertEquals(listOf("c-1", "c-2"), photo.comments.map { it.id })
        assertEquals(listOf(ANA, ME), photo.tagged)
        assertTrue(vm.state.value.taggedByMe)
        vm.setTagged(false)
        assertFalse(vm.state.value.taggedByMe)
        assertTrue(data.calls.contains("untagSelf:v-1"))
        data.failNext += "tagSelf:v-1"
        vm.setTagged(true)
        assertFalse("reverted after the failure", vm.state.value.taggedByMe)
    }

    /** Tap to advance: past the last photo the viewer closes; tap back stops at the first. */
    @Test fun viewerAdvancesAndClosesAfterTheLast() {
        val data = viewerData()
        val vm = PhotoViewerViewModel(data, GROUP, "v-2", PhotoContext.Album, "a-v", null)
        assertEquals(1, vm.state.value.index)
        vm.previous()
        vm.previous()
        assertEquals(0, vm.state.value.index)
        vm.next(); vm.next()
        assertEquals(2, vm.state.value.index)
        vm.next()
        assertTrue(vm.state.value.closed)
    }

    /** The recap list: ready and pending recaps newest first, each with its cover. */
    @Test fun recapListShowsReadyAndPendingNewestFirst() {
        val data = FakeSocialData().apply { seedRecaps() }
        val s = app.feature.social.week.RecapListViewModel(data, GROUP).state.value
        assertEquals(listOf("r-w", "r-prev", "r-old"), s.cards.map { it.recap.id })
        assertTrue(s.cards.first().coverPath!!.endsWith("thumb.jpg"))
    }

    /** `week.recap.layout.gridFill` BLOCKED: release draws only full rows of four; development fills row by row up to 24. */
    @Test fun recapCardCellsFollowTheFillRule() {
        assertEquals(4, app.feature.social.week.recapCardCells(6, approximation = false))
        assertEquals(6, app.feature.social.week.recapCardCells(6, approximation = true))
        assertEquals(24, app.feature.social.week.recapCardCells(30, approximation = true))
        assertEquals(0, app.feature.social.week.recapCardCells(3, approximation = false))
    }

    // ---- week.recap / week.edit / week.history ----

    @Test fun recapShowsCardAndPicsAndItsStates() {
        val data = FakeSocialData().apply { seedWeek() }
        val ready = RecapViewModel(data, GROUP, "r-w").state.value
        assertEquals(RecapState.Phase.Ready, ready.phase)
        assertEquals((1..6).map { "w-$it" }, ready.card.map { it.post.id })
        assertEquals((1..7).map { "w-$it" }, ready.pics.map { it.post.id })
        assertEquals("r-w", RecapViewModel(data, GROUP, null).state.value.recap?.id)

        data.recaps["r-p"] = data.recap("r-p", LocalDate.parse("2026-10-19"), emptyList(), RenderStatus.Pending)
        assertEquals(RecapState.Phase.Pending, RecapViewModel(data, GROUP, "r-p").state.value.phase)
        assertEquals(RecapState.Phase.Empty, RecapViewModel(FakeSocialData().apply { seedGroup() }, GROUP, null).state.value.phase)
    }

    @Test fun recapEditIsOptimisticOnTheRecapScreenAndRollsBack() {
        val data = FakeSocialData().apply { seedWeek() }
        val recap = RecapViewModel(data, GROUP, "r-w")
        val edit = WeekEditViewModel(data, GROUP, "r-w", null, albumOnly = false)
        val seen = collect(edit.effects)
        assertEquals(EditState.Phase.Ready, edit.state.value.phase)
        assertEquals((1..7).map { "w-$it" }, edit.state.value.photos.map { it.post.id })
        edit.toggle("w-1")
        edit.toggle("w-7")
        edit.move("w-7", 0)
        assertEquals(listOf("w-7", "w-2", "w-3", "w-4", "w-5", "w-6"), edit.state.value.checked)
        edit.setText("new text")

        data.gate = CompletableDeferred()
        edit.save()
        assertEquals("shown before the call returns", listOf("w-7", "w-2", "w-3", "w-4", "w-5", "w-6"), recap.state.value.card.map { it.post.id })
        data.gate!!.complete(Unit)
        assertTrue(data.calls.contains("updateRecap:w-7,w-2,w-3,w-4,w-5,w-6:new text"))
        assertTrue(seen.contains(app.feature.social.week.EditEffect.Saved))

        data.gate = null
        edit.toggle("w-2")
        data.failNext += "updateRecap:w-7,w-3,w-4,w-5,w-6:new text"
        RecapEdits.pending.value = emptyMap()
        edit.save()
        assertEquals(EditError.Save, edit.state.value.error)
        assertTrue("rolled back", RecapEdits.pending.value.isEmpty())
    }

    @Test fun saveAsAlbumValidatesTheNameAndSavesTheCheckedOrder() {
        val data = FakeSocialData().apply { seedWeek() }
        val edit = WeekEditViewModel(data, GROUP, null, LocalDate.parse("2026-10-12"), albumOnly = true)
        assertTrue(edit.state.value.albumSheet)
        assertEquals((1..7).map { "w-$it" }, edit.state.value.checked)
        edit.setAlbumName("   ")
        edit.saveAlbum()
        assertEquals(EditError.AlbumName, edit.state.value.albumError)
        edit.setAlbumName("lake week")
        edit.saveAlbum()
        assertTrue(data.calls.contains("saveAlbum:lake week:" + (1..7).joinToString(",") { "w-$it" }))
    }

    @Test fun historySynthesisesTheCurrentWeekAndFollowsRealtime() = runBlocking {
        val data = FakeSocialData().apply { seedWeek() }
        val vm = HistoryViewModel(data, GROUP) { LocalDate.parse("2026-10-21") }
        val weeks = vm.state.value.weeks
        assertEquals(LocalDate.parse("2026-10-19"), weeks.first().weekStart)
        assertTrue(weeks.first().isCurrent && weeks.first().photos.isEmpty())
        assertEquals(7, weeks[1].photos.size)
        assertEquals("r-w", weeks[1].recapId)

        val fresh = data.addPhoto("new", BEN, LocalDate.parse("2026-10-20").atStartOfDay(ZoneOffset.UTC).toInstant())
        data.emit(GroupEvent.PostInserted(GROUP, fresh))
        assertEquals(listOf("new"), vm.state.value.weeks.first().photos.map { it.post.id })
        data.emit(GroupEvent.PostDeleted(GROUP, "w-1", null))
        assertEquals(6, vm.state.value.weeks[1].photos.size)
    }

    @Test fun historyPaginatesByWeek() {
        val data = FakeSocialData().apply { seedGroup() }
        val monday = LocalDate.parse("2026-10-12")
        data.weeks[GROUP] = (0 until 10).map { i ->
            val p = data.addPhoto("h-$i", ANA, monday.minusWeeks(i.toLong()).atStartOfDay(ZoneOffset.UTC).toInstant())
            app.data.model.HistoryWeek(monday.minusWeeks(i.toLong()), listOf(p.id))
        }.toMutableList()
        val vm = HistoryViewModel(data, GROUP) { monday }
        assertEquals(8, vm.state.value.weeks.size)
        vm.loadMore()
        assertEquals(10, vm.state.value.weeks.size)
        assertTrue(vm.state.value.endReached)
    }

    // ---- albums ----

    @Test fun albumsListCardsNewestFirstWithCoverAndSaver() {
        val data = FakeSocialData().apply { seedAlbums() }
        val s = AlbumsViewModel(data, GROUP).state.value
        assertEquals(AlbumsState.Phase.Ready, s.phase)
        assertEquals(listOf("a-2", "a-1"), s.cards.map { it.album.id })
        assertEquals("Ana", s.cards[1].savedBy)
        assertEquals("u/$BEN/md-w-2/r/thumb.jpg", s.cards[1].coverPath)
    }

    @Test fun albumRenameIsOptimisticAndDeleteNeedsCreatorOrAdmin() {
        val data = FakeSocialData().apply { seedAlbums() }
        val vm = AlbumViewModel(data, GROUP, "a-1")
        val seen = collect(vm.effects)
        assertFalse("Ana created it; I am not admin", vm.state.value.canDelete)
        assertEquals(listOf("w-2", "w-1"), vm.state.value.photos.map { it.post.id })
        vm.startRename()
        vm.setRenameName("lake weekend 2026")
        data.gate = CompletableDeferred()
        vm.rename()
        assertEquals("lake weekend 2026", vm.state.value.album?.name)
        data.gate!!.complete(Unit)
        assertTrue(seen.contains(AlbumEffect.Renamed))

        data.gate = null
        vm.startRename()
        vm.setRenameName("nope")
        data.failNext += "renameAlbum:nope"
        vm.rename()
        assertEquals("rolled back", "lake weekend 2026", vm.state.value.album?.name)
        assertTrue(vm.state.value.renaming)

        val mine = AlbumViewModel(data, GROUP, "a-2")
        assertTrue(mine.state.value.canDelete)
        val mineEffects = collect(mine.effects)
        mine.delete()
        assertTrue(mineEffects.contains(AlbumEffect.Deleted))
    }
}
