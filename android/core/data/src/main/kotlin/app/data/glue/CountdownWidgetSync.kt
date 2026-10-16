package app.data.glue

import android.content.Context
import app.data.media.MediaStorage
import app.data.model.NextPlan
import app.data.repo.AuthRepository
import app.data.repo.AuthState
import app.data.repo.GroupRepository
import app.data.repo.PlanRepository
import app.model.CountdownPlan
import app.model.CountdownSnapshot
import app.widget.CountdownStore
import app.widget.CountdownWidget
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.flow.filterNotNull
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import java.time.Clock

/**
 * Keeps the countdown widget's snapshot (core:widget [CountdownStore]) in step with `next_plans()` (`widget.countdown` →
 * Data & actions: "a snapshot of next_plans() … on every plan_* event and on foreground"): your upcoming plans, soonest
 * first, with each group's name and the covers of the plans the widget shows today and falls through to after that day.
 * Runs only while a countdown widget is placed. Signing out clears it (nothing of the last person stays on the home
 * screen). Triggers: sign-in, this device's own plan writes ([PlanRepository.changes]) and [request] (the app's
 * foreground, a plan change seen live).
 */
class CountdownWidgetSync(
    private val plans: PlanRepository,
    private val groups: GroupRepository,
    private val storage: MediaStorage,
    private val scope: CoroutineScope,
    private val store: CountdownStore,
    private val clock: Clock = Clock.systemUTC(),
    private val placed: suspend () -> Boolean,
    private val refresh: suspend () -> Unit,
) {
    constructor(context: Context, plans: PlanRepository, groups: GroupRepository, storage: MediaStorage, scope: CoroutineScope, clock: Clock = Clock.systemUTC()) : this(
        plans, groups, storage, scope, CountdownStore.default(context), clock,
        placed = { CountdownWidget.isPlaced(context) },
        refresh = { CountdownWidget.refresh(context) },
    )

    private val mutex = Mutex()
    @Volatile private var pending: Job? = null
    @Volatile private var started = false

    /** Follows the session and this device's plan writes (once per process). */
    fun start(auth: AuthRepository) {
        if (started) return
        started = true
        scope.launch {
            auth.authState
                .map { state -> if (state is AuthState.Initializing) null else state is AuthState.SignedIn }
                .filterNotNull()
                .distinctUntilChanged()
                .collect { signedIn -> if (signedIn) request() else clear() }
        }
        scope.launch { plans.changes.collect { request() } }
    }

    /** A snapshot soon; a burst of triggers writes once. */
    fun request() {
        pending?.cancel()
        pending = scope.launch {
            delay(DEBOUNCE_MS)
            try {
                sync()
            } catch (e: CancellationException) {
                throw e
            } catch (_: Exception) {
                // Best effort: the widget keeps its last entry (HIG: don't hide stale data); the next trigger repeats it.
            }
        }
    }

    /** Fetches and writes the snapshot now, then re-renders the widgets. */
    suspend fun sync() = mutex.withLock {
        if (!placed()) return@withLock
        val upcoming = plans.nextPlans()
        val names = groups.myGroups().associate { it.id to it.name }
        val covers = coversFor(upcoming)
        val entries = upcoming.map { plan ->
            CountdownPlan(
                planId = plan.id,
                groupId = plan.groupId,
                groupName = names[plan.groupId].orEmpty(),
                title = plan.title,
                localDate = plan.localDate.toString(),
                coverFile = plan.coverPath?.let(CountdownStore::coverName)?.takeIf { it in covers },
            )
        }
        store.write(CountdownSnapshot(entries, clock.millis()))
        refresh()
    }

    /**
     * Downloads the covers of the first plan of the first two plan days (the plan shown today and the one shown once that
     * day has passed); covers already on the device are kept. Returns the file names present afterwards.
     */
    private suspend fun coversFor(upcoming: List<NextPlan>): Set<String> {
        val shown = upcoming.distinctBy { it.localDate }.take(SHOWN_DAYS).mapNotNull { it.coverPath }
        val present = HashSet<String>()
        for (path in shown) {
            val name = CountdownStore.coverName(path)
            if (!store.hasCover(name)) {
                val bytes = try {
                    storage.download(path)
                } catch (e: CancellationException) {
                    throw e
                } catch (_: Exception) {
                    null
                } ?: continue
                store.writeCover(name, bytes)
            }
            present += name
        }
        return present
    }

    /** Signed out: the snapshot and covers go; every placed widget shows the signed-out state. */
    fun clear() {
        pending?.cancel()
        scope.launch {
            mutex.withLock { store.clear() }
            runCatching { refresh() }
        }
    }

    private companion object {
        const val DEBOUNCE_MS = 500L // provenance-ok: coalesces a burst of triggers, not a design value
        /** Today's plan day and the next one (`widget.countdown` → Timeline: "+1 entry for the day after"). */
        const val SHOWN_DAYS = 2
    }
}
