// Surface: groups.list — group list / home. Spec: design/surfaces/groups.list.md.
// References: references/auto/yope/frames/a-savannahclooney-7683341732695592206-t6.73-home-list.png (H1),
// a-virgi-7686278541255642390-t40.23-home-list-es.png (H2), a-itsmthuyope-7644974799302823175-t44.23-home-list-new-group-icon.png (H3),
// a-chuongxetank-7694968408424582452-t7.73-posted-toast-contacts-card.png (H4), references/auto/yope/store/yope-store-02.png (TB),
// references/auto/yope/web/a-bi-2025-onboarding-composite.jpg (BI).
package app.feature.account.groups

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
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
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBars
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.runtime.Composable
import androidx.compose.runtime.Immutable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.text.withStyle
import androidx.lifecycle.compose.LifecycleResumeEffect
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewModelScope
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.navigation.NavController
import app.data.error.DataError
import app.data.model.Group
import app.data.model.Media
import app.data.model.Post
import app.data.offline.DataState
import app.data.realtime.GroupEvent
import app.designsystem.R
import app.designsystem.generated.Tokens
import app.feature.account.AccountEnvironment
import app.feature.account.LocalAccountEnvironment
import app.feature.account.blocked.BlockedValues
import app.feature.account.common.AccountViewModel
import app.feature.account.common.CollectEvents
import app.feature.account.common.dataError
import app.model.AppRoute
import app.ui.components.AccentTitle
import app.ui.components.Avatar
import app.ui.components.EmptyState
import app.ui.components.EmptyStateAction
import app.ui.components.HeaderCircleButton
import app.ui.components.HeaderCircleFill
import app.ui.components.LoadingHud
import app.ui.components.PrimaryButton
import app.ui.components.TitleSplit
import app.ui.format.Formats
import app.ui.text.TextRoles
import coil3.compose.AsyncImage
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.async
import kotlinx.coroutines.awaitAll
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.flow.flatMapLatest
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.merge
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import java.time.Instant
import java.time.ZoneId
import java.util.concurrent.ConcurrentHashMap

/** What a card's subtitle says (`groups.list.row.*`). */
@Immutable
sealed interface RowSubtitle {
    data object NoPics : RowSubtitle
    data class NewPic(val at: Instant) : RowSubtitle
    data class SentPic(val firstName: String, val at: Instant) : RowSubtitle
}

/** The newest activity of one group, as the card and the cover need it. */
@Immutable
data class RowDetail(val newest: Post?, val senderFirstName: String?, val coverUrl: String?, val photoUrl: String?)

@Immutable
data class GroupRow(val id: String, val name: String, val coverUrl: String?, val subtitle: RowSubtitle?, val activityAt: Instant)

@Immutable
data class CoverPhoto(val groupId: String, val postId: String, val url: String?, val firstName: String?, val groupName: String)

@Immutable
data class GroupsListUiState(
    /** Null until the first page (cache or network) is known. */
    val rows: List<GroupRow>? = null,
    val cover: CoverPhoto? = null,
    val refreshing: Boolean = true,
    val error: DataError? = null,
) {
    val loading: Boolean get() = rows == null && error == null
    val offline: Boolean get() = error == DataError.Network
}

