// Surface: favorites — design/surfaces/favorites.md: your private favorites (Apple Photos Favorites; owner decision 34,
// docs/RESEARCH_FEATURES_2026-10-17.md #19) as the pushed `albums.list` header over the `albums.view` grid.
// References: references/auto/retro/store/editorial/retro-appstore-story-1854931006-week3-albums.png (pushed header),
// references/auto/retro/press/tc-2024-04-journals-1.webp phone 3 (grid). No count anywhere (tenet 2).
package app.feature.social.walls

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
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
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.GridItemSpan
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.itemsIndexed
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.role
import androidx.lifecycle.ViewModel
import androidx.lifecycle.compose.LifecycleResumeEffect
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewModelScope
import app.data.error.DataError
import app.data.model.FavoritePhoto
import app.designsystem.R
import app.designsystem.generated.Tokens
import app.feature.social.albums.gridCellShape
import app.feature.social.common.Formats
import app.feature.social.common.RemotePhoto
import app.feature.social.common.stringRes
import app.feature.social.common.videoDurationMs
import app.feature.social.common.withVideoLabel
import app.feature.social.data.SocialData
import app.feature.social.data.dataError
import app.ui.components.ActivityIndicator
import app.ui.components.EmptyState
import app.ui.components.EmptyStateFill
import app.ui.components.PushedHeader
import app.ui.components.VideoTileMarker
import app.ui.foundation.PageRoles
import app.ui.foundation.tapClickable
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.flow.drop
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import java.time.Instant

/** Where `favorites` leads (favorites.md → Navigation out). */
data class FavoritesNav(
    val back: () -> Unit,
    /** `photo.viewer` on that photo, the context being your favorites ([app.model.PhotoContext.Favorites]). */
    val photo: (groupId: String, postId: String) -> Unit,
)

/** One cell: the favorite, its author's first name and, for a video, its length (the video pill). */
data class FavoriteTile(val favorite: FavoritePhoto, val authorName: String?, val videoDurationMs: Long? = null)

data class FavoritesState(
    val phase: Phase = Phase.Loading,
    /** Newest favorite first (`favorited_at`). */
    val tiles: List<FavoriteTile> = emptyList(),
    val me: String? = null,
    val loadingMore: Boolean = false,
    val offline: Boolean = false,
) {
    enum class Phase { Loading, Ready, Empty, Error, OfflineEmpty }
}

/**
 * `favorites`: `my_favorites` newest favorite first, pages of 60 (`p_before` = the last `favorited_at`). Kept in memory
 * only (a deleted photo never survives on the device): offline shows what loaded this session, else the error line.
 * Reloaded on resume (an Unfavorite in the viewer leaves the grid) and when back online.
 */
class FavoritesViewModel(private val data: SocialData) : ViewModel() {
    private val _state = MutableStateFlow(FavoritesState(me = data.currentUserId()))
    val state: StateFlow<FavoritesState> = _state.asStateFlow()
    private var cursor: Instant? = null
    private var loadJob: Job? = null

    init {
        viewModelScope.launch { data.online.distinctUntilChanged().drop(1).collect { if (it) load() } }
    }

    fun load() {
        loadJob?.cancel()
        loadJob = viewModelScope.launch {
            try {
                val rows = data.myFavorites(null, PAGE)
                cursor = if (rows.size == PAGE) rows.lastOrNull()?.favoritedAt else null
                val tiles = tiles(rows)
                _state.update { it.copy(phase = if (tiles.isEmpty()) FavoritesState.Phase.Empty else FavoritesState.Phase.Ready, tiles = tiles, offline = false) }
            } catch (e: CancellationException) {
                throw e
            } catch (e: Throwable) {
                val offline = e.dataError() == DataError.Network
                _state.update {
                    when {
                        it.tiles.isNotEmpty() -> it.copy(offline = offline)
                        offline -> it.copy(phase = FavoritesState.Phase.OfflineEmpty, offline = true)
                        else -> it.copy(phase = FavoritesState.Phase.Error)
                    }
                }
            }
        }
    }

    /** The last row shows: the next page. */
    fun loadMore() {
        val before = cursor ?: return
        val s = _state.value
        if (s.loadingMore || s.phase != FavoritesState.Phase.Ready) return
        _state.update { it.copy(loadingMore = true) }
        viewModelScope.launch {
            try {
                val rows = data.myFavorites(before, PAGE)
                cursor = if (rows.size == PAGE) rows.lastOrNull()?.favoritedAt else null
                val more = tiles(rows)
                _state.update { st ->
                    val known = st.tiles.map { it.favorite.mediaId }.toSet()
                    st.copy(tiles = st.tiles + more.filter { it.favorite.mediaId !in known }, loadingMore = false)
                }
            } catch (e: CancellationException) {
                throw e
            } catch (_: Throwable) {
                _state.update { it.copy(loadingMore = false) }
            }
        }
    }

