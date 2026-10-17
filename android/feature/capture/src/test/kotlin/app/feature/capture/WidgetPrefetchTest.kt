package app.feature.capture

import android.app.Application
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.work.WorkInfo
import androidx.work.WorkManager
import androidx.work.testing.WorkManagerTestInitHelper
import app.feature.capture.data.NewestForWidget
import app.feature.capture.widget.WidgetPrefetch
import app.model.WidgetSnapshot
import app.widget.WidgetFileStore
import app.widget.WidgetUpdateScheduler
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith

/**
 * The app itself brings each placed widget's group up to date when it starts (iOS parity: `WidgetContentSync`,
 * docs/WIDGET_REFRESH.md "The app itself").
 */
@RunWith(AndroidJUnit4::class)
class WidgetPrefetchTest {
    private val app = ApplicationProvider.getApplicationContext<Application>()
    private val store get() = WidgetFileStore.default(app)
    private val data = FakeCaptureData().apply { groupById["g1"] = group("g1", "Lima family") }

    @Before fun setUp() {
        WorkManagerTestInitHelper.initializeTestWorkManager(app)
        store.remove("g1")
    }

    private fun show(source: String, postedAt: java.time.Instant) = store.write(
        WidgetFileStore.Incoming("g1", "Lima family", WidgetSnapshot.Kind.Photo, postedAt, source, null, null),
        writePhoto = { it.write(byteArrayOf(1, 2, 3)) },
    )

    private fun newest(source: String, postedAt: java.time.Instant) =
        NewestForWidget("u/u1/$source/r/widget.jpg", isCollage = false, sourceId = source, postedAt = postedAt, senderName = "Rui", senderAvatarPath = null, caption = null)

    private fun queued(): List<WorkInfo> =
        WorkManager.getInstance(app).getWorkInfosForUniqueWork(WidgetUpdateScheduler.uniqueWorkName("g1")).get()

    @Test fun aWidgetAlreadyShowingTheNewestIsLeftAlone() = runBlocking {
        show("p1", T0)
        data.newest = newest("p1", T0)
        WidgetPrefetch.refreshPlaced(app, data, placed = setOf("g1"))
        assertTrue(queued().isEmpty())
    }

    @Test fun aNewerPhotoIsQueued() = runBlocking {
        show("p1", T0)
        data.newest = newest("p2", T0.plusSeconds(60))
        WidgetPrefetch.refreshPlaced(app, data, placed = setOf("g1"))
        assertEquals(1, queued().size)
        assertEquals("p1", store.read("g1")?.sourceId, "kept until the download replaces it")
    }

    @Test fun aDeletedShownPhotoMakesWayForTheOlderNewest() = runBlocking {
        show("p2", T0.plusSeconds(60))
        data.newest = newest("p1", T0)
        WidgetPrefetch.refreshPlaced(app, data, placed = setOf("g1"))
        assertNull(store.read("g1"))
        assertEquals(1, queued().size)
    }

    @Test fun nothingLeftEmptiesTheWidget() = runBlocking {
        show("p1", T0)
        data.newest = null
        WidgetPrefetch.refreshPlaced(app, data, placed = setOf("g1"))
        assertNull(store.read("g1"))
        assertTrue(queued().isEmpty())
    }

    private fun assertEquals(expected: Any?, actual: Any?, message: String) = org.junit.Assert.assertEquals(message, expected, actual)
}