/**
 * Cache-then-network group list (`GroupRepository.observeMyGroups`), the newest post of each group
 * (`posts … order(created_at desc) limit 1`), sender first names and signed URLs; realtime post
 * inserts / deletions refresh that group's card and the cover; refetch on (re)subscription.
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
        val firstName = newest?.takeIf { it.authorId != me }?.let { post ->
            runCatching { env.backend.profiles(listOf(post.authorId)).firstOrNull()?.firstName }.getOrNull()
        }
        val media: Media? = newest?.let { post -> runCatching { env.backend.media(listOf(post.mediaId)).firstOrNull() }.getOrNull() }
        val paths = listOfNotNull(group.coverPath, media?.imagePath(Media.Rendition.Display))
        val urls = runCatching { env.backend.signedUrls(paths) }.getOrDefault(emptyMap())
        return RowDetail(
            newest = newest,
            senderFirstName = firstName,
            coverUrl = group.coverPath?.let(urls::get),
            photoUrl = media?.imagePath(Media.Rendition.Display)?.let(urls::get),
        )
    }

    private fun publish(list: List<Group>, refreshing: Boolean, error: DataError?) {
        val me = env.backend.currentUserId
        val left = env.optimistic.leftGroups.value
        val visible = list.filterNot { it.id in left }
        val rows = visible.map { g ->
            val d = Details.byGroup[g.id]
            val subtitle: RowSubtitle? = when {
                d == null -> null
                d.newest == null -> RowSubtitle.NoPics
                d.newest.authorId == me || d.senderFirstName == null -> RowSubtitle.NewPic(d.newest.createdAt)
                else -> RowSubtitle.SentPic(d.senderFirstName, d.newest.createdAt)
            }
            GroupRow(g.id, g.name, d?.coverUrl, subtitle, maxOf(d?.newest?.createdAt ?: g.createdAt, g.createdAt))
        }.sortedByDescending { it.activityAt }
        val newest = visible.mapNotNull { g -> Details.byGroup[g.id]?.let { d -> d.newest?.let { p -> Triple(g, d, p) } } }.maxByOrNull { it.third.createdAt }
        val cover = newest?.let { (g, d, p) -> CoverPhoto(g.id, p.id, d.photoUrl, d.senderFirstName, g.name) }
        mutable.update { it.copy(rows = rows, cover = cover, refreshing = refreshing, error = error) }
    }

    /** Known activity per group, kept for the process so coming back to the list never reorders or flashes (tests clear it). */
    object Details {
        val byGroup = ConcurrentHashMap<String, RowDetail>()
    }
}

/** Space the floating tab bar takes over the list (`size.global.tabBarHeight` + `.tabBarInset`). */
val TabBarClearance = Tokens.Sizes.globalTabBarHeight + Tokens.Sizes.globalTabBarInset

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
        zone = env.zone(),
        onRefresh = vm::refresh,
        onOpenGroup = { nav.navigate(AppRoute.Group(it)) },
        onCamera = { nav.navigate(AppRoute.Camera(it)) },
        onCreate = { nav.navigate(AppRoute.GroupCreate) },
        onCover = { nav.navigate(AppRoute.PhotoViewer(it.groupId, it.postId)) },
    )
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun GroupsListScreen(
    state: GroupsListUiState,
    zone: ZoneId,
    onRefresh: () -> Unit,
    onOpenGroup: (String) -> Unit,
    onCamera: (String) -> Unit,
    onCreate: () -> Unit,
    onCover: (CoverPhoto) -> Unit,
) {
    val bottom = WindowInsets.navigationBars.asPaddingValues().calculateBottomPadding() + TabBarClearance
    Box(Modifier.fillMaxSize().background(Tokens.Colors.globalBackgroundDeep)) {
        val rows = state.rows
        when {
            state.loading -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) { LoadingHud(stringResource(R.string.groups_create_hud_loading)) }
            rows == null && state.offline -> CenteredHome(bottom) {
                EmptyState(stringResource(R.string.groups_list_offline_title), stringResource(R.string.groups_list_offline_detail))
            }
            rows == null -> CenteredHome(bottom) {
                EmptyState(
                    stringResource(R.string.groups_list_error_title),
                    stringResource(R.string.groups_list_error_detail),
                    action = EmptyStateAction(stringResource(R.string.groups_list_error_retry), onRefresh),
                )
            }
            rows.isEmpty() -> EmptyHome(bottom, onCreate)
            else -> PullToRefreshBox(isRefreshing = false, onRefresh = onRefresh, modifier = Modifier.fillMaxSize()) {
                GroupsListContent(rows, state.cover, zone, bottom, onOpenGroup, onCamera, onCreate, onCover)
            }
        }
    }
}

@Composable
private fun GroupsListContent(
    rows: List<GroupRow>,
    cover: CoverPhoto?,
    zone: ZoneId,
    bottom: androidx.compose.ui.unit.Dp,
    onOpenGroup: (String) -> Unit,
    onCamera: (String) -> Unit,
    onCreate: () -> Unit,
    onCover: (CoverPhoto) -> Unit,
) {
    LazyColumn(Modifier.fillMaxSize(), contentPadding = PaddingValues(bottom = bottom)) {
        item(key = "cover") { CoverHeader(cover, onCreate, onCover) }
        items(rows, key = { it.id }, contentType = { "card" }) { row ->
            GroupCard(row, zone, onOpen = { onOpenGroup(row.id) }, onCamera = { onCamera(row.id) })
            Spacer(Modifier.height(Tokens.Sizes.globalListGap))
        }
    }
}

