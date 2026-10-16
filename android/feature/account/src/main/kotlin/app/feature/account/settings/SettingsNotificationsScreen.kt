// Surface: settings.notifications — per-group notifications, quiet hours. Spec: design/surfaces/settings.notifications.md.
// References: references/auto/retro/video/ig-DJXvmqRv2_N-referrals-sheet-f042-059.png (VID-SET: grouped rows, section headers),
// references/auto/retro/apk/retro-android-2026.10.1150-strings.txt (APK-S: notification_settings_*, the off-permission upsell),
// references/auto/retro/lazyweb/retro-lazyweb-20251020-week43-dark.png (H43: C-27 block, outline capsule).
package app.feature.account.settings

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.runtime.Composable
import androidx.compose.runtime.Immutable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.core.app.NotificationManagerCompat
import androidx.lifecycle.compose.LifecycleResumeEffect
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewModelScope
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.navigation.NavController
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
import app.feature.account.groups.TimeDialog
import app.ui.components.Avatar
import app.ui.components.EmptyState
import app.ui.components.EmptyStateAction
import app.ui.components.GroupedRowSpec
import app.ui.components.GroupedTrailing
import app.ui.components.HeaderAction
import app.ui.foundation.DsMotion
import app.ui.format.Formats
import app.ui.permissions.PermissionChecks
import app.ui.system.ErrorAlert
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import java.time.LocalTime

@Immutable
data class GroupToggle(val groupId: String, val name: String, val muted: Boolean, val coverUrl: String? = null)

@Immutable
data class SettingsNotificationsUiState(
    val groups: List<GroupToggle>? = null,
    val quietStart: LocalTime? = null,
    val quietEnd: LocalTime? = null,
    /** The quiet-hours switch (on while both times are set, or while the person is choosing them). */
    val quietOn: Boolean = false,
    val loaded: Boolean = false,
    val online: Boolean = true,
    /** A change failed (the control returned): the message-only alert `settings.notifications.error`. */
    val error: Boolean = false,
)

class SettingsNotificationsViewModel(private val env: AccountEnvironment) : AccountViewModel() {
    private val mutable = MutableStateFlow(SettingsNotificationsUiState())
    val state: StateFlow<SettingsNotificationsUiState> = mutable.asStateFlow()

    init {
        viewModelScope.launch { env.backend.online.collect { online -> mutable.update { it.copy(online = online) } } }
        viewModelScope.launch {
            env.backend.observeMyGroups().collect { page ->
                val groups = page.value ?: return@collect
                val muted = runCatching { env.backend.myMemberships() }.getOrNull()?.associate { it.groupId to it.muted }
                val covers = runCatching { env.backend.signedUrls(groups.mapNotNull { it.coverPath }) }.getOrDefault(emptyMap())
                mutable.update { s ->
                    val previous = s.groups?.associate { it.groupId to it.muted }.orEmpty()
                    s.copy(groups = groups.map { g -> GroupToggle(g.id, g.name, muted?.get(g.id) ?: previous[g.id] ?: false, g.coverPath?.let(covers::get)) })
                }
            }
        }
        viewModelScope.launch {
            val settings = runCatching { env.backend.notificationSettings() }.getOrNull()
            mutable.update { it.copy(quietStart = settings?.quietStart, quietEnd = settings?.quietEnd, quietOn = settings?.quietStart != null && settings.quietEnd != null, loaded = true) }
        }
    }

    fun dismissError() = mutable.update { it.copy(error = false) }

    /** Row on = not muted; `set_group_muted(p_group_id, !isOn)`, optimistic; reverts with the error alert. */
    fun setGroupOn(groupId: String, on: Boolean) {
        if (!mutable.value.online) return failed()
        val before = mutable.value.groups
        mutable.update { s -> s.copy(groups = s.groups?.map { if (it.groupId == groupId) it.copy(muted = !on) else it }, error = false) }
        viewModelScope.launch {
            try {
                env.backend.setMuted(groupId, !on)
            } catch (t: Throwable) {
                t.dataError()
                mutable.update { it.copy(groups = before) }
                failed()
            }
        }
    }

