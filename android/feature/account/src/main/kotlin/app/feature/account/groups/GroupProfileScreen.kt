// Surface: groups.screen — B. group profile page (avatar, name, members, "pics | wall | recaps", ••• menu).
// Spec: design/surfaces/groups.screen.md (B). References:
// references/auto/yope/frames/a-itsmthuyope-7644974799302823175-t51.73-group-profile-add-20-pics.png (G3),
// a-yrrah-7434441926000037121-t33.73-group-menu-leave-report-2024.png (M24).
package app.feature.account.groups

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.asPaddingValues
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBars
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.GridItemSpan
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextAlign
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.navigation.NavController
import app.data.model.Post
import app.designsystem.R
import app.designsystem.dsTextStyle
import app.designsystem.generated.Tokens
import app.feature.account.LocalAccountEnvironment
import app.feature.account.common.AccountEvent
import app.feature.account.common.CollectEvents
import app.feature.account.common.navigateAccount
import app.model.AppRoute
import app.ui.components.Avatar
import app.ui.components.HeaderCircleButton
import app.ui.components.HeaderCircleFill
import app.ui.components.SegmentedControl
import app.ui.haptics.rememberHaptics
import app.ui.system.SystemAlertDialog
import coil3.compose.AsyncImage

@Composable
fun GroupProfileRoute(nav: NavController, groupId: String) {
    val env = LocalAccountEnvironment.current
    val vm = viewModel(key = "feed:$groupId") { GroupFeedViewModel(env, groupId) }
    val state by vm.state.collectAsStateWithLifecycle()
    CollectEvents(vm.events, nav)
    val haptics = rememberHaptics()
    var confirmLeave by remember { mutableStateOf(false) }
    GroupProfileScreen(
        state = state,
        onBack = { nav.popBackStack() },
        onMembers = { nav.navigate(AppRoute.GroupSettings(groupId)) },
        onPhoto = { nav.navigate(AppRoute.PhotoViewer(groupId, it.id)) },
        onWall = { nav.navigate(AppRoute.WallsBrowse) },
        onRecaps = { nav.navigate(AppRoute.WeekHistory(groupId)) },
        onShareInvite = { nav.navigate(AppRoute.GroupInvite(groupId)) },
        onSettings = { nav.navigate(AppRoute.GroupSettings(groupId)) },
        onLeave = { confirmLeave = true },
        onReport = { nav.navigate(AppRoute.SafetyReport(groupId = groupId)) },
    )
    if (confirmLeave) {
        LeaveGroupDialog(
            groupName = state.group?.name.orEmpty(),
            last = state.otherNames.isEmpty(),
            onConfirm = {
                confirmLeave = false
                haptics.perform(Tokens.Haptics.globalWarning)
                GroupActions.leave(env, groupId)
                nav.navigateAccount(AccountEvent.Navigate(AppRoute.GroupsList, clearStack = true))
            },
            onDismiss = { confirmLeave = false },
        )
    }
}

/** The leave alert of groups.settings (`settings.account.layout.alert`), shared with the profile ••• menu. */
@Composable
internal fun LeaveGroupDialog(groupName: String, last: Boolean, onConfirm: () -> Unit, onDismiss: () -> Unit) {
    SystemAlertDialog(
        title = stringResource(R.string.groups_settings_leave_title, groupName),
        text = stringResource(if (last) R.string.groups_settings_leave_messagelast else R.string.groups_settings_leave_message),
        confirmLabel = stringResource(R.string.groups_settings_leave_confirm),
        onConfirm = onConfirm,
        dismissLabel = stringResource(R.string.groups_settings_alert_cancel),
        onDismiss = onDismiss,
        destructive = true,
    )
}

/**
 * Background `groups.screen.layout.background` profile = `color.global.backgroundDeep`; ‹ (fill
 * `color.global.controlOnDeep`) and ••• header circles; group avatar `groups.screen.size.profileAvatar`;
 * name `groups.screen.fontSize.profileName` / `.fontWeight.profileName`, up to 2 lines; member avatars
 * (`size.global.avatarSmall`, overlapping by `size.global.headerGap` — not measured; no count) →
 * groups.settings; segmented control (`groups.screen.size.segmentMarginH`); pics = the group's photos
 * in a grid (`radius.global.photo`; columns, gap and tile shape reuse the Yope wall grid tokens
 * `walls.mine.count.gridColumns` / `.dimension.gridGap` / `.aspectRatio.gridTile` — approximation);
 * wall → walls.browse; recaps → week.history.
 */
