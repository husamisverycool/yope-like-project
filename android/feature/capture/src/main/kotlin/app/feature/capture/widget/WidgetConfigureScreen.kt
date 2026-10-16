// Surface: widget.android → configure activity: the group picker the launcher opens when the widget is placed (and on
// reconfigure, or a tap on a "not set up" widget). Retro page on `color.global.background.android`: C-29 centred
// title, C-16 rows (group cover + name) between C-32 hairlines, single choice (no "Done").
// References: design/surfaces/widget.android.md (Elements → configure activity); references/auto/retro/apk/
// retro-android-2026.10.1150-strings.txt `app_widget_configuration_*` (configuration title pattern).
package app.feature.capture.widget

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawing
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.produceState
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import app.data.error.DataError
import app.data.model.Group
import app.data.offline.DataState
import app.designsystem.R
import app.designsystem.generated.Tokens
import app.feature.capture.data.CaptureDataProvider
import app.ui.components.Avatar
import app.ui.components.EmptyState
import app.ui.components.EmptyStateFill
import app.ui.components.Hairline
import app.ui.components.LoadingState
import app.ui.foundation.PageRoles
import app.ui.foundation.tapClickable
import app.ui.system.SheetHeader
import app.ui.text.TextRoles
import app.ui.theme.AppTheme
import app.widget.WidgetConfigureUi
import kotlinx.coroutines.flow.map

/** What the picker shows (`widget.android` → States → configure). */
sealed interface WidgetPickerState {
    data object Loading : WidgetPickerState
    data class Groups(val groups: List<Group>) : WidgetPickerState
    /** No group to choose (none joined, signed out, not configured). */
    data object Empty : WidgetPickerState
    /** Nothing cached and the load failed. */
    data object Error : WidgetPickerState

    companion object {
        fun of(result: DataState<List<Group>>): WidgetPickerState {
            val list = result.value
            return when {
                !list.isNullOrEmpty() -> Groups(list)
                result.refreshing -> Loading
                list == null && result.error != null && result.error != DataError.NotSignedIn && result.error != DataError.NotConfigured -> Error
                else -> Empty
            }
        }
    }
}

/**
 * The widget's group picker (`widget.home.small.configuration.title`): choosing a group prepares the widget
 * ([WidgetPrefetch]) and binds it (RESULT_OK). Follows the system appearance.
 */
object CaptureWidgetConfigureUi : WidgetConfigureUi {
    @Composable
    override fun Content(onGroupChosen: (groupId: String) -> Unit, onCancel: () -> Unit) {
        val context = LocalContext.current
        val data = CaptureDataProvider.get(context)
        val state by data.groups().map(WidgetPickerState::of).collectAsStateWithLifecycle(WidgetPickerState.Loading)
        val groups = (state as? WidgetPickerState.Groups)?.groups.orEmpty()
        val covers by produceState<Map<String, Any?>>(emptyMap(), groups.map { it.id }) {
            val paths = groups.mapNotNull { g -> g.coverPath?.let { g.id to it } }
            if (paths.isNotEmpty()) {
                val urls = runCatching { data.signedUrls(paths.map { it.second }) }.getOrDefault(emptyMap())
                value = paths.mapNotNull { (id, path) -> urls[path]?.let { id to it } }.toMap()
            }
        }
        AppTheme {
            WidgetPickerScreen(state, covers) { group ->
                WidgetPrefetch.prepare(context, data, group)
                onGroupChosen(group.id)
            }
        }
    }
}

/**
 * The picker page (`color.global.background.android`): C-29 centred title (`sheetTitle`), then the groups as C-16
 * rows — cover in a `size.global.avatarPicker` circle (no cover: `icon.global.group`), the name in text role
 * `listTitle` (`color.global.textPrimary`) `size.global.rowThumbGap` after it — with C-32 hairlines between them.
 * Loading: C-28 indicator; empty: C-27 with `widget.android.configure.empty`; error: the `camera.sendto.error.generic`
 * line. A row tap plays `haptic.global.tap` and finishes.
 */
@Composable
fun WidgetPickerScreen(state: WidgetPickerState, covers: Map<String, Any?> = emptyMap(), onChoose: (Group) -> Unit) {
    Column(
        Modifier
            .fillMaxSize()
            .background(PageRoles.page)
            .windowInsetsPadding(WindowInsets.safeDrawing)
            .testTag("widget.configure"),
    ) {
        SheetHeader(stringResource(R.string.widget_home_small_configuration_title))
        when (state) {
            WidgetPickerState.Loading -> LoadingState(stringResource(R.string.global_a11y_loading))
            WidgetPickerState.Empty -> EmptyStateFill {
                EmptyState(title = null, detail = stringResource(R.string.widget_android_configure_empty), icon = Tokens.Icons.globalGroup)
            }
            WidgetPickerState.Error -> EmptyStateFill {
                EmptyState(title = null, detail = stringResource(R.string.camera_sendto_error_generic))
            }
            is WidgetPickerState.Groups -> LazyColumn(Modifier.fillMaxSize()) {
                itemsIndexed(state.groups, key = { _, g -> g.id }) { index, group ->
                    if (index > 0) Hairline(Modifier.padding(horizontal = Tokens.Sizes.globalScreenMargin))
                    GroupRow(group, covers[group.id]) { onChoose(group) }
                }
            }
        }
    }
}

/** One C-16 row: cover + name, padded `camera.sendto.layout.recipientRow.padding` (Retro's grouped-list 16) above and below. */
@Composable
private fun GroupRow(group: Group, cover: Any?, onClick: () -> Unit) {
    Row(
        Modifier
            .fillMaxWidth()
            .tapClickable(onClick = onClick)
            .semantics(mergeDescendants = true) {}
            .padding(horizontal = Tokens.Sizes.globalScreenMargin, vertical = Dp(Tokens.Layouts.CameraSendtoLayoutRecipientRow.padding))
            .testTag("widget.configure.${group.id}"),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Avatar(cover, Tokens.Sizes.globalAvatarPicker, fallbackIcon = Tokens.Icons.globalGroup)
        Spacer(Modifier.width(Tokens.Sizes.globalRowThumbGap))
        Text(group.name, style = TextRoles.listTitle, color = Tokens.Colors.globalTextPrimary, maxLines = 1, overflow = TextOverflow.Ellipsis)
    }
}
