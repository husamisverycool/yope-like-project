package app.widget

import android.appwidget.AppWidgetProviderInfo
import android.content.Context
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import app.model.CountdownPlan
import app.model.CountdownSnapshot
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.xmlpull.v1.XmlPullParser
import java.util.Locale

/**
 * The countdown widget's day words, store and provider (`widget.countdown`). The day words are the platform formatter's
 * output; this test pins them in en-US — including the same-day word, which design/MERGE_DECISIONS.md PL-10 keeps
 * BLOCKED "until a snapshot test pins it".
 */
@RunWith(AndroidJUnit4::class)
class CountdownWidgetTest {
    private val context: Context get() = ApplicationProvider.getApplicationContext()
    private val store get() = CountdownStore.default(context)

    @Before fun setUp() = store.clear()

    @Test fun dayWordsComeFromThePlatformFormatterAtDayGranularity() {
        assertEquals("Today", CountdownWords.text(0, Locale.US))
        assertEquals("Tomorrow", CountdownWords.text(1, Locale.US))
        assertEquals("In 2 days", CountdownWords.text(2, Locale.US))
        assertEquals("In 9 days", CountdownWords.text(9, Locale.US))
        assertEquals("In 400 days", CountdownWords.text(400, Locale.US))
        assertNull(CountdownWords.text(-1, Locale.US))
        // Another locale writes its own words (sentence case at the start).
        assertEquals("Mañana", CountdownWords.text(1, Locale.forLanguageTag("es-ES")))
        // Inside the TalkBack sentence ("{title} with {group}, {countdown}").
        assertEquals("tomorrow", CountdownWords.text(1, Locale.US, inSentence = true))
        assertEquals("in 2 days", CountdownWords.text(2, Locale.US, inSentence = true))
    }

    @Test fun theStoreKeepsOnlyTheCoversItsSnapshotNames() {
        val cover = CountdownStore.coverName("u/a/covers/x.jpg")
        assertTrue(cover.startsWith("c-") && cover.endsWith(".jpg"))
        assertEquals(cover, CountdownStore.coverName("u/a/covers/x.jpg"))
        store.writeCover(cover, byteArrayOf(1, 2, 3))
        store.writeCover("c-old.jpg", byteArrayOf(4))
        val plan = CountdownPlan("p1", "g1", "Sunday Dinners", "Picnic", "2026-10-24", cover)
        store.write(CountdownSnapshot(listOf(plan, plan.copy(planId = "p2", coverFile = null)), 1))
        assertEquals(listOf("p1", "p2"), store.read()?.plans?.map { it.planId })
        assertTrue(store.hasCover(cover))
        assertFalse("pruned", store.hasCover("c-old.jpg"))
        assertEquals(3L, store.cover(plan)?.length())
        assertNull(store.cover(plan.copy(coverFile = null)))
        store.clear()
        assertNull(store.read())
    }

    @Test fun emptyStatesFollowTheSessionAndTheSnapshot() {
        assertEquals(CountdownEmptyState.SignedOut, CountdownEmptyState.of(null, signedOut = true))
        assertEquals(CountdownEmptyState.Loading, CountdownEmptyState.of(null, signedOut = false))
        assertEquals(CountdownEmptyState.NoPlans, CountdownEmptyState.of(CountdownSnapshot(emptyList(), 0), signedOut = false))
    }

    @Test fun theProviderKeepsTheWidgetRules() {
        val android = "http://schemas.android.com/apk/res/android"
        val parser = context.resources.getXml(R.xml.countdown_widget_info)
        while (parser.next() != XmlPullParser.START_TAG || parser.name != "appwidget-provider") Unit
        assertEquals(AppWidgetProviderInfo.WIDGET_CATEGORY_HOME_SCREEN or AppWidgetProviderInfo.WIDGET_CATEGORY_KEYGUARD, parser.getAttributeIntValue(android, "widgetCategory", 0))
        assertEquals(2, parser.getAttributeIntValue(android, "targetCellWidth", 0))
        assertEquals(2, parser.getAttributeIntValue(android, "targetCellHeight", 0))
        assertEquals(3_600_000, parser.getAttributeIntValue(android, "updatePeriodMillis", 0))
        assertNull("no configuration activity: All groups", parser.getAttributeValue(android, "configure"))
    }
}
