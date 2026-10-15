package app.feature.memory

import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.navigation.NavGraphBuilder
import androidx.navigation.NavHostController
import androidx.navigation.compose.composable
import androidx.navigation.toRoute
import app.feature.memory.birthday.BirthdayAddScreen
import app.feature.memory.birthday.BirthdayAddViewModel
import app.feature.memory.birthday.BirthdayRequestDestination
import app.feature.memory.birthday.DateEntryPattern
import app.feature.memory.birthday.TributeDestination
import app.feature.memory.common.CollectEffects
import app.feature.memory.common.MemoryBackend
import app.feature.memory.common.rememberMemoryBackend
import app.feature.memory.onthisday.OnThisDayScreen
import app.feature.memory.onthisday.OnThisDayState
import app.feature.memory.onthisday.OnThisDayViewModel
import app.feature.memory.yearstory.YearStoryDestination
import app.model.AppRoute
import app.model.OnThisDayRoute
import app.ui.nav.emptyDestination
import java.time.Clock

/**
 * Destinations of the memory feature group (surface specs in design/surfaces/):
 * - [OnThisDayRoute] → `onthisday` (the day of one group; entry: `OnThisDayEntry`);
 * - [AppRoute.BirthdayAdd] → `birthday.add` (from the settings row);
 * - [AppRoute.BirthdayContribute] → `birthday.request` then `birthday.contribute` in a nested graph
 *   (push `DeepLink.BirthdayRequest` lands here; entry: `BirthdayRequestEntries`);
 * - [AppRoute.Tribute] → `birthday.tribute` (push `DeepLink.Tribute`);
 * - [AppRoute.YearStory] → `year.story` (deep link `DeepLink.YearStory`; entry: `YearStoryEntry`).
 *
 * [AppRoute.OnThisDay] carries no group id, so it cannot show a day; it stays an empty destination
 * and the day is opened with [OnThisDayRoute].
 */
fun NavGraphBuilder.memoryDestinations(navController: NavHostController) {
    emptyDestination<AppRoute.OnThisDay>()
    composable<OnThisDayRoute> { entry ->
        val route = entry.toRoute<OnThisDayRoute>()
        OnThisDayDestination(route.groupId, onClose = { navController.popBackStack() })
    }
    composable<AppRoute.BirthdayAdd> {
        BirthdayAddDestination(onClose = { navController.popBackStack() })
    }
    composable<AppRoute.BirthdayContribute> { entry ->
        val route = entry.toRoute<AppRoute.BirthdayContribute>()
        BirthdayRequestDestination(
            groupId = route.groupId,
            requestId = route.requestId,
            onClose = { navController.popBackStack() },
            onOpenGroup = { groupId -> navController.navigate(AppRoute.Group(groupId)) },
        )
    }
    composable<AppRoute.Tribute> { entry ->
        val route = entry.toRoute<AppRoute.Tribute>()
        TributeDestination(route.tributeId, onClose = { navController.popBackStack() })
    }
    composable<AppRoute.YearStory> { entry ->
        val route = entry.toRoute<AppRoute.YearStory>()
        YearStoryDestination(route.groupId, route.year, onClose = { navController.popBackStack() })
    }
}

/** Opens the day of [groupId] (for the `groups.screen` entry). */
fun NavHostController.openOnThisDay(groupId: String) = navigate(OnThisDayRoute(groupId))

/** The `onthisday` destination: the day, closing itself when the day is over. */
@Composable
fun OnThisDayDestination(groupId: String, onClose: () -> Unit, backend: MemoryBackend = rememberMemoryBackend(), clock: Clock = Clock.systemUTC()) {
    val vm = viewModel(key = "onthisday/$groupId") { OnThisDayViewModel(groupId, backend, clock) }
    val state by vm.state.collectAsStateWithLifecycle()
    LaunchedEffect(state) { if (state == OnThisDayState.Finished) onClose() }
    OnThisDayScreen(state, vm::next, vm::previous, vm::retry, onClose)
}

/** The `birthday.add` destination. */
@Composable
fun BirthdayAddDestination(onClose: () -> Unit, backend: MemoryBackend = rememberMemoryBackend()) {
    val pattern = remember { DateEntryPattern.forLocale() }
    val vm = viewModel(key = "birthday.add") { BirthdayAddViewModel(backend, pattern) }
    val state by vm.state.collectAsStateWithLifecycle()
    CollectEffects(vm.effects, onClose)
    BirthdayAddScreen(
        state = state,
        pattern = pattern,
        onDigits = vm::setDigits,
        onAdd = vm::add,
        onRemove = vm::remove,
        onLater = vm::later,
        onClose = onClose,
        onDismissToast = vm::dismissToast,
    )
}
