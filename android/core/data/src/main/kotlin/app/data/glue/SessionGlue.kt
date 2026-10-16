package app.data.glue

import android.content.Context
import app.billing.Billing
import app.data.media.SignedUrlCache
import app.data.model.Message
import app.data.model.Post
import app.data.offline.CacheKey
import app.data.offline.OfflineCache
import app.data.realtime.GroupEvent
import app.data.realtime.GroupRealtime
import app.data.repo.AuthRepository
import app.data.repo.AuthState
import app.data.repo.DeviceRepository
import app.data.repo.GroupRepository
import app.data.repo.SettingsRepository
import app.push.PushTokenSink
import app.push.PushTokens
import app.push.QuietHoursSource
import app.widget.WidgetBinding
import app.widget.WidgetFileStore
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.collectLatest
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.flow.filterNotNull
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.merge
import kotlinx.coroutines.launch
import kotlinx.serialization.builtins.ListSerializer

/** FCM token hand-off (core:push `PushTokens`). */
interface PushTokenBridge {
    fun setSink(sink: ((String) -> Unit)?)
    suspend fun fetch(): String?
    fun lastKnown(): String?
    suspend fun delete()
}

/** RevenueCat identity (core:billing `Billing`). */
interface BillingBridge {
    suspend fun identify(userId: String)
    suspend fun reset()
}

/** The widget store (core:widget `WidgetFileStore` + Glance refresh). */
interface WidgetBridge {
    /** Drops widget data of groups not in [groupIds] (left, removed, signed out). */
    suspend fun retainGroups(groupIds: Set<String>)
    /** Clears [groupId]'s widget when it currently shows [sourceId] (a deleted post). */
    suspend fun removeIfShowing(groupId: String, sourceId: String)
}

class FcmPushTokenBridge(private val context: Context) : PushTokenBridge {
    override fun setSink(sink: ((String) -> Unit)?) {
        PushTokens.sink = sink?.let { PushTokenSink(it) }
    }

    override suspend fun fetch(): String? = PushTokens.fetch(context)
    override fun lastKnown(): String? = PushTokens.lastKnown(context)
    override suspend fun delete() = PushTokens.delete(context)
}

object RevenueCatBillingBridge : BillingBridge {
    override suspend fun identify(userId: String) = Billing.identify(userId)
    override suspend fun reset() = Billing.reset()
}

class GlanceWidgetBridge(private val context: Context, private val store: WidgetFileStore = WidgetFileStore.default(context)) : WidgetBridge {
    override suspend fun retainGroups(groupIds: Set<String>) {
        val removed = store.groups() - groupIds
        store.retainGroups(groupIds)
        if (removed.isNotEmpty()) WidgetBinding.refreshAll(context)
    }

    override suspend fun removeIfShowing(groupId: String, sourceId: String) {
        if (store.read(groupId)?.sourceId != sourceId) return
        store.remove(groupId)
        WidgetBinding.refresh(context, groupId)
    }
}

/** The platform pieces the glue talks to; tests pass fakes. */
data class GlueBridges(val push: PushTokenBridge, val billing: BillingBridge, val widgets: WidgetBridge) {
    companion object {
        fun default(context: Context) = GlueBridges(FcmPushTokenBridge(context.applicationContext), RevenueCatBillingBridge, GlanceWidgetBridge(context.applicationContext))
    }
}

/**
 * What happens around a session (docs/API.md §2, §8):
 * - signed in → `Billing.identify(userId)`, FCM token → `register_device` (and on every new token),
 *   quiet hours loaded for the push layer, offline cache switched to that user;
 * - group list changes → `WidgetFileStore.retainGroups`;
 * - `post_deleted` broadcasts (all your groups) → the widget showing that post is cleared;
 * - signing out → `unregister_device` first, then billing reset, token deleted, caches, widgets and the outbox cleared.
 */
