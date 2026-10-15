// Surface: safety.report — report flow. Spec: design/surfaces/safety.report.md.
// References: https://developer.apple.com/design/human-interface-guidelines/menus (HIG-M), …/action-sheets, …/sheets (HIG-AS / HIG-SH),
// https://m3.material.io/components/bottom-sheets/specs (M3-BS), https://developer.apple.com/app-store/review/guidelines/ (RG 1.2).
package app.feature.account.safety

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.Immutable
import androidx.compose.runtime.SideEffect
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
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
import app.feature.account.blocked.BlockedCopy
import app.feature.account.common.AccountViewModel
import app.feature.account.common.CollectEvents
import app.feature.account.common.dataError
import app.model.AppRoute
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

/** What is reported (`report(p_target_kind, p_target_id, …)`). */
@Immutable
data class ReportTarget(val kind: ReportTargetKind, val id: String, val groupId: String?, val personId: String?)

enum class ReportPhase { Editing, Sending, Sent, Error, NotFound }

@Immutable
data class ReportUiState(
    val target: ReportTarget,
    val details: String = "",
    val phase: ReportPhase = ReportPhase.Editing,
    /** The person (target user, or the author of the post / message): title, sent message, Block. */
    val firstName: String? = null,
    val groupName: String? = null,
)

class ReportViewModel(private val env: AccountEnvironment, target: ReportTarget) : AccountViewModel() {
    private val mutable = MutableStateFlow(ReportUiState(target))
    val state: StateFlow<ReportUiState> = mutable.asStateFlow()

    init {
        viewModelScope.launch {
            val personId = target.personId ?: if (target.kind == ReportTargetKind.Post) runCatching { env.backend.post(target.id)?.authorId }.getOrNull() else null
            val first = personId?.let { id -> runCatching { env.backend.profiles(listOf(id)).firstOrNull()?.firstName }.getOrNull() }
            val group = target.groupId?.takeIf { target.kind == ReportTargetKind.Group }?.let { id -> runCatching { env.backend.group(id)?.name }.getOrNull() }
            mutable.update { it.copy(firstName = first, groupName = group, target = it.target.copy(personId = personId)) }
        }
    }

    fun onDetails(text: String) = mutable.update { it.copy(details = text.take(MAX_DETAILS)) }

    fun submit() {
        val current = mutable.value
        if (current.phase == ReportPhase.Sending) return
        mutable.update { it.copy(phase = ReportPhase.Sending) }
        viewModelScope.launch {
            try {
                // Empty details → the reason is the target kind (spec); reasons list BLOCKED.
                env.backend.report(current.target.kind, current.target.id, current.details.trim().ifEmpty { current.target.kind.wire })
                mutable.update { it.copy(phase = ReportPhase.Sent) }
                haptic(Tokens.Haptics.globalSuccess)
            } catch (t: Throwable) {
                val error = t.dataError()
                val gone = (error as? DataError.Api)?.code == ApiError.TargetNotFound
                mutable.update { it.copy(phase = if (gone) ReportPhase.NotFound else ReportPhase.Error) }
                haptic(Tokens.Haptics.globalError)
            }
        }
    }

