// Surface: groups.settings — members, notifications, invitation hours, admin, report, leave. Spec: design/surfaces/groups.settings.md.
// References: references/auto/retro/video/ig-DJXvmqRv2_N-referrals-sheet-f042-059.png (VID-SET frames 42–44: centred "Settings"
// + close circle, small grey section headers, Fill grouped rows), references/auto/retro/press/tc-2024-04-retro-journals-5.png
// (TC-J5: row height 58.7, red destructive row), references/auto/retro/press/tc-2023-07-retro-1b.webp (TC-1B: people rows),
// references/auto/retro/apk/retro-android-2026.10.1150-strings.txt (APK-S: journal_settings_*, journal_edit_members_*).
package app.feature.account.groups

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.ExperimentalMaterial3Api
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
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
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
import app.feature.account.common.AccountViewModel
import app.feature.account.common.CollectEvents
import app.feature.account.common.SheetPage
import app.feature.account.common.dataError
import app.feature.account.common.errorDismissLabel
import app.feature.account.common.sheetBottomPadding
import app.feature.account.plans.PlansBackend
import app.feature.account.plans.rememberPlansBackend
import app.feature.account.settings.LoadingGroup
import app.feature.account.settings.SettingsFooter
import app.feature.account.settings.SettingsGap
import app.feature.account.settings.SettingsGroup
import app.feature.account.settings.SettingsHeader
import app.feature.account.settings.navRow
import app.model.AppRoute
import app.model.GroupEditRoute
import app.ui.components.Avatar
import app.ui.components.GroupedPosition
import app.ui.components.GroupedRowSpec
import app.ui.components.GroupedTrailing
import app.ui.components.Hairline
import app.ui.components.HeaderAction
import app.ui.components.HeaderIconButton
import app.ui.components.OutlineCta
import app.ui.foundation.PageRoles
import app.ui.foundation.tapClickable
import app.ui.format.Formats
import app.ui.system.DsDropdownMenu
import app.ui.system.DsMenuItem
import app.ui.system.ErrorAlert
import app.ui.system.SystemAlertDialog
import app.ui.text.TextRoles
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import java.time.LocalTime

@Immutable
data class MemberRow(val userId: String, val name: String, val firstName: String, val avatarUrl: String?, val admin: Boolean, val you: Boolean)

@Immutable
data class GroupSettingsUiState(
    val group: Group? = null,
    val members: List<MemberRow>? = null,
    val muted: Boolean = false,
    val isAdmin: Boolean = false,
    val full: Boolean = false,
    val online: Boolean = true,
    /** A change failed (or was tried offline): the message-only alert `groups.settings.error.generic`. */
    val failed: Boolean = false,
    /** The invitation window is too short: the message-only alert `groups.settings.invitation.invalid`. */
    val invalidWindow: Boolean = false,
) {
    val loading: Boolean get() = group == null || members == null
}

