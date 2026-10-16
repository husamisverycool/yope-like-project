// Surfaces: walls.mine, walls.member, walls.browse — design/surfaces/walls.mine.md, walls.member.md, walls.browse.md
// References: references/auto/retro/store/retro-store-02.png (profile: serif name, 64 avatar, capsule row, week sections),
// references/auto/retro/press/engadget-2026-08-profile.jpg (current week: photos, add, placeholders),
// references/auto/retro/lazyweb/retro-lazyweb-20251020-week43-dark.png (empty week, "Welcome to Week 43!"),
// references/auto/retro/press/tc-2023-07-retro-1b.webp (Friends grid; outline icon capsule ending the profile row).
package app.feature.social.walls

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.asPaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.paddingFromBaseline
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyListState
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.derivedStateOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.layout.layout
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.input.TextFieldValue
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import app.data.model.Profile
import app.designsystem.R
import app.designsystem.generated.Tokens
import app.feature.social.common.Formats
import app.feature.social.common.PersonAvatar
import app.feature.social.common.StripPhoto
import app.feature.social.common.placeholderDays
import app.feature.social.common.stringRes
import app.feature.social.common.weekStripTiles
import app.ui.components.ActivityIndicator
import app.ui.components.DayTile
import app.ui.components.EmptyState
import app.ui.components.EmptyStateAction
import app.ui.components.EmptyStateFill
import app.ui.components.HeaderIconButton
import app.ui.components.IconCapsule
import app.ui.components.LoadingState
import app.ui.components.ScreenHeader
import app.ui.components.SearchField
import app.ui.components.WeekSection
import app.ui.foundation.GlyphInk
import app.ui.foundation.PageRoles
import app.ui.foundation.endAtLastBaseline
import app.ui.foundation.tapClickable
import app.ui.system.DsDropdownMenu
import app.ui.system.DsMenuItem
import app.ui.text.CapTop
import app.ui.text.TextRoles
import app.ui.text.capTopAt
import java.time.LocalDate
import java.time.ZoneId

/** Where the wall screens lead (walls.*.md → Navigation out). */
data class WallNav(
    val back: () -> Unit,
    val settings: () -> Unit,
    val photo: (wallUserId: String, groupId: String, postId: String) -> Unit,
    val collage: (groupId: String, invitationId: String) -> Unit,
    val camera: () -> Unit,
    val createGroup: () -> Unit,
    val member: (userId: String) -> Unit,
    val report: (userId: String) -> Unit,
    val block: (userId: String) -> Unit,
)

/** One week section of a wall. */
data class WallWeek(val weekStart: LocalDate, val tiles: List<WallTile>, val current: Boolean)

/**
 * The wall's weeks (`walls.mine.layout.weeks`): items grouped by week in the device's time zone (Monday start),
 * newest first; the current week always first; past weeks only when they hold photos.
 */
fun wallWeeks(tiles: List<WallTile>, zone: ZoneId, today: LocalDate): List<WallWeek> {
    val current = Formats.weekStartOf(today)
    val byWeek = tiles.groupBy { Formats.weekStartOf(it.createdAt.atZone(zone).toLocalDate()) }
    val past = byWeek.filterKeys { it != current }.toSortedMap(compareByDescending { it }).map { (start, list) -> WallWeek(start, list, false) }
    return listOf(WallWeek(current, byWeek[current].orEmpty(), true)) + past
}

/** Bottom inset of a tab root: the tab bar (C-04, `size.global.tabBarHeight`) over the navigation bar. */
@Composable
internal fun tabBarClearance(): Dp = Tokens.Sizes.globalTabBarHeight + WindowInsets.navigationBars.asPaddingValues().calculateBottomPadding()

@Composable
fun WallMineScreen(vm: WallViewModel, nav: WallNav) {
    val state by vm.state.collectAsStateWithLifecycle()
    WallMineContent(state, nav, onRetry = vm.loader::retry, onLoadMore = vm.loader::loadMore)
}

@Composable
fun WallMemberScreen(vm: WallViewModel, nav: WallNav) {
    val state by vm.state.collectAsStateWithLifecycle()
    WallMemberContent(state, vm.loader.userId, nav, onRetry = vm.loader::retry, onLoadMore = vm.loader::loadMore)
}

