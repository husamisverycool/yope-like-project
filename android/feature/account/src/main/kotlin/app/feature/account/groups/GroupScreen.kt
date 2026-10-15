// Surface: groups.screen — A. feed (photos, header, "chat" pill). Spec: design/surfaces/groups.screen.md.
// References: references/auto/yope/frames/a-itsmthuyope-7644974799302823175-t43.73-group-screen-hourly.png (G1),
// -t51.23-group-created-empty-state.png (G2), -t51.73-group-profile-add-20-pics.png (G3), references/auto/yope/store/yope-store-01.png (S1),
// a-yrrah-7434441926000037121-t33.73-group-menu-leave-report-2024.png (M24), references/auto/yope/web/a-bi-2025-create-group-composite.jpg (BI).
package app.feature.account.groups

import androidx.compose.animation.core.spring
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
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.Immutable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.derivedStateOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.snapshotFlow
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.IntOffset
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewModelScope
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.navigation.NavController
import app.data.error.DataError
import app.data.model.Group
import app.data.model.GroupKind
import app.data.model.Media
import app.data.model.Post
import app.data.realtime.GroupEvent
import app.data.repo.Member
import app.designsystem.R
import app.designsystem.dsTextStyle
import app.designsystem.generated.Tokens
import app.designsystem.rememberReduceMotion
import app.feature.account.AccountEnvironment
import app.feature.account.LocalAccountEnvironment
import app.feature.account.common.AccountViewModel
import app.feature.account.common.CollectEvents
import app.feature.account.common.dataError
import app.model.AppRoute
import app.model.GroupProfileRoute
import app.ui.components.Avatar
import app.ui.components.EmptyState
import app.ui.components.EmptyStateAction
import app.ui.components.HeaderCircleButton
import app.ui.components.HeaderCircleFill
import app.ui.components.LoadingHud
import app.ui.format.Formats
import app.ui.text.TextRoles
import coil3.compose.AsyncImage
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.flow.filter
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import java.time.Instant
import java.time.ZoneId

/** One entry of the feed, newest first. */
@Immutable
sealed interface FeedItem {
    val key: String
    val at: Instant

    data class Photo(
        val post: Post,
        val url: String?,
        val authorFirstName: String?,
        val authorAvatarUrl: String?,
        val mine: Boolean,
    ) : FeedItem {
        override val key get() = "post:" + post.id
        override val at: Instant get() = post.createdAt
    }

    /** "{first_name} joined" system pill at the joining time. */
    data class Joined(val userId: String, val firstName: String, val avatarUrl: String?, override val at: Instant) : FeedItem {
        override val key get() = "joined:$userId"
    }
}

@Immutable
data class GroupFeedUiState(
    val group: Group? = null,
    val groupAvatarUrl: String? = null,
    /** Null until the first page (cache or network) is known. */
    val items: List<FeedItem>? = null,
    val isCreator: Boolean = false,
    /** First names of members other than you (created state detail). */
    val otherNames: List<String> = emptyList(),
    /** Every member's avatar URL (null = no photo), joining order: the profile page's member row. */
    val memberAvatars: List<String?> = emptyList(),
    val error: DataError? = null,
    val removed: Boolean = false,
    val endReached: Boolean = false,
) {
    val loading: Boolean get() = items == null && error == null && !removed
}

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
                    is GroupEvent.Subscribed -> if (event.resumed) load()
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
                    val avatar = group.coverPath?.let { path -> urls[path] ?: runCatching { env.backend.signedUrls(listOf(path)) }.getOrDefault(emptyMap())[path]?.also { urls[path] = it } }
                    mutable.update { it.copy(group = group, groupAvatarUrl = avatar, isCreator = group.createdBy == env.backend.currentUserId) }
                } else if (page.value != null && page.source == app.data.offline.DataState.Source.Network) {
                    // Loaded from the server and the group is not among yours: removed (or deleted).
                    mutable.update { it.copy(removed = true) }
                }
            }
        }
        viewModelScope.launch {
            env.backend.observeMembers(groupId).collect { page ->
                page.value?.let { list ->
                    members = list
                    enrichMembers(list)
                    publish()
                }
            }
        }
        viewModelScope.launch {
            env.backend.observeFeed(groupId).collect { page ->
                val list = page.value
                if (list != null) {
                    posts = (list + posts.filter { old -> list.none { it.id == old.id } && old.createdAt < (list.lastOrNull()?.createdAt ?: Instant.MAX) }).sortedByDescending { it.createdAt }
                    // Cached page first, then enriched (URLs, names) in place.
                    publish(error = page.error)
                    enrich(list)
                    publish(error = page.error)
                    if (!page.refreshing && list.size < app.data.repo.PostRepository.FEED_PAGE) mutable.update { it.copy(endReached = true) }
                } else if (!page.refreshing) {
                    mutable.update { it.copy(error = page.error) }
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
            FeedItem.Photo(
                post = p,
                url = mediaById[p.mediaId]?.imagePath(Media.Rendition.Display)?.let(urls::get),
                authorFirstName = author?.firstName,
                authorAvatarUrl = author?.avatarPath?.let(urls::get),
                mine = p.authorId == me,
            )
        }
        val creator = mutable.value.group?.createdBy
        val oldest = if (mutable.value.endReached) null else posts.lastOrNull()?.createdAt
        val joins = members
            .filter { it.member.userId != creator }
            .filter { oldest == null || !it.member.joinedAt.isBefore(oldest) }
            .mapNotNull { m ->
                val profile = m.profile ?: return@mapNotNull null
                val first = profile.firstName ?: return@mapNotNull null
                FeedItem.Joined(m.member.userId, first, profile.avatarPath?.let(urls::get), m.member.joinedAt)
            }
        val items = (photos + joins.takeIf { photos.isNotEmpty() }.orEmpty()).sortedByDescending { it.at }
        val others = members.filter { it.member.userId != me }.mapNotNull { it.profile?.firstName }
        val avatars = members.map { m -> m.profile?.avatarPath?.let(urls::get) }
        mutable.update { it.copy(items = items, otherNames = others, memberAvatars = avatars, error = error) }
    }
}

