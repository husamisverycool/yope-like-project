// Surface: groups.list — the group list (home). Spec: design/surfaces/groups.list.md.
// References: references/auto/retro/store/editorial/retro-appstore-story-1854931006-week3-albums.png (ED-W3: row pitch 119.5,
// 72 × 97 covers, subtitle with the actor in semibold, avatar stack, 36-pt "+" circle, new-album glyph),
// references/auto/retro/press/tc-2024-04-journals-1.webp (TC-J1 phone 2: serif title), references/auto/retro/press/
// jeddacp-2024-05-home-profile-journals.png (JED phone 3: "Ideas to Get Started" template rows with a Fill "Create" capsule),
// references/auto/retro/lazyweb/retro-lazyweb-20251020-week43-dark.png and …-20260528-week22-dark-a.png (H43 / H22: title, tab bar).
package app.feature.account.groups

import androidx.annotation.DrawableRes
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.asPaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBars
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.runtime.Composable
import androidx.compose.runtime.Immutable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.LifecycleResumeEffect
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewModelScope
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.navigation.NavController
import app.data.error.DataError
import app.data.model.Group
import app.data.model.GroupKind
import app.data.model.Post
import app.data.offline.DataState
import app.data.realtime.GroupEvent
import app.designsystem.R
import app.designsystem.generated.Tokens
import app.feature.account.R as AccountR
import app.feature.account.AccountEnvironment
import app.feature.account.LocalAccountEnvironment
import app.feature.account.common.AccountViewModel
import app.feature.account.common.CollectEvents
import app.feature.account.common.TapLine
import app.feature.account.common.dataError
import app.model.AppRoute
import app.model.GroupCreateKindRoute
import app.ui.components.Capsule
import app.ui.components.CapsuleStyle
import app.ui.components.EmptyState
import app.ui.components.EmptyStateAction
import app.ui.components.HeaderAction
import app.ui.components.ScreenHeader
import app.ui.components.SectionHeader
import app.ui.components.ThumbnailRow
import app.ui.components.ThumbnailRowSpacing
import app.ui.components.subtitleWithActor
import app.ui.foundation.DsMotion
import app.ui.foundation.PageRoles
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.async
import kotlinx.coroutines.awaitAll
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.flatMapLatest
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.merge
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import java.time.Instant
import java.util.concurrent.ConcurrentHashMap

/** What a row's subtitle says (`groups.list.row.*`); the actor ({first_name} or "you") is set in semibold. */
@Immutable
sealed interface RowSubtitle {
    /** No posts and the creator is unknown: "group created". */
    data object NoPics : RowSubtitle

    /** Newest post is yours: "you shared a post". */
    data object NewPic : RowSubtitle

    /** Newest post by someone else: "{first_name} shared a post". */
    data class SentPic(val firstName: String) : RowSubtitle

    /** No posts, you created it: "you created the group". */
    data object CreatedByYou : RowSubtitle

    /** No posts, someone else created it: "{first_name} created the group". */
    data class CreatedBy(val firstName: String) : RowSubtitle
}

/** The newest activity of one group, its creator's first name and its members' avatars (joining order). */
@Immutable
data class RowDetail(val newest: Post?, val senderFirstName: String?, val creatorFirstName: String?, val coverUrl: String?, val memberAvatars: List<String?>)

@Immutable
data class GroupRow(
    val id: String,
    val name: String,
    val coverUrl: String?,
    val subtitle: RowSubtitle?,
    val activityAt: Instant,
    /** Members' avatar URLs (null = no photo), joining order. */
    val avatars: List<String?> = emptyList(),
)

@Immutable
data class GroupsListUiState(
    /** Null until the first page (cache or network) is known. */
    val rows: List<GroupRow>? = null,
    val refreshing: Boolean = true,
    val error: DataError? = null,
) {
    val loading: Boolean get() = rows == null && error == null
    val offline: Boolean get() = error == DataError.Network
}

/**
 * Cache-then-network group list (`GroupRepository.observeMyGroups`), per group the newest post
 * (`posts … order(created_at desc) limit 1`), the sender's or creator's first name, the members' avatars (joining order)
 * and signed URLs; realtime post inserts / deletions refresh that group's row and the order; refetch on (re)subscription.
 */
