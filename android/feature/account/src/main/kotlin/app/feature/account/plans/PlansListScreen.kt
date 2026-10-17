package app.feature.account.plans

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.asPaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.Immutable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.text.style.TextOverflow
import androidx.lifecycle.compose.LifecycleResumeEffect
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewModelScope
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.navigation.NavController
import app.data.error.ApiError
import app.data.error.DataError
import app.data.model.GroupPlan
import app.data.model.GroupPlanState
import app.designsystem.R
import app.designsystem.generated.Tokens
import app.feature.account.common.AccountViewModel
import app.feature.account.common.CollectEvents
import app.feature.account.common.dataError
import app.model.PlanCreateRoute
import app.model.PlanRoute
import app.ui.components.EmptyState
import app.ui.components.EmptyStateAction
import app.ui.components.EmptyStateFill
import app.ui.components.HeaderAction
import app.ui.components.PushedHeader
import app.ui.components.SectionHeader
import app.ui.components.ThumbnailRowSpacing
import app.ui.foundation.PageRoles
import app.ui.foundation.tapClickable
import app.ui.foundation.DsImage
import app.ui.text.TextRoles
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import java.time.ZoneId

/*
 * Surface: plans.list — every plan of a group: Upcoming, Past Plans, Canceled (design/surfaces/plans.list.md; MERGE FV-1).
 * Visual reference: Retro's Albums list as albums.list builds it (references/auto/retro/store/editorial/
 * retro-appstore-story-1854931006-week3-albums.png, ED-W3: pushed serif header, C-15 rows with a 3:4 cover) with C-20
 * section labels; mechanics Apple Invites' categories "Upcoming" / "Past Events" and the "+" beside the title
 * (references/auto/apple-invites/store/apple-invites-store-03.png; support guide view-your-events) and Partiful's Past
 * Events (help 15525513). Server: `group_plans` (docs/API.md §14.2).
 */

/** One row: the plan, its day line (the locale's medium date + short time; all-day the date) and its cover's URL. */
@Immutable
data class PlanListItem(val plan: GroupPlan, val line: String, val coverUrl: String?)

/** One section in the server's order (Upcoming, Past Plans, Canceled), only when it has plans. */
@Immutable
data class PlanListSection(val state: GroupPlanState, val items: List<PlanListItem>)

@Immutable
data class PlansListUiState(val phase: Phase = Phase.Loading, val sections: List<PlanListSection> = emptyList()) {
    enum class Phase { Loading, Loaded, Empty, Error, Offline, Removed }
}

class PlansListViewModel(private val backend: PlansBackend, val groupId: String) : AccountViewModel() {
    private val mutable = MutableStateFlow(PlansListUiState())
    val state: StateFlow<PlansListUiState> = mutable.asStateFlow()
    private var loadJob: Job? = null

    init {
        load()
        viewModelScope.launch {
            var first = true
            // Another member's plan or answer (Realtime); the first signal is the subscription going live.
            backend.planChanges(groupId).collect { if (first) first = false else load() }
        }
    }

    fun load() {
        loadJob?.cancel()
        loadJob = viewModelScope.launch {
            try {
                val plans = backend.groupPlans(groupId)
                val zone = backend.group(groupId)?.timeZone?.let { runCatching { ZoneId.of(it) }.getOrNull() } ?: ZoneId.systemDefault()
                val urls = plans.mapNotNull { it.coverPath }.takeIf { it.isNotEmpty() }?.let { backend.signedUrls(it) }.orEmpty()
                val sections = listOf(GroupPlanState.Upcoming, GroupPlanState.Past, GroupPlanState.Canceled).mapNotNull { state ->
                    plans.filter { it.state == state }.takeIf { it.isNotEmpty() }?.let { inState ->
                        PlanListSection(
                            state,
                            inState.map { PlanListItem(it, PlanFormats.rowLine(it.startsAt, it.allDay, it.localDate, zone), it.coverPath?.let(urls::get)) },
                        )
                    }
                }
                mutable.value = PlansListUiState(if (sections.isEmpty()) PlansListUiState.Phase.Empty else PlansListUiState.Phase.Loaded, sections)
            } catch (e: Exception) {
                val error = e.dataError()
                mutable.update { current ->
                    when {
                        error is DataError.Api && error.code == ApiError.NotGroupMember -> current.copy(phase = PlansListUiState.Phase.Removed)
                        // A loaded list stays; with nothing shown yet, the offline or error line.
                        current.sections.isNotEmpty() -> current
                        error == DataError.Network -> current.copy(phase = PlansListUiState.Phase.Offline)
                        else -> current.copy(phase = PlansListUiState.Phase.Error)
                    }
                }
            }
        }
    }

