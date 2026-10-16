// Surface: plans.create — make a plan in a group (and edit it). Spec: design/surfaces/plans.create.md.
// Visual reference: Retro's New Album flow as groups.create step B composes it (cover, C-07, C-12, C-05 on a C-29 page sheet;
// references/auto/retro/press/tc-2024-04-journals-1.webp). Mechanics: Apple Invites' create order (title → date and time →
// location → description; references/auto/apple-invites/newsroom/ai-newsroom-2025-02-create-an-event.jpg) and Partiful's
// New Event sheet (free-text place row; references/auto/partiful/frames/pf-apppreview-t7.250.png).
package app.feature.account.plans

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import androidx.activity.compose.BackHandler
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.expandVertically
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.shrinkVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.DatePicker
import androidx.compose.material3.DatePickerDialog
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.SelectableDates
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberDatePickerState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.Immutable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.TextRange
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.input.TextFieldValue
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewModelScope
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.navigation.NavController
import app.data.error.DataError
import app.data.error.StorageFailure
import app.data.model.Plan
import app.designsystem.R
import app.designsystem.generated.Tokens
import app.feature.account.AccountEnvironment
import app.feature.account.LocalAccountEnvironment
import app.feature.account.common.AccountEvent
import app.feature.account.common.AccountViewModel
import app.feature.account.common.BookCover
import app.feature.account.common.CollectEvents
import app.feature.account.common.SheetPage
import app.feature.account.common.dataError
import app.feature.account.groups.TimeDialog
import app.media.PhotoImport
import app.model.PlanRoute
import app.ui.components.Capsule
import app.ui.components.CapsuleStyle
import app.ui.components.FormTextField
import app.ui.components.GroupedPosition
import app.ui.components.GroupedRow
import app.ui.components.GroupedRowSpec
import app.ui.components.GroupedTrailing
import app.ui.components.HeaderAction
import app.ui.components.OutlineCta
import app.ui.components.PrimaryButton
import app.ui.foundation.DsMotion
import app.ui.foundation.PageRoles
import app.ui.foundation.reduceMotion
import app.ui.foundation.tapClickable
import app.ui.system.SystemAlertDialog
import app.ui.text.TextRoles
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.File
import java.time.Instant
import java.time.LocalDate
import java.time.LocalTime
import java.time.ZoneId
import java.time.ZoneOffset
import kotlin.math.min

/** The inline line under the button (`plans.create` → States: error / offline). */
enum class PlanCreateError(val copy: Int) {
    Failed(R.string.plans_create_error_failed),
    Cover(R.string.plans_create_error_cover),
    Offline(R.string.plans_create_offline),
}

@Immutable
data class PlanCreateUiState(
    val groupId: String,
    val editPlanId: String? = null,
    /** The group's time zone: the plan's day and time are the group's (`plans.local_date`). */
    val zone: ZoneId = ZoneId.systemDefault(),
    /** Today in [zone]: the date picker's minimum (`create_plan` refuses an earlier day). */
    val today: LocalDate = LocalDate.now(zone),
    val title: String = "",
    val date: LocalDate? = null,
    val allDay: Boolean = false,
    val time: LocalTime? = null,
    val place: String = "",
    val note: String = "",
    /** A newly picked cover (square JPEG) … */
    val pickedCover: File? = null,
    /** … or the plan's current cover (edit mode): its storage path and signed URL. */
    val currentCoverPath: String? = null,
    val currentCoverUrl: String? = null,
    val working: Boolean = false,
    val error: PlanCreateError? = null,
    /** The form as it was opened (edit: the plan's values), to tell unsaved input. */
    val original: Fields = Fields(),
) {
    @Immutable
    data class Fields(val title: String = "", val date: LocalDate? = null, val allDay: Boolean = false, val time: LocalTime? = null, val place: String = "", val note: String = "")

    val fields: Fields get() = Fields(title, date, allDay, time, place, note)

    /** Plan titles are 1–80 characters (docs/API.md §14.2): past that, "Name too long" (C-12 error). */
    val tooLong: Boolean get() = title.trim().length > MAX_TITLE
    val canSubmit: Boolean get() = !working && title.isNotBlank() && !tooLong && date != null
    val coverImage: Any? get() = pickedCover ?: currentCoverUrl
    val hasUnsavedInput: Boolean get() = fields != original || pickedCover != null

    /** No time chosen = all-day (`plans.create` → Time: "default: none chosen = all-day"). */
    val sendsAllDay: Boolean get() = allDay || time == null

    companion object {
        const val MAX_TITLE = 80
        const val MAX_NOTE = 2048
    }
}

