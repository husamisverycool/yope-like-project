// Surface: groups.screen — the group: cover, name, members, actions, this week, members' weeks and memories, earlier photos.
// Spec: design/surfaces/groups.screen.md. References: references/auto/retro/press/tc-2024-04-journals-1.webp (TC-J1 phone 3:
// book cover 173.5 × 246 + shadow, serif title, meta line, outline capsules, dated sections over a 3-column grid),
// references/auto/retro/lazyweb/retro-lazyweb-20251020-week43-dark.png and …-20260528-week22-dark-a.png (H43 / H22: header
// glyphs book + chat 48 apart, week strip, empty week), references/auto/retro/store/retro-store-01.png and -02.png (ST-01 /
// ST-02: populated strip, "Week 27  Jul 3 - 9", friend cards, action row with the gear capsule),
// references/auto/retro/store/editorial/retro-appstore-story-1840659619-albums.png (ED-A: friend-card pager).
package app.feature.account.groups

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
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.paddingFrom
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBars
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyListScope
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.Immutable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.SideEffect
import androidx.compose.runtime.derivedStateOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.snapshotFlow
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.layout.LastBaseline
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewModelScope
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.navigation.NavHostController
import app.data.error.DataError
import app.data.model.Group
import app.data.model.GroupKind
import app.data.model.Media
import app.data.model.Post
import app.data.offline.DataState
import app.data.realtime.GroupEvent
import app.data.repo.Member
import app.designsystem.R
import app.designsystem.generated.Tokens
import app.feature.account.AccountEnvironment
import app.feature.account.LocalAccountEnvironment
import app.feature.account.common.AccountViewModel
import app.feature.account.common.BookCover
import app.feature.account.common.CollectEvents
import app.feature.account.common.TapLine
import app.feature.account.common.dataError
import app.feature.memory.birthday.BirthdayRequestEntries
import app.feature.memory.onthisday.OnThisDayEntry
import app.feature.memory.openOnThisDay
import app.feature.memory.yearstory.YearStoryEntry
import app.feature.account.plans.PlanBlocked
import app.feature.account.plans.PlanEntries
import app.feature.account.plans.developingTile
import app.feature.account.plans.rememberGroupDeveloping
import app.feature.account.question.QuestionCardEntry
import app.model.AppRoute
import app.model.PhotoContext
import app.model.PhotoViewerIn
import app.model.PlanCreateRoute
import app.model.PlanRoute
import app.model.QuestionHandoff
import app.ui.components.Avatar
import app.ui.components.AvatarStack
import app.ui.components.Capsule
import app.ui.components.CapsuleRowSpacing
import app.ui.components.CapsuleStyle
import app.ui.components.DayTile
import app.ui.components.EmptyState
import app.ui.components.EmptyStateAction
import app.ui.components.FriendCard
import app.ui.components.GridCell
import app.ui.components.HeaderAction
import app.ui.components.IconCapsule
import app.ui.components.MediaPill
import app.ui.components.PhotoGrid
import app.ui.components.PushedHeader
import app.ui.components.SectionHeader
import app.ui.components.WeekStrip
import app.ui.components.WeekStripOrder
import app.ui.foundation.DsImage
import app.ui.foundation.GlyphInk
import app.ui.foundation.PageRoles
import app.ui.foundation.PhotoScrimOverlay
import app.ui.foundation.endAtLastBaseline
import app.ui.foundation.tapClickable
import app.ui.format.Formats
import app.ui.system.DsMenuItem
import app.ui.text.CapTop
import app.ui.text.TextRoles
import app.ui.text.capTopAt
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.flow.filter
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import java.time.DayOfWeek
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.format.TextStyle
import java.time.temporal.IsoFields
import java.time.temporal.TemporalAdjusters
import java.util.Locale

/** One photo of the group (newest first in [GroupFeedUiState.photos]). */
@Immutable
data class GroupPhoto(
    val post: Post,
    val url: String?,
    val authorFirstName: String?,
    val authorAvatarUrl: String?,
    val mine: Boolean,
)

@Immutable
data class GroupFeedUiState(
    val group: Group? = null,
    val coverUrl: String? = null,
    /** Null until the first page (cache or network) is known. */
    val photos: List<GroupPhoto>? = null,
    val isCreator: Boolean = false,
    /** Every member's avatar URL (null = no photo), joining order. */
    val memberAvatars: List<String?> = emptyList(),
    val error: DataError? = null,
    val removed: Boolean = false,
    val endReached: Boolean = false,
    /** Bumped by each `developing_changed` broadcast: the developing tile refetches `group_developing` (§14.3). */
    val developingVersion: Int = 0,
) {
    val loading: Boolean get() = photos == null && error == null && !removed
}

/** The group's week (group time zone, Monday start — `app_config.week_start_isodow`, docs/API.md §6.4). */
object GroupWeek {
    fun start(day: LocalDate): LocalDate = day.with(TemporalAdjusters.previousOrSame(DayOfWeek.MONDAY))
    fun end(day: LocalDate): LocalDate = start(day).plusDays(DAYS_IN_WEEK - 1)
    fun number(day: LocalDate): Int = day.get(IsoFields.WEEK_OF_WEEK_BASED_YEAR)
    fun zone(group: Group?, fallback: ZoneId): ZoneId = group?.timeZone?.let { runCatching { ZoneId.of(it) }.getOrNull() } ?: fallback

