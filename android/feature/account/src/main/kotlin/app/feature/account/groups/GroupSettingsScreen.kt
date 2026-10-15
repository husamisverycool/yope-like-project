// Surface: groups.settings — members, mute, quiet hours, invitation hours / pause, leave, report, block.
// Spec: design/surfaces/groups.settings.md. References:
// references/auto/yope/frames/a-yrrah-7434441926000037121-t33.73-group-menu-leave-report-2024.png (M24),
// a-yrrah-7434441926000037121-t43.23-members-list-2024.png (ML24), a-itsmthuyope-7644974799302823175-t51.23-group-created-empty-state.png (E26),
// https://developer.apple.com/design/human-interface-guidelines/lists-and-tables (HIG), https://m3.material.io/components/lists/specs (M3).
package app.feature.account.groups

import androidx.compose.foundation.layout.Box
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TimePicker
import androidx.compose.material3.rememberTimePickerState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.Immutable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewModelScope
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.navigation.NavController
import app.data.error.ApiError
import app.data.error.DataError
import app.data.model.Group
import app.data.model.GroupKind
import app.data.model.MemberRole
import app.designsystem.R
import app.designsystem.generated.Tokens
import app.feature.account.AccountEnvironment
import app.feature.account.LocalAccountEnvironment
import app.feature.account.blocked.BlockedCopy
import app.feature.account.common.AccountEvent
import app.feature.account.common.AccountViewModel
import app.feature.account.common.CollectEvents
import app.feature.account.common.dataError
import app.feature.account.common.navigateAccount
import app.model.AppRoute
import app.model.GroupEditRoute
import app.ui.components.Avatar
import app.ui.format.Formats
import app.ui.permissions.PermissionChecks
import app.ui.system.SystemAlertDialog
import app.ui.system.SystemDivider
import app.ui.system.SystemList
import app.ui.system.SystemLoading
import app.ui.system.SystemRow
import app.ui.system.SystemScaffold
import app.ui.system.SystemSectionFooter
import app.ui.system.SystemSectionHeader
import app.ui.system.SystemSwitchRow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import java.time.LocalTime

@Immutable
data class MemberRow(val userId: String, val name: String, val firstName: String, val avatarUrl: String?, val admin: Boolean, val you: Boolean)

/** Which section shows an error footer after a failed save. */
enum class SettingsSection { Members, Notifications, Invitation }

@Immutable
data class GroupSettingsUiState(
    val group: Group? = null,
    val members: List<MemberRow>? = null,
    val muted: Boolean = false,
    val isAdmin: Boolean = false,
    val full: Boolean = false,
    val online: Boolean = true,
    val errorIn: SettingsSection? = null,
    val invalidWindow: Boolean = false,
) {
    val loading: Boolean get() = group == null || members == null
}

class GroupSettingsViewModel(private val env: AccountEnvironment, private val groupId: String) : AccountViewModel() {
    private val mutable = MutableStateFlow(GroupSettingsUiState())
    val state: StateFlow<GroupSettingsUiState> = mutable.asStateFlow()

    init {
        viewModelScope.launch { env.backend.online.collect { online -> mutable.update { it.copy(online = online) } } }
        load()
    }

    fun load() {
        viewModelScope.launch {
            env.backend.observeMyGroups().collect { page -> page.value?.firstOrNull { it.id == groupId }?.let { g -> mutable.update { it.copy(group = g) } } }
        }
        viewModelScope.launch {
            env.backend.observeMembers(groupId).collect { page ->
                val list = page.value ?: return@collect
                val me = env.backend.currentUserId
                val urls = runCatching { env.backend.signedUrls(list.mapNotNull { it.profile?.avatarPath }) }.getOrDefault(emptyMap())
                val rows = list.map { m ->
                    MemberRow(
                        userId = m.member.userId,
                        name = m.profile?.displayName.orEmpty(),
                        firstName = m.profile?.firstName.orEmpty(),
                        avatarUrl = m.profile?.avatarPath?.let(urls::get),
                        admin = m.member.role == MemberRole.Admin,
                        you = m.member.userId == me,
                    )
                }
                val mine = list.firstOrNull { it.member.userId == me }
                val max = runCatching { env.backend.publicConfig().maxGroupMembers }.getOrNull()
                mutable.update {
                    it.copy(
                        members = rows,
                        muted = mine?.member?.muted ?: it.muted,
                        isAdmin = mine?.member?.role == MemberRole.Admin,
                        full = max != null && list.size >= max,
                    )
                }
            }
        }
    }

