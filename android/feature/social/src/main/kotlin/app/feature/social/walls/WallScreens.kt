// Surfaces: walls.mine (my wall), walls.member (a member's wall), walls.browse (me & friends).
// References: references/auto/yope/frames/b-presskit-profile.png (grid, primary for walls.mine / walls.member),
// references/auto/yope/frames/b-yopeapp-7591560669967682847-t116.00-me-and-friends.png (walls.browse; title placement),
// references/auto/yope/frames/b-play-05.png (2-column wall thumbnails, not used: S-11).
package app.feature.social.walls

import androidx.compose.foundation.clickable
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.asPaddingValues
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBars
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.GridItemSpan
import androidx.compose.foundation.lazy.grid.LazyGridState
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.lazy.grid.rememberLazyGridState
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.snapshotFlow
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.layout.FirstBaseline
import androidx.compose.ui.layout.Layout
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.Constraints
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import app.designsystem.R
import app.designsystem.generated.Tokens
import app.feature.social.common.ActivityIndicator
import app.feature.social.common.Avatar
import app.feature.social.common.EmptyState
import app.feature.social.common.Formats
import app.feature.social.common.HeaderCircle
import app.feature.social.common.Line
import app.feature.social.common.PillAction
import app.feature.social.common.RemotePhoto
import app.feature.social.common.Type
import app.feature.social.common.rememberHaptics
import app.feature.social.common.stringRes
import app.ui.components.HeaderCircleFill
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlin.math.max

/** Where walls lead. */
data class WallNav(
    val back: () -> Unit,
    val settings: () -> Unit,
    val photo: (wallUserId: String, groupId: String, postId: String) -> Unit,
    val collage: (groupId: String, invitationId: String) -> Unit,
    val camera: () -> Unit,
    val createGroup: () -> Unit,
)

/** Header circles of wall screens. */
private enum class WallHeaderButton { Settings, Back, None }

/**
 * The wall header: title centred, text role `sheetTitle`, baseline
 * `walls.browse.dimension.titleBaseline` below the top safe-area inset, with an optional header
 * circle vertically centred on the title (settings at the right for walls.mine, back at the left for
 * walls.member), [height] tall in all.
 */
@Composable
private fun WallTitle(title: String, button: WallHeaderButton, onButton: () -> Unit, height: Dp, label: String?, modifier: Modifier = Modifier) {
    val top = WindowInsets.statusBars.asPaddingValues().calculateTopPadding()
    val circleLabel = when (button) {
        WallHeaderButton.Settings -> stringRes(R.string.walls_mine_a11y_settings)
        WallHeaderButton.Back -> stringRes(R.string.chat_thread_a11y_back)
        WallHeaderButton.None -> ""
    }
    Layout(
        modifier = modifier.fillMaxWidth(),
        content = {
            Line(title, Type.sheetTitle(), Tokens.Colors.globalTextPrimary, Modifier.semantics { heading(); if (label != null) contentDescription = label })
            when (button) {
                WallHeaderButton.Settings -> HeaderCircle(Tokens.Icons.globalSettings, circleLabel, HeaderCircleFill.OnDeep, onButton)
                WallHeaderButton.Back -> HeaderCircle(Tokens.Icons.globalBack, circleLabel, HeaderCircleFill.OnDeep, onButton)
                WallHeaderButton.None -> Unit
            }
        },
    ) { measurables, constraints ->
        val inset = Tokens.Sizes.globalHeaderInset.roundToPx()
        val circleSize = Tokens.Sizes.globalHeaderButton.roundToPx()
        val titleMax = (constraints.maxWidth - 2 * (inset + circleSize)).coerceAtLeast(0)
        val titlePlaceable = measurables[0].measure(Constraints(maxWidth = titleMax))
        val circle = measurables.getOrNull(1)?.measure(Constraints())
        val baseline = (top + Tokens.Sizes.wallsBrowseDimensionTitleBaseline).roundToPx()
        val titleY = baseline - titlePlaceable[FirstBaseline]
        val centre = titleY + titlePlaceable.height / 2
        val h = max(height.roundToPx(), titleY + titlePlaceable.height)
        layout(constraints.maxWidth, h) {
            titlePlaceable.place((constraints.maxWidth - titlePlaceable.width) / 2, titleY)
            if (circle != null) {
                val y = (centre - circle.height / 2).coerceAtLeast(top.roundToPx())
                val x = if (button == WallHeaderButton.Settings) constraints.maxWidth - inset - circle.width else inset
                circle.place(x, y)
            }
        }
    }
}