/**
 * `plans.create`: cover (square crop, uploaded first, as group covers) → `create_plan` / `update_plan` → the new plan's page
 * (create) or back (edit). Busy: C-05 busy and the `plans.create.creating` announcement; a failure keeps the sheet with the
 * inline line (`plans.create.error.failed` / `.error.cover` / `plans.create.offline`).
 */
class PlanCreateViewModel(
    private val env: AccountEnvironment,
    private val backend: PlansBackend,
    groupId: String,
    editPlanId: String?,
) : AccountViewModel() {
    private val mutable = MutableStateFlow(PlanCreateUiState(groupId = groupId, editPlanId = editPlanId, zone = env.zone(), today = env.clock.instant().atZone(env.zone()).toLocalDate()))
    val state: StateFlow<PlanCreateUiState> = mutable.asStateFlow()

    init {
        viewModelScope.launch {
            val zone = runCatching { backend.group(groupId) }.getOrNull()?.timeZone?.let { runCatching { ZoneId.of(it) }.getOrNull() }
            if (zone != null) mutable.update { it.copy(zone = zone, today = env.clock.instant().atZone(zone).toLocalDate()) }
            if (editPlanId != null) prefill(editPlanId, zone ?: mutable.value.zone)
        }
    }

    private suspend fun prefill(planId: String, zone: ZoneId) {
        val plan: Plan = runCatching { backend.plan(planId) }.getOrNull() ?: return
        val cover = plan.coverPath?.let { path -> runCatching { backend.signedUrls(listOf(path))[path] }.getOrNull() }
        val fields = PlanCreateUiState.Fields(
            title = plan.title,
            date = plan.localDate,
            allDay = plan.allDay,
            time = if (plan.allDay) null else plan.startsAt.atZone(zone).toLocalTime(),
            place = plan.place.orEmpty(),
            note = plan.note.orEmpty(),
        )
        mutable.update {
            it.copy(
                title = fields.title, date = fields.date, allDay = fields.allDay, time = fields.time, place = fields.place, note = fields.note,
                currentCoverPath = plan.coverPath, currentCoverUrl = cover, original = fields,
            )
        }
    }

    fun onTitle(text: String) = mutable.update { it.copy(title = text, error = null) }
    fun onDate(date: LocalDate) = mutable.update { it.copy(date = date, error = null) }
    fun onAllDay(on: Boolean) = mutable.update { it.copy(allDay = on, error = null) }
    fun onTime(time: LocalTime) = mutable.update { it.copy(time = time, error = null) }
    fun onPlace(text: String) = mutable.update { it.copy(place = text, error = null) }
    fun onNote(text: String) = mutable.update { it.copy(note = text.take(PlanCreateUiState.MAX_NOTE), error = null) }

    /** The picked image as a square JPEG (Partiful stores covers 1:1). */
    fun onCoverPicked(uri: Uri) {
        viewModelScope.launch {
            val file = runCatching { SquareCover.crop(env.images.importJpeg(uri)) }.getOrNull()
            mutable.update { it.copy(pickedCover = file ?: it.pickedCover, error = if (file == null) PlanCreateError.Cover else null) }
        }
    }

    fun submit() {
        val s = mutable.value
        val date = s.date ?: return
        if (!s.canSubmit) return
        mutable.update { it.copy(working = true, error = null) }
        viewModelScope.launch {
            val coverPath = s.pickedCover?.let { file ->
                try {
                    backend.uploadCover(file)
                } catch (t: Throwable) {
                    val error = t.dataError()
                    mutable.update { it.copy(working = false, error = if (error == DataError.Network) PlanCreateError.Offline else PlanCreateError.Cover) }
                    haptic(Tokens.Haptics.globalError)
                    return@launch
                }
            } ?: s.currentCoverPath
            val allDay = s.sendsAllDay
            val startsAt: Instant = date.atTime(if (allDay) LocalTime.MIDNIGHT else s.time ?: LocalTime.MIDNIGHT).atZone(s.zone).toInstant()
            val place = s.place.trim().takeIf { it.isNotEmpty() }
            val note = s.note.takeIf { it.isNotBlank() }
            try {
                val edit = s.editPlanId
                if (edit == null) {
                    val plan = backend.createPlan(s.groupId, s.title.trim(), startsAt, allDay, place, note, coverPath)
                    mutable.update { it.copy(working = false) }
                    // No haptic on send (owner decision 15: creating a plan is a send). The sheet closes onto the plan.
                    navigate(PlanRoute(plan.id, plan.groupId), popCurrent = true)
                } else {
                    backend.updatePlan(edit, s.title.trim(), startsAt, allDay, place, note, coverPath)
                    mutable.update { it.copy(working = false) }
                    emit(AccountEvent.Back)
                }
            } catch (t: Throwable) {
                val error = t.dataError()
                mutable.update {
                    it.copy(
                        working = false,
                        error = when {
                            error == DataError.Network -> PlanCreateError.Offline
                            error is DataError.Storage && error.kind != StorageFailure.Other -> PlanCreateError.Cover
                            else -> PlanCreateError.Failed
                        },
                    )
                }
                haptic(Tokens.Haptics.globalError)
            }
        }
    }
}

