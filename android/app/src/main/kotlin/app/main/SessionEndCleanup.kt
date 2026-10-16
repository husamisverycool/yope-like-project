package app.main

import android.content.Context
import app.data.repo.AuthState
import app.feature.capture.data.CaptureHandoff
import app.feature.social.week.RecapEdits
import app.voice.voiceCacheDirectory
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.launch
import java.io.File

/**
 * When a signed-in session ends (sign-out, account deletion, expiry), the per-person state the feature modules keep
 * outside the data layer goes with it: the capture waiting for `camera.sendto` and the capture folder, voice
 * recordings and drafts in the cache, and recap edits not yet saved. The data layer clears its own caches, widgets and
 * outbox (SessionGlue); the account screens theirs (AccountFlow.sessionEnded).
 */
internal object SessionEndCleanup {
    fun start(context: Context, authState: Flow<AuthState>, scope: CoroutineScope): Job = scope.launch {
        var signedIn = false
        authState.collect { state ->
            when (state) {
                is AuthState.SignedIn -> signedIn = true
                AuthState.SignedOut -> {
                    if (signedIn) run(context)
                    signedIn = false
                }
                AuthState.Initializing -> Unit
            }
        }
    }

    fun run(context: Context) {
        CaptureHandoff.process.discard()
        emptyDirectory(CaptureHandoff.dir(context))
        emptyDirectory(voiceCacheDirectory(context))
        RecapEdits.pending.value = emptyMap()
    }

    private fun emptyDirectory(dir: File) {
        dir.listFiles()?.forEach { it.deleteRecursively() }
    }
}
