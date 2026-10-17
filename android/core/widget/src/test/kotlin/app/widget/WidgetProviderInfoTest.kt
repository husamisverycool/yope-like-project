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
 * values (`widget.android.layout.provider`). Friend Updates and Your Memories (`widget.friend`, `widget.memories`) take
 * the same provider as `widget.android`, each with the configuration activity (the person; the style).
 */
@RunWith(AndroidJUnit4::class)
class WidgetProviderInfoTest {
    private val android = "http://schemas.android.com/apk/res/android"
    private val context get() = ApplicationProvider.getApplicationContext<android.content.Context>()

    private fun provider(xml: Int): XmlPullParser {
        val parser = context.resources.getXml(xml)
        while (parser.next() != XmlPullParser.START_TAG || parser.name != "appwidget-provider") Unit
        return parser
    }

    private fun assertWidgetAndroidRules(parser: XmlPullParser) {
        val category = parser.getAttributeIntValue(android, "widgetCategory", 0)
        assertEquals(AppWidgetProviderInfo.WIDGET_CATEGORY_HOME_SCREEN or AppWidgetProviderInfo.WIDGET_CATEGORY_KEYGUARD, category)
        assertTrue(category and AppWidgetProviderInfo.WIDGET_CATEGORY_NOT_KEYGUARD == 0)
        assertEquals(2, parser.getAttributeIntValue(android, "targetCellWidth", 0))
        assertEquals(2, parser.getAttributeIntValue(android, "targetCellHeight", 0))
        assertEquals(3_600_000, parser.getAttributeIntValue(android, "updatePeriodMillis", 0))
    }

    @Test fun providerOptsIntoTheLockScreenAndKeepsItsSizes() {
        assertWidgetAndroidRules(provider(R.xml.group_photo_widget_info))
    }

    @Test fun friendAndMemoriesProvidersFollowTheSameRules() {
        val friend = provider(R.xml.friend_photo_widget_info)
        assertWidgetAndroidRules(friend)
        assertEquals(WidgetConfigureActivity::class.java.name, friend.getAttributeValue(android, "configure"))
        assertEquals(AppWidgetProviderInfo.WIDGET_FEATURE_RECONFIGURABLE, friend.getAttributeIntValue(android, "widgetFeatures", 0))

        val memories = provider(R.xml.memories_widget_info)
        assertWidgetAndroidRules(memories)
        assertEquals(WidgetConfigureActivity::class.java.name, memories.getAttributeValue(android, "configure"))
        // Placed in the free Photo style without asking; the style can be changed later.
        assertEquals(
            AppWidgetProviderInfo.WIDGET_FEATURE_RECONFIGURABLE or AppWidgetProviderInfo.WIDGET_FEATURE_CONFIGURATION_OPTIONAL,
            memories.getAttributeIntValue(android, "widgetFeatures", 0),
        )
    }

    @Test fun eachLayoutNamesItsReceiverAndKind() {
        assertEquals(listOf(WidgetKind.Group, WidgetKind.Friend, WidgetKind.Memories), WidgetLayouts.all.map { it.kind })
        assertEquals(GroupPhotoWidgetReceiver::class.java.name, WidgetLayouts.groupPhoto.receiverClassName)
        assertEquals(FriendPhotoWidgetReceiver::class.java.name, WidgetLayouts.friendPhoto.receiverClassName)
        assertEquals(MemoriesWidgetReceiver::class.java.name, WidgetLayouts.memories.receiverClassName)
        // An unknown widget id is configured as a group widget.
        assertEquals(WidgetKind.Group, WidgetLayouts.kindOf(context, 424242))
    }
}
