package app.feature.capture

import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import app.data.error.DataError
import app.data.media.upload.UploadProgress
import app.data.model.MediaKind
import app.data.model.RenderStatus
import app.data.offline.DataState
import app.feature.capture.camera.CameraViewModel
import app.feature.capture.collage.CollageViewModel
import app.feature.capture.daily.DailyCaptureViewModel
import app.feature.capture.data.CaptureHandoff
import app.feature.capture.data.CapturedMedia
import app.feature.capture.data.MemoryCapturePrefs
import app.feature.capture.data.PostSend
import app.feature.capture.sendto.SendToViewModel
import app.feature.capture.sendto.VoiceNoteFile
import app.media.DualCaptureMode
import app.media.Lens
import app.model.CountdownState
import app.model.ServerClock
import app.model.SessionPromptGate
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.toList
import kotlinx.coroutines.launch
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.advanceTimeBy
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import java.io.File
import java.time.Duration

@OptIn(ExperimentalCoroutinesApi::class)
@RunWith(AndroidJUnit4::class)
class ViewModelTests {
    private val context = ApplicationProvider.getApplicationContext<android.content.Context>()
    private val dir = File(context.cacheDir, "vm-test").apply { deleteRecursively(); mkdirs() }
    private val data = FakeCaptureData()
    private val handoff = CaptureHandoff()
    private val dispatcher = UnconfinedTestDispatcher()

    @Before fun setUp() = Dispatchers.setMain(dispatcher)
    @After fun tearDown() = Dispatchers.resetMain()


    // ---- camera.capture -------------------------------------------------------------------

    private fun camera(gate: SessionPromptGate = SessionPromptGate(), group: String? = "g1", prefs: MemoryCapturePrefs = MemoryCapturePrefs()) =
        CameraViewModel(data, handoff, prefs, gate, dir, group, durationOf = { 3_000L }, sizeOf = { 300 to 400 })

    @Test fun oneTapCapturesAndHandsTheGroupToSendTo() = runTest(dispatcher) {
        val vm = camera()
        val camera = FakeCameraController()
        vm.onPermission(true)
        vm.attach(camera)
        assertEquals(CameraViewModel.Session.Live, vm.ui.value.session)
        val events = mutableListOf<CameraViewModel.Event>()
        val job = launch { vm.event.toList(events) }
        vm.capturePhoto()
        val pending = handoff.pending.value!!
        assertEquals(MediaKind.Photo, pending.media.kind)
        assertEquals("g1", pending.contextGroupId)
        assertEquals(300, pending.media.width)
        assertEquals(listOf(CameraViewModel.Event.OpenSendTo), events)
        job.cancel()
    }

    @Test fun flashOnlyWhenTheCameraHasOneAndFlipKeepsTheLensForTheSession() = runTest(dispatcher) {
        val prefs = MemoryCapturePrefs()
        val vm = camera(prefs = prefs)
        val camera = FakeCameraController(hasFlash = true)
        vm.onPermission(true)
        vm.attach(camera)
        vm.toggleFlash()
        vm.capturePhoto()
        assertTrue(camera.photos.single().second)
        vm.flip()
        assertEquals(Lens.Front, vm.ui.value.lens)
        assertFalse(vm.ui.value.flashOn)
        assertTrue(prefs.frontLensThisSession)
        assertEquals(Lens.Front, camera(prefs = prefs).ui.value.lens)
    }

    @Test fun freeLongPressOpensThePaywallOncePerSessionAndTapStillCaptures() = runTest(dispatcher) {
        val gate = SessionPromptGate()
        val vm = camera(gate)
        vm.onPermission(true)
        vm.attach(FakeCameraController())
        val events = mutableListOf<CameraViewModel.Event>()
        val job = launch { vm.event.toList(events) }
        vm.startVideo(microphoneAsked = true)
        vm.startVideo(microphoneAsked = true)
        assertEquals(listOf(CameraViewModel.Event.OpenPaywall), events)
        assertFalse(vm.ui.value.coachVisible) // video not available → no coach
        vm.capturePhoto()
        assertEquals(CameraViewModel.Event.OpenSendTo, events.last())
        job.cancel()
    }

