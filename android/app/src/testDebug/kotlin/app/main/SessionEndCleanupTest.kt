package app.main

import android.content.Context
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import app.data.model.MediaKind
import app.data.model.RenderStatus
import app.data.model.WeeklyRecap
import app.data.repo.AuthState
import app.feature.capture.data.CaptureHandoff
import app.feature.capture.data.CapturedMedia
import app.feature.social.week.RecapEdits
import app.voice.voiceCacheDirectory
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import java.io.File
import java.time.Instant
import java.time.LocalDate

/**
 * The next person on the device finds nothing of the previous one's: when a signed-in session ends, the capture waiting
 * for send-to, the capture folder, voice recordings and unsaved recap edits are gone (the end-to-end sign-out audit).
 */
@RunWith(AndroidJUnit4::class)
class SessionEndCleanupTest {
    private val context: Context = ApplicationProvider.getApplicationContext()

    private fun leaveStateBehind(): Pair<File, File> {
        val photo = File(CaptureHandoff.dir(context), "last.jpg").apply { writeText("photo") }
        CaptureHandoff.process.put(CapturedMedia(MediaKind.Photo, photo, 3, 4, null, fromLibrary = false), contextGroupId = "g1")
        val voice = File(voiceCacheDirectory(context).apply { mkdirs() }, "draft.m4a").apply { writeText("voice") }
        val now = Instant.parse("2026-10-16T10:00:00Z")
        RecapEdits.set(WeeklyRecap("r1", "g1", LocalDate.parse("2026-10-12"), listOf("p1"), "Our week", RenderStatus.Ready, now, "u1", now, now))
        return photo to voice
    }

    @Test fun runEmptiesCaptureVoiceAndRecapEdits() {
        val (photo, voice) = leaveStateBehind()
        SessionEndCleanup.run(context)
        assertNull(CaptureHandoff.process.pending.value)
        assertFalse(photo.exists())
        assertFalse(voice.exists())
        assertTrue(CaptureHandoff.dir(context).listFiles().isNullOrEmpty())
        assertEquals(emptyMap<String, WeeklyRecap>(), RecapEdits.pending.value)
    }

    @Test fun onlyAnEndedSessionClears() {
        val auth = MutableStateFlow<AuthState>(AuthState.Initializing)
        // Unconfined: each new auth state reaches the collector before the assignment returns.
        val scope = CoroutineScope(Dispatchers.Unconfined)
        val job = SessionEndCleanup.start(context, auth, scope)
        try {
            val (photo, _) = leaveStateBehind()
            auth.value = AuthState.SignedOut // launch while signed out: nothing of anyone's to clear
            assertTrue(photo.exists())
            auth.value = AuthState.SignedIn("u1")
            assertTrue(photo.exists())
            auth.value = AuthState.SignedOut
            assertFalse(photo.exists())
            assertNull(CaptureHandoff.process.pending.value)
            assertEquals(emptyMap<String, WeeklyRecap>(), RecapEdits.pending.value)
        } finally {
            job.cancel()
            SessionEndCleanup.run(context)
        }
    }
}