/**
 * The cover header: newest photo across groups, full-bleed from the top edge, height
 * `groups.list.size.coverHeight`, `scaledToFill`; square bottom corners (radius not measured); ⌄
 * (`icon.global.chevronDown`, white) under it, `size.global.listGap` above the first card. The "+"
 * circle (`size.global.headerButton`, `icon.global.add`) sits over the cover at the trailing
 * `size.global.headerInset`, filled `groups.list.color.headerCircleOverPhoto`.
 */
@Composable
private fun CoverHeader(cover: CoverPhoto?, onCreate: () -> Unit, onCover: (CoverPhoto) -> Unit) {
    val addLabel = stringResource(R.string.groups_list_header_add_accessibilitylabel)
    if (cover == null) {
        Box(Modifier.fillMaxWidth().windowInsetsPadding(WindowInsets.statusBars).padding(horizontal = Tokens.Sizes.globalHeaderInset)) {
            HeaderCircleButton(Tokens.Icons.globalAdd, addLabel, onCreate, fill = HeaderCircleFill.OnDeep, modifier = Modifier.align(Alignment.CenterEnd))
        }
        Spacer(Modifier.height(Tokens.Sizes.globalListGap))
        return
    }
    val coverLabel = stringResource(R.string.groups_list_cover_accessibilitylabel, cover.firstName.orEmpty(), cover.groupName)
    Column(horizontalAlignment = Alignment.CenterHorizontally, modifier = Modifier.fillMaxWidth()) {
        Box(Modifier.fillMaxWidth().height(Tokens.Sizes.groupsListSizeCoverHeight)) {
            Box(
                Modifier
                    .fillMaxSize()
                    .background(Tokens.Colors.globalControlRaised)
                    .clickable(role = Role.Image) { onCover(cover) }
                    .semantics { contentDescription = coverLabel },
            ) {
                if (cover.url != null) {
                    AsyncImage(model = cover.url, contentDescription = null, contentScale = ContentScale.Crop, modifier = Modifier.fillMaxSize())
                }
            }
            BlockedValues.groupsListHeaderCircleOverPhoto?.let { fill ->
                HeaderCircleButton(
                    Tokens.Icons.globalAdd,
                    addLabel,
                    onCreate,
                    fillColor = fill,
                    modifier = Modifier.align(Alignment.TopEnd).windowInsetsPadding(WindowInsets.statusBars).padding(horizontal = Tokens.Sizes.globalHeaderInset),
                )
            }
        }
        Icon(Tokens.Icons.globalChevronDown, contentDescription = null, tint = Tokens.Colors.globalTextPrimary)
        Spacer(Modifier.height(Tokens.Sizes.globalListGap))
    }
}

/**
 * One group card: fill `groups.list.color.card`, minimum height `groups.list.size.cardHeight` (grows
 * with text), corners `radius.global.card`, side margin `size.global.screenMargin`; avatar
 * `size.global.avatarList` at `groups.list.size.avatarInset` (group glyph fallback); name text role
 * `listTitle`; subtitle `listSubtitle` in `color.global.textSecondary` with the sender in
 * `color.global.accent`; camera glyph `icon.global.camera` (`groups.list.size.cameraGlyph`) at the
 * trailing inset. The avatar → text gap reuses `groups.list.size.avatarInset` (not measured). The
 * card is one TalkBack element (name + subtitle); the camera glyph is a second.
 */