class GroupSettingsViewModel(
    private val env: AccountEnvironment,
    private val groupId: String,
    /** The weekly question's switch (`question.weekly` E, `set_group_weekly_question`); null: the switch does nothing. */
    private val plans: PlansBackend? = null,
) : AccountViewModel() {
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
        mutable.update { it.copy(muted = muted) }
        viewModelScope.launch {
            try {
                env.backend.setMuted(groupId, muted)
            } catch (t: Throwable) {
                t.dataError()
                mutable.update { it.copy(muted = before, failed = true) }
                haptic(Tokens.Haptics.globalError)
            }
        }
    }

    /** `set_group_invitation_paused` (admins), optimistic. */
    fun setPaused(paused: Boolean) {
        val group = mutable.value.group ?: return
        mutable.update { it.copy(group = group.copy(invitationPaused = paused)) }
        viewModelScope.launch {
            try {
                val saved = env.backend.setInvitationPaused(groupId, paused)
                mutable.update { it.copy(group = saved) }
            } catch (t: Throwable) {
                t.dataError()
                mutable.update { it.copy(group = group, failed = true) }
                haptic(Tokens.Haptics.globalError)
            }
        }
    }

    /** `set_group_invitation_hours` (admins): both times together, optimistic. */
    fun setHours(start: LocalTime, end: LocalTime) {
        val group = mutable.value.group ?: return
        mutable.update { it.copy(group = group.copy(wakingStart = start, wakingEnd = end), failed = false, invalidWindow = false) }
        viewModelScope.launch {
            try {
                val saved = env.backend.setInvitationHours(groupId, start, end)
                mutable.update { it.copy(group = saved) }
            } catch (t: Throwable) {
                val error = t.dataError()
                val invalid = (error as? DataError.Api)?.code == ApiError.InvalidWakingWindow
                mutable.update { it.copy(group = group, invalidWindow = invalid, failed = !invalid) }
                haptic(Tokens.Haptics.globalError)
            }
        }
    }

    /** `set_group_weekly_question` (admins, `question.weekly` E), optimistic; reverts with the error alert. */
    fun setWeeklyQuestion(on: Boolean) {
        val group = mutable.value.group ?: return
        val backend = plans ?: return
        mutable.update { it.copy(group = group.copy(weeklyQuestion = on)) }
        viewModelScope.launch {
            try {
                val saved = backend.setWeeklyQuestion(groupId, on)
                mutable.update { it.copy(group = saved) }
            } catch (t: Throwable) {
                t.dataError()
                mutable.update { it.copy(group = group, failed = true) }
                haptic(Tokens.Haptics.globalError)
            }
        }
    }

    /** `remove_member` (admins), optimistic. */
    fun remove(member: MemberRow) {
        val before = mutable.value.members
        mutable.update { it.copy(members = before?.filterNot { m -> m.userId == member.userId }) }
        haptic(Tokens.Haptics.globalWarning)
        viewModelScope.launch {
            try {
                env.backend.removeMember(groupId, member.userId)
            } catch (t: Throwable) {
                t.dataError()
                mutable.update { it.copy(members = before, failed = true) }
                haptic(Tokens.Haptics.globalError)
            }
        }
    }

    fun dismissAlert() = mutable.update { it.copy(failed = false, invalidWindow = false) }

    /** Offline: the control does not change; the error alert explains (spec: controls disabled, the alert on tap). */
    fun offlineTap() {
        mutable.update { it.copy(failed = true) }
        haptic(Tokens.Haptics.globalError)
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
    val onClose: () -> Unit = {},
    val onMember: (MemberRow) -> Unit = {},
    val onInvite: () -> Unit = {},
    val onUpdates: (Boolean) -> Unit = {},
    val onQuietHours: () -> Unit = {},
    val onPaused: (Boolean) -> Unit = {},
    val onHours: (LocalTime, LocalTime) -> Unit = { _, _ -> },
    val onEdit: () -> Unit = {},
    val onReportGroup: () -> Unit = {},
    val onLeave: () -> Unit = {},
    val onRemove: (MemberRow) -> Unit = {},
    val onReportMember: (MemberRow) -> Unit = {},
    val onBlockMember: (MemberRow) -> Unit = {},
    val onOffline: () -> Unit = {},
    val onDismissAlert: () -> Unit = {},
    val onWeeklyQuestion: (Boolean) -> Unit = {},
)

@Composable
fun GroupSettingsRoute(nav: NavController, groupId: String) {
    val env = LocalAccountEnvironment.current
    val plans = rememberPlansBackend()
    val vm = viewModel(key = "groupSettings:$groupId") { GroupSettingsViewModel(env, groupId, plans) }
    val state by vm.state.collectAsStateWithLifecycle()
    CollectEvents(vm.events, nav)
    GroupSettingsScreen(
        state = state,
        actions = GroupSettingsActions(
            onClose = { nav.popBackStack() },
            onMember = { if (!it.you) nav.navigate(AppRoute.WallMember(it.userId)) },
            onInvite = { nav.navigate(AppRoute.GroupInvite(groupId)) },
            onUpdates = { on -> vm.setMuted(!on) },
            onQuietHours = { nav.navigate(AppRoute.SettingsNotifications) },
            onPaused = vm::setPaused,
            onHours = vm::setHours,
            onEdit = { nav.navigate(GroupEditRoute(groupId)) },
            onReportGroup = { nav.navigate(AppRoute.SafetyReport(groupId = groupId)) },
            onLeave = vm::leave,
            onRemove = vm::remove,
            onReportMember = { nav.navigate(AppRoute.SafetyReport(groupId = groupId, userId = it.userId)) },
            onBlockMember = { nav.navigate(AppRoute.SafetyBlock(it.userId)) },
            onOffline = vm::offlineTap,
            onDismissAlert = vm::dismissAlert,
            onWeeklyQuestion = vm::setWeeklyQuestion,
        ),
    )
}

