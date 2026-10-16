package app.feature.account.plans

import android.content.Context
import android.text.format.DateUtils
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.Immutable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.produceState
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.LifecycleResumeEffect
import app.data.model.Developing
import app.designsystem.R
import app.designsystem.generated.Tokens
import app.ui.components.DayTile
import app.ui.components.HeaderIconButton
import app.ui.foundation.PageRoles
import app.ui.foundation.tapClickable
import app.ui.text.TextRoles
import kotlinx.coroutines.CancellationException
import java.time.Instant
import java.time.ZoneId
import java.util.concurrent.ConcurrentHashMap

/** The group's next plan as its `groups.screen` row shows it. */
@Immutable
data class NextPlanRow(val planId: String, val title: String, val whenLine: String)

/**
 * The plan entry on `groups.screen` (plans.md §11: "one C-14 row on groups.screen (as the birthday request row) for the
 * next plan"), as iOS `PlanRowEntry`: [PlanRow] — the group's next plan (→ `plans.page`) with the "+" of
 * `plans.create.entry` (→ `plans.create`), or the "Make a Plan" row when none is upcoming. Nothing until the first read
 * (or the cached one) is in; a failed read keeps the last row. Its place next to the birthday request row is BLOCKED
 * (plans.md §12 item 6): the caller shows it beside a birthday row in debug builds only ([PlanBlocked.besideBirthdayRow]),
 * so release builds decide no order. Realtime plan changes refetch it (and the countdown widget follows).
 */
@Composable
fun PlanEntries(groupId: String, refreshKey: Any?, onOpen: (planId: String) -> Unit, onCreate: () -> Unit) {
    val backend = rememberPlansBackend()
    var tick by remember(groupId) { mutableIntStateOf(0) }
    LaunchedEffect(groupId, backend) {
        var first = true
        backend.planChanges(groupId).collect {
            // The first signal is the subscription going live, not a change.
            if (first) {
                first = false
            } else {
                backend.planSeenChanged()
                tick++
            }
        }
    }
    val loaded = produceState(NextPlanCache.get(groupId), groupId, refreshKey, tick, backend) {
        loadNextPlan(backend, groupId)?.let { value = it; NextPlanCache.put(groupId, it) }
    }.value ?: return
    PlanRow(loaded.row, onOpen = { loaded.row?.let { onOpen(it.planId) } }, onCreate = onCreate)
}

/** A completed read of the group's next plan: [row] null = no upcoming plan. */
@Immutable
data class NextPlanLoad(val row: NextPlanRow?)

/** The group's next plan (not cancelled, not over) in the group's time zone; null when the read failed. */
internal suspend fun loadNextPlan(backend: PlansBackend, groupId: String): NextPlanLoad? = try {
    val plan = backend.nextPlans(groupId).firstOrNull()
    NextPlanLoad(
        plan?.let {
            val zone = backend.group(groupId)?.timeZone?.let { tz -> runCatching { ZoneId.of(tz) }.getOrNull() } ?: ZoneId.systemDefault()
            NextPlanRow(it.id, it.title, PlanFormats.rowLine(it.startsAt, it.allDay, it.localDate, zone))
        },
    )
} catch (e: CancellationException) {
    throw e
} catch (_: Exception) {
    null
}

/** The last completed read per group (process memory), so the row does not pop in on every visit. */
internal object NextPlanCache {
    private val loads = ConcurrentHashMap<String, NextPlanLoad>()

    fun get(groupId: String): NextPlanLoad? = loads[groupId]

    fun put(groupId: String, load: NextPlanLoad) {
        loads[groupId] = load
    }
}

/**
 * The plan row (iOS `PlanRowEntry`), one C-14 single row inside the margins (fill `color.global.surfaceSecondary.android`,
 * `radius.global.groupedRow`, `size.global.sectionGap` under the content above, row padding `size.global.screenMargin`):
 * - a next plan: `icon.global.calendar`, the title (`listTitle`, one line) over its day and time (`listSubtitle`,
 *   secondary), `icon.global.chevron` in secondary text — one button → `plans.page`; then the C-11 bare "+"
 *   (`icon.global.add`, labelled `plans.create.entry`) → `plans.create`;
 * - none upcoming: `icon.global.add` and `plans.create.entry` (`body`) — one button → `plans.create`.
 * Glyph → text `size.global.cardNameGap` (C-14's leading element gap).
 */