    private companion object {
        const val MAX_DETAILS = 1000
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
 * The report sheet as a navigation dialog destination: an M3 ModalBottomSheet
 * (`safety.report.layout.flow` android: container `color.global.system.surfaceContainerLow`, top
 * corners `radius.global.sheet` android 28, M3 drag handle; swipe down = cancel). The destination's
 * own dialog window is undimmed so only the sheet's scrim shows.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ReportRoute(nav: NavController, target: ReportTarget) {
    val env = LocalAccountEnvironment.current
    val vm = viewModel(key = "report:${target.kind}:${target.id}") { ReportViewModel(env, target) }
    val state by vm.state.collectAsStateWithLifecycle()
    CollectEvents(vm.events, nav)
    UndimmedDialogWindow()
    val sheet = rememberModalBottomSheetState(skipPartiallyExpanded = true, confirmValueChange = { state.phase != ReportPhase.Sending })
    ModalBottomSheet(
        onDismissRequest = { nav.popBackStack() },
        sheetState = sheet,
        containerColor = Tokens.Colors.globalSystemSurfaceContainerLow,
        shape = RoundedCornerShape(topStart = Tokens.Layouts.GlobalSheet.android.dp, topEnd = Tokens.Layouts.GlobalSheet.android.dp),
    ) {
        ReportContent(
            state = state,
            onDetails = vm::onDetails,
            onCancel = { nav.popBackStack() },
            onSubmit = vm::submit,
            onDone = { nav.popBackStack() },
            onBlock = { personId ->
                nav.popBackStack()
                nav.navigate(AppRoute.SafetyBlock(personId))
            },
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
private fun reportTitle(state: ReportUiState): String = when (state.target.kind) {
    ReportTargetKind.Post -> stringResource(R.string.safety_report_title_post)
    ReportTargetKind.Message -> stringResource(R.string.safety_report_title_message)
    ReportTargetKind.User -> stringResource(R.string.safety_report_title_user, state.firstName.orEmpty())
    ReportTargetKind.Group -> stringResource(R.string.safety_report_title_group, state.groupName.orEmpty())
}

/**
 * Sheet content: navigation bar (Cancel leading, Report trailing in `color.global.system.error`,
 * enabled at once); title (`titleLarge`, heading); explanation (`bodyMedium`; BLOCKED copy, omitted in
 * release); the reason list is BLOCKED (`safety.report.layout.reasons`, omitted); details (M3
 * OutlinedTextField, ≤ 1000 characters). After submit: "report sent" with Block (person or their
 * content) and Done. Paddings are M3's (`settings.root.size.listItemPaddingH.android`).
 */
@Composable
fun ReportContent(
    state: ReportUiState,
    onDetails: (String) -> Unit,
    onCancel: () -> Unit,
    onSubmit: () -> Unit,
    onDone: () -> Unit,
    onBlock: (String) -> Unit,
) {
    val context = LocalContext.current
    val pad = Tokens.Sizes.settingsRootSizeListItemPaddingHAndroid
    Column(Modifier.fillMaxWidth().navigationBarsPadding().padding(horizontal = pad, vertical = Tokens.Sizes.settingsRootSizeListItemPaddingVAndroid)) {
        when (state.phase) {
            ReportPhase.Sent -> {
                Text(stringResource(R.string.safety_report_sent_title), style = MaterialTheme.typography.titleLarge, color = Tokens.Colors.globalSystemOnSurface, modifier = Modifier.semantics { heading() })
                val message = state.firstName?.takeIf { state.target.kind != ReportTargetKind.Group }
                    ?.let { stringResource(R.string.safety_report_sent_message, it) }
                    ?: stringResource(R.string.safety_report_sent_messagegroup)
                Text(message, style = MaterialTheme.typography.bodyMedium, color = Tokens.Colors.globalSystemOnSurfaceVariant)
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.End) {
                    val person = state.target.personId
                    if (person != null && state.target.kind != ReportTargetKind.Group) {
                        TextButton(onClick = { onBlock(person) }) { Text(stringResource(R.string.safety_report_sent_block), color = Tokens.Colors.globalSystemError) }
                    }
                    TextButton(onClick = onDone) { Text(stringResource(R.string.safety_report_sent_done), color = Tokens.Colors.globalSystemPrimary) }
                }
            }
            ReportPhase.NotFound -> {
                Text(stringResource(R.string.safety_report_error_notfound), style = MaterialTheme.typography.bodyMedium, color = Tokens.Colors.globalSystemOnSurfaceVariant)
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.End) {
                    TextButton(onClick = onDone) { Text(stringResource(R.string.safety_report_sent_done), color = Tokens.Colors.globalSystemPrimary) }
                }
            }
            else -> {
                val sending = state.phase == ReportPhase.Sending
                Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                    TextButton(onClick = onCancel, enabled = !sending) { Text(stringResource(R.string.safety_report_cancel), color = Tokens.Colors.globalSystemPrimary) }
                    Box(Modifier.weight(1f))
                    if (sending) {
                        CircularProgressIndicator(color = Tokens.Colors.globalSystemError)
                    } else {
                        TextButton(onClick = onSubmit) { Text(stringResource(R.string.safety_report_submit), color = Tokens.Colors.globalSystemError) }
                    }
                }
                Text(reportTitle(state), style = MaterialTheme.typography.titleLarge, color = Tokens.Colors.globalSystemOnSurface, modifier = Modifier.semantics { heading() })
                BlockedCopy.reportExplanation(context)?.let { Text(it, style = MaterialTheme.typography.bodyMedium, color = Tokens.Colors.globalSystemOnSurfaceVariant) }
                OutlinedTextField(
                    value = state.details,
                    onValueChange = onDetails,
                    enabled = !sending,
                    placeholder = { Text(stringResource(R.string.safety_report_details_placeholder)) },
                    modifier = Modifier.fillMaxWidth().padding(vertical = Tokens.Sizes.settingsRootSizeListItemPaddingVAndroid),
                )
                if (state.phase == ReportPhase.Error) {
                    Text(stringResource(R.string.safety_report_error_title), style = MaterialTheme.typography.bodyMedium, color = Tokens.Colors.globalSystemError)
                    Text(stringResource(R.string.safety_report_error_detail), style = MaterialTheme.typography.bodyMedium, color = Tokens.Colors.globalSystemOnSurfaceVariant)
                }
            }
        }
    }
}
