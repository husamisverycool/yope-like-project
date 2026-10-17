// Surface: plans.page — one plan: details, answers, who's coming, photos. Spec: design/surfaces/plans.page.md.
// Visual reference: Retro's album detail skeleton as groups.screen / albums.view compose it (cover with its shadow, serif name
// centred, grey meta line, C-06 capsules, sections, a 3-column grid; references/auto/retro/press/tc-2024-04-journals-1.webp).
// Mechanics: Apple Invites' event page (order, cancel = crossed-out name; references/auto/apple-invites/store/
// apple-invites-store-04.png, -05.png, -07.png) and Partiful (Going · Maybe · Can't Go; guests see only Going and Maybe;
// references/auto/partiful/store/partiful-store-01.png, references/auto/partiful/web/pf-web-public-light-rsvp-sheet.png).
// Decisions: design/MERGE_DECISIONS.md PL-1 … PL-8.
package app.feature.account.plans

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.asPaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.paddingFrom
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBars
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.selection.selectableGroup
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.Immutable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.layout.LastBaseline
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.CustomAccessibilityAction
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.customActions
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewModelScope
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.navigation.NavController
import app.data.error.DataError
import app.data.model.Media
import app.data.model.MemberRole
import app.data.model.Plan
import app.data.model.PlanAnswer
import app.data.model.PlanAnswerKind
import app.data.model.Post
import app.data.offline.DataState
import app.data.repo.PlanDetail
import app.designsystem.R
import app.designsystem.generated.Tokens
import app.feature.account.AccountEnvironment
import app.feature.account.LocalAccountEnvironment
import app.feature.account.common.AccountViewModel
import app.feature.account.common.BookCover
import app.feature.account.common.CollectEvents
import app.feature.account.common.TapLine
import app.feature.account.common.dataError
import app.model.AppRoute
import app.model.SafetyReportContentRoute
import app.model.PlanCreateRoute
import app.ui.components.Avatar
import app.ui.components.AvatarStack
import app.ui.components.CapsuleRowSpacing
import app.ui.components.CapsuleToggle
import app.ui.components.EmptyState
import app.ui.components.GridCell
import app.ui.components.GroupedPosition
import app.ui.components.GroupedSectionHeader
import app.ui.components.Hairline
import app.ui.components.HeaderAction
import app.ui.components.PeopleRow
import app.ui.components.PhotoGrid
import app.ui.components.PushedHeader
import app.ui.foundation.GlyphInk
import app.ui.foundation.PageRoles
import app.ui.foundation.endAtLastBaseline
import app.ui.foundation.tapClickable
import app.ui.permissions.PermissionChecks
import app.ui.system.DsBottomSheet
import app.ui.system.DsDropdownMenu
import app.ui.system.DsMenuItem
import app.ui.system.SheetHeader
import app.ui.system.SystemAlertDialog
import app.ui.text.CapTop
import app.ui.text.TextRoles
import app.ui.text.capTopAt
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import java.time.Instant
import java.time.ZoneId

/** A member as the plan page lists them: first name and avatar (signed URL, null = no photo). */
@Immutable
data class PlanPerson(val userId: String, val firstName: String, val avatarUrl: String?)

/** A photo of the plan's days (`plan_photos`) with its thumbnail URL. */
@Immutable
data class PlanPhoto(val post: Post, val url: String?)

@Immutable
data class PlanPageUiState(
    val plan: Plan? = null,
    /** The group's time zone (the plan's day and time are the group's). */
    val zone: ZoneId? = null,
    val coverUrl: String? = null,
    /** Null when the maker's account is gone (`created_by` null) or not visible. */
    val maker: PlanPerson? = null,
    /** Answers in the order they were given (oldest first). */
    val going: List<PlanPerson> = emptyList(),
    val maybe: List<PlanPerson> = emptyList(),
    /** Only what RLS shows: your own Can't go, or everyone's for the plan's maker. */
    val cantGo: List<PlanPerson> = emptyList(),
    val myAnswer: PlanAnswerKind? = null,
    /** The maker or a group admin (edit, cancel, restore — MERGE PL-6). */
    val canManage: Boolean = false,
    /** Another member's plan: "Report Plan" and "Block {first_name}" in the menu (safety.report, MERGE FV-4). */
    val canReport: Boolean = false,
    val photos: List<PlanPhoto> = emptyList(),
    val notFound: Boolean = false,
    val error: Boolean = false,
    val online: Boolean = true,
    val confirmCancel: Boolean = false,
) {
    val loading: Boolean get() = plan == null && !notFound && !error

    /** The plan's day has ended in the group's time zone (or its end time passed): no answers, no edits (§14.2 "over"). */
    fun past(now: Instant): Boolean = plan != null && plan.isOver(now, zone ?: ZoneId.systemDefault())
}

