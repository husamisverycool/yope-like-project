// Surface: groups.create — create group: name, cover, type (and edit mode). Spec: design/surfaces/groups.create.md.
// References: references/auto/yope/frames/a-itsmthuyope-7644974799302823175-t45.23-new-group-empty.png (NG1),
// -t49.23-new-group-selected-create.png (NG2), a-yrrah-7452976839846382855-t3.73-create-new-group-empty-2024.png (C24),
// references/auto/yope/web/a-bi-2025-create-group-composite.jpg (BI), -t51.73-group-profile-add-20-pics.png (GP), -t50.60-loading-hud.png (HUD).
package app.feature.account.groups

import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawing
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.TextRange
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.TextFieldValue
import androidx.compose.ui.text.style.TextAlign
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewModelScope
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.navigation.NavController
import app.data.error.DataError
import app.data.error.StorageFailure
import app.data.model.GroupKind
import app.data.repo.CoverChange
import app.designsystem.R
import app.designsystem.dsTextStyle
import app.designsystem.generated.Tokens
import app.feature.account.AccountEnvironment
import app.feature.account.LocalAccountEnvironment
import app.feature.account.common.AccountViewModel
import app.feature.account.common.CollectEvents
import app.feature.account.common.dataError
import app.media.PhotoImport
import app.model.AppRoute
import app.ui.components.FormTextField
import app.ui.components.HeaderCircleButton
import app.ui.components.HeaderCircleFill
import app.ui.components.HudOverlay
import app.ui.components.PrimaryButton
import app.ui.components.SegmentedControl
import app.ui.text.TextRoles
import coil3.compose.AsyncImage
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import java.io.File

/** groups.create failures: presentation BLOCKED (`auth.phone.layout.inlineError`), kept in state. */
enum class CreateError(val copy: Int) {
    Failed(R.string.groups_create_error_failed),
    SaveFailed(R.string.groups_create_error_savefailed),
    Cover(R.string.groups_create_error_cover),
    Offline(R.string.groups_create_offline),
}

data class GroupCreateUiState(
    val editGroupId: String? = null,
    val name: String = "",
    /** Default selection friends (first segment; enum order of `group_kind`). */
    val kind: GroupKind = GroupKind.Friends,
    /** A newly picked cover (local JPEG) … */
    val pickedCover: File? = null,
    /** … or the group's current cover (edit mode). */
    val currentCoverUrl: String? = null,
    val coverRemoved: Boolean = false,
    val working: Boolean = false,
    val error: CreateError? = null,
) {
    val canSubmit: Boolean get() = !working && name.isNotBlank()
    val coverImage: Any? get() = pickedCover ?: currentCoverUrl.takeUnless { coverRemoved }
}

class GroupCreateViewModel(private val env: AccountEnvironment, editGroupId: String?) : AccountViewModel() {
    private val mutable = MutableStateFlow(GroupCreateUiState(editGroupId = editGroupId))
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

    fun onName(text: String) = mutable.update { it.copy(name = text.take(MAX_NAME), error = null) }
    fun onKind(kind: GroupKind) = mutable.update { it.copy(kind = kind) }

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

    private companion object {
        /** `create_group` trims the name to 1–80 characters (docs/API.md §6.1). */
        const val MAX_NAME = 80
    }
}

@Composable
fun GroupCreateRoute(nav: NavController, editGroupId: String? = null) {
    val env = LocalAccountEnvironment.current
    val vm = viewModel(key = "groupCreate:$editGroupId") { GroupCreateViewModel(env, editGroupId) }
    val state by vm.state.collectAsStateWithLifecycle()
    CollectEvents(vm.events, nav)
    val picker = rememberLauncherForActivityResult(PhotoImport.single()) { uri -> uri?.let(vm::onCoverPicked) }
    GroupCreateScreen(
        state = state,
        onClose = { nav.popBackStack() },
        onName = vm::onName,
        onKind = vm::onKind,
        onPickCover = { picker.launch(PhotoImport.imagesOnly) },
        onSubmit = vm::submit,
    )
}

/** The four types in `group_kind` enum order with their labels (`groups.create.type.*`). */
@Composable
internal fun kindLabels(): List<Pair<GroupKind, String>> = listOf(
    GroupKind.Friends to stringResource(R.string.groups_create_type_friends),
    GroupKind.Family to stringResource(R.string.groups_create_type_family),
    GroupKind.Roommates to stringResource(R.string.groups_create_type_roommates),
    GroupKind.Custom to stringResource(R.string.groups_create_type_custom),
)

