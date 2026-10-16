// Surface: settings.account — profile fields, delete account. Spec: design/surfaces/settings.account.md.
// References: references/auto/retro/video/ig-DJXvmqRv2_N-referrals-sheet-f042-059.png (VID-SET: grouped rows),
// references/auto/retro/press/tc-2024-04-retro-journals-5.png (TC-J5: red destructive row, row height),
// references/auto/retro/apk/retro-android-2026.10.1150-strings.txt (APK-S: Edit Profile rows, photo choice sheet,
// "Name too long", delete copy, "Yes, delete").
package app.feature.account.settings

import android.Manifest
import android.net.Uri
import androidx.activity.compose.BackHandler
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.Immutable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.autofill.ContentType
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.TextRange
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.input.TextFieldValue
import androidx.core.content.FileProvider
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewModelScope
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.navigation.NavController
import app.designsystem.R
import app.designsystem.generated.Tokens
import app.feature.account.AccountEnvironment
import app.feature.account.LocalAccountEnvironment
import app.feature.account.auth.PhoneNumbers
import app.feature.account.common.AccountViewModel
import app.feature.account.common.CollectEvents
import app.feature.account.common.SheetPage
import app.feature.account.common.dataError
import app.feature.account.common.errorDismissLabel
import app.feature.account.common.sheetBottomPadding
import app.media.PhotoImport
import app.model.AppRoute
import app.ui.components.Avatar
import app.ui.components.FormTextField
import app.ui.components.GroupedRowSpec
import app.ui.components.GroupedTrailing
import app.ui.components.HeaderAction
import app.ui.components.PrimaryButton
import app.ui.foundation.DsMotion
import app.ui.foundation.tapClickable
import app.ui.format.Formats
import app.ui.permissions.PermissionChecks
import app.ui.permissions.PermissionRationale
import app.ui.permissions.rememberPermissionRequest
import app.ui.system.DsBottomSheet
import app.ui.system.ErrorAlert
import app.ui.system.SystemAlertDialog
import app.ui.text.TextRoles
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import java.io.File
import java.time.LocalDate
import java.util.UUID

/** The FileProvider handing the system camera its target file (settings.account "Take Photo"). */
class AccountFileProvider : FileProvider()

@Immutable
data class SettingsAccountUiState(
    val name: String = "",
    val avatar: Any? = null,
    val hasPhoto: Boolean = false,
    val phone: String? = null,
    val birthday: LocalDate? = null,
    val premium: Boolean = false,
    val online: Boolean = true,
    /** The Edit Full Name page is open. */
    val editingName: Boolean = false,
    val savingName: Boolean = false,
    val savingPhoto: Boolean = false,
    val confirmDelete: Boolean = false,
    val deleting: Boolean = false,
    val deleteError: Boolean = false,
    /** A name or photo save failed (or was tried offline): `settings.account.name.error`. */
    val saveError: Boolean = false,
    /** The camera was denied from the photo sheet: the alert with `onboarding.permission.camera.denied.*`. */
    val cameraDenied: Boolean = false,
)

class SettingsAccountViewModel(private val env: AccountEnvironment) : AccountViewModel() {
    private val mutable = MutableStateFlow(SettingsAccountUiState(phone = env.backend.currentPhone()?.let(PhoneNumbers::display)))
    val state: StateFlow<SettingsAccountUiState> = mutable.asStateFlow()

    init {
        viewModelScope.launch { env.backend.online.collect { online -> mutable.update { it.copy(online = online) } } }
        viewModelScope.launch { env.premium.isActive.collect { p -> mutable.update { it.copy(premium = p) } } }
        viewModelScope.launch {
            val me = runCatching { env.backend.me() }.getOrNull() ?: return@launch
            val url = me.avatarPath?.let { path -> runCatching { env.backend.signedUrls(listOf(path))[path] }.getOrNull() }
            mutable.update { it.copy(name = me.displayName, avatar = url, hasPhoto = me.avatarPath != null) }
        }
        reloadBirthday()
    }

    /** Back from birthday.add: the row shows the saved date. */
    fun reloadBirthday() {
        viewModelScope.launch {
            val birthday = runCatching { env.backend.birthday() }.getOrNull()
            mutable.update { it.copy(birthday = birthday) }
        }
    }