/**
 * The plan and its answers, cache-then-network (`observeDetail`); first names and avatars from the group's members; the
 * cover's signed URL; after the plan's day the photos of its days (`plan_photos`). Inserts and updates of `plans` and
 * `plan_answers` refetch (realtime). Answering is optimistic: a failure reverts and shows the toast
 * `plans.page.error.answer`.
 */
class PlanPageViewModel(
    private val env: AccountEnvironment,
    private val backend: PlansBackend,
    private val planId: String,
) : AccountViewModel() {
    private val mutable = MutableStateFlow(PlanPageUiState())
    val state: StateFlow<PlanPageUiState> = mutable.asStateFlow()

    private var detail: PlanDetail? = null
    private var answers: List<PlanAnswer> = emptyList()
    private val people = HashMap<String, PlanPerson>()
    private var admins: Set<String> = emptySet()
    private val urls = HashMap<String, String>()
    private var loadJob: Job? = null
    private var liveGroup: String? = null

    init {
        viewModelScope.launch { backend.online.collect { online -> mutable.update { it.copy(online = online) } } }
        load()
    }

    fun load() {
        loadJob?.cancel()
        mutable.update { it.copy(error = false) }
        loadJob = viewModelScope.launch { backend.observePlan(planId).collect(::onPage) }
    }

    private suspend fun onPage(page: DataState<PlanDetail?>) {
        val value = page.value
        when {
            value != null -> show(value)
            page.refreshing -> Unit
            page.error == null -> mutable.update { PlanPageUiState(notFound = true, online = it.online) }
            (page.error as? DataError.Api)?.raw == PLAN_NOT_FOUND -> mutable.update { PlanPageUiState(notFound = true, online = it.online) }
            else -> mutable.update { it.copy(error = it.plan == null) }
        }
    }

    private suspend fun show(value: PlanDetail) {
        detail = value
        answers = value.answers
        val plan = value.plan
        publish()
        val group = runCatching { backend.group(plan.groupId) }.getOrNull()
        val zone = group?.timeZone?.let { runCatching { ZoneId.of(it) }.getOrNull() }
        mutable.update { it.copy(zone = zone ?: it.zone) }
        loadPeople(plan)
        plan.coverPath?.let { path ->
            if (path !in urls) urls.putAll(runCatching { backend.signedUrls(listOf(path)) }.getOrDefault(emptyMap()))
        }
        publish()
        if (!plan.canceled && mutable.value.past(env.clock.instant())) loadPhotos(plan)
        follow(plan.groupId)
    }

    /** Members' first names and avatars (and anyone who answered but left the group, by profile). */
    private suspend fun loadPeople(plan: Plan) {
        val members = runCatching { backend.members(plan.groupId) }.getOrDefault(emptyList())
        admins = members.filter { it.member.role == MemberRole.Admin }.mapTo(HashSet()) { it.member.userId }
        val profiles = members.mapNotNull { it.profile }
        val known = profiles.map { it.id }.toSet()
        val missing = (answers.map { it.userId } + listOfNotNull(plan.createdBy)).filter { it !in known && it !in people }.distinct()
        val extra = if (missing.isEmpty()) emptyList() else runCatching { backend.profiles(missing) }.getOrDefault(emptyList())
        val all = profiles + extra
        val avatarPaths = all.mapNotNull { it.avatarPath }.filter { it !in urls }
        if (avatarPaths.isNotEmpty()) urls.putAll(runCatching { backend.signedUrls(avatarPaths) }.getOrDefault(emptyMap()))
        all.forEach { p -> people[p.id] = PlanPerson(p.id, p.firstName ?: p.displayName, p.avatarPath?.let(urls::get)) }
    }

    private suspend fun loadPhotos(plan: Plan) {
        val posts = runCatching { backend.planPhotos(plan.id) }.getOrNull() ?: return
        val shown = posts.take(ALBUM_CELLS)
        val media = runCatching { backend.media(shown.map { it.mediaId }) }.getOrDefault(emptyList()).associateBy { it.id }
        val paths = shown.mapNotNull { media[it.mediaId]?.imagePath(Media.Rendition.Thumb) }.filter { it !in urls }
        if (paths.isNotEmpty()) urls.putAll(runCatching { backend.signedUrls(paths) }.getOrDefault(emptyMap()))
        mutable.update { s -> s.copy(photos = shown.map { PlanPhoto(it, media[it.mediaId]?.imagePath(Media.Rendition.Thumb)?.let(urls::get)) }) }
    }

    /** Realtime: a change of the group's plans or answers refetches (and the countdown widget follows). */
    private fun follow(groupId: String) {
        if (liveGroup == groupId) return
        liveGroup = groupId
        viewModelScope.launch {
            var first = true
            backend.planChanges(groupId).collect {
                // The first signal is the subscription going live, right after this load.
                if (first) {
                    first = false
                    return@collect
                }
                backend.planSeenChanged()
                load()
            }
        }
    }

    private fun publish() {
        val value = detail ?: return
        val plan = value.plan
        val me = backend.currentUserId
        fun person(id: String) = people[id] ?: PlanPerson(id, "", null)
        fun list(kind: PlanAnswerKind) = answers.filter { it.answer == kind }.map { person(it.userId) }.filter { it.firstName.isNotEmpty() }
        mutable.update {
            it.copy(
                plan = plan,
                coverUrl = plan.coverPath?.let(urls::get),
                maker = plan.createdBy?.let(people::get),
                going = list(PlanAnswerKind.Going),
                maybe = list(PlanAnswerKind.Maybe),
                cantGo = list(PlanAnswerKind.CantGo),
                myAnswer = answers.firstOrNull { a -> a.userId == me }?.answer,
                canManage = me != null && (plan.createdBy == me || me in admins),
                canReport = me != null && plan.createdBy != null && plan.createdBy != me,
                notFound = false,
                error = false,
            )
        }
    }

    /**
     * One tap commits (Partiful); [kind] null clears the answer (tapping the selected capsule again). Optimistic: the
     * capsule fills at once; a failure reverts it, plays `haptic.global.error` and shows `plans.page.error.answer`.
     */
    fun answer(kind: PlanAnswerKind?) {
        val s = mutable.value
        val plan = s.plan ?: return
        val me = backend.currentUserId ?: return
        if (!s.online || plan.canceled || s.past(env.clock.instant())) return
        val before = answers
        answers = answers.filterNot { it.userId == me } + listOfNotNull(kind?.let { PlanAnswer(plan.id, me, plan.groupId, it, env.clock.instant()) })
        publish()
        viewModelScope.launch {
            try {
                if (kind == null) backend.clearAnswer(plan.id) else backend.answer(plan.id, kind)
            } catch (t: Throwable) {
                t.dataError()
                answers = before
                publish()
                haptic(Tokens.Haptics.globalError)
                toast(R.string.plans_page_error_answer)
            }
        }
    }

    fun askCancel() = mutable.update { it.copy(confirmCancel = true) }

    fun dismissCancel() = mutable.update { it.copy(confirmCancel = false) }

    /** "Yes, cancel": `cancel_plan` (Going and Maybe are told once); the title is struck through. */
    fun confirmCancel() {
        mutable.update { it.copy(confirmCancel = false) }
        write { backend.cancelPlan(planId) }
    }

    /** "Restore Plan": `restore_plan` (tells nobody). */
    fun restore() = write { backend.restorePlan(planId) }

    private fun write(call: suspend () -> Plan) {
        viewModelScope.launch {
            try {
                val plan = call()
                detail = detail?.copy(plan = plan)
                publish()
            } catch (t: Throwable) {
                t.dataError()
                haptic(Tokens.Haptics.globalError)
            }
        }
    }

    fun edit() {
        val plan = mutable.value.plan ?: return
        navigate(PlanCreateRoute(plan.groupId, plan.id))
    }

    private companion object {
        /** `plans.page` → Album: "at most 3 rows on this page" of the 3-column grid. */
        const val ALBUM_CELLS = 9 // provenance-ok: 3 rows × 3 columns (spec text), a count

        const val PLAN_NOT_FOUND = "plan_not_found" // provenance-ok: server error code (docs/API.md §14.2)
    }
}

