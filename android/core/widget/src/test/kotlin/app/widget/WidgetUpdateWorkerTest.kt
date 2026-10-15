package app.widget

import android.content.Context
import androidx.compose.ui.unit.DpSize
import androidx.compose.ui.unit.dp
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.work.ListenableWorker
import androidx.work.WorkInfo
import androidx.work.WorkManager
import androidx.work.WorkerFactory
import androidx.work.WorkerParameters
import androidx.work.testing.TestListenableWorkerBuilder
import androidx.work.testing.WorkManagerTestInitHelper
import app.model.WidgetSnapshot
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import java.io.File
import java.io.IOException
import java.time.Instant

@RunWith(AndroidJUnit4::class)
class WidgetUpdateWorkerTest {
    private val context: Context = ApplicationProvider.getApplicationContext()
    private lateinit var store: WidgetFileStore
    private val refreshed = mutableListOf<String>()
    private val downloads = mutableListOf<String>()

    private val request = WidgetUpdateRequest(
        groupId = "g1", groupName = "Family", renditionUrl = "https://storage.example/w.jpg?token=abc",
        kind = WidgetSnapshot.Kind.Photo, postedAt = Instant.parse("2026-10-15T12:00:00Z"), sourceId = "p1",
        senderName = "Ana", senderAvatarUrl = null, caption = "hello",
    )

    @Before fun setUp() {
        store = WidgetFileStore(File(context.cacheDir, "widgets-test").apply { deleteRecursively() })
    }

    private fun worker(downloader: RenditionDownloader, data: WidgetUpdateRequest = request, attempt: Int = 0) =
        TestListenableWorkerBuilder<WidgetUpdateWorker>(context)
            .setInputData(data.toData())
            .setRunAttemptCount(attempt)
            .setWorkerFactory(object : WorkerFactory() {
                override fun createWorker(appContext: Context, workerClassName: String, workerParameters: WorkerParameters): ListenableWorker =
                    WidgetUpdateWorker(appContext, workerParameters, downloader, store) { _, g -> refreshed += g }
            })
            .build()

    @Test fun downloadsStoresAndRefreshesTheGroupsWidgets() = runBlocking {
        val result = worker({ url, out -> downloads += url; out.write(byteArrayOf(1, 2, 3)) }).doWork()
        assertEquals(ListenableWorker.Result.success(), result)
        val snapshot = store.read("g1")!!
        assertEquals("hello", snapshot.caption)
        assertEquals(3L, store.photo(snapshot).length())
        assertEquals(listOf("g1"), refreshed)
        assertEquals(listOf(request.renditionUrl), downloads)
    }

    @Test fun duplicateDeliveryDoesNotDownloadAgain() = runBlocking {
        worker({ _, out -> out.write(1) }).doWork()
        downloads.clear(); refreshed.clear()
        val result = worker({ url, out -> downloads += url; out.write(1) }).doWork()
        assertEquals(ListenableWorker.Result.success(), result)
        assertTrue(downloads.isEmpty())
        assertTrue(refreshed.isEmpty())
    }

    @Test fun expiredSignedUrlFailsWithoutRetry() = runBlocking {
        val result = worker({ _, _ -> throw HttpStatusException(403) }).doWork()
        assertEquals(ListenableWorker.Result.failure(), result)
        assertNull(store.read("g1"))
        assertTrue(refreshed.isEmpty())
    }

    @Test fun networkErrorsRetryThenGiveUp() = runBlocking {
        assertEquals(ListenableWorker.Result.retry(), worker({ _, _ -> throw IOException("reset") }).doWork())
        assertEquals(ListenableWorker.Result.retry(), worker({ _, _ -> throw HttpStatusException(503) }).doWork())
        assertEquals(ListenableWorker.Result.failure(), worker({ _, _ -> throw IOException("reset") }, attempt = 4).doWork())
    }

    @Test fun malformedInputFails() = runBlocking {
        val bad = TestListenableWorkerBuilder<WidgetUpdateWorker>(context).build()
        assertEquals(ListenableWorker.Result.failure(), bad.doWork())
    }

    @Test fun requestDataRoundTrips() {
        assertEquals(request, WidgetUpdateRequest.fromData(request.toData()))
        assertNull(WidgetUpdateRequest.fromData(request.copy(groupId = "../x").toData()))
    }

    @Test fun schedulerQueuesOneChainPerGroup() {
        WorkManagerTestInitHelper.initializeTestWorkManager(context)
        WidgetUpdateScheduler.enqueue(context, request, expedited = true)
        WidgetUpdateScheduler.enqueue(context, request.copy(postedAt = request.postedAt.plusSeconds(1)), expedited = true)
        val infos = WorkManager.getInstance(context).getWorkInfosForUniqueWork(WidgetUpdateScheduler.uniqueWorkName("g1")).get()
        assertEquals(2, infos.size)
        assertTrue(infos.all { WidgetUpdateScheduler.TAG in it.tags })
        assertTrue(infos.any { it.state == WorkInfo.State.ENQUEUED })
        assertTrue(WidgetUpdateScheduler.request(request, expedited = true).workSpec.expedited)
        assertFalse(WidgetUpdateScheduler.request(request, expedited = false).workSpec.expedited)
    }

    @Test fun sizeClassesFollowThePlatformGrid() {
        assertEquals(DpSize(130.dp, 117.dp), WidgetSizeClass.Small.minSize)
        assertEquals(DpSize(276.dp, 117.dp), WidgetSizeClass.Medium.minSize)
        assertEquals(DpSize(276.dp, 249.dp), WidgetSizeClass.Large.minSize)
        assertEquals(3, WidgetSizeClass.breakpoints.size)
        assertEquals(WidgetSizeClass.Small, WidgetSizeClass.of(DpSize(100.dp, 100.dp)))
        assertEquals(WidgetSizeClass.Medium, WidgetSizeClass.of(DpSize(300.dp, 150.dp)))
        assertEquals(WidgetSizeClass.Large, WidgetSizeClass.of(DpSize(300.dp, 300.dp)))
    }

    @Test fun bitmapsAreCroppedToTheWidgetSize() {
        val src = android.graphics.Bitmap.createBitmap(400, 200, android.graphics.Bitmap.Config.ARGB_8888)
        val out = WidgetBitmaps.centerCrop(src, 100, 100)
        assertEquals(100, out.width)
        assertEquals(100, out.height)
    }
}
