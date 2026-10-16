// Surface: safety.report — report a post, message, person or group. Spec: design/surfaces/safety.report.md.
// References: references/auto/retro/apk/retro-android-2026.10.1150-strings.txt (APK-S: media_viewer_report_*, profile_report_*:
// titles, reason lists, "Next Steps", "Submitted!", "Report Post" / "Report Profile"), references/auto/retro/press/
// tc-2025-12-rewind-panels.png (TC-RWP: native menu, destructive red); HIG action sheets; M3 bottom sheets; App Review 1.2.
package app.feature.account.safety

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.Immutable
import androidx.compose.runtime.SideEffect
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.DialogWindowProvider
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewModelScope
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.navigation.NavController
import app.data.error.ApiError
import app.data.error.DataError
import app.data.model.ReportTargetKind
import app.designsystem.R
import app.designsystem.generated.Tokens
import app.feature.account.AccountEnvironment
import app.feature.account.LocalAccountEnvironment
import app.feature.account.common.AccountEvent
import app.feature.account.common.AccountViewModel
import app.feature.account.common.CollectEvents
import app.feature.account.common.dataError
import app.feature.account.common.errorDismissLabel
import app.feature.account.groups.GroupActions
import app.feature.account.groups.LeaveGroupDialog
import app.model.AppRoute
import app.ui.foundation.tapClickable
import app.ui.system.SystemAlertDialog
import app.ui.text.TextRoles
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

/** What is reported (`report(p_target_kind, p_target_id, …)`). */
@Immutable
data class ReportTarget(val kind: ReportTargetKind, val id: String, val groupId: String?, val personId: String?)

/**
 * The flow (`safety.report.layout.flow`): the reasons sheet → a reason files the report and the sheet closes at once
 * (Sending runs with no sheet) → "Submitted!" (toast) or an alert; "I don't like it" opens Next Steps (Leave / Block).
 */
enum class ReportPhase { Reasons, NextSteps, Sending, ConfirmLeave, Error, NotFound }

/** A reason (`safety.report.layout.reasons`): its copy and the English text sent as `p_reason` (the token's own value). */
@Immutable
data class ReportReason(val copy: Int, val wire: String, val dontLike: Boolean = false)

@Immutable
data class ReportUiState(
    val target: ReportTarget,
    val phase: ReportPhase = ReportPhase.Reasons,
    /** The person (target user, or the author of the post / message): "Block {first_name}". */
    val firstName: String? = null,
    val groupName: String? = null,
)

/** Retro's reason lists per target kind (MERGE RA-12), copy order = the token's order. */
object ReportReasons {
    private const val SEPARATOR = " · " // provenance-ok: list separator inside the safety.report.layout.reasons token value

    fun of(kind: ReportTargetKind): List<ReportReason> {
        val layout = Tokens.Layouts.SafetyReportLayoutReasons
        return when (kind) {
            ReportTargetKind.Post, ReportTargetKind.Message -> {
                val wire = (if (kind == ReportTargetKind.Post) layout.post else layout.message).split(SEPARATOR)
                listOf(
                    ReportReason(R.string.safety_report_reason_dontlike, wire[0], dontLike = true),
                    ReportReason(R.string.safety_report_reason_nudity, wire[1]),
                    ReportReason(R.string.safety_report_reason_other, wire[2]),
                )
            }
            ReportTargetKind.User, ReportTargetKind.Group -> {
                val wire = (if (kind == ReportTargetKind.User) layout.user else layout.group).split(SEPARATOR)
                listOf(
                    ReportReason(R.string.safety_report_reason_impersonation, wire[0]),
                    ReportReason(R.string.safety_report_reason_inappropriate, wire[1]),
                    ReportReason(R.string.safety_report_reason_other, wire[2]),
                )
            }
        }
    }
}

class ReportViewModel(private val env: AccountEnvironment, target: ReportTarget) : AccountViewModel() {
    private val mutable = MutableStateFlow(ReportUiState(target))
    val state: StateFlow<ReportUiState> = mutable.asStateFlow()