/** `walls.mine`: my photos from all my groups, week by week, under the profile header (C-19 adapted). */
@Composable
fun WallMineContent(
    state: WallState,
    nav: WallNav,
    onRetry: () -> Unit,
    onLoadMore: () -> Unit,
    listState: LazyListState = rememberLazyListState(),
    zone: ZoneId = ZoneId.systemDefault(),
    today: LocalDate = LocalDate.now(zone),
) {
    val person = state.person
    WallFrame(
        state = state,
        me = true,
        userId = person?.id.orEmpty(),
        nav = nav,
        onRetry = onRetry,
        onLoadMore = onLoadMore,
        listState = listState,
        zone = zone,
        today = today,
        header = {
            WallHeader(
                name = person?.displayName.orEmpty(),
                avatarPath = person?.avatarPath,
                back = null,
                action = { IconCapsule(Tokens.Icons.globalSettings, stringRes(R.string.walls_mine_a11y_settings), nav.settings) },
            )
        },
        empty = { week ->
            EmptyState(
                stringRes(R.string.walls_mine_empty_title, Formats.isoWeek(week)),
                null,
                action = EmptyStateAction(stringRes(R.string.walls_mine_empty_action), nav.camera, Tokens.Icons.globalAdd),
                icon = Tokens.Icons.globalCalendar,
            )
        },
        tabRoot = true,
        modifier = Modifier.testTag("walls.mine"),
    )
}

/** `walls.member`: a member's photos from groups you share, under a pushed profile header with the "•••" capsule. */
@Composable
fun WallMemberContent(
    state: WallState,
    userId: String,
    nav: WallNav,
    onRetry: () -> Unit,
    onLoadMore: () -> Unit,
    listState: LazyListState = rememberLazyListState(),
    zone: ZoneId = ZoneId.systemDefault(),
    today: LocalDate = LocalDate.now(zone),
    menuOpen: Boolean = false,
) {
    val person = state.person
    val name = person?.displayName.orEmpty()
    WallFrame(
        state = state,
        me = false,
        userId = userId,
        nav = nav,
        onRetry = onRetry,
        onLoadMore = onLoadMore,
        listState = listState,
        zone = zone,
        today = today,
        header = {
            var open by remember { mutableStateOf(menuOpen) }
            WallHeader(
                name = name,
                avatarPath = person?.avatarPath,
                back = nav.back,
                screenLabel = stringRes(R.string.walls_member_a11y_wall, name),
                action = {
                    Box {
                        IconCapsule(Tokens.Icons.globalMore, stringRes(R.string.walls_member_a11y_more), { open = true })
                        DsDropdownMenu(
                            open,
                            { open = false },
                            listOf(
                                DsMenuItem(stringRes(R.string.walls_member_menu_report), { nav.report(userId) }, destructive = true),
                                DsMenuItem(stringRes(R.string.walls_member_menu_block), { nav.block(userId) }, destructive = true),
                            ),
                        )
                    }
                },
            )
        },
        empty = {
            EmptyState(
                stringRes(R.string.walls_member_empty_title),
                stringRes(R.string.walls_member_empty_detail, person?.firstName ?: name),
                icon = Tokens.Icons.globalCalendar,
            )
        },
        tabRoot = false,
        modifier = Modifier.testTag("walls.member"),
    )
}

/**
 * The shared wall layout: [header], then the week sections (C-20 + C-17) — the first header's cap top
 * `walls.mine.dimension.actionsToWeeks` below the action row, the next ones `size.global.sectionGap` below the
 * strip above — with the loading, error, offline and empty states of the specs.
 */