    private const val DAYS_IN_WEEK = 7L
}

/**
 * Cache-then-network: the group (cover signed URL), its members (avatars, first names) and its posts newest first
 * (`observeFeed`, then pages older than the last post), each post's display rendition signed; realtime inserts and
 * deletions update the list; a resumed subscription refetches (§8). `not_group_member` / a group missing from the
 * server's list = removed.
 */
class GroupFeedViewModel(private val env: AccountEnvironment, private val groupId: String) : AccountViewModel() {
    private val mutable = MutableStateFlow(GroupFeedUiState())
    val state: StateFlow<GroupFeedUiState> = mutable.asStateFlow()
    private var posts: List<Post> = emptyList()
    private var members: List<Member> = emptyList()
    private val urls = HashMap<String, String>()
    private var mediaById = HashMap<String, Media>()
    private var loadingMore = false

    init {
        load()
        viewModelScope.launch {
            env.backend.groupEvents(groupId).collect { event ->
                when (event) {
                    is GroupEvent.PostInserted -> if (posts.none { it.id == event.post.id }) {
                        posts = (listOf(event.post) + posts).sortedByDescending { it.createdAt }
                        enrich(listOf(event.post))
                        publish()
                    }
                    is GroupEvent.PostDeleted -> {
                        posts = posts.filterNot { it.id == event.postId }
                        publish()
                    }
                    // A post the screen holds changed (e.g. linked to the week's question by answer_question, which runs
                    // after create_post): keep the newer row.
                    is GroupEvent.PostUpdated -> if (posts.any { it.id == event.post.id }) {
                        posts = posts.map { if (it.id == event.post.id) event.post else it }
                        publish()
                    }
                    is GroupEvent.Subscribed -> if (event.resumed) load()
                    // Someone's 9 AM photo started developing, or the group's photos were revealed.
                    is GroupEvent.DevelopingChanged -> mutable.update { it.copy(developingVersion = it.developingVersion + 1) }
                    else -> Unit
                }
            }
        }
    }

    fun load() {
        viewModelScope.launch {
            env.backend.observeMyGroups().collect { page ->
                val group = page.value?.firstOrNull { it.id == groupId }
                if (group != null) {
                    val cover = group.coverPath?.let { path -> urls[path] ?: runCatching { env.backend.signedUrls(listOf(path)) }.getOrDefault(emptyMap())[path]?.also { urls[path] = it } }
                    mutable.update { it.copy(group = group, coverUrl = cover, isCreator = group.createdBy == env.backend.currentUserId) }
                } else if (page.value != null && page.source == DataState.Source.Network) {
                    // Loaded from the server and the group is not among yours: removed (or deleted).
                    mutable.update { it.copy(removed = true) }
                }
            }
        }
        viewModelScope.launch {
            env.backend.observeMembers(groupId).collect { page ->
                page.value?.let { list ->
                    members = list.sortedBy { it.member.joinedAt }
                    enrichMembers(members)
                    publish()
                }
            }
        }
        viewModelScope.launch {
            env.backend.observeFeed(groupId).collect { page ->
                val list = page.value
                if (list != null) {
                    posts = (list + posts.filter { old -> list.none { it.id == old.id } && old.createdAt < (list.lastOrNull()?.createdAt ?: Instant.MAX) }).sortedByDescending { it.createdAt }
                    if (!page.refreshing && list.size < app.data.repo.PostRepository.FEED_PAGE) mutable.update { it.copy(endReached = true) }
                    // Cached page first, then enriched (URLs, names) in place.
                    publish(error = page.error)
                    enrich(list)
                    publish(error = page.error)
                } else if (!page.refreshing) {
                    val error = page.error
                    val removed = (error as? DataError.Api)?.code == app.data.error.ApiError.NotGroupMember
                    mutable.update { it.copy(error = error, removed = it.removed || removed) }
                }
            }
        }
    }

    /** Next page (older than the last post) when the list nears its end. */
    fun loadMore() {
        val last = posts.lastOrNull() ?: return
        if (loadingMore || mutable.value.endReached) return
        loadingMore = true
        viewModelScope.launch {
            try {
                val page = env.backend.feedPage(groupId, last.createdAt)
                posts = (posts + page.filter { p -> posts.none { it.id == p.id } }).sortedByDescending { it.createdAt }
                enrich(page)
                mutable.update { it.copy(endReached = page.size < app.data.repo.PostRepository.FEED_PAGE) }
                publish()
            } catch (t: Throwable) {
                t.dataError()
            } finally {
                loadingMore = false
            }
        }
    }

    private suspend fun enrich(page: List<Post>) {
        val missing = page.map { it.mediaId }.filter { it !in mediaById }
        if (missing.isNotEmpty()) runCatching { env.backend.media(missing) }.getOrNull()?.forEach { mediaById[it.id] = it }
        val paths = page.mapNotNull { mediaById[it.mediaId]?.imagePath(Media.Rendition.Display) }.filter { it !in urls }
        if (paths.isNotEmpty()) urls.putAll(runCatching { env.backend.signedUrls(paths) }.getOrDefault(emptyMap()))
    }