@Composable
fun GroupFeedRoute(nav: NavController, groupId: String) {
    val env = LocalAccountEnvironment.current
    val vm = viewModel(key = "feed:$groupId") { GroupFeedViewModel(env, groupId) }
    val state by vm.state.collectAsStateWithLifecycle()
    CollectEvents(vm.events, nav)
    var recapTarget by remember { mutableStateOf<AppRoute?>(null) }
    LaunchedEffect(groupId) {
        recapTarget = runCatching { env.backend.latestRecapId(groupId) }.getOrNull()?.let { AppRoute.WeekRecap(groupId, it) }
    }
    GroupFeedScreen(
        state = state,
        zone = env.zone(),
        onBack = { nav.popBackStack() },
        onHeader = { nav.navigate(GroupProfileRoute(groupId)) },
        onWeeks = { nav.navigate(AppRoute.WeekHistory(groupId)) },
        onRecap = { nav.navigate(recapTarget ?: AppRoute.WeekHistory(groupId)) },
        onPhoto = { nav.navigate(AppRoute.PhotoViewer(groupId, it.id)) },
        onReport = { nav.navigate(AppRoute.SafetyReport(groupId = groupId, postId = it.id)) },
        onBlock = { nav.navigate(AppRoute.SafetyBlock(it.authorId)) },
        onChat = { nav.navigate(AppRoute.Chat(groupId)) },
        onInvite = { nav.navigate(AppRoute.GroupInvite(groupId)) },
        onCamera = { nav.navigate(AppRoute.Camera(groupId)) },
        onRetry = vm::load,
        onLoadMore = vm::loadMore,
    )
}

@Composable
internal fun createdInviteLabel(kind: GroupKind): String = when (kind) {
    GroupKind.Friends -> stringResource(R.string.groups_screen_created_invite_friends)
    GroupKind.Family -> stringResource(R.string.groups_screen_created_invite_family)
    GroupKind.Roommates -> stringResource(R.string.groups_screen_created_invite_roommates)
    GroupKind.Custom -> stringResource(R.string.groups_screen_created_invite_custom)
}