@OptIn(ExperimentalCoroutinesApi::class)
class GroupsListViewModel(private val env: AccountEnvironment) : AccountViewModel() {
    private val mutable = MutableStateFlow(GroupsListUiState())
    val state: StateFlow<GroupsListUiState> = mutable.asStateFlow()
    private val groups = MutableStateFlow<List<Group>>(emptyList())

    init {
        load()
        // Optimistic leave (GroupActions.leave): hide at once, restore if the server refuses.
        viewModelScope.launch { env.optimistic.leftGroups.collect { if (mutable.value.rows != null) publish(groups.value, mutable.value.refreshing, mutable.value.error) } }
        viewModelScope.launch {
            groups.map { list -> list.map { it.id }.toSet() }.distinctUntilChanged().flatMapLatest { ids ->
                merge(*ids.map { id -> env.backend.groupEvents(id) }.toTypedArray())
            }.collect { event ->
                when (event) {
                    is GroupEvent.PostInserted, is GroupEvent.PostDeleted -> refreshDetail(event.groupId)
                    is GroupEvent.Subscribed -> if (event.resumed) refreshDetail(event.groupId)
                    else -> Unit
                }
            }
        }
    }

    fun refresh() = load()

    private var resumedOnce = false

    /** Back on screen (from a group, after creating or leaving one, app foreground): refetch in place (§8.3). */
    fun onResume() {
        if (resumedOnce) load() else resumedOnce = true
    }

    private fun load() {
        viewModelScope.launch {
            env.backend.observeMyGroups().collect { page -> apply(page) }
        }
    }

    private suspend fun apply(page: DataState<List<Group>>) {
        val list = page.value
        if (list == null) {
            mutable.update { it.copy(refreshing = page.refreshing, error = if (page.refreshing) null else page.error) }
            return
        }
        groups.value = list
        // Cached rows first, with whatever activity is already known (no empty frame, no spinner).
        publish(list, page.refreshing, page.error)
        val fresh = coroutineScope { list.map { g -> async { g.id to runCatching { detail(g) }.getOrNull() } }.awaitAll() }
        fresh.forEach { (id, detail) -> if (detail != null) Details.byGroup[id] = detail }
        publish(list, page.refreshing, page.error)
    }

    private suspend fun refreshDetail(groupId: String) {
        val group = groups.value.firstOrNull { it.id == groupId } ?: return
        runCatching { detail(group) }.getOrNull()?.let { Details.byGroup[groupId] = it }
        publish(groups.value, mutable.value.refreshing, mutable.value.error)
    }

    private suspend fun detail(group: Group): RowDetail {
        val newest = try {
            env.backend.newestPost(group.id)
        } catch (t: Throwable) {
            t.dataError()
            Details.byGroup[group.id]?.newest
        }
        val me = env.backend.currentUserId
        val members = runCatching {
            env.backend.observeMembers(group.id).first { it.value != null || !it.refreshing }.value.orEmpty()
        }.getOrDefault(emptyList()).sortedBy { it.member.joinedAt }
        val byId = members.associateBy { it.member.userId }
        suspend fun firstName(userId: String): String? =
            byId[userId]?.profile?.firstName ?: runCatching { env.backend.profiles(listOf(userId)).firstOrNull()?.firstName }.getOrNull()
        val sender = newest?.takeIf { it.authorId != me }?.let { firstName(it.authorId) }
        val creator = if (newest == null) group.createdBy?.takeIf { it != me }?.let { firstName(it) } else null
        val paths = listOfNotNull(group.coverPath) + members.mapNotNull { it.profile?.avatarPath }
        val urls = runCatching { env.backend.signedUrls(paths) }.getOrDefault(emptyMap())
        return RowDetail(
            newest = newest,
            senderFirstName = sender,
            creatorFirstName = creator,
            coverUrl = group.coverPath?.let(urls::get),
            memberAvatars = members.map { m -> m.profile?.avatarPath?.let(urls::get) },
        )
    }