/** Square centre crop of a picked JPEG (`plans.create` → cover: "stored as a square crop", Partiful 1:1). */
internal object SquareCover {
    suspend fun crop(source: File): File = withContext(Dispatchers.IO) {
        val bitmap = BitmapFactory.decodeFile(source.path) ?: return@withContext source
        val side = min(bitmap.width, bitmap.height)
        if (bitmap.width == bitmap.height) return@withContext source
        val square = Bitmap.createBitmap(bitmap, (bitmap.width - side) / 2, (bitmap.height - side) / 2, side, side)
        val out = File(source.parentFile, "square-" + source.name)
        out.outputStream().use { square.compress(Bitmap.CompressFormat.JPEG, JPEG_QUALITY, it) }
        if (square !== bitmap) square.recycle()
        bitmap.recycle()
        source.delete()
        out
    }

    /** The importer's quality (the worker's rendition quality, backend/worker/src/media/renditions.ts). */
    private const val JPEG_QUALITY = 85
}

@Composable
fun PlanCreateSheetRoute(nav: NavController, groupId: String, editPlanId: String?) {
    val env = LocalAccountEnvironment.current
    val backend = rememberPlansBackend()
    val vm = viewModel(key = "planCreate:$groupId:$editPlanId") { PlanCreateViewModel(env, backend, groupId, editPlanId) }
    val state by vm.state.collectAsStateWithLifecycle()
    CollectEvents(vm.events, nav)
    var confirmDiscard by remember { mutableStateOf(false) }
    val close = { if (state.hasUnsavedInput && !state.working) confirmDiscard = true else if (!state.working) nav.popBackStack() }
    BackHandler(enabled = state.hasUnsavedInput || state.working) { close() }
    val picker = rememberLauncherForActivityResult(PhotoImport.single()) { uri -> uri?.let(vm::onCoverPicked) }
    PlanCreateScreen(
        state = state,
        actions = PlanCreateActions(
            onClose = close,
            onTitle = vm::onTitle,
            onDate = vm::onDate,
            onAllDay = vm::onAllDay,
            onTime = vm::onTime,
            onPlace = vm::onPlace,
            onNote = vm::onNote,
            onPickCover = { picker.launch(PhotoImport.imagesOnly) },
            onSubmit = vm::submit,
        ),
    )
    if (confirmDiscard) DiscardDialog(onDiscard = { confirmDiscard = false; nav.popBackStack() }, onKeep = { confirmDiscard = false })
}