    /** Off → both null (`set_quiet_hours(null, null, …)`); on shows the time rows until both are chosen. */
    fun setQuietOn(on: Boolean) {
        if (!mutable.value.online) return failed()
        if (on) {
            mutable.update { it.copy(quietOn = true) }
            return
        }
        val before = mutable.value
        mutable.update { it.copy(quietOn = false, quietStart = null, quietEnd = null, error = false) }
        save(null, null, before)
    }

    fun setStart(time: LocalTime) = updateTimes(start = time, end = mutable.value.quietEnd)
    fun setEnd(time: LocalTime) = updateTimes(start = mutable.value.quietStart, end = time)

    private fun updateTimes(start: LocalTime?, end: LocalTime?) {
        if (!mutable.value.online) return failed()
        val before = mutable.value
        mutable.update { it.copy(quietStart = start, quietEnd = end, error = false) }
        if (start != null && end != null) save(start, end, before)
    }

    private fun save(start: LocalTime?, end: LocalTime?, before: SettingsNotificationsUiState) {
        viewModelScope.launch {
            try {
                env.backend.setQuietHours(start, end, if (start != null) env.zone().id else null)
            } catch (t: Throwable) {
                t.dataError()
                mutable.update { it.copy(quietStart = before.quietStart, quietEnd = before.quietEnd, quietOn = before.quietOn) }
                failed()
            }
        }
    }

    private fun failed() {
        mutable.update { it.copy(error = true) }
        haptic(Tokens.Haptics.globalError)
    }
}

@Composable
fun SettingsNotificationsRoute(nav: NavController) {
    val env = LocalAccountEnvironment.current
    val context = LocalContext.current
    val vm = viewModel { SettingsNotificationsViewModel(env) }
    val state by vm.state.collectAsStateWithLifecycle()
    CollectEvents(vm.events, nav)
    var systemOff by remember { mutableStateOf(!NotificationManagerCompat.from(context).areNotificationsEnabled()) }
    // Back from system Settings: the off block follows the permission.
    LifecycleResumeEffect(Unit) {
        systemOff = !NotificationManagerCompat.from(context).areNotificationsEnabled()
        onPauseOrDispose { }
    }
    val openSettings = { PermissionChecks.openSafely(context, PermissionChecks.notificationSettingsIntent(context)) }
    SettingsNotificationsScreen(
        state = state,
        systemOff = systemOff,
        onBack = { nav.popBackStack() },
        onOpenSettings = openSettings,
        onGroup = vm::setGroupOn,
        onQuiet = vm::setQuietOn,
        onStart = vm::setStart,
        onEnd = vm::setEnd,
        onCategories = openSettings,
        onDismissError = vm::dismissError,
    )
}

/**
 * Pushed inside the Settings sheet (back + centred "Notifications"; `settings.root.layout.list`): 1. while the system
 * permission is off, the C-27 block at the top, left-aligned, no glyph (title, explanation, outline "Enable push" → the
 * app's notification settings; the rows below stay editable); 2. Groups — one row per group (cover in a
 * `size.global.avatarComment` circle, C-23 fallback `icon.global.group`; name; native switch, on = notifications on) and
 * the footer (hidden with no groups); 3. Quiet Hours — switch; when on, Start / End with their times → the M3 time
 * picker; footer (the rows expand with `AnimatedVisibility`); 5. Android: "Notification Categories" → the channel settings.
 */
