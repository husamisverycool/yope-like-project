package app.feature.capture

import android.content.Intent
import android.net.Uri
import androidx.core.content.pm.ShortcutManagerCompat
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import app.data.error.DataError
import app.data.media.upload.UploadProgress
import app.data.model.MediaKind
import app.feature.capture.camera.CameraViewModel
import app.feature.capture.camera.TrimRequest
import app.feature.capture.data.CaptureHandoff
import app.feature.capture.data.CapturedMedia
import app.feature.capture.data.MemoryCapturePrefs
import app.feature.capture.data.PickedFile
import app.feature.capture.data.TakenOn
import app.feature.capture.sendto.SendToViewModel
import app.feature.capture.share.ShareIn
import app.feature.capture.share.ShareInbox
import app.feature.capture.share.ShareTargets
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
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import java.io.File
import java.time.LocalDate
import java.time.ZoneId

/**
 * Several photos in one post (camera.sendto "Several photos"), the day a library photo was taken (migration 0050) and
 * "Share to Jolt" (share.in) — docs/RESEARCH_FEATURES_2026-10-17.md #1, #5, #4.
 */
@OptIn(ExperimentalCoroutinesApi::class)
@RunWith(AndroidJUnit4::class)
class BatchShareTest {
    private val context = ApplicationProvider.getApplicationContext<android.content.Context>()
    private val dir = File(context.cacheDir, "batch-test").apply { deleteRecursively(); mkdirs() }
    private val data = FakeCaptureData()
    private val handoff = CaptureHandoff()
    private val dispatcher = UnconfinedTestDispatcher()

    @Before fun setUp() = Dispatchers.setMain(dispatcher)
    @After fun tearDown() {
        Dispatchers.resetMain()
        ShareInbox.take()
    }

    private fun photo(day: LocalDate? = null) =
        CapturedMedia(MediaKind.Photo, Images.photoFile(dir, "p-${System.nanoTime()}.jpg"), 300, 400, null, fromLibrary = true, takenOn = day)

    private fun sendTo(media: CapturedMedia, more: List<CapturedMedia>, context: String? = "g1"): SendToViewModel {
        handoff.put(media, context, more = more)
        return SendToViewModel(data, handoff, SessionPromptGate(), voiceRecorderAvailable = false)
    }

    // ---- camera.sendto with a selection ------------------------------------------------------

    @Test fun aSelectionPostsEachPhotoInOrderWithOneBatchIdAndTheMessageOnTheFirst() = runTest(dispatcher) {
        data.loaded(group("g1", "Family"), group("g2", "Roommates"))
        val days = listOf(LocalDate.of(2026, 9, 1), LocalDate.of(2026, 9, 2), LocalDate.of(2026, 9, 3))
        val items = days.map { photo(it) }
        val vm = sendTo(items[0], items.drop(1))
        assertTrue(vm.ui.value.showsSelection)
        assertEquals(items, vm.ui.value.selection)
        vm.toggle("g2")
        vm.onCaption("the weekend")
        val events = mutableListOf<SendToViewModel.Event>()
        val job = launch { vm.event.toList(events) }

        vm.send()
        // One photo at a time: the next is queued once the one before it is posted (the posts keep the order picked).
        assertEquals(1, data.enqueued.size)
        data.progressFlows["draft1"]!!.value = UploadProgress.Done(listOf("p1"))
        assertEquals(2, data.enqueued.size)
        assertTrue("still sending", vm.ui.value.sending)
        assertTrue(events.isEmpty())
        data.progressFlows["draft2"]!!.value = UploadProgress.Done(listOf("p2"))
        data.progressFlows["draft3"]!!.value = UploadProgress.Done(listOf("p3"))

        val posts = data.enqueued
        assertEquals(items.map { it.file }, posts.map { it.original })
        assertEquals(days, posts.map { it.takenOn })
        val batch = posts.first().batchId
        assertNotNull(batch)
        assertEquals(setOf(batch), posts.map { it.batchId }.toSet())
        assertEquals(listOf("the weekend", null, null), posts.map { it.caption })
        assertEquals(setOf(listOf("g1", "g2")), posts.map { it.groupIds }.toSet())
        assertEquals("one confirmation for the selection", listOf(SendToViewModel.Event.Sent(listOf("Family", "Roommates"))), events)
        assertNull(handoff.pending.value)
        assertFalse(items.any { it.file.exists() })
        job.cancel()
    }

    @Test fun onePhotoHasNoBatchAndACameraPhotoNoDay() = runTest(dispatcher) {
        data.loaded(group("g1", "Family"))
        val vm = sendTo(photo().copy(fromLibrary = false), emptyList())
        assertFalse(vm.ui.value.showsSelection)
        vm.send()
        assertNull(data.enqueued.single().batchId)
        assertNull(data.enqueued.single().takenOn)
    }