/** What the plan page does on each control. */
class PlanPageActions(
    val onBack: () -> Unit = {},
    val onEdit: () -> Unit = {},
    val onCancel: () -> Unit = {},
    val onConfirmCancel: () -> Unit = {},
    val onDismissCancel: () -> Unit = {},
    val onRestore: () -> Unit = {},
    /** "Report Plan" (safety.report, kind `plan`). */
    val onReport: () -> Unit = {},
    /** "Block {first_name}" of the plan's maker (safety.block). */
    val onBlockMaker: () -> Unit = {},
    /** "Add to Calendar": the calendar app's new-event screen for the plan (PlanCalendar.kt). */
    val onAddToCalendar: () -> Unit = {},
    val onAnswer: (PlanAnswerKind?) -> Unit = {},
    val onPhoto: (Post) -> Unit = {},
    val onRetry: () -> Unit = {},
)

@Composable
fun PlanPageRoute(nav: NavController, planId: String) {
    val env = LocalAccountEnvironment.current
    val backend = rememberPlansBackend()
    val vm = viewModel(key = "plan:$planId") { PlanPageViewModel(env, backend, planId) }
    val state by vm.state.collectAsStateWithLifecycle()
    val context = LocalContext.current
    CollectEvents(vm.events, nav)
    PlanPageScreen(
        state = state,
        now = env.clock.instant(),
        actions = PlanPageActions(
            onBack = { nav.popBackStack() },
            onEdit = vm::edit,
            onCancel = vm::askCancel,
            onConfirmCancel = vm::confirmCancel,
            onDismissCancel = vm::dismissCancel,
            onRestore = vm::restore,
            onReport = {
                state.plan?.let { plan -> nav.navigate(SafetyReportContentRoute("plan", plan.id, plan.groupId, plan.createdBy)) }
            },
            onBlockMaker = { state.plan?.createdBy?.let { maker -> nav.navigate(AppRoute.SafetyBlock(maker)) } },
            onAddToCalendar = { state.plan?.let { plan -> PermissionChecks.openSafely(context, PlanCalendarFields.of(plan).intent()) } },
            onAnswer = vm::answer,
            onPhoto = { post -> nav.navigate(AppRoute.PhotoViewer(post.groupId, post.id)) },
            onRetry = vm::load,
        ),
    )
}