@Composable
fun PlanRow(next: NextPlanRow?, onOpen: () -> Unit, onCreate: () -> Unit) {
    val shape = RoundedCornerShape(Tokens.Radii.globalGroupedRow)
    val secondary = PageRoles.secondaryText()
    val primary = Tokens.Colors.globalTextPrimary
    val margin = Tokens.Sizes.globalScreenMargin
    val glyph = Modifier.size(Tokens.Sizes.globalIcon)
    Row(
        Modifier
            .padding(start = margin, end = margin, top = Tokens.Sizes.globalSectionGap)
            .fillMaxWidth()
            .clip(shape)
            .background(PageRoles.secondarySurface, shape),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        val create = stringResource(R.string.plans_create_entry)
        if (next == null) {
            Row(
                Modifier.fillMaxWidth().heightIn(min = Tokens.Sizes.globalMinTouchTargetAndroid).tapClickable(onClick = onCreate)
                    .semantics(mergeDescendants = true) {}.padding(margin),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(Tokens.Sizes.globalCardNameGap),
            ) {
                Icon(Tokens.Icons.globalAdd, contentDescription = null, tint = primary, modifier = glyph)
                Text(create, style = TextRoles.body, color = primary)
            }
            return@Row
        }
        Row(
            Modifier.weight(1f).tapClickable(onClick = onOpen).semantics(mergeDescendants = true) {}.padding(margin),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(Tokens.Sizes.globalCardNameGap),
        ) {
            Icon(Tokens.Icons.globalCalendar, contentDescription = null, tint = primary, modifier = glyph)
            Column(Modifier.weight(1f)) {
                Text(next.title, style = TextRoles.listTitle, color = primary, maxLines = 1, overflow = TextOverflow.Ellipsis)
                Text(next.whenLine, style = TextRoles.listSubtitle, color = secondary)
            }
            Icon(Tokens.Icons.globalChevron, contentDescription = null, tint = secondary, modifier = glyph)
        }
        // The bare "+" ends `size.global.screenMargin` from the row's edge (its glyph centred in the hit area).
        HeaderIconButton(
            Tokens.Icons.globalAdd,
            create,
            onCreate,
            Modifier.padding(end = (margin - (Tokens.Sizes.globalMinTouchTargetAndroid - Tokens.Sizes.globalIcon) / 2).coerceAtLeast(0.dp)),
        )
    }
}

/**
 * Whether the group has photos developing (`group_developing`, docs/API.md §14.3 — a boolean and the next reveal, never a
 * number): fetched when [refreshKey] changes (new posts: a reveal inserts them) and each time the screen resumes. Null
 * until known or when the read fails (no tile).
 */
@Composable
fun rememberGroupDeveloping(groupId: String, refreshKey: Any?): Developing? {
    val backend = rememberPlansBackend()
    var resumes by remember(groupId) { mutableIntStateOf(0) }
    LifecycleResumeEffect(groupId) {
        resumes++
        onPauseOrDispose { }
    }
    return produceState<Developing?>(null, groupId, refreshKey, resumes, backend) {
        value = try {
            backend.groupDeveloping(groupId)
        } catch (e: CancellationException) {
            throw e
        } catch (_: Exception) {
            null
        }
    }.value
}

/**
 * The developing tile (`camera.overnight.layout.developingTile`): one C-17 placeholder tile per group, whatever the number
 * of photos — fill `color.global.control`, the word `camera.overnight.tile.label` centred (`tileLabel`, secondary text);
 * not a button. TalkBack: `camera.overnight.tile.a11y` with `{reveal}` (the relative day + time, `DateUtils`).
 */
@Composable
fun developingTile(developing: Developing?): DayTile? {
    if (developing == null || !developing.developing) return null
    val context = LocalContext.current
    val reveal = developing.revealAt?.let { revealWords(context, it) }.orEmpty()
    return DayTile.Placeholder(
        key = DEVELOPING_KEY,
        accessibilityLabel = stringResource(R.string.camera_overnight_tile_a11y, reveal),
        label = stringResource(R.string.camera_overnight_tile_label),
    )
}

/** `{reveal}`: "Tomorrow, 9:00 AM" — the platform's relative day and time (`camera.overnight` → Platform notes). */
internal fun revealWords(context: Context, at: Instant): String =
    DateUtils.getRelativeDateTimeString(context, at.toEpochMilli(), DateUtils.DAY_IN_MILLIS, DateUtils.WEEK_IN_MILLIS, 0).toString()

/** Stable key of the developing tile in the week strip. */
const val DEVELOPING_KEY = "day-tile-developing" // provenance-ok: list key, not shown
