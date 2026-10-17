package app.push

import android.content.Context
import androidx.core.content.edit
import app.links.AppLinkConfig
import app.model.DeepLinkCodec
import app.model.PushMessage
import app.widget.WidgetUpdateRequest
import app.widget.WidgetUpdateScheduler
import com.google.firebase.FirebaseApp
import com.google.firebase.messaging.FirebaseMessaging
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withTimeoutOrNull
import java.time.Instant
import kotlin.coroutines.resume

/** Routes one FCM data message. Independent of Firebase, so it is unit-tested directly. */
class PushHandler(
    private val context: Context,
    private val codec: DeepLinkCodec = AppLinkConfig.codec,
    private val now: () -> Instant = Instant::now,
) {
    enum class Outcome { WidgetRefreshQueued, CountdownShown, CountdownEnded, AlertShown, NotShown, Ignored }

    fun handle(data: Map<String, String>): Outcome = when (val message = PushMessage.parse(data, codec)) {
        is PushMessage.WidgetUpdate -> {
            WidgetUpdateScheduler.enqueue(context, WidgetUpdateRequest.from(message), expedited = true)
            Outcome.WidgetRefreshQueued
        }
        is PushMessage.DailyInvitation ->
            if (DailyInvitationNotifier.show(context, message, now())) Outcome.CountdownShown else Outcome.NotShown
        is PushMessage.DailyInvitationEnded -> {
            DailyInvitationNotifier.cancel(context, message.groupId)
            Outcome.CountdownEnded
        }
        is PushMessage.Alert -> if (AlertNotifier.show(context, message, now(), data)) Outcome.AlertShown else Outcome.NotShown
        null -> Outcome.Ignored
    }
}

/** FCM entry point. Firebase is initialised on first use (see [FirebaseBootstrap]). */
class AppMessagingService : FirebaseMessagingService() {
    override fun onCreate() {
        FirebaseBootstrap.ensure(applicationContext)
        super.onCreate()
    }

    override fun onMessageReceived(message: RemoteMessage) {
        val outcome = PushHandler(applicationContext).handle(message.data)
        // The worker sends the widget message when a deletion changes the widget: alerts of photos that are gone leave
        // the shade (DeliveredAlerts). Bounded: FCM gives onMessageReceived a short window.
        if (outcome == PushHandler.Outcome.WidgetRefreshQueued) {
            runBlocking { withTimeoutOrNull(RECONCILE_BUDGET_MS) { DeliveredAlerts.reconcile(applicationContext) } }
        }
    }

    private companion object {
        /**
         * One server lookup, kept short: Firebase, "Receive messages in an Android app" — "For long-running tasks (10 seconds
         * or more) use WorkManager".
         */
        const val RECONCILE_BUDGET_MS = 5_000L
    }

    // Token-based registration matches the worker's FCM HTTP v1 sends to `devices.push_token`
    // (docs/ARCHITECTURE.md). Firebase Messaging 25.1+ deprecates it in favour of opt-in
    // installation-ID registration (onRegistered); switching needs the worker to target FIDs.
    @Suppress("OVERRIDE_DEPRECATION")
    override fun onNewToken(token: String) {
        PushTokens.onNewToken(applicationContext, token)
    }
}

/**
 * Lazy, optional Firebase: `google-services.json` is git-ignored and CI has none, so Firebase is
 * initialised only on first use and only when the build carried its config resources.
 */
object FirebaseBootstrap {
    /** True when Firebase is (now) initialised. */
    @Synchronized
    fun ensure(context: Context): Boolean =
        FirebaseApp.getApps(context).isNotEmpty() || FirebaseApp.initializeApp(context) != null
}

/** Receives device tokens; the API layer implements it (registers the token in `devices`). */
fun interface PushTokenSink {
    fun onToken(token: String)
}

/** Token hand-off between FCM and the API layer. */
object PushTokens {
    private const val PREFS = "push"
    private const val KEY_TOKEN = "fcm_token"

    @Volatile var sink: PushTokenSink? = null

    private val latest = MutableStateFlow<String?>(null)
    val tokens: StateFlow<String?> = latest.asStateFlow()

    fun lastKnown(context: Context): String? =
        latest.value ?: context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString(KEY_TOKEN, null)

    fun onNewToken(context: Context, token: String) {
        if (token.isBlank()) return
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit { putString(KEY_TOKEN, token) }
        latest.value = token
        sink?.onToken(token)
    }

    /**
     * Turns on FCM for this install and returns its token, or null when Firebase is not configured
     * or no token could be fetched. Call after sign-in.
     */
    suspend fun fetch(context: Context): String? {
        if (!FirebaseBootstrap.ensure(context)) return null
        val messaging = FirebaseMessaging.getInstance()
        messaging.isAutoInitEnabled = true
        @Suppress("DEPRECATION") // see AppMessagingService.onNewToken
        val token = suspendCancellableCoroutine { cont ->
            messaging.token.addOnCompleteListener { task -> cont.resume(if (task.isSuccessful) task.result else null) }
        }
        if (token != null && token != lastKnown(context)) onNewToken(context, token)
        return token
    }

    /** On sign-out / account deletion: stop delivery to this install. */
    suspend fun delete(context: Context) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit { remove(KEY_TOKEN) }
        latest.value = null
        if (!FirebaseBootstrap.ensure(context)) return
        val messaging = FirebaseMessaging.getInstance()
        messaging.isAutoInitEnabled = false
        @Suppress("DEPRECATION") // see AppMessagingService.onNewToken
        suspendCancellableCoroutine { cont -> messaging.deleteToken().addOnCompleteListener { cont.resume(Unit) } }
    }
}