    @Test fun premiumFirstLongPressAsksForTheMicThenRecordsAVideo() = runTest(dispatcher) {
        data.premium = true
        val prefs = MemoryCapturePrefs()
        val vm = camera(prefs = prefs)
        val camera = FakeCameraController()
        vm.onPermission(true)
        vm.attach(camera)
        assertTrue(vm.ui.value.coachVisible)
        assertEquals(Lens.Back to true, camera.binds.last()) // bound with video for premium
        val events = mutableListOf<CameraViewModel.Event>()
        val job = launch { vm.event.toList(events) }
        vm.startVideo(microphoneAsked = false)
        assertEquals(CameraViewModel.Event.AskMicrophone, events.single())
        vm.startVideo(microphoneAsked = true)
        assertTrue(vm.ui.value.recording)
        assertEquals(CameraViewModel.Event.RecordingStarted, events.last())
        vm.stopVideo()
        assertFalse(vm.ui.value.recording)
        val media = handoff.pending.value!!.media
        assertEquals(MediaKind.Video, media.kind)
        assertEquals(3_000, media.durationMs)
        // The first recorded video ends the coach for good.
        assertTrue(prefs.holdToRecordCoachDone)
        assertFalse(vm.ui.value.coachVisible)
        job.cancel()
    }

    @Test fun sessionFailureShowsUnavailableAndRetryRebinds() = runTest(dispatcher) {
        val vm = camera()
        val camera = FakeCameraController(bindFails = true)
        vm.onPermission(true)
        vm.attach(camera)
        assertEquals(CameraViewModel.Session.Unavailable, vm.ui.value.session)
        assertFalse(vm.ui.value.showControls)
        camera.bindFails = false
        vm.startSession()
        assertEquals(CameraViewModel.Session.Live, vm.ui.value.session)
    }

    @Test fun deniedPermissionHidesTheControls() {
        val vm = camera()
        vm.onPermission(false)
        assertEquals(CameraViewModel.Permission.Denied, vm.ui.value.permission)
        assertFalse(vm.ui.value.showControls)
    }

    // ---- camera.sendto ----------------------------------------------------------------------

    private fun media(kind: MediaKind = MediaKind.Photo) = CapturedMedia(kind, Images.photoFile(dir, "c-${System.nanoTime()}.jpg"), 300, 400, if (kind == MediaKind.Video) 3000 else null, fromLibrary = false)

    private fun sendTo(context: String?, kind: MediaKind = MediaKind.Photo, gate: SessionPromptGate = SessionPromptGate(), reply: String? = null, maxCaption: Int? = null): SendToViewModel {
        handoff.put(media(kind), context, reply)
        return SendToViewModel(data, handoff, gate, voiceRecorderAvailable = false, maxCaption = maxCaption)
    }

    @Test fun groupsLoadCacheFirstWithoutALoadingFlash() {
        data.loaded(group("g1", "Family"), group("g2", "Roommates"), source = DataState.Source.Cache, refreshing = true)
        val vm = sendTo(null)
        assertTrue(vm.ui.value.groups is SendToViewModel.Groups.Loaded)
    }

    @Test fun preselectsTheContextGroupOrEveryGroupWithoutContext() {
        data.loaded(group("g1", "Family"), group("g2", "Roommates"))
        assertEquals(setOf("g1"), sendTo("g1").ui.value.selected)
        assertEquals(setOf("g1", "g2"), sendTo(null).ui.value.selected)
        // A widget whose group was left: nothing preselected, Send disabled until a choice.
        val gone = sendTo("gone")
        assertTrue(gone.ui.value.selected.isEmpty())
        assertFalse(gone.ui.value.sendEnabled)
    }