/** A grid tile (`walls.mine.aspectRatio.gridTile`, `.radius.gridTile`), aspect fill. */
@Composable
private fun Tile(tile: WallTile, label: String, onClick: () -> Unit) {
    val path = when (tile) {
        is WallTile.Photo -> tile.thumbPath
        is WallTile.CollageTile -> tile.imagePath
    }
    RemotePhoto(
        path,
        null,
        Modifier
            .fillMaxWidth()
            .aspectRatio(Tokens.AspectRatios.wallsMineAspectRatioGridTile)
            .clip(RoundedCornerShape(Tokens.Radii.wallsMineRadiusGridTile))
            .clickable(role = Role.Button, onClick = onClick)
            .clearAndSetSemantics { contentDescription = label; role = Role.Button },
    )
}

/** What a wall grid shows beyond its tiles (the header and the state of the wall). */
private sealed interface WallBody {
    data object Loading : WallBody
    data class Message(val title: String, val detail: String?, val pill: PillAction?) : WallBody
    data object Tiles : WallBody
}

/**
 * The wall grid of walls.mine §Structure 2: `walls.mine.count.gridColumns` columns,
 * `.dimension.gridInset` side insets, `.dimension.gridGap` both ways, newest first. Loads more at
 * the end. [header] is the first, full-width item; the grid starts `walls.mine.dimension.titleToGrid`
 * below the title baseline ([headerHeight] includes that).
 */
@Composable
private fun WallGrid(
    state: WallState,
    loader: WallLoader?,
    personName: String,
    mine: Boolean,
    body: WallBody,
    bottomInset: Dp,
    nav: WallNav,
    gridState: LazyGridState,
    header: @Composable () -> Unit,
) {
    val gap = Tokens.Sizes.wallsMineDimensionGridGap
    LaunchedEffect(gridState, loader) {
        snapshotFlow { gridState.layoutInfo.visibleItemsInfo.lastOrNull()?.index ?: 0 }
            .distinctUntilChanged()
            .collect { last -> if (last >= gridState.layoutInfo.totalItemsCount - LOAD_MORE_THRESHOLD) loader?.loadMore() }
    }
    if (body !is WallBody.Tiles) {
        // Loading / empty / error / offline: centred in the space under the header.
        Column(Modifier.fillMaxSize().padding(bottom = bottomInset)) {
            Box(Modifier.padding(horizontal = Tokens.Sizes.wallsMineDimensionGridInset)) { header() }
            Box(Modifier.weight(1f).fillMaxWidth(), contentAlignment = Alignment.Center) {
                when (body) {
                    WallBody.Loading -> ActivityIndicator()
                    is WallBody.Message -> EmptyState(body.title, body.detail, body.pill)
                    WallBody.Tiles -> Unit
                }
            }
        }
        return
    }
    LazyVerticalGrid(
        columns = GridCells.Fixed(Tokens.Counts.wallsMineCountGridColumns),
        state = gridState,
        modifier = Modifier.fillMaxSize(),
        contentPadding = PaddingValues(start = Tokens.Sizes.wallsMineDimensionGridInset, end = Tokens.Sizes.wallsMineDimensionGridInset, bottom = bottomInset),
        horizontalArrangement = Arrangement.spacedBy(gap),
        verticalArrangement = Arrangement.spacedBy(gap),
    ) {
        item(key = "header", span = { GridItemSpan(maxLineSpan) }) { header() }
        items(state.tiles, key = { it.key }, contentType = { it::class }) { tile ->
            val date = Formats.viewerDate(tile.createdAt)
            when (tile) {
                is WallTile.Photo -> Tile(
                    tile,
                    if (mine) stringRes(R.string.photo_viewer_a11y_photomine, date) else stringRes(R.string.photo_viewer_a11y_photo, personName, date),
                ) { tile.groupId?.let { g -> nav.photo(loader?.userId.orEmpty(), g, tile.postId) } }
                is WallTile.CollageTile -> Tile(tile, stringRes(R.string.walls_browse_a11y_collage, date)) {
                    val g = tile.groupId
                    val inv = tile.invitationId
                    if (g != null && inv != null) nav.collage(g, inv)
                }
            }
        }
        if (state.loadingMore) item(key = "more", span = { GridItemSpan(maxLineSpan) }) {
            Box(Modifier.fillMaxWidth(), contentAlignment = Alignment.Center) { ActivityIndicator() }
        }
    }
}