    private fun publish(list: List<Group>, refreshing: Boolean, error: DataError?) {
        val me = env.backend.currentUserId
        val left = env.optimistic.leftGroups.value
        val rows = list.filterNot { it.id in left }.map { g ->
            val d = Details.byGroup[g.id]
            val subtitle: RowSubtitle? = when {
                d == null -> null
                d.newest != null && (d.newest.authorId == me || d.senderFirstName == null) -> RowSubtitle.NewPic
                d.newest != null -> RowSubtitle.SentPic(d.senderFirstName!!)
                g.createdBy == me -> RowSubtitle.CreatedByYou
                d.creatorFirstName != null -> RowSubtitle.CreatedBy(d.creatorFirstName)
                else -> RowSubtitle.NoPics
            }
            GroupRow(g.id, g.name, d?.coverUrl, subtitle, maxOf(d?.newest?.createdAt ?: g.createdAt, g.createdAt), d?.memberAvatars.orEmpty())
        }.sortedByDescending { it.activityAt }
        mutable.update { it.copy(rows = rows, refreshing = refreshing, error = error) }
    }

    /** Known activity per group, kept for the process so coming back to the list never reorders or flashes (tests clear it). */
    object Details {
        val byGroup = ConcurrentHashMap<String, RowDetail>()
    }
}

/** Space the tab bar (C-04, the shell's) takes over the list: `size.global.tabBarHeight` above the navigation bar. */
val TabBarClearance: Dp get() = Tokens.Sizes.globalTabBarHeight + Tokens.Sizes.globalTabBarInset

@Composable
fun GroupsListRoute(nav: NavController) {
    val env = LocalAccountEnvironment.current
    val vm = viewModel { GroupsListViewModel(env) }
    val state by vm.state.collectAsStateWithLifecycle()
    CollectEvents(vm.events, nav)
    LifecycleResumeEffect(vm) {
        vm.onResume()
        onPauseOrDispose { }
    }
    GroupsListScreen(
        state = state,
        onRefresh = vm::refresh,
        onOpenGroup = { nav.navigate(AppRoute.Group(it)) },
        onCamera = { nav.navigate(AppRoute.Camera(it)) },
        onCreate = { nav.navigate(AppRoute.GroupCreate) },
        onTemplate = { nav.navigate(GroupCreateKindRoute(it.wire)) },
        onSearch = { nav.navigate(app.model.SearchPhotos(null)) },
    )
}