    @Test fun sendsOnePostToTwoGroupsWithCaptionAndVoiceAndClosesWhenPosted() = runTest(dispatcher) {
        data.loaded(group("g1", "Family"), group("g2", "Roommates"), group("g3", "Work"))
        val vm = sendTo("g1")
        vm.toggle("g2")
        vm.onCaption("  sunday  ")
        val voice = File(dir, "v.m4a").apply { writeBytes(byteArrayOf(1, 2)) }
        vm.onVoiceNote(VoiceNoteFile(voice, 2_000))
        val events = mutableListOf<SendToViewModel.Event>()
        val job = launch { vm.event.toList(events) }
        assertTrue(vm.ui.value.sendEnabled)
        vm.send()
        val post = data.enqueued.single()
        assertEquals(listOf("g1", "g2"), post.groupIds)
        assertEquals("sunday", post.caption)
        assertEquals(2_000, post.voiceDurationMs)
        assertEquals(MediaKind.Photo, post.kind)
        // The sheet stays open, busy, until the post exists (camera.sendto → send).
        assertTrue(vm.ui.value.sending)
        assertFalse(vm.ui.value.sendEnabled)
        assertTrue(events.isEmpty())
        vm.toggle("g3") // rows are disabled while sending
        assertEquals(setOf("g1", "g2"), vm.ui.value.selected)
        data.progressFlows["draft1"]!!.value = UploadProgress.Done(listOf("p1", "p2"))
        assertEquals(listOf(SendToViewModel.Event.Sent(listOf("Family", "Roommates"))), events)
        assertFalse(vm.ui.value.sending)
        assertNull(handoff.pending.value)
        assertFalse(voice.exists())
        job.cancel()
    }

    @Test fun aFailedSendStaysInTheSheetWithTryAgainAndCancel() = runTest(dispatcher) {
        data.loaded(group("g1", "Family"))
        val vm = sendTo("g1")
        val events = mutableListOf<SendToViewModel.Event>()
        val job = launch { vm.event.toList(events) }
        vm.send()
        data.progressFlows["draft1"]!!.value = UploadProgress.Failed(DataError.Unexpected(null))
        assertEquals(SendToViewModel.Alert.SendFailed(offline = false), vm.ui.value.alert)
        assertEquals(listOf(SendToViewModel.Event.Failed), events)
        assertNotNull(handoff.pending.value)
        // Try Again: the same draft once more, busy again.
        vm.retry()
        assertEquals(listOf("draft1"), data.retried)
        assertTrue(vm.ui.value.sending)
        assertNull(vm.ui.value.alert)
        // Offline while waiting: the offline alert.
        data.onlineFlow.value = false
        assertEquals(SendToViewModel.Alert.SendFailed(offline = true), vm.ui.value.alert)
        // Cancel withdraws the draft; the capture and choices stay; a new Send starts over.
        vm.dismissAlert()
        assertEquals(listOf("draft1"), data.discarded)
        assertNull(vm.ui.value.alert)
        assertFalse(vm.ui.value.sending)
        assertTrue(vm.ui.value.sendEnabled)
        data.onlineFlow.value = true
        vm.send()
        assertEquals(2, data.enqueued.size)
        job.cancel()
    }

    @Test fun closingAsksFirstOnlyWhenAMessageOrVoiceNoteWouldBeLost() = runTest(dispatcher) {
        data.loaded(group("g1", "Family"))
        val vm = sendTo("g1")
        val events = mutableListOf<SendToViewModel.Event>()
        val job = launch { vm.event.toList(events) }
        vm.onCaption("hi")
        vm.close()
        assertEquals(SendToViewModel.Alert.Discard, vm.ui.value.alert)
        assertTrue(events.isEmpty())
        vm.dismissAlert()
        assertNull(vm.ui.value.alert)
        assertNotNull(handoff.pending.value)
        vm.close()
        vm.confirmDiscard()
        assertEquals(listOf(SendToViewModel.Event.Close), events)
        assertNull(handoff.pending.value)
        job.cancel()
    }

