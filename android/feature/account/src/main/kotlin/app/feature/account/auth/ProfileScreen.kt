// Surface: auth.profile — 1. name, 2. profile photo. Spec: design/surfaces/auth.profile.md.
// References: references/auto/retro/apk/retro-android-2026.10.1150-strings.txt (APK-S: hints, "Choose photo", "Edit photo",
// "Maybe Later", "Name too long"), references/auto/retro/web/retro.app-5bff8a0be69f7ec7.css (WEB: 112-pt centred avatar),
// references/auto/retro/lazyweb/retro-lazyweb-20251119-social.png (LAND: capsule and secondary link). Composition of
// C-02, C-12, C-23, C-05, C-08 in Retro's sign-up order (FULL_NAME → … → PROFILE_PHOTO; MERGE RA-2, RA-24).
package app.feature.account.auth

import android.net.Uri
import androidx.activity.compose.BackHandler
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.compose.animation.Crossfade
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.autofill.ContentType
import androidx.compose.ui.draw.clip
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.TextRange
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.input.TextFieldValue
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
import app.feature.account.common.OnboardingForm
import app.feature.account.common.dataError
import app.feature.account.common.errorDismissLabel
import app.feature.account.shell.AccountFlow
import app.media.PhotoImport
import app.ui.components.Avatar
import app.ui.components.FormTextField
import app.ui.components.HeaderAction
import app.ui.components.OnboardingPages
import app.ui.components.PrimaryButton
import app.ui.components.TextLink
import app.ui.foundation.DsMotion
import app.ui.foundation.PageRoles
import app.ui.foundation.tapClickable
import app.ui.system.ErrorAlert
import app.ui.text.CapTop
import app.ui.text.TextRoles
import app.ui.text.capTopAt
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

/** The two steps of auth.profile (Retro's FULL_NAME form, then its PROFILE_PHOTO page). */
enum class ProfileStep { Name, Photo }

data class ProfileUiState(
    val step: ProfileStep = ProfileStep.Name,
    val name: String = "",
    /** The picked photo, prepared for upload (shown cropped to the circle). */
    val avatar: File? = null,
    val saving: Boolean = false,
    val offline: Boolean = false,
    /** Shown as the message-only alert of `auth.phone.layout.inlineError`. */
    val error: ProfileError? = null,
) {
    /** `profiles.display_name` holds 1–80 characters after trimming (docs/API.md §5.1): past that, "Name too long". */
    val tooLong: Boolean get() = name.trim().length > MAX_NAME
    val canContinue: Boolean get() = !saving && name.isNotBlank() && !tooLong

    companion object {
        const val MAX_NAME = 80
    }
}

class ProfileViewModel(private val env: AccountEnvironment) : AccountViewModel() {
    private val mutable = MutableStateFlow(ProfileUiState())
    val state: StateFlow<ProfileUiState> = mutable.asStateFlow()
    private var savedName: String? = null

    fun dismissError() = mutable.update { it.copy(error = null) }

    fun onName(text: String) = mutable.update { it.copy(name = text, error = null) }

    fun onPicked(uri: Uri) {
        viewModelScope.launch {
            val file = runCatching { env.images.importJpeg(uri) }.getOrNull()
            mutable.update { it.copy(avatar = file, error = if (file == null) ProfileError.Upload else null) }
        }
    }

    fun retry() = mutable.update { it.copy(offline = false) }

    /** Step 2's back (C-02) → step 1, the name kept. */
    fun backToName() = mutable.update { if (it.saving) it else it.copy(step = ProfileStep.Name) }

    /** The current step's capsule: step 1 saves the name and opens step 2; step 2 uploads the chosen photo and continues. */
    fun submit() = when (mutable.value.step) {
        ProfileStep.Name -> saveName()
        ProfileStep.Photo -> savePhoto()
    }

    /** "Maybe Later": continue without a photo (no follow-up nudge — tenet 5). */
    fun skipPhoto() {
        if (mutable.value.saving) return
        mutable.update { it.copy(avatar = null) }
        navigate(AccountFlow.firstOnboardingStep(env), clearStack = true)
    }

