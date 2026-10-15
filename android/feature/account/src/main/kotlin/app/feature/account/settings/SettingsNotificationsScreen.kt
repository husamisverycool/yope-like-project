// Surface: settings.notifications — per-group mute, quiet hours. Spec: design/surfaces/settings.notifications.md.
// References: HIG / M3 list guidance (as settings.root), https://developer.apple.com/design/human-interface-guidelines/live-activities (HIG-LA),
// docs/WIDGET_REFRESH.md (WR).
package app.feature.account.settings

import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.Immutable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.core.app.NotificationManagerCompat
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewModelScope
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.navigation.NavController
import app.designsystem.R
import app.designsystem.generated.Tokens
import app.feature.account.AccountEnvironment
import app.feature.account.LocalAccountEnvironment
import app.feature.account.blocked.BlockedCopy
import app.feature.account.common.AccountViewModel
import app.feature.account.common.CollectEvents
import app.feature.account.common.dataError
import app.feature.account.groups.TimeDialog
import app.ui.format.Formats
import app.ui.permissions.PermissionChecks
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
data class GroupToggle(val groupId: String, val name: String, val muted: Boolean)

@Immutable
data class SettingsNotificationsUiState(
    val groups: List<GroupToggle>? = null,
    val quietStart: LocalTime? = null,
    val quietEnd: LocalTime? = null,
    /** The quiet-hours switch (on while both times are set, or while the person is choosing them). */
    val quietOn: Boolean = false,
    val loaded: Boolean = false,
    val online: Boolean = true,
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
                mutable.update { s ->
                    val previous = s.groups?.associate { it.groupId to it.muted }.orEmpty()
                    s.copy(groups = groups.map { g -> GroupToggle(g.id, g.name, muted?.get(g.id) ?: previous[g.id] ?: false) })
                }
            }
        }
        viewModelScope.launch {
            val settings = runCatching { env.backend.notificationSettings() }.getOrNull()
            mutable.update { it.copy(quietStart = settings?.quietStart, quietEnd = settings?.quietEnd, quietOn = settings?.quietStart != null && settings.quietEnd != null, loaded = true) }
        }
    }

    /** Row on = not muted; `set_group_muted(p_group_id, !isOn)`, optimistic. */
    fun setGroupOn(groupId: String, on: Boolean) {
        val before = mutable.value.groups
        mutable.update { s -> s.copy(groups = s.groups?.map { if (it.groupId == groupId) it.copy(muted = !on) else it }, error = false) }
        viewModelScope.launch {
            try {
                env.backend.setMuted(groupId, !on)
            } catch (t: Throwable) {
                t.dataError()
                mutable.update { it.copy(groups = before, error = true) }
                haptic(Tokens.Haptics.globalError)
            }
        }
    }

    /** Off → both null (`set_quiet_hours(null, null, …)`); on shows the time rows until both are chosen. */
    fun setQuietOn(on: Boolean) {
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
                mutable.update { it.copy(quietStart = before.quietStart, quietEnd = before.quietEnd, quietOn = before.quietOn, error = true) }
                haptic(Tokens.Haptics.globalError)
            }
        }
    }
}

@Composable
fun SettingsNotificationsRoute(nav: NavController) {
    val env = LocalAccountEnvironment.current
    val context = LocalContext.current
    val vm = viewModel { SettingsNotificationsViewModel(env) }
    val state by vm.state.collectAsStateWithLifecycle()
    CollectEvents(vm.events, nav)
    SettingsNotificationsScreen(
        state = state,
        systemOff = !NotificationManagerCompat.from(context).areNotificationsEnabled(),
        onBack = { nav.popBackStack() },
        onOpenSettings = { PermissionChecks.openSafely(context, PermissionChecks.notificationSettingsIntent(context)) },
        onGroup = vm::setGroupOn,
        onQuiet = vm::setQuietOn,
        onStart = vm::setStart,
        onEnd = vm::setEnd,
        onCategories = { PermissionChecks.openSafely(context, PermissionChecks.notificationSettingsIntent(context)) },
    )
}

/**
 * `settings.root.layout.list`: 1. system off (footer `settings.notifications.off.footer` — BLOCKED,
 * omitted in release — + Open Settings), 2. Groups (one switch per group, on = not muted; footer),
 * 3. Quiet hours (switch; Start / End rows with the M3 TimePicker dialog; footer), 5. Android
 * "Notification Categories" → the system channel settings. (4. Live Activity is iOS only.)
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
) {
    val context = LocalContext.current
    var picking by remember { mutableStateOf<Boolean?>(null) } // true = start, false = end
    SystemScaffold(
        title = stringResource(R.string.settings_notifications_title),
        backLabel = stringResource(R.string.groups_screen_back_accessibilitylabel),
        onBack = onBack,
    ) { padding ->
        val groups = state.groups
        if (groups == null || !state.loaded) {
            SystemLoading()
            return@SystemScaffold
        }
        SystemList(padding) {
            if (systemOff) {
                BlockedCopy.notificationsOffFooter(context)?.let { item(key = "offFooter") { SystemSectionFooter(it) } }
                item(key = "openSettings") { SystemRow(stringResource(R.string.settings_notifications_opensettings), onClick = onOpenSettings) }
                item(key = "d0") { SystemDivider() }
            }
            if (groups.isNotEmpty()) {
                item(key = "groupsHeader") { SystemSectionHeader(stringResource(R.string.settings_notifications_groups_header)) }
                groups.forEach { g ->
                    item(key = "group:" + g.groupId) { SystemSwitchRow(g.name, checked = !g.muted, onCheckedChange = { onGroup(g.groupId, it) }, enabled = state.online) }
                }
                item(key = "groupsFooter") { SystemSectionFooter(stringResource(R.string.settings_notifications_groups_footer)) }
                item(key = "d1") { SystemDivider() }
            }
            item(key = "quiet") { SystemSwitchRow(stringResource(R.string.settings_notifications_quiethours), state.quietOn, onQuiet, enabled = state.online) }
            if (state.quietOn) {
                item(key = "start") {
                    SystemRow(
                        stringResource(R.string.settings_notifications_quiethours_start),
                        trailing = { state.quietStart?.let { Text(Formats.time(it)) } },
                        enabled = state.online,
                        onClick = { picking = true },
                    )
                }
                item(key = "end") {
                    SystemRow(
                        stringResource(R.string.settings_notifications_quiethours_end),
                        trailing = { state.quietEnd?.let { Text(Formats.time(it)) } },
                        enabled = state.online,
                        onClick = { picking = false },
                    )
                }
            }
            item(key = "quietFooter") { SystemSectionFooter(stringResource(R.string.settings_notifications_quiethours_footer)) }
            if (state.error) item(key = "error") { SystemSectionFooter(stringResource(R.string.settings_notifications_error), isError = true) }
            item(key = "d2") { SystemDivider() }
            item(key = "categories") { SystemRow(stringResource(R.string.settings_notifications_categories), onClick = onCategories) }
        }
        when (picking) {
            true -> TimeDialog(stringResource(R.string.settings_notifications_quiethours_start), state.quietStart, onCancel = { picking = null }) { picking = null; onStart(it) }
            false -> TimeDialog(stringResource(R.string.settings_notifications_quiethours_end), state.quietEnd, onCancel = { picking = null }) { picking = null; onEnd(it) }
            null -> Unit
        }
    }
}