/** Callbacks of [PlanCreateScreen]. */
class PlanCreateActions(
    val onClose: () -> Unit = {},
    val onTitle: (String) -> Unit = {},
    val onDate: (LocalDate) -> Unit = {},
    val onAllDay: (Boolean) -> Unit = {},
    val onTime: (LocalTime) -> Unit = {},
    val onPlace: (String) -> Unit = {},
    val onNote: (String) -> Unit = {},
    val onPickCover: () -> Unit = {},
    val onSubmit: () -> Unit = {},
)

/** Closing with unsaved input: the native confirm (`plans.create.discard.*`, "Yes, discard" destructive). */
@Composable
internal fun DiscardDialog(onDiscard: () -> Unit, onKeep: () -> Unit) {
    SystemAlertDialog(
        title = stringResource(R.string.plans_create_discard_title),
        text = null,
        confirmLabel = stringResource(R.string.plans_create_discard_confirm),
        onConfirm = onDiscard,
        dismissLabel = stringResource(R.string.plans_create_discard_cancel),
        onDismiss = onKeep,
        destructive = true,
    )
}

/**
 * The create sheet (C-29 page sheet, [SheetPage]: centred `plans.create.title` / `.titleEdit` and the close circle), then
 * in one scroll, Apple Invites' order on Retro's New Album composition:
 * 1. the cover (`groups.screen.size.coverWidth` × `.coverHeight`, `radius.global.thumbnail`, `groups.screen.shadow.cover`;
 *    empty = `color.global.control`) `size.global.titleToContent` under the header, tappable; `groups.screen.size.coverToTitle`
 *    below, C-07 "Add cover image" (or C-06 outline "Edit cover image");
 * 2. the C-12 title field `size.global.titleToContent` below ("Name too long" past 80 characters);
 * 3. `size.global.sectionGap` below, one C-14 group: Date (`icon.global.calendar`, value in the locale's medium date or
 *    "Choose" → M3 date picker from today in the group's time zone), All-day (switch), Time (hidden while All-day is on;
 *    the locale's short time → M3 time picker; shown and hidden with `duration.global.fade`, Reduce Motion: cross-fade only),
 *    Place (`icon.global.location`, inline field — typed text only);
 * 4. `size.global.sectionGap` below, the multi-line C-12 note (grows to 6 lines, then scrolls; up to 2,048 characters);
 * 5. the C-05 capsule "Create Plan" / "Save" pinned `size.global.buttonMarginH` above the keyboard / bottom inset, disabled
 *    until the title and a date are set, busy while saving; a failure's line under it (`meta`, `color.global.destructive`).
 */
