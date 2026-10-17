// Surface: widget.android → configure activity: the picker the launcher opens when a widget is placed (and on
// reconfigure, or a tap on a "not set up" widget). Retro page on `color.global.background.android`: C-29 centred
// title, C-16 rows between C-32 hairlines, single choice (no "Done"), one thing per page (Retro's widget configuration):
// the group (first row All Groups, Retro's "All Friends" — widget.home.small.layout.allGroups) or the person
// (widget.friend: "See photos from…", avatar + name), then the style (widget.styles: "Select Style", C-25 premium pill).
// References: design/surfaces/widget.android.md (Elements → configure activity), widget.friend.md, widget.styles.md;
// references/auto/retro/apk/retro-android-2026.10.1150-strings.txt `app_widget_configuration_*`,
// `app_widget_config_screen_title_friend_picker`, `app_widget_config_screen_friend_picker_item_all_friends`,
// `recap_select_style_title`, `app_widget_config_media_type_*` (option title + subtitle rows).
package app.feature.capture.widget

import android.content.Context
import androidx.activity.compose.BackHandler
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
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.produceState
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
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
import app.data.model.WidgetPerson
import app.data.offline.DataState
import app.designsystem.R
import app.designsystem.generated.Tokens
import app.feature.capture.data.CaptureData
import app.feature.capture.data.CaptureDataProvider
import app.links.DeepLinkIntents
import app.model.DeepLink
import app.model.DeepLinkCodec
import app.model.SessionPromptGate
import app.model.WidgetStyle
import app.ui.components.Avatar
import app.ui.components.EmptyState
import app.ui.components.EmptyStateFill
import app.ui.components.Hairline
import app.ui.components.LoadingState
import app.ui.components.PremiumPill
import app.ui.foundation.PageRoles
import app.ui.foundation.tapClickable
import app.ui.system.SheetHeader
import app.ui.text.TextRoles
import app.ui.theme.AppTheme
import app.widget.WidgetChoice
import app.widget.WidgetConfigureUi
import app.widget.WidgetKind
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

/** What the friend widget's picker shows (`widget.friend` → configure activity). */
sealed interface WidgetPeopleState {
    data object Loading : WidgetPeopleState
    data class People(val people: List<WidgetPerson>) : WidgetPeopleState
    /** Nobody shares a group with the person (`widget.friend.configure.empty`). */
    data object Empty : WidgetPeopleState
    /** `widget_people` could not be read. */
    data object Error : WidgetPeopleState

    companion object {
        /** [people]: `widget_people`'s answer; null when it failed. */
        fun of(people: List<WidgetPerson>?): WidgetPeopleState = when {
            people == null -> Error
            people.isEmpty() -> Empty
            else -> People(people)
        }
    }
}

/**
 * The widget's configuration (`widget.android`, `widget.friend`, `widget.memories`, `widget.styles`): a group widget
 * asks for the group (or All Groups), a friend widget for the person, then every kind for its style; a memories widget
 * asks only the style. Choosing prepares the widget's content ([WidgetPrefetch]) so it never waits for the next photo,
 * then binds it (RESULT_OK). A premium style chosen without premium also opens the paywall at the widgets perk, when the
 * session's one prompt is still available. Follows the system appearance.
 */