@Composable
private fun WallFrame(
    state: WallState,
    me: Boolean,
    userId: String,
    nav: WallNav,
    onRetry: () -> Unit,
    onLoadMore: () -> Unit,
    listState: LazyListState,
    zone: ZoneId,
    today: LocalDate,
    header: @Composable () -> Unit,
    empty: @Composable (currentWeek: LocalDate) -> Unit,
    tabRoot: Boolean,
    modifier: Modifier,
) {
    val context = LocalContext.current
    val bottom = if (tabRoot) tabBarClearance() else WindowInsets.navigationBars.asPaddingValues().calculateBottomPadding()
    val currentWeek = Formats.weekStartOf(today)
    val firstHeader = Modifier.capTopAt(Tokens.Sizes.wallsMineDimensionActionsToWeeks, CapTop.height(TextRoles.sectionLabel))
    Column(modifier.fillMaxSize().background(PageRoles.page).statusBarsPadding()) {
        when {
            state.phase == WallState.Phase.Loading -> {
                header()
                WeekSection(stringRes(R.string.week_history_header_title, Formats.isoWeek(currentWeek)), placeholderDays(currentWeek), firstHeader)
                Box(Modifier.weight(1f).fillMaxWidth()) { LoadingState(stringRes(R.string.week_history_a11y_loading)) }
            }
            state.phase == WallState.Phase.Error || state.phase == WallState.Phase.OfflineEmpty -> {
                header()
                ErrorLine(stringRes(R.string.walls_mine_error_title), onRetry, Modifier.capTopAt(Tokens.Sizes.wallsMineDimensionActionsToWeeks, CapTop.height(TextRoles.body)))
            }
            state.isEmpty && !me -> {
                header()
                EmptyStateFill(Modifier.weight(1f).padding(bottom = bottom)) { empty(currentWeek) }
            }
            state.isEmpty -> {
                header()
                WallWeekSection(WallWeek(currentWeek, emptyList(), true), me, userId, nav, zone, context, firstHeader)
                EmptyStateFill(Modifier.weight(1f).padding(bottom = bottom)) { empty(currentWeek) }
            }
            else -> {
                val weeks = remember(state.tiles, zone, today) { wallWeeks(state.tiles, zone, today) }
                val nearEnd by remember(weeks) { derivedStateOf { (listState.layoutInfo.visibleItemsInfo.lastOrNull()?.index ?: 0) >= weeks.size - 1 } }
                LaunchedEffect(nearEnd) { if (nearEnd) onLoadMore() }
                LazyColumn(state = listState, modifier = Modifier.fillMaxSize(), contentPadding = PaddingValues(bottom = bottom + Tokens.Sizes.globalSectionGap)) {
                    item(key = "header") { header() }
                    items(weeks, key = { it.weekStart.toString() }) { week ->
                        WallWeekSection(week, me, userId, nav, zone, context, if (week.current) firstHeader else Modifier, afterContent = !week.current, name = state.person?.firstName.orEmpty())
                    }
                    if (state.loadingMore) item(key = "more") {
                        Box(Modifier.fillMaxWidth().padding(top = Tokens.Sizes.globalSectionGap), contentAlignment = Alignment.Center) {
                            ActivityIndicator(stringRes(R.string.week_history_a11y_loading))
                        }
                    }
                }
            }
        }
    }
}

/** One week of a wall: C-20 "Week 27  Jul 3 - 9" (no "•••" on walls) over its C-17 strip. */
@Composable
private fun WallWeekSection(
    week: WallWeek,
    me: Boolean,
    userId: String,
    nav: WallNav,
    zone: ZoneId,
    context: android.content.Context,
    modifier: Modifier,
    afterContent: Boolean = false,
    name: String = "",
) {
    val number = Formats.isoWeek(week.weekStart)
    val title = stringRes(R.string.week_history_header_title, number)
    val hasPhotos = week.tiles.isNotEmpty()
    val range = if (week.current && !hasPhotos) null else Formats.weekRange(context, week.weekStart, zone)
    val spoken = if (range == null) title else "$title, ${Formats.spokenWeekRange(context, week.weekStart, zone)}"
    val photos = week.tiles.map { tile ->
        val day = tile.createdAt.atZone(zone).toLocalDate()
        when (tile) {
            is WallTile.Photo -> StripPhoto(
                tile.key,
                tile.thumbPath,
                tile.createdAt,
                if (me) stringRes(R.string.photo_viewer_a11y_photomine, Formats.spokenDate(day))
                else stringRes(R.string.week_history_a11y_tile, Formats.weekdayLong(day), Formats.spokenDate(day), name),
                tile.groupId?.let { g -> { nav.photo(userId, g, tile.postId) } },
            )
            is WallTile.CollageTile -> StripPhoto(
                tile.key,
                tile.imagePath,
                tile.createdAt,
                stringRes(R.string.walls_browse_a11y_collage, Formats.spokenDate(day)),
                if (tile.groupId != null && tile.invitationId != null) ({ nav.collage(tile.groupId, tile.invitationId) }) else null,
            )
        }
    }
    val add = if (me && week.current) DayTile.Add(stringRes(R.string.week_history_a11y_add), nav.camera) else null
    WeekSection(
        title = title,
        tiles = weekStripTiles(week.weekStart, photos, week.current, add, zone),
        modifier = modifier,
        range = range,
        accessibilityLabel = spoken,
        afterContent = afterContent,
    )
}