    private suspend fun enrichMembers(list: List<Member>) {
        val paths = list.mapNotNull { it.profile?.avatarPath }.filter { it !in urls }
        if (paths.isNotEmpty()) urls.putAll(runCatching { env.backend.signedUrls(paths) }.getOrDefault(emptyMap()))
    }

    private fun publish(error: DataError? = mutable.value.error) {
        val me = env.backend.currentUserId
        val byUser = members.associateBy { it.member.userId }
        val photos = posts.map { p ->
            val author = byUser[p.authorId]?.profile
            GroupPhoto(
                post = p,
                url = mediaById[p.mediaId]?.imagePath(Media.Rendition.Display)?.let(urls::get),
                authorFirstName = author?.firstName,
                authorAvatarUrl = author?.avatarPath?.let(urls::get),
                mine = p.authorId == me,
            )
        }
        val avatars = members.map { m -> m.profile?.avatarPath?.let(urls::get) }
        mutable.update { it.copy(photos = photos, memberAvatars = avatars, error = error) }
    }
}

@Composable
fun GroupFeedRoute(nav: NavHostController, groupId: String) {
    val env = LocalAccountEnvironment.current
    val vm = viewModel(key = "feed:$groupId") { GroupFeedViewModel(env, groupId) }
    val state by vm.state.collectAsStateWithLifecycle()
    CollectEvents(vm.events, nav)
    // After safety.block returns: refetch (RLS now hides the blocked person's posts).
    val entry = nav.currentBackStackEntry
    LaunchedEffect(entry) {
        entry?.savedStateHandle?.getStateFlow<String?>(app.feature.account.safety.BLOCKED_RESULT_KEY, null)?.collect { blocked ->
            if (blocked != null) {
                entry.savedStateHandle.remove<String>(app.feature.account.safety.BLOCKED_RESULT_KEY)
                vm.load()
            }
        }
    }
    /** Whether a birthday request row is on screen (the plan row's placement). */
    var birthdayRowShown by remember(groupId) { mutableStateOf(false) }
    // The developing state refetches on each `developing_changed` broadcast (a 9 AM photo taken in the group, a reveal) and
    // when the newest post changes; the question card's newest answer refetches with the newest post.
    val newestPost = state.photos?.firstOrNull()?.post?.id
    val developing = rememberGroupDeveloping(groupId, newestPost to state.developingVersion)
    val answeredPosts = state.photos?.mapNotNull { photo -> photo.post.id.takeIf { photo.post.questionId != null } }
    GroupFeedScreen(
        state = state,
        now = env.clock.instant(),
        fallbackZone = env.zone(),
        developing = developingTile(developing),
        actions = GroupScreenActions(
            onBack = { nav.popBackStack() },
            onAlbums = { nav.navigate(AppRoute.AlbumsList(groupId)) },
            onChat = { nav.navigate(AppRoute.Chat(groupId)) },
            onMembers = { nav.navigate(AppRoute.GroupSettings(groupId)) },
            // "Recaps" opens the group's recap list sheet (week.recap list; social pass).
            onRecaps = { nav.navigate(app.model.WeekRecapList(groupId)) },
            onInvite = { nav.navigate(AppRoute.GroupInvite(groupId)) },
            onSettings = { nav.navigate(AppRoute.GroupSettings(groupId)) },
            onWeeks = { nav.navigate(AppRoute.WeekHistory(groupId)) },
            onPhoto = { nav.navigate(AppRoute.PhotoViewer(groupId, it.id)) },
            onReport = { nav.navigate(AppRoute.SafetyReport(groupId = groupId, postId = it.id)) },
            onBlock = { nav.navigate(AppRoute.SafetyBlock(it.authorId)) },
            onCamera = { nav.navigate(AppRoute.Camera(groupId)) },
            onRetry = vm::load,
            onLoadMore = vm::loadMore,
        ),
        // The memory pass's entries: copy and data are theirs; the row / card and its place are this screen's.
        birthdayRows = {
            var shown = false
            BirthdayRequestEntries(groupId, onOpen = { requestId -> nav.navigate(AppRoute.BirthdayContribute(groupId, requestId)) }) { title, subtitle, onClick ->
                shown = true
                BirthdayRequestRow(title, subtitle, avatar = null, onClick = onClick)
            }
            SideEffect { birthdayRowShown = shown }
        },
        // The plans pass's entry (the next plan with its "+", or "Make a Plan"). Its order next to a birthday request row
        // is BLOCKED (plans.md §12 item 6): release builds show it only while no birthday row is on screen (iOS as well).
        planRows = {
            if (PlanBlocked.besideBirthdayRow || !birthdayRowShown) PlanEntries(
                groupId,
                refreshKey = newestPost,
                onOpen = { planId -> nav.navigate(PlanRoute(planId, groupId)) },
                onCreate = { nav.navigate(PlanCreateRoute(groupId)) },
            )
        },
        feedCards = {
            // question.weekly A: the first feed card, after the friend cards, before the memory cards.
            QuestionCardEntry(
                groupId,
                // The newest post, and the posts linked to a question: answer_question links a photo after create_post,
                // so a new answer usually arrives as an update of a post the screen already shows.
                refreshKey = newestPost to answeredPosts,
                onAnswer = { questionId, key ->
                    nav.navigate(AppRoute.Camera(groupId))
                    nav.currentBackStackEntry?.savedStateHandle?.let { handle ->
                        handle[QuestionHandoff.QUESTION_ID] = questionId
                        handle[QuestionHandoff.QUESTION_KEY] = key
                    }
                },
                // The week's answers in this group, oldest first, in the viewer (question.weekly A, "See answers").
                onOpenAnswers = { questionId, oldestPostId -> nav.navigate(PhotoViewerIn(groupId, oldestPostId, PhotoContext.Question, questionId)) },
            )
            OnThisDayEntry(groupId, onOpen = { nav.openOnThisDay(groupId) }) { title, subtitle, button, onClick ->
                FeedEntryCard(Tokens.Icons.globalRewind, title, subtitle, button = button, photo = null, onClick = onClick)
            }
            YearStoryEntry(groupId, onOpen = { year -> nav.navigate(AppRoute.YearStory(groupId, year)) }) { title, subtitle, button, onClick ->
                FeedEntryCard(Tokens.Icons.globalRecap, title, subtitle, button = button, photo = null, onClick = onClick)
            }
        },
    )
}