    @Test fun voiceRecordingAttachesReplacesAndDeletesTheNote() {
        data.loaded(group("g1", "Family"))
        handoff.put(media(), "g1", null)
        val vm = SendToViewModel(data, handoff, SessionPromptGate(), voiceRecorderAvailable = true)
        assertTrue(vm.ui.value.micAvailable)
        vm.onVoiceRecording(true, startedAt = 42L)
        assertTrue(vm.ui.value.recordingVoice)
        assertEquals(42L, vm.ui.value.recordingStartedAt)
        val first = File(dir, "v1.m4a").apply { writeBytes(byteArrayOf(1)) }
        vm.onVoiceNote(VoiceNoteFile(first, 1_000))
        assertFalse(vm.ui.value.recordingVoice)
        assertNull(vm.ui.value.recordingStartedAt)
        assertTrue(vm.ui.value.hasAdditions)
        // A new note replaces (and deletes) the previous one.
        val second = File(dir, "v2.m4a").apply { writeBytes(byteArrayOf(2)) }
        vm.onVoiceNote(VoiceNoteFile(second, 2_000))
        assertFalse(first.exists())
        assertEquals(second, vm.ui.value.voice?.file)
        // "Delete recording".
        vm.deleteVoice()
        assertNull(vm.ui.value.voice)
        assertFalse(second.exists())
    }

    @Test fun nothingSelectedDisablesSend() {
        data.loaded(group("g1", "Family"))
        val vm = sendTo("g1")
        vm.toggle("g1")
        assertFalse(vm.ui.value.sendEnabled)
        vm.send()
        assertTrue(data.enqueued.isEmpty())
    }

    @Test fun aPickedVideoByAFreeMemberPromptsOnceAndDisablesSend() = runTest(dispatcher) {
        data.loaded(group("g1", "Family"))
        val gate = SessionPromptGate()
        val vm = sendTo("g1", MediaKind.Video, gate)
        val first = vm.event.first()
        assertEquals(SendToViewModel.Event.OpenPaywall, first)
        assertFalse(vm.ui.value.sendEnabled)
        assertTrue(gate.hasPrompted)
        data.premium = true
        val premium = sendTo("g1", MediaKind.Video, gate)
        assertTrue(premium.ui.value.sendEnabled)
    }

    @Test fun queueFailureKeepsTheCaptureAndShowsTheError() {
        data.loaded(group("g1", "Family"))
        data.enqueueError = DataError.NotSignedIn
        val vm = sendTo("g1")
        vm.send()
        assertEquals(SendToViewModel.Alert.SendFailed(offline = false), vm.ui.value.alert)
        assertNotNull(handoff.pending.value)
    }

    @Test fun replyGoesToExactlyTheRepliedGroup() {
        data.loaded(group("g1", "Family"), group("g2", "Roommates"))
        val vm = sendTo("g2", reply = "p9")
        assertEquals(listOf("g2"), vm.ui.value.visibleGroups.map { it.id })
        vm.toggle("g2") // locked
        vm.send()
        assertEquals(listOf("g2"), data.enqueued.single().groupIds)
        assertEquals("p9", data.enqueued.single().replyToPostId)
    }

    @Test fun groupStates() {
        data.groupsFlow.value = DataState(emptyList(), DataState.Source.Network, T0, refreshing = false, error = null)
        assertEquals(SendToViewModel.Groups.Empty, sendTo(null).ui.value.groups)
        data.groupsFlow.value = DataState(null, DataState.Source.None, null, refreshing = false, error = DataError.Network)
        assertEquals(SendToViewModel.Groups.Failed(offline = true), sendTo(null).ui.value.groups)
        data.groupsFlow.value = DataState(null, DataState.Source.None, null, refreshing = true, error = null)
        assertEquals(SendToViewModel.Groups.Loading, sendTo(null).ui.value.groups)
    }

    @Test fun captionIsCappedAtTheTokenLimitWithoutSplittingAnEmoji() {
        data.loaded(group("g1", "Family"))
        val max = app.designsystem.generated.Tokens.Counts.cameraSendtoSizeCaptionMaxLength
        val capped = sendTo("g1", maxCaption = max)
        capped.onCaption("x".repeat(2000))
        assertEquals(max, capped.ui.value.caption.length)
        // An emoji (two UTF-16 units) straddling the limit is dropped whole.
        capped.onCaption("x".repeat(max - 1) + "\uD83D\uDE00")
        assertEquals("x".repeat(max - 1), capped.ui.value.caption)
    }

    @Test fun closeDiscardsTheCapture() {
        data.loaded(group("g1", "Family"))
        val vm = sendTo("g1")
        val file = handoff.pending.value!!.media.file
        vm.close()
        assertNull(handoff.pending.value)
        assertFalse(file.exists())
    }