/**
 * The plan (pushed; page `color.global.background.android`; one vertical scroll), Apple Invites' order on Retro's album
 * page:
 * 1. C-02 header row without a title — back; trailing C-01 `icon.global.calendar` "Add to Calendar" while the plan is on
 *    (Apple Invites' calendar button beside "•••"), then `icon.global.more` for the maker and admins while the plan is
 *    not over → native menu "Edit Plan" · "Cancel Plan" (C-10 red), or "Restore Plan" once cancelled;
 * 2. the cover (when the plan has one), as `groups.screen`'s (`groups.screen.size.cover*`, `radius.global.thumbnail`,
 *    `groups.screen.shadow.cover`);
 * 3. the title (`font.global.display` `displayMedium`, centred, ≤ 3 lines, cap top `groups.screen.size.coverToTitle`
 *    under the cover); cancelled: struck through in secondary text;
 * 4. the meta lines `groups.screen.size.titleToMeta` below (`listSubtitle`, secondary, centred): the day and time (all-day:
 *    the day), the place; cancelled: `plans.page.canceled`;
 * 5. while the plan is on: three C-06 capsules Going · Maybe · Can't go (equal widths, `size.global.pillGap` apart,
 *    `groups.screen.size.metaToActions` below), the current answer filled;
 * 6. "Made by {name}" (C-16, `size.global.avatarPicker`) and the note (`body`), `size.global.sectionGap` below;
 * 7. one block per non-empty list (Going, Maybe): C-20 label (no number) + C-23 stack + the first names, a button that
 *    opens the "Who's Coming" sheet; nobody answered: no block;
 * 8. after the plan's day, the photos of its days: C-20 label `plans.page.album` over the 3-column C-21 grid (≤ 3 rows).
 */
