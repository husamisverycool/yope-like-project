// Surface: groups.create — create a group: A. type (Retro's templates), B. cover and name; edit mode. Spec:
// design/surfaces/groups.create.md. References: references/auto/retro/press/jeddacp-2024-05-home-profile-journals.png (JED phone 3:
// template rows with a Fill "Create" capsule), references/auto/retro/press/tc-2024-04-journals-1.webp (TC-J1 phone 3: book cover
// 173.5 × 246 with its drop shadow), references/auto/retro/video/ig-DJXvmqRv2_N-referrals-sheet-f042-059.png (VID-SET: sheet header),
// references/auto/retro/apk/retro-android-2026.10.1150-strings.txt (APK-S: New Album flow strings). Composition of C-29 sheet header,
// C-15 template rows, C-24 cover, C-07, C-12, C-05 in Retro's New Album order.
package app.feature.account.groups

import android.net.Uri
import androidx.activity.compose.BackHandler
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.paddingFrom
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.layout.FirstBaseline
import androidx.compose.ui.layout.LastBaseline
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.TextRange
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.input.TextFieldValue
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewModelScope
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.navigation.NavController
import app.data.error.DataError
import app.data.error.StorageFailure
import app.data.model.GroupKind
import app.data.repo.CoverChange
import app.designsystem.R
import app.designsystem.generated.Tokens
import app.feature.account.AccountEnvironment
import app.feature.account.LocalAccountEnvironment
import app.feature.account.common.AccountViewModel
import app.feature.account.common.BookCover
import app.feature.account.common.CollectEvents
import app.feature.account.common.SheetPage
import app.feature.account.common.dataError
import app.feature.account.common.errorDismissLabel
import app.feature.account.common.sheetBottomPadding
import app.media.PhotoImport
import app.model.AppRoute
import app.ui.components.Capsule
import app.ui.components.CapsuleStyle
import app.ui.components.FormTextField
import app.ui.components.HeaderAction
import app.ui.components.OutlineCta
import app.ui.components.PrimaryButton
import app.ui.foundation.DsMotion
import app.ui.foundation.tapClickable
import app.ui.system.ErrorAlert
import app.ui.text.TextRoles
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import java.io.File

/** groups.create failures, shown as the alert of `auth.phone.layout.inlineError` (message = the error sentence, one OK). */
enum class CreateError(val copy: Int) {
    Failed(R.string.groups_create_error_failed),
    SaveFailed(R.string.groups_create_error_savefailed),
    Cover(R.string.groups_create_error_cover),
    Offline(R.string.groups_create_offline),
}

/** The two steps of the create sheet: A. the group kind (Retro's templates), B. cover and name. */
enum class CreateStep { Type, Details }

data class GroupCreateUiState(
    val editGroupId: String? = null,
    val step: CreateStep = CreateStep.Type,
    /** Opened with the kind already chosen (a template row) or in edit mode: step B has no back chevron. */
    val kindPreset: Boolean = false,
    val name: String = "",
    val kind: GroupKind = GroupKind.Friends,
    /** A newly picked cover (local JPEG) … */
    val pickedCover: File? = null,
    /** … or the group's current cover (edit mode). */
    val currentCoverUrl: String? = null,
    val coverRemoved: Boolean = false,
    val working: Boolean = false,
    val error: CreateError? = null,
) {
    /** `create_group` trims the name to 1–80 characters (docs/API.md §6.1): past that, "Name too long" (C-12 error). */
    val tooLong: Boolean get() = name.trim().length > MAX_NAME
    val canSubmit: Boolean get() = !working && name.isNotBlank() && !tooLong
    val coverImage: Any? get() = pickedCover ?: currentCoverUrl.takeUnless { coverRemoved }

    companion object {
        const val MAX_NAME = 80
    }
}

