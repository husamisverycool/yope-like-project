package app.feature.memory.birthday

import androidx.activity.compose.BackHandler
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.navigation.NavHostController
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import app.feature.memory.common.CollectEffects
import app.feature.memory.common.MemoryBackend
import app.feature.memory.common.rememberMemoryBackend
import java.time.Clock

/**
 * The request destination: `birthday.request`, then the `birthday.contribute` steps in a nested
 * navigation graph (native push between pages). The view model is the single source of truth for
 * the page; the nested graph follows it so back, Done and errors move the same way.
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
    val nav = rememberNavController()
    LaunchedEffect(state.page) { nav.follow(state.page) }
    NavHost(nav, startDestination = RequestPage.Request.route, modifier = Modifier) {
        composable(RequestPage.Request.route) {
            BackHandler { vm.back() }
            BirthdayRequestScreen(
                state = state.request,
                onAddPhoto = vm::startContribution,
                onRetake = vm::startContribution,
                onRemove = vm::withdraw,
                onRetry = vm::retry,
                onClose = vm::back,
            )
        }
        for (page in listOf(RequestPage.Photo, RequestPage.Message, RequestPage.Done)) {
            composable(page.route) {
                BackHandler { vm.back() }
                val info = (state.request as? RequestState.Ready)?.info ?: return@composable
                BirthdayContributeScreen(
                    page = page,
                    info = info,
                    state = state.contribute,
                    onSelect = vm::select,
                    onUsePhoto = vm::usePhoto,
                    onLine = vm::setLine,
                    onSubmit = vm::submit,
                    onRetake = vm::retake,
                    onDone = vm::done,
                    onBack = vm::back,
                    onRetryPhotos = vm::loadPhotos,
                    onOpenGroup = { onOpenGroup(info.groupId) },
                )
            }
        }
    }
}

/** Moves the nested graph to [page]: pop back to it when it is on the stack, else push it. */
private fun NavHostController.follow(page: RequestPage) {
    if (currentDestination?.route == page.route) return
    val onStack = currentBackStack.value.any { it.destination.route == page.route }
    if (onStack) popBackStack(page.route, inclusive = false)
    else navigate(page.route) {
        // Done replaces the steps: back from it returns to the request.
        if (page == RequestPage.Done) popUpTo(RequestPage.Request.route)
    }
}
