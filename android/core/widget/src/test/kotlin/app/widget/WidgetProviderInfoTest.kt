package app.widget

import android.appwidget.AppWidgetProviderInfo
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.xmlpull.v1.XmlPullParser

/**
 * The provider metadata (`res/xml/group_photo_widget_info.xml`): owner decision 18 — the widget opts into the
 * lock-screen category (`widget.android.layout.lockScreen`: `home_screen|keyguard`) and keeps Retro's provider
 * values (`widget.android.layout.provider`).
 */
@RunWith(AndroidJUnit4::class)
class WidgetProviderInfoTest {
    private val android = "http://schemas.android.com/apk/res/android"

    @Test fun providerOptsIntoTheLockScreenAndKeepsItsSizes() {
        val context = ApplicationProvider.getApplicationContext<android.content.Context>()
        val parser = context.resources.getXml(R.xml.group_photo_widget_info)
        while (parser.next() != XmlPullParser.START_TAG || parser.name != "appwidget-provider") Unit
        val category = parser.getAttributeIntValue(android, "widgetCategory", 0)
        assertEquals(AppWidgetProviderInfo.WIDGET_CATEGORY_HOME_SCREEN or AppWidgetProviderInfo.WIDGET_CATEGORY_KEYGUARD, category)
        assertTrue(category and AppWidgetProviderInfo.WIDGET_CATEGORY_NOT_KEYGUARD == 0)
        assertEquals(2, parser.getAttributeIntValue(android, "targetCellWidth", 0))
        assertEquals(2, parser.getAttributeIntValue(android, "targetCellHeight", 0))
        assertEquals(3_600_000, parser.getAttributeIntValue(android, "updatePeriodMillis", 0))
    }
}