/**
 * The profile header of a wall (C-19 adapted, `walls.mine.layout.header`): the name in the display serif
 * (`headerTitle`) at `size.global.screenMargin` — or, pushed ([back]), after the C-02 chevron (`icon.global.back`
 * ink at `size.global.backInset`, title `size.global.headerGap` after it) — baseline `size.global.titleTop` below the
 * top safe area, one line, tail truncation; the avatar `size.global.avatarProfile` at the trailing margin centred on
 * the name's cap middle; the action row `walls.mine.dimension.nameToActions` below the name baseline with one C-06
 * outline icon capsule at the trailing margin. (core:ui `ProfileHeader` / `PushedHeader` fix their own spacing below
 * the title — `size.global.infoRowPitch` / `titleToContent` — and place a lone icon capsule leading; component gap.)
 */
@Composable
private fun WallHeader(name: String, avatarPath: String?, back: (() -> Unit)?, action: @Composable () -> Unit, screenLabel: String? = null) {
    val margin = Tokens.Sizes.globalScreenMargin
    val style = TextRoles.headerTitle
    val capMiddle = Tokens.Sizes.globalTitleTop - CapTop.height(style) / 2
    val box = Tokens.Sizes.globalIcon
    val chevron = Tokens.Icons.globalBack
    val hit = app.feature.social.chat.glyphHit
    val titleStart = if (back == null) margin else Tokens.Sizes.globalBackInset + GlyphInk.width(chevron, box) + Tokens.Sizes.globalHeaderGap
    Column(Modifier.fillMaxWidth()) {
        Box(Modifier.fillMaxWidth()) {
            Text(
                name,
                style = style,
                color = Tokens.Colors.globalTextPrimary,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
                modifier = Modifier
                    .padding(start = titleStart, end = margin + Tokens.Sizes.globalAvatarProfile + margin)
                    .paddingFromBaseline(top = Tokens.Sizes.globalTitleTop)
                    .endAtLastBaseline()
                    .semantics {
                        heading()
                        if (screenLabel != null) contentDescription = screenLabel
                    },
            )
            if (back != null) {
                val hitStart = Tokens.Sizes.globalBackInset - GlyphInk.leading(chevron, box) - (hit - box) / 2
                Box(Modifier.padding(start = hitStart).centredOverlay(capMiddle)) {
                    HeaderIconButton(chevron, stringRes(R.string.chat_thread_a11y_back), back)
                }
            }
            Box(Modifier.align(Alignment.TopEnd).padding(end = margin).centredOverlay(capMiddle)) {
                PersonAvatar(avatarPath, Tokens.Sizes.globalAvatarProfile)
            }
        }
        Row(Modifier.fillMaxWidth().padding(top = Tokens.Sizes.wallsMineDimensionNameToActions).padding(horizontal = margin), horizontalArrangement = Arrangement.End) {
            action()
        }
    }
}

/** Draws the element centred on [centreY] without taking height in the layout (the name's baseline ends the header box). */
private fun Modifier.centredOverlay(centreY: Dp): Modifier = layout { measurable, constraints ->
    val placeable = measurable.measure(constraints.copy(minHeight = 0))
    layout(placeable.width, 0) { placeable.place(0, (centreY.toPx() - placeable.height / 2f).toInt()) }
}

/** The list-error line (`retro.voice.error`): one tappable line at `size.global.screenMargin`, text role `body`, secondary text. */
@Composable
internal fun ErrorLine(text: String, onRetry: () -> Unit, modifier: Modifier = Modifier) {
    Text(
        text,
        style = TextRoles.body,
        color = PageRoles.secondaryText(),
        modifier = modifier
            .fillMaxWidth()
            .tapClickable(onClick = onRetry)
            .padding(horizontal = Tokens.Sizes.globalScreenMargin)
            .semantics { role = Role.Button },
    )
}

@Composable
fun WallsBrowseScreen(vm: BrowseViewModel, nav: WallNav) {
    val state by vm.state.collectAsStateWithLifecycle()
    WallsBrowseContent(state, nav, onQuery = vm::setQuery, onRetry = vm::retry)
}

