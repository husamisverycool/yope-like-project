package app.feature.account

import app.feature.account.common.AccountEvent
import app.feature.account.common.AccountViewModel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.launch
import kotlinx.coroutines.test.TestDispatcher
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.setMain
import org.junit.rules.TestWatcher
import org.junit.runner.Description

/** Runs view models on a test dispatcher (viewModelScope uses Dispatchers.Main). */
@OptIn(ExperimentalCoroutinesApi::class)
class MainDispatcherRule(val dispatcher: TestDispatcher = UnconfinedTestDispatcher()) : TestWatcher() {
    override fun starting(description: Description) = Dispatchers.setMain(dispatcher)
    override fun finished(description: Description) = Dispatchers.resetMain()
}

/** Collects a view model's events into a list for assertions. */
fun AccountViewModel.recordEvents(scope: CoroutineScope): MutableList<AccountEvent> {
    val out = mutableListOf<AccountEvent>()
    scope.launch { events.collect { out += it } }
    return out
}

fun List<AccountEvent>.navigations() = filterIsInstance<AccountEvent.Navigate>()
fun List<AccountEvent>.haptics() = filterIsInstance<AccountEvent.Haptic>().map { it.token }