/**
 * The home list (page `color.global.background.android`; vertical scroll; the shell's C-04 tab bar over the bottom):
 * C-01 header — serif "Groups" and the trailing `icon.global.newAlbum` → groups.create; `size.global.titleToContent` below,
 * C-15 rows (newest activity first, thumbnails `size.global.listGap` apart): cover 72 × 97 (no cover: `color.global.control`
 * with `icon.global.group`), name (one line, tail truncation), subtitle with the actor in semibold, the C-23 member stack
 * (as many as fit, no count), the "+" circle → the camera for that group; `size.global.sectionGap` below, the C-20
 * "Ideas to Get Started" header and one template row per `group_kind` (the kind's cover photo, ≤ 2-line description, C-06
 * fill capsule "Create" → groups.create with that kind). Rows fade in / reorder with the house fade.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun GroupsListScreen(
    state: GroupsListUiState,
    onRefresh: () -> Unit,
    onOpenGroup: (String) -> Unit,
    onCamera: (String) -> Unit,
    onCreate: () -> Unit,
    onTemplate: (GroupKind) -> Unit,
    onSearch: () -> Unit = {},
) {
    val bottom = WindowInsets.navigationBars.asPaddingValues().calculateBottomPadding() + TabBarClearance
    // While you have a group: search (`search.photos` over all your groups — Yope's search on its group list), then new group.
    val search = stringResource(R.string.search_photos_open)
    val add = stringResource(R.string.groups_list_header_add_accessibilitylabel)
    val hasGroups = !state.rows.isNullOrEmpty()
    val header = @Composable {
        ScreenHeader(
            stringResource(R.string.groups_list_title),
            actions = listOfNotNull(
                if (hasGroups) HeaderAction(Tokens.Icons.globalSearch, search, onSearch) else null,
                HeaderAction(Tokens.Icons.globalNewAlbum, add, onCreate),
            ),
        )
    }
    Box(Modifier.fillMaxSize().background(PageRoles.page).windowInsetsPadding(WindowInsets.statusBars)) {
        val rows = state.rows
        when {
            state.loading -> Column(Modifier.fillMaxSize()) {
                header()
                LoadingRows()
            }
            rows == null && state.offline -> Column(Modifier.fillMaxSize().padding(bottom = bottom)) {
                header()
                Box(Modifier.weight(1f).fillMaxWidth(), contentAlignment = Alignment.Center) {
                    EmptyState(stringResource(R.string.groups_list_offline_title), stringResource(R.string.groups_list_offline_detail))
                }
            }
            rows == null -> Column(Modifier.fillMaxSize()) {
                header()
                TapLine(stringResource(R.string.groups_list_error_title), onRefresh)
            }
            else -> PullToRefreshBox(isRefreshing = false, onRefresh = onRefresh, modifier = Modifier.fillMaxSize()) {
                LazyColumn(Modifier.fillMaxSize(), contentPadding = PaddingValues(bottom = bottom)) {
                    item(key = "header", contentType = "header") { header() }
                    if (rows.isEmpty()) {
                        item(key = "empty", contentType = "empty") {
                            Box(Modifier.fillMaxWidth().padding(vertical = Tokens.Sizes.globalSectionGap), contentAlignment = Alignment.Center) {
                                EmptyState(
                                    title = stringResource(R.string.groups_list_empty_title),
                                    detail = stringResource(R.string.groups_list_empty_detail),
                                    icon = Tokens.Icons.globalAlbums,
                                    action = EmptyStateAction(stringResource(R.string.groups_list_empty_button), onCreate, Tokens.Icons.globalAdd),
                                )
                            }
                        }
                    }
                    itemsIndexed(rows, key = { _, row -> row.id }, contentType = { _, _ -> "group" }) { index, row ->
                        // Thumbnails `size.global.listGap` apart (the header already ends `size.global.titleToContent` below its baseline).
                        GroupListRow(
                            row,
                            Modifier
                                .animateItem(fadeInSpec = DsMotion.fade(), placementSpec = null, fadeOutSpec = DsMotion.crossfade())
                                .padding(top = if (index == 0) 0.dp else Tokens.Sizes.globalListGap),
                            onOpenGroup,
                            onCamera,
                        )
                    }
                    item(key = "ideas", contentType = "ideas") {
                        SectionHeader(stringResource(R.string.groups_list_ideas_title), afterContent = rows.isNotEmpty())
                    }
                    itemsIndexed(GroupKind.entries, key = { _, kind -> "idea:" + kind.wire }, contentType = { _, _ -> "idea" }) { index, kind ->
                        TemplateRow(kind, onTemplate, Modifier.padding(top = if (index == 0) 0.dp else Tokens.Sizes.globalListGap))
                    }
                }
            }
        }
    }
}

/** One group (C-15 + C-23 + C-11 "+"): one button (name + subtitle); the "+" is a separate labelled button. */
@Composable
private fun GroupListRow(row: GroupRow, modifier: Modifier, onOpen: (String) -> Unit, onCamera: (String) -> Unit) {
    val subtitle = row.subtitle?.let { rowSubtitle(it) }
    ThumbnailRow(
        title = row.name,
        subtitle = subtitle,
        thumbnail = row.coverUrl,
        onClick = { onOpen(row.id) },
        modifier = modifier,
        avatars = row.avatars.take(avatarsThatFit()),
        add = HeaderAction(Tokens.Icons.globalAdd, stringResource(R.string.groups_list_row_camera_accessibilitylabel, row.name)) { onCamera(row.id) },
        contentDescription = stringResource(R.string.groups_list_row_accessibilitylabel, row.name, subtitle?.text.orEmpty()),
        thumbnailFallback = Tokens.Icons.globalGroup,
        titleMaxLines = 1,
    )
}

/** The row subtitle with its actor in semibold (C-15 `subtitleWithActor`). */
@Composable
internal fun rowSubtitle(subtitle: RowSubtitle): AnnotatedString {
    // "you" is the people-row label for yourself (`groups.settings.members.you`), found in the sentence whatever its case.
    val you = stringResource(R.string.groups_settings_members_you)
    fun withYou(text: String): AnnotatedString {
        val at = text.indexOf(you, ignoreCase = true)
        return if (at < 0) AnnotatedString(text) else subtitleWithActor(text, text.substring(at, at + you.length))
    }
    return when (subtitle) {
        RowSubtitle.NoPics -> AnnotatedString(stringResource(R.string.groups_list_row_nopics))
        RowSubtitle.NewPic -> withYou(stringResource(R.string.groups_list_row_newpic))
        is RowSubtitle.SentPic -> subtitleWithActor(stringResource(R.string.groups_list_row_sentpic, subtitle.firstName), subtitle.firstName)
        RowSubtitle.CreatedByYou -> withYou(stringResource(R.string.groups_list_row_createdbyyou))
        is RowSubtitle.CreatedBy -> subtitleWithActor(stringResource(R.string.groups_list_row_createdby, subtitle.firstName), subtitle.firstName)
    }
}