class GroupCreateViewModel(private val env: AccountEnvironment, editGroupId: String?, presetKind: GroupKind? = null) : AccountViewModel() {
    private val mutable = MutableStateFlow(
        GroupCreateUiState(
            editGroupId = editGroupId,
            step = if (editGroupId != null || presetKind != null) CreateStep.Details else CreateStep.Type,
            kindPreset = editGroupId != null || presetKind != null,
            kind = presetKind ?: GroupKind.Friends,
        ),
    )
    val state: StateFlow<GroupCreateUiState> = mutable.asStateFlow()

    init {
        if (editGroupId != null) {
            viewModelScope.launch {
                val group = runCatching { env.backend.group(editGroupId) }.getOrNull() ?: return@launch
                val cover = group.coverPath?.let { path -> runCatching { env.backend.signedUrls(listOf(path))[path] }.getOrNull() }
                mutable.update { it.copy(name = group.name, kind = group.kind, currentCoverUrl = cover) }
            }
        }
    }

    fun dismissError() = mutable.update { it.copy(error = null) }

    fun onName(text: String) = mutable.update { it.copy(name = text, error = null) }

    /** A template chosen on step A: that kind, then step B (`haptic.global.select`, a choice among options). */
    fun onKind(kind: GroupKind) {
        mutable.update { it.copy(kind = kind, step = CreateStep.Details) }
        haptic(Tokens.Haptics.globalSelect)
    }

    /** Step B's back chevron → step A (name and cover kept). */
    fun backToType() = mutable.update { if (it.working || it.kindPreset) it else it.copy(step = CreateStep.Type) }

    fun onCoverPicked(uri: Uri) {
        viewModelScope.launch {
            val file = runCatching { env.images.importJpeg(uri) }.getOrNull()
            mutable.update { it.copy(pickedCover = file, error = if (file == null) CreateError.Cover else null) }
        }
    }

    fun submit() {
        val current = mutable.value
        if (!current.canSubmit) return
        mutable.update { it.copy(working = true, error = null) }
        viewModelScope.launch {
            val coverPath: String? = current.pickedCover?.let { file ->
                try {
                    env.backend.uploadCover(file)
                } catch (t: Throwable) {
                    val error = t.dataError()
                    // The cover returns to the placeholder; the person can retry or go on without it.
                    mutable.update { it.copy(working = false, pickedCover = null, error = if (error == DataError.Network) CreateError.Offline else CreateError.Cover) }
                    haptic(Tokens.Haptics.globalError)
                    return@launch
                }
            }
            try {
                val edit = current.editGroupId
                if (edit == null) {
                    val group = env.backend.createGroup(current.name.trim(), current.kind, env.zone().id, coverPath)
                    mutable.update { it.copy(working = false) }
                    haptic(Tokens.Haptics.globalSuccess)
                    // Push to the new group; the sheet closes.
                    navigate(AppRoute.Group(group.id), popCurrent = true)
                } else {
                    val cover = when {
                        coverPath != null -> CoverChange.Set(coverPath)
                        current.coverRemoved -> CoverChange.Remove
                        else -> CoverChange.Keep
                    }
                    env.backend.updateGroup(edit, current.name.trim(), current.kind, cover)
                    mutable.update { it.copy(working = false) }
                    haptic(Tokens.Haptics.globalSuccess)
                    emit(app.feature.account.common.AccountEvent.Back)
                }
            } catch (t: Throwable) {
                val error = t.dataError()
                mutable.update {
                    it.copy(
                        working = false,
                        error = when {
                            error == DataError.Network -> CreateError.Offline
                            error is DataError.Storage && error.kind != StorageFailure.Other -> CreateError.Cover
                            current.editGroupId != null -> CreateError.SaveFailed
                            else -> CreateError.Failed
                        },
                    )
                }
                haptic(Tokens.Haptics.globalError)
            }
        }
    }
}