@Composable
fun PlanPageScreen(state: PlanPageUiState, now: Instant, actions: PlanPageActions) {
    var peopleOpen by remember { mutableStateOf(false) }
    val plan = state.plan
    val past = state.past(now)
    val bottom = WindowInsets.navigationBars.asPaddingValues().calculateBottomPadding() + Tokens.Sizes.globalSectionGap
    Box(Modifier.fillMaxSize().background(PageRoles.page).windowInsetsPadding(WindowInsets.statusBars)) {
        when {
            state.notFound -> Column(Modifier.fillMaxSize()) {
                Header(state, past, actions)
                Box(Modifier.weight(1f).fillMaxWidth(), contentAlignment = Alignment.Center) {
                    EmptyState(stringResource(R.string.plans_page_notfound_title), stringResource(R.string.plans_page_notfound_detail))
                }
            }
            state.error -> Column(Modifier.fillMaxSize()) {
                Header(state, past, actions)
                Box(Modifier.weight(1f).fillMaxWidth(), contentAlignment = Alignment.Center) {
                    TapLine(stringResource(R.string.plans_page_error_title), actions.onRetry)
                }
            }
            plan == null -> Column(Modifier.fillMaxSize()) {
                Header(state, past, actions)
                // Loading (C-28): the cover's place in `color.global.control`, nothing else until the plan is there.
                Box(Modifier.fillMaxWidth(), contentAlignment = Alignment.Center) {
                    BookCover(null, Tokens.Sizes.groupsScreenSizeCoverWidth, Tokens.Sizes.groupsScreenSizeCoverHeight, glyph = null)
                }
            }
            else -> LazyColumn(Modifier.fillMaxSize(), contentPadding = PaddingValues(bottom = bottom)) {
                item(key = "header") { Header(state, past, actions) }
                if (plan.coverPath != null) item(key = "cover") { Cover(state.coverUrl, plan.title) }
                item(key = "title") { Title(plan, afterCover = plan.coverPath != null) }
                item(key = "meta") { Meta(plan, state.zone ?: ZoneId.systemDefault()) }
                if (!plan.canceled && !past) item(key = "answers") { AnswerRow(state.myAnswer, state.online, actions.onAnswer) }
                if (!plan.canceled && !past && !state.online) item(key = "offline") { OfflineLine() }
                item(key = "madeBy") { MadeBy(state.maker, plan.note) }
                if (state.going.isNotEmpty()) {
                    item(key = "going") {
                        val label = stringResource(if (past) R.string.plans_page_went else R.string.plans_page_going)
                        ListBlock(label, state.going) { peopleOpen = true }
                    }
                }
                if (state.maybe.isNotEmpty()) item(key = "maybe") { ListBlock(stringResource(R.string.plans_page_maybe), state.maybe) { peopleOpen = true } }
                if (past && !plan.canceled && state.photos.isNotEmpty()) item(key = "album") { Album(state.photos, actions.onPhoto) }
            }
        }
    }
    if (peopleOpen) PeopleSheet(state, past) { peopleOpen = false }
    if (state.confirmCancel && plan != null) {
        SystemAlertDialog(
            title = stringResource(R.string.plans_page_cancel_title, plan.title),
            text = stringResource(R.string.plans_page_cancel_message),
            confirmLabel = stringResource(R.string.plans_page_cancel_confirm),
            onConfirm = actions.onConfirmCancel,
            dismissLabel = stringResource(R.string.plans_page_cancel_keep),
            onDismiss = actions.onDismissCancel,
            destructive = true,
        )
    }
}

/**
 * C-02 without a title: back, and the C-01 "•••" with the native menu: the maker's and admins' Edit / Cancel (or Restore)
 * while the plan is not over; on another member's plan "Report Plan" and "Block {first_name}" (C-10 red, MERGE FV-4).
 */