    // ---- PostSend ---------------------------------------------------------------------------

    @Test fun postSendFollowsTheDraftUntilPostedOrFailed() = runTest(dispatcher) {
        val sender = PostSend(data, CoroutineScope(dispatcher))
        assertEquals(PostSend.Status.Idle, sender.status.value)
        assertTrue(sender.send(app.data.media.upload.NewPost(MediaKind.Photo, media().file, groupIds = listOf("g1"))))
        assertEquals(PostSend.Status.Sending, sender.status.value)
        data.onlineFlow.value = false
        assertEquals(PostSend.Status.Failed(offline = true), sender.status.value)
        data.onlineFlow.value = true
        assertEquals(PostSend.Status.Sending, sender.status.value)
        data.progressFlows["draft1"]!!.value = UploadProgress.Failed(DataError.Network)
        assertEquals(PostSend.Status.Failed(offline = true), sender.status.value)
        sender.retry()
        assertEquals(listOf("draft1"), data.retried)
        data.progressFlows["draft1"]!!.value = UploadProgress.Done(listOf("p1"))
        assertEquals(PostSend.Status.Sent(listOf("p1")), sender.status.value)
    }

    // ---- daily.capture ----------------------------------------------------------------------

    private fun daily(scope: TestScope, gate: SessionPromptGate = SessionPromptGate()): DailyCaptureViewModel {
        data.invitation = invitation()
        data.groupById["g1"] = group("g1", "Family")
        val clock = ServerClock(Duration.ZERO) { T0.plusMillis(scope.testScheduler.currentTime) }
        return DailyCaptureViewModel(data, gate, dir, "g1", "inv1", clock, sizeOf = { 300 to 400 })
    }

    @Test fun countdownTicksToClosesAtAndIsThenRemoved() {
        val standard = StandardTestDispatcher()
        Dispatchers.setMain(standard)
        val scope = TestScope(standard)
        val vm = daily(scope)
        scope.runCurrent()
        assertEquals(120L, vm.ui.value.countdown?.remainingSeconds)
        scope.advanceTimeBy(60_500)
        scope.runCurrent()
        assertEquals(60L, vm.ui.value.countdown?.remainingSeconds)
        scope.advanceTimeBy(60_000)
        scope.runCurrent()
        assertNull(vm.ui.value.countdown)
    }

    @Test fun openedAfterTheWindowShowsNoCountdownAndStillPostsWithTheInvitation() = runTest(dispatcher) {
        data.invitation = invitation(closesAt = T0.minusSeconds(1))
        data.groupById["g1"] = group("g1", "Family")
        val vm = DailyCaptureViewModel(data, SessionPromptGate(), dir, "g1", "inv1", ServerClock(Duration.ZERO) { T0 })
        assertNull(vm.ui.value.countdown)
        vm.onPermission(true)
        vm.attach(FakeCameraController())
        vm.capture()
        vm.send()
        assertEquals("inv1", data.enqueued.single().invitationId)
    }

    @Test fun dualCaptureConcurrentAndSequentialFallbackAndSingleCamera() = runTest(dispatcher) {
        for ((mode, frontFails) in listOf(DualCaptureMode.Concurrent to false, DualCaptureMode.Sequential to false, DualCaptureMode.Sequential to true)) {
            val vm = daily(this)
            val camera = FakeCameraController(mode = mode, frontFails = frontFails)
            vm.onPermission(true)
            vm.attach(camera)
            assertEquals(mode, vm.ui.value.mode)
            vm.capture()
            val s = vm.ui.value
            assertEquals(DailyCaptureViewModel.Phase.Preview, s.phase)
            assertNotNull(s.main)
            assertEquals(frontFails, s.inset == null)
        }
    }

