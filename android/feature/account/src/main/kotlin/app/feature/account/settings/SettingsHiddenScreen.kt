// Surface: settings.hidden — Hidden Memories. Spec: design/surfaces/settings.hidden.md.
// References: references/auto/retro/press/tc-2023-07-retro-1b.webp (TC-1B: row with a capsule action),
// references/auto/retro/apk/retro-android-2026.10.1150-strings.txt (APK-S: "Error loading friends. Tap here to try again.",
// empty-state voice), references/auto/retro/lazyweb/retro-lazyweb-20251020-week43-dark.png (H43: C-27 block); the list after
// Timehop's hidden-memory settings with "UNHIDE" (T help/th-help-2024-02-settings-hidden-memory.jpg) and Google Photos' hidden
// dates (support.google.com/photos/answer/9454489). Composition of C-14, C-16, C-06, C-27 as settings.blocked.
package app.feature.account.settings

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.Immutable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewModelScope
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.navigation.NavController
import app.data.model.HiddenMemory
import app.designsystem.R
import app.designsystem.generated.Tokens
import app.feature.account.AccountEnvironment
import app.feature.account.LocalAccountEnvironment
import app.feature.account.common.AccountViewModel
import app.feature.account.common.CollectEvents
import app.feature.account.common.SheetPage
import app.feature.account.common.TapLine
import app.feature.account.common.dataError
import app.feature.account.common.errorDismissLabel
import app.feature.account.common.sheetBottomPadding
import app.feature.memory.common.MemoryFormats
import app.ui.components.Avatar
import app.ui.components.Capsule
import app.ui.components.CapsuleStyle
import app.ui.components.EmptyState
import app.ui.components.GroupedPosition
import app.ui.components.Hairline
import app.ui.components.HeaderAction
import app.ui.foundation.DsMotion
import app.ui.foundation.PageRoles
import app.ui.system.ErrorAlert
import app.ui.text.TextRoles
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import java.time.LocalDate
import java.time.ZoneId

/** One row: a hidden day, or a hidden photo with its signed thumbnail. */
@Immutable
data class HiddenRow(
    val id: String,
    /** The hidden day, or the day the photo was posted (this device's zone: the list spans groups). */
    val date: LocalDate,
    val isDay: Boolean,
    val thumbnailUrl: String? = null,
)

@Immutable
data class SettingsHiddenUiState(
    val rows: List<HiddenRow>? = null,
    /** The list failed to load (or the device is offline): Retro's one tappable line. */
    val error: Boolean = false,
    val online: Boolean = true,
    /** An unhide failed (the row stays): the message-only alert `settings.hidden.unhideError`. */
    val unhideFailed: Boolean = false,
)

class SettingsHiddenViewModel(private val env: AccountEnvironment, private val zone: ZoneId = ZoneId.systemDefault()) : AccountViewModel() {
    private val mutable = MutableStateFlow(SettingsHiddenUiState())
    val state: StateFlow<SettingsHiddenUiState> = mutable.asStateFlow()

    init {
        viewModelScope.launch {
            env.backend.online.collect { online ->
                val wasOffline = !mutable.value.online
                mutable.update { it.copy(online = online) }
                // Back online after a failed read: try again.
                if (online && wasOffline && mutable.value.rows == null) load()
            }
        }
        load()
    }

    /** `my_hidden_memories`, newest hide first; thumbnails signed in one call (a failed signing leaves the placeholder). */
    fun load() {
        mutable.update { it.copy(error = false) }
        viewModelScope.launch {
            try {
                val hidden = env.backend.hiddenMemories()
                val urls = runCatching { env.backend.signedUrls(hidden.mapNotNull { it.thumbPath }) }.getOrDefault(emptyMap())
                mutable.update { it.copy(rows = hidden.mapNotNull { row(it, urls) }) }
            } catch (t: Throwable) {
                t.dataError()
                mutable.update { it.copy(error = true) }
            }
        }
    }

    private fun row(memory: HiddenMemory, urls: Map<String, String>): HiddenRow? {
        val day = memory.day
        if (day != null) return HiddenRow(memory.id, day, isDay = true)
        val taken = memory.takenAt ?: return null
        return HiddenRow(memory.id, taken.atZone(zone).toLocalDate(), isDay = false, thumbnailUrl = memory.thumbPath?.let(urls::get))
    }

    fun dismissError() = mutable.update { it.copy(unhideFailed = false) }

    /** `unhide_memory`: no confirmation (it only shows a memory again); the row leaves at once, restored on failure. */
    fun unhide(row: HiddenRow) {
        val before = mutable.value.rows
        mutable.update { it.copy(rows = before?.filterNot { r -> r.id == row.id }) }
        viewModelScope.launch {
            try {
                env.backend.unhideMemory(row.id)
                haptic(Tokens.Haptics.globalSuccess)
            } catch (t: Throwable) {
                t.dataError()
                mutable.update { it.copy(rows = before, unhideFailed = true) }
                haptic(Tokens.Haptics.globalError)
            }
        }
    }
}