@Composable
fun GroupCreateScreen(
    state: GroupCreateUiState,
    onClose: () -> Unit,
    onName: (String) -> Unit,
    onKind: (GroupKind) -> Unit,
    onPickCover: () -> Unit,
    onSubmit: () -> Unit,
    coverImage: Any? = state.coverImage,
) {
    val focus = LocalFocusManager.current
    var field by remember { mutableStateOf(TextFieldValue(state.name, TextRange(state.name.length))) }
    if (field.text != state.name) field = TextFieldValue(state.name, TextRange(state.name.length))
    val kinds = kindLabels()
    val editing = state.editGroupId != null
    Box(Modifier.fillMaxSize().background(Tokens.Colors.globalBackgroundDeep)) {
        Column(Modifier.fillMaxSize().windowInsetsPadding(WindowInsets.safeDrawing).imePadding()) {
            // 1. Header row: ✕ leading, title centred on the circle's row.
            Box(Modifier.fillMaxWidth().padding(horizontal = Tokens.Sizes.globalHeaderInset), contentAlignment = Alignment.Center) {
                HeaderCircleButton(
                    Tokens.Icons.globalClose,
                    stringResource(R.string.groups_create_close_accessibilitylabel),
                    onClose,
                    fill = HeaderCircleFill.OnDeep,
                    modifier = Modifier.align(Alignment.CenterStart),
                )
                Text(
                    stringResource(if (editing) R.string.groups_create_titleedit else R.string.groups_create_title),
                    style = dsTextStyle(Tokens.FontSizes.groupsCreateFontSizeTitle, Tokens.FontWeights.groupsCreateFontWeightTitle),
                    color = Tokens.Colors.globalTextPrimary,
                    modifier = Modifier.semantics { heading() },
                )
            }
            Column(
                Modifier.weight(1f).fillMaxWidth().verticalScroll(rememberScrollState()),
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                Spacer(Modifier.height(Tokens.Sizes.groupsCreateSizeTitleToContent))
                CoverPlaceholder(coverImage, onPickCover)
                Spacer(Modifier.height(Tokens.Sizes.groupsCreateSizeMediaToField))
                FormTextField(
                    value = field,
                    onValueChange = { field = it; onName(it.text) },
                    placeholder = stringResource(R.string.groups_create_name_placeholder),
                    accessibilityLabel = stringResource(R.string.groups_create_name_accessibilitylabel),
                    keyboardOptions = KeyboardOptions(imeAction = ImeAction.Done),
                    keyboardActions = KeyboardActions(onDone = { focus.clearFocus() }),
                    modifier = Modifier.padding(horizontal = Tokens.Sizes.globalButtonMarginH),
                )
                Spacer(Modifier.height(Tokens.Sizes.groupsCreateSizeMediaToField))
                Text(
                    stringResource(R.string.groups_create_type_label),
                    style = TextRoles.sectionLabel,
                    color = Tokens.Colors.globalTextSecondary,
                    textAlign = TextAlign.Start,
                    modifier = Modifier.fillMaxWidth().padding(horizontal = Tokens.Sizes.globalButtonMarginH),
                )
                SegmentedControl(
                    options = kinds.map { it.second },
                    selectedIndex = kinds.indexOfFirst { it.first == state.kind }.coerceAtLeast(0),
                    onSelect = { onKind(kinds[it].first) },
                    modifier = Modifier.padding(horizontal = Tokens.Sizes.globalButtonMarginH),
                )
            }
            PrimaryButton(
                stringResource(if (editing) R.string.groups_create_save else R.string.groups_create_cta),
                onSubmit,
                enabled = state.canSubmit,
                modifier = Modifier.padding(horizontal = Tokens.Sizes.globalButtonMarginH),
            )
            Spacer(Modifier.height(Tokens.Sizes.groupsCreateSizeFieldToButton))
        }
        HudOverlay(state.working, stringResource(R.string.groups_create_hud_loading))
    }
}

/**
 * Cover placeholder `groups.create.size.cover.width` × `.cover.height` (narrower screens keep the
 * same aspect), corners `groups.create.radius.cover`, fill `groups.create.color.cover`, camera glyph
 * `icon.global.camera` at `groups.create.size.coverGlyph` in `color.global.textPrimary`; a chosen photo
 * fills it (`scaledToFill`) and hides the glyph. Tap → system photo picker.
 */
@Composable
private fun CoverPlaceholder(image: Any?, onPick: () -> Unit) {
    val shape = RoundedCornerShape(Tokens.Radii.groupsCreateRadiusCover)
    val label = stringResource(if (image == null) R.string.groups_create_cover_accessibilitylabel else R.string.groups_create_cover_changeaccessibilitylabel)
    Box(
        Modifier
            .widthIn(max = Tokens.Sizes.groupsCreateSizeCoverWidth)
            .fillMaxWidth()
            .aspectRatio(Tokens.Sizes.groupsCreateSizeCoverWidth / Tokens.Sizes.groupsCreateSizeCoverHeight)
            .clip(shape)
            .background(Tokens.Colors.groupsCreateColorCover, shape)
            .clickable(role = Role.Button, onClick = onPick)
            .semantics { contentDescription = label },
        contentAlignment = Alignment.Center,
    ) {
        if (image != null) {
            when (image) {
                is androidx.compose.ui.graphics.painter.Painter -> androidx.compose.foundation.Image(image, null, contentScale = ContentScale.Crop, modifier = Modifier.fillMaxSize())
                else -> AsyncImage(model = image, contentDescription = null, contentScale = ContentScale.Crop, modifier = Modifier.fillMaxSize())
            }
        } else {
            Icon(Tokens.Icons.globalCamera, contentDescription = null, tint = Tokens.Colors.globalTextPrimary, modifier = Modifier.size(Tokens.Sizes.groupsCreateSizeCoverGlyph))
        }
    }
}