@Composable
fun GroupCreateRoute(nav: NavController, editGroupId: String? = null, presetKind: GroupKind? = null) {
    val env = LocalAccountEnvironment.current
    val vm = viewModel(key = "groupCreate:$editGroupId:$presetKind") { GroupCreateViewModel(env, editGroupId, presetKind) }
    val state by vm.state.collectAsStateWithLifecycle()
    CollectEvents(vm.events, nav)
    val picker = rememberLauncherForActivityResult(PhotoImport.single()) { uri -> uri?.let(vm::onCoverPicked) }
    BackHandler(enabled = state.step == CreateStep.Details && !state.kindPreset) { vm.backToType() }
    GroupCreateScreen(
        state = state,
        onClose = { nav.popBackStack() },
        onName = vm::onName,
        onKind = vm::onKind,
        onPickCover = { picker.launch(PhotoImport.imagesOnly) },
        onSubmit = vm::submit,
        onBack = vm::backToType,
        onDismissError = vm::dismissError,
    )
}

/**
 * The create sheet (C-29 page sheet, [SheetPage]): centred title (`groups.create.title` / `.titleEdit`) and the close
 * circle; on step B a leading back glyph (unless the kind came with the sheet). Steps change with the house fade
 * (the native in-sheet push is not reproduced; Reduce Motion: the fade stays).
 */
@Composable
fun GroupCreateScreen(
    state: GroupCreateUiState,
    onClose: () -> Unit,
    onName: (String) -> Unit,
    onKind: (GroupKind) -> Unit,
    onPickCover: () -> Unit,
    onSubmit: () -> Unit,
    onBack: () -> Unit = {},
    coverImage: Any? = state.coverImage,
    onDismissError: () -> Unit = {},
) {
    val editing = state.editGroupId != null
    val showBack = state.step == CreateStep.Details && !state.kindPreset
    SheetPage(
        title = stringResource(if (editing) R.string.groups_create_titleedit else R.string.groups_create_title),
        close = HeaderAction(Tokens.Icons.globalClose, stringResource(R.string.groups_create_close_accessibilitylabel), onClose),
        back = if (showBack) HeaderAction(Tokens.Icons.globalBack, stringResource(R.string.groups_create_back_accessibilitylabel), onBack) else null,
    ) {
        AnimatedContent(
            targetState = state.step,
            transitionSpec = { DsMotion.fadeIn togetherWith DsMotion.fadeOut },
            label = "createStep",
        ) { step ->
            when (step) {
                CreateStep.Type -> TypeStep(onKind)
                CreateStep.Details -> DetailsStep(state, coverImage, onName, onPickCover, onSubmit)
            }
        }
    }
    state.error?.let { ErrorAlert(stringResource(it.copy), errorDismissLabel(), onDismissError) }
    // "Creating…" is announced while the capsule is busy (C-05 keeps its label for TalkBack).
    val view = LocalView.current
    val creating = stringResource(R.string.groups_create_creating)
    LaunchedEffect(state.working) { if (state.working) view.announceForAccessibility(creating) }
}

/**
 * Step A: the question (`font.global.display` text role `displayMedium`) at the margin, its first baseline
 * `size.global.titleToContent` under the header; `size.global.titleToContent` below its baseline, the four templates
 * (C-15 geometry, `size.global.listGap` apart; the row and its fill capsule "Create" choose the kind).
 */
@Composable
private fun TypeStep(onKind: (GroupKind) -> Unit) {
    LazyColumn(Modifier.fillMaxSize(), contentPadding = PaddingValues(bottom = sheetBottomPadding())) {
        item(key = "question") {
            Text(
                stringResource(R.string.groups_create_type_label),
                style = TextRoles.displayMedium,
                color = Tokens.Colors.globalTextPrimary,
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = Tokens.Sizes.globalScreenMargin)
                    .paddingFrom(FirstBaseline, before = Tokens.Sizes.globalTitleToContent)
                    .paddingFrom(LastBaseline, after = Tokens.Sizes.globalTitleToContent)
                    .semantics { heading() },
            )
        }
        itemsIndexed(GroupKind.entries, key = { _, kind -> kind.wire }) { index, kind ->
            TemplateRow(kind, onKind, Modifier.padding(top = if (index == 0) 0.dp else Tokens.Sizes.globalListGap))
        }
    }
}

