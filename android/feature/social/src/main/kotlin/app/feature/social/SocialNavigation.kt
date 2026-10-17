package app.feature.social

import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.SideEffect
import androidx.compose.runtime.remember
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.window.DialogProperties
import androidx.compose.ui.window.DialogWindowProvider
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.navigation.NavGraphBuilder
import androidx.navigation.NavHostController
import androidx.navigation.compose.composable
import androidx.navigation.compose.dialog
import androidx.navigation.toRoute
import app.feature.social.albums.AlbumViewModel
import app.feature.social.albums.AlbumViewSheet
import app.feature.social.albums.AlbumsListScreen
import app.feature.social.albums.AlbumsViewModel
import app.feature.social.chat.ChatNav
import app.feature.social.chat.ChatScreen
import app.feature.social.chat.ChatViewModel
import app.feature.social.chat.LinkPreviewBuilder
import app.feature.social.data.GraphSocialData
import app.feature.social.common.LocalSocialData
import app.feature.social.common.SocialRoot
import app.feature.social.data.SocialData
import app.feature.social.data.socialDataFor
import app.feature.social.search.SearchNav
import app.feature.social.search.SearchPhotosScreen
import app.feature.social.search.SearchViewModel
import app.feature.social.viewer.PhotoViewerScreen
import app.feature.social.viewer.PhotoViewerViewModel
import app.feature.social.viewer.ViewerNav
import app.feature.social.walls.BrowseViewModel
import app.feature.social.walls.FavoritesNav
import app.feature.social.walls.FavoritesScreen
import app.feature.social.walls.FavoritesViewModel
import app.feature.social.walls.WallMemberScreen
import app.feature.social.walls.WallMineScreen
import app.feature.social.walls.WallNav
import app.feature.social.walls.WallViewModel
import app.feature.social.walls.WallsBrowseScreen
import app.feature.social.week.HistoryNav
import app.feature.social.week.HistoryViewModel
import app.feature.social.week.RecapListViewModel
import app.feature.social.week.RecapNav
import app.feature.social.week.RecapViewModel
import app.feature.social.week.WeekEditSheet
import app.feature.social.week.WeekEditViewModel
import app.feature.social.week.WeekHistoryScreen
import app.feature.social.week.WeekRecapListSheet
import app.feature.social.week.WeekRecapScreen
import androidx.compose.ui.res.stringResource
import app.data.model.DownloadScope
import app.designsystem.R
import app.feature.social.downloads.DownloadRoute
import app.feature.social.downloads.DownloadViewModel
import app.feature.social.downloads.GalleryDownloadSaver
import app.feature.social.downloads.PrefsDownloadCursors
import app.model.AppRoute
import app.model.DownloadsRoute
import app.model.FavoritesRoute
import app.ui.paywall.openPaywallFromLockedPerk
import app.model.PhotoContext
import app.model.PhotoViewerIn
import app.model.SafetyReportMessageRoute
import app.model.SafetyReportSelfieRoute
import app.model.SearchPhotos
import app.model.SocialHandoff
import app.model.WeekAlbum
import app.model.WeekRecapAlbum
import app.model.WeekRecapList
import java.time.LocalDate

/** Tests (and previews) provide the data here; the app uses the data graph. */
val LocalSocialDataOverride = staticCompositionLocalOf<SocialData?> { null }

/** The social screens' data and theme (system appearance) around one destination. */
@Composable
private fun SocialHost(content: @Composable (SocialData) -> Unit) {
    val context = LocalContext.current
    val override = LocalSocialDataOverride.current
    val data = override ?: remember(context) { socialDataFor(context) }
    CompositionLocalProvider(LocalSocialData provides data) {
        SocialRoot { content(data) }
    }
}

/**
 * Destinations of the social feature group (surface specs in design/surfaces/): chat.thread (+ composer, voice,
 * reactions), photo.viewer, walls.*, week.*, albums.*. Page sheets (recap list, week.edit, albums.view) are dialog
 * destinations whose content is the native sheet. `search.photos` ([SearchPhotos]) is pushed from groups.list / groups.screen.
 */
