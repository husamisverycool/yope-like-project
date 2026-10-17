// Surface: share.in — "Share to Jolt" from other apps (design/surfaces/share.in.md; docs/RESEARCH_FEATURES_2026-10-17.md
// #4). Mechanics: Android "Receiving simple data from other apps" (developer.android.com/training/sharing/receive):
// ACTION_SEND / ACTION_SEND_MULTIPLE with image/* and video/* (the app's AndroidManifest), EXTRA_STREAM content URIs read
// at once (the read grant lasts while the receiving activity's task lives). The items are copied into the capture
// directory with the day each was taken, then wait in [ShareInbox]; once the person is home (signed in and onboarded) the
// camera takes them as a library selection — the trimmer for long videos, then camera.sendto (several photos in one post).
// A share through one of the share sheet's per-group targets ([ShareTargets]) carries EXTRA_SHORTCUT_ID: that group waits
// with the items and send-to opens with it preselected.
package app.feature.capture.share

import android.content.ContentResolver
import android.content.Context
import android.content.Intent
import android.net.Uri
import androidx.core.content.IntentCompat
import androidx.core.content.pm.ShortcutManagerCompat
import androidx.navigation.NavDestination
import androidx.navigation.NavDestination.Companion.hasRoute
import app.feature.capture.data.CaptureDataProvider
import app.feature.capture.data.PickedFile
import app.feature.capture.data.importPicked
import app.model.AppRoute
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

/** Shared items copied and waiting for the camera (one share at a time: a new share replaces one still waiting). */
object ShareInbox {
    /** A share as the camera takes it: the items in the order shared, and the group picked in the share sheet (or null). */
    data class Share(val items: List<PickedFile>, val groupId: String?)

    private val state = MutableStateFlow<List<PickedFile>?>(null)
    val pending: StateFlow<List<PickedFile>?> = state.asStateFlow()

    /** The group of the waiting items (set before them, so a reader of [pending] finds both). */
    @Volatile private var groupId: String? = null

    @Synchronized
    fun put(items: List<PickedFile>, groupId: String? = null) {
        if (items.isEmpty()) return
        val kept = items.map { it.file }.toSet()
        state.value?.forEach { old -> if (old.file !in kept) old.file.delete() }
        this.groupId = groupId
        state.value = items
    }

    /** The waiting items, once; null when none. */
    fun take(): List<PickedFile>? = takeShare()?.items

    /** The waiting items with the group picked in the share sheet, once; null when none. */
    @Synchronized
    fun takeShare(): Share? {
        val items = state.value ?: return null
        val group = groupId
        state.value = null
        groupId = null
        return Share(items, group)
    }
}

object ShareIn {
    /** Copies outlive the activity (a rotation while copying): the process's scope. */
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    fun isShare(intent: Intent?): Boolean = intent?.action == Intent.ACTION_SEND || intent?.action == Intent.ACTION_SEND_MULTIPLE

    /**
     * The shared streams, in the order shared: `EXTRA_STREAM` (one for ACTION_SEND, a list for ACTION_SEND_MULTIPLE), else
     * the intent's clip. Only `content://` URIs of other apps are taken — never a `file://` path, and never one of this
     * app's own providers (a crafted share must not make the app post its own private files).
     */
    fun uris(intent: Intent, ownPackage: String): List<Uri> {
        val streams = when (intent.action) {
            Intent.ACTION_SEND -> listOfNotNull(IntentCompat.getParcelableExtra(intent, Intent.EXTRA_STREAM, Uri::class.java))
            Intent.ACTION_SEND_MULTIPLE -> IntentCompat.getParcelableArrayListExtra(intent, Intent.EXTRA_STREAM, Uri::class.java).orEmpty().filterNotNull()
            else -> emptyList()
        }
        val clip = intent.clipData?.let { data -> (0 until data.itemCount).mapNotNull { data.getItemAt(it).uri } }.orEmpty()
        return streams.ifEmpty { clip }.filter { isAcceptable(it, ownPackage) }.distinct()
    }

    /** The group of the share sheet's per-group target the person picked ([ShareTargets]); null when the app itself was. */
    fun groupId(intent: Intent): String? = ShareTargets.groupIdOf(intent.getStringExtra(ShortcutManagerCompat.EXTRA_SHORTCUT_ID))

    fun isAcceptable(uri: Uri, ownPackage: String): Boolean {
        if (uri.scheme != ContentResolver.SCHEME_CONTENT) return false
        val authority = uri.authority ?: return false
        return authority != ownPackage && !authority.startsWith("$ownPackage.")
    }

    /**
     * Copies the shared photos and videos (at most `batch_max_photos`; one while it is unknown) and puts them in the
     * [ShareInbox]. Other types are left out.
     */
    fun receive(context: Context, intent: Intent) {
        val uris = uris(intent, context.packageName)
        if (uris.isEmpty()) return
        val type = intent.type
        val groupId = groupId(intent)
        val app = context.applicationContext
        scope.launch {
            val limit = runCatching { CaptureDataProvider.get(app).batchMaxPhotos() }.getOrNull()?.takeIf { it > 0 } ?: 1
            val picked = uris.take(limit).mapIndexedNotNull { index, uri ->
                importPicked(app, uri, index, fallbackType = type?.takeIf { it.startsWith("image/") || it.startsWith("video/") }, imagesAndVideosOnly = true)
            }
            ShareInbox.put(picked, groupId)
        }
    }

    /**
     * Whether the app shell should open the camera for waiting shared items now: not before the person is home (sign-up,
     * onboarding, an invite being joined: those come first), and not over the camera or its send-to (the camera takes
     * them itself once its composer is closed).
     */
    fun opensCameraFrom(destination: NavDestination?): Boolean {
        if (destination == null) return false
        val waits = destination.hasRoute<AppRoute.AuthPhone>() || destination.hasRoute<AppRoute.AuthCode>() ||
            destination.hasRoute<AppRoute.AuthAgeGate>() || destination.hasRoute<AppRoute.AuthProfile>() ||
            destination.hasRoute<AppRoute.PermissionCamera>() || destination.hasRoute<AppRoute.PermissionNotifications>() ||
            destination.hasRoute<AppRoute.PermissionPhotos>() || destination.hasRoute<AppRoute.PermissionContacts>() ||
            destination.hasRoute<AppRoute.OnboardingWidget>() || destination.hasRoute<AppRoute.InviteJoin>() ||
            destination.hasRoute<AppRoute.Camera>() || destination.hasRoute<AppRoute.SendTo>()
        return !waits
    }
}
