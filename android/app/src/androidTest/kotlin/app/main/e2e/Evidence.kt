package app.main.e2e

import android.content.ContentValues
import android.graphics.Bitmap
import android.os.Build
import android.os.Environment
import android.os.SystemClock
import android.provider.MediaStore
import android.util.Log
import androidx.compose.ui.test.isRoot
import androidx.compose.ui.test.junit4.ComposeTestRule
import androidx.compose.ui.test.printToString
import androidx.test.platform.app.InstrumentationRegistry
import java.io.File
import java.io.OutputStream

/**
 * What each step of the journey leaves behind for the CI artifact: a screenshot of the whole display (UiAutomation, so
 * system dialogs and toasts are in it) and the Compose semantics tree of every window (the labels and roles TalkBack
 * reads), as `<nn>-<step>.png` / `.txt` in the shared Downloads collection under `e2e/`. Downloads outlive the app's
 * uninstall at the end of `connectedAndroidTest`; the CI script pulls `/sdcard/Download/e2e`.
 */
class Evidence(private val compose: ComposeTestRule) {
    private var index = 0

    fun step(name: String) {
        runCatching { compose.waitForIdle() }
        settle()
        index += 1
        val base = "%02d-%s".format(index, name)
        Log.i(E2eRunner.TAG, "step $base")
        capture(base)
    }

    /**
     * Lets the display catch up with the composition before the screenshot: the semantics are current after `waitForIdle`,
     * but the frame that draws them reaches the screen on a later vsync (a screenshot taken at once showed the previous
     * screen).
     */
    private fun settle() {
        runCatching { InstrumentationRegistry.getInstrumentation().waitForIdleSync() }
        SystemClock.sleep(SETTLE_MS)
    }

    /** The failure's state (called by the test's watcher while the activity is still up). */
    fun failure(testName: String) = capture("failure-$testName")

    private fun capture(base: String) {
        runCatching {
            val bitmap = InstrumentationRegistry.getInstrumentation().uiAutomation.takeScreenshot()
            if (bitmap != null) write("$base.png", "image/png") { bitmap.compress(Bitmap.CompressFormat.PNG, PNG_QUALITY, it) }
        }.onFailure { Log.w(E2eRunner.TAG, "screenshot $base failed", it) }
        runCatching {
            val tree = semantics()
            write("$base.txt", "text/plain") { it.write(tree.toByteArray()) }
        }.onFailure { Log.w(E2eRunner.TAG, "semantics dump $base failed", it) }
    }

    /** Every Compose root (the activity, dialogs, popups, menus), unmerged: each node's text, description, tag, actions. */
    fun semantics(): String = buildString {
        val roots = compose.onAllNodes(isRoot(), useUnmergedTree = true)
        val count = roots.fetchSemanticsNodes(atLeastOneRootRequired = false).size
        for (i in 0 until count) {
            append("== root ").append(i).append('\n')
            append(runCatching { roots[i].printToString(maxDepth = Int.MAX_VALUE) }.getOrElse { "(unreadable: $it)" })
            append('\n')
        }
    }

    private fun write(name: String, mime: String, body: (OutputStream) -> Unit) {
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val values = ContentValues().apply {
                put(MediaStore.MediaColumns.DISPLAY_NAME, name)
                put(MediaStore.MediaColumns.MIME_TYPE, mime)
                put(MediaStore.MediaColumns.RELATIVE_PATH, "${Environment.DIRECTORY_DOWNLOADS}/$FOLDER")
            }
            val resolver = context.contentResolver
            val uri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values) ?: error("MediaStore refused $name")
            resolver.openOutputStream(uri)?.use(body) ?: error("no stream for $name")
        } else {
            val dir = File(context.getExternalFilesDir(null), FOLDER).apply { mkdirs() }
            File(dir, name).outputStream().use(body)
        }
    }

    private companion object {
        const val FOLDER = "e2e"
        const val PNG_QUALITY = 100
        /** A few frames at 60 Hz plus the compositor's latency. */
        const val SETTLE_MS = 500L
    }
}