fun NavGraphBuilder.socialDestinations(navController: NavHostController) {
    val nav = SocialNavigator(navController)

    composable<AppRoute.Chat> { entry ->
        val route = entry.toRoute<AppRoute.Chat>()
        SocialHost { data ->
            // Link previews are read from the network only over the real backend (never with a test / demo override).
            val vm = viewModel(key = "chat:${route.groupId}") {
                ChatViewModel(data, route.groupId, linkPreviews = if (data is GraphSocialData) LinkPreviewBuilder.live() else null)
            }
            ChatScreen(vm, route.focusMessageId, nav.chat(route.groupId, data))
        }
    }
    composable<AppRoute.PhotoViewer> { entry ->
        val route = entry.toRoute<AppRoute.PhotoViewer>()
        SocialHost { data ->
            // A link names one photo; an overnight photo opens with the photos revealed with it (the reveal push names the first).
            val vm = viewModel(key = "viewer:${route.postId}") { PhotoViewerViewModel(data, route.groupId, route.postId, PhotoContext.Reveal, route.postId, null) }
            PhotoViewerScreen(vm, nav.viewer(data))
        }
    }
    composable<PhotoViewerIn> { entry ->
        val route = entry.toRoute<PhotoViewerIn>()
        SocialHost { data ->
            val vm = viewModel(key = "viewer:${route.context}:${route.contextId}:${route.postId}") {
                PhotoViewerViewModel(data, route.groupId, route.postId, route.context, route.contextId, route.weekStart?.let(LocalDate::parse))
            }
            PhotoViewerScreen(vm, nav.viewer(data))
        }
    }
    composable<AppRoute.WallMine> {
        SocialHost { data ->
            val me = data.currentUserId().orEmpty()
            val vm = viewModel(key = "wall:$me") { WallViewModel(data, me) }
            WallMineScreen(vm, nav.walls())
        }
    }
    composable<FavoritesRoute> {
        SocialHost { data ->
            val vm = viewModel(key = "favorites") { FavoritesViewModel(data) }
            FavoritesScreen(vm, nav.favorites(data))
        }
    }
    composable<AppRoute.WallMember> { entry ->
        val route = entry.toRoute<AppRoute.WallMember>()
        SocialHost { data ->
            val vm = viewModel(key = "wall:${route.userId}") { WallViewModel(data, route.userId) }
            WallMemberScreen(vm, nav.walls())
        }
    }
    composable<AppRoute.WallsBrowse> {
        SocialHost { data ->
            val vm = viewModel(key = "browse") { BrowseViewModel(data) }
            WallsBrowseScreen(vm, nav.walls())
        }
    }
    dialog<WeekRecapList>(dialogProperties = SheetDialog) { entry ->
        val route = entry.toRoute<WeekRecapList>()
        SheetWindow()
        SocialHost { data ->
            val vm = viewModel(key = "recaps:${route.groupId}") { RecapListViewModel(data, route.groupId) }
            WeekRecapListSheet(vm, nav.recap(route.groupId))
        }
    }
    composable<AppRoute.WeekRecap> { entry ->
        val route = entry.toRoute<AppRoute.WeekRecap>()
        SocialHost { data ->
            val vm = viewModel(key = "recap:${route.recapId}") { RecapViewModel(data, route.groupId, route.recapId) }
            WeekRecapScreen(vm, nav.recap(route.groupId))
        }
    }
    dialog<AppRoute.WeekEdit>(dialogProperties = SheetDialog) { entry ->
        val route = entry.toRoute<AppRoute.WeekEdit>()
        SheetWindow()
        SocialHost { data ->
            val vm = viewModel(key = "edit:${route.recapId}") { WeekEditViewModel(data, route.groupId, route.recapId, null, albumOnly = false) }
            WeekEditSheet(vm, onClose = { navController.popBackStack() })
        }
    }
    dialog<WeekRecapAlbum>(dialogProperties = SheetDialog) { entry ->
        val route = entry.toRoute<WeekRecapAlbum>()
        SheetWindow()
        SocialHost { data ->
            val vm = viewModel(key = "album:recap:${route.recapId}") { WeekEditViewModel(data, route.groupId, route.recapId, null, albumOnly = true) }
            WeekEditSheet(vm, onClose = { navController.popBackStack() })
        }
    }
    dialog<WeekAlbum>(dialogProperties = SheetDialog) { entry ->
        val route = entry.toRoute<WeekAlbum>()
        SheetWindow()
        SocialHost { data ->
            val vm = viewModel(key = "album:${route.groupId}:${route.weekStart}") { WeekEditViewModel(data, route.groupId, null, LocalDate.parse(route.weekStart), albumOnly = true) }
            WeekEditSheet(vm, onClose = { navController.popBackStack() })
        }
    }
    composable<AppRoute.WeekHistory> { entry ->
        val route = entry.toRoute<AppRoute.WeekHistory>()
        SocialHost { data ->
            val vm = viewModel(key = "history:${route.groupId}") { HistoryViewModel(data, route.groupId) }
            WeekHistoryScreen(vm, nav.history(route.groupId))
        }
    }
    composable<SearchPhotos> { entry ->
        val route = entry.toRoute<SearchPhotos>()
        SocialHost { data ->
            val vm = viewModel(key = "search:${route.groupId}") { SearchViewModel(data, route.groupId) }
            SearchPhotosScreen(
                vm,
                SearchNav(
                    back = { navController.popBackStack() },
                    photo = { groupId, postId -> navController.navigate(PhotoViewerIn(groupId, postId, PhotoContext.Search, vm.resultsKey)) },
                ),
            )
        }
    }
    composable<AppRoute.AlbumsList> { entry ->
        val route = entry.toRoute<AppRoute.AlbumsList>()
        SocialHost { data ->
            val vm = viewModel(key = "albums:${route.groupId}") { AlbumsViewModel(data, route.groupId) }
            AlbumsListScreen(
                vm,
                onBack = { navController.popBackStack() },
                onAlbum = { id -> navController.navigate(AppRoute.AlbumView(route.groupId, id)) },
                onViewRecaps = { navController.navigate(WeekRecapList(route.groupId)) },
            )
        }
    }
    dialog<AppRoute.AlbumView>(dialogProperties = SheetDialog) { entry ->
        val route = entry.toRoute<AppRoute.AlbumView>()
        SheetWindow()
        SocialHost { data ->
            val vm = viewModel(key = "album:${route.albumId}") { AlbumViewModel(data, route.groupId, route.albumId) }
            AlbumViewSheet(
                vm,
                onClose = { navController.popBackStack() },
                onPhoto = { postId -> navController.navigate(PhotoViewerIn(route.groupId, postId, PhotoContext.Album, route.albumId)) },
                onDownload = { navController.navigate(DownloadsRoute(route.albumId)) },
                onPaywall = { navController.openPaywallFromLockedPerk(perk = PAYWALL_PERK_EXPORT) },
            )
        }
    }
    // settings.downloads: settings.root → Download My Photos (free), or an album's Download Album (premium; starts at once).
    composable<DownloadsRoute> { entry ->
        val route = entry.toRoute<DownloadsRoute>()
        SocialHost { data ->
            val context = LocalContext.current
            val gallery = app.feature.social.common.LocalSocialServices.current.gallery
            val scope = route.albumId?.let { DownloadScope.InAlbum(it) } ?: DownloadScope.Mine
            val vm = viewModel(key = "downloads:${route.albumId}") {
                DownloadViewModel(data, scope, GalleryDownloadSaver(context.applicationContext, data, gallery), PrefsDownloadCursors(context))
            }
            DownloadRoute(
                vm,
                title = stringResource(if (route.albumId != null) R.string.settings_downloads_albumtitle else R.string.settings_downloads_title),
                detail = stringResource(if (route.albumId != null) R.string.settings_downloads_albumdetail else R.string.settings_downloads_detail),
                gallery = gallery,
                onBack = { navController.popBackStack() },
                onPaywall = {
                    navController.popBackStack()
                    navController.openPaywallFromLockedPerk(perk = PAYWALL_PERK_EXPORT)
                },
                autoStart = route.albumId != null,
            )
        }
    }
}