private const val LOAD_MORE_THRESHOLD = 9

/** Error / offline / empty / tiles for one wall. */
@Composable
private fun wallBody(state: WallState, mine: Boolean, name: String, nav: WallNav, onRetry: () -> Unit): WallBody = when {
    state.phase == WallState.Phase.Loading -> WallBody.Loading
    state.phase == WallState.Phase.Error -> WallBody.Message(stringRes(R.string.walls_mine_error_title), stringRes(R.string.chat_thread_error_detail), PillAction(stringRes(R.string.chat_thread_error_retry), null, onRetry))
    state.phase == WallState.Phase.OfflineEmpty -> WallBody.Message(stringRes(R.string.chat_thread_offline_title), stringRes(R.string.chat_thread_offline_detail), null)
    state.isEmpty && mine -> WallBody.Message(stringRes(R.string.walls_mine_empty_title), stringRes(R.string.walls_mine_empty_detail), PillAction(stringRes(R.string.walls_mine_empty_action), Tokens.Icons.globalCamera, nav.camera))
    state.isEmpty -> WallBody.Message(stringRes(R.string.walls_member_empty_title, name), stringRes(R.string.walls_member_empty_detail, name), null)
    else -> WallBody.Tiles
}

/** Content inset under the floating tab bar of tab-root walls (`size.global.tabBarHeight` + the navigation bar). */
@Composable
private fun tabBarInset(): Dp = Tokens.Sizes.globalTabBarHeight + WindowInsets.navigationBars.asPaddingValues().calculateBottomPadding()

@Composable
fun WallMineScreen(vm: WallViewModel, nav: WallNav) {
    val state by vm.loader.state.collectAsStateWithLifecycle()
    WallMineContent(state, vm.loader, nav)
}

/** walls.mine: settings circle, "my wall", my wall items in Yope's grid on `color.global.backgroundDeep`. */
@Composable
fun WallMineContent(state: WallState, loader: WallLoader?, nav: WallNav, gridState: LazyGridState = rememberLazyGridState()) {
    Box(Modifier.fillMaxSize().background(Tokens.Colors.globalBackgroundDeep).testTag("walls.mine")) {
        val body = wallBody(state, mine = true, name = "", nav = nav, onRetry = { loader?.retry() })
        val headerHeight = Tokens.Sizes.wallsBrowseDimensionTitleBaseline + Tokens.Sizes.wallsMineDimensionTitleToGrid - Tokens.Sizes.wallsMineDimensionGridGap
        WallGrid(state, loader, "", mine = true, body = body, bottomInset = tabBarInset(), nav = nav, gridState = gridState) {
            WallTitle(stringRes(R.string.walls_mine_title), WallHeaderButton.Settings, nav.settings, headerHeight + WindowInsets.statusBars.asPaddingValues().calculateTopPadding(), null)
        }
    }
}

