// Surface: settings.account — account, delete account. Spec: design/surfaces/settings.account.md.
// References: https://developer.apple.com/support/offering-account-deletion-in-your-app/ (ADF),
// https://developer.apple.com/design/human-interface-guidelines/managing-accounts#Deleting-accounts (HIG-MA),
// https://m3.material.io/components/dialogs/specs (M3-D), https://support.google.com/googleplay/android-developer/answer/13327111 (GP).
package app.feature.account.settings

import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Text
import androidx.compose.material3.TextField
import androidx.compose.runtime.Composable
import androidx.compose.runtime.Immutable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.input.ImeAction
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewModelScope
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.navigation.NavController
import app.data.error.DataError
import app.designsystem.R
import app.designsystem.generated.Tokens
import app.feature.account.AccountEnvironment
import app.feature.account.LocalAccountEnvironment
import app.feature.account.common.AccountViewModel
import app.feature.account.common.CollectEvents
import app.feature.account.common.dataError
import app.media.PhotoImport
import app.model.AppRoute
import app.ui.components.Avatar
import app.ui.system.SystemAlertDialog
import app.ui.system.SystemDivider
import app.ui.system.SystemList
import app.ui.system.SystemRow
import app.ui.system.SystemScaffold
import app.ui.system.SystemSectionFooter
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import java.io.File

@Immutable
data class SettingsAccountUiState(
    val name: String = "",
    val avatar: Any? = null,
    val phone: String? = null,
    val premium: Boolean = false,
    val online: Boolean = true,
    val confirmDelete: Boolean = false,
    val deleting: Boolean = false,
    val deleteError: Boolean = false,
    val nameError: Boolean = false,
)

class SettingsAccountViewModel(private val env: AccountEnvironment) : AccountViewModel() {
    private val mutable = MutableStateFlow(SettingsAccountUiState(phone = env.backend.currentPhone()))
    val state: StateFlow<SettingsAccountUiState> = mutable.asStateFlow()

    init {
        viewModelScope.launch { env.backend.online.collect { online -> mutable.update { it.copy(online = online) } } }
        viewModelScope.launch { env.premium.isActive.collect { p -> mutable.update { it.copy(premium = p) } } }
        viewModelScope.launch {
            val me = runCatching { env.backend.me() }.getOrNull() ?: return@launch
            val url = me.avatarPath?.let { path -> runCatching { env.backend.signedUrls(listOf(path))[path] }.getOrNull() }
            mutable.update { it.copy(name = me.displayName, avatar = url) }
        }
    }

    /** Saved on submit; optimistic, with the section footer on failure. */
    fun saveName(name: String) {
        val trimmed = name.trim().take(MAX_NAME)
        val before = mutable.value.name
        if (trimmed.isEmpty() || trimmed == before) return
        mutable.update { it.copy(name = trimmed, nameError = false) }
        viewModelScope.launch {
            try {
                env.backend.updateDisplayName(trimmed)
            } catch (t: Throwable) {
                t.dataError()
                mutable.update { it.copy(name = before, nameError = true) }
                haptic(Tokens.Haptics.globalError)
            }
        }
    }

    /** New photo: shown at once (local file), uploaded, reverted on failure. */
    fun onPhoto(uri: Uri) {
        val before = mutable.value.avatar
        viewModelScope.launch {
            val file: File = runCatching { env.images.importJpeg(uri) }.getOrNull() ?: return@launch
            mutable.update { it.copy(avatar = file) }
            try {
                env.backend.setAvatar(file)
            } catch (t: Throwable) {
                t.dataError()
                mutable.update { it.copy(avatar = before) }
                haptic(Tokens.Haptics.globalError)
            }
        }
    }

    fun askDelete() = mutable.update { it.copy(confirmDelete = true, deleteError = false) }
    fun cancelDelete() = mutable.update { it.copy(confirmDelete = false, deleteError = false) }

    /**
     * `delete_account()` then the session is dropped (core:data `AccountRepository`; the device row
     * is deleted with the account) → auth.phone. The "deleted" toast is BLOCKED (dwell time).
     */
    fun delete() {
        mutable.update { it.copy(confirmDelete = false, deleting = true) }
        haptic(Tokens.Haptics.globalWarning)
        viewModelScope.launch {
            try {
                env.backend.deleteAccount()
                mutable.update { it.copy(deleting = false) }
                navigate(AppRoute.AuthPhone, clearStack = true)
            } catch (t: Throwable) {
                t.dataError()
                mutable.update { it.copy(deleting = false, deleteError = true) }
                haptic(Tokens.Haptics.globalError)
            }
        }
    }

    private companion object {
        const val MAX_NAME = 80
    }
}

