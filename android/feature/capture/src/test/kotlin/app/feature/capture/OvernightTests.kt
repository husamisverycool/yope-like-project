package app.feature.capture

import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import app.data.error.DataError
import app.data.media.upload.UploadProgress
import app.data.model.Developing
import app.data.model.MediaKind
import app.feature.capture.camera.CameraViewModel
import app.feature.capture.camera.CaptureMode
import app.feature.capture.camera.OvernightReveal
import app.feature.capture.data.CaptureHandoff
import app.feature.capture.data.MemoryCapturePrefs
import app.feature.capture.sendto.SendToViewModel
import app.model.SessionPromptGate
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.toList
import kotlinx.coroutines.launch
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import java.io.File
import java.time.Instant
import java.time.ZoneId

/** camera.overnight (part A, and part C's reveal rule): the 9 AM · Now mode, destinations, the queued capture. */
@OptIn(ExperimentalCoroutinesApi::class)
@RunWith(AndroidJUnit4::class)
class OvernightTests {
    private val context = ApplicationProvider.getApplicationContext<android.content.Context>()
    private val dir = File(context.cacheDir, "overnight-test").apply { deleteRecursively(); mkdirs() }
    private val data = FakeCaptureData()
    private val handoff = CaptureHandoff()
    private val dispatcher = UnconfinedTestDispatcher()

    /** Thursday 15 October 2026, 23:30 UTC (a photo taken late reveals the next morning). */
    private val night: Instant = Instant.parse("2026-10-15T23:30:00Z")

    @Before fun setUp() {
        Dispatchers.setMain(dispatcher)
        data.loaded(group("g1", "Sunday dinners"), group("g2", "Roommates"), group("g3", "Family"))
    }

    @After fun tearDown() = Dispatchers.resetMain()

    private fun camera(group: String? = null, prefs: MemoryCapturePrefs = MemoryCapturePrefs(), reply: String? = null) =
        CameraViewModel(data, handoff, prefs, SessionPromptGate(), dir, group, replyToPostId = reply, clock = { night.toEpochMilli() }, sizeOf = { 300 to 400 })

    @Test fun nowIsTheDefaultAndRepliesHaveNoModeControl() {
        val vm = camera()
        assertEquals(CaptureMode.Now, vm.ui.value.mode)
        assertTrue(vm.ui.value.overnightAvailable)
        assertTrue(vm.ui.value.showLibrary)
        val reply = camera(group = "g1", reply = "p1")
        assertFalse(reply.ui.value.overnightAvailable)
        reply.selectMode(CaptureMode.Later)
        assertEquals(CaptureMode.Now, reply.ui.value.mode)
    }

    @Test fun theFirstSwitchOpensTheSheetWithEveryGroupAndTheChoiceIsKeptForTheSession() {
        val prefs = MemoryCapturePrefs()
        val vm = camera(prefs = prefs)
        assertEquals(SendToViewModel.Groups.Loading, vm.ui.value.groups) // nothing read until 9 AM is used
        vm.selectMode(CaptureMode.Later)
        assertEquals(setOf("g1", "g2", "g3"), vm.ui.value.destinations) // owner decision 11, as camera.sendto
        assertTrue(vm.ui.value.destinationSheet)
        assertFalse(vm.ui.value.showLibrary)
        vm.toggleDestination("g2")
        vm.confirmDestinations()
        assertFalse(vm.ui.value.destinationSheet)
        assertEquals(CaptureMode.Later, vm.ui.value.mode)
        assertEquals(setOf("g1", "g3"), prefs.overnightGroups)
        // Back and forth: no sheet again this session; the pill opens it.
        vm.selectMode(CaptureMode.Now)
        vm.selectMode(CaptureMode.Later)
        assertFalse(vm.ui.value.destinationSheet)
        vm.openDestinations()
        assertTrue(vm.ui.value.destinationSheet)
        // A new camera in the same session starts in Now with the session's groups.
        val next = camera(prefs = prefs)
        assertEquals(CaptureMode.Now, next.ui.value.mode)
        next.selectMode(CaptureMode.Later)
        assertFalse(next.ui.value.destinationSheet)
        assertEquals(setOf("g1", "g3"), next.ui.value.destinations)
    }

    @Test fun theCamerasGroupIsPreselectedAndNothingSelectedGoesBackToNow() {
        val vm = camera(group = "g2")
        vm.selectMode(CaptureMode.Later)
        assertEquals(setOf("g2"), vm.ui.value.destinations)
        vm.toggleDestination("g2")
        vm.confirmDestinations()
        assertEquals(CaptureMode.Now, vm.ui.value.mode)
    }

