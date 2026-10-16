package app.feature.memory.birthday

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.navigation.NavHostController
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import app.designsystem.generated.Tokens
import app.feature.memory.common.CollectEffects
import app.feature.memory.common.LightSystemBarIcons
import app.feature.memory.common.MemoryBackend
import app.feature.memory.common.rememberMemoryBackend
import app.ui.foundation.PageRoles
import java.time.Clock

/**
 * The request destination: `birthday.request` (full screen), and over it the `birthday.contribute` page sheet
 * (C-29: the platform `ModalBottomSheet`, fully expanded) holding a nested navigation graph — step 1 (choose a
 * photo), step 2 (the composer) — with native push between them, and the "Add a Message" modal as a second sheet
 * over step 2. The view model is the single source of truth for the page; the nested graph follows it so Back, Next
 * and errors move the same way.
 */
@Composable
fun BirthdayRequestDestination(
    groupId: String,
    requestId: String,
    onClose: () -> Unit,
    onOpenGroup: (groupId: String) -> Unit,
    backend: MemoryBackend = rememberMemoryBackend(),
    clock: Clock = Clock.systemUTC(),
) {
    val vm = viewModel(key = "birthday.request/$requestId") { BirthdayRequestViewModel(groupId, requestId, backend, clock) }
    val state by vm.state.collectAsStateWithLifecycle()
    CollectEffects(vm.effects, onClose)
    LightSystemBarIcons()
    BackHandler { vm.back() }
    BirthdayRequestScreen(
        state = state.request,
        actions = RequestActions(
            onAddPhoto = vm::startContribution,
            onChangePhoto = vm::startContribution,
            onRemove = vm::withdraw,
            onRetry = vm::retry,
            onClose = onClose,
            onToastShown = vm::toastShown,
        ),
        toast = state.toast,
    )
    val info = (state.request as? RequestState.Ready)?.info
    if (state.page != RequestPage.Request && info != null) {
        ContributeSheet(
            state = state,
            info = info,
            onDismiss = vm::dismissSheet,
            onSelect = vm::select,
            onNext = vm::usePhoto,
            onBackToPhotos = vm::back,
            onRetryPhotos = vm::loadPhotos,
            onOpenGroup = { onOpenGroup(info.groupId) },
            onEditMessage = vm::editMessage,
            onSubmit = vm::submit,
        )
        if (state.contribute.editing) MessageSheet(state.contribute.line, vm::setLine, vm::doneEditing)
    }
}

/** The contribute page sheet: step 1 follows the appearance, step 2 is dark (its container follows the step). */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun ContributeSheet(
    state: BirthdayFlowState,
    info: RequestInfo,
    onDismiss: () -> Unit,
    onSelect: (String) -> Unit,
    onNext: () -> Unit,
    onBackToPhotos: () -> Unit,
    onRetryPhotos: () -> Unit,
    onOpenGroup: () -> Unit,
    onEditMessage: () -> Unit,
    onSubmit: () -> Unit,
) {
    val corner = Tokens.Layouts.GlobalSheet.android.dp
    val composer = state.page == RequestPage.Message
    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true),
        shape = RoundedCornerShape(topStart = corner, topEnd = corner),
        containerColor = if (composer) Tokens.Colors.globalBackgroundDeep else PageRoles.page,
        contentColor = Tokens.Colors.globalTextPrimary,
    ) {
        val nav = rememberNavController()
        LaunchedEffect(state.page) { nav.follow(state.page) }
        NavHost(nav, startDestination = RequestPage.Photo.route, modifier = Modifier.fillMaxSize()) {
            composable(RequestPage.Photo.route) {
                ChoosePhotoStep(info, state.contribute, onSelect, onNext, onDismiss, onRetryPhotos, onOpenGroup)
            }
            composable(RequestPage.Message.route) {
                ComposerStep(info, state.contribute, onBack = onBackToPhotos, onClose = onDismiss, onEditMessage = onEditMessage, onSubmit = onSubmit)
            }
        }
    }
}

/** The "Add a Message" modal: a second page sheet over the composer, following the appearance. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun MessageSheet(line: String, onLine: (String) -> Unit, onDone: () -> Unit) {
    val corner = Tokens.Layouts.GlobalSheet.android.dp
    ModalBottomSheet(
        onDismissRequest = onDone,
        sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true),
        shape = RoundedCornerShape(topStart = corner, topEnd = corner),
        containerColor = PageRoles.page,
        contentColor = Tokens.Colors.globalTextPrimary,
    ) {
        MessageModal(line, onLine, onDone)
    }
}

/** Moves the nested graph to [page]: pop back to it when it is on the stack, else push it. */
private fun NavHostController.follow(page: RequestPage) {
    if (page == RequestPage.Request) return
    if (currentDestination?.route == page.route) return
    val onStack = currentBackStack.value.any { it.destination.route == page.route }
    if (onStack) popBackStack(page.route, inclusive = false) else navigate(page.route)
}