    fun retry() {
        mutable.update { it.copy(phase = PlansListUiState.Phase.Loading) }
        load()
    }
}

@Composable
fun PlansListRoute(nav: NavController, groupId: String) {
    val backend = rememberPlansBackend()
    val vm = viewModel(key = "plans:$groupId") { PlansListViewModel(backend, groupId) }
    val state by vm.state.collectAsStateWithLifecycle()
    CollectEvents(vm.events, nav)
    LifecycleResumeEffect(vm) {
        vm.load()
        onPauseOrDispose { }
    }
    LaunchedEffect(state.phase) { if (state.phase == PlansListUiState.Phase.Removed) nav.popBackStack() }
    PlansListScreen(
        state = state,
        onBack = { nav.popBackStack() },
        onCreate = { nav.navigate(PlanCreateRoute(groupId)) },
        onOpen = { plan -> nav.navigate(PlanRoute(plan.id, plan.groupId)) },
        onRetry = vm::retry,
    )
}

/**
 * `plans.list` (Retro's Albums list): C-02 "Plans" with the trailing "+" (Apple Invites' create beside "Upcoming") →
 * `plans.create`; then each non-empty section — C-20 label "Upcoming" / "Past Plans" / "Canceled" (no count) and its C-15
 * rows `size.global.listGap` apart: the plan's cover as the 3:4 thumbnail (no cover: `color.global.control` with
 * `icon.global.calendar`, the group cover's placeholder), the title (`listTitle`, ≤ 2 lines; cancelled: struck through
 * in secondary text, as `plans.page`) over the day line (`listSubtitle`, secondary). States: loading (three C-15
 * thumbnails), empty (C-27: calendar glyph, "No plans yet", "Make a Plan"), error / offline (one tappable line).
 */
@Composable
fun PlansListScreen(
    state: PlansListUiState,
    onBack: () -> Unit,
    onCreate: () -> Unit,
    onOpen: (GroupPlan) -> Unit,
    onRetry: () -> Unit,
) {
    val bottom = WindowInsets.navigationBars.asPaddingValues().calculateBottomPadding()
    Column(Modifier.fillMaxSize().background(PageRoles.page).statusBarsPadding().testTag("plans.list")) {
        PushedHeader(
            stringResource(R.string.plans_list_title),
            onBack,
            stringResource(R.string.plans_list_back_accessibilitylabel),
            actions = listOf(HeaderAction(Tokens.Icons.globalAdd, stringResource(R.string.plans_create_entry), onCreate)),
        )
        when (state.phase) {
            PlansListUiState.Phase.Loading -> Column(Modifier.padding(top = Tokens.Sizes.globalTitleToContent), verticalArrangement = ThumbnailRowSpacing) {
                repeat(LOADING_ROWS) {
                    Box(
                        Modifier
                            .padding(start = Tokens.Sizes.globalScreenMargin)
                            .size(Tokens.Sizes.globalRowThumbWidth, Tokens.Sizes.globalRowThumbHeight)
                            .clip(RoundedCornerShape(Tokens.Radii.globalThumbnail))
                            .background(Tokens.Colors.globalControl),
                    )
                }
            }
            PlansListUiState.Phase.Error -> PlansErrorLine(stringResource(R.string.plans_list_error_title), onRetry)
            PlansListUiState.Phase.Offline -> PlansErrorLine(stringResource(R.string.plans_list_offline), onRetry)
            PlansListUiState.Phase.Empty, PlansListUiState.Phase.Removed -> EmptyStateFill(Modifier.weight(1f).padding(bottom = bottom)) {
                EmptyState(
                    stringResource(R.string.plans_list_empty_title),
                    null,
                    action = EmptyStateAction(stringResource(R.string.plans_create_entry), onCreate),
                    icon = Tokens.Icons.globalCalendar,
                )
            }
            PlansListUiState.Phase.Loaded -> LazyColumn(
                Modifier.fillMaxSize(),
                contentPadding = PaddingValues(top = Tokens.Sizes.globalTitleToContent, bottom = bottom + Tokens.Sizes.globalSectionGap),
            ) {
                state.sections.forEachIndexed { index, section ->
                    item(key = "header-${section.state}") {
                        SectionHeader(sectionTitle(section.state), afterContent = index > 0)
                    }
                    items(section.items, key = { it.plan.id }) { item ->
                        Column {
                            PlanListRow(item) { onOpen(item.plan) }
                            if (item != section.items.last()) Spacer(Modifier.size(Tokens.Sizes.globalListGap))
                        }
                    }
                }
            }
        }
    }
}