object CaptureWidgetConfigureUi : WidgetConfigureUi {
    @Composable
    override fun Content(kind: WidgetKind, onChosen: (WidgetChoice) -> Unit, onCancel: () -> Unit) {
        val context = LocalContext.current
        val data = remember { CaptureDataProvider.get(context) }
        var pending by remember { mutableStateOf(if (kind == WidgetKind.Memories) WidgetChoice() else null) }
        val premium by produceState(false) { value = data.premiumOrNull() ?: data.isPremium() }
        // The widgets' premium marker follows what the picker learns (the styles draw Photo without premium).
        LaunchedEffect(Unit) { PersonalWidgetSync.refreshPremium(context, data) }
        AppTheme {
            val chosen = pending
            if (chosen == null) {
                when (kind) {
                    WidgetKind.Group -> GroupStep(context, data) { pending = it }
                    WidgetKind.Friend -> FriendStep(context, data) { pending = it }
                    WidgetKind.Memories -> Unit
                }
            } else {
                // Back from the style step returns to the group or person; a memories widget has no step before it.
                BackHandler(enabled = kind != WidgetKind.Memories) { pending = null }
                WidgetStylePickerScreen(premium) { style ->
                    if (kind == WidgetKind.Memories) WidgetPrefetch.prepareMemories(context, data)
                    onChosen(chosen.copy(style = style))
                    if (style.isLocked(premium)) openPaywallOnce(context)
                }
            }
        }
    }

    @Composable
    private fun GroupStep(context: Context, data: CaptureData, onPicked: (WidgetChoice) -> Unit) {
        val state by data.groups().map(WidgetPickerState::of).collectAsStateWithLifecycle(WidgetPickerState.Loading)
        val groups = (state as? WidgetPickerState.Groups)?.groups.orEmpty()
        val covers by produceState<Map<String, Any?>>(emptyMap(), groups.map { it.id }) {
            val paths = groups.mapNotNull { g -> g.coverPath?.let { g.id to it } }
            if (paths.isNotEmpty()) {
                val urls = runCatching { data.signedUrls(paths.map { it.second }) }.getOrDefault(emptyMap())
                value = paths.mapNotNull { (id, path) -> urls[path]?.let { id to it } }.toMap()
            }
        }
        WidgetPickerScreen(
            state,
            covers,
            onAllGroups = {
                WidgetPrefetch.prepareAll(context, data, groups)
                onPicked(WidgetChoice(allGroups = true))
            },
        ) { group ->
            WidgetPrefetch.prepare(context, data, group)
            onPicked(WidgetChoice(groupId = group.id))
        }
    }

    @Composable
    private fun FriendStep(context: Context, data: CaptureData, onPicked: (WidgetChoice) -> Unit) {
        val state by produceState<WidgetPeopleState>(WidgetPeopleState.Loading) { value = WidgetPeopleState.of(data.widgetPeople()) }
        val people = (state as? WidgetPeopleState.People)?.people.orEmpty()
        val avatars by produceState<Map<String, Any?>>(emptyMap(), people.map { it.userId }) {
            val paths = people.mapNotNull { p -> p.avatarPath?.let { p.userId to it } }
            if (paths.isNotEmpty()) {
                val urls = runCatching { data.signedUrls(paths.map { it.second }) }.getOrDefault(emptyMap())
                value = paths.mapNotNull { (id, path) -> urls[path]?.let { id to it } }.toMap()
            }
        }
        WidgetPeoplePickerScreen(state, avatars) { person ->
            WidgetPrefetch.prepareFriend(context, data, person.userId)
            onPicked(WidgetChoice(personId = person.userId))
        }
    }

    /** `app://premium?perk=widgets` (the paywall at the widgets perk), only while the session's one prompt is unused. */
    private fun openPaywallOnce(context: Context) {
        if (!SessionPromptGate.process.canPrompt) return
        val intent = DeepLinkIntents.intent(context, DeepLink.Premium(DeepLinkCodec.PERK_WIDGETS)) ?: return
        runCatching { context.startActivity(intent) }
    }
}

/**
 * The group picker page (`color.global.background.android`): C-29 centred title (`sheetTitle`), then — when
 * [onAllGroups] is given — the All Groups row (`widget.home.small.configuration.allGroups`, the group glyph in the cover
 * circle), then the groups as C-16 rows — cover in a `size.global.avatarPicker` circle (no cover: `icon.global.group`),
 * the name in text role `listTitle` (`color.global.textPrimary`) `size.global.rowThumbGap` after it — with C-32
 * hairlines between them. Loading: C-28 indicator; empty: C-27 with `widget.android.configure.empty`; error: the
 * `camera.sendto.error.generic` line. A row tap plays `haptic.global.tap` and goes on.
 */