/**
 * How many `size.global.avatarSmall` avatars (overlapping `size.global.avatarStackOverlap`) fit the C-15 text column: the
 * screen width less the margins, the cover, its gap and the "+" circle. No "+N" and no count (tenets).
 */
@Composable
private fun avatarsThatFit(): Int {
    val width = LocalConfiguration.current.screenWidthDp.dp
    val column = width - Tokens.Sizes.globalScreenMargin * 2 - Tokens.Sizes.globalRowThumbWidth - Tokens.Sizes.globalRowThumbGap - Tokens.Sizes.globalCircleButton
    val avatar = Tokens.Sizes.globalAvatarSmall
    val pitch = avatar - Tokens.Sizes.globalAvatarStackOverlap
    return if (column < avatar) 0 else 1 + ((column - avatar) / pitch).toInt()
}

/**
 * A template ("Ideas to Get Started"): C-15 geometry with the kind's cover photo (`groups.list.layout.templateCovers`,
 * owner decision 9 — people-free Unsplash photos bundled in drawable-nodpi, aspect-fill) and the C-06 fill capsule "Create".
 */
@Composable
internal fun TemplateRow(kind: GroupKind, onCreate: (GroupKind) -> Unit, modifier: Modifier = Modifier) {
    val (title, detail) = kindCopy(kind)
    ThumbnailRow(
        title = title,
        subtitle = AnnotatedString(detail),
        thumbnail = painterResource(templateCover(kind)),
        onClick = { onCreate(kind) },
        modifier = modifier,
        subtitleMaxLines = 2,
        trailing = { Capsule(stringResource(R.string.groups_create_type_create), { onCreate(kind) }, style = CapsuleStyle.Fill) },
    )
}

/**
 * The cover of a kind's template (`groups.list.layout.templateCovers`: the drawable named by the token's field for the
 * kind; `TemplateCoverTest` keeps the names equal).
 */
@DrawableRes
internal fun templateCover(kind: GroupKind): Int = when (kind) {
    GroupKind.Friends -> AccountR.drawable.template_cover_friends
    GroupKind.Family -> AccountR.drawable.template_cover_family
    GroupKind.Roommates -> AccountR.drawable.template_cover_roommates
    GroupKind.Custom -> AccountR.drawable.template_cover_custom
}

/** Title and description of a group kind's template (`groups.create.type.<kind>` / `.detail`). */
@Composable
internal fun kindCopy(kind: GroupKind): Pair<String, String> = when (kind) {
    GroupKind.Friends -> stringResource(R.string.groups_create_type_friends) to stringResource(R.string.groups_create_type_friends_detail)
    GroupKind.Family -> stringResource(R.string.groups_create_type_family) to stringResource(R.string.groups_create_type_family_detail)
    GroupKind.Roommates -> stringResource(R.string.groups_create_type_roommates) to stringResource(R.string.groups_create_type_roommates_detail)
    GroupKind.Custom -> stringResource(R.string.groups_create_type_custom) to stringResource(R.string.groups_create_type_custom_detail)
}

/** Loading (C-28 placeholder form): three C-15 rows whose thumbnails are `color.global.control` placeholders, no text. */
@Composable
private fun LoadingRows() {
    val shape = RoundedCornerShape(Tokens.Radii.globalThumbnail)
    Column(verticalArrangement = ThumbnailRowSpacing) {
        repeat(LOADING_ROWS) {
            Row(Modifier.fillMaxWidth().padding(horizontal = Tokens.Sizes.globalScreenMargin).clearAndSetSemantics { }) {
                Box(Modifier.size(Tokens.Sizes.globalRowThumbWidth, Tokens.Sizes.globalRowThumbHeight).clip(shape).background(Tokens.Colors.globalControl, shape))
            }
        }
    }
}

/** groups.list States → loading: "three C-15 rows". */
private const val LOADING_ROWS = 3
