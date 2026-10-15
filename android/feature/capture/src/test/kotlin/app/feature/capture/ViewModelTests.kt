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
import app.feature.capture.data.SendTracker
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

    private fun tracker() = SendTracker(data, CoroutineScope(dispatcher))

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
        return SendToViewModel(data, handoff, tracker(), MemoryCapturePrefs(), gate, voiceRecorderAvailable = false, maxCaption = maxCaption)
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
        // A widget whose group was left: nothing preselected, send hidden until a choice.
        val gone = sendTo("gone")
        assertTrue(gone.ui.value.selected.isEmpty())
        assertFalse(gone.ui.value.sendVisible)
    }

    @Test fun sendsOnePostToTwoGroupsWithCaptionAndVoiceAndClosesAtOnce() = runTest(dispatcher) {
        data.loaded(group("g1", "Family"), group("g2", "Roommates"), group("g3", "Work"))
        val vm = sendTo("g1")
        vm.toggle("g2")
        vm.onCaption("  sunday  ")
        val voice = File(dir, "v.m4a").apply { writeBytes(byteArrayOf(1, 2)) }
        vm.onVoiceNote(VoiceNoteFile(voice, 2_000))
        val events = mutableListOf<SendToViewModel.Event>()
        val job = launch { vm.event.toList(events) }
        assertTrue(vm.ui.value.sendVisible)
        vm.send()
        val post = data.enqueued.single()
        assertEquals(listOf("g1", "g2"), post.groupIds)
        assertEquals("sunday", post.caption)
        assertEquals(2_000, post.voiceDurationMs)
        assertEquals(MediaKind.Photo, post.kind)
        assertEquals(listOf(SendToViewModel.Event.Sent), events)
        assertNull(handoff.pending.value)
        job.cancel()
    }

    @Test fun voiceRecordingLocksAndAttachesTheNote() {
        data.loaded(group("g1", "Family"))
        handoff.put(media(), "g1", null)
        val vm = SendToViewModel(data, handoff, tracker(), MemoryCapturePrefs(), SessionPromptGate(), voiceRecorderAvailable = true)
        assertTrue(vm.ui.value.micAvailable)
        assertTrue(vm.ui.value.voiceCoachVisible)
        vm.onVoiceLocked() // nothing to lock before a recording
        assertFalse(vm.ui.value.voiceLocked)
        vm.onVoiceRecording(true, startedAt = 42L)
        assertTrue(vm.ui.value.recordingVoice)
        assertEquals(42L, vm.ui.value.recordingStartedAt)
        assertFalse(vm.ui.value.voiceCoachVisible) // recording dismisses the coach for good
        vm.onVoiceLocked()
        assertTrue(vm.ui.value.voiceLocked)
        val first = File(dir, "v1.m4a").apply { writeBytes(byteArrayOf(1)) }
        vm.onVoiceNote(VoiceNoteFile(first, 1_000))
        assertFalse(vm.ui.value.recordingVoice)
        assertFalse(vm.ui.value.voiceLocked)
        assertNull(vm.ui.value.recordingStartedAt)
        // A new note replaces (and deletes) the previous one.
        val second = File(dir, "v2.m4a").apply { writeBytes(byteArrayOf(2)) }
        vm.onVoiceNote(VoiceNoteFile(second, 2_000))
        assertFalse(first.exists())
        assertEquals(second, vm.ui.value.voice?.file)
    }

    @Test fun nothingSelectedHidesSend() {
        data.loaded(group("g1", "Family"))
        val vm = sendTo("g1")
        vm.toggle("g1")
        assertFalse(vm.ui.value.sendVisible)
        vm.send()
        assertTrue(data.enqueued.isEmpty())
    }

    @Test fun aPickedVideoByAFreeMemberPromptsOnceAndHidesSend() = runTest(dispatcher) {
        data.loaded(group("g1", "Family"))
        val gate = SessionPromptGate()
        val vm = sendTo("g1", MediaKind.Video, gate)
        val first = vm.event.first()
        assertEquals(SendToViewModel.Event.OpenPaywall, first)
        assertFalse(vm.ui.value.sendVisible)
        assertTrue(gate.hasPrompted)
        data.premium = true
        val premium = sendTo("g1", MediaKind.Video, gate)
        assertTrue(premium.ui.value.sendVisible)
    }

    @Test fun queueFailureKeepsTheCaptureAndShowsTheError() {
        data.loaded(group("g1", "Family"))
        data.enqueueError = DataError.NotSignedIn
        val vm = sendTo("g1")
        vm.send()
        assertEquals(DataError.NotSignedIn, vm.ui.value.sendError)
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

    // ---- SendTracker ------------------------------------------------------------------------

    @Test fun trackerShowsOfflineAndFailureAndClearsWhenSent() = runTest(dispatcher) {
        val tracker = tracker()
        val draft = data.enqueue(app.data.media.upload.NewPost(MediaKind.Photo, media().file, groupIds = listOf("g1")))
        val sent = mutableListOf<SendTracker.Sent>()
        val job = launch { tracker.sent.toList(sent) }
        tracker.track(draft, listOf("Family"))
        assertNull(tracker.failure.value)
        data.onlineFlow.value = false
        assertTrue(tracker.failure.value is SendTracker.Failure.Offline)
        data.progressFlows[draft]!!.value = UploadProgress.Failed(DataError.Network)
        assertTrue(tracker.failure.value is SendTracker.Failure.SendFailed)
        tracker.retry(draft)
        assertEquals(listOf(draft), data.retried)
        data.onlineFlow.value = true
        data.progressFlows[draft]!!.value = UploadProgress.Done(listOf("p1"))
        assertNull(tracker.failure.value)
        assertEquals(listOf("Family"), sent.single().groupNames)
        job.cancel()
    }

    // ---- daily.capture ----------------------------------------------------------------------

    private fun daily(scope: TestScope, gate: SessionPromptGate = SessionPromptGate()): DailyCaptureViewModel {
        data.invitation = invitation()
        data.groupById["g1"] = group("g1", "Family")
        val clock = ServerClock(Duration.ZERO) { T0.plusMillis(scope.testScheduler.currentTime) }
        return DailyCaptureViewModel(data, tracker(), gate, dir, "g1", "inv1", clock, sizeOf = { 300 to 400 })
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
        val vm = DailyCaptureViewModel(data, tracker(), SessionPromptGate(), dir, "g1", "inv1", ServerClock(Duration.ZERO) { T0 })
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
        assertEquals(listOf(DailyCaptureViewModel.Event.Sent), events)
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