@Composable
fun WallMemberScreen(vm: WallViewModel, nav: WallNav) {
    val state by vm.loader.state.collectAsStateWithLifecycle()
    WallMemberContent(state, vm.loader, nav)
}

/** walls.member: back circle, the member's display name, their photos from groups we share. */
@Composable
fun WallMemberContent(state: WallState, loader: WallLoader?, nav: WallNav, gridState: LazyGridState = rememberLazyGridState()) {
    val name = state.person?.displayName.orEmpty()
    val first = state.person?.firstName ?: name
    Box(Modifier.fillMaxSize().background(Tokens.Colors.globalBackgroundDeep).testTag("walls.member")) {
        val body = wallBody(state, mine = false, name = first, nav = nav, onRetry = { loader?.retry() })
        val headerHeight = Tokens.Sizes.wallsBrowseDimensionTitleBaseline + Tokens.Sizes.wallsMineDimensionTitleToGrid - Tokens.Sizes.wallsMineDimensionGridGap
        val bottom = WindowInsets.navigationBars.asPaddingValues().calculateBottomPadding()
        WallGrid(state, loader, first, mine = false, body = body, bottomInset = bottom, nav = nav, gridState = gridState) {
            WallTitle(name, WallHeaderButton.Back, nav.back, headerHeight + WindowInsets.statusBars.asPaddingValues().calculateTopPadding(), stringRes(R.string.walls_member_a11y_wall, first))
        }
    }
}

@Composable
fun WallsBrowseScreen(vm: BrowseViewModel, nav: WallNav) {
    val state by vm.state.collectAsStateWithLifecycle()
    val loader by vm.wall.collectAsStateWithLifecycle()
    val wall = loader?.state?.collectAsStateWithLifecycle()?.value ?: WallState()
    val haptics = rememberHaptics()
    WallsBrowseContent(state, loader, wall, nav, onSelect = { id -> haptics.play(Tokens.Haptics.globalSelect); vm.select(id) }, onRetry = vm::retry)
}

/**
 * walls.browse: "me & friends", the person row (me first), the selected person's wall below
 * (`walls.browse.dimension.wallTop`). The selected person's marking is BLOCKED
 * (`walls.browse.layout.selection`): only TalkBack's selected state shows it.
 */