@Composable
fun PlanCreateScreen(state: PlanCreateUiState, actions: PlanCreateActions) {
    val editing = state.editPlanId != null
    val focus = LocalFocusManager.current
    var pickingDate by remember { mutableStateOf(false) }
    var pickingTime by remember { mutableStateOf(false) }
    var title by remember { mutableStateOf(TextFieldValue(state.title, TextRange(state.title.length))) }
    if (title.text != state.title) title = TextFieldValue(state.title, TextRange(state.title.length))
    SheetPage(
        title = stringResource(if (editing) R.string.plans_create_titleedit else R.string.plans_create_title),
        close = HeaderAction(Tokens.Icons.globalClose, stringResource(R.string.plans_create_close_accessibilitylabel), actions.onClose),
    ) {
        Column(Modifier.fillMaxSize().windowInsetsPadding(WindowInsets.navigationBars).imePadding()) {
            Column(Modifier.weight(1f).fillMaxWidth().verticalScroll(rememberScrollState()), horizontalAlignment = Alignment.CenterHorizontally) {
                CoverBlock(state, actions.onPickCover)
                FormTextField(
                    value = title,
                    onValueChange = { title = it; actions.onTitle(it.text) },
                    placeholder = stringResource(R.string.plans_create_name_placeholder),
                    accessibilityLabel = stringResource(R.string.plans_create_name_accessibilitylabel),
                    keyboardOptions = KeyboardOptions(capitalization = KeyboardCapitalization.Sentences, imeAction = ImeAction.Next),
                    keyboardActions = KeyboardActions(onNext = { focus.clearFocus() }),
                    enabled = !state.working,
                    error = if (state.tooLong) stringResource(R.string.plans_create_error_toolong) else null,
                    modifier = Modifier.padding(start = Tokens.Sizes.globalScreenMargin, end = Tokens.Sizes.globalScreenMargin, top = Tokens.Sizes.globalTitleToContent),
                )
                DetailRows(state, actions, onPickDate = { focus.clearFocus(); pickingDate = true }, onPickTime = { focus.clearFocus(); pickingTime = true })
                NoteField(state.note, actions.onNote, enabled = !state.working)
            }
            PrimaryButton(
                stringResource(if (editing) R.string.plans_create_save else R.string.plans_create_cta),
                actions.onSubmit,
                enabled = state.canSubmit || state.working,
                loading = state.working,
                modifier = Modifier.padding(
                    start = Tokens.Sizes.globalButtonMarginH,
                    end = Tokens.Sizes.globalButtonMarginH,
                    bottom = if (state.error == null) Tokens.Sizes.globalButtonMarginH else Tokens.Sizes.globalPillGap,
                ),
            )
            state.error?.let { error ->
                Text(
                    stringResource(error.copy),
                    style = TextRoles.meta,
                    color = Tokens.Colors.globalDestructive,
                    modifier = Modifier.fillMaxWidth().padding(start = Tokens.Sizes.globalButtonMarginH, end = Tokens.Sizes.globalButtonMarginH, bottom = Tokens.Sizes.globalButtonMarginH),
                )
            }
        }
    }
    if (pickingDate) PlanDateDialog(state.date ?: state.today, state.today, onCancel = { pickingDate = false }) { pickingDate = false; actions.onDate(it) }
    if (pickingTime) TimeDialog(stringResource(R.string.plans_create_time), state.time, onCancel = { pickingTime = false }) { pickingTime = false; actions.onTime(it) }
    // "Creating…" is announced while the capsule is busy (C-05 keeps its label for TalkBack).
    val view = LocalView.current
    val creating = stringResource(R.string.plans_create_creating)
    LaunchedEffect(state.working) { if (state.working) view.announceForAccessibility(creating) }
}

/** The cover and its capsule (C-07 "Add cover image" / C-06 "Edit cover image"); the system photo picker either way. */
@Composable
private fun CoverBlock(state: PlanCreateUiState, onPick: () -> Unit) {
    val image = state.coverImage
    val label = stringResource(if (image == null) R.string.plans_create_cover_accessibilitylabel else R.string.plans_create_cover_edit)
    Box(Modifier.padding(top = Tokens.Sizes.globalTitleToContent)) {
        BookCover(
            image,
            Tokens.Sizes.groupsScreenSizeCoverWidth,
            Tokens.Sizes.groupsScreenSizeCoverHeight,
            Modifier.tapClickable(enabled = !state.working, onClickLabel = label, onClick = onPick),
            contentDescription = label,
            glyph = null,
        )
    }
    Box(Modifier.padding(top = Tokens.Sizes.groupsScreenSizeCoverToTitle)) {
        if (image == null) {
            OutlineCta(stringResource(R.string.plans_create_cover_add), onPick, enabled = !state.working)
        } else {
            Capsule(stringResource(R.string.plans_create_cover_edit), onPick, style = CapsuleStyle.Outline, enabled = !state.working)
        }
    }
}

