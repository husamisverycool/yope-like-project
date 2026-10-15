package app.ui.nav

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.navigation.NavGraphBuilder
import androidx.navigation.compose.composable
import androidx.navigation.toRoute
import app.model.AppRoute

/** Registers [T] with an empty screen until its feature module builds it. */
inline fun <reified T : AppRoute> NavGraphBuilder.emptyDestination() {
    // The route class is captured here: a reified call inside the composable lambda is not
    // inlined by the Compose compiler and fails at runtime.
    val type = T::class
    composable<T> { entry -> EmptyDestination(entry.toRoute<AppRoute>(type)) }
}

/**
 * A destination whose screen is not built yet. It draws nothing — no token exists for it — and is
 * tagged with its surface id for tests.
 */
@Composable
fun EmptyDestination(route: AppRoute) {
    Box(Modifier.fillMaxSize().testTag(route.surface))
}
