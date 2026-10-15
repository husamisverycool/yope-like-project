package app.feature.capture.data

import android.content.Context
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob

/** Process-wide pieces shared by the capture destinations; tests replace [tracker]. */
object CaptureServices {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)

    @Volatile private var trackerInstance: SendTracker? = null

    fun tracker(context: Context): SendTracker = trackerInstance ?: synchronized(this) {
        trackerInstance ?: SendTracker(CaptureDataProvider.get(context), scope).also { trackerInstance = it }
    }

    /** Tests: use [tracker] as the process instance (null resets). */
    fun overrideTracker(tracker: SendTracker?) = synchronized(this) { trackerInstance = tracker }
}