/** The C-14 group: Date · All-day · (Time) · Place, in Apple's order. Each row is one element read as label + value. */
@Composable
private fun DetailRows(state: PlanCreateUiState, actions: PlanCreateActions, onPickDate: () -> Unit, onPickTime: () -> Unit) {
    val showTime = !state.allDay
    val reduce = reduceMotion()
    val secondary = PageRoles.secondaryText()
    Column(Modifier.fillMaxWidth().padding(start = Tokens.Sizes.globalScreenMargin, end = Tokens.Sizes.globalScreenMargin, top = Tokens.Sizes.globalSectionGap)) {
        GroupedRow(
            GroupedRowSpec(
                title = stringResource(R.string.plans_create_date),
                trailing = GroupedTrailing.Value(state.date?.let { PlanFormats.dateValue(it) } ?: stringResource(R.string.plans_create_date_none)),
                enabled = !state.working,
                leading = { Icon(Tokens.Icons.globalCalendar, contentDescription = null, tint = secondary, modifier = Modifier.size(Tokens.Sizes.globalIconSmall)) },
                onClick = onPickDate,
            ),
            GroupedPosition.First,
        )
        GroupedRow(
            GroupedRowSpec(title = stringResource(R.string.plans_create_allday), trailing = GroupedTrailing.Toggle(state.allDay, actions.onAllDay), enabled = !state.working),
            GroupedPosition.Middle,
        )
        AnimatedVisibility(
            visible = showTime,
            enter = if (reduce) fadeIn(DsMotion.fade()) else fadeIn(DsMotion.fade()) + expandVertically(DsMotion.fade()),
            exit = if (reduce) fadeOut(DsMotion.fade()) else fadeOut(DsMotion.fade()) + shrinkVertically(DsMotion.fade()),
        ) {
            GroupedRow(
                GroupedRowSpec(
                    title = stringResource(R.string.plans_create_time),
                    trailing = state.time?.let { GroupedTrailing.Value(PlanFormats.timeValue(it)) } ?: GroupedTrailing.None,
                    enabled = !state.working,
                    onClick = onPickTime,
                ),
                GroupedPosition.Middle,
            )
        }
        PlaceRow(state.place, actions.onPlace, enabled = !state.working)
    }
}

/**
 * The Place row: `icon.global.location` and an inline text field (text role `body`, placeholder
 * `plans.create.place.placeholder` in secondary text) — typed text only: no search, no suggestions, no maps. The row's
 * geometry is C-14's ([GroupedRow]: padding `size.global.screenMargin`, icon → text `size.global.cardNameGap`).
 */
@Composable
private fun PlaceRow(place: String, onPlace: (String) -> Unit, enabled: Boolean) {
    val shape = GroupedPosition.Last.shape()
    val secondary = PageRoles.secondaryText()
    val placeholder = stringResource(R.string.plans_create_place_placeholder)
    val style = TextRoles.body.copy(color = if (enabled) Tokens.Colors.globalTextPrimary else Tokens.Colors.globalTextTertiary)
    Row(
        Modifier
            .fillMaxWidth()
            .clip(shape)
            .background(PageRoles.secondarySurface, shape)
            .heightIn(min = Tokens.Sizes.globalMinTouchTargetAndroid)
            .padding(Tokens.Sizes.globalScreenMargin),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(Tokens.Sizes.globalCardNameGap),
    ) {
        Icon(Tokens.Icons.globalLocation, contentDescription = null, tint = secondary, modifier = Modifier.size(Tokens.Sizes.globalIconSmall))
        BasicTextField(
            value = place,
            onValueChange = onPlace,
            enabled = enabled,
            singleLine = true,
            textStyle = style,
            cursorBrush = SolidColor(Tokens.Colors.globalSystemPrimary),
            keyboardOptions = KeyboardOptions(capitalization = KeyboardCapitalization.Words, imeAction = ImeAction.Done),
            modifier = Modifier.weight(1f).semantics { contentDescription = placeholder },
            decorationBox = { inner ->
                Box {
                    if (place.isEmpty()) Text(placeholder, style = style.copy(color = secondary), maxLines = 1)
                    inner()
                }
            },
        )
    }
}