    private fun saveName() {
        val current = mutable.value
        if (!current.canContinue) return
        val name = current.name.trim()
        if (name == savedName) {
            mutable.update { it.copy(step = ProfileStep.Photo) }
            return
        }
        mutable.update { it.copy(saving = true, error = null) }
        viewModelScope.launch {
            try {
                env.backend.updateDisplayName(name)
                savedName = name
                mutable.update { it.copy(saving = false, step = ProfileStep.Photo) }
                haptic(Tokens.Haptics.globalSuccess)
            } catch (t: Throwable) {
                val error = t.dataError()
                mutable.update { if (error == DataError.Network) it.copy(saving = false, offline = true) else it.copy(saving = false, error = ProfileError.Save) }
                haptic(Tokens.Haptics.globalError)
            }
        }
    }

    private fun savePhoto() {
        val file = mutable.value.avatar ?: return
        if (mutable.value.saving) return
        mutable.update { it.copy(saving = true, error = null) }
        viewModelScope.launch {
            try {
                env.backend.setAvatar(file)
            } catch (t: Throwable) {
                val error = t.dataError()
                // Upload failed: the circle returns to empty; "Choose photo" and "Maybe Later" stay.
                mutable.update { if (error == DataError.Network) it.copy(saving = false, offline = true) else it.copy(saving = false, avatar = null, error = ProfileError.Upload) }
                haptic(Tokens.Haptics.globalError)
                return@launch
            }
            mutable.update { it.copy(saving = false, avatar = null) }
            haptic(Tokens.Haptics.globalSuccess)
            navigate(AccountFlow.firstOnboardingStep(env), clearStack = true)
        }
    }
}

@Composable
fun ProfileRoute(nav: NavController) {
    val env = LocalAccountEnvironment.current
    val vm = viewModel { ProfileViewModel(env) }
    val state by vm.state.collectAsStateWithLifecycle()
    CollectEvents(vm.events, nav)
    val picker = rememberLauncherForActivityResult(PhotoImport.single()) { uri -> uri?.let(vm::onPicked) }
    BackHandler(enabled = state.step == ProfileStep.Photo) { vm.backToName() }
    ProfileScreen(
        state,
        vm::onName,
        onPickAvatar = { picker.launch(PhotoImport.imagesOnly) },
        onContinue = vm::submit,
        onRetry = vm::retry,
        onSkip = vm::skipPhoto,
        onBack = vm::backToName,
        onDismissError = vm::dismissError,
    )
}

/**
 * Step 1 (name) and step 2 (photo) are pages of one surface: Retro's onboarding page transition between them (C-33,
 * `duration.global.pageTransition`; Reduce Motion keeps the fades).
 */
@Composable
fun ProfileScreen(
    state: ProfileUiState,
    onName: (String) -> Unit,
    onPickAvatar: () -> Unit,
    onContinue: () -> Unit,
    onRetry: () -> Unit,
    onSkip: () -> Unit = {},
    onBack: () -> Unit = {},
    onDismissError: () -> Unit = {},
    avatarImage: Any? = state.avatar,
    focusOnAppear: Boolean = true,
) {
    OnboardingPages(state.step.ordinal) { page ->
        if (page == ProfileStep.Name.ordinal) {
            NameStep(state, onName, onContinue, onRetry, focusOnAppear)
        } else {
            PhotoStep(state, avatarImage, onPickAvatar, onContinue, onRetry, onSkip, onBack)
        }
    }
    state.error?.let { ErrorAlert(stringResource(it.copy), errorDismissLabel(), onDismissError) }
}

/**
 * Step 1 — the onboarding form ([OnboardingForm], no back: age is confirmed): title / explanation; C-12 name field; the
 * note (text role `caption`, secondary) with its cap top `size.global.sectionHeaderToContent` under the field — or, past
 * 80 characters, the C-12 inline error "Name too long" (text role `meta`, `color.global.destructive`) with Next disabled;
 * C-05 "Next" (busy while the name saves).
 */