    /** `set_group_muted`, optimistic; reverts with the section's error footer on failure. */
    fun setMuted(muted: Boolean) {
        val before = mutable.value.muted
        mutable.update { it.copy(muted = muted, errorIn = null) }
        viewModelScope.launch {
            try {
                env.backend.setMuted(groupId, muted)
            } catch (t: Throwable) {
                t.dataError()
                mutable.update { it.copy(muted = before, errorIn = SettingsSection.Notifications) }
                haptic(Tokens.Haptics.globalError)
            }
        }
    }

    /** `set_group_invitation_paused` (admins), optimistic. */
    fun setPaused(paused: Boolean) {
        val group = mutable.value.group ?: return
        mutable.update { it.copy(group = group.copy(invitationPaused = paused), errorIn = null) }
        viewModelScope.launch {
            try {
                val saved = env.backend.setInvitationPaused(groupId, paused)
                mutable.update { it.copy(group = saved) }
            } catch (t: Throwable) {
                t.dataError()
                mutable.update { it.copy(group = group, errorIn = SettingsSection.Invitation) }
                haptic(Tokens.Haptics.globalError)
            }
        }
    }

    /** `set_group_invitation_hours` (admins): both times together, optimistic. */
    fun setHours(start: LocalTime, end: LocalTime) {
        val group = mutable.value.group ?: return
        mutable.update { it.copy(group = group.copy(wakingStart = start, wakingEnd = end), errorIn = null, invalidWindow = false) }
        viewModelScope.launch {
            try {
                val saved = env.backend.setInvitationHours(groupId, start, end)
                mutable.update { it.copy(group = saved) }
            } catch (t: Throwable) {
                val error = t.dataError()
                val invalid = (error as? DataError.Api)?.code == ApiError.InvalidWakingWindow
                mutable.update { it.copy(group = group, invalidWindow = invalid, errorIn = if (invalid) null else SettingsSection.Invitation) }
                haptic(Tokens.Haptics.globalError)
            }
        }
    }

    /** `remove_member` (admins), optimistic. */
    fun remove(member: MemberRow) {
        val before = mutable.value.members
        mutable.update { it.copy(members = before?.filterNot { m -> m.userId == member.userId }, errorIn = null) }
        haptic(Tokens.Haptics.globalWarning)
        viewModelScope.launch {
            try {
                env.backend.removeMember(groupId, member.userId)
            } catch (t: Throwable) {
                t.dataError()
                mutable.update { it.copy(members = before, errorIn = SettingsSection.Members) }
                haptic(Tokens.Haptics.globalError)
            }
        }
    }

    fun leave() {
        haptic(Tokens.Haptics.globalWarning)
        GroupActions.leave(env, groupId)
        navigate(AppRoute.GroupsList, clearStack = true)
    }
}

@Composable
internal fun inviteMoreLabel(kind: GroupKind): String = when (kind) {
    GroupKind.Friends -> stringResource(R.string.groups_settings_members_invite_friends)
    GroupKind.Family -> stringResource(R.string.groups_settings_members_invite_family)
    GroupKind.Roommates -> stringResource(R.string.groups_settings_members_invite_roommates)
    GroupKind.Custom -> stringResource(R.string.groups_settings_members_invite_custom)
}

