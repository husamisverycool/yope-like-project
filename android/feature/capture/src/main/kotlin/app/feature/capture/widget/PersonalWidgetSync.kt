package app.feature.capture.widget

import android.content.Context
import app.data.repo.WidgetRepository
import app.feature.capture.data.CaptureData
import app.model.WidgetSnapshot
import app.widget.MemoriesWidget
import app.widget.WidgetBinding
import app.widget.WidgetFileStore
import app.widget.WidgetGroupMeta
import app.widget.WidgetSlotStore
import kotlinx.coroutines.CancellationException
import java.io.File
import java.time.LocalDate
import java.time.ZoneId

/**
 * The app's own look-up for the friend and memories widgets (iOS `WidgetContentSync.syncFriends` / `syncMemories`;
 * docs/WIDGET_REFRESH.md "Friend and memories widgets"), run on each return to the foreground ([WidgetPrefetch.refreshPlaced])
 * and when such a widget is placed or set up. Offline or failed look-ups leave the widgets as they are.
 */
object PersonalWidgetSync {

    /**
     * Each followed friend ([people]; default: the placed friend widgets') gets their newest photo the person may see
     * (`newest_photos_of`): their posts and the photos they tagged themselves in. This is how self-tags arrive (tagging
     * sends no push) and how a deleted, hidden or blocked photo leaves. Someone `widget_people` no longer lists (no shared
     * group, a block) shows "not set up"; nothing to show yet, the empty state. [prune] (the foreground call): slots no
     * placed widget follows are dropped — never while a widget is being set up, whose binding is not written yet.
     */
    suspend fun refreshFriends(context: Context, data: CaptureData, people: Set<String>? = null, prune: Boolean = false) {
        val app = context.applicationContext
        val store = WidgetSlotStore.friends(app)
        val followed = people ?: try {
            WidgetBinding.followedPeople(app).also { if (prune) store.retain(it) }
        } catch (e: CancellationException) {
            throw e
        } catch (_: Exception) {
            return
        }
        if (followed.isEmpty()) return
        val listed = data.widgetPeople()?.map { it.userId }?.toSet()
        for (personId in followed) {
            if (listed != null && personId !in listed) {
                if (store.state(personId) != WidgetSlotStore.State.Gone) {
                    store.markGone(personId)
                    rerenderPerson(app, personId)
                }
                continue
            }
            val photos = data.newestPhotosOf(personId) ?: continue
            val photo = photos.firstOrNull { it.widgetPath != null }
            if (photo == null) {
                // Nothing the person may see (yet, or any more); a photo whose rendition is still being made waits.
                if (photos.isEmpty() && store.state(personId) != WidgetSlotStore.State.None) {
                    store.markNone(personId)
                    rerenderPerson(app, personId)
                }
                continue
            }
            if (store.read(personId)?.sourceId == photo.postId) continue
            val snapshot = WidgetSnapshot(
                groupId = photo.groupId,
                groupName = photo.groupName,
                photoFile = PENDING,
                senderName = photo.authorName.ifBlank { null },
                caption = photo.caption,
                kind = WidgetSnapshot.Kind.Photo,
                postedAtEpochMillis = photo.visibleAt.toEpochMilli(),
                sourceId = photo.postId,
            )
            if (fetch(app, data, store, personId, photo.widgetPath!!, snapshot)) rerenderPerson(app, personId)
        }
    }

    /**
     * Today's and the next days' memories (`my_memories`, the device's zone; `WidgetRepository.MEMORY_DAYS`), when a
     * memories widget is placed ([force]: it is being set up). A day without a memory — or whose memory has no widget
     * rendition — is recorded as such (the empty state, never another photo); a failed download keeps what the day had.
     */
    suspend fun refreshMemories(
        context: Context,
        data: CaptureData,
        force: Boolean = false,
        today: LocalDate = LocalDate.now(),
        zone: ZoneId = ZoneId.systemDefault(),
    ) {
        val app = context.applicationContext
        if (!force) {
            val placed = try {
                MemoriesWidget.isPlaced(app)
            } catch (e: CancellationException) {
                throw e
            } catch (_: Exception) {
                false
            }
            if (!placed) return
        }
        val rows = data.myMemories(today, WidgetRepository.MEMORY_DAYS, zone) ?: return
        val store = WidgetSlotStore.memories(app)
        val days = (0 until WidgetRepository.MEMORY_DAYS).map { today.plusDays(it.toLong()) }
        val byDay = rows.associateBy { it.day }
        var changed = false
        for (day in days) {
            val slot = day.toString()
            val row = byDay[day]
            val path = row?.widgetPath
            if (row == null || path == null) {
                if (store.state(slot) != WidgetSlotStore.State.None) {
                    store.markNone(slot)
                    changed = true
                }
                continue
            }
            if (store.read(slot)?.sourceId == row.postId) continue
            val snapshot = WidgetSnapshot(
                groupId = row.groupId,
                groupName = row.groupName,
                photoFile = PENDING,
                senderName = row.authorName.ifBlank { null },
                kind = WidgetSnapshot.Kind.Photo,
                postedAtEpochMillis = row.takenAt.toEpochMilli(),
                sourceId = row.postId,
            )
            if (fetch(app, data, store, slot, path, snapshot)) changed = true
        }
        store.retain(days.map(LocalDate::toString).toSet())
        if (changed) runCatching { MemoriesWidget.refresh(app) }
    }

    /**
     * Writes the premium marker the widgets read (`widget.styles`: a premium style draws Photo without premium) when the
     * entitlement is known, and re-renders every widget when it changed.
     */
    suspend fun refreshPremium(context: Context, data: CaptureData) {
        val premium = data.premiumOrNull() ?: return
        val app = context.applicationContext
        val meta = WidgetGroupMeta.of(WidgetFileStore.default(app))
        if (meta.isPremium() == premium) return
        meta.setPremium(premium)
        runCatching { WidgetBinding.refreshAll(app) }
    }

    /** Downloads [path]'s rendition into [slot]; false when it could not be read or stored (the slot keeps what it had). */
    private suspend fun fetch(context: Context, data: CaptureData, store: WidgetSlotStore, slot: String, path: String, snapshot: WidgetSnapshot): Boolean {
        val tmp = File(context.cacheDir, "widget-slot-$slot.jpg")
        return try {
            val url = data.signedUrls(listOf(path))[path] ?: return false
            data.download(url, tmp)
            store.write(slot, snapshot) { out -> tmp.inputStream().use { it.copyTo(out) } }
            true
        } catch (e: CancellationException) {
            throw e
        } catch (_: Exception) {
            false
        } finally {
            tmp.delete()
        }
    }

    private suspend fun rerenderPerson(context: Context, personId: String) {
        runCatching { WidgetBinding.refreshPerson(context, personId) }
    }

    /** Replaced by the store's own file name on write. */
    private const val PENDING = "pending"
}
