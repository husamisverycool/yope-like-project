// Surface: settings.blocked — blocked people. Spec: design/surfaces/settings.blocked.md.
// References: HIG Lists and tables; M3 Lists specs (leading avatar 40 dp); SwiftUI ContentUnavailableView.
package app.feature.account.settings

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.Immutable
import androidx.compose.runtime.getValue
import androidx.compose.ui.res.stringResource
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
import app.feature.account.common.dataError
import app.ui.components.Avatar
import app.ui.system.SystemEmpty
import app.ui.system.SystemList
import app.ui.system.SystemLoading
import app.ui.system.SystemRow
import app.ui.system.SystemScaffold
import app.ui.system.SystemSectionFooter
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

@Immutable
data class BlockedPerson(val userId: String, val name: String?, val avatarUrl: String?, val firstName: String? = null)

@Immutable
data class SettingsBlockedUiState(val people: List<BlockedPerson>? = null, val error: Boolean = false, val online: Boolean = true)

class SettingsBlockedViewModel(private val env: AccountEnvironment) : AccountViewModel() {
    private val mutable = MutableStateFlow(SettingsBlockedUiState())
    val state: StateFlow<SettingsBlockedUiState> = mutable.asStateFlow()

    init {
        viewModelScope.launch { env.backend.online.collect { online -> mutable.update { it.copy(online = online) } } }
        load()
    }

    fun load() {
        mutable.update { it.copy(error = false) }
        viewModelScope.launch {
            try {
                val blocks = env.backend.blocked()
                val profiles = runCatching { env.backend.profiles(blocks.map { it.blockedId }) }.getOrDefault(emptyList()).associateBy { it.id }
                val urls = runCatching { env.backend.signedUrls(profiles.values.mapNotNull { it.avatarPath }) }.getOrDefault(emptyMap())
                val people = blocks.sortedByDescending { it.createdAt }.map { b ->
                    val p = profiles[b.blockedId]
                    BlockedPerson(b.blockedId, p?.displayName?.takeIf { it.isNotBlank() }, p?.avatarPath?.let(urls::get), p?.firstName?.takeIf { it.isNotBlank() })
                }
                mutable.update { it.copy(people = people) }
            } catch (t: Throwable) {
                t.dataError()
                mutable.update { it.copy(error = true) }
            }
        }
    }

    /** `unblock_user`: no confirmation (not destructive); the row leaves at once, restored on failure. */
    fun unblock(person: BlockedPerson) {
        val before = mutable.value.people
        mutable.update { it.copy(people = before?.filterNot { p -> p.userId == person.userId }) }
        haptic(Tokens.Haptics.globalSuccess)
        viewModelScope.launch {
            try {
                env.backend.unblock(person.userId)
                person.firstName?.let { toast(R.string.safety_block_undone, it) }
            } catch (t: Throwable) {
                t.dataError()
                mutable.update { it.copy(people = before, error = true) }
                haptic(Tokens.Haptics.globalError)
            }
        }
    }
}

@Composable
fun SettingsBlockedRoute(nav: NavController) {
    val env = LocalAccountEnvironment.current
    val vm = viewModel { SettingsBlockedViewModel(env) }
    val state by vm.state.collectAsStateWithLifecycle()
    CollectEvents(vm.events, nav)
    SettingsBlockedScreen(state, onBack = { nav.popBackStack() }, onUnblock = vm::unblock, onRetry = vm::load)
}

/**
 * One row per block, newest first: avatar `settings.root.size.listItemAvatar.android` (fallback gray +
 * person glyph), name or `settings.blocked.unknown`, trailing TextButton `settings.blocked.unblock` in
 * `color.global.system.primary`. Empty: `settings.blocked.layout.empty`. Error: footer + retry.
 */
@Composable
fun SettingsBlockedScreen(state: SettingsBlockedUiState, onBack: () -> Unit, onUnblock: (BlockedPerson) -> Unit, onRetry: () -> Unit) {
    SystemScaffold(
        title = stringResource(R.string.settings_blocked_title),
        backLabel = stringResource(R.string.groups_screen_back_accessibilitylabel),
        onBack = onBack,
    ) { padding ->
        val people = state.people
        when {
            people == null && state.error -> SystemList(padding) {
                item(key = "error") { SystemSectionFooter(stringResource(R.string.settings_blocked_error), isError = true) }
                item(key = "retry") {
                    TextButton(onClick = onRetry) { Text(stringResource(R.string.settings_blocked_retry), style = MaterialTheme.typography.labelLarge, color = Tokens.Colors.globalSystemPrimary) }
                }
            }
            people == null -> SystemLoading()
            people.isEmpty() -> SystemEmpty(stringResource(R.string.settings_blocked_empty_title), stringResource(R.string.settings_blocked_empty_message))
            else -> SystemList(padding) {
                people.forEach { person ->
                    item(key = person.userId) {
                        SystemRow(
                            headline = person.name ?: stringResource(R.string.settings_blocked_unknown),
                            leading = { Avatar(person.avatarUrl, Tokens.Sizes.settingsRootSizeListItemAvatarAndroid) },
                            trailing = {
                                TextButton(onClick = { onUnblock(person) }, enabled = state.online) {
                                    Text(stringResource(R.string.settings_blocked_unblock), style = MaterialTheme.typography.labelLarge, color = Tokens.Colors.globalSystemPrimary)
                                }
                            },
                            modifier = androidx.compose.ui.Modifier.animateItem(),
                        )
                    }
                }
                if (state.error) item(key = "error") { SystemSectionFooter(stringResource(R.string.settings_blocked_error), isError = true) }
            }
        }
    }
}