/** Test tag of the screen's vertical list (UI tests scroll it; the week strip is a second scrollable list). */
const val GROUP_SCREEN_LIST_TAG = "groups.screen.list" // provenance-ok: test tag, not shown

/** What the group screen does on each control. */
@Immutable
data class GroupScreenActions(
    val onBack: () -> Unit = {},
    val onAlbums: () -> Unit = {},
    val onChat: () -> Unit = {},
    val onMembers: () -> Unit = {},
    val onRecaps: () -> Unit = {},
    val onInvite: () -> Unit = {},
    val onSettings: () -> Unit = {},
    val onWeeks: () -> Unit = {},
    val onPhoto: (Post) -> Unit = {},
    val onReport: (Post) -> Unit = {},
    val onBlock: (Post) -> Unit = {},
    val onCamera: () -> Unit = {},
    val onRetry: () -> Unit = {},
    val onLoadMore: () -> Unit = {},
)

@Composable
internal fun createdInviteLabel(kind: GroupKind): String = when (kind) {
    GroupKind.Friends -> stringResource(R.string.groups_screen_created_invite_friends)
    GroupKind.Family -> stringResource(R.string.groups_screen_created_invite_family)
    GroupKind.Roommates -> stringResource(R.string.groups_screen_created_invite_roommates)
    GroupKind.Custom -> stringResource(R.string.groups_screen_created_invite_custom)
}

/**
 * The group (pushed; page `color.global.background.android`; one vertical scroll):
 * 1. C-02 header row without a title — back, and the trailing `icon.global.albums` / `icon.global.chats` glyphs at the C-01
 *    positions (centred on the cap middle of a title at `size.global.titleTop`);
 * 2. the cover (C-24, `groups.screen.size.coverWidth` × `.coverHeight`, shadow `groups.screen.shadow.cover`),
 *    `size.global.titleToContent` below that title line, centred;
 * 3. the name (display serif `displayMedium`, centred, ≤ 2 lines), its cap top `groups.screen.size.coverToTitle` under the cover;
 * 4. the C-23 member stack `groups.screen.size.titleToMeta` under the name's baseline (as many as fit, no count) → members;
 * 5. `groups.screen.size.metaToActions` below: outline "Recaps", outline "Invite" (equal widths) and the gear capsule;
 * 6. the birthday request row(s) (`size.global.sectionGap` apart), then the plan row (release builds: only without a
 *    birthday row — order BLOCKED);
 * 7. this week: the C-20 header as one button (chevron → week.history), the C-17 strip (photos oldest → newest, add tile
 *    last; an empty week: add tile first, then empty-day tiles to the week's end) and, for an empty group, the C-27 block;
 * 8. the members' weeks (C-18 cards, newest first), the weekly question card and the memory feed cards in one pager,
 *    `size.global.cardGap` apart;
 * 9. earlier photos: dated C-20 headers over the 3-column C-21 grid, `size.global.sectionGap` apart, paged.
 */
