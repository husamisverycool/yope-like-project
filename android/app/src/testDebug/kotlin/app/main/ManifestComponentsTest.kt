package app.main

import android.content.pm.ComponentInfo
import android.content.pm.PackageManager
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith

/**
 * Every component the merged manifest declares (activities, services, receivers, providers — the app's and its modules')
 * names a class that is in the app. A provider whose class is missing crashes every launch before any screen ("Unable
 * to get provider …": the end-to-end journey found `CaptureFileProvider` gone while the capture manifest still declared
 * it), and nothing else in the unit tests starts the app's providers.
 */
@RunWith(AndroidJUnit4::class)
class ManifestComponentsTest {
    @Test fun everyDeclaredComponentClassExists() {
        val context = ApplicationProvider.getApplicationContext<App>()
        @Suppress("DEPRECATION")
        val info = context.packageManager.getPackageInfo(
            context.packageName,
            PackageManager.GET_ACTIVITIES or PackageManager.GET_SERVICES or PackageManager.GET_RECEIVERS or PackageManager.GET_PROVIDERS,
        )
        val components: List<ComponentInfo> = listOfNotNull(info.activities, info.services, info.receivers, info.providers).flatMap { it.toList() }
        assertTrue("the merged manifest declares components", components.isNotEmpty())
        val missing = components.map { it.name }.filter { name ->
            runCatching { Class.forName(name, false, context.classLoader) }.isFailure
        }
        assertTrue("declared in the manifest but not in the app: $missing", missing.isEmpty())
    }
}
