// Surfaces: widget.friend (Friend Updates: one person's newest photo) and widget.memories (Your Memories: your own photo
// from this day in an earlier year), Android form widget.android (Glance, every size), each in the styles of
// widget.styles. Specs: design/surfaces/widget.friend.md, widget.memories.md, widget.styles.md.
// Visual reference: Retro's Friend Updates and Your Memories Glance widgets — the same anatomy as its Albums widget
// (references/auto/retro/apk/widget_preview_friends.webp, widget_preview_memories.webp: full-bleed photo, white name over
// place at the bottom-trailing corner). Mechanics: Locket's one-friend widget (references/auto/locket/frames/
// locket-tt-7532209311150329102-14.500s-gallery-best-friend-widget.jpg); Retro's "time hop back to your own memories".
package app.widget

import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.datastore.preferences.core.Preferences
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.Image
import androidx.glance.ImageProvider
import androidx.glance.LocalContext
import androidx.glance.LocalSize
import androidx.glance.action.clickable
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.GlanceAppWidgetManager
import androidx.glance.appwidget.GlanceAppWidgetReceiver
import androidx.glance.appwidget.SizeMode
import androidx.glance.appwidget.appWidgetBackground
import androidx.glance.appwidget.cornerRadius
import androidx.glance.appwidget.provideContent
import androidx.glance.currentState
import androidx.glance.layout.Box
import androidx.glance.layout.ContentScale
import androidx.glance.layout.fillMaxSize
import androidx.glance.semantics.contentDescription
import androidx.glance.semantics.semantics
import androidx.glance.state.PreferencesGlanceStateDefinition
import androidx.work.CoroutineWorker
import androidx.work.ExistingWorkPolicy
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.WorkerParameters
import app.designsystem.R
import app.designsystem.generated.Tokens
import app.model.WidgetSnapshot
import app.model.WidgetStyle
import java.io.File
import java.time.Duration
import java.time.LocalDate
import java.time.ZonedDateTime
import java.util.concurrent.TimeUnit
import kotlin.math.roundToInt

/**
 * Set by the app at process start (feature:capture, which reads the server; this module cannot): looks the followed friends
 * and the coming days' memories up now — called when the first friend or memories widget is placed, so it does not wait
 * for the app's next foreground (docs/WIDGET_REFRESH.md "Friend and memories widgets").
 */
object PersonalWidgets {
    @Volatile var onPlaced: () -> Unit = {}

    /** The device's date (the memories turn over at local midnight); replaceable in tests. */
    @Volatile var today: () -> LocalDate = { LocalDate.now() }
}

/**
 * Friend Updates (`widget.friend`): the newest photo of the person the widget follows (`WidgetBinding.PERSON_ID`) that the
 * viewer may see — their posts and the photos they tagged themselves in ("I'm in this"), never by face — from
 * [WidgetSlotStore.friends]. The stack: the poster's first name over the group. Tap: the camera with the photo's group
 * (`camera.fromwidget`); no photo yet: the camera; not set up: the configuration.
 */
class FriendPhotoWidget : GlanceAppWidget() {
    override val sizeMode: SizeMode = SizeMode.Responsive(WidgetSizeClass.breakpoints)
    override val stateDefinition = PreferencesGlanceStateDefinition

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        val store = WidgetSlotStore.friends(context)
        val appWidgetId = GlanceAppWidgetManager(context).getAppWidgetId(id)
        provideContent {
            val state = currentState<Preferences>()
            FriendWidgetContent(
                store = store,
                personId = state[WidgetBinding.PERSON_ID],
                style = WidgetStyle.fromWire(state[WidgetBinding.STYLE]),
                revision = state[WidgetBinding.REVISION] ?: 0L,
                appWidgetId = appWidgetId,
            )
        }
    }
}

class FriendPhotoWidgetReceiver : GlanceAppWidgetReceiver() {
    override val glanceAppWidget: GlanceAppWidget = FriendPhotoWidget()