@Composable
internal fun GroupCard(row: GroupRow, zone: ZoneId, onOpen: () -> Unit, onCamera: () -> Unit) {
    val shape = RoundedCornerShape(Tokens.Radii.globalCard)
    val subtitleText = subtitleText(row.subtitle, zone)
    val rowLabel = stringResource(R.string.groups_list_row_accessibilitylabel, row.name, subtitleText?.text.orEmpty())
    val cameraLabel = stringResource(R.string.groups_list_row_camera_accessibilitylabel, row.name)
    Row(
        Modifier
            .padding(horizontal = Tokens.Sizes.globalScreenMargin)
            .fillMaxWidth()
            .heightIn(min = Tokens.Sizes.groupsListSizeCardHeight)
            .clip(shape)
            .background(Tokens.Colors.groupsListColorCard, shape),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Row(
            Modifier
                .weight(1f)
                .heightIn(min = Tokens.Sizes.groupsListSizeCardHeight)
                .clickable(onClick = onOpen)
                .clearAndSetSemantics { contentDescription = rowLabel; role = Role.Button }
                .padding(start = Tokens.Sizes.groupsListSizeAvatarInset),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(Tokens.Sizes.groupsListSizeAvatarInset),
        ) {
            Avatar(row.coverUrl, Tokens.Sizes.globalAvatarList, fallbackIcon = Tokens.Icons.globalGroup)
            Column(Modifier.weight(1f)) {
                Text(row.name, style = TextRoles.listTitle, color = Tokens.Colors.globalTextPrimary, maxLines = 1, overflow = TextOverflow.Ellipsis)
                val placeholder = stringResource(R.string.groups_list_row_nopics)
                if (subtitleText != null) {
                    Text(subtitleText, style = TextRoles.listSubtitle, color = Tokens.Colors.globalTextSecondary)
                } else {
                    // Activity not known yet: the line is reserved so the card never changes height.
                    Text(placeholder, style = TextRoles.listSubtitle, modifier = Modifier.alpha(0f))
                }
            }
        }
        Box(
            Modifier
                .size(Tokens.Sizes.globalMinTouchTargetAndroid)
                .clickable(role = Role.Button, onClick = onCamera)
                .semantics { contentDescription = cameraLabel },
            contentAlignment = Alignment.Center,
        ) {
            Icon(Tokens.Icons.globalCamera, contentDescription = null, tint = Tokens.Colors.globalTextPrimary, modifier = Modifier.size(Tokens.Sizes.groupsListSizeCameraGlyph))
        }
        // The 48-dp hit area (size.global.minTouchTarget.android) centred on the 16-dp glyph puts the
        // glyph exactly groups.list.size.avatarInset (16) from the card's trailing edge.
    }
}

@Composable
private fun subtitleText(subtitle: RowSubtitle?, zone: ZoneId) = when (subtitle) {
    null -> null
    RowSubtitle.NoPics -> buildAnnotatedString { append(stringResource(R.string.groups_list_row_nopics)) }
    is RowSubtitle.NewPic -> buildAnnotatedString { append(stringResource(R.string.groups_list_row_newpic, Formats.time(subtitle.at, zone))) }
    is RowSubtitle.SentPic -> {
        val full = stringResource(R.string.groups_list_row_sentpic, subtitle.firstName, Formats.time(subtitle.at, zone))
        val at = full.indexOf(subtitle.firstName)
        buildAnnotatedString {
            if (at < 0) {
                append(full)
            } else {
                append(full.substring(0, at))
                withStyle(SpanStyle(color = Tokens.Colors.globalAccent)) { append(subtitle.firstName) }
                append(full.substring(at + subtitle.firstName.length))
            }
        }
    }
}

@Composable
private fun CenteredHome(bottom: androidx.compose.ui.unit.Dp, content: @Composable () -> Unit) {
    Box(Modifier.fillMaxSize().padding(bottom = bottom), contentAlignment = Alignment.Center) { content() }
}

/**
 * Empty state (no groups; Yope's 2025 "create your first group", BI): two-line title in text role
 * `onboardingTitle`, second line lime (`groups.create.layout.titleAccent`), detail in the onboarding
 * subtitle style, lime primary button `groups.create.size.titleToContent` below; vertically centred
 * above the tab bar. No cover.
 */
@Composable
private fun EmptyHome(bottom: androidx.compose.ui.unit.Dp, onCreate: () -> Unit) {
    val (line1, line2) = TitleSplit.atMiddleWord(stringResource(R.string.groups_list_empty_title))
    CenteredHome(bottom) {
        Column(Modifier.padding(horizontal = Tokens.Sizes.globalButtonMarginH), horizontalAlignment = Alignment.CenterHorizontally) {
            AccentTitle(line1, line2)
            Text(stringResource(R.string.groups_list_empty_detail), style = TextRoles.onboardingSubtitle, textAlign = TextAlign.Center)
            Spacer(Modifier.height(Tokens.Sizes.groupsCreateSizeTitleToContent))
            PrimaryButton(stringResource(R.string.groups_list_empty_button), onCreate)
        }
    }
}