@Composable
fun GroupFeedScreen(
    state: GroupFeedUiState,
    zone: ZoneId,
    onBack: () -> Unit,
    onHeader: () -> Unit,
    onWeeks: () -> Unit,
    onRecap: () -> Unit,
    onPhoto: (Post) -> Unit,
    onReport: (Post) -> Unit,
    onBlock: (Post) -> Unit,
    onChat: () -> Unit,
    onInvite: () -> Unit,
    onCamera: () -> Unit,
    onRetry: () -> Unit,
    onLoadMore: () -> Unit,
) {
    val reduceMotion by rememberReduceMotion()
    val bottom = WindowInsets.navigationBars.asPaddingValues().calculateBottomPadding()
    Box(Modifier.fillMaxSize().background(Tokens.Colors.globalBackground)) {
        Column(Modifier.fillMaxSize()) {
            FeedHeader(state, onBack, onHeader, onWeeks, onRecap)
            val items = state.items
            Box(Modifier.weight(1f).fillMaxWidth()) {
                when {
                    state.removed -> EmptyCentered {
                        EmptyState(stringResource(R.string.groups_screen_removed_title), stringResource(R.string.groups_screen_removed_detail))
                    }
                    state.loading -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) { LoadingHud(stringResource(R.string.groups_create_hud_loading)) }
                    items == null && state.error == DataError.Network -> EmptyCentered {
                        EmptyState(stringResource(R.string.groups_screen_offline_title), stringResource(R.string.groups_screen_offline_detail))
                    }
                    items == null -> EmptyCentered {
                        EmptyState(
                            stringResource(R.string.groups_screen_error_title),
                            stringResource(R.string.groups_screen_error_detail),
                            action = EmptyStateAction(stringResource(R.string.groups_screen_error_retry), onRetry),
                        )
                    }
                    items.isEmpty() && state.isCreator -> EmptyCentered {
                        EmptyState(
                            stringResource(R.string.groups_screen_created_title),
                            state.otherNames.takeIf { it.isNotEmpty() }?.let { stringResource(R.string.groups_screen_created_detail, it.joinToString(NAME_SEPARATOR)) },
                            action = EmptyStateAction(createdInviteLabel(state.group?.kind ?: GroupKind.Friends), onInvite, Tokens.Icons.globalLink),
                        )
                    }
                    items.isEmpty() -> EmptyCentered {
                        EmptyState(
                            stringResource(R.string.groups_screen_empty_title),
                            stringResource(R.string.groups_screen_empty_detail),
                            action = EmptyStateAction(stringResource(R.string.groups_screen_empty_button), onCamera, Tokens.Icons.globalCamera),
                        )
                    }
                    else -> {
                        val list = rememberLazyListState()
                        val nearEnd by remember { derivedStateOf { list.layoutInfo.visibleItemsInfo.lastOrNull()?.index?.let { it >= list.layoutInfo.totalItemsCount - PREFETCH_DISTANCE } ?: false } }
                        LaunchedEffect(list) { snapshotFlow { nearEnd }.distinctUntilChanged().filter { it }.collect { onLoadMore() } }
                        LazyColumn(
                            state = list,
                            modifier = Modifier.fillMaxSize(),
                            contentPadding = PaddingValues(bottom = bottom + Tokens.Sizes.groupsScreenSizeChatPillHeight + Tokens.Sizes.groupsScreenSizeCardGap),
                            verticalArrangement = Arrangement.spacedBy(Tokens.Sizes.groupsScreenSizeCardGap),
                        ) {
                            items(items, key = { it.key }, contentType = { it::class }) { item ->
                                // New posts arrive with spring.global.platformDefault.android; Reduce Motion: fade only.
                                val placement = if (reduceMotion) null else Tokens.Springs.globalPlatformDefaultAndroid.spec<IntOffset>()
                                val fade = Tokens.Springs.globalPlatformDefaultAndroid.spec<Float>()
                                Box(Modifier.animateItem(fadeInSpec = fade, placementSpec = placement, fadeOutSpec = fade)) {
                                    when (item) {
                                        is FeedItem.Photo -> PhotoCard(item, zone, onPhoto, onReport, onBlock)
                                        is FeedItem.Joined -> JoinedPill(item)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        ChatPill(onChat, Modifier.align(Alignment.BottomCenter).padding(bottom = bottom))
    }
}

private const val NAME_SEPARATOR = ", "
private const val PREFETCH_DISTANCE = 5

@Composable
private fun EmptyCentered(content: @Composable () -> Unit) {
    Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) { content() }
}

/**
 * Header row (S1): ‹ circle; `size.global.headerGap`; capsule (height `size.global.headerButton`,
 * `color.global.control`, capsule shape; group avatar `size.global.avatarHeader` · name text role
 * `headerTitle` · `icon.global.chevron` in `color.global.textSecondary`); trailing calendar and recap
 * circles `size.global.headerGap` apart; insets `size.global.headerInset`.
 */
@Composable
private fun FeedHeader(state: GroupFeedUiState, onBack: () -> Unit, onHeader: () -> Unit, onWeeks: () -> Unit, onRecap: () -> Unit) {
    val name = state.group?.name.orEmpty()
    val headerLabel = stringResource(R.string.groups_screen_header_accessibilitylabel, name)
    Row(
        Modifier.fillMaxWidth().windowInsetsPadding(WindowInsets.statusBars).padding(horizontal = Tokens.Sizes.globalHeaderInset),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(Tokens.Sizes.globalHeaderGap),
    ) {
        HeaderCircleButton(Tokens.Icons.globalBack, stringResource(R.string.groups_screen_back_accessibilitylabel), onBack)
        Box(Modifier.weight(1f)) {
            Row(
                Modifier
                    .heightIn(min = Tokens.Sizes.globalHeaderButton)
                    .clip(CircleShape)
                    .background(Tokens.Colors.globalControl, CircleShape)
                    .clickable(role = Role.Button, onClick = onHeader)
                    .semantics(mergeDescendants = true) { contentDescription = headerLabel }
                    .padding(horizontal = (Tokens.Sizes.globalHeaderButton - Tokens.Sizes.globalAvatarHeader) / 2),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(Tokens.Sizes.globalHeaderGap),
            ) {
                Avatar(state.groupAvatarUrl, Tokens.Sizes.globalAvatarHeader, fallbackIcon = Tokens.Icons.globalGroup)
                Text(name, style = TextRoles.headerTitle, color = Tokens.Colors.globalTextPrimary, maxLines = 1, overflow = TextOverflow.Ellipsis, modifier = Modifier.weight(1f, fill = false))
                Icon(Tokens.Icons.globalChevron, contentDescription = null, tint = Tokens.Colors.globalTextSecondary)
            }
        }
        HeaderCircleButton(Tokens.Icons.globalCalendar, stringResource(R.string.groups_screen_weeks_accessibilitylabel), onWeeks)
        HeaderCircleButton(Tokens.Icons.globalRecap, stringResource(R.string.groups_screen_recap_accessibilitylabel), onRecap)
    }
}

/**
 * Photo card: full width minus `groups.screen.size.cardMarginH`, height `groups.screen.size.cardHeight`,
 * corners `groups.screen.radius.card`, photo `scaledToFill` (reserved before it loads:
 * `color.global.controlRaised`); time centred (text role `overlayTime`, white, `h:mm AM/PM`); caption
 * under it (`listSubtitle`, white); author avatar `size.global.avatarHeader` + first name
 * (`listSubtitle`) bottom-leading and the ••• circle (`icon.global.more`, `color.global.controlRaised`)
 * bottom-trailing, `groups.screen.size.cardGap` from the card edges (insets not measured: role reuse).
 */
@Composable
private fun PhotoCard(item: FeedItem.Photo, zone: ZoneId, onPhoto: (Post) -> Unit, onReport: (Post) -> Unit, onBlock: (Post) -> Unit) {
    val shape = RoundedCornerShape(Tokens.Radii.groupsScreenRadiusCard)
    val time = Formats.time(item.post.createdAt, zone)
    val label = stringResource(R.string.groups_screen_photo_accessibilitylabel, item.authorFirstName.orEmpty(), time)
    var menu by remember { mutableStateOf(false) }
    Box(
        Modifier
            .padding(horizontal = Tokens.Sizes.groupsScreenSizeCardMarginH)
            .fillMaxWidth()
            .height(Tokens.Sizes.groupsScreenSizeCardHeight)
            .clip(shape)
            .background(Tokens.Colors.globalControlRaised, shape),
    ) {
        Box(
            Modifier
                .fillMaxSize()
                .clickable(role = Role.Image) { onPhoto(item.post) }
                .semantics { contentDescription = label },
        ) {
            if (item.url != null) AsyncImage(model = item.url, contentDescription = null, contentScale = ContentScale.Crop, modifier = Modifier.fillMaxSize())
        }
        Column(Modifier.align(Alignment.Center), horizontalAlignment = Alignment.CenterHorizontally) {
            Text(time, style = TextRoles.overlayTime, color = Tokens.Colors.globalTextPrimary)
            item.post.caption?.let { Text(it, style = TextRoles.listSubtitle, color = Tokens.Colors.globalTextPrimary, textAlign = TextAlign.Center) }
        }
        Row(
            Modifier.align(Alignment.BottomStart).padding(Tokens.Sizes.groupsScreenSizeCardGap),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(Tokens.Sizes.globalHeaderGap),
        ) {
            Avatar(item.authorAvatarUrl, Tokens.Sizes.globalAvatarHeader)
            item.authorFirstName?.let { Text(it, style = TextRoles.listSubtitle, color = Tokens.Colors.globalTextPrimary) }
        }
        Box(Modifier.align(Alignment.BottomEnd).padding(Tokens.Sizes.groupsScreenSizeCardGap)) {
            HeaderCircleButton(
                Tokens.Icons.globalMore,
                stringResource(R.string.groups_screen_photo_more_accessibilitylabel),
                { menu = true },
                fill = HeaderCircleFill.Raised,
                diameter = Tokens.Sizes.globalAvatarHeader,
            )
            PhotoMenu(menu, item, onDismiss = { menu = false }, onOpen = { onPhoto(item.post) }, onReport = { onReport(item.post) }, onBlock = { onBlock(item.post) })
        }
    }
}

/**
 * The card's native menu (`safety.block.layout.menu` android: DropdownMenu, destructive items in
 * `color.global.system.error`): others' photos → Report…, Block {first_name}; own → Open.
 */
@Composable
private fun PhotoMenu(expanded: Boolean, item: FeedItem.Photo, onDismiss: () -> Unit, onOpen: () -> Unit, onReport: () -> Unit, onBlock: () -> Unit) {
    DropdownMenu(expanded = expanded, onDismissRequest = onDismiss, containerColor = Tokens.Colors.globalSystemSurfaceContainerHigh) {
        if (item.mine) {
            MenuItem(stringResource(R.string.groups_screen_photo_menu_open), destructive = false) { onDismiss(); onOpen() }
        } else {
            MenuItem(stringResource(R.string.groups_screen_photo_menu_report), destructive = true, icon = Tokens.Icons.globalReport) { onDismiss(); onReport() }
            MenuItem(stringResource(R.string.groups_screen_photo_menu_block, item.authorFirstName.orEmpty()), destructive = true) { onDismiss(); onBlock() }
        }
    }
}

@Composable
internal fun MenuItem(text: String, destructive: Boolean, icon: androidx.compose.ui.graphics.vector.ImageVector? = null, onClick: () -> Unit) {
    val color = if (destructive) Tokens.Colors.globalSystemError else Tokens.Colors.globalSystemOnSurface
    DropdownMenuItem(
        text = { Text(text, style = MaterialTheme.typography.labelLarge, color = color) },
        onClick = onClick,
        trailingIcon = icon?.let { { Icon(it, contentDescription = null, tint = color) } },
    )
}

/**
 * "{first_name} joined" (BI): capsule in `color.global.control`, avatar `size.global.avatarSmall`
 * leading, text `listSubtitle` in `color.global.textPrimary`, centred between cards (sizes not
 * measured: inner spacing reuses `size.global.headerGap`).
 */
@Composable
private fun JoinedPill(item: FeedItem.Joined) {
    Box(Modifier.fillMaxWidth(), contentAlignment = Alignment.Center) {
        Row(
            Modifier.background(Tokens.Colors.globalControl, CircleShape).padding(end = Tokens.Sizes.globalScreenMargin),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(Tokens.Sizes.globalHeaderGap),
        ) {
            Avatar(item.avatarUrl, Tokens.Sizes.globalAvatarSmall)
            Text(stringResource(R.string.groups_screen_memberjoined, item.firstName), style = TextRoles.listSubtitle, color = Tokens.Colors.globalTextPrimary)
        }
    }
}

/**
 * The floating "chat" pill: `groups.screen.size.chatPillWidth` × `.chatPillHeight` (minimum; grows
 * with text), fill `groups.screen.color.chatPill`, corners `radius.global.button` (approximation),
 * `icon.global.chats` + `groups.screen.chat` (`groups.screen.fontSize.chatPill`, bold, white).
 */
@Composable
private fun ChatPill(onClick: () -> Unit, modifier: Modifier = Modifier) {
    val shape = RoundedCornerShape(Tokens.Radii.globalButton)
    Row(
        modifier
            .widthIn(min = Tokens.Sizes.groupsScreenSizeChatPillWidth)
            .heightIn(min = Tokens.Sizes.groupsScreenSizeChatPillHeight)
            .clip(shape)
            .background(Tokens.Colors.groupsScreenColorChatPill, shape)
            .clickable(role = Role.Button, onClick = onClick)
            .padding(horizontal = Tokens.Sizes.globalHeaderGap),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(Tokens.Sizes.globalHeaderGap, Alignment.CenterHorizontally),
    ) {
        Icon(Tokens.Icons.globalChats, contentDescription = null, tint = Tokens.Colors.globalTextPrimary)
        Text(
            stringResource(R.string.groups_screen_chat),
            style = dsTextStyle(Tokens.FontSizes.groupsScreenFontSizeChatPill, Tokens.FontWeights.fontWeightGlobalHeaderTitle),
            color = Tokens.Colors.globalTextPrimary,
        )
    }
}