@Composable
private fun NameStep(state: ProfileUiState, onName: (String) -> Unit, onContinue: () -> Unit, onRetry: () -> Unit, focusOnAppear: Boolean) {
    val focus = remember { FocusRequester() }
    var field by remember { mutableStateOf(TextFieldValue(state.name, TextRange(state.name.length))) }
    if (field.text != state.name) field = TextFieldValue(state.name, TextRange(state.name.length))
    OnboardingForm(
        title = stringResource(R.string.auth_profile_title),
        explanation = stringResource(R.string.auth_profile_subtitle),
        replacement = if (state.offline) {
            { OfflineBlock(onRetry) }
        } else {
            null
        },
        bottom = { PrimaryButton(stringResource(R.string.auth_profile_continue), onContinue, enabled = state.canContinue || state.saving, loading = state.saving) },
    ) {
        FormTextField(
            value = field,
            onValueChange = { field = it; onName(it.text) },
            placeholder = stringResource(R.string.auth_profile_field_placeholder),
            accessibilityLabel = stringResource(R.string.auth_profile_field_accessibilitylabel),
            keyboardOptions = KeyboardOptions(capitalization = KeyboardCapitalization.Words, imeAction = ImeAction.Next),
            keyboardActions = KeyboardActions(onNext = { onContinue() }),
            autofill = ContentType.PersonFullName,
            enabled = !state.saving,
            error = if (state.tooLong) stringResource(R.string.auth_profile_error_toolong) else null,
            modifier = Modifier.focusRequester(focus),
        )
        if (!state.tooLong) {
            val caption = TextRoles.caption
            Text(
                stringResource(R.string.auth_profile_field_note),
                style = caption,
                color = PageRoles.secondaryText(),
                modifier = Modifier.fillMaxWidth().capTopAt(Tokens.Sizes.globalSectionHeaderToContent, CapTop.height(caption)),
            )
        }
    }
    if (focusOnAppear && !state.offline) LaunchedEffect(Unit) { runCatching { focus.requestFocus() } }
}

/**
 * Step 2 — the onboarding page (keyboard down): back → step 1; title / explanation; the avatar circle
 * `auth.profile.size.avatar` (C-23; empty = `color.global.control` + `icon.global.person` in secondary text,
 * `auth.profile.layout.avatarPicker` empty) centred in the space above the capsule, tappable (same action as the capsule);
 * C-05 "Choose photo" while empty, "Next" once chosen (busy while uploading); `auth.phone.size.capsuleToLink` below (ink),
 * the C-08 link "Maybe Later" / "Edit photo". The chosen photo fades in (`duration.global.fade`).
 */
@Composable
private fun PhotoStep(
    state: ProfileUiState,
    avatarImage: Any?,
    onPickAvatar: () -> Unit,
    onContinue: () -> Unit,
    onRetry: () -> Unit,
    onSkip: () -> Unit,
    onBack: () -> Unit,
) {
    val chosen = avatarImage != null
    val avatarLabel = stringResource(if (chosen) R.string.auth_profile_avatar_changeaccessibilitylabel else R.string.auth_profile_avatar_accessibilitylabel)
    OnboardingForm(
        title = stringResource(R.string.auth_profile_photo_title),
        explanation = stringResource(R.string.auth_profile_photo_subtitle),
        back = HeaderAction(Tokens.Icons.globalBack, stringResource(R.string.auth_code_back_accessibilitylabel)) { onBack() },
        replacement = if (state.offline) {
            { OfflineBlock(onRetry) }
        } else {
            null
        },
        scrollable = false,
        bottom = {
            if (chosen) {
                PrimaryButton(stringResource(R.string.auth_profile_continue), onContinue, enabled = true, loading = state.saving)
            } else {
                PrimaryButton(stringResource(R.string.auth_profile_avatar_add), onPickAvatar)
            }
            TextLink(
                stringResource(if (chosen) R.string.auth_profile_avatar_edit else R.string.auth_profile_photo_skip),
                if (chosen) onPickAvatar else onSkip,
                Modifier.capTopAt(Tokens.Sizes.authPhoneSizeCapsuleToLink, CapTop.height(TextRoles.listTitle)),
                enabled = !state.saving,
            )
        },
    ) {
        Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
            val size = Tokens.Sizes.authProfileSizeAvatar
            Crossfade(targetState = avatarImage, animationSpec = DsMotion.fade(), label = "avatar") { image ->
                Avatar(
                    image,
                    size,
                    Modifier.clip(CircleShape).tapClickable(enabled = !state.saving, onClick = onPickAvatar),
                    fallbackIcon = Tokens.Icons.globalPerson,
                    contentDescription = avatarLabel,
                )
            }
        }
    }
}