/**
 * The group's settings sheet (C-29 page sheet: centred "Settings" + close; `settings.root.layout.list`; scrolls):
 * 1. Members — people rows (C-16 in C-14: avatar `size.global.avatarPicker`, first name `listTitle`, "You" / "Admin" in
 *    `listSubtitle`, "•••" on others' rows → native menu: Remove from Group (admins), Report Profile, Block Profile), then the
 *    C-07 outline CTA "Invite …" (by kind) as the group's last row;
 * 2. Notifications — "Group updates" (native switch, on = not muted), "Quiet Hours" → settings.notifications, footer;
 * 3. Daily Invitation — "Invitation Hours" with its value → the M3 time pickers (start, then end), "Pause Invitations"
 *    (switch), footer; non-admins: rows disabled and the admin-only line;
 * 4. Admin Settings (admins) — "Edit Group" → groups.create (edit); "Weekly Question" (switch, with its detail line);
 * 5. a last group without header — "Report Group" and "Leave Group" (C-10 red).
 * Loading: each section one row with the platform indicator. Offline: controls disabled; a tap shows the error alert.
 */
@Composable
fun GroupSettingsScreen(state: GroupSettingsUiState, actions: GroupSettingsActions) {
    var confirmLeave by remember { mutableStateOf(false) }
    var confirmRemove by remember { mutableStateOf<MemberRow?>(null) }
    var hoursStart by remember { mutableStateOf<LocalTime?>(null) }
    var pickingStart by remember { mutableStateOf(false) }
    val group = state.group
    val members = state.members
    SheetPage(
        title = stringResource(R.string.groups_settings_title),
        close = HeaderAction(Tokens.Icons.globalClose, stringResource(R.string.groups_settings_close_accessibilitylabel), actions.onClose),
    ) {
        Column(Modifier.fillMaxWidth().verticalScroll(rememberScrollState()).padding(bottom = sheetBottomPadding())) {
            SettingsHeader(stringResource(R.string.groups_settings_members_header), first = true)
            if (state.loading || group == null || members == null) {
                LoadingGroup()
                SettingsHeader(stringResource(R.string.groups_settings_notifications_header))
                LoadingGroup()
                SettingsHeader(stringResource(R.string.groups_settings_invitation_header))
                LoadingGroup()
                return@Column
            }
            val online = state.online
            // 1. Members
            Column(Modifier.padding(horizontal = Tokens.Sizes.globalScreenMargin)) {
                val count = members.size + if (state.full) 0 else 1
                members.forEachIndexed { index, member ->
                    MemberRowItem(member, GroupedPosition.of(index, count), state.isAdmin, actions, onRemove = { confirmRemove = it })
                }
                if (!state.full) InviteRow(inviteMoreLabel(group.kind), GroupedPosition.of(count - 1, count), actions.onInvite)
            }
            // 2. Notifications
            SettingsHeader(stringResource(R.string.groups_settings_notifications_header))
            SettingsGroup(
                listOf(
                    GroupedRowSpec(
                        title = stringResource(R.string.groups_settings_notifications_updates),
                        trailing = GroupedTrailing.Toggle(!state.muted) { on -> if (online) actions.onUpdates(on) else actions.onOffline() },
                    ),
                    navRow(stringResource(R.string.groups_settings_notifications_quiethours), onClick = actions.onQuietHours),
                ),
            )
            SettingsFooter(stringResource(R.string.groups_settings_notifications_footer))
            // 3. Daily Invitation
            SettingsHeader(stringResource(R.string.groups_settings_invitation_header))
            val start = group.wakingStart
            val end = group.wakingEnd
            val range = if (start != null && end != null) {
                stringResource(R.string.groups_settings_invitation_range, Formats.time(start), Formats.time(end))
            } else {
                stringResource(R.string.groups_settings_invitation_default)
            }
            SettingsGroup(
                listOf(
                    GroupedRowSpec(
                        title = stringResource(R.string.groups_settings_invitation_hours),
                        trailing = GroupedTrailing.Value(range),
                        enabled = state.isAdmin,
                        onClick = if (state.isAdmin) ({ if (online) pickingStart = true else actions.onOffline() }) else null,
                    ),
                    GroupedRowSpec(
                        title = stringResource(R.string.groups_settings_invitation_pause),
                        trailing = GroupedTrailing.Toggle(group.invitationPaused) { paused -> if (online) actions.onPaused(paused) else actions.onOffline() },
                        enabled = state.isAdmin,
                    ),
                ),
            )
            SettingsFooter(stringResource(R.string.groups_settings_invitation_footer))
            if (!state.isAdmin) SettingsFooter(stringResource(R.string.groups_settings_invitation_adminonly))
            // 4. Admin Settings (+ the weekly question's switch, question.weekly E: the same permission as the other settings)
            if (state.isAdmin) {
                SettingsHeader(stringResource(R.string.groups_settings_group_header))
                SettingsGroup(
                    listOf(
                        navRow(stringResource(R.string.groups_settings_group_edit), onClick = actions.onEdit),
                        GroupedRowSpec(
                            title = stringResource(R.string.question_weekly_settings_row),
                            subtitle = stringResource(R.string.question_weekly_settings_rowdetail),
                            trailing = GroupedTrailing.Toggle(group.weeklyQuestion) { on -> if (online) actions.onWeeklyQuestion(on) else actions.onOffline() },
                        ),
                    ),
                )
            }
            // 5. Report · Leave
            SettingsGap()
            SettingsGroup(
                listOf(
                    GroupedRowSpec(stringResource(R.string.groups_settings_report), trailing = GroupedTrailing.None, destructive = true, onClick = actions.onReportGroup),
                    GroupedRowSpec(stringResource(R.string.groups_settings_leave), trailing = GroupedTrailing.None, destructive = true, onClick = { confirmLeave = true }),
                ),
            )
        }
    }
    if (group != null && confirmLeave) {
        LeaveGroupDialog(group.name, last = (members?.size ?: 0) <= 1, onConfirm = { confirmLeave = false; actions.onLeave() }, onDismiss = { confirmLeave = false })
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
    if (group != null && pickingStart) {
        TimeDialog(stringResource(R.string.groups_settings_invitation_start), group.wakingStart, onCancel = { pickingStart = false }) { start ->
            pickingStart = false
            hoursStart = start
        }
    }
    if (group != null) {
        hoursStart?.let { start ->
            TimeDialog(stringResource(R.string.groups_settings_invitation_end), group.wakingEnd, onCancel = { hoursStart = null }) { end ->
                hoursStart = null
                actions.onHours(start, end)
            }
        }
    }
    when {
        state.invalidWindow -> ErrorAlert(stringResource(R.string.groups_settings_invitation_invalid), errorDismissLabel(), actions.onDismissAlert)
        state.failed -> ErrorAlert(stringResource(R.string.groups_settings_error_generic), errorDismissLabel(), actions.onDismissAlert)
    }
}

/** The leave alert (`settings.account.layout.alert`): "Leave {group_name}?", the last-member message when it applies, "Yes, leave" (destructive). */
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
 * A member (C-16 in a C-14 row): avatar `size.global.avatarPicker`, `size.global.rowThumbGap` to the first name
 * (`listTitle`) over "You" / "Admin" (`listSubtitle`, secondary); on others' rows the "•••" glyph (secondary text) opening
 * the native menu (C-29). The row is one button → that person's wall; "More Options" is a separate button.
 */
@Composable
private fun MemberRowItem(member: MemberRow, position: GroupedPosition, viewerIsAdmin: Boolean, actions: GroupSettingsActions, onRemove: (MemberRow) -> Unit) {
    val shape = position.shape()
    val secondary = PageRoles.secondaryText()
    val role = when {
        member.you -> stringResource(R.string.groups_settings_members_you)
        member.admin -> stringResource(R.string.groups_settings_members_admin)
        else -> null
    }
    Column(Modifier.fillMaxWidth().clip(shape).background(PageRoles.secondarySurface, shape)) {
        Row(
            Modifier
                .fillMaxWidth()
                .heightIn(min = Tokens.Sizes.settingsRootSizeRowHeight)
                .tapClickable(enabled = !member.you) { actions.onMember(member) }
                .padding(start = Tokens.Sizes.globalScreenMargin),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Avatar(member.avatarUrl, Tokens.Sizes.globalAvatarPicker)
            Spacer(Modifier.width(Tokens.Sizes.globalRowThumbGap))
            Column(Modifier.weight(1f).padding(vertical = Tokens.Sizes.globalSectionHeaderToContent)) {
                Text(member.firstName.ifEmpty { member.name }, style = TextRoles.listTitle, color = Tokens.Colors.globalTextPrimary)
                if (role != null) Text(role, style = TextRoles.listSubtitle, color = secondary)
            }
            if (member.you) {
                Spacer(Modifier.width(Tokens.Sizes.globalScreenMargin))
            } else {
                var open by remember { mutableStateOf(false) }
                Box {
                    HeaderIconButton(Tokens.Icons.globalMore, stringResource(R.string.groups_settings_members_more_accessibilitylabel), { open = true }, tint = secondary)
                    DsDropdownMenu(
                        expanded = open,
                        onDismissRequest = { open = false },
                        items = listOfNotNull(
                            if (viewerIsAdmin) DsMenuItem(stringResource(R.string.groups_settings_members_menu_remove), { onRemove(member) }, destructive = true) else null,
                            DsMenuItem(stringResource(R.string.groups_settings_members_menu_report), { actions.onReportMember(member) }, icon = Tokens.Icons.globalReport, destructive = true),
                            DsMenuItem(stringResource(R.string.groups_settings_members_menu_block), { actions.onBlockMember(member) }, destructive = true),
                        ),
                    )
                }
            }
        }
        if (position.dividerBelow) Hairline()
    }
}

/** The members group's last row: the C-07 outline CTA (`icon.global.add` + "Invite …") with the rows' padding. */
@Composable
private fun InviteRow(label: String, position: GroupedPosition, onInvite: () -> Unit) {
    val shape = position.shape()
    Box(
        Modifier
            .fillMaxWidth()
            .heightIn(min = Tokens.Sizes.settingsRootSizeRowHeight)
            .clip(shape)
            .background(PageRoles.secondarySurface, shape)
            .padding(Tokens.Sizes.globalScreenMargin),
        contentAlignment = Alignment.CenterStart,
    ) {
        OutlineCta(label, onInvite)
    }
}

/**
 * The M3 TimePicker in a dialog (groups.settings invitation hours; settings.notifications quiet hours; PLATFORM). Title = the
 * row's own label; buttons are the platform's `android.R.string.cancel` / `android.R.string.ok` (the system time picker
 * dialog's labels; no app copy exists for them). Colours from the theme's `color.global.system.*` scheme.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
internal fun TimeDialog(title: String, initial: LocalTime?, onCancel: () -> Unit, onConfirm: (LocalTime) -> Unit) {
    val picker = rememberTimePickerState(initialHour = initial?.hour ?: 0, initialMinute = initial?.minute ?: 0)
    AlertDialog(
        onDismissRequest = onCancel,
        title = { Text(title) },
        text = { TimePicker(picker) },
        confirmButton = { TextButton(onClick = { onConfirm(LocalTime.of(picker.hour, picker.minute)) }) { Text(stringResource(android.R.string.ok)) } },
        dismissButton = { TextButton(onClick = onCancel) { Text(stringResource(android.R.string.cancel)) } },
    )
}