@Composable
fun WallsBrowseContent(
    state: BrowseState,
    loader: WallLoader?,
    wall: WallState,
    nav: WallNav,
    onSelect: (String) -> Unit,
    onRetry: () -> Unit,
    gridState: LazyGridState = rememberLazyGridState(),
) {
    Box(Modifier.fillMaxSize().background(Tokens.Colors.globalBackgroundDeep).testTag("walls.browse")) {
        val selected = state.people.firstOrNull { it.profile.id == state.selected }
        val isMe = selected?.isMe == true
        val first = selected?.profile?.firstName ?: selected?.profile?.displayName.orEmpty()
        val body: WallBody = when {
            state.phase == BrowseState.Phase.Loading -> WallBody.Loading
            state.phase == BrowseState.Phase.Error -> WallBody.Message(stringRes(R.string.walls_mine_error_title), stringRes(R.string.chat_thread_error_detail), PillAction(stringRes(R.string.chat_thread_error_retry), null, onRetry))
            state.phase == BrowseState.Phase.OfflineEmpty -> WallBody.Message(stringRes(R.string.chat_thread_offline_title), stringRes(R.string.chat_thread_offline_detail), null)
            state.alone && (wall.isEmpty || wall.phase != WallState.Phase.Ready) -> WallBody.Message(stringRes(R.string.walls_browse_empty_title), stringRes(R.string.walls_browse_empty_detail), PillAction(stringRes(R.string.walls_browse_empty_action), null, nav.createGroup))
            else -> wallBody(wall, isMe, first, nav, onRetry = { loader?.retry() })
        }
        val top = WindowInsets.statusBars.asPaddingValues().calculateTopPadding()
        WallGrid(wall, loader, first, mine = isMe, body = body, bottomInset = tabBarInset(), nav = nav, gridState = gridState) {
            Layout(
                content = {
                    Line(stringRes(R.string.walls_browse_title), Type.sheetTitle(), Tokens.Colors.globalTextPrimary, Modifier.semantics { heading() })
                    PersonRow(state, onSelect)
                },
            ) { measurables, constraints ->
                // Header spans the grid width; the row is laid out across the full screen width (the grid's insets are undone).
                val gridInset = Tokens.Sizes.wallsMineDimensionGridInset.roundToPx()
                val title = measurables[0].measure(Constraints(maxWidth = constraints.maxWidth))
                val row = measurables[1].measure(Constraints(minWidth = constraints.maxWidth + 2 * gridInset, maxWidth = constraints.maxWidth + 2 * gridInset))
                val titleY = (top + Tokens.Sizes.wallsBrowseDimensionTitleBaseline).roundToPx() - title[FirstBaseline]
                val rowY = (top + Tokens.Sizes.wallsBrowseDimensionRowCenter).roundToPx() - Tokens.Sizes.wallsBrowseDimensionAvatar.roundToPx() / 2
                val height = (top + Tokens.Sizes.wallsBrowseDimensionWallTop - Tokens.Sizes.wallsMineDimensionGridGap).roundToPx()
                layout(constraints.maxWidth, max(height, rowY + row.height)) {
                    title.place((constraints.maxWidth - title.width) / 2, titleY)
                    row.place(-gridInset, rowY)
                }
            }
        }
    }
}

/**
 * The person row: `walls.browse.dimension.avatar` circles at `.avatarPitch`, the first at
 * `.rowInset`; the first name under each (text role `caption`), baseline `.labelBaselineGap` below
 * the circle, one line no wider than the pitch.
 */
@Composable
private fun PersonRow(state: BrowseState, onSelect: (String) -> Unit) {
    val avatar = Tokens.Sizes.wallsBrowseDimensionAvatar
    val pitch = Tokens.Sizes.wallsBrowseDimensionAvatarPitch
    LazyRow(
        contentPadding = PaddingValues(start = Tokens.Sizes.wallsBrowseDimensionRowInset, end = Tokens.Sizes.wallsBrowseDimensionRowInset),
        horizontalArrangement = Arrangement.spacedBy(pitch - avatar),
    ) {
        items(state.people, key = { it.profile.id }) { person ->
            val name = if (person.isMe) stringRes(R.string.walls_browse_me) else person.profile.firstName ?: person.profile.displayName
            val label = if (person.isMe) stringRes(R.string.walls_mine_title) else stringRes(R.string.walls_member_a11y_wall, name)
            val isSelected = state.selected == person.profile.id
            Layout(
                modifier = Modifier
                    .clickable(role = Role.Button) { onSelect(person.profile.id) }
                    .clearAndSetSemantics {
                        contentDescription = label
                        role = Role.Button
                        selected = isSelected
                    },
                content = {
                    Avatar(person.profile.avatarPath, avatar)
                    Line(name, Type.caption(), Tokens.Colors.globalTextPrimary)
                },
            ) { measurables, _ ->
                val circle = measurables[0].measure(Constraints.fixed(avatar.roundToPx(), avatar.roundToPx()))
                val text = measurables[1].measure(Constraints(maxWidth = pitch.roundToPx()))
                val baseline = circle.height + Tokens.Sizes.wallsBrowseDimensionLabelBaselineGap.roundToPx()
                val textY = baseline - text[FirstBaseline]
                layout(circle.width, max(circle.height, textY + text.height)) {
                    circle.place(0, 0)
                    text.place((circle.width - text.width) / 2, textY)
                }
            }
        }
    }
}

@Suppress("unused")
private val zero: Dp = 0.dp