/**
 * Step B: the cover (C-24, `groups.screen.size.coverWidth` × `.coverHeight`, `radius.global.thumbnail`,
 * `groups.screen.shadow.cover`; empty = `color.global.control`), centred `size.global.titleToContent` under the header,
 * tappable; `groups.screen.size.coverToTitle` below, the C-07 outline CTA "Add cover image" (or the C-06 outline capsule
 * "Edit cover image" once chosen), centred; `size.global.titleToContent` below, the C-12 name field (C-12 error "Name too
 * long" past 80 characters); the C-05 capsule "Create Group" / "Save" pinned `size.global.buttonMarginH` above the
 * keyboard / bottom safe area (disabled while the name is empty; busy while creating — fields disabled).
 */
@Composable
private fun DetailsStep(
    state: GroupCreateUiState,
    coverImage: Any?,
    onName: (String) -> Unit,
    onPickCover: () -> Unit,
    onSubmit: () -> Unit,
) {
    val focus = LocalFocusManager.current
    var field by remember { mutableStateOf(TextFieldValue(state.name, TextRange(state.name.length))) }
    if (field.text != state.name) field = TextFieldValue(state.name, TextRange(state.name.length))
    val editing = state.editGroupId != null
    Column(Modifier.fillMaxSize().windowInsetsPadding(WindowInsets.navigationBars).imePadding()) {
        Column(Modifier.weight(1f).fillMaxWidth().verticalScroll(rememberScrollState()), horizontalAlignment = Alignment.CenterHorizontally) {
            val coverLabel = stringResource(if (coverImage == null) R.string.groups_create_cover_accessibilitylabel else R.string.groups_create_cover_changeaccessibilitylabel)
            Box(Modifier.padding(top = Tokens.Sizes.globalTitleToContent)) {
                BookCover(
                    coverImage,
                    Tokens.Sizes.groupsScreenSizeCoverWidth,
                    Tokens.Sizes.groupsScreenSizeCoverHeight,
                    Modifier.tapClickable(enabled = !state.working, onClickLabel = coverLabel, onClick = onPickCover),
                    contentDescription = coverLabel,
                    glyph = null,
                )
            }
            Box(Modifier.padding(top = Tokens.Sizes.groupsScreenSizeCoverToTitle)) {
                if (coverImage == null) {
                    OutlineCta(stringResource(R.string.groups_create_cover_add), onPickCover, enabled = !state.working)
                } else {
                    Capsule(stringResource(R.string.groups_create_cover_edit), onPickCover, style = CapsuleStyle.Outline, enabled = !state.working)
                }
            }
            FormTextField(
                value = field,
                onValueChange = { field = it; onName(it.text) },
                placeholder = stringResource(R.string.groups_create_name_placeholder),
                accessibilityLabel = stringResource(R.string.groups_create_name_accessibilitylabel),
                keyboardOptions = KeyboardOptions(capitalization = KeyboardCapitalization.Sentences, imeAction = ImeAction.Done),
                keyboardActions = KeyboardActions(onDone = { focus.clearFocus() }),
                enabled = !state.working,
                error = if (state.tooLong) stringResource(R.string.groups_create_error_toolong) else null,
                modifier = Modifier.padding(start = Tokens.Sizes.globalScreenMargin, end = Tokens.Sizes.globalScreenMargin, top = Tokens.Sizes.globalTitleToContent),
            )
        }
        PrimaryButton(
            stringResource(if (editing) R.string.groups_create_save else R.string.groups_create_cta),
            onSubmit,
            enabled = state.canSubmit || state.working,
            loading = state.working,
            modifier = Modifier.padding(start = Tokens.Sizes.globalButtonMarginH, end = Tokens.Sizes.globalButtonMarginH, bottom = Tokens.Sizes.globalButtonMarginH),
        )
    }
}