/** The paywall perk of full-quality downloads (account's `Perk.Export.wire`; iOS `PaywallPerk.export`). */
private const val PAYWALL_PERK_EXPORT = "export"

/** Sheets over the screen below: a full-window dialog destination whose content is the native sheet. */
private val SheetDialog = DialogProperties(usePlatformDefaultWidth = false, decorFitsSystemWindows = false)

/** The dialog window itself draws nothing (the native sheet brings its own scrim). */
@Composable
private fun SheetWindow() {
    val window = (LocalView.current.parent as? DialogWindowProvider)?.window
    SideEffect { window?.setDimAmount(0f) }
}

/** Builds each screen's navigation callbacks from the routes of every group (docs/SURFACES.md). */
private class SocialNavigator(private val nav: NavHostController) {
    private fun back() {
        nav.popBackStack()
    }

    private fun person(data: SocialData, userId: String) {
        nav.navigate(if (userId == data.currentUserId()) AppRoute.WallMine else AppRoute.WallMember(userId))
    }

    /** `camera.capture` for [groupId]; a photo reply rides on the camera entry for `create_post`'s `p_reply_to_post_id`. */
    private fun camera(groupId: String?, replyToPostId: String?) {
        nav.navigate(AppRoute.Camera(groupId))
        if (replyToPostId != null) nav.currentBackStackEntry?.savedStateHandle?.set(SocialHandoff.REPLY_TO_POST_ID, replyToPostId)
    }