@Composable
private fun Header(state: PlanPageUiState, past: Boolean, actions: PlanPageActions) {
    val plan = state.plan
    var menuOpen by remember { mutableStateOf(false) }
    val manage = when {
        plan == null || !state.canManage || past -> emptyList()
        plan.canceled -> listOf(DsMenuItem(stringResource(R.string.plans_page_menu_restore), actions.onRestore))
        else -> listOf(
            DsMenuItem(stringResource(R.string.plans_page_menu_edit), actions.onEdit),
            DsMenuItem(stringResource(R.string.plans_page_menu_cancel), actions.onCancel, destructive = true),
        )
    }
    val report = if (plan != null && state.canReport) {
        listOfNotNull(
            DsMenuItem(stringResource(R.string.safety_report_menuitem_plan), actions.onReport, destructive = true),
            state.maker?.let { DsMenuItem(stringResource(R.string.safety_block_menuitemnamed, it.firstName), actions.onBlockMaker, destructive = true) },
        )
    } else {
        emptyList()
    }
    val items = manage + report
    val calendar = if (plan != null && !plan.canceled && !past) {
        listOf(HeaderAction(Tokens.Icons.globalCalendar, stringResource(R.string.plans_page_addtocalendar_accessibilitylabel), actions.onAddToCalendar))
    } else {
        emptyList()
    }
    val more = if (items.isEmpty()) emptyList() else listOf(HeaderAction(Tokens.Icons.globalMore, stringResource(R.string.plans_page_more_accessibilitylabel)) { menuOpen = true })
    Box(Modifier.fillMaxWidth()) {
        PushedHeader(
            title = "",
            onBack = actions.onBack,
            backContentDescription = stringResource(R.string.plans_page_back_accessibilitylabel),
            actions = calendar + more,
        )
        Box(Modifier.align(Alignment.TopEnd).padding(end = Tokens.Sizes.globalHeaderInset)) {
            DsDropdownMenu(expanded = menuOpen, onDismissRequest = { menuOpen = false }, items = items)
        }
    }
}

@Composable
private fun Cover(url: String?, title: String) {
    Box(Modifier.fillMaxWidth(), contentAlignment = Alignment.Center) {
        BookCover(
            url,
            Tokens.Sizes.groupsScreenSizeCoverWidth,
            Tokens.Sizes.groupsScreenSizeCoverHeight,
            contentDescription = stringResource(R.string.plans_page_cover_accessibilitylabel, title),
            glyph = null,
        )
    }
}

/**
 * The title: `font.global.display` at `displayMedium` (text role `displayTitle`), centred, ≤ 3 lines; its cap top
 * `groups.screen.size.coverToTitle` under the cover (none: the header's `size.global.titleToContent` is above it);
 * cancelled: `TextDecoration.LineThrough` in secondary text (Apple "the name is crossed out"); header trait.
 */
@Composable
private fun Title(plan: Plan, afterCover: Boolean) {
    val base = TextRoles.displayTitle
    val style = if (plan.canceled) base.copy(textDecoration = TextDecoration.LineThrough) else base
    Text(
        plan.title,
        style = style,
        color = if (plan.canceled) PageRoles.secondaryText() else Tokens.Colors.globalTextPrimary,
        textAlign = TextAlign.Center,
        maxLines = TITLE_MAX_LINES,
        overflow = TextOverflow.Ellipsis,
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = Tokens.Sizes.globalScreenMargin)
            .then(if (afterCover) Modifier.capTopAt(Tokens.Sizes.groupsScreenSizeCoverToTitle, CapTop.height(style)) else Modifier)
            .endAtLastBaseline()
            .semantics { heading() },
    )
}

/**
 * The meta lines, one element for TalkBack: the day and time in the group's time zone (all-day: the day alone), the place;
 * cancelled: `plans.page.canceled` (which also announces the strikethrough). Cap top `groups.screen.size.titleToMeta`
 * under the title's baseline; `listSubtitle`, secondary text, centred. No maps link.
 */
@Composable
private fun Meta(plan: Plan, zone: ZoneId) {
    val style = TextRoles.listSubtitle
    val secondary = PageRoles.secondaryText()
    val line1 = if (plan.canceled) stringResource(R.string.plans_page_canceled) else PlanFormats.whenLine(plan, zone)
    Column(
        Modifier
            .fillMaxWidth()
            .padding(horizontal = Tokens.Sizes.globalScreenMargin)
            .capTopAt(Tokens.Sizes.groupsScreenSizeTitleToMeta, CapTop.height(style))
            .endAtLastBaseline()
            .semantics(mergeDescendants = true) {},
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text(line1, style = style, color = secondary, textAlign = TextAlign.Center)
        plan.place?.let { Text(it, style = style, color = secondary, textAlign = TextAlign.Center) }
    }
}

/**
 * The answer row: three C-06 toggle capsules (outline → primary when chosen), equal widths `size.global.pillGap` apart
 * inside `size.global.screenMargin`, `groups.screen.size.metaToActions` under the meta line; Partiful's order. One
 * selectable group "Your answer"; the chosen one is selected and has the custom action "Clear answer"; tapping it again
 * clears the answer. `haptic.global.select` (the C-06 toggle's tick). Offline: disabled.
 */