/**
 * The note: the C-12 field look (fill `color.global.control`, `radius.global.field`, at least `size.global.fieldHeight`,
 * text role `placeholder`) as a multi-line field that grows to 6 lines and then scrolls; `size.global.sectionGap` under
 * the details group, inside `size.global.screenMargin`. Text inset: `radius.global.field` at the sides (as C-12) and
 * `size.global.screenMargin` above and below (the C-14 row padding: C-12's inner inset is not measured — Gap). Labelled by
 * its placeholder copy for TalkBack.
 */
@Composable
private fun NoteField(note: String, onNote: (String) -> Unit, enabled: Boolean) {
    val shape = RoundedCornerShape(Tokens.Radii.globalField)
    val inset = Tokens.Radii.globalField
    val placeholder = stringResource(R.string.plans_create_note_placeholder)
    val style = TextRoles.placeholder.copy(color = if (enabled) Tokens.Colors.globalTextPrimary else Tokens.Colors.globalTextTertiary)
    BasicTextField(
        value = note,
        onValueChange = onNote,
        enabled = enabled,
        maxLines = NOTE_MAX_LINES,
        textStyle = style,
        cursorBrush = SolidColor(Tokens.Colors.globalSystemPrimary),
        keyboardOptions = KeyboardOptions(capitalization = KeyboardCapitalization.Sentences),
        modifier = Modifier
            .fillMaxWidth()
            .padding(start = Tokens.Sizes.globalScreenMargin, end = Tokens.Sizes.globalScreenMargin, top = Tokens.Sizes.globalSectionGap)
            .semantics { contentDescription = placeholder },
        decorationBox = { inner ->
            Box(
                Modifier.fillMaxWidth().heightIn(min = Tokens.Sizes.globalFieldHeight).clip(shape).background(Tokens.Colors.globalControl, shape)
                    .padding(horizontal = inset, vertical = Tokens.Sizes.globalScreenMargin),
                contentAlignment = Alignment.CenterStart,
            ) {
                if (note.isEmpty()) Text(placeholder, style = style.copy(color = PageRoles.secondaryText()))
                inner()
            }
        },
    )
}

/**
 * The M3 `DatePickerDialog` (PLATFORM; `plans.create` → Date: "M3 DatePickerDialog"), days before [min] (today in the
 * group's time zone) not selectable. Buttons are the platform's `android.R.string.ok` / `cancel`.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun PlanDateDialog(initial: LocalDate, min: LocalDate, onCancel: () -> Unit, onConfirm: (LocalDate) -> Unit) {
    val minMillis = min.atStartOfDay(ZoneOffset.UTC).toInstant().toEpochMilli()
    val picker = rememberDatePickerState(
        initialSelectedDateMillis = initial.atStartOfDay(ZoneOffset.UTC).toInstant().toEpochMilli(),
        selectableDates = object : SelectableDates {
            override fun isSelectableDate(utcTimeMillis: Long): Boolean = utcTimeMillis >= minMillis
            override fun isSelectableYear(year: Int): Boolean = year >= min.year
        },
    )
    DatePickerDialog(
        onDismissRequest = onCancel,
        confirmButton = {
            TextButton(onClick = {
                val millis = picker.selectedDateMillis
                if (millis != null) onConfirm(Instant.ofEpochMilli(millis).atZone(ZoneOffset.UTC).toLocalDate()) else onCancel()
            }) { Text(stringResource(android.R.string.ok)) }
        },
        dismissButton = { TextButton(onClick = onCancel) { Text(stringResource(android.R.string.cancel)) } },
    ) {
        DatePicker(picker)
    }
}

/** "grows to 6 lines, then scrolls" (`plans.create` → Note). */
private const val NOTE_MAX_LINES = 6