    fun chat(groupId: String, data: SocialData) = ChatNav(
        back = ::back,
        photo = { postId -> nav.navigate(PhotoViewerIn(groupId, postId, PhotoContext.Chat, groupId)) },
        member = { userId -> person(data, userId) },
        invite = { nav.navigate(AppRoute.GroupInvite(groupId)) },
        camera = { replyTo -> camera(groupId, replyTo) },
        reportMessage = { messageId, authorId -> nav.navigate(SafetyReportMessageRoute(groupId, messageId, authorId)) },
        reportPost = { postId -> nav.navigate(AppRoute.SafetyReport(groupId = groupId, postId = postId)) },
    )

    fun viewer(data: SocialData) = ViewerNav(
        close = ::back,
        person = { userId, _ -> person(data, userId) },
        replyWithPhoto = { groupId, postId -> camera(groupId, postId) },
        report = { groupId, postId -> nav.navigate(AppRoute.SafetyReport(groupId = groupId, postId = postId)) },
        block = { userId -> nav.navigate(AppRoute.SafetyBlock(userId)) },
        reportSelfie = { groupId, selfieId, userId -> nav.navigate(SafetyReportSelfieRoute(groupId, selfieId, userId)) },
    )

    fun walls() = WallNav(
        back = ::back,
        settings = { nav.navigate(AppRoute.Settings) },
        photo = { wallUserId, groupId, postId -> nav.navigate(PhotoViewerIn(groupId, postId, PhotoContext.Wall, wallUserId)) },
        collage = { groupId, invitationId -> nav.navigate(AppRoute.Collage(groupId, invitationId)) },
        camera = { camera(null, null) },
        createGroup = { nav.navigate(AppRoute.GroupCreate) },
        member = { userId -> nav.navigate(AppRoute.WallMember(userId)) },
        report = { userId -> nav.navigate(AppRoute.SafetyReport(userId = userId)) },
        block = { userId -> nav.navigate(AppRoute.SafetyBlock(userId)) },
        favorites = { nav.navigate(FavoritesRoute) },
    )

    fun favorites(data: SocialData) = FavoritesNav(
        back = ::back,
        photo = { groupId, postId -> nav.navigate(PhotoViewerIn(groupId, postId, PhotoContext.Favorites, data.currentUserId().orEmpty())) },
    )

    fun recap(groupId: String) = RecapNav(
        back = ::back,
        open = { recapId -> nav.navigate(AppRoute.WeekRecap(groupId, recapId)) },
        edit = { recapId -> nav.navigate(AppRoute.WeekEdit(groupId, recapId)) },
        saveAsAlbum = { recapId -> nav.navigate(WeekRecapAlbum(groupId, recapId)) },
        cardPhoto = { recapId, postId -> nav.navigate(PhotoViewerIn(groupId, postId, PhotoContext.Recap, recapId)) },
        camera = { camera(groupId, null) },
        report = { recapId -> nav.navigate(app.model.SafetyReportContentRoute("recap", recapId, groupId)) },
        collage = { invitationId -> nav.navigate(AppRoute.Collage(groupId, invitationId)) },
    )

    fun history(groupId: String) = HistoryNav(
        back = ::back,
        photo = { weekStart, postId -> nav.navigate(PhotoViewerIn(groupId, postId, PhotoContext.Week, groupId, weekStart)) },
        recap = { recapId -> nav.navigate(AppRoute.WeekRecap(groupId, recapId)) },
        saveAsAlbum = { weekStart -> nav.navigate(WeekAlbum(groupId, weekStart)) },
        camera = { camera(groupId, null) },
        collage = { invitationId -> nav.navigate(AppRoute.Collage(groupId, invitationId)) },
    )
}