    override fun onEnabled(context: Context) {
        super.onEnabled(context)
        PersonalWidgets.onPlaced()
    }
}

/**
 * Your Memories (`widget.memories`): today's memory — the person's own photo (posted or self-tagged) from this month and
 * day in an earlier year — from [WidgetSlotStore.memories] (one slot per day, filled by the app for today and the next 6
 * days). The stack: the poster's first name over the group. Tap: the memory in the photo viewer; without one, the app.
 */
class MemoriesWidget : GlanceAppWidget() {
    override val sizeMode: SizeMode = SizeMode.Responsive(WidgetSizeClass.breakpoints)
    override val stateDefinition = PreferencesGlanceStateDefinition

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        val store = WidgetSlotStore.memories(context)
        val appWidgetId = GlanceAppWidgetManager(context).getAppWidgetId(id)
        provideContent {
            val state = currentState<Preferences>()
            MemoriesWidgetContent(
                store = store,
                day = PersonalWidgets.today(),
                style = WidgetStyle.fromWire(state[WidgetBinding.STYLE]),
                revision = state[WidgetBinding.REVISION] ?: 0L,
                appWidgetId = appWidgetId,
            )
        }
    }

    companion object {
        /** Whether a memories widget is on a home screen (the app looks the memories up only then). */
        suspend fun isPlaced(context: Context): Boolean =
            GlanceAppWidgetManager(context).getGlanceIds(MemoriesWidget::class.java).isNotEmpty()

        /** Re-renders every placed memories widget and keeps the midnight turn-over scheduled. */
        suspend fun refresh(context: Context) {
            WidgetBinding.refreshLayout(context, WidgetLayouts.memories)
            MemoriesMidnight.schedule(context)
        }
    }
}

class MemoriesWidgetReceiver : GlanceAppWidgetReceiver() {
    override val glanceAppWidget: GlanceAppWidget = MemoriesWidget()

    override fun onEnabled(context: Context) {
        super.onEnabled(context)
        MemoriesMidnight.schedule(context)
        PersonalWidgets.onPlaced()
    }

    override fun onDisabled(context: Context) {
        super.onDisabled(context)
        MemoriesMidnight.cancel(context)
    }

    /** The clock or the zone changed (exempt from the implicit-broadcast limits): the day may have changed. */
    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action in CLOCK_ACTIONS) MemoriesMidnight.enqueueNow(context)
    }

    private companion object {
        val CLOCK_ACTIONS = setOf(Intent.ACTION_TIME_CHANGED, Intent.ACTION_TIMEZONE_CHANGED)
    }
}

/**
 * The memory changes at local midnight only (`widget.memories` → Motion: a re-render at midnight, instantly): one WorkManager
 * job at the next local midnight re-renders the memories widgets from the stored days and schedules the following one, as
 * the countdown widget's (`CountdownMidnight`); `widget.android.duration.updatePeriod` is the provider's backstop.
 */
object MemoriesMidnight {
    private const val WORK = "memories-midnight"

    fun schedule(context: Context, now: ZonedDateTime = ZonedDateTime.now()) {
        val midnight = now.toLocalDate().plusDays(1).atStartOfDay(now.zone)
        val delay = Duration.between(now, midnight).toMillis().coerceAtLeast(0)
        val request = OneTimeWorkRequestBuilder<MemoriesMidnightWorker>().setInitialDelay(delay, TimeUnit.MILLISECONDS).build()
        WorkManager.getInstance(context).enqueueUniqueWork(WORK, ExistingWorkPolicy.REPLACE, request)
    }

    fun enqueueNow(context: Context) {
        WorkManager.getInstance(context).enqueueUniqueWork(WORK, ExistingWorkPolicy.REPLACE, OneTimeWorkRequestBuilder<MemoriesMidnightWorker>().build())
    }

    fun cancel(context: Context) {
        WorkManager.getInstance(context).cancelUniqueWork(WORK)
    }
}

