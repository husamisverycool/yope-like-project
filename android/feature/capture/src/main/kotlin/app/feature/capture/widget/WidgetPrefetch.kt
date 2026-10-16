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
        val scope = DataGraph.get(app)?.scope ?: fallbackScope
        scope.launch(Dispatchers.IO) { fill(app, data, group, meta) }
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