@Composable
fun GroupFeedScreen(
    state: GroupFeedUiState,
    now: Instant,
    fallbackZone: ZoneId,
    actions: GroupScreenActions,
    birthdayRows: @Composable () -> Unit = {},
    feedCards: @Composable () -> Unit = {},
    planRows: @Composable () -> Unit = {},
    developing: DayTile? = null,
) {
    val zone = GroupWeek.zone(state.group, fallbackZone)
    val today = now.atZone(zone).toLocalDate()
    val bottom = WindowInsets.navigationBars.asPaddingValues().calculateBottomPadding() + Tokens.Sizes.globalSectionGap
    val list = rememberLazyListState()
    val photos = state.photos
    if (photos != null && photos.isNotEmpty()) {
        val nearEnd by remember { derivedStateOf { list.layoutInfo.visibleItemsInfo.lastOrNull()?.index?.let { it >= list.layoutInfo.totalItemsCount - PREFETCH_DISTANCE } ?: false } }
        LaunchedEffect(list) { snapshotFlow { nearEnd }.distinctUntilChanged().filter { it }.collect { actions.onLoadMore() } }
    }
    Box(Modifier.fillMaxSize().background(PageRoles.page).windowInsetsPadding(WindowInsets.statusBars)) {
        if (state.removed) {
            Column(Modifier.fillMaxSize()) {
                Header(actions, glyphs = false)
                Box(Modifier.weight(1f).fillMaxWidth(), contentAlignment = Alignment.Center) {
                    EmptyState(stringResource(R.string.groups_screen_removed_title), stringResource(R.string.groups_screen_removed_detail))
                }
            }
            return@Box
        }
        LazyColumn(state = list, modifier = Modifier.fillMaxSize().testTag(GROUP_SCREEN_LIST_TAG), contentPadding = PaddingValues(bottom = bottom)) {
            item(key = "header") { Header(actions, glyphs = true) }
            item(key = "cover") { Cover(state) }
            item(key = "name") { Name(state.group?.name) }
            when {
                state.loading -> {
                    item(key = "loadingStrip") { LoadingWeek() }
                    item(key = "loadingGrid") { LoadingGrid() }
                }
                photos == null && state.error == DataError.Network -> item(key = "offline") {
                    Box(Modifier.fillMaxWidth().padding(top = Tokens.Sizes.globalSectionGap), contentAlignment = Alignment.Center) {
                        EmptyState(stringResource(R.string.groups_screen_offline_title), stringResource(R.string.groups_screen_offline_detail))
                    }
                }
                photos == null -> {
                    item(key = "members") { Members(state.memberAvatars, actions.onMembers) }
                    item(key = "actions") { ActionRow(actions) }
                    item(key = "error") { TapLine(stringResource(R.string.groups_screen_error_title), actions.onRetry, Modifier.padding(top = Tokens.Sizes.globalSectionGap)) }
                }
                else -> loaded(state, photos, today, zone, actions, birthdayRows, feedCards, planRows, developing)
            }
        }
    }
}

private fun LazyListScope.loaded(
    state: GroupFeedUiState,
    photos: List<GroupPhoto>,
    today: LocalDate,
    zone: ZoneId,
    actions: GroupScreenActions,
    birthdayRows: @Composable () -> Unit,
    feedCards: @Composable () -> Unit,
    planRows: @Composable () -> Unit,
    developing: DayTile?,
) {
    val weekStart = GroupWeek.start(today)
    val thisWeek = photos.filter { !it.post.createdAt.atZone(zone).toLocalDate().isBefore(weekStart) }
    val earlier = photos.filter { it.post.createdAt.atZone(zone).toLocalDate().isBefore(weekStart) }
    item(key = "members") { Members(state.memberAvatars, actions.onMembers) }
    item(key = "actions") { ActionRow(actions) }
    item(key = "birthday") { Column { birthdayRows() } }
    item(key = "plans") { Column { planRows() } }
    item(key = "weekHeader") {
        val range = if (thisWeek.isEmpty()) null else Formats.weekRange(weekStart, GroupWeek.end(today), zone)
        WeekHeader(stringResource(R.string.groups_screen_week_title, GroupWeek.number(today).toString()), range, actions.onWeeks)
    }
    item(key = "strip") { WeekStrip(stripTiles(thisWeek, today, zone, actions, developing)) }
    if (photos.isEmpty()) {
        item(key = "emptyBlock") {
            Box(Modifier.fillMaxWidth().padding(top = Tokens.Sizes.globalSectionGap), contentAlignment = Alignment.Center) {
                if (state.isCreator) {
                    EmptyState(
                        title = stringResource(R.string.groups_screen_created_title),
                        detail = stringResource(R.string.groups_screen_created_detail),
                        icon = Tokens.Icons.globalCalendar,
                        action = EmptyStateAction(createdInviteLabel(state.group?.kind ?: GroupKind.Friends), actions.onInvite, Tokens.Icons.globalAdd),
                    )
                } else {
                    EmptyState(
                        title = stringResource(R.string.groups_screen_empty_title),
                        detail = stringResource(R.string.groups_screen_empty_detail),
                        icon = Tokens.Icons.globalCalendar,
                        action = EmptyStateAction(stringResource(R.string.groups_screen_empty_button), actions.onCamera, Tokens.Icons.globalAdd),
                    )
                }
            }
        }
    }
    item(key = "pager") { CardPager(friendWeeks(thisWeek), zone, actions, feedCards) }
    earlier.groupBy { it.post.createdAt.atZone(zone).toLocalDate() }.forEach { (day, dayPhotos) ->
        item(key = "day:$day", contentType = "day") {
            Column(Modifier.fillMaxWidth()) {
                SectionHeader(Formats.longDate(day), afterContent = true)
                PhotoGrid(dayPhotos.map { gridCell(it, zone, actions) }, columns = GRID_COLUMNS)
            }
        }
    }
}

