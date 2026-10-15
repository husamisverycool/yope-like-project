package app.data.integration

import android.content.Context
import android.util.Log
import androidx.work.Configuration
import androidx.work.WorkInfo
import androidx.work.WorkManager
import androidx.work.testing.SynchronousExecutor
import androidx.work.testing.WorkManagerTestInitHelper
import app.data.error.ApiError
import app.data.error.DataError
import app.data.error.DataException
import app.data.media.upload.UploadQueue
import kotlinx.coroutines.delay
import kotlinx.coroutines.withTimeout
import org.junit.Assert.assertEquals
import org.junit.Assert.fail
import java.net.HttpURLConnection
import java.net.URI
import kotlin.time.Duration
import kotlin.time.Duration.Companion.seconds

/** Asserts [block] fails with the RPC error [code] (docs/API.md §3). */
suspend fun expectApi(code: ApiError, block: suspend () -> Unit): DataError.Api {
    val error = expectDataError(block)
    if (error !is DataError.Api || error.code != code) fail("expected api error $code, got $error")
    return error as DataError.Api
}

suspend fun expectDataError(block: suspend () -> Unit): DataError {
    try {
        block()
    } catch (e: DataException) {
        return e.error
    }
    fail("expected a DataException")
    error("unreachable")
}

/** Polls [predicate] until true or [timeout]. */
suspend fun eventually(timeout: Duration = 15.seconds, step: Long = 200, predicate: suspend () -> Boolean) {
    withTimeout(timeout) {
        while (!predicate()) delay(step)
    }
}

fun download(url: String): ByteArray {
    val connection = URI(url).toURL().openConnection() as HttpURLConnection
    return try {
        assertEquals(200, connection.responseCode)
        connection.inputStream.use { it.readBytes() }
    } finally {
        connection.disconnect()
    }
}

/** WorkManager for tests: work runs when the test driver says its constraints are met. */
fun initTestWorkManager(context: Context) {
    WorkManagerTestInitHelper.initializeTestWorkManager(
        context,
        Configuration.Builder().setMinimumLoggingLevel(Log.WARN).setExecutor(SynchronousExecutor()).build(),
    )
}

/** Runs the queued upload of [draftId] (network constraint met) and waits for it to finish. */
suspend fun runUploadWork(context: Context, draftId: String, timeout: Duration = 60.seconds): WorkInfo {
    val workManager = WorkManager.getInstance(context)
    val info = workManager.getWorkInfosForUniqueWork(UploadQueue.workName(draftId)).get().single()
    WorkManagerTestInitHelper.getTestDriver(context)!!.setAllConstraintsMet(info.id)
    var last: WorkInfo? = null
    eventually(timeout, step = 250) {
        last = workManager.getWorkInfoById(info.id).get()
        last!!.state.isFinished
    }
    return last!!
}
