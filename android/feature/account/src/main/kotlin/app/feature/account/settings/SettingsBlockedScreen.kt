// Surface: settings.blocked — blocked people. Spec: design/surfaces/settings.blocked.md.
// References: references/auto/retro/press/tc-2023-07-retro-1b.webp (TC-1B: people row — avatar 37, name, capsule action),
// references/auto/retro/apk/retro-android-2026.10.1150-strings.txt (APK-S: "Unblock Profile", "Error loading friends. Tap here to
// try again.", empty-state voice), references/auto/retro/lazyweb/retro-lazyweb-20251020-week43-dark.png (H43: C-27 block).
// Composition of C-14, C-16, C-06, C-27 in the platform's list order.
package app.feature.account.settings

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.runtime.Composable
import androidx.compose.runtime.Immutable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
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
import app.feature.account.common.TapLine
import app.feature.account.common.dataError
import app.feature.account.common.errorDismissLabel
import app.feature.account.common.sheetBottomPadding
import app.ui.components.Capsule
import app.ui.components.CapsuleStyle
import app.ui.components.EmptyState
import app.ui.components.GroupedPosition
import app.ui.components.Hairline
import app.ui.components.HeaderAction
import app.ui.components.PeopleRow
import app.ui.foundation.DsMotion
import app.ui.foundation.PageRoles
import app.ui.system.ErrorAlert
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

@Immutable
data class BlockedPerson(val userId: String, val name: String?, val avatarUrl: String?, val firstName: String? = null)

@Immutable
data class SettingsBlockedUiState(
    val people: List<BlockedPerson>? = null,
    /** The list failed to load (or the device is offline): Retro's one tappable line. */
    val error: Boolean = false,
    val online: Boolean = true,
    /** An unblock failed (the row stays): the message-only alert `safety.block.error`. */
    val unblockFailed: Boolean = false,
)

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

    fun dismissError() = mutable.update { it.copy(unblockFailed = false) }

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
                mutable.update { it.copy(people = before, unblockFailed = true) }
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
    SettingsBlockedScreen(state, onBack = { nav.popBackStack() }, onUnblock = vm::unblock, onRetry = vm::load, onDismissError = vm::dismissError)
}

/**
 * Pushed inside the Settings sheet (back + centred "Blocked People"): one C-14 group of people rows (C-16: avatar
 * `size.global.avatarPicker` — C-23 fallback `icon.global.person` —, first name `listTitle` or "Someone you blocked" in
 * secondary text, trailing C-06 outline capsule "Unblock"), rows at least `settings.root.size.rowHeight`, hairlines between;
 * an unblocked row fades out (`duration.global.fade`). Loading: one row with the platform indicator; empty: the C-27 block
 * centred (glyph `icon.global.person`, no action); error / offline: Retro's one tappable line, centred.
 */
@Composable
fun SettingsBlockedScreen(
    state: SettingsBlockedUiState,
    onBack: () -> Unit,
    onUnblock: (BlockedPerson) -> Unit,
    onRetry: () -> Unit,
    onDismissError: () -> Unit = {},
) {
    SheetPage(
        title = stringResource(R.string.settings_blocked_title),
        back = HeaderAction(Tokens.Icons.globalBack, stringResource(R.string.groups_screen_back_accessibilitylabel), onBack),
    ) {
        val people = state.people
        when {
            people == null && (state.error || !state.online) -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                TapLine(stringResource(R.string.settings_blocked_error), onRetry)
            }
            people == null -> Box(Modifier.padding(top = Tokens.Sizes.globalSectionHeaderToContent)) { LoadingGroup() }
            people.isEmpty() -> Box(Modifier.fillMaxSize().padding(bottom = sheetBottomPadding()), contentAlignment = Alignment.Center) {
                EmptyState(
                    title = stringResource(R.string.settings_blocked_empty_title),
                    detail = stringResource(R.string.settings_blocked_empty_message),
                    icon = Tokens.Icons.globalPerson,
                )
            }
            else -> LazyColumn(
                Modifier.fillMaxSize(),
                contentPadding = PaddingValues(start = Tokens.Sizes.globalScreenMargin, end = Tokens.Sizes.globalScreenMargin, top = Tokens.Sizes.globalSectionHeaderToContent, bottom = sheetBottomPadding()),
            ) {
                itemsIndexed(people, key = { _, p -> p.userId }) { index, person ->
                    BlockedRow(person, GroupedPosition.of(index, people.size), onUnblock, Modifier.animateItem(fadeInSpec = DsMotion.fade(), fadeOutSpec = DsMotion.fade()))
                }
            }
        }
    }
    if (state.unblockFailed) ErrorAlert(stringResource(R.string.safety_block_error), errorDismissLabel(), onDismissError)
}

@Composable
private fun BlockedRow(person: BlockedPerson, position: GroupedPosition, onUnblock: (BlockedPerson) -> Unit, modifier: Modifier) {
    val shape = position.shape()
    val unblock = stringResource(R.string.settings_blocked_unblock)
    val name = person.firstName ?: person.name
    Column(modifier.fillMaxWidth().clip(shape).background(PageRoles.secondarySurface, shape)) {
        Box(Modifier.fillMaxWidth().heightIn(min = Tokens.Sizes.settingsRootSizeRowHeight).padding(vertical = Tokens.Sizes.globalSectionHeaderToContent), contentAlignment = Alignment.CenterStart) {
            PeopleRow(
                name = name ?: stringResource(R.string.settings_blocked_unknown),
                avatar = person.avatarUrl,
                trailing = {
                    // "Unblock Ana": the capsule's label composed with the name for TalkBack.
                    Capsule(
                        unblock,
                        { onUnblock(person) },
                        Modifier.semantics { contentDescription = if (name != null) "$unblock $name" else unblock },
                        style = CapsuleStyle.Outline,
                    )
                },
            )
        }
        if (position.dividerBelow) Hairline()
    }
}