    @Test fun aFailedPhotoOfASelectionKeepsTheRestAndTryAgainGoesOn() = runTest(dispatcher) {
        data.loaded(group("g1", "Family"))
        val items = listOf(photo(), photo(), photo())
        val vm = sendTo(items[0], items.drop(1))
        vm.onCaption("hi")
        vm.send()
        data.progressFlows["draft1"]!!.value = UploadProgress.Done(listOf("p1"))
        data.progressFlows["draft2"]!!.value = UploadProgress.Failed(DataError.Unexpected(null))
        assertEquals(SendToViewModel.Alert.SendFailed(offline = false), vm.ui.value.alert)
        assertNotNull("the photos not yet posted stay", handoff.pending.value)
        vm.retry()
        assertEquals(listOf("draft2"), data.retried)
        data.progressFlows["draft2"]!!.value = UploadProgress.Done(listOf("p2"))
        assertEquals(3, data.enqueued.size)
        data.progressFlows["draft3"]!!.value = UploadProgress.Done(listOf("p3"))
        assertEquals(items.map { it.file }, data.enqueued.map { it.original })
        assertEquals(listOf("hi", null, null), data.enqueued.map { it.caption })
        assertEquals(1, data.enqueued.map { it.batchId }.toSet().size)
        assertNull(handoff.pending.value)
    }

    @Test fun aSelectionWithAVideoNeedsPremium() {
        data.loaded(group("g1", "Family"))
        val video = CapturedMedia(MediaKind.Video, Images.photoFile(dir, "v-${System.nanoTime()}.mp4"), null, null, 3000, fromLibrary = true)
        assertFalse(sendTo(photo(), listOf(video)).ui.value.sendEnabled)
        data.premium = true
        assertTrue(sendTo(photo(), listOf(video)).ui.value.sendEnabled)
    }

    // ---- camera.capture's library picker -----------------------------------------------------

    @Test fun pickingSeveralOpensOneSendToInOrderAndALongVideoIsTrimmedInPlace() = runTest(dispatcher) {
        val long = File(dir, "long.mp4").apply { writeText("v") }
        var lengths = mapOf(long to 42_000L)
        val vm = CameraViewModel(data, handoff, MemoryCapturePrefs(), SessionPromptGate(), dir, null, durationOf = { lengths[it] ?: 3_000L }, sizeOf = { 300 to 400 })
        val events = mutableListOf<CameraViewModel.Event>()
        val job = launch { vm.event.toList(events) }
        val first = Images.photoFile(dir, "a.jpg")
        val last = Images.photoFile(dir, "c.jpg")
        val day = LocalDate.of(2026, 8, 30)
        vm.onPickedAll(listOf(PickedFile(first, MediaKind.Photo, day), PickedFile(long, MediaKind.Video, day), PickedFile(last, MediaKind.Photo)))
        assertEquals(TrimRequest(long, 42_000L), vm.ui.value.trim)
        assertNull("send-to waits for the trimmer", handoff.pending.value)

        val clip = vm.trimTarget().apply { writeText("clip") }
        lengths = lengths + (clip to 9_000L)
        vm.onTrimmed(clip, failed = false)
        val pending = handoff.pending.value!!
        assertEquals(listOf(first, clip, last), pending.items.map { it.file })
        assertEquals(listOf(day, day, null), pending.items.map { it.takenOn })
        assertEquals(listOf(CameraViewModel.Event.OpenSendTo), events)
        job.cancel()
    }

    @Test fun aCancelledTrimLeavesThatVideoOut() = runTest(dispatcher) {
        val long = File(dir, "long2.mp4").apply { writeText("v") }
        val vm = CameraViewModel(data, handoff, MemoryCapturePrefs(), SessionPromptGate(), dir, null, durationOf = { if (it == long) 42_000L else 3_000L }, sizeOf = { 300 to 400 })
        val first = Images.photoFile(dir, "a2.jpg")
        vm.onPickedAll(listOf(PickedFile(first, MediaKind.Photo), PickedFile(long, MediaKind.Video)))
        vm.onTrimmed(null, failed = false)
        assertEquals(listOf(first), handoff.pending.value!!.items.map { it.file })
        assertFalse(long.exists())
    }

    @Test fun theLibraryLimitComesFromTheServerAndIsOneWhileUnknown() {
        assertEquals(1, CameraViewModel(data, handoff, MemoryCapturePrefs(), SessionPromptGate(), dir, null).ui.value.selectionLimit)
        data.batchMax = 20
        assertEquals(20, CameraViewModel(data, handoff, MemoryCapturePrefs(), SessionPromptGate(), dir, null).ui.value.selectionLimit)
    }

    // ---- the day a library photo was taken ---------------------------------------------------