/** C-02 without a title: back + (unless [glyphs] is false) the albums and chat glyphs at the C-01 places. */
@Composable
private fun Header(actions: GroupScreenActions, glyphs: Boolean) {
    PushedHeader(
        title = "",
        onBack = actions.onBack,
        backContentDescription = stringResource(R.string.groups_screen_back_accessibilitylabel),
        actions = if (!glyphs) {
            emptyList()
        } else {
            listOf(
                HeaderAction(Tokens.Icons.globalAlbums, stringResource(R.string.groups_screen_albums_accessibilitylabel), actions.onAlbums),
                HeaderAction(Tokens.Icons.globalChats, stringResource(R.string.groups_screen_chat), actions.onChat),
            )
        },
    )
}

@Composable
private fun Cover(state: GroupFeedUiState) {
    Box(Modifier.fillMaxWidth(), contentAlignment = Alignment.Center) {
        BookCover(
            state.coverUrl,
            Tokens.Sizes.groupsScreenSizeCoverWidth,
            Tokens.Sizes.groupsScreenSizeCoverHeight,
            contentDescription = state.group?.name?.let { stringResource(R.string.groups_screen_cover_accessibilitylabel, it) },
        )
    }
}

/** The name: text role `displayTitle` (`font.global.display` at `displayMedium`, L-8), centred, ≤ 2 lines, cap top `groups.screen.size.coverToTitle` under the cover; header trait. */
@Composable
private fun Name(name: String?) {
    val style = TextRoles.displayTitle
    Text(
        name.orEmpty(),
        style = style,
        color = Tokens.Colors.globalTextPrimary,
        textAlign = TextAlign.Center,
        maxLines = NAME_MAX_LINES,
        overflow = TextOverflow.Ellipsis,
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = Tokens.Sizes.globalScreenMargin)
            .capTopAt(Tokens.Sizes.groupsScreenSizeCoverToTitle, CapTop.height(style))
            .endAtLastBaseline()
            .semantics { heading() },
    )
}

/** The member stack (C-23, joining order, as many as fit the screen inside the margins — no "+N", no count): one button "Members". */
@Composable
private fun Members(avatars: List<String?>, onMembers: () -> Unit) {
    val width = LocalConfiguration.current.screenWidthDp.dp - Tokens.Sizes.globalScreenMargin * 2
    val avatar = Tokens.Sizes.globalAvatarSmall
    val fit = if (width < avatar) 0 else 1 + ((width - avatar) / (avatar - Tokens.Sizes.globalAvatarStackOverlap)).toInt()
    val label = stringResource(R.string.groups_screen_members_accessibilitylabel)
    Box(Modifier.fillMaxWidth().padding(top = Tokens.Sizes.groupsScreenSizeTitleToMeta), contentAlignment = Alignment.Center) {
        AvatarStack(
            avatars.take(fit),
            Modifier.tapClickable(onClick = onMembers).clearAndSetSemantics { contentDescription = label },
        )
    }
}

/** C-19 / C-06 action row: outline "Recaps" and "Invite" (equal widths), then the icon-only gear capsule; `size.global.pillGap` apart. */
@Composable
private fun ActionRow(actions: GroupScreenActions) {
    Row(
        Modifier.fillMaxWidth().padding(start = Tokens.Sizes.globalScreenMargin, end = Tokens.Sizes.globalScreenMargin, top = Tokens.Sizes.groupsScreenSizeMetaToActions),
        horizontalArrangement = CapsuleRowSpacing,
    ) {
        Capsule(stringResource(R.string.groups_screen_recap_accessibilitylabel), actions.onRecaps, Modifier.weight(1f), style = CapsuleStyle.Outline)
        Capsule(stringResource(R.string.groups_screen_invite), actions.onInvite, Modifier.weight(1f), style = CapsuleStyle.Outline)
        IconCapsule(Tokens.Icons.globalSettings, stringResource(R.string.groups_screen_settings_accessibilitylabel), actions.onSettings, style = CapsuleStyle.Outline)
    }
}

/**
 * The week header (C-20: "Week 43" in text role `sectionLabel` + the range in `listSubtitle`, secondary; no range for a
 * current week without photos), its cap top `size.global.sectionGap` below the content above, content
 * `size.global.sectionHeaderToContent` under its baseline; in place of C-20's "•••" (Retro's week menu was not captured)
 * `icon.global.chevron` in secondary text with its ink at the right margin. One button → week.history.
 */
@Composable
private fun WeekHeader(title: String, range: String?, onClick: () -> Unit) {
    val style = TextRoles.sectionLabel
    val secondary = PageRoles.secondaryText()
    val chevron = Tokens.Icons.globalChevron
    val weeksLabel = stringResource(R.string.groups_screen_weeks_accessibilitylabel)
    Row(
        Modifier
            .fillMaxWidth()
            .capTopAt(Tokens.Sizes.globalSectionGap, CapTop.height(style))
            .paddingFrom(LastBaseline, after = Tokens.Sizes.globalSectionHeaderToContent)
            .tapClickable(onClickLabel = weeksLabel, onClick = onClick)
            .semantics(mergeDescendants = true) { heading() }
            .padding(horizontal = Tokens.Sizes.globalScreenMargin),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            buildAnnotatedString {
                append(title)
                if (range != null) {
                    append(' ')
                    withStyle(TextRoles.listSubtitle.toSpanStyle().copy(color = secondary)) { append(range) }
                }
            },
            style = style,
            color = Tokens.Colors.globalTextPrimary,
            modifier = Modifier.weight(1f),
        )
        Icon(
            chevron,
            contentDescription = null,
            tint = secondary,
            modifier = Modifier.offset(x = GlyphInk.trailing(chevron, Tokens.Sizes.globalIcon)).size(Tokens.Sizes.globalIcon),
        )
    }
}