    @Test fun retakeReturnsToLiveAndSendQueuesBothPhotosToTheGroup() = runTest(dispatcher) {
        val gate = SessionPromptGate()
        val vm = daily(this, gate)
        assertFalse(gate.canPrompt) // no prompt while capturing
        vm.onPermission(true)
        vm.attach(FakeCameraController())
        vm.capture()
        vm.retake()
        assertEquals(DailyCaptureViewModel.Phase.Live, vm.ui.value.phase)
        vm.capture()
        val events = mutableListOf<DailyCaptureViewModel.Event>()
        val job = launch { vm.event.toList(events) }
        vm.send()
        val post = data.enqueued.single()
        assertEquals(listOf("g1"), post.groupIds)
        assertEquals("inv1", post.invitationId)
        assertNotNull(post.front)
        // The cover stays busy until the post exists, then closes with the group's name for the toast.
        assertTrue(vm.ui.value.sending)
        assertTrue(events.isEmpty())
        data.progressFlows["draft1"]!!.value = UploadProgress.Done(listOf("p1"))
        assertEquals(listOf(DailyCaptureViewModel.Event.Sent("Family")), events)
        job.cancel()
    }

    // ---- collage.view / collage.share ------------------------------------------------------

    private fun collageVm(scope: CoroutineScope? = null) = CollageViewModel(data, "g1", "inv1", File(dir, "collage-${System.nanoTime()}"), now = { T0.plusSeconds(600) }, pollMillis = 1_000)

    @Test fun readyCollageDownloadsEveryPage() {
        data.invitation = invitation()
        data.collage = collage(pages = 2)
        val vm = collageVm()
        val content = vm.ui.value.content as CollageViewModel.Content.Ready
        assertEquals(2, content.pages.size)
        assertTrue(content.pages.all { it != null })
        assertTrue(content.shareable)
        assertEquals(java.time.LocalDate.of(2026, 5, 26), vm.ui.value.date)
        assertTrue(data.downloads.any { it.endsWith("display-2.jpg") })
    }

    @Test fun collageShowsCachedPagesFirstAndKeepsThemOffline() {
        data.invitation = invitation()
        data.collage = collage(pages = 2)
        val cache = File(dir, "collage-cache")
        CollageViewModel(data, "g1", "inv1", cache, now = { T0.plusSeconds(600) })
        data.collageError = DataError.Network
        val offline = CollageViewModel(data, "g1", "inv1", cache, now = { T0.plusSeconds(600) })
        // Cached pages render from the first frame (no loading flash) and stay when the network fails.
        val content = offline.ui.value.content as CollageViewModel.Content.Ready
        assertEquals(2, content.pages.size)
    }

    @Test fun collageStates() {
        data.invitation = invitation()
        data.collage = null
        assertEquals(CollageViewModel.Content.Empty, collageVm().ui.value.content)
        data.collage = collage(status = RenderStatus.Failed)
        assertEquals(CollageViewModel.Content.Error, collageVm().ui.value.content)
        data.collage = null
        data.collageError = DataError.Network
        assertEquals(CollageViewModel.Content.Offline, collageVm().ui.value.content)
    }

    @Test fun composingCollageShowsLoadingAndIsLookedUpAgain() {
        val standard = StandardTestDispatcher()
        Dispatchers.setMain(standard)
        data.invitation = invitation()
        data.collage = collage(status = RenderStatus.Pending)
        val vm = collageVm()
        standard.scheduler.runCurrent()
        assertEquals(CollageViewModel.Content.Loading, vm.ui.value.content)
        data.collage = collage()
        standard.scheduler.advanceTimeBy(1_500)
        standard.scheduler.runCurrent()
        assertTrue(vm.ui.value.content is CollageViewModel.Content.Ready)
    }

    @Test fun shareDownloadsTheCurrentPagesStoriesImage() = runTest(dispatcher) {
        data.invitation = invitation()
        data.collage = collage(pages = 2)
        val vm = collageVm()
        vm.onPage(1)
        val events = mutableListOf<CollageViewModel.Event>()
        val job = launch { vm.event.toList(events) }
        vm.share()
        assertTrue(data.downloads.last().endsWith("g/g1/collages/c1/v1/share-2.jpg"))
        assertTrue((events.single() as CollageViewModel.Event.Share).file.isFile)
        job.cancel()
    }

    @Test fun countdownStateIsOpenOnlyBeforeClosesAt() {
        assertTrue(CountdownState.at(T0.plusSeconds(1), T0) is CountdownState.Open)
        assertTrue(CountdownState.at(T0, T0) is CountdownState.Closed)
    }
}