@Composable
fun SettingsHiddenRoute(nav: NavController) {
    val env = LocalAccountEnvironment.current
    val vm = viewModel { SettingsHiddenViewModel(env) }
    val state by vm.state.collectAsStateWithLifecycle()
    CollectEvents(vm.events, nav)
    SettingsHiddenScreen(state, onBack = { nav.popBackStack() }, onUnhide = vm::unhide, onRetry = vm::load, onDismissError = vm::dismissError)
}

/**
 * Pushed inside the Settings sheet (back + centred "Hidden Memories"): one C-14 group of rows (C-16: a hidden photo's
 * thumbnail `size.global.avatarPicker`, corners `radius.global.thumbnail`, or for a hidden day the C-23 circle with
 * `icon.global.calendar`; the date `listTitle` as `layout.onthisday.dateFormat`, "Every photo from this day" `listSubtitle`
 * under a day; trailing C-06 outline capsule "Unhide"), rows at least `settings.root.size.rowHeight`, hairlines between; an
 * unhidden row fades out (`duration.global.fade`). Loading: one row with the platform indicator; empty: the C-27 block
 * centred (glyph `icon.global.hide`, no action); error / offline: Retro's one tappable line, centred. No count anywhere.
 */
@Composable
fun SettingsHiddenScreen(
    state: SettingsHiddenUiState,
    onBack: () -> Unit,
    onUnhide: (HiddenRow) -> Unit,
    onRetry: () -> Unit,
    onDismissError: () -> Unit = {},
) {
    SheetPage(
        title = stringResource(R.string.settings_hidden_title),
        back = HeaderAction(Tokens.Icons.globalBack, stringResource(R.string.groups_screen_back_accessibilitylabel), onBack),
    ) {
        val rows = state.rows
        when {
            rows == null && (state.error || !state.online) -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                TapLine(stringResource(R.string.settings_hidden_error), onRetry)
            }
            rows == null -> Box(Modifier.padding(top = Tokens.Sizes.globalSectionHeaderToContent)) { LoadingGroup() }
            rows.isEmpty() -> Box(Modifier.fillMaxSize().padding(bottom = sheetBottomPadding()), contentAlignment = Alignment.Center) {
                EmptyState(
                    title = stringResource(R.string.settings_hidden_empty_title),
                    detail = stringResource(R.string.settings_hidden_empty_message),
                    icon = Tokens.Icons.globalHide,
                )
            }
            else -> LazyColumn(
                Modifier.fillMaxSize(),
                contentPadding = PaddingValues(start = Tokens.Sizes.globalScreenMargin, end = Tokens.Sizes.globalScreenMargin, top = Tokens.Sizes.globalSectionHeaderToContent, bottom = sheetBottomPadding()),
            ) {
                itemsIndexed(rows, key = { _, r -> r.id }) { index, row ->
                    HiddenMemoryRow(row, GroupedPosition.of(index, rows.size), state.online, onUnhide, Modifier.animateItem(fadeInSpec = DsMotion.fade(), fadeOutSpec = DsMotion.fade()))
                }
            }
        }
    }
    if (state.unhideFailed) ErrorAlert(stringResource(R.string.settings_hidden_unhideerror), errorDismissLabel(), onDismissError)
}

@Composable
private fun HiddenMemoryRow(row: HiddenRow, position: GroupedPosition, online: Boolean, onUnhide: (HiddenRow) -> Unit, modifier: Modifier) {
    val shape = position.shape()
    val unhide = stringResource(R.string.settings_hidden_unhide)
    val title = MemoryFormats.memoryDate(row.date)
    // "Unhide Jul 22, 2022": the capsule's label composed with the date for TalkBack.
    val spoken = "$unhide $title"
    Column(modifier.fillMaxWidth().clip(shape).background(PageRoles.secondarySurface, shape)) {
        Box(Modifier.fillMaxWidth().heightIn(min = Tokens.Sizes.settingsRootSizeRowHeight).padding(vertical = Tokens.Sizes.globalSectionHeaderToContent), contentAlignment = Alignment.CenterStart) {
            Row(Modifier.fillMaxWidth().padding(horizontal = Tokens.Sizes.globalScreenMargin), verticalAlignment = Alignment.CenterVertically) {
                if (row.isDay) {
                    Avatar(null, Tokens.Sizes.globalAvatarPicker, fallbackIcon = Tokens.Icons.globalCalendar, shape = CircleShape)
                } else {
                    Avatar(row.thumbnailUrl, Tokens.Sizes.globalAvatarPicker, fallbackIcon = Tokens.Icons.globalHide, shape = RoundedCornerShape(Tokens.Radii.globalThumbnail))
                }
                Spacer(Modifier.width(Tokens.Sizes.globalRowThumbGap))
                Column(Modifier.weight(1f)) {
                    Text(title, style = TextRoles.listTitle, color = Tokens.Colors.globalTextPrimary)
                    if (row.isDay) Text(stringResource(R.string.settings_hidden_day_detail), style = TextRoles.listSubtitle, color = PageRoles.secondaryText())
                }
                Box(Modifier.padding(start = Tokens.Sizes.globalPillGap)) {
                    Capsule(
                        unhide,
                        { onUnhide(row) },
                        Modifier.semantics { contentDescription = spoken },
                        style = CapsuleStyle.Outline,
                        enabled = online,
                    )
                }
            }
        }
        if (position.dividerBelow) Hairline()
    }
}
