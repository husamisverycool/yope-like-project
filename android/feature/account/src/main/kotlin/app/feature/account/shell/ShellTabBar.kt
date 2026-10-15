package app.feature.account.shell

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.navigation.NavDestination.Companion.hasRoute
import androidx.navigation.NavHostController
import androidx.navigation.compose.currentBackStackEntryAsState
import app.data.repo.AuthState
import app.designsystem.R
import app.designsystem.generated.Tokens
import app.feature.account.AccountEnvironment
import app.model.AppRoute
import app.ui.components.AppTab
import app.ui.components.FloatingTabBar
import app.ui.components.FloatingTabBarSlot
import app.ui.components.TabLabels

/**
 * The app chrome: the floating tab bar (`groups.list.layout.tabBar`) over the tab destinations —
 * camera.capture (camera, the bar under the camera as on Yope's), groups.list (groups), walls.browse
 * (walls), walls.mine (me, own avatar).
 * Placed `size.global.tabBarInset` from the screen sides, above the navigation bar.
 */
@Composable
fun ShellTabBar(nav: NavHostController, env: AccountEnvironment, modifier: Modifier = Modifier) {
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
    var avatar by remember { mutableStateOf<String?>(null) }
    val auth by env.backend.authState.collectAsState()
    LaunchedEffect(auth) {
        if (auth is AuthState.SignedIn) {
            avatar = runCatching {
                val path = env.backend.me().avatarPath
                path?.let { env.backend.signedUrls(listOf(it))[it] }
            }.getOrNull()
        }
    }
    val labels = TabLabels(
        camera = stringResource(R.string.groups_list_tab_camera_accessibilitylabel),
        groups = stringResource(R.string.groups_list_tab_groups_accessibilitylabel),
        walls = stringResource(R.string.groups_list_tab_walls_accessibilitylabel),
        me = stringResource(R.string.groups_list_tab_me_accessibilitylabel),
    )
    FloatingTabBarSlot(
        modifier = modifier.windowInsetsPadding(WindowInsets.navigationBars).padding(bottom = Tokens.Sizes.globalTabBarInset),
        content = {
            FloatingTabBar(
                selected = selected,
                labels = labels,
                meAvatar = avatar,
                onSelect = { tab ->
                    val route = when (tab) {
                        AppTab.Camera -> AppRoute.Camera()
                        AppTab.Groups -> AppRoute.GroupsList
                        AppTab.Walls -> AppRoute.WallsBrowse
                        AppTab.Me -> AppRoute.WallMine
                    }
                    if (tab == selected) {
                        // Already there.
                    } else if (tab == AppTab.Camera) {
                        nav.navigate(route) { launchSingleTop = true }
                    } else {
                        nav.navigate(route) {
                            popUpTo(nav.graph.startDestinationId) { saveState = true }
                            launchSingleTop = true
                            restoreState = true
                        }
                    }
                },
            )
        },
    )
}