@Composable
fun WidgetPickerScreen(
    state: WidgetPickerState,
    covers: Map<String, Any?> = emptyMap(),
    onAllGroups: (() -> Unit)? = null,
    onChoose: (Group) -> Unit,
) {
    PickerPage(stringResource(R.string.widget_home_small_configuration_title)) {
        when (state) {
            WidgetPickerState.Loading -> LoadingState(stringResource(R.string.global_a11y_loading))
            WidgetPickerState.Empty -> EmptyStateFill {
                EmptyState(title = null, detail = stringResource(R.string.widget_android_configure_empty), icon = Tokens.Icons.globalGroup)
            }
            WidgetPickerState.Error -> EmptyStateFill {
                EmptyState(title = null, detail = stringResource(R.string.camera_sendto_error_generic))
            }
            is WidgetPickerState.Groups -> LazyColumn(Modifier.fillMaxSize()) {
                if (onAllGroups != null) {
                    item(key = ALL_GROUPS_KEY) {
                        PickerRow(stringResource(R.string.widget_home_small_configuration_allgroups), null, Tokens.Icons.globalGroup, "widget.configure.all", onAllGroups)
                    }
                }
                itemsIndexed(state.groups, key = { _, g -> g.id }) { index, group ->
                    if (index > 0 || onAllGroups != null) Hairline(Modifier.padding(horizontal = Tokens.Sizes.globalScreenMargin))
                    PickerRow(group.name, covers[group.id], Tokens.Icons.globalGroup, "widget.configure.${group.id}") { onChoose(group) }
                }
            }
        }
    }
}

/**
 * The friend widget's person picker (`widget.friend.configuration.title`, "See photos from…"): the people `widget_people`
 * lists as C-16 rows — avatar in a `size.global.avatarPicker` circle (none: `icon.global.person`), the name in `listTitle`
 * — between C-32 hairlines. Loading: C-28; empty: C-27 with `widget.friend.configure.empty`; error: the
 * `camera.sendto.error.generic` line.
 */
@Composable
fun WidgetPeoplePickerScreen(state: WidgetPeopleState, avatars: Map<String, Any?> = emptyMap(), onChoose: (WidgetPerson) -> Unit) {
    PickerPage(stringResource(R.string.widget_friend_configuration_title)) {
        when (state) {
            WidgetPeopleState.Loading -> LoadingState(stringResource(R.string.global_a11y_loading))
            WidgetPeopleState.Empty -> EmptyStateFill {
                EmptyState(title = null, detail = stringResource(R.string.widget_friend_configure_empty), icon = Tokens.Icons.globalPerson)
            }
            WidgetPeopleState.Error -> EmptyStateFill {
                EmptyState(title = null, detail = stringResource(R.string.camera_sendto_error_generic))
            }
            is WidgetPeopleState.People -> LazyColumn(Modifier.fillMaxSize()) {
                itemsIndexed(state.people, key = { _, p -> p.userId }) { index, person ->
                    if (index > 0) Hairline(Modifier.padding(horizontal = Tokens.Sizes.globalScreenMargin))
                    PickerRow(person.displayName, avatars[person.userId], Tokens.Icons.globalPerson, "widget.configure.person.${person.userId}") { onChoose(person) }
                }
            }
        }
    }
}

/**
 * The style step (`widget.styles` → Android style step): C-29 title `widget.styles.configuration.title` ("Select
 * Style"), then Photo, Date and Frame as C-16 rows — the name (`widget.styles.name.*`, text role `listTitle`) over its
 * description (`widget.styles.description.*`, `listSubtitle`, secondary text), and while the person has no premium the
 * C-25 pill `paywall.locked.badge` on each premium style — between C-32 hairlines. A tap plays `haptic.global.tap` and
 * binds the widget.
 */
