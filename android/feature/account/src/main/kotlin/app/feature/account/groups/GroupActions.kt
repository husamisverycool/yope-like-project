package app.feature.account.groups

import app.feature.account.AccountEnvironment
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

/** Writes shared by groups.screen and groups.settings. */
object GroupActions {
    /**
     * `leave_group`, optimistic: the group leaves groups.list at once (the caller pops to it) and the
     * call finishes in the app scope; if the server refuses, the group comes back and [onFailed] runs.
     */
    fun leave(env: AccountEnvironment, groupId: String, onFailed: () -> Unit = {}) {
        env.optimistic.leftGroups.update { it + groupId }
        env.appScope.launch {
            try {
                env.backend.leaveGroup(groupId)
                GroupsListViewModel.Details.byGroup.remove(groupId)
            } catch (e: kotlinx.coroutines.CancellationException) {
                throw e
            } catch (_: Exception) {
                env.optimistic.leftGroups.update { it - groupId }
                onFailed()
            }
        }
    }
}