/**
 * The week strip's tiles: photos oldest → newest with the add tile last; an empty week: the add tile first, then empty-day
 * tiles from today to the week's end. While the group has photos developing, the one [developing] tile sits just before the
 * add tile (`camera.overnight.layout.developingTile`: the newest position).
 */
@Composable
private fun stripTiles(thisWeek: List<GroupPhoto>, today: LocalDate, zone: ZoneId, actions: GroupScreenActions, developing: DayTile? = null): List<DayTile> {
    val locale = Locale.getDefault()
    val add = DayTile.Add(stringResource(R.string.groups_screen_week_add_accessibilitylabel), actions.onCamera)
    val days: List<DayTile> = if (thisWeek.isNotEmpty()) {
        thisWeek.reversed().map { photo ->
            val day = photo.post.createdAt.atZone(zone).toLocalDate()
            DayTile.Photo(
                key = photo.post.id,
                image = photo.url,
                weekday = day.dayOfWeek.getDisplayName(TextStyle.SHORT, locale),
                accessibilityLabel = photoLabel(day, photo.authorFirstName),
                onClick = { actions.onPhoto(photo.post) },
                menu = photoMenu(photo, actions),
            )
        }
    } else {
        generateSequence(today) { it.plusDays(1) }.takeWhile { !it.isAfter(GroupWeek.end(today)) }.map { day ->
            DayTile.Empty(
                key = "empty:$day",
                month = day.month.getDisplayName(TextStyle.SHORT, locale),
                day = day.dayOfMonth.toString(),
                weekday = day.dayOfWeek.getDisplayName(TextStyle.SHORT, locale),
                accessibilityLabel = Formats.longDate(day),
            )
        }.toList()
    }
    val tiles = WeekStripOrder.withAdd(days, add)
    if (developing == null) return tiles
    val at = tiles.indexOfFirst { it is DayTile.Add }.coerceAtLeast(0)
    return tiles.subList(0, at) + developing + tiles.subList(at, tiles.size)
}

/** `groups.screen.photo.accessibilityLabel`: "{date}, photo by {first_name}". */
@Composable
private fun photoLabel(day: LocalDate, firstName: String?): String = stringResource(R.string.groups_screen_photo_accessibilitylabel, Formats.longDate(day), firstName.orEmpty())

/** `groups.screen.layout.menu`: others' photos — "Report Post", "Block {first_name}"; own photos: none. */
@Composable
private fun photoMenu(photo: GroupPhoto, actions: GroupScreenActions): List<DsMenuItem> {
    if (photo.mine) return emptyList()
    val report = DsMenuItem(stringResource(R.string.groups_screen_photo_menu_report), { actions.onReport(photo.post) }, icon = Tokens.Icons.globalReport, destructive = true)
    val name = photo.authorFirstName ?: return listOf(report)
    return listOf(report, DsMenuItem(stringResource(R.string.groups_screen_photo_menu_block, name), { actions.onBlock(photo.post) }, destructive = true))
}

@Composable
private fun gridCell(photo: GroupPhoto, zone: ZoneId, actions: GroupScreenActions): GridCell {
    val day = photo.post.createdAt.atZone(zone).toLocalDate()
    return GridCell(photo.post.id, photo.url, photoLabel(day, photo.authorFirstName), { actions.onPhoto(photo.post) }, photoMenu(photo, actions))
}

/** One member's week for a C-18 card: their newest photo of the week. */
private fun friendWeeks(thisWeek: List<GroupPhoto>): List<GroupPhoto> =
    thisWeek.filterNot { it.mine }.distinctBy { it.post.authorId }

/**
 * The members' weeks and memories pager: C-18 friend cards (newest first) and the memory feed cards, a horizontal row
 * starting at `size.global.screenMargin`, `size.global.cardGap` apart, the next card peeking; each card sits
 * `size.global.sectionGap` below the strip, so an empty pager takes no space.
 */
@Composable
private fun CardPager(friends: List<GroupPhoto>, zone: ZoneId, actions: GroupScreenActions, feedCards: @Composable () -> Unit) {
    Row(
        Modifier
            .fillMaxWidth()
            .horizontalScroll(rememberScrollState())
            .padding(horizontal = Tokens.Sizes.globalScreenMargin),
        horizontalArrangement = Arrangement.spacedBy(Tokens.Sizes.globalCardGap),
    ) {
        friends.forEach { photo ->
            val day = photo.post.createdAt.atZone(zone).toLocalDate()
            FriendCard(
                name = photo.authorFirstName.orEmpty(),
                avatar = photo.authorAvatarUrl,
                photo = photo.url,
                contentDescription = photoLabel(day, photo.authorFirstName),
                onClick = { actions.onPhoto(photo.post) },
                modifier = Modifier.padding(top = Tokens.Sizes.globalSectionGap),
            )
        }
        feedCards()
    }
}