    @Test fun noGroupsShowsTheSendToEmptyStateAndDoneReturnsToNow() {
        data.loaded()
        val vm = camera()
        vm.selectMode(CaptureMode.Later)
        assertEquals(SendToViewModel.Groups.Empty, vm.ui.value.groups)
        assertTrue(vm.ui.value.destinationSheet)
        vm.confirmDestinations()
        assertEquals(CaptureMode.Now, vm.ui.value.mode)
    }

    @Test fun theNineAmShutterQueuesAnOvernightPhotoWithoutPreviewAndAnnouncesTheReveal() = runTest(dispatcher) {
        val vm = camera(prefs = MemoryCapturePrefs(overnightGroups = setOf("g3", "g1")))
        val camera = FakeCameraController()
        vm.onPermission(true)
        vm.attach(camera)
        vm.selectMode(CaptureMode.Later)
        assertFalse(vm.ui.value.destinationSheet)
        val events = mutableListOf<CameraViewModel.Event>()
        val job = launch { vm.event.toList(events) }
        vm.capturePhoto()
        val post = data.enqueued.single()
        assertTrue(post.overnight)
        assertEquals(MediaKind.Photo, post.kind)
        assertEquals(listOf("g1", "g3"), post.groupIds) // the member's group order
        assertNull(post.caption)
        assertNull(handoff.pending.value) // no send-to
        assertFalse(camera.photos.single().first.exists()) // the queue keeps its own copy; the camera's goes
        // 23:30 UTC → 09:00 the next morning in the groups' zone (UTC).
        assertEquals(listOf<CameraViewModel.Event>(CameraViewModel.Event.OvernightCaptured(Instant.parse("2026-10-16T09:00:00Z"))), events)
        assertFalse(vm.ui.value.capturing) // the camera stays ready for the next photo

        // Uploaded: the developing state is read again; failed after its retries: the toast.
        data.developing = Developing(true, Instant.parse("2026-10-16T09:00:00Z"))
        data.progressFlows.getValue("draft1").value = UploadProgress.Done(emptyList())
        assertTrue(vm.ui.value.developing!!.developing)
        vm.capturePhoto()
        data.progressFlows.getValue("draft2").value = UploadProgress.Failed(DataError.Network)
        assertEquals(CameraViewModel.Event.OvernightFailed, events.last())
        job.cancel()
    }

    @Test fun aPhotoThatCannotBeQueuedFailsAndHoldDoesNothingInNineAmMode() = runTest(dispatcher) {
        data.premium = true
        data.enqueueError = DataError.NotSignedIn
        val vm = camera(prefs = MemoryCapturePrefs(overnightGroups = setOf("g1")))
        vm.onPermission(true)
        vm.attach(FakeCameraController())
        vm.selectMode(CaptureMode.Later)
        val events = mutableListOf<CameraViewModel.Event>()
        val job = launch { vm.event.toList(events) }
        vm.capturePhoto()
        assertEquals(listOf<CameraViewModel.Event>(CameraViewModel.Event.OvernightFailed), events)
        vm.startVideo(microphoneAsked = true)
        assertFalse(vm.ui.value.recording)
        assertFalse(vm.ui.value.coachVisible)
        assertEquals(1, events.size)
        job.cancel()
    }

    @Test fun theRevealIsTheFirstNineAmAfterCaptureInTheGroupsZone() {
        val utc = ZoneId.of("UTC")
        assertEquals(Instant.parse("2026-10-16T09:00:00Z"), OvernightReveal.next(Instant.parse("2026-10-16T08:59:00Z"), utc))
        assertEquals(Instant.parse("2026-10-17T09:00:00Z"), OvernightReveal.next(Instant.parse("2026-10-16T09:00:00Z"), utc))
        // Wall clock across daylight saving (New York springs forward on 8 March 2026): 09:00 EDT = 13:00 UTC.
        val ny = ZoneId.of("America/New_York")
        assertEquals(Instant.parse("2026-03-08T13:00:00Z"), OvernightReveal.next(Instant.parse("2026-03-08T05:00:00Z"), ny))
        // Two groups in two zones: the earlier reveal is announced.
        val paris = group("p", "Paris").copy(timeZone = "Europe/Paris")
        val newYork = group("n", "New York").copy(timeZone = "America/New_York")
        assertEquals(Instant.parse("2026-10-16T07:00:00Z"), OvernightReveal.earliest(night, listOf(newYork, paris)))
    }
}