/** Callbacks of [GroupSettingsScreen] (navigation and writes). */
class GroupSettingsActions(
    val onBack: () -> Unit = {},
    val onMember: (MemberRow) -> Unit = {},
    val onInvite: () -> Unit = {},
    val onMuted: (Boolean) -> Unit = {},
    val onQuietHours: () -> Unit = {},
    val onPaused: (Boolean) -> Unit = {},
    val onHours: (LocalTime, LocalTime) -> Unit = { _, _ -> },
    val onEdit: () -> Unit = {},
    val onReportGroup: () -> Unit = {},
    val onLeave: () -> Unit = {},
    val onRemove: (MemberRow) -> Unit = {},
    val onReportMember: (MemberRow) -> Unit = {},
    val onBlockMember: (MemberRow) -> Unit = {},
    val onOpenSettings: () -> Unit = {},
)

@Composable
fun GroupSettingsRoute(nav: NavController, groupId: String) {
    val env = LocalAccountEnvironment.current
    val context = LocalContext.current
    val vm = viewModel(key = "groupSettings:$groupId") { GroupSettingsViewModel(env, groupId) }
    val state by vm.state.collectAsStateWithLifecycle()
    CollectEvents(vm.events, nav)
    val notificationsOff = !androidx.core.app.NotificationManagerCompat.from(context).areNotificationsEnabled()
    GroupSettingsScreen(
        state = state,
        notificationsOff = notificationsOff,
        actions = GroupSettingsActions(
            onBack = { nav.popBackStack() },
            onMember = { if (!it.you) nav.navigate(AppRoute.WallMember(it.userId)) },
            onInvite = { nav.navigate(AppRoute.GroupInvite(groupId)) },
            onMuted = vm::setMuted,
            onQuietHours = { nav.navigate(AppRoute.SettingsNotifications) },
            onPaused = vm::setPaused,
            onHours = vm::setHours,
            onEdit = { nav.navigate(GroupEditRoute(groupId)) },
            onReportGroup = { nav.navigate(AppRoute.SafetyReport(groupId = groupId)) },
            onLeave = vm::leave,
            onRemove = vm::remove,
            onReportMember = { nav.navigate(AppRoute.SafetyReport(groupId = groupId, userId = it.userId)) },
            onBlockMember = { nav.navigate(AppRoute.SafetyBlock(it.userId)) },
            onOpenSettings = { PermissionChecks.openSafely(context, PermissionChecks.notificationSettingsIntent(context)) },
        ),
    )
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun GroupSettingsScreen(state: GroupSettingsUiState, notificationsOff: Boolean, actions: GroupSettingsActions) {
    val context = LocalContext.current
    var confirmLeave by remember { mutableStateOf(false) }
    var confirmRemove by remember { mutableStateOf<MemberRow?>(null) }
    var hoursStep by remember { mutableStateOf<LocalTime?>(null) }
    var pickingStart by remember { mutableStateOf(false) }
    SystemScaffold(
        title = stringResource(R.string.groups_settings_title),
        backLabel = stringResource(R.string.groups_screen_back_accessibilitylabel),
        onBack = actions.onBack,
    ) { padding ->
        val group = state.group
        val members = state.members
        if (state.loading || group == null || members == null) {
            SystemLoading()
            return@SystemScaffold
        }
        val editable = state.online
        SystemList(padding) {
            // 1. members
            item(key = "membersHeader") { SystemSectionHeader(stringResource(R.string.groups_settings_members_header)) }
            members.forEach { member ->
                item(key = "member:" + member.userId) {
                    MemberRowItem(member, state.isAdmin, actions, onRemove = { confirmRemove = it })
                }
            }
            if (!state.full) item(key = "invite") {
                SystemRow(inviteMoreLabel(group.kind), leading = { Icon(Tokens.Icons.globalLink, null) }, onClick = actions.onInvite)
            }
            if (state.errorIn == SettingsSection.Members) item(key = "membersError") { SystemSectionFooter(stringResource(R.string.groups_settings_error_generic), isError = true) }
            item(key = "d1") { SystemDivider() }
            // 2. notifications
            item(key = "notifHeader") { SystemSectionHeader(stringResource(R.string.groups_settings_notifications_header)) }
            item(key = "mute") { SystemSwitchRow(stringResource(R.string.groups_settings_notifications_mute), state.muted, actions.onMuted, enabled = editable) }
            item(key = "quiet") { SystemRow(stringResource(R.string.groups_settings_notifications_quiethours), onClick = actions.onQuietHours) }
            item(key = "notifFooter") { SystemSectionFooter(stringResource(R.string.groups_settings_notifications_footer)) }
            if (notificationsOff) {
                // Permission-denied: the system-wide off footer (BLOCKED copy: omitted in release) + Open Settings.
                BlockedCopy.notificationsOffFooter(context)?.let { item(key = "offFooter") { SystemSectionFooter(it) } }
                item(key = "openSettings") { SystemRow(stringResource(R.string.settings_notifications_opensettings), onClick = actions.onOpenSettings) }
            }
            if (state.errorIn == SettingsSection.Notifications) item(key = "notifError") { SystemSectionFooter(stringResource(R.string.groups_settings_error_generic), isError = true) }
            item(key = "d2") { SystemDivider() }
            // 3. daily invitation
            item(key = "invHeader") { SystemSectionHeader(stringResource(R.string.groups_settings_invitation_header)) }
            item(key = "hours") {
                val start = group.wakingStart
                val end = group.wakingEnd
                val value = if (start != null && end != null) {
                    stringResource(R.string.groups_settings_invitation_range, Formats.time(start), Formats.time(end))
                } else {
                    stringResource(R.string.groups_settings_invitation_default)
                }
                SystemRow(
                    stringResource(R.string.groups_settings_invitation_hours),
                    trailing = { Text(value) },
                    enabled = state.isAdmin && editable,
                    onClick = if (state.isAdmin) ({ pickingStart = true }) else null,
                )
            }
            item(key = "pause") {
                SystemSwitchRow(stringResource(R.string.groups_settings_invitation_pause), group.invitationPaused, actions.onPaused, enabled = state.isAdmin && editable)
            }
            item(key = "invFooter") { SystemSectionFooter(stringResource(R.string.groups_settings_invitation_footer)) }
            if (!state.isAdmin) item(key = "adminOnly") { SystemSectionFooter(stringResource(R.string.groups_settings_invitation_adminonly)) }
            if (state.invalidWindow) item(key = "invalid") { SystemSectionFooter(stringResource(R.string.groups_settings_invitation_invalid), isError = true) }
            if (state.errorIn == SettingsSection.Invitation) item(key = "invError") { SystemSectionFooter(stringResource(R.string.groups_settings_error_generic), isError = true) }
            item(key = "d3") { SystemDivider() }
            // 4. group (admins)
            if (state.isAdmin) {
                item(key = "groupHeader") { SystemSectionHeader(stringResource(R.string.groups_settings_group_header)) }
                item(key = "edit") { SystemRow(stringResource(R.string.groups_settings_group_edit), onClick = actions.onEdit) }
                item(key = "d4") { SystemDivider() }
            }
            // 5. actions
            item(key = "share") { SystemRow(stringResource(R.string.groups_settings_shareinvite), leading = { Icon(Tokens.Icons.globalShare, null) }, onClick = actions.onInvite) }
            item(key = "report") { SystemRow(stringResource(R.string.groups_settings_report), destructive = true, leading = { Icon(Tokens.Icons.globalReport, null) }, onClick = actions.onReportGroup) }
            item(key = "leave") { SystemRow(stringResource(R.string.groups_settings_leave), destructive = true, leading = { Icon(Tokens.Icons.globalLeave, null) }, onClick = { confirmLeave = true }) }
        }
        if (confirmLeave) {
            LeaveGroupDialog(group.name, last = members.size <= 1, onConfirm = { confirmLeave = false; actions.onLeave() }, onDismiss = { confirmLeave = false })
        }
        confirmRemove?.let { member ->
            SystemAlertDialog(
                title = stringResource(R.string.groups_settings_remove_title, member.firstName),
                text = stringResource(R.string.groups_settings_remove_message),
                confirmLabel = stringResource(R.string.groups_settings_remove_confirm),
                onConfirm = { confirmRemove = null; actions.onRemove(member) },
                dismissLabel = stringResource(R.string.groups_settings_alert_cancel),
                onDismiss = { confirmRemove = null },
                destructive = true,
            )
        }
        if (pickingStart) {
            TimeDialog(stringResource(R.string.settings_notifications_quiethours_start), group.wakingStart, onCancel = { pickingStart = false }) { start ->
                pickingStart = false
                hoursStep = start
            }
        }
        hoursStep?.let { start ->
            TimeDialog(stringResource(R.string.settings_notifications_quiethours_end), group.wakingEnd, onCancel = { hoursStep = null }) { end ->
                hoursStep = null
                actions.onHours(start, end)
            }
        }
    }
}

/** Member row: avatar `settings.root.size.listItemAvatar.android`; name; "admin" / "you"; ••• menu on others' rows. */
@Composable
private fun MemberRowItem(member: MemberRow, viewerIsAdmin: Boolean, actions: GroupSettingsActions, onRemove: (MemberRow) -> Unit) {
    var menu by remember { mutableStateOf(false) }
    val supporting = when {
        member.you -> stringResource(R.string.groups_settings_members_you)
        member.admin -> stringResource(R.string.groups_settings_members_admin)
        else -> null
    }
    SystemRow(
        headline = member.name,
        supporting = supporting,
        leading = { Avatar(member.avatarUrl, Tokens.Sizes.settingsRootSizeListItemAvatarAndroid) },
        trailing = if (member.you) null else {
            {
                Box {
                    IconButton(onClick = { menu = true }) {
                        Icon(Tokens.Icons.globalMore, contentDescription = stringResource(R.string.groups_settings_members_more_accessibilitylabel, member.firstName))
                    }
                    DropdownMenu(expanded = menu, onDismissRequest = { menu = false }, containerColor = Tokens.Colors.globalSystemSurfaceContainerHigh) {
                        if (viewerIsAdmin) MenuItem(stringResource(R.string.groups_settings_members_menu_remove), destructive = true) { menu = false; onRemove(member) }
                        MenuItem(stringResource(R.string.groups_settings_members_menu_report), destructive = true) { menu = false; actions.onReportMember(member) }
                        MenuItem(stringResource(R.string.groups_settings_members_menu_block), destructive = true) { menu = false; actions.onBlockMember(member) }
                    }
                }
            }
        },
        onClick = { actions.onMember(member) },
    )
}

/**
 * The M3 TimePicker in a dialog (groups.settings invitation hours; settings.notifications quiet
 * hours). Title = the row's own label; buttons are the platform's own `android.R.string.cancel` /
 * `android.R.string.ok` (the system time picker dialog's labels; no app copy exists for them).
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
internal fun TimeDialog(title: String, initial: LocalTime?, onCancel: () -> Unit, onConfirm: (LocalTime) -> Unit) {
    val picker = rememberTimePickerState(initialHour = initial?.hour ?: 0, initialMinute = initial?.minute ?: 0)
    AlertDialog(
        onDismissRequest = onCancel,
        containerColor = Tokens.Colors.globalSystemSurfaceContainerHigh,
        title = { Text(title) },
        text = { TimePicker(picker) },
        confirmButton = { TextButton(onClick = { onConfirm(LocalTime.of(picker.hour, picker.minute)) }) { Text(stringResource(android.R.string.ok)) } },
        dismissButton = { TextButton(onClick = onCancel) { Text(stringResource(android.R.string.cancel)) } },
    )
}

/** Navigates home after leaving (used by tests of the leave flow). */
internal fun NavController.homeAfterLeave() = navigateAccount(AccountEvent.Navigate(AppRoute.GroupsList, clearStack = true))