    init {
        viewModelScope.launch {
            val personId = target.personId ?: if (target.kind == ReportTargetKind.Post) runCatching { env.backend.post(target.id)?.authorId }.getOrNull() else null
            val first = personId?.let { id -> runCatching { env.backend.profiles(listOf(id)).firstOrNull()?.firstName }.getOrNull() }
            val group = target.groupId?.let { id -> runCatching { env.backend.group(id)?.name }.getOrNull() }
            mutable.update { it.copy(firstName = first, groupName = group, target = it.target.copy(personId = personId)) }
        }
    }

    /** A reason chosen: "I don't like it" → Next Steps (nothing filed); any other → `report(…)` with the sheet closed. */
    fun choose(reason: ReportReason) {
        if (reason.dontLike) {
            mutable.update { it.copy(phase = ReportPhase.NextSteps) }
            return
        }
        val target = mutable.value.target
        mutable.update { it.copy(phase = ReportPhase.Sending) }
        viewModelScope.launch {
            try {
                env.backend.report(target.kind, target.id, reason.wire)
                haptic(Tokens.Haptics.globalSuccess)
                toast(R.string.safety_report_sent_title)
                emit(AccountEvent.Back)
            } catch (t: Throwable) {
                val error = t.dataError()
                val gone = (error as? DataError.Api)?.code == ApiError.TargetNotFound
                mutable.update { it.copy(phase = if (gone) ReportPhase.NotFound else ReportPhase.Error) }
                haptic(Tokens.Haptics.globalError)
            }
        }
    }

    fun askLeave() = mutable.update { it.copy(phase = ReportPhase.ConfirmLeave) }

    /** Next Steps → Leave: `leave_group` (optimistic, GroupActions) → "Left group" → home. */
    fun leave() {
        val groupId = mutable.value.target.groupId ?: return
        haptic(Tokens.Haptics.globalWarning)
        GroupActions.leave(env, groupId)
        toast(R.string.safety_report_left)
        navigate(AppRoute.GroupsList, clearStack = true)
    }
}

/** A chat message target (`chat.thread` long-press menu). */
fun reportTarget(route: app.model.SafetyReportMessageRoute): ReportTarget =
    ReportTarget(ReportTargetKind.Message, route.messageId, route.groupId, route.authorId)

/** Builds the target from the route (post, person or group). */
fun reportTarget(route: AppRoute.SafetyReport): ReportTarget? = when {
    route.postId != null -> ReportTarget(ReportTargetKind.Post, route.postId!!, route.groupId, null)
    route.userId != null -> ReportTarget(ReportTargetKind.User, route.userId!!, route.groupId, route.userId)
    route.groupId != null -> ReportTarget(ReportTargetKind.Group, route.groupId!!, route.groupId, null)
    else -> null
}

/**
 * The report flow as a navigation dialog destination (its own window undimmed so the sheet's scrim is the only one): the
 * M3 ModalBottomSheet (`safety.report.layout.flow` android — container `color.global.system.surfaceContainerLow`, top
 * corners `radius.global.sheet` android) while choosing; nothing while the report is sent; the platform alerts after.
 */
@Composable
fun ReportRoute(nav: NavController, target: ReportTarget) {
    val env = LocalAccountEnvironment.current
    val vm = viewModel(key = "report:${target.kind}:${target.id}") { ReportViewModel(env, target) }
    val state by vm.state.collectAsStateWithLifecycle()
    CollectEvents(vm.events, nav)
    UndimmedDialogWindow()
    ReportFlow(
        state = state,
        onClose = { nav.popBackStack() },
        onReason = vm::choose,
        onAskLeave = vm::askLeave,
        onLeave = vm::leave,
        onBlock = { personId ->
            nav.popBackStack()
            nav.navigate(AppRoute.SafetyBlock(personId))
        },
    )
}