@Composable
fun SettingsNotificationsScreen(
    state: SettingsNotificationsUiState,
    systemOff: Boolean,
    onBack: () -> Unit,
    onOpenSettings: () -> Unit,
    onGroup: (String, Boolean) -> Unit,
    onQuiet: (Boolean) -> Unit,
    onStart: (LocalTime) -> Unit,
    onEnd: (LocalTime) -> Unit,
    onCategories: () -> Unit,
    onDismissError: () -> Unit = {},
) {
    var picking by remember { mutableStateOf<Boolean?>(null) } // true = start, false = end
    SheetPage(
        title = stringResource(R.string.settings_notifications_title),
        back = HeaderAction(Tokens.Icons.globalBack, stringResource(R.string.groups_screen_back_accessibilitylabel), onBack),
    ) {
        Column(Modifier.fillMaxWidth().verticalScroll(rememberScrollState()).padding(bottom = sheetBottomPadding())) {
            AnimatedVisibility(visible = systemOff, enter = DsMotion.fadeIn, exit = DsMotion.fadeOut) {
                Box(Modifier.fillMaxWidth().padding(top = Tokens.Sizes.globalSectionHeaderToContent), contentAlignment = Alignment.CenterStart) {
                    EmptyState(
                        title = stringResource(R.string.settings_notifications_off_title),
                        detail = stringResource(R.string.settings_notifications_off_footer),
                        action = EmptyStateAction(stringResource(R.string.settings_notifications_opensettings), onOpenSettings),
                        alignment = Alignment.Start,
                    )
                }
            }
            val groups = state.groups
            if (groups == null || !state.loaded) {
                SettingsHeader(stringResource(R.string.settings_notifications_groups_header), first = !systemOff)
                LoadingGroup()
                return@Column
            }
            if (groups.isNotEmpty()) {
                SettingsHeader(stringResource(R.string.settings_notifications_groups_header), first = !systemOff)
                SettingsGroup(
                    groups.map { g ->
                        GroupedRowSpec(
                            title = g.name,
                            trailing = GroupedTrailing.Toggle(!g.muted) { on -> onGroup(g.groupId, on) },
                            leading = { Avatar(g.coverUrl, Tokens.Sizes.globalAvatarComment, fallbackIcon = Tokens.Icons.globalGroup) },
                        )
                    },
                )
                SettingsFooter(stringResource(R.string.settings_notifications_groups_footer))
                SettingsGap()
            } else {
                // No groups: the Groups section is hidden; Quiet Hours (no header of its own) starts the page.
                Box(Modifier.padding(top = if (systemOff) Tokens.Sizes.globalSectionGap else Tokens.Sizes.globalSectionHeaderToContent))
            }
            val rows = buildList {
                add(GroupedRowSpec(stringResource(R.string.settings_notifications_quiethours), trailing = GroupedTrailing.Toggle(state.quietOn, onQuiet)))
                if (state.quietOn) {
                    add(GroupedRowSpec(stringResource(R.string.settings_notifications_quiethours_start), trailing = GroupedTrailing.ValueChevron(state.quietStart?.let { Formats.time(it) }.orEmpty()), onClick = { picking = true }))
                    add(GroupedRowSpec(stringResource(R.string.settings_notifications_quiethours_end), trailing = GroupedTrailing.ValueChevron(state.quietEnd?.let { Formats.time(it) }.orEmpty()), onClick = { picking = false }))
                }
            }
            SettingsGroup(rows)
            SettingsFooter(stringResource(R.string.settings_notifications_quiethours_footer))
            SettingsGap()
            SettingsGroup(listOf(navRow(stringResource(R.string.settings_notifications_categories), onClick = onCategories)))
        }
    }
    when (picking) {
        true -> TimeDialog(stringResource(R.string.settings_notifications_quiethours_start), state.quietStart, onCancel = { picking = null }) { picking = null; onStart(it) }
        false -> TimeDialog(stringResource(R.string.settings_notifications_quiethours_end), state.quietEnd, onCancel = { picking = null }) { picking = null; onEnd(it) }
        null -> Unit
    }
    if (state.error) ErrorAlert(stringResource(R.string.settings_notifications_error), errorDismissLabel(), onDismissError)
}
