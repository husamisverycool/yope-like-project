package app.feature.account.shell

import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.navigation.NavDestination.Companion.hasRoute
import androidx.navigation.NavHostController
import androidx.navigation.compose.currentBackStackEntryAsState
import app.designsystem.R
import app.designsystem.generated.Tokens
import app.feature.account.AccountEnvironment
import app.model.AppRoute
import app.ui.components.TabBar
import app.ui.components.TabBarItem

/** The app's four tab destinations, in `groups.list.layout.tabBar` order: camera · groups (home) · walls (people) · me (profile). */
enum class AppTab { Camera, Groups, Walls, Me }

/**
 * The app chrome (`groups.list.layout.tabBar`, MERGE RA-7): the C-04 tab bar under the tab destinations — camera.capture
 * (`icon.global.camera`), groups.list (`icon.global.home`), walls.browse (`icon.global.group`), walls.mine
 * (`icon.global.wall`); icon-only, evenly distributed, page-coloured, no hairline, no labels, no unread dot (this app has no
 * Activity tab). While the camera tab shows, the bar sits over the black camera surface (C-04 `overMedia`: selected
 * `color.global.textOnMedia`, unselected `color.global.tabInactiveOnMedia`). TalkBack labels from copy; a tab change
 * plays `haptic.global.tap`.
 */
@Composable
fun ShellTabBar(nav: NavHostController, @Suppress("UNUSED_PARAMETER") env: AccountEnvironment, modifier: Modifier = Modifier) {
    val entry by nav.currentBackStackEntryAsState()
    val destination = entry?.destination
    val selected = when {
        destination == null -> null
        destination.hasRoute<AppRoute.Camera>() -> AppTab.Camera
        destination.hasRoute<AppRoute.GroupsList>() -> AppTab.Groups
        destination.hasRoute<AppRoute.WallsBrowse>() -> AppTab.Walls
        destination.hasRoute<AppRoute.WallMine>() -> AppTab.Me
        else -> null
    } ?: return
    val items = listOf(
        TabBarItem(Tokens.Icons.globalCamera, stringResource(R.string.groups_list_tab_camera_accessibilitylabel)),
        TabBarItem(Tokens.Icons.globalHome, stringResource(R.string.groups_list_tab_groups_accessibilitylabel)),
        TabBarItem(Tokens.Icons.globalGroup, stringResource(R.string.groups_list_tab_walls_accessibilitylabel)),
        TabBarItem(Tokens.Icons.globalWall, stringResource(R.string.groups_list_tab_me_accessibilitylabel)),
    )
    TabBar(
        items = items,
        selectedIndex = selected.ordinal,
        overMedia = selected == AppTab.Camera,
        modifier = modifier,
        onSelect = { index ->
            val tab = AppTab.entries[index]
            val route = when (tab) {
                AppTab.Camera -> AppRoute.Camera()
                AppTab.Groups -> AppRoute.GroupsList
                AppTab.Walls -> AppRoute.WallsBrowse
                AppTab.Me -> AppRoute.WallMine
            }
            when {
                tab == selected -> Unit
                tab == AppTab.Camera -> nav.navigate(route) { launchSingleTop = true }
                else -> {
                    // The camera is never kept in a tab's saved state: leave it first.
                    if (selected == AppTab.Camera) nav.popBackStack()
                    if (nav.currentDestination?.hasRoute(route::class) != true) {
                        nav.navigate(route) {
                            popUpTo(nav.graph.startDestinationId) { saveState = true }
                            launchSingleTop = true
                            restoreState = true
                        }
                    }
                }
            }
        },
    )
}