@Composable
fun WidgetStylePickerScreen(premium: Boolean, onChoose: (WidgetStyle) -> Unit) {
    PickerPage(stringResource(R.string.widget_styles_configuration_title)) {
        LazyColumn(Modifier.fillMaxSize()) {
            itemsIndexed(WidgetStyle.entries, key = { _, s -> s.wire }) { index, style ->
                if (index > 0) Hairline(Modifier.padding(horizontal = Tokens.Sizes.globalScreenMargin))
                StyleRow(style, locked = style.isLocked(premium)) { onChoose(style) }
            }
        }
    }
}

/** The configure page: `color.global.background.android`, safe-area insets, the C-29 header. */
@Composable
private fun PickerPage(title: String, content: @Composable () -> Unit) {
    Column(
        Modifier
            .fillMaxSize()
            .background(PageRoles.page)
            .windowInsetsPadding(WindowInsets.safeDrawing)
            .testTag("widget.configure"),
    ) {
        SheetHeader(title)
        content()
    }
}

/** One C-16 row: image + name, padded `camera.sendto.layout.recipientRow.padding` (Retro's grouped-list 16) above and below. */
@Composable
private fun PickerRow(name: String, image: Any?, fallbackIcon: androidx.compose.ui.graphics.vector.ImageVector, tag: String, onClick: () -> Unit) {
    Row(
        Modifier
            .fillMaxWidth()
            .tapClickable(onClick = onClick)
            .semantics(mergeDescendants = true) {}
            .padding(horizontal = Tokens.Sizes.globalScreenMargin, vertical = Dp(Tokens.Layouts.CameraSendtoLayoutRecipientRow.padding))
            .testTag(tag),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Avatar(image, Tokens.Sizes.globalAvatarPicker, fallbackIcon = fallbackIcon)
        Spacer(Modifier.width(Tokens.Sizes.globalRowThumbGap))
        Text(name, style = TextRoles.listTitle, color = Tokens.Colors.globalTextPrimary, maxLines = 1, overflow = TextOverflow.Ellipsis)
    }
}

/** A style row: name over description, and the premium pill when [locked]. */
@Composable
private fun StyleRow(style: WidgetStyle, locked: Boolean, onClick: () -> Unit) {
    Row(
        Modifier
            .fillMaxWidth()
            .tapClickable(onClick = onClick)
            .semantics(mergeDescendants = true) {}
            .padding(horizontal = Tokens.Sizes.globalScreenMargin, vertical = Dp(Tokens.Layouts.CameraSendtoLayoutRecipientRow.padding))
            .testTag("widget.style.${style.wire}"),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Column(Modifier.weight(1f)) {
            Text(stringResource(style.nameRes), style = TextRoles.listTitle, color = Tokens.Colors.globalTextPrimary, maxLines = 1, overflow = TextOverflow.Ellipsis)
            Text(stringResource(style.descriptionRes), style = TextRoles.listSubtitle, color = PageRoles.secondaryText(), maxLines = 1, overflow = TextOverflow.Ellipsis)
        }
        if (locked) {
            Spacer(Modifier.width(Tokens.Sizes.globalRowThumbGap))
            PremiumPill(stringResource(R.string.paywall_locked_badge))
        }
    }
}

/** `widget.styles.name.*`. */
private val WidgetStyle.nameRes: Int
    get() = when (this) {
        WidgetStyle.Photo -> R.string.widget_styles_name_photo
        WidgetStyle.Date -> R.string.widget_styles_name_date
        WidgetStyle.Frame -> R.string.widget_styles_name_frame
    }

/** `widget.styles.description.*`. */
private val WidgetStyle.descriptionRes: Int
    get() = when (this) {
        WidgetStyle.Photo -> R.string.widget_styles_description_photo
        WidgetStyle.Date -> R.string.widget_styles_description_date
        WidgetStyle.Frame -> R.string.widget_styles_description_frame
    }

private const val ALL_GROUPS_KEY = "all-groups"