class MemoriesMidnightWorker(context: Context, params: WorkerParameters) : CoroutineWorker(context, params) {
    override suspend fun doWork(): Result {
        if (MemoriesWidget.isPlaced(applicationContext)) MemoriesWidget.refresh(applicationContext)
        return Result.success()
    }
}

/**
 * The push path of Friend Updates (docs/WIDGET_REFRESH.md: "the Android widget worker copies a photo by a followed friend
 * into that friend's slot when it is newer"): after a group's widget rendition is stored, a friend widget following its
 * poster takes the same photo. Self-tags send no push; the app's own look-up brings them.
 */
object FriendWidgets {
    suspend fun copyFromGroup(context: Context, senderId: String, snapshot: WidgetSnapshot, groups: WidgetFileStore) {
        if (snapshot.kind != WidgetSnapshot.Kind.Photo) return
        if (senderId !in WidgetBinding.followedPeople(context)) return
        val slots = WidgetSlotStore.friends(context)
        if (!snapshot.supersedes(slots.read(senderId))) return
        val file = groups.photo(snapshot)
        if (!file.isFile) return
        slots.write(senderId, snapshot) { out -> file.inputStream().use { it.copyTo(out) } }
        WidgetBinding.refreshPerson(context, senderId)
    }
}

/**
 * The friend and memories slots follow the groups and the deletions the app learns (docs/WIDGET_REFRESH.md → Deletion): a
 * deleted photo, or one of a group left, leaves its slot at once (the slot then reads as not looked up until the next
 * look-up); signing out clears both.
 */
object PersonalWidgetStores {
    suspend fun removeSource(context: Context, sourceId: String) {
        val friends = WidgetSlotStore.friends(context).removeSource(sourceId)
        val memories = WidgetSlotStore.memories(context).removeSource(sourceId)
        rerender(context, friends.isNotEmpty(), memories.isNotEmpty())
    }

    suspend fun retainGroups(context: Context, groupIds: Set<String>) {
        val friends = WidgetSlotStore.friends(context).retainGroups(groupIds)
        val memories = WidgetSlotStore.memories(context).retainGroups(groupIds)
        rerender(context, friends.isNotEmpty(), memories.isNotEmpty())
    }

    fun clear(context: Context) {
        WidgetSlotStore.friends(context).clear()
        WidgetSlotStore.memories(context).clear()
    }

    private suspend fun rerender(context: Context, friends: Boolean, memories: Boolean) {
        if (friends) WidgetBinding.refreshLayout(context, WidgetLayouts.friendPhoto)
        if (memories) WidgetBinding.refreshLayout(context, WidgetLayouts.memories)
    }
}

@Composable
internal fun FriendWidgetContent(store: WidgetSlotStore, personId: String?, style: WidgetStyle, revision: Long, appWidgetId: Int) {
    val context = LocalContext.current
    val meta = WidgetGroupMeta.of(WidgetFileStore.default(context))
    val signedOut = meta.isSignedOut()
    val snapshot = remember(personId, revision, signedOut) { if (signedOut) null else personId?.let { runCatching { store.read(it) }.getOrNull() } }
    val slotState = remember(personId, revision) { personId?.let { runCatching { store.state(it) }.getOrNull() } }
    val empty = WidgetEmptyState.ofFriend(personId, slotState, signedOut)
    val tap = when {
        signedOut -> WidgetTap.App
        snapshot != null -> WidgetTap.Camera(snapshot.groupId)
        empty == WidgetEmptyState.NotSetUp -> WidgetTap.Configure
        else -> WidgetTap.Camera(null)
    }
    val label = snapshot?.let {
        context.getString(R.string.widget_home_small_a11y_photo, TokenPhotoWidgetSlots.firstName(it.senderName).orEmpty(), it.groupName)
    } ?: TokenPhotoWidgetSlots.emptyLabel(context, empty, WidgetStateLines.friend)
    SlotPhotoWidget(
        snapshot = snapshot,
        photo = { personId?.let { id -> snapshot?.let { s -> store.photo(id, s) } } },
        style = style,
        premium = meta.isPremium(),
        empty = empty,
        lines = WidgetStateLines.friend,
        tap = tap,
        label = label,
        appWidgetId = appWidgetId,
        locked = !signedOut,
    )
}