    @Test fun takenOnIsTheDateOnlyOnTheDevicesDay() {
        val paris = ZoneId.of("Europe/Paris")
        val today = LocalDate.of(2026, 10, 17)
        assertEquals(LocalDate.of(2026, 9, 14), TakenOn.fromExif("2026:09:14 23:30:00", null, paris, today))
        // With an offset: the instant, on the device's day (23:30 in New York is the next morning in Paris).
        assertEquals(LocalDate.of(2026, 9, 15), TakenOn.fromExif("2026:09:14 23:30:00", "-04:00", paris, today))
        assertNull(TakenOn.fromExif("2027:01:01 10:00:00", null, paris, today))
        assertNull(TakenOn.fromExif("1899:12:31 10:00:00", null, paris, today))
        assertNull(TakenOn.fromExif("0000:00:00 00:00:00", null, paris, today))
        assertNull(TakenOn.fromExif(null, null, paris, today))
        // MediaStore DATE_TAKEN (ms) and the MP4 creation date (UTC).
        assertEquals(LocalDate.of(2026, 5, 2), TakenOn.fromEpochMillis(java.time.Instant.parse("2026-05-01T22:30:00Z").toEpochMilli(), paris, today))
        assertNull(TakenOn.fromEpochMillis(0, paris, today))
        assertEquals(LocalDate.of(2026, 5, 2), TakenOn.fromMp4Date("20260501T223000.000Z", paris, today))
        assertNull("never set (the MP4 epoch)", TakenOn.fromMp4Date("19040101T000000.000Z", paris, today))
    }

    // ---- share.in -----------------------------------------------------------------------------

    @Test fun sharedStreamsAreTakenInOrderAndOnlyOtherAppsContent() {
        val own = context.packageName
        val a = Uri.parse("content://media/external/images/media/1")
        val b = Uri.parse("content://com.example.gallery.provider/v/2")
        val single = Intent(Intent.ACTION_SEND).setType("image/jpeg").putExtra(Intent.EXTRA_STREAM, a)
        assertTrue(ShareIn.isShare(single))
        assertEquals(listOf(a), ShareIn.uris(single, own))
        val several = Intent(Intent.ACTION_SEND_MULTIPLE).setType("image/*")
            .putParcelableArrayListExtra(Intent.EXTRA_STREAM, arrayListOf(b, a, Uri.parse("file:///data/data/$own/files/secret.jpg"), Uri.parse("content://$own.capture.files/x.jpg")))
        assertEquals("file:// paths and this app's own providers are refused", listOf(b, a), ShareIn.uris(several, own))
        assertFalse(ShareIn.isShare(Intent(Intent.ACTION_VIEW)))
    }

    @Test fun theCameraTakesSharedItemsAsASelection() = runTest(dispatcher) {
        val vm = CameraViewModel(data, handoff, MemoryCapturePrefs(), SessionPromptGate(), dir, null, durationOf = { 3_000L }, sizeOf = { 300 to 400 })
        val shared = listOf(PickedFile(Images.photoFile(dir, "s1.jpg"), MediaKind.Photo, LocalDate.of(2026, 7, 4)), PickedFile(Images.photoFile(dir, "s2.jpg"), MediaKind.Photo))
        ShareInbox.put(shared)
        ShareInbox.takeShare()?.let { vm.onPickedAll(it.items, it.groupId) }
        assertNull("taken once", ShareInbox.take())
        assertEquals(shared.map { it.file }, handoff.pending.value!!.items.map { it.file })
        assertEquals(LocalDate.of(2026, 7, 4), handoff.pending.value!!.media.takenOn)
        assertNull("no group picked: the camera's own context", handoff.pending.value!!.contextGroupId)
    }

    @Test fun aShareThroughAGroupsShareTargetPreselectsThatGroup() {
        val target = Intent(Intent.ACTION_SEND).setType("image/jpeg")
            .putExtra(ShortcutManagerCompat.EXTRA_SHORTCUT_ID, ShareTargets.shortcutId("g2"))
        assertEquals("g2", ShareIn.groupId(target))
        assertNull("the camera's launcher shortcut is not a share target", ShareIn.groupId(Intent(Intent.ACTION_SEND).putExtra(ShortcutManagerCompat.EXTRA_SHORTCUT_ID, "camera-group-g2")))
        assertNull(ShareIn.groupId(Intent(Intent.ACTION_SEND)))
        val vm = CameraViewModel(data, handoff, MemoryCapturePrefs(), SessionPromptGate(), dir, "g1", durationOf = { 3_000L }, sizeOf = { 300 to 400 })
        ShareInbox.put(listOf(PickedFile(Images.photoFile(dir, "t1.jpg"), MediaKind.Photo)), groupId = "g2")
        ShareInbox.takeShare()?.let { vm.onPickedAll(it.items, it.groupId) }
        assertEquals("g2", handoff.pending.value!!.contextGroupId)
    }
}