@Composable
fun SettingsAccountRoute(nav: NavController) {
    val env = LocalAccountEnvironment.current
    val context = LocalContext.current
    val vm = viewModel { SettingsAccountViewModel(env) }
    val state by vm.state.collectAsStateWithLifecycle()
    CollectEvents(vm.events, nav)
    val picker = rememberLauncherForActivityResult(PhotoImport.single()) { uri -> uri?.let(vm::onPhoto) }
    SettingsAccountScreen(
        state = state,
        onBack = { nav.popBackStack() },
        onName = vm::saveName,
        onPhoto = { picker.launch(PhotoImport.imagesOnly) },
        onBirthday = { nav.navigate(AppRoute.BirthdayAdd) },
        onManage = { ManageSubscription.open(context) },
        onDelete = vm::askDelete,
        onConfirmDelete = vm::delete,
        onCancelDelete = vm::cancelDelete,
    )
}

/**
 * `settings.root.layout.list`: 1. Name (inline text field, saved on submit), Photo (avatar thumbnail;
 * system photo picker), Phone Number (read-only), Birthday (→ birthday.add); 2. Manage Subscription
 * (while premium); 3. Delete Account (`color.global.system.error`) + footer. The delete dialog is
 * `settings.account.layout.alert` (2 actions on Android; the subscription note while premium).
 */
@Composable
fun SettingsAccountScreen(
    state: SettingsAccountUiState,
    onBack: () -> Unit,
    onName: (String) -> Unit,
    onPhoto: () -> Unit,
    onBirthday: () -> Unit,
    onManage: () -> Unit,
    onDelete: () -> Unit,
    onConfirmDelete: () -> Unit,
    onCancelDelete: () -> Unit,
) {
    var editing by remember { mutableStateOf(false) }
    var draft by remember(state.name) { mutableStateOf(state.name) }
    val enabled = state.online && !state.deleting
    SystemScaffold(
        title = stringResource(R.string.settings_account_title),
        backLabel = stringResource(R.string.groups_screen_back_accessibilitylabel),
        onBack = onBack,
    ) { padding ->
        SystemList(padding) {
            item(key = "name") {
                if (editing) {
                    TextField(
                        value = draft,
                        onValueChange = { draft = it },
                        singleLine = true,
                        label = { Text(stringResource(R.string.settings_account_name)) },
                        keyboardOptions = KeyboardOptions(imeAction = ImeAction.Done),
                        keyboardActions = KeyboardActions(onDone = { editing = false; onName(draft) }),
                        modifier = Modifier.fillMaxWidth(),
                    )
                } else {
                    SystemRow(stringResource(R.string.settings_account_name), trailing = { Text(state.name) }, enabled = enabled, onClick = { editing = true })
                }
            }
            if (state.nameError) item(key = "nameError") { SystemSectionFooter(stringResource(R.string.settings_account_name_error), isError = true) }
            item(key = "photo") {
                SystemRow(
                    stringResource(R.string.settings_account_photo),
                    trailing = { Avatar(state.avatar, Tokens.Sizes.settingsRootSizeListItemAvatarAndroid) },
                    enabled = enabled,
                    onClick = onPhoto,
                )
            }
            item(key = "phone") { SystemRow(stringResource(R.string.settings_account_phone), trailing = { Text(state.phone.orEmpty()) }) }
            item(key = "birthday") { SystemRow(stringResource(R.string.settings_account_birthday), onClick = onBirthday) }
            item(key = "d1") { SystemDivider() }
            if (state.premium) {
                item(key = "manage") { SystemRow(stringResource(R.string.settings_root_managesubscription), onClick = onManage) }
                item(key = "d2") { SystemDivider() }
            }
            item(key = "delete") {
                SystemRow(
                    stringResource(R.string.settings_account_delete),
                    destructive = true,
                    enabled = enabled,
                    trailing = if (state.deleting) ({ CircularProgressIndicator(color = Tokens.Colors.globalSystemError) }) else null,
                    onClick = onDelete,
                )
            }
            item(key = "deleteFooter") { SystemSectionFooter(stringResource(R.string.settings_account_delete_footer)) }
        }
        if (state.confirmDelete) {
            val message = stringResource(R.string.settings_account_delete_message) +
                if (state.premium) "\n\n" + stringResource(R.string.settings_account_delete_subscriptionnote) else ""
            SystemAlertDialog(
                title = stringResource(R.string.settings_account_delete_title),
                text = message,
                confirmLabel = stringResource(R.string.settings_account_delete_confirm),
                onConfirm = onConfirmDelete,
                dismissLabel = stringResource(R.string.settings_account_alert_cancel),
                onDismiss = onCancelDelete,
                destructive = true,
            )
        }
        if (state.deleteError) {
            AlertWithCancel(stringResource(R.string.settings_account_delete_error), stringResource(R.string.settings_account_alert_cancel), onCancelDelete)
        }
    }
}

/** The error alert: the message and Cancel only (settings.account States "error"). */
@Composable
private fun AlertWithCancel(message: String, cancel: String, onDismiss: () -> Unit) {
    androidx.compose.material3.AlertDialog(
        onDismissRequest = onDismiss,
        containerColor = Tokens.Colors.globalSystemSurfaceContainerHigh,
        text = { Text(message) },
        confirmButton = { androidx.compose.material3.TextButton(onClick = onDismiss) { Text(cancel) } },
    )
}
