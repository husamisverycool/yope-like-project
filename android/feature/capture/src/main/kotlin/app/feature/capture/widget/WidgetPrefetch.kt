package app.feature.capture.widget

import android.content.Context
import app.data.DataGraph
import app.data.model.Group
import app.feature.capture.data.CaptureData
import app.model.WidgetSnapshot
import app.widget.WidgetBinding
import app.widget.WidgetFileStore
import app.widget.WidgetGroupMeta
import app.widget.WidgetUpdateRequest
import app.widget.WidgetUpdateScheduler
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch

/**
 * Prepares a widget for its newly chosen group so it never waits for the next post:
 * 1. marks the group prepared (the widget shows its loading state at once — `color.global.backgroundDeep`, no
 *    content, `widget.home.small` → States → loading);
 * 2. queues the newest rendition (post or newer collage) through the regular [WidgetUpdateScheduler] path, or
 *    records that the group has no photo yet (the empty state).
 * The widget renders from the store only; nothing here blocks it (provideGlance never touches the network).
 */
object WidgetPrefetch {
    private val fallbackScope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    fun prepare(context: Context, data: CaptureData, group: Group) {
        val app = context.applicationContext
        val meta = WidgetGroupMeta.of(WidgetFileStore.default(app))
        meta.prepare(group.id)
        scope(app).launch(Dispatchers.IO) { fill(app, data, group, meta) }
    }

    /**
     * An All Groups widget (`widget.home.small.layout.allGroups`): every group is prepared and filled, so the widget shows
     * the newest item across them at once. A group already prepared keeps what it shows.
     */
    fun prepareAll(context: Context, data: CaptureData, groups: List<Group>) {
        val app = context.applicationContext
        val meta = WidgetGroupMeta.of(WidgetFileStore.default(app))
        val fresh = groups.filterNot { meta.isPrepared(it.id) }
        fresh.forEach { meta.prepare(it.id) }
        scope(app).launch(Dispatchers.IO) { fresh.forEach { fill(app, data, it, meta) } }
    }

    /** A friend widget set up for [personId]: their newest photo now (the widget shows its loading state meanwhile). */
    fun prepareFriend(context: Context, data: CaptureData, personId: String) {
        val app = context.applicationContext
        scope(app).launch(Dispatchers.IO) { PersonalWidgetSync.refreshFriends(app, data, setOf(personId)) }
    }

    /** A memories widget set up: today's and the coming days' memories now. */
    fun prepareMemories(context: Context, data: CaptureData) {
        val app = context.applicationContext
        scope(app).launch(Dispatchers.IO) { PersonalWidgetSync.refreshMemories(app, data, force = true) }
    }

    /** The first friend or memories widget placed (`PersonalWidgets.onPlaced`): their look-ups now. */
    fun refreshPersonal(context: Context, data: CaptureData) {
        val app = context.applicationContext
        scope(app).launch(Dispatchers.IO) {
            PersonalWidgetSync.refreshFriends(app, data)
            PersonalWidgetSync.refreshMemories(app, data)
        }
    }

    private fun scope(app: Context): CoroutineScope = DataGraph.get(app)?.scope ?: fallbackScope

    /**
     * Every placed widget's group brought up to date from the app itself when it comes to the front (iOS parity:
     * `WidgetContentSync`, docs/WIDGET_REFRESH.md "The app itself"): a group whose newest photo or collage is not the one
     * its widget shows is queued through the regular [WidgetUpdateScheduler] path; a group with nothing left shows its
     * empty state. Offline or unreadable groups are left as they are. While an All Groups widget is placed every group is
     * brought up to date (docs/WIDGET_REFRESH.md "Friend and memories widgets"). The app's own call ([placed] null) then
     * writes the premium marker and looks the followed friends and the memories up ([PersonalWidgetSync]).
     */
    suspend fun refreshPlaced(context: Context, data: CaptureData, placed: Set<String>? = null) {
        val app = context.applicationContext
        val store = WidgetFileStore.default(app)
        val meta = WidgetGroupMeta.of(store)
        if (placed == null) PersonalWidgetSync.refreshPremium(app, data)
        val bound = placed ?: try {
            WidgetBinding.boundGroups(app)
        } catch (_: Exception) {
            return
        }
        val allGroups = placed == null && try {
            WidgetBinding.hasAllGroups(app)
        } catch (_: Exception) {
            false
        }
        val extra = if (allGroups) (data.myGroupIds() ?: emptySet()) - bound else emptySet()
        for (groupId in bound + extra) {
            if (groupId in extra && !meta.isPrepared(groupId)) {
                // A group an All Groups widget has not seen yet (joined since): prepared and filled.
                val group = try {
                    data.group(groupId)
                } catch (_: Exception) {
                    null
                } ?: continue
                meta.prepare(groupId)
                fill(app, data, group, meta)
                continue
            }
            val newest = try {
                data.newestForWidget(groupId)
            } catch (_: Exception) {
                continue
            }
            val shown = store.read(groupId)
            if (newest != null && shown?.sourceId == newest.sourceId) continue
            if (newest == null && shown == null) continue
            // The shown item is gone (nothing left, or the newest is not newer than it: it was deleted or hidden). The
            // store keeps the newest, so it is removed before the older one is written.
            if (shown != null && (newest == null || !newest.postedAt.isAfter(shown.postedAt))) store.remove(groupId)
            val group = try {
                data.group(groupId)
            } catch (_: Exception) {
                null
            } ?: continue
            fill(app, data, group, meta)
        }
        if (placed == null) {
            PersonalWidgetSync.refreshFriends(app, data, prune = true)
            PersonalWidgetSync.refreshMemories(app, data)
        }
    }

    internal suspend fun fill(context: Context, data: CaptureData, group: Group, meta: WidgetGroupMeta) {
        runCatching {
            val newest = data.newestForWidget(group.id)
            if (newest == null) {
                meta.setContent(group.id, WidgetGroupMeta.Content.NoPhotos)
                WidgetBinding.refresh(context, group.id)
                return
            }
            val paths = listOfNotNull(newest.renditionPath, newest.senderAvatarPath)
            val urls = data.signedUrls(paths)
            val rendition = urls[newest.renditionPath] ?: return
            meta.setContent(group.id, WidgetGroupMeta.Content.HasPhotos)
            WidgetUpdateScheduler.enqueue(
                context,
                WidgetUpdateRequest(
                    groupId = group.id,
                    groupName = group.name,
                    renditionUrl = rendition,
                    kind = if (newest.isCollage) WidgetSnapshot.Kind.Collage else WidgetSnapshot.Kind.Photo,
                    postedAt = newest.postedAt,
                    sourceId = newest.sourceId,
                    senderName = newest.senderName,
                    senderAvatarUrl = newest.senderAvatarPath?.let(urls::get),
                    caption = newest.caption,
                ),
                expedited = true,
            )
        }
    }

}