/** `plans.list.section.*`. */
@Composable
private fun sectionTitle(state: GroupPlanState): String = stringResource(
    when (state) {
        GroupPlanState.Upcoming -> R.string.plans_list_section_upcoming
        GroupPlanState.Past -> R.string.plans_list_section_past
        GroupPlanState.Canceled -> R.string.plans_list_section_canceled
    },
)

/** C-15 row of a plan: one button, read as "{title}, {day line}". */
@Composable
private fun PlanListRow(item: PlanListItem, onClick: () -> Unit) {
    val canceled = item.plan.state == GroupPlanState.Canceled
    val secondary = PageRoles.secondaryText()
    Row(
        Modifier
            .fillMaxWidth()
            .tapClickable(onClick = onClick)
            .semantics(mergeDescendants = true) { contentDescription = item.plan.title + ", " + item.line }
            .padding(horizontal = Tokens.Sizes.globalScreenMargin)
            .testTag("plans.list.row"),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        val shape = RoundedCornerShape(Tokens.Radii.globalThumbnail)
        Box(
            Modifier.size(Tokens.Sizes.globalRowThumbWidth, Tokens.Sizes.globalRowThumbHeight).clip(shape).background(Tokens.Colors.globalControl),
            contentAlignment = Alignment.Center,
        ) {
            if (item.coverUrl != null) {
                DsImage(item.coverUrl, null, Modifier.matchParentSize())
            } else {
                Icon(Tokens.Icons.globalCalendar, contentDescription = null, tint = secondary, modifier = Modifier.size(Tokens.Sizes.globalIcon))
            }
        }
        Spacer(Modifier.width(Tokens.Sizes.globalRowThumbGap))
        Column(Modifier.weight(1f)) {
            Text(
                item.plan.title,
                style = TextRoles.listTitle,
                color = if (canceled) secondary else Tokens.Colors.globalTextPrimary,
                textDecoration = if (canceled) TextDecoration.LineThrough else null,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis,
            )
            Text(item.line, style = TextRoles.listSubtitle, color = secondary)
        }
    }
}

/** The list-error line (`retro.voice.error`, as `albums.list`): one tappable line, text role `body`, secondary text. */
@Composable
private fun PlansErrorLine(text: String, onRetry: () -> Unit) {
    Text(
        text,
        style = TextRoles.body,
        color = PageRoles.secondaryText(),
        modifier = Modifier
            .padding(top = Tokens.Sizes.globalTitleToContent)
            .fillMaxWidth()
            .tapClickable(onClick = onRetry)
            .padding(horizontal = Tokens.Sizes.globalScreenMargin)
            .semantics { role = Role.Button }
            .testTag("plans.list.error"),
    )
}

/** Rows drawn while loading (`plans.list` → loading: "three C-15 rows", as `albums.list`). */
private const val LOADING_ROWS = 3