/**
 * What the flow draws per phase: the M3 ModalBottomSheet with [ReportContent] while choosing; nothing while sending; the
 * leave confirmation, or the platform alerts after.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ReportFlow(
    state: ReportUiState,
    onClose: () -> Unit,
    onReason: (ReportReason) -> Unit,
    onAskLeave: () -> Unit,
    onLeave: () -> Unit,
    onBlock: (String) -> Unit,
) {
    when (state.phase) {
        ReportPhase.Reasons, ReportPhase.NextSteps -> {
            val corner = Tokens.Layouts.GlobalSheet.android.dp
            ModalBottomSheet(
                onDismissRequest = onClose,
                sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true),
                containerColor = Tokens.Colors.globalSystemSurfaceContainerLow,
                shape = RoundedCornerShape(topStart = corner, topEnd = corner),
            ) {
                ReportContent(state = state, onReason = onReason, onCancel = onClose, onLeave = onAskLeave, onBlock = onBlock)
            }
        }
        ReportPhase.Sending -> Unit
        ReportPhase.ConfirmLeave -> LeaveGroupDialog(
            groupName = state.groupName.orEmpty(),
            last = false,
            onConfirm = onLeave,
            onDismiss = onClose,
        )
        ReportPhase.Error -> SystemAlertDialog(
            title = stringResource(R.string.safety_report_error_title),
            text = stringResource(R.string.safety_report_error_detail),
            confirmLabel = errorDismissLabel(),
            onConfirm = onClose,
            dismissLabel = null,
            onDismiss = onClose,
            dismissible = false,
        )
        ReportPhase.NotFound -> SystemAlertDialog(
            title = null,
            text = stringResource(R.string.safety_report_error_notfound),
            confirmLabel = errorDismissLabel(),
            onConfirm = onClose,
            dismissLabel = null,
            onDismiss = onClose,
            dismissible = false,
        )
    }
}

/** Removes the navigation dialog's own dim so a sheet or alert inside it draws the only scrim. */
@Composable
internal fun UndimmedDialogWindow() {
    val view = LocalView.current
    SideEffect { (view.parent as? DialogWindowProvider)?.window?.setDimAmount(0f) }
}

@Composable
private fun reportTitle(kind: ReportTargetKind): String = when (kind) {
    ReportTargetKind.Post -> stringResource(R.string.safety_report_title_post)
    ReportTargetKind.Message -> stringResource(R.string.safety_report_title_message)
    ReportTargetKind.User -> stringResource(R.string.safety_report_title_user)
    ReportTargetKind.Group -> stringResource(R.string.safety_report_title_group)
}

/**
 * The sheet's content (M3's action-sheet form): the title (text role `sheetTitle`, centred, header trait), one row per
 * reason (text role `body`, at least `settings.root.size.rowHeight`, `size.global.screenMargin` padding), "Cancel" last.
 * Next Steps: "Leave the group" and "Block {first_name}" in `color.global.destructive`, then "Cancel".
 */
@Composable
fun ReportContent(
    state: ReportUiState,
    onReason: (ReportReason) -> Unit,
    onCancel: () -> Unit,
    onLeave: () -> Unit,
    onBlock: (String) -> Unit,
) {
    Column(Modifier.fillMaxWidth().windowInsetsPadding(WindowInsets.navigationBars).padding(bottom = Tokens.Sizes.globalScreenMargin)) {
        if (state.phase == ReportPhase.NextSteps) {
            SheetTitle(stringResource(R.string.safety_report_nextsteps_title))
            if (state.target.groupId != null) Choice(stringResource(R.string.safety_report_nextsteps_leave), Tokens.Colors.globalDestructive, onLeave)
            val person = state.target.personId
            val name = state.firstName
            if (person != null && name != null) Choice(stringResource(R.string.safety_report_nextsteps_block, name), Tokens.Colors.globalDestructive) { onBlock(person) }
        } else {
            SheetTitle(reportTitle(state.target.kind))
            ReportReasons.of(state.target.kind).forEach { reason ->
                Choice(stringResource(reason.copy), Tokens.Colors.globalTextPrimary) { onReason(reason) }
            }
        }
        Choice(stringResource(R.string.safety_report_cancel), Tokens.Colors.globalTextPrimary, onCancel)
    }
}

@Composable
private fun SheetTitle(text: String) {
    Text(
        text,
        style = TextRoles.sheetTitle,
        color = Tokens.Colors.globalTextPrimary,
        textAlign = TextAlign.Center,
        modifier = Modifier
            .fillMaxWidth()
            .padding(start = Tokens.Sizes.globalScreenMargin, end = Tokens.Sizes.globalScreenMargin, bottom = Tokens.Sizes.globalScreenMargin)
            .semantics { heading() },
    )
}

@Composable
private fun Choice(text: String, color: Color, onClick: () -> Unit) {
    Box(
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
