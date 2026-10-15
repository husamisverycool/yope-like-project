// Surface: widget.android → configure activity (a system surface: Material 3 list).
// References: design/surfaces/widget.android.md (Elements → configure activity); Material 3 lists
// (color.global.system.*, layout.global.system.typography).
package app.feature.capture.widget

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ListItem
import androidx.compose.material3.ListItemDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.style.TextAlign
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import app.data.model.Group
import app.data.offline.DataState
import app.designsystem.R
import app.designsystem.generated.Tokens
import app.feature.capture.data.CaptureDataProvider
import app.ui.system.SystemList
import app.ui.system.SystemScaffold
import app.ui.theme.AppTheme
import app.widget.WidgetConfigureUi
import kotlinx.coroutines.flow.map

/** What the picker shows. */
sealed interface WidgetPickerState {
    data object Loading : WidgetPickerState
    data class Groups(val groups: List<Group>) : WidgetPickerState
    /** No group to choose (none joined, signed out, not configured, or nothing loaded offline). */
    data object Empty : WidgetPickerState

    companion object {
        fun of(result: DataState<List<Group>>): WidgetPickerState {
            val list = result.value
            return when {
                !list.isNullOrEmpty() -> Groups(list)
                result.refreshing -> Loading
                else -> Empty
            }
        }
    }
}

/**
 * The widget's group picker (`widget.home.small.configuration.title`): the member's groups as a
 * Material 3 list; choosing one prepares the widget ([WidgetPrefetch]) and binds it (RESULT_OK).
 */
object CaptureWidgetConfigureUi : WidgetConfigureUi {
    @Composable
    override fun Content(onGroupChosen: (groupId: String) -> Unit, onCancel: () -> Unit) {
        val context = LocalContext.current
        val data = CaptureDataProvider.get(context)
        val state by data.groups().map(WidgetPickerState::of).collectAsStateWithLifecycle(WidgetPickerState.Loading)
        AppTheme {
            WidgetPickerScreen(state) { group ->
                WidgetPrefetch.prepare(context, data, group)
                onGroupChosen(group.id)
            }
        }
    }
}

@Composable
fun WidgetPickerScreen(state: WidgetPickerState, onChoose: (Group) -> Unit) {
    SystemScaffold(
        title = stringResource(R.string.widget_home_small_configuration_title),
        backLabel = null,
        onBack = null,
        modifier = Modifier.testTag("widget.configure"),
    ) { padding ->
        when (state) {
            WidgetPickerState.Loading -> Box(Modifier.fillMaxSize().padding(padding), contentAlignment = Alignment.Center) {
                CircularProgressIndicator()
            }
            WidgetPickerState.Empty -> Box(Modifier.fillMaxSize().padding(padding).padding(Tokens.Sizes.globalScreenMargin), contentAlignment = Alignment.Center) {
                Text(
                    stringResource(R.string.widget_android_configure_empty),
                    style = MaterialTheme.typography.bodyLarge,
                    color = Tokens.Colors.globalSystemOnSurfaceVariant,
                    textAlign = TextAlign.Center,
                )
            }
            is WidgetPickerState.Groups -> SystemList(padding) {
                items(state.groups, key = { it.id }) { group ->
                    ListItem(
                        headlineContent = { Text(group.name) },
                        colors = ListItemDefaults.colors(
                            containerColor = Tokens.Colors.globalSystemSurface,
                            headlineColor = Tokens.Colors.globalSystemOnSurface,
                        ),
                        modifier = Modifier.clickable { onChoose(group) }.testTag("widget.configure.${group.id}"),
                    )
                }
            }
        }
    }
}