    fun openName() = mutable.update { it.copy(editingName = true) }
    fun closeName() = mutable.update { if (it.savingName) it else it.copy(editingName = false) }
    fun dismissError() = mutable.update { it.copy(saveError = false, deleteError = false, cameraDenied = false) }
    fun onCameraDenied() = mutable.update { it.copy(cameraDenied = true) }

    /** Edit Full Name → Save: `update profiles set display_name`; the page closes on success. */
    fun saveName(name: String) {
        val trimmed = name.trim()
        if (trimmed.isEmpty() || trimmed.length > MAX_NAME) return
        if (!mutable.value.online) return saveFailed()
        if (trimmed == mutable.value.name) return closeName()
        mutable.update { it.copy(savingName = true, saveError = false) }
        viewModelScope.launch {
            try {
                env.backend.updateDisplayName(trimmed)
                mutable.update { it.copy(name = trimmed, savingName = false, editingName = false) }
                haptic(Tokens.Haptics.globalSuccess)
            } catch (t: Throwable) {
                t.dataError()
                mutable.update { it.copy(savingName = false) }
                saveFailed()
            }
        }
    }

    /** A new photo (library or camera): shown at once with the platform indicator over it, uploaded, reverted on failure. */
    fun onPhoto(uri: Uri) {
        if (!mutable.value.online) return saveFailed()
        val before = mutable.value
        viewModelScope.launch {
            val file: File = runCatching { env.images.importJpeg(uri) }.getOrNull() ?: return@launch saveFailed()
            mutable.update { it.copy(avatar = file, savingPhoto = true) }
            try {
                env.backend.setAvatar(file)
                mutable.update { it.copy(savingPhoto = false, hasPhoto = true) }
                haptic(Tokens.Haptics.globalSuccess)
            } catch (t: Throwable) {
                t.dataError()
                mutable.update { it.copy(avatar = before.avatar, hasPhoto = before.hasPhoto, savingPhoto = false) }
                saveFailed()
            }
        }
    }

    /** "Remove Profile Photo": clears `avatar_path`. */
    fun removePhoto() {
        if (!mutable.value.online) return saveFailed()
        val before = mutable.value
        mutable.update { it.copy(avatar = null, hasPhoto = false, savingPhoto = true) }
        viewModelScope.launch {
            try {
                env.backend.removeAvatar()
                mutable.update { it.copy(savingPhoto = false) }
            } catch (t: Throwable) {
                t.dataError()
                mutable.update { it.copy(avatar = before.avatar, hasPhoto = before.hasPhoto, savingPhoto = false) }
                saveFailed()
            }
        }
    }

    private fun saveFailed() {
        mutable.update { it.copy(saveError = true) }
        haptic(Tokens.Haptics.globalError)
    }

    fun askDelete() = mutable.update { it.copy(confirmDelete = true, deleteError = false) }
    fun cancelDelete() = mutable.update { it.copy(confirmDelete = false, deleteError = false) }

    /**
     * `delete_account()` then the session is dropped (core:data `AccountRepository`; the device row is deleted with the
     * account) → auth.phone with the toast `settings.account.deleted.toast`.
     */
    fun delete() {
        mutable.update { it.copy(confirmDelete = false, deleting = true) }
        haptic(Tokens.Haptics.globalWarning)
        viewModelScope.launch {
            try {
                env.backend.deleteAccount()
                mutable.update { it.copy(deleting = false) }
                toast(R.string.settings_account_deleted_toast)
                navigate(AppRoute.AuthPhone, clearStack = true)
            } catch (t: Throwable) {
                t.dataError()
                mutable.update { it.copy(deleting = false, deleteError = true) }
                haptic(Tokens.Haptics.globalError)
            }
        }
    }