class SessionGlue(
    private val auth: AuthRepository,
    private val groups: GroupRepository,
    private val devices: DeviceRepository,
    private val settings: SettingsRepository,
    private val realtime: GroupRealtime,
    private val cache: OfflineCache,
    private val signedUrls: SignedUrlCache,
    private val bridges: GlueBridges,
    private val scope: CoroutineScope,
    /** Empties the outbox when a session ends (the app's: `UploadQueue.discardAll`). */
    private val discardUploads: () -> Unit = {},
) {
    @Volatile private var currentUser: String? = null
    private val jobs = mutableListOf<Job>()

    @OptIn(ExperimentalCoroutinesApi::class)
    fun start() {
        QuietHoursSource.current = QuietHoursSource { settings.quietHours.value }
        auth.addSignOutHook {
            bridges.push.lastKnown()?.let { token -> devices.unregister(token) }
        }
        realtime.addListener(::reconcileCache)
        jobs += scope.launch {
            auth.authState.collect { state ->
                when (state) {
                    is AuthState.SignedIn -> if (state.userId != currentUser) {
                        currentUser = state.userId
                        onSignedIn(state.userId)
                    }
                    AuthState.SignedOut -> {
                        val previous = currentUser
                        currentUser = null
                        onSignedOut(wasSignedIn = previous != null)
                    }
                    AuthState.Initializing -> Unit
                }
            }
        }
        jobs += scope.launch {
            groups.myGroupIds.filterNotNull().distinctUntilChanged().collect { ids -> quietly { bridges.widgets.retainGroups(ids) } }
        }
        jobs += scope.launch {
            groups.myGroupIds.map { it.orEmpty() }.distinctUntilChanged().collectLatest { ids ->
                if (ids.isEmpty()) return@collectLatest
                merge(*ids.map(realtime::deletions).toTypedArray()).collect { event ->
                    if (event is GroupEvent.PostDeleted) quietly { bridges.widgets.removeIfShowing(event.groupId, event.postId) }
                }
            }
        }
    }

    fun stop() {
        jobs.forEach { it.cancel() }
        jobs.clear()
    }

    private suspend fun onSignedIn(userId: String) {
        cache.setUser(userId)
        quietly { bridges.billing.identify(userId) }
        bridges.push.setSink { token -> scope.launch { quietly { devices.register(token) } } }
        quietly {
            val token = bridges.push.fetch() ?: bridges.push.lastKnown()
            if (token != null) devices.register(token)
        }
        quietly { settings.notificationSettings() }
    }

    private suspend fun onSignedOut(wasSignedIn: Boolean) {
        cache.setUser(null)
        groups.reset()
        settings.reset()
        if (!wasSignedIn) return
        bridges.push.setSink(null)
        quietly { bridges.billing.reset() }
        quietly { bridges.push.delete() }
        quietly { cache.clearAll() }
        quietly { signedUrls.clear() }
        quietly { bridges.widgets.retainGroups(emptySet()) }
        quietly { discardUploads() }
    }

    /** Keeps the cached pages in line with live events, so an offline render shows no deleted content. */
    internal suspend fun reconcileCache(event: GroupEvent) {
        val posts = ListSerializer(Post.serializer())
        val messages = ListSerializer(Message.serializer())
        when (event) {
            is GroupEvent.PostDeleted -> {
                cache.update(CacheKey.feed(event.groupId), posts) { list -> list.filterNot { it.id == event.postId } }
                cache.update(CacheKey.chat(event.groupId), messages) { list -> list.filterNot { it.postId == event.postId } }
            }
            is GroupEvent.MessageDeleted -> cache.update(CacheKey.chat(event.groupId), messages) { list -> list.filterNot { it.id == event.messageId } }
            is GroupEvent.PostInserted -> cache.update(CacheKey.feed(event.groupId), posts) { list ->
                if (list.any { it.id == event.post.id }) list else (listOf(event.post) + list).sortedByDescending { it.createdAt }
            }
            is GroupEvent.PostUpdated -> cache.update(CacheKey.feed(event.groupId), posts) { list -> list.map { if (it.id == event.post.id) event.post else it } }
            is GroupEvent.MessageInserted -> cache.update(CacheKey.chat(event.groupId), messages) { list ->
                if (list.any { it.id == event.message.id }) list else (listOf(event.message) + list).sortedByDescending { it.createdAt }
            }
            is GroupEvent.MessageUpdated -> cache.update(CacheKey.chat(event.groupId), messages) { list -> list.map { if (it.id == event.message.id) event.message else it } }
            else -> Unit
        }
    }

    private inline fun quietly(block: () -> Unit) {
        try {
            block()
        } catch (e: CancellationException) {
            throw e
        } catch (_: Exception) {
            // Best effort: the next sign-in / token refresh / group load repeats it.
        }
    }
}