@Composable
private fun AnswerRow(answer: PlanAnswerKind?, online: Boolean, onAnswer: (PlanAnswerKind?) -> Unit) {
    val groupLabel = stringResource(R.string.plans_page_answer_grouplabel)
    val clearLabel = stringResource(R.string.plans_page_answer_clear)
    Row(
        Modifier
            .fillMaxWidth()
            .padding(start = Tokens.Sizes.globalScreenMargin, end = Tokens.Sizes.globalScreenMargin, top = Tokens.Sizes.groupsScreenSizeMetaToActions)
            .selectableGroup()
            .semantics { contentDescription = groupLabel },
        horizontalArrangement = CapsuleRowSpacing,
    ) {
        for (kind in PlanAnswerKind.entries) {
            val chosen = answer == kind
            CapsuleToggle(
                text = stringResource(answerLabel(kind)),
                selected = chosen,
                onSelectedChange = { on -> onAnswer(if (on) kind else null) },
                enabled = online,
                modifier = Modifier.weight(1f).semantics {
                    selected = chosen
                    if (chosen) customActions = listOf(CustomAccessibilityAction(clearLabel) { onAnswer(null); true })
                },
            )
        }
    }
}

private fun answerLabel(kind: PlanAnswerKind): Int = when (kind) {
    PlanAnswerKind.Going -> R.string.plans_page_answer_going
    PlanAnswerKind.Maybe -> R.string.plans_page_answer_maybe
    PlanAnswerKind.CantGo -> R.string.plans_page_answer_cantgo
}

/** Offline (`plans.page` → States): the capsules are disabled; this line says why (`meta`, secondary, centred). */
@Composable
private fun OfflineLine() {
    Text(
        stringResource(R.string.plans_page_offline),
        style = TextRoles.meta,
        color = PageRoles.secondaryText(),
        textAlign = TextAlign.Center,
        modifier = Modifier.fillMaxWidth().padding(start = Tokens.Sizes.globalScreenMargin, end = Tokens.Sizes.globalScreenMargin, top = Tokens.Sizes.globalPillGap),
    )
}

/** "Made by {name}" (C-16, avatar `size.global.avatarPicker`, `listTitle`; no crown, no badge) and the note (`body`, full text). */
@Composable
private fun MadeBy(maker: PlanPerson?, note: String?) {
    if (maker == null && note == null) return
    Column(Modifier.fillMaxWidth().padding(top = Tokens.Sizes.globalSectionGap)) {
        if (maker != null) PeopleRow(name = stringResource(R.string.plans_page_madeby, maker.firstName), avatar = maker.avatarUrl)
        if (note != null) {
            Text(
                note,
                style = TextRoles.body,
                color = Tokens.Colors.globalTextPrimary,
                // Under the row as C-16 places content under its text: `size.global.pillGap` (that gap is not measured — Gap).
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(start = Tokens.Sizes.globalScreenMargin, end = Tokens.Sizes.globalScreenMargin, top = if (maker != null) Tokens.Sizes.globalPillGap else 0.dp),
            )
        }
    }
}

/**
 * A list block (Going / Maybe): the C-20 label in `sectionLabel` (no number) with `icon.global.chevron` in secondary text
 * when the stack cannot show everyone, its cap top `size.global.sectionGap` below the content above; then
 * `size.global.sectionHeaderToContent` below it the C-23 stack (`size.global.avatarSmall`, oldest answer first, as many as
 * fit) and the first names joined by the list formatter (`listSubtitle`, secondary, wrapping). One button → the sheet;
 * the avatars are decorative. [label] null: a BLOCKED label left out (the list stays).
 */
