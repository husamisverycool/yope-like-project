package app.feature.account.common

import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.ui.platform.LocalContext
import androidx.lifecycle.ViewModel
import androidx.navigation.NavController
import app.data.error.DataError
import app.data.error.DataException
import app.data.error.ErrorMapping
import app.feature.account.LocalAccountEnvironment
import app.model.AppRoute
import app.ui.haptics.rememberHaptics
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.receiveAsFlow

/** One-off effects a view model asks its screen to perform. */
sealed interface AccountEvent {
    /** Navigate; [clearStack] replaces the whole back stack (sign-up steps, sign-out). */
    data class Navigate(val route: AppRoute, val clearStack: Boolean = false, val popCurrent: Boolean = false) : AccountEvent
    data object Back : AccountEvent
    /** A `haptic` token (`Tokens.Haptics.*`). */
    data class Haptic(val token: Int) : AccountEvent
    /** A confirmation (C-26: the platform toast, `LENGTH_SHORT`) with the copy [copy] (`R.string.*`) formatted with [args]. */
    data class Toast(val copy: Int, val args: List<String> = emptyList()) : AccountEvent
}

/** Base view model: an event channel and the typed error of a failed data call. */
abstract class AccountViewModel : ViewModel() {
    private val channel = Channel<AccountEvent>(Channel.BUFFERED)
    val events: Flow<AccountEvent> = channel.receiveAsFlow()

    protected fun emit(event: AccountEvent) {
        channel.trySend(event)
    }

    protected fun navigate(route: AppRoute, clearStack: Boolean = false, popCurrent: Boolean = false) = emit(AccountEvent.Navigate(route, clearStack, popCurrent))
    protected fun haptic(token: Int) = emit(AccountEvent.Haptic(token))
    protected fun toast(copy: Int, vararg args: String) = emit(AccountEvent.Toast(copy, args.toList()))
}

/** The [DataError] of a thrown data-layer failure (cancellation rethrown). */
fun Throwable.dataError(): DataError {
    if (this is CancellationException) throw this
    return (this as? DataException)?.error ?: ErrorMapping.map(this)
}

/** Performs a view model's events: navigation on [nav], haptics on the current view, toasts in the shell. */
@Composable
fun CollectEvents(events: Flow<AccountEvent>, nav: NavController, extra: (AccountEvent) -> Boolean = { false }) {
    val haptics = rememberHaptics()
    val context = LocalContext.current
    val toasts = LocalAccountEnvironment.current.toasts
    val handle by rememberUpdatedState(extra)
    LaunchedEffect(events) {
        events.collect { event ->
            if (handle(event)) return@collect
            when (event) {
                is AccountEvent.Navigate -> nav.navigateAccount(event)
                AccountEvent.Back -> nav.popBackStack()
                is AccountEvent.Haptic -> haptics.perform(event.token)
                is AccountEvent.Toast -> toasts.show(context.getString(event.copy, *event.args.toTypedArray()))
            }
        }
    }
}

/** Applies a [AccountEvent.Navigate] to the back stack. */
fun NavController.navigateAccount(event: AccountEvent.Navigate) {
    val current = currentBackStackEntry?.destination?.id
    navigate(event.route) {
        launchSingleTop = true
        when {
            event.clearStack -> popUpTo(graph.id) { inclusive = true }
            event.popCurrent && current != null -> popUpTo(current) { inclusive = true }
        }
    }
}