    companion object {
        /** `profiles.display_name` holds 1–80 characters (docs/API.md §5.1). */
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
    var cameraTarget by remember { mutableStateOf<Uri?>(null) }
    val camera = rememberLauncherForActivityResult(ActivityResultContracts.TakePicture()) { taken -> cameraTarget?.takeIf { taken }?.let(vm::onPhoto) }
    val cameraPermission = rememberPermissionRequest(
        Manifest.permission.CAMERA,
        PermissionRationale(
            title = stringResource(R.string.system_permissions_rationale_camera_title),
            message = stringResource(R.string.system_permissions_rationale_camera_message),
            notNow = stringResource(R.string.system_permissions_rationale_notnow),
            continueLabel = stringResource(R.string.system_permissions_rationale_continue),
            openSettings = stringResource(R.string.system_permissions_opensettings),
        ),
        onResult = { granted ->
            if (granted) {
                val file = File(context.cacheDir, "camera/${UUID.randomUUID()}.jpg").also { it.parentFile?.mkdirs() }
                val uri = FileProvider.getUriForFile(context, context.packageName + ".account.files", file)
                cameraTarget = uri
                camera.launch(uri)
            } else {
                vm.onCameraDenied()
            }
        },
    )
    BackHandler(enabled = state.editingName) { vm.closeName() }
    // Back from birthday.add: the Birthday row follows.
    androidx.lifecycle.compose.LifecycleResumeEffect(Unit) {
        vm.reloadBirthday()
        onPauseOrDispose { }
    }
    SettingsAccountScreen(
        state = state,
        actions = SettingsAccountActions(
            onBack = { nav.popBackStack() },
            onOpenName = vm::openName,
            onCloseName = vm::closeName,
            onSaveName = vm::saveName,
            onLibrary = { picker.launch(PhotoImport.imagesOnly) },
            onCamera = cameraPermission::launch,
            onRemovePhoto = vm::removePhoto,
            onBirthday = { nav.navigate(AppRoute.BirthdayAdd) },
            onDelete = vm::askDelete,
            onConfirmDelete = vm::delete,
            onCancelDelete = vm::cancelDelete,
            onDismissError = vm::dismissError,
            onOpenSettings = { PermissionChecks.openSafely(context, PermissionChecks.appSettingsIntent(context)) },
        ),
    )
}

/** What the Account page does on each control. */
@Immutable
data class SettingsAccountActions(
    val onBack: () -> Unit = {},
    val onOpenName: () -> Unit = {},
    val onCloseName: () -> Unit = {},
    val onSaveName: (String) -> Unit = {},
    val onLibrary: () -> Unit = {},
    val onCamera: () -> Unit = {},
    val onRemovePhoto: () -> Unit = {},
    val onBirthday: () -> Unit = {},
    val onDelete: () -> Unit = {},
    val onConfirmDelete: () -> Unit = {},
    val onCancelDelete: () -> Unit = {},
    val onDismissError: () -> Unit = {},
    val onOpenSettings: () -> Unit = {},
)

/**
 * Pushed inside the Settings sheet (back + centred "Account"; `settings.root.layout.list`): group 1 — Profile Photo (the
 * 64 avatar leading, C-23; chevron → the photo sheet: Choose from Library, Take Photo, Remove Profile Photo), Full Name
 * (name + chevron → Edit Full Name), Phone Number (read-only value), Birthday (date or nothing + chevron → birthday.add);
 * group 2 — Delete Account (C-10 red) and its footer. Edit Full Name (pushed): back + centred title, the C-12 field
 * `size.global.titleToContent` under the bar (C-12 error "Name too long"), C-05 "Save" pinned above the keyboard.
 * Pages change with the house fade.
 */
@Composable
fun SettingsAccountScreen(state: SettingsAccountUiState, actions: SettingsAccountActions) {
    var photoSheet by remember { mutableStateOf(false) }
    AnimatedContent(targetState = state.editingName, transitionSpec = { DsMotion.fadeIn togetherWith DsMotion.fadeOut }, label = "accountPage") { editing ->
        if (editing) {
            EditNamePage(state, actions)
        } else {
            AccountPage(state, actions, onPhoto = { photoSheet = true })
        }
    }
    if (photoSheet) {
        PhotoSheet(
            hasPhoto = state.hasPhoto,
            onDismiss = { photoSheet = false },
            onLibrary = { photoSheet = false; actions.onLibrary() },
            onCamera = { photoSheet = false; actions.onCamera() },
            onRemove = { photoSheet = false; actions.onRemovePhoto() },
        )
    }
    if (state.confirmDelete) {
        val message = stringResource(R.string.settings_account_delete_message) +
            if (state.premium) PARAGRAPH + stringResource(R.string.settings_account_delete_subscriptionnote) else ""
        SystemAlertDialog(
            title = stringResource(R.string.settings_account_delete_title),
            text = message,
            confirmLabel = stringResource(R.string.settings_account_delete_confirm),
            onConfirm = actions.onConfirmDelete,
            dismissLabel = stringResource(R.string.settings_account_alert_cancel),
            onDismiss = actions.onCancelDelete,
            destructive = true,
        )
    }
    when {
        state.deleteError -> ErrorAlert(stringResource(R.string.settings_account_delete_error), errorDismissLabel(), actions.onDismissError)
        state.saveError -> ErrorAlert(stringResource(R.string.settings_account_name_error), errorDismissLabel(), actions.onDismissError)
        state.cameraDenied -> SystemAlertDialog(
            title = stringResource(R.string.onboarding_permission_camera_denied_title),
            text = stringResource(R.string.onboarding_permission_camera_denied_detail),
            confirmLabel = stringResource(R.string.onboarding_permission_camera_denied_button),
            onConfirm = { actions.onDismissError(); actions.onOpenSettings() },
            dismissLabel = stringResource(R.string.settings_account_alert_cancel),
            onDismiss = actions.onDismissError,
        )
    }
}

/** Two paragraphs of an alert message (the delete message and the subscription note). */
private const val PARAGRAPH = "\n\n" // provenance-ok: paragraph break joining two copy strings

@Composable
private fun AccountPage(state: SettingsAccountUiState, actions: SettingsAccountActions, onPhoto: () -> Unit) {
    SheetPage(
        title = stringResource(R.string.settings_account_title),
        back = HeaderAction(Tokens.Icons.globalBack, stringResource(R.string.groups_screen_back_accessibilitylabel), actions.onBack),
    ) {
        Column(Modifier.fillMaxWidth().verticalScroll(rememberScrollState()).padding(top = Tokens.Sizes.globalSectionHeaderToContent, bottom = sheetBottomPadding())) {
            val birthday = state.birthday?.let(Formats::longDate)
            SettingsGroup(
                listOf(
                    GroupedRowSpec(
                        title = stringResource(R.string.settings_account_photo),
                        enabled = !state.savingPhoto && !state.deleting,
                        leading = {
                            androidx.compose.foundation.layout.Box(contentAlignment = Alignment.Center) {
                                Avatar(state.avatar, Tokens.Sizes.globalAvatarProfile)
                                if (state.savingPhoto) app.ui.components.ActivityIndicator(stringResource(R.string.global_a11y_loading))
                            }
                        },
                        onClick = onPhoto,
                    ),
                    GroupedRowSpec(stringResource(R.string.settings_account_name), trailing = GroupedTrailing.ValueChevron(state.name), enabled = !state.deleting, onClick = actions.onOpenName),
                    GroupedRowSpec(stringResource(R.string.settings_account_phone), trailing = state.phone?.let { GroupedTrailing.Value(it) } ?: GroupedTrailing.None),
                    GroupedRowSpec(
                        stringResource(R.string.settings_account_birthday),
                        trailing = birthday?.let { GroupedTrailing.ValueChevron(it) } ?: GroupedTrailing.Chevron,
                        enabled = !state.deleting,
                        onClick = actions.onBirthday,
                    ),
                ),
            )
            SettingsGap()
            if (state.deleting) {
                LoadingGroup()
            } else {
                SettingsGroup(listOf(GroupedRowSpec(stringResource(R.string.settings_account_delete), trailing = GroupedTrailing.None, destructive = true, onClick = actions.onDelete)))
            }
            SettingsFooter(stringResource(R.string.settings_account_delete_footer))
        }
    }
}

/** Edit Full Name: the C-12 field (prefilled) and C-05 "Save" (disabled while empty or too long; busy while saving). */
@Composable
private fun EditNamePage(state: SettingsAccountUiState, actions: SettingsAccountActions) {
    val focus = remember { FocusRequester() }
    var field by remember { mutableStateOf(TextFieldValue(state.name, TextRange(state.name.length))) }
    val tooLong = field.text.trim().length > SettingsAccountViewModel.MAX_NAME
    val canSave = field.text.isNotBlank() && !tooLong
    SheetPage(
        title = stringResource(R.string.settings_account_name_title),
        back = HeaderAction(Tokens.Icons.globalBack, stringResource(R.string.groups_screen_back_accessibilitylabel), actions.onCloseName),
    ) {
        Column(Modifier.fillMaxSize().windowInsetsPadding(WindowInsets.navigationBars).imePadding()) {
            Column(Modifier.weight(1f).fillMaxWidth().verticalScroll(rememberScrollState()).padding(start = Tokens.Sizes.globalScreenMargin, end = Tokens.Sizes.globalScreenMargin, top = Tokens.Sizes.globalTitleToContent)) {
                FormTextField(
                    value = field,
                    onValueChange = { field = it },
                    placeholder = stringResource(R.string.auth_profile_field_placeholder),
                    accessibilityLabel = stringResource(R.string.settings_account_name),
                    keyboardOptions = KeyboardOptions(capitalization = KeyboardCapitalization.Words, imeAction = ImeAction.Done),
                    keyboardActions = KeyboardActions(onDone = { if (canSave) actions.onSaveName(field.text) }),
                    autofill = ContentType.PersonFullName,
                    enabled = !state.savingName,
                    error = if (tooLong) stringResource(R.string.settings_account_name_toolong) else null,
                    modifier = Modifier.focusRequester(focus),
                )
            }
            PrimaryButton(
                stringResource(R.string.settings_account_name_save),
                { actions.onSaveName(field.text) },
                Modifier.padding(start = Tokens.Sizes.globalButtonMarginH, end = Tokens.Sizes.globalButtonMarginH, bottom = Tokens.Sizes.globalButtonMarginH),
                enabled = canSave || state.savingName,
                loading = state.savingName,
            )
        }
    }
    LaunchedEffect(Unit) { runCatching { focus.requestFocus() } }
}

/**
 * The photo choices (`settings.account` Android: an M3 `ModalBottomSheet` list — C-29 [DsBottomSheet]): the sheet title
 * (text role `sheetTitle`, centred) and one row per choice (text role `body`, at least `settings.root.size.rowHeight`);
 * "Remove Profile Photo" in `color.global.destructive`, only with a photo.
 */
@Composable
private fun PhotoSheet(hasPhoto: Boolean, onDismiss: () -> Unit, onLibrary: () -> Unit, onCamera: () -> Unit, onRemove: () -> Unit) {
    DsBottomSheet(onDismissRequest = onDismiss) {
        Column(Modifier.fillMaxWidth().windowInsetsPadding(WindowInsets.navigationBars).padding(bottom = Tokens.Sizes.globalScreenMargin)) {
            Text(
                stringResource(R.string.settings_account_photo_sheettitle),
                style = TextRoles.sheetTitle,
                color = Tokens.Colors.globalTextPrimary,
                textAlign = androidx.compose.ui.text.style.TextAlign.Center,
                modifier = Modifier.fillMaxWidth().padding(bottom = Tokens.Sizes.globalScreenMargin).semantics { heading() },
            )
            SheetChoice(stringResource(R.string.settings_account_photo_library), Tokens.Colors.globalTextPrimary, onLibrary)
            SheetChoice(stringResource(R.string.settings_account_photo_camera), Tokens.Colors.globalTextPrimary, onCamera)
            if (hasPhoto) SheetChoice(stringResource(R.string.settings_account_photo_remove), Tokens.Colors.globalDestructive, onRemove)
        }
    }
}

@Composable
private fun SheetChoice(text: String, color: androidx.compose.ui.graphics.Color, onClick: () -> Unit) {
    androidx.compose.foundation.layout.Box(
        Modifier
            .fillMaxWidth()
            .heightIn(min = Tokens.Sizes.settingsRootSizeRowHeight)
            .tapClickable(onClick = onClick)
            .padding(horizontal = Tokens.Sizes.globalScreenMargin),
        contentAlignment = Alignment.CenterStart,
    ) {
        Text(text, style = TextRoles.body, color = color)
    }
}