/**
 * A memory feed card (Retro's Rewind / "Year in Photos" cards in its home feed; composition of C-18, C-09 and the display
 * role): the header line shows the feature's [glyph] in the `size.global.avatarList` box (no name), `size.global.cardHeaderGap`
 * above a `size.global.friendCardWidth` × `.friendCardHeight` card (`radius.global.card`) — the feature's [photo] aspect-fill
 * (none: `color.global.backgroundDeep`) under the bottom scrim (`layout.global.photoScrim`), and at the bottom inside
 * `size.global.screenMargin`: [title] (`font.global.display` text role `displaySmall`, `color.global.textOnMedia`), [line]
 * (`listSubtitle`, `color.global.textOnMedia`) and the C-09 light pill [button] `size.global.screenMargin` below (the inner
 * gaps are not measured). One button; the pill repeats the action.
 */
@Composable
fun FeedEntryCard(glyph: ImageVector, title: String, line: String, button: String?, photo: Any?, onClick: () -> Unit, modifier: Modifier = Modifier) {
    Column(
        modifier
            .padding(top = Tokens.Sizes.globalSectionGap)
            .width(Tokens.Sizes.globalFriendCardWidth)
            .tapClickable(onClick = onClick)
            .semantics(mergeDescendants = true) {},
    ) {
        Box(Modifier.size(Tokens.Sizes.globalAvatarList), contentAlignment = Alignment.Center) {
            Icon(glyph, contentDescription = null, tint = Tokens.Colors.globalTextPrimary, modifier = Modifier.size(Tokens.Sizes.globalAvatarList))
        }
        Spacer(Modifier.height(Tokens.Sizes.globalCardHeaderGap))
        Box(Modifier.size(Tokens.Sizes.globalFriendCardWidth, Tokens.Sizes.globalFriendCardHeight).clip(RoundedCornerShape(Tokens.Radii.globalCard))) {
            DsImage(photo, null, Modifier.fillMaxSize(), placeholder = Tokens.Colors.globalBackgroundDeep)
            PhotoScrimOverlay()
            Column(Modifier.align(Alignment.BottomStart).padding(Tokens.Sizes.globalScreenMargin)) {
                Text(title, style = TextRoles.displaySmall, color = Tokens.Colors.globalTextOnMedia)
                Text(line, style = TextRoles.listSubtitle, color = Tokens.Colors.globalTextOnMedia)
                if (button != null) MediaPill(button, onClick, Modifier.padding(top = Tokens.Sizes.globalScreenMargin))
            }
        }
    }
}

/**
 * The birthday request row (`birthday.request` entry): one C-14 single row inside the margins (fill
 * `color.global.surfaceSecondary.android`, `radius.global.groupedRow`) holding a C-16 people row — honoree avatar
 * `size.global.avatarPicker`, title (`listTitle`), due line (`listSubtitle`, secondary) — and `icon.global.chevron` in
 * secondary text; `size.global.sectionGap` under the content above. One button → birthday.request.
 */
@Composable
fun BirthdayRequestRow(title: String, line: String, avatar: Any?, onClick: () -> Unit) {
    val shape = RoundedCornerShape(Tokens.Radii.globalGroupedRow)
    val secondary = PageRoles.secondaryText()
    Row(
        Modifier
            .padding(start = Tokens.Sizes.globalScreenMargin, end = Tokens.Sizes.globalScreenMargin, top = Tokens.Sizes.globalSectionGap)
            .fillMaxWidth()
            .clip(shape)
            .background(PageRoles.secondarySurface, shape)
            .tapClickable(onClick = onClick)
            .semantics(mergeDescendants = true) {}
            .padding(Tokens.Sizes.globalScreenMargin),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Avatar(avatar, Tokens.Sizes.globalAvatarPicker)
        Spacer(Modifier.width(Tokens.Sizes.globalRowThumbGap))
        Column(Modifier.weight(1f)) {
            Text(title, style = TextRoles.listTitle, color = Tokens.Colors.globalTextPrimary)
            Text(line, style = TextRoles.listSubtitle, color = secondary)
        }
        Icon(Tokens.Icons.globalChevron, contentDescription = null, tint = secondary, modifier = Modifier.size(Tokens.Sizes.globalIcon))
    }
}

/** Loading (C-28 placeholder form): the week header line's place and a strip of C-17 placeholder tiles. */
@Composable
private fun LoadingWeek() {
    Column(Modifier.fillMaxWidth().padding(top = Tokens.Sizes.globalSectionGap)) {
        WeekStrip(List(LOADING_TILES) { DayTile.Placeholder("placeholder:$it") })
    }
}

/** Loading: a grid of `color.global.control` cells (C-21 with no photos yet). */
@Composable
private fun LoadingGrid() {
    PhotoGrid(List(LOADING_CELLS) { GridCell("loading:$it", null, "") }, columns = GRID_COLUMNS, modifier = Modifier.padding(top = Tokens.Sizes.globalSectionGap).clearAndSetSemantics { })
}

private const val NAME_MAX_LINES = 2
private const val GRID_COLUMNS = 3
private const val LOADING_TILES = 4
private const val LOADING_CELLS = 6
private const val PREFETCH_DISTANCE = 3