/**
 * `walls.browse` (Retro's Friends tab): C-01 serif "Friends"; the C-12 search field `size.global.titleToContent`
 * below the title baseline; the people grid `size.global.sectionGap` below it — three columns
 * `walls.browse.dimension.columnPitch` apart centred on the screen, avatar `size.global.avatarGrid`, the name
 * (`listTitle`) centred, baseline `walls.browse.dimension.nameBaseline` below the avatar, rows
 * `walls.browse.dimension.rowPitch` apart (core:ui `PeopleGrid` spaces by weight / `size.global.listGap` — the
 * measured pitches are this surface's tokens).
 */
@Composable
fun WallsBrowseContent(state: BrowseState, nav: WallNav, onQuery: (String) -> Unit, onRetry: () -> Unit, initialQuery: String = "") {
    var query by remember { mutableStateOf(TextFieldValue(initialQuery)) }
    val bottom = tabBarClearance()
    Column(Modifier.fillMaxSize().background(PageRoles.page).statusBarsPadding().testTag("walls.browse")) {
        ScreenHeader(stringRes(R.string.walls_browse_title))
        when {
            state.phase == BrowseState.Phase.Error || state.phase == BrowseState.Phase.OfflineEmpty ->
                ErrorLine(stringRes(R.string.walls_browse_error_title), onRetry)
            state.phase == BrowseState.Phase.Ready && state.alone -> EmptyStateFill(Modifier.weight(1f).padding(bottom = bottom)) {
                EmptyState(
                    stringRes(R.string.walls_browse_empty_title),
                    stringRes(R.string.walls_browse_empty_detail),
                    action = EmptyStateAction(stringRes(R.string.walls_browse_empty_action), nav.createGroup),
                    icon = Tokens.Icons.globalGroup,
                )
            }
            else -> {
                SearchField(
                    value = query,
                    onValueChange = {
                        query = it
                        onQuery(it.text)
                    },
                    placeholder = stringRes(R.string.walls_browse_search),
                    accessibilityLabel = stringRes(R.string.walls_browse_search),
                    modifier = Modifier.padding(horizontal = Tokens.Sizes.globalScreenMargin),
                )
                when {
                    state.phase == BrowseState.Phase.Loading -> Box(Modifier.weight(1f).fillMaxWidth().padding(bottom = bottom)) { LoadingState(stringRes(R.string.week_history_a11y_loading)) }
                    state.shown.isEmpty() -> Box(Modifier.fillMaxWidth().padding(top = Tokens.Sizes.globalSectionGap), contentAlignment = Alignment.TopCenter) {
                        EmptyState(stringRes(R.string.walls_browse_search_empty), null)
                    }
                    else -> PeopleGridList(state.shown, nav, PaddingValues(top = Tokens.Sizes.globalSectionGap, bottom = bottom))
                }
            }
        }
    }
}

/** The people grid (`walls.browse.layout.grid`): rows of three cells of `walls.browse.dimension.columnPitch`, centred. */
@Composable
private fun PeopleGridList(people: List<Profile>, nav: WallNav, padding: PaddingValues) {
    val rows = people.chunked(GRID_COLUMNS)
    LazyColumn(Modifier.fillMaxSize(), contentPadding = padding) {
        items(rows, key = { row -> row.first().id }) { row ->
            Row(Modifier.fillMaxWidth().heightIn(min = Tokens.Sizes.wallsBrowseDimensionRowPitch), horizontalArrangement = Arrangement.Center) {
                row.forEach { p -> PersonCell(p, nav) }
                repeat(GRID_COLUMNS - row.size) { Box(Modifier.width(Tokens.Sizes.wallsBrowseDimensionColumnPitch)) }
            }
        }
    }
}

@Composable
private fun PersonCell(p: Profile, nav: WallNav) {
    val label = stringRes(R.string.walls_member_a11y_wall, p.displayName)
    Column(
        Modifier
            .width(Tokens.Sizes.wallsBrowseDimensionColumnPitch)
            .tapClickable { nav.member(p.id) }
            .clearAndSetSemantics {
                contentDescription = label
                role = Role.Button
            },
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        PersonAvatar(p.avatarPath, Tokens.Sizes.globalAvatarGrid)
        Text(
            p.displayName,
            style = TextRoles.listTitle,
            color = Tokens.Colors.globalTextPrimary,
            textAlign = TextAlign.Center,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
            modifier = Modifier.paddingFromBaseline(top = Tokens.Sizes.wallsBrowseDimensionNameBaseline),
        )
    }
}

/** C-21: three columns (`walls.browse.layout.grid`). */
private const val GRID_COLUMNS = 3