@Composable
internal fun MemoriesWidgetContent(store: WidgetSlotStore, day: LocalDate, style: WidgetStyle, revision: Long, appWidgetId: Int) {
    val context = LocalContext.current
    val meta = WidgetGroupMeta.of(WidgetFileStore.default(context))
    val signedOut = meta.isSignedOut()
    val slot = day.toString()
    val snapshot = remember(slot, revision, signedOut) { if (signedOut) null else runCatching { store.read(slot) }.getOrNull() }
    val slotState = remember(slot, revision) { runCatching { store.state(slot) }.getOrDefault(WidgetSlotStore.State.Unknown) }
    val empty = WidgetEmptyState.ofMemories(slotState, signedOut)
    val tap = when {
        snapshot != null && snapshot.sourceId != null -> WidgetTap.Post(snapshot.groupId, snapshot.sourceId!!)
        else -> WidgetTap.App
    }
    val label = snapshot?.let { context.getString(R.string.widget_memories_a11y_photo, WidgetStyleArt.dateText(it), it.groupName) }
        ?: TokenPhotoWidgetSlots.emptyLabel(context, empty, WidgetStateLines.memories)
    SlotPhotoWidget(
        snapshot = snapshot,
        photo = { snapshot?.let { store.photo(slot, it) } },
        style = style,
        premium = meta.isPremium(),
        empty = empty,
        lines = WidgetStateLines.memories,
        tap = tap,
        label = label,
        appWidgetId = appWidgetId,
        locked = !signedOut,
    )
}

/**
 * One photo widget drawn as `widget.home.small` in [style] (Friend Updates, Your Memories): the photo (Photo / Date: with the
 * scrim and the name stack; Frame: the print), or [empty] with [lines]; the root carries [label] and [tap]. [locked]
 * false skips the paywall link (signed out).
 */
@Composable
private fun SlotPhotoWidget(
    snapshot: WidgetSnapshot?,
    photo: () -> File?,
    style: WidgetStyle,
    premium: Boolean,
    empty: WidgetEmptyState,
    lines: WidgetStateLines,
    tap: WidgetTap,
    label: String?,
    appWidgetId: Int,
    locked: Boolean,
) {
    val context = LocalContext.current
    val size = LocalSize.current
    val sizeClass = WidgetSizeClass.of(size)
    val drawn = style.drawn(premium)
    val density = context.resources.displayMetrics.density
    val widthPx = (size.width.value * density).roundToInt()
    val heightPx = (size.height.value * density).roundToInt()
    val bitmap: Bitmap? = remember(snapshot, widthPx, heightPx, drawn) {
        photo()?.let { file -> styledPhoto(context, TokenPhotoWidgetSlots, file, widthPx, heightPx, drawn) }
    }
    var modifier = GlanceModifier.fillMaxSize().appWidgetBackground()
        .clickable(widgetTapAction(context, tap, appWidgetId, locked = locked && style.isLocked(premium)))
    label?.let { modifier = modifier.semantics { contentDescription = it } }
    if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.S) {
        modifier = modifier.cornerRadius(Tokens.Radii.widgetAndroidRadiusWidget)
    }
    Box(modifier = modifier) {
        if (snapshot != null && bitmap != null) {
            Image(
                provider = ImageProvider(bitmap),
                contentDescription = null,
                contentScale = ContentScale.Crop,
                modifier = GlanceModifier.fillMaxSize(),
            )
            StyleOverlay(drawn, snapshot) { TokenPhotoWidgetSlots.Overlay(snapshot, sizeClass) }
        } else {
            TokenPhotoWidgetSlots.EmptyState(empty, lines)
        }
    }
}
