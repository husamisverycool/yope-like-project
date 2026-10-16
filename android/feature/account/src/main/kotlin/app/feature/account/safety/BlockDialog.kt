// Surface: safety.block — block flow (the confirmation; the menu items are placed by each calling surface).
// Spec: design/surfaces/safety.block.md. References: references/auto/retro/apk/retro-android-2026.10.1150-strings.txt (APK-S:
// "Block Profile", "Block %1$s?", confirm message, "They will not be notified"), references/auto/retro/press/
// tc-2025-12-rewind-panels.png (TC-RWP: native menu with a red destructive item); HIG action sheets; M3 dialogs.
package app.feature.account.safety

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
import app.feature.account.common.AccountEvent
import app.feature.account.common.AccountViewModel
import app.feature.account.common.CollectEvents
import app.feature.account.common.dataError
import app.ui.system.ErrorAlert
import app.ui.system.SystemAlertDialog
import app.feature.account.common.errorDismissLabel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

@Immutable
data class BlockUiState(val firstName: String = "", val blocking: Boolean = false, val error: Boolean = false)

class BlockViewModel(private val env: AccountEnvironment, private val userId: String) : AccountViewModel() {
    private val mutable = MutableStateFlow(BlockUiState())
    val state: StateFlow<BlockUiState> = mutable.asStateFlow()

    init {
        viewModelScope.launch {
            val first = runCatching { env.backend.profiles(listOf(userId)).firstOrNull()?.firstName }.getOrNull()
            if (first != null) mutable.update { it.copy(firstName = first) }
        }
    }

    /** `block_user`: the dialog's confirm shows progress; done → back to the caller, which refetches (RLS hides their content). */
    fun block() {
        mutable.update { it.copy(blocking = true, error = false) }
        viewModelScope.launch {
            try {
                env.backend.block(userId)
                haptic(Tokens.Haptics.globalWarning)
                mutable.value.firstName.takeIf { it.isNotBlank() }?.let { toast(R.string.safety_block_done, it) }
                emit(AccountEvent.Back)
            } catch (t: Throwable) {
                t.dataError()
                mutable.update { it.copy(blocking = false, error = true) }
                haptic(Tokens.Haptics.globalError)
            }
        }
    }
}

/** Key the caller's back-stack entry receives after a block (refetch what it shows). */
const val BLOCKED_RESULT_KEY = "safety.block.blockedUserId"

@Composable
fun BlockRoute(nav: NavController, userId: String) {
    val env = LocalAccountEnvironment.current
    val vm = viewModel(key = "block:$userId") { BlockViewModel(env, userId) }
    val state by vm.state.collectAsStateWithLifecycle()
    CollectEvents(vm.events, nav) { event ->
        if (event == AccountEvent.Back) {
            nav.previousBackStackEntry?.savedStateHandle?.set(BLOCKED_RESULT_KEY, userId)
            nav.popBackStack()
            true
        } else {
            false
        }
    }
    UndimmedDialogWindow()
    BlockConfirmation(state, onConfirm = vm::block, onCancel = { nav.popBackStack() })
}

/**
 * `safety.block.layout.confirm` android: the M3 AlertDialog (`settings.account.layout.alert`, C-29) — title
 * `safety.block.title`, message `safety.block.message`, Cancel (dismissive, leading) and "Yes, block" (destructive,
 * trailing; the platform indicator while `block_user` runs). Done: the platform toast `safety.block.done` (C-26). Failed /
 * offline: the message-only alert `safety.block.error` with "OK".
 */
@Composable
fun BlockConfirmation(state: BlockUiState, onConfirm: () -> Unit, onCancel: () -> Unit) {
    if (state.error) {
        ErrorAlert(stringResource(R.string.safety_block_error), errorDismissLabel(), onCancel)
        return
    }
    SystemAlertDialog(
        title = stringResource(R.string.safety_block_title, state.firstName),
        text = stringResource(R.string.safety_block_message, state.firstName),
        confirmLabel = stringResource(R.string.safety_block_confirm),
        onConfirm = onConfirm,
        dismissLabel = stringResource(R.string.safety_block_cancel),
        onDismiss = onCancel,
        destructive = true,
        confirmBusy = state.blocking,
    )
}