    private suspend fun tiles(rows: List<FavoritePhoto>): List<FavoriteTile> {
        val names = runCatching { data.profiles(rows.map { it.authorId }.distinct()) }.getOrDefault(emptyList()).associate { it.id to it.firstName }
        val videos = rows.filter { it.kind == app.data.model.MediaKind.Video }.map { it.mediaId }
        val durations = if (videos.isEmpty()) emptyMap() else runCatching { data.media(videos) }.getOrDefault(emptyList()).associate { it.id to it.videoDurationMs }
        return rows.map { FavoriteTile(it, names[it.authorId], durations[it.mediaId]) }
    }

    private companion object {
        /** `favorites`: `my_favorites(p_limit: 60)`. */
        const val PAGE = 60
    }
}

@Composable
fun FavoritesScreen(vm: FavoritesViewModel, nav: FavoritesNav) {
    val state by vm.state.collectAsStateWithLifecycle()
    LifecycleResumeEffect(vm) {
        vm.load()
        onPauseOrDispose { }
    }
    FavoritesContent(state, nav, onRetry = vm::load, onMore = vm::loadMore)
}

/**
 * `favorites`: C-02 "Favorites"; the grid `size.global.titleToContent` below — `albums.view.count.gridColumns` columns of
 * `albums.view.aspectRatio.gridCell` cells, `size.global.stripGap` gaps, outer corners `albums.view.radius.grid`.
 */
@Composable
fun FavoritesContent(state: FavoritesState, nav: FavoritesNav, onRetry: () -> Unit, onMore: () -> Unit) {
    val margin = Tokens.Sizes.globalScreenMargin
    val gap = Tokens.Sizes.globalStripGap
    val columns = Tokens.Counts.albumsViewCountGridColumns
    val bottom = WindowInsets.navigationBars.asPaddingValues().calculateBottomPadding()
    Column(Modifier.fillMaxSize().background(PageRoles.page).statusBarsPadding().testTag("favorites")) {
        PushedHeader(stringRes(R.string.favorites_title), nav.back, stringRes(R.string.chat_thread_a11y_back))
        when (state.phase) {
            FavoritesState.Phase.Error, FavoritesState.Phase.OfflineEmpty ->
                ErrorLine(stringRes(R.string.favorites_error_title), onRetry, Modifier.padding(top = Tokens.Sizes.globalTitleToContent))
            FavoritesState.Phase.Empty -> EmptyStateFill(Modifier.weight(1f).padding(bottom = bottom)) {
                EmptyState(stringRes(R.string.favorites_empty_title), stringRes(R.string.favorites_empty_detail), icon = Tokens.Icons.globalFavorite)
            }
            FavoritesState.Phase.Loading, FavoritesState.Phase.Ready -> LazyVerticalGrid(
                columns = GridCells.Fixed(columns),
                modifier = Modifier.fillMaxWidth().weight(1f),
                contentPadding = PaddingValues(start = margin, end = margin, top = Tokens.Sizes.globalTitleToContent, bottom = bottom + Tokens.Sizes.globalSectionGap),
                horizontalArrangement = Arrangement.spacedBy(gap),
                verticalArrangement = Arrangement.spacedBy(gap),
            ) {
                if (state.phase == FavoritesState.Phase.Loading) {
                    itemsIndexed(List(columns * 2) { it }, key = { _, i -> "loading-$i" }) { i, _ ->
                        Box(Modifier.aspectRatio(Tokens.AspectRatios.albumsViewAspectRatioGridCell).clip(gridCellShape(i, columns * 2, columns)).background(Tokens.Colors.globalControl))
                    }
                } else {
                    val tiles = state.tiles
                    itemsIndexed(tiles, key = { _, t -> t.favorite.mediaId }) { i, tile ->
                        if (i == tiles.lastIndex) LaunchedEffect(tile.favorite.mediaId) { onMore() }
                        FavoriteCell(tile, state.me, gridCellShape(i, tiles.size, columns)) { nav.photo(tile.favorite.groupId, tile.favorite.postId) }
                    }
                    if (state.loadingMore) {
                        item(key = "more", span = { GridItemSpan(maxLineSpan) }) {
                            Box(Modifier.fillMaxWidth().padding(top = Tokens.Sizes.globalSectionGap), contentAlignment = Alignment.Center) { ActivityIndicator(null) }
                        }
                    }
                }
            }
        }
    }
}

/** A favorite's cell: `photo.viewer.a11y.photoMine` / `.photo` (the day it was posted) plus the video length. */
@Composable
private fun FavoriteCell(tile: FavoriteTile, me: String?, shape: androidx.compose.ui.graphics.Shape, onClick: () -> Unit) {
    val date = Formats.viewerDate(tile.favorite.takenAt)
    val base = if (tile.favorite.authorId == me) stringRes(R.string.photo_viewer_a11y_photomine, date)
    else stringRes(R.string.photo_viewer_a11y_photo, tile.authorName.orEmpty(), date)
    val label = withVideoLabel(LocalContext.current, base, tile.videoDurationMs)
    Box(
        Modifier
            .aspectRatio(Tokens.AspectRatios.albumsViewAspectRatioGridCell)
            .clip(shape)
            .tapClickable(onClick = onClick)
            .clearAndSetSemantics {
                contentDescription = label
                role = Role.Button
            },
    ) {
        RemotePhoto(tile.favorite.thumbPath, null, Modifier.fillMaxSize())
        tile.videoDurationMs?.let { VideoTileMarker(it) }
    }
}