@Composable
private fun ListBlock(label: String?, people: List<PlanPerson>, onOpen: () -> Unit) {
    val style = TextRoles.sectionLabel
    val secondary = PageRoles.secondaryText()
    val width = LocalConfiguration.current.screenWidthDp.dp - Tokens.Sizes.globalScreenMargin * 2
    val avatar = Tokens.Sizes.globalAvatarSmall
    val fit = if (width < avatar) 0 else 1 + ((width - avatar) / (avatar - Tokens.Sizes.globalAvatarStackOverlap)).toInt()
    val chevron = Tokens.Icons.globalChevron
    Column(
        Modifier
            .fillMaxWidth()
            .padding(top = if (label == null) Tokens.Sizes.globalSectionGap else 0.dp)
            .tapClickable(onClick = onOpen)
            .semantics(mergeDescendants = true) {}
            .padding(horizontal = Tokens.Sizes.globalScreenMargin),
    ) {
        if (label != null) {
            Row(
                Modifier.fillMaxWidth().capTopAt(Tokens.Sizes.globalSectionGap, CapTop.height(style)).paddingFrom(LastBaseline, after = Tokens.Sizes.globalSectionHeaderToContent),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(label, style = style, color = Tokens.Colors.globalTextPrimary, modifier = Modifier.weight(1f).semantics { heading() })
                if (people.size > fit) {
                    Icon(chevron, contentDescription = null, tint = secondary, modifier = Modifier.offset(x = GlyphInk.trailing(chevron, Tokens.Sizes.globalIcon)).size(Tokens.Sizes.globalIcon))
                }
            }
        }
        AvatarStack(people.take(fit).map { it.avatarUrl }, Modifier.clearAndSetSemantics { })
        Text(PlanFormats.names(people.map { it.firstName }), style = TextRoles.listSubtitle, color = secondary)
    }
}

/** After the plan's day: the C-20 label "Photos" over the first rows (≤ 3) of a 3-column C-21 grid; a cell opens the viewer. */
@Composable
private fun Album(photos: List<PlanPhoto>, onPhoto: (Post) -> Unit) {
    val label = stringResource(R.string.plans_page_album)
    Column(Modifier.fillMaxWidth()) {
        val style = TextRoles.sectionLabel
        Text(
            label,
            style = style,
            color = Tokens.Colors.globalTextPrimary,
            modifier = Modifier
                .fillMaxWidth()
                .capTopAt(Tokens.Sizes.globalSectionGap, CapTop.height(style))
                .paddingFrom(LastBaseline, after = Tokens.Sizes.globalSectionHeaderToContent)
                .padding(horizontal = Tokens.Sizes.globalScreenMargin)
                .semantics { heading() },
        )
        PhotoGrid(photos.map { GridCell(it.post.id, it.url, label, { onPhoto(it.post) }) }, columns = GRID_COLUMNS)
    }
}

/**
 * "Who's Coming" (C-29 page sheet, `plans.page.people.title`): C-14 sections Going, Maybe and — for its own member and the
 * maker only, as RLS returns it — Can't go, of C-16 rows (avatar `size.global.avatarPicker`, first name `listTitle`); no
 * counts; rows are not buttons. A past plan's Going section reads "Went" (`plans.page.went`, MERGE FV-2).
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun PeopleSheet(state: PlanPageUiState, past: Boolean, onDismiss: () -> Unit) {
    val goingLabel = stringResource(if (past) R.string.plans_page_went else R.string.plans_page_going)
    DsBottomSheet(onDismissRequest = onDismiss) {
        SheetHeader(stringResource(R.string.plans_page_people_title))
        Column(Modifier.fillMaxWidth().verticalScroll(rememberScrollState()).padding(bottom = Tokens.Sizes.globalSectionGap)) {
            PeopleSection(goingLabel, state.going)
            PeopleSection(stringResource(R.string.plans_page_maybe), state.maybe)
            PeopleSection(stringResource(R.string.plans_page_people_cantgo), state.cantGo)
        }
    }
}

@Composable
private fun PeopleSection(header: String?, people: List<PlanPerson>) {
    if (people.isEmpty()) return
    Spacer(Modifier.heightIn(min = Tokens.Sizes.globalSectionGap))
    if (header != null) GroupedSectionHeader(header)
    Column(Modifier.padding(horizontal = Tokens.Sizes.globalScreenMargin)) {
        people.forEachIndexed { index, person ->
            val position = GroupedPosition.of(index, people.size)
            val shape = position.shape()
            Column(Modifier.fillMaxWidth().clip(shape).background(PageRoles.secondarySurface, shape)) {
                Row(
                    Modifier.fillMaxWidth().heightIn(min = Tokens.Sizes.settingsRootSizeRowHeight).padding(start = Tokens.Sizes.globalScreenMargin),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Avatar(person.avatarUrl, Tokens.Sizes.globalAvatarPicker)
                    Spacer(Modifier.width(Tokens.Sizes.globalRowThumbGap))
                    Text(person.firstName, style = TextRoles.listTitle, color = Tokens.Colors.globalTextPrimary)
                }
                if (position.dividerBelow) Hairline()
            }
        }
    }
}

private const val TITLE_MAX_LINES = 3
private const val GRID_COLUMNS = 3
