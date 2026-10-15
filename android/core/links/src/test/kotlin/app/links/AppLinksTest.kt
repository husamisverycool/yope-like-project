package app.links

import android.app.Activity
import android.content.Intent
import android.net.Uri
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import app.model.DeepLink
import app.model.DeepLinkCodec
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Shadows.shadowOf

@RunWith(AndroidJUnit4::class)
class AppLinksTest {
    private val context = ApplicationProvider.getApplicationContext<android.app.Application>()
    private val codec = DeepLinkCodec("example.org")

    class HostActivity : Activity()

    @After fun reset() {
        DeepLinkIntents.targetActivity = null
    }

    @Test fun parsesViewIntents() {
        assertEquals(DeepLink.Invite("t"), AppLinks.parse(Intent(Intent.ACTION_VIEW, Uri.parse("https://example.org/i/t")), codec))
        assertEquals(DeepLink.Camera("g"), AppLinks.parse(Intent(Intent.ACTION_VIEW, Uri.parse("app://camera?group=g")), codec))
        assertNull(AppLinks.parse(Intent(Intent.ACTION_MAIN, Uri.parse("app://camera?group=g")), codec))
        assertNull(AppLinks.parse(Intent(Intent.ACTION_VIEW), codec))
        assertNull(AppLinks.parse(null, codec))
    }

    @Test fun buildsExplicitIntentsToTheHostActivity() {
        DeepLinkIntents.targetActivity = HostActivity::class.java
        val intent = DeepLinkIntents.intent(context, DeepLink.Post("g", "p"), codec)!!
        assertEquals(HostActivity::class.java.name, intent.component?.className)
        assertEquals(context.packageName, intent.component?.packageName)
        assertEquals("app://post?group=g&post=p", intent.dataString)
        assertTrue(intent.flags and Intent.FLAG_ACTIVITY_SINGLE_TOP != 0)
        assertEquals(DeepLink.Post("g", "p"), AppLinks.parse(intent, codec))
    }

    @Test fun pendingIntentsAreImmutableAndDistinctPerLink() {
        DeepLinkIntents.targetActivity = HostActivity::class.java
        val a = DeepLinkIntents.pendingIntent(context, DeepLink.Camera("a"), codec)
        val b = DeepLinkIntents.pendingIntent(context, DeepLink.Camera("b"), codec)
        assertNotNull(a)
        assertTrue(shadowOf(a).isImmutable)
        assertEquals("app://camera?group=b", shadowOf(b).savedIntent.dataString)
        assertTrue(DeepLinkIntents.requestCode(DeepLink.Camera("a"), codec) != DeepLinkIntents.requestCode(DeepLink.Camera("b"), codec))
    }

    @Test fun noTargetMeansNoIntent() {
        assertNull(DeepLinkIntents.intent(context, DeepLink.Camera("g"), codec))
    }

    @Test fun inviteNeedsDomain() {
        DeepLinkIntents.targetActivity = HostActivity::class.java
        assertNull(DeepLinkIntents.intent(context, DeepLink.Invite("t"), DeepLinkCodec(null)))
    }
}