@Composable
fun GroupProfileScreen(
    state: GroupFeedUiState,
    onBack: () -> Unit,
    onMembers: () -> Unit,
    onPhoto: (Post) -> Unit,
    onWall: () -> Unit,
    onRecaps: () -> Unit,
    onShareInvite: () -> Unit,
    onSettings: () -> Unit,
    onLeave: () -> Unit,
    onReport: () -> Unit,
) {
    var menu by remember { mutableStateOf(false) }
    val photos = state.items.orEmpty().filterIsInstance<FeedItem.Photo>()
    val columns = Tokens.Counts.wallsMineCountGridColumns
    val bottom = WindowInsets.navigationBars.asPaddingValues().calculateBottomPadding()
    Box(Modifier.fillMaxSize().background(Tokens.Colors.globalBackgroundDeep)) {
        LazyVerticalGrid(
            columns = GridCells.Fixed(columns),
            modifier = Modifier.fillMaxSize().windowInsetsPadding(WindowInsets.statusBars),
            contentPadding = PaddingValues(start = Tokens.Sizes.groupsScreenSizeSegmentMarginH, end = Tokens.Sizes.groupsScreenSizeSegmentMarginH, bottom = bottom),
            horizontalArrangement = Arrangement.spacedBy(Tokens.Sizes.wallsMineDimensionGridGap),
            verticalArrangement = Arrangement.spacedBy(Tokens.Sizes.wallsMineDimensionGridGap),
        ) {
            item(key = "header", span = { GridItemSpan(maxLineSpan) }) {
                Box(Modifier.fillMaxWidth().padding(horizontal = Tokens.Sizes.globalHeaderInset - Tokens.Sizes.groupsScreenSizeSegmentMarginH)) {
                    HeaderCircleButton(Tokens.Icons.globalBack, stringResource(R.string.groups_screen_back_accessibilitylabel), onBack, fill = HeaderCircleFill.OnDeep, modifier = Modifier.align(Alignment.CenterStart))
                    Box(Modifier.align(Alignment.CenterEnd)) {
                        HeaderCircleButton(Tokens.Icons.globalMore, stringResource(R.string.groups_screen_profile_more_accessibilitylabel), { menu = true }, fill = HeaderCircleFill.OnDeep)
                        DropdownMenu(expanded = menu, onDismissRequest = { menu = false }, containerColor = Tokens.Colors.globalSystemSurfaceContainerHigh) {
                            MenuItem(stringResource(R.string.groups_screen_menu_shareinvite), destructive = false, icon = Tokens.Icons.globalShare) { menu = false; onShareInvite() }
                            MenuItem(stringResource(R.string.groups_screen_menu_settings), destructive = false, icon = Tokens.Icons.globalSettings) { menu = false; onSettings() }
                            MenuItem(stringResource(R.string.groups_screen_menu_leave), destructive = true, icon = Tokens.Icons.globalLeave) { menu = false; onLeave() }
                            MenuItem(stringResource(R.string.groups_screen_menu_report), destructive = true, icon = Tokens.Icons.globalReport) { menu = false; onReport() }
                        }
                    }
                }
            }
            item(key = "identity", span = { GridItemSpan(maxLineSpan) }) {
                androidx.compose.foundation.layout.Column(horizontalAlignment = Alignment.CenterHorizontally, modifier = Modifier.fillMaxWidth()) {
                    Avatar(state.groupAvatarUrl, Tokens.Sizes.groupsScreenSizeProfileAvatar, fallbackIcon = Tokens.Icons.globalGroup)
                    Text(
                        state.group?.name.orEmpty(),
                        style = dsTextStyle(Tokens.FontSizes.groupsScreenFontSizeProfileName, Tokens.FontWeights.groupsScreenFontWeightProfileName),
                        color = Tokens.Colors.globalTextPrimary,
                        textAlign = TextAlign.Center,
                        maxLines = 2,
                        modifier = Modifier.semantics { heading() },
                    )
                    MemberAvatars(state, onMembers)
                    Spacer(Modifier.height(Tokens.Sizes.groupsScreenSizeCardGap))
                    var segment by remember { mutableStateOf(0) }
                    SegmentedControl(
                        options = listOf(
                            stringResource(R.string.groups_screen_profile_segment_pics),
                            stringResource(R.string.groups_screen_profile_segment_wall),
                            stringResource(R.string.groups_screen_profile_segment_recaps),
                        ),
                        selectedIndex = segment,
                        onSelect = { index ->
                            when (index) {
                                1 -> onWall()
                                2 -> onRecaps()
                                else -> segment = 0
                            }
                        },
                    )
                    Spacer(Modifier.height(Tokens.Sizes.groupsScreenSizeCardGap))
                }
            }
            items(photos, key = { it.key }) { photo ->
                val shape = RoundedCornerShape(Tokens.Radii.globalPhoto)
                Box(
                    Modifier
                        .aspectRatio(Tokens.AspectRatios.wallsMineAspectRatioGridTile)
                        .clip(shape)
                        .background(Tokens.Colors.globalControlRaised, shape)
                        .clickable(role = Role.Image) { onPhoto(photo.post) },
                ) {
                    if (photo.url != null) AsyncImage(photo.url, contentDescription = null, contentScale = ContentScale.Crop, modifier = Modifier.fillMaxSize())
                }
            }
        }
    }
}

@Composable
private fun MemberAvatars(state: GroupFeedUiState, onMembers: () -> Unit) {
    val label = stringResource(R.string.groups_settings_members_header)
    Row(
        Modifier
            .padding(vertical = Tokens.Sizes.groupsScreenSizeCardGap)
            .clickable(role = Role.Button, onClick = onMembers)
            .semantics(mergeDescendants = true) { contentDescription = label },
        horizontalArrangement = Arrangement.spacedBy(-Tokens.Sizes.globalHeaderGap),
    ) {
        // Every member's avatar, no count (tenet 2).
        state.memberAvatars.forEach { Avatar(it, Tokens.Sizes.globalAvatarSmall) }
    }
}
