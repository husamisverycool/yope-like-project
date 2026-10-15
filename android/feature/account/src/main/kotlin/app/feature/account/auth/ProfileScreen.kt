// Surface: auth.profile — name and avatar. Spec: design/surfaces/auth.profile.md.
// References: as auth.phone plus references/auto/yope/frames/a-itsmthuyope-7644974799302823175-t51.73-group-profile-add-20-pics.png (GP, 92-pt avatar)
// and a-yrrah-7434441926000037121-t43.23-members-list-2024.png (ML, default avatar).
package app.feature.account.auth

import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.autofill.ContentType
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.TextRange
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.input.TextFieldValue
import androidx.compose.ui.text.style.TextAlign
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
import app.feature.account.common.SignUpLayout
import app.feature.account.common.dataError
import app.feature.account.shell.AccountFlow
import app.media.PhotoImport
import app.ui.components.Avatar
import app.ui.components.FormTextField
import app.ui.components.HudOverlay
import app.ui.components.OnboardingTitle
import app.ui.components.PrimaryButton
import app.ui.text.TextRoles
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import java.io.File

enum class ProfileError(val copy: Int) {
    Upload(R.string.auth_profile_error_upload),
    Save(R.string.auth_profile_error_save),
}

data class ProfileUiState(
    val name: String = "",
    /** The picked photo, prepared for upload (shown cropped to the circle). */
    val avatar: File? = null,
    val saving: Boolean = false,
    val offline: Boolean = false,
    /** BLOCKED presentation (`auth.phone.layout.inlineError`): kept in state, not drawn. */
    val error: ProfileError? = null,
) {
    val canContinue: Boolean get() = !saving && name.isNotBlank()
}

class ProfileViewModel(private val env: AccountEnvironment) : AccountViewModel() {
    private val mutable = MutableStateFlow(ProfileUiState())
    val state: StateFlow<ProfileUiState> = mutable.asStateFlow()

    fun onName(text: String) = mutable.update { it.copy(name = text.take(MAX_NAME), error = null) }

    fun onPicked(uri: Uri) {
        viewModelScope.launch {
            val file = runCatching { env.images.importJpeg(uri) }.getOrNull()
            mutable.update { it.copy(avatar = file, error = if (file == null) ProfileError.Upload else null) }
        }
    }

    fun retry() = mutable.update { it.copy(offline = false) }

    fun submit() {
        val current = mutable.value
        if (!current.canContinue) return
        mutable.update { it.copy(saving = true, error = null) }
        viewModelScope.launch {
            current.avatar?.let { file ->
                try {
                    env.backend.setAvatar(file)
                } catch (t: Throwable) {
                    val error = t.dataError()
                    // Upload failed: the avatar returns to empty; continue stays enabled.
                    mutable.update { if (error == DataError.Network) it.copy(saving = false, offline = true) else it.copy(saving = false, avatar = null, error = ProfileError.Upload) }
                    haptic(Tokens.Haptics.globalError)
                    return@launch
                }
                mutable.update { it.copy(avatar = null) }
            }
            try {
                env.backend.updateDisplayName(current.name.trim())
                mutable.update { it.copy(saving = false) }
                haptic(Tokens.Haptics.globalSuccess)
                navigate(AccountFlow.firstOnboardingStep(env), clearStack = true)
            } catch (t: Throwable) {
                val error = t.dataError()
                mutable.update { if (error == DataError.Network) it.copy(saving = false, offline = true) else it.copy(saving = false, error = ProfileError.Save) }
                haptic(Tokens.Haptics.globalError)
            }
        }
    }

    private companion object {
        /** `profiles.display_name` 1–80 characters (docs/API.md §5.1). */
        const val MAX_NAME = 80
    }
}

@Composable
fun ProfileRoute(nav: NavController) {
    val env = LocalAccountEnvironment.current
    val vm = viewModel { ProfileViewModel(env) }
    val state by vm.state.collectAsStateWithLifecycle()
    CollectEvents(vm.events, nav)
    val picker = rememberLauncherForActivityResult(PhotoImport.single()) { uri -> uri?.let(vm::onPicked) }
    ProfileScreen(state, vm::onName, onPickAvatar = { picker.launch(PhotoImport.imagesOnly) }, onContinue = vm::submit, onRetry = vm::retry)
}

@Composable
fun ProfileScreen(
    state: ProfileUiState,
    onName: (String) -> Unit,
    onPickAvatar: () -> Unit,
    onContinue: () -> Unit,
    onRetry: () -> Unit,
    avatarImage: Any? = state.avatar,
) {
    if (state.offline) {
        SignUpOffline(stringResource(R.string.auth_profile_offline_detail), onRetry)
        return
    }
    var field by remember { mutableStateOf(TextFieldValue(state.name, TextRange(state.name.length))) }
    if (field.text != state.name) field = TextFieldValue(state.name, TextRange(state.name.length))
    val avatarLabel = stringResource(if (avatarImage == null) R.string.auth_profile_avatar_accessibilitylabel else R.string.auth_profile_avatar_changeaccessibilitylabel)
    SignUpLayout(overlay = { HudOverlay(state.saving, stringResource(R.string.groups_create_hud_loading)) }) {
        OnboardingTitle(stringResource(R.string.auth_profile_title))
        Text(stringResource(R.string.auth_profile_subtitle), style = TextRoles.onboardingSubtitle, modifier = Modifier.fillMaxWidth())
        Spacer(Modifier.height(Tokens.Sizes.groupsCreateSizeTitleToContent))
        Avatar(
            image = avatarImage,
            size = Tokens.Sizes.authProfileSizeAvatar,
            modifier = Modifier
                .clickable(role = Role.Button, onClick = onPickAvatar)
                .semantics { contentDescription = avatarLabel },
        )
        if (avatarImage == null) {
            Spacer(Modifier.height(Tokens.Sizes.groupsCreateSizeFieldToButton))
            Text(
                stringResource(R.string.auth_profile_avatar_add),
                style = TextRoles.listSubtitle,
                color = Tokens.Colors.globalTextSecondary,
                textAlign = TextAlign.Center,
                modifier = Modifier.clickable(onClick = onPickAvatar),
            )
        }
        Spacer(Modifier.height(Tokens.Sizes.groupsCreateSizeMediaToField))
        FormTextField(
            value = field,
            onValueChange = { field = it; onName(it.text) },
            placeholder = stringResource(R.string.auth_profile_field_placeholder),
            accessibilityLabel = stringResource(R.string.auth_profile_field_accessibilitylabel),
            keyboardOptions = KeyboardOptions(capitalization = KeyboardCapitalization.Words, imeAction = ImeAction.Done),
            keyboardActions = KeyboardActions(onDone = { onContinue() }),
            autofill = ContentType.PersonFirstName,
        )
        Text(
            stringResource(R.string.auth_profile_field_note),
            style = TextRoles.caption,
            color = Tokens.Colors.globalTextSecondary,
            textAlign = TextAlign.Center,
            modifier = Modifier.fillMaxWidth(),
        )
        Spacer(Modifier.height(Tokens.Sizes.groupsCreateSizeFieldToButton))
        PrimaryButton(stringResource(R.string.auth_profile_continue), onContinue, enabled = state.canContinue)
    }
}
