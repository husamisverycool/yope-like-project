// Surface: camera.overnight (part A: the mode on the camera; part C's reveal rule for the local announcement).
// Spec: design/surfaces/camera.overnight.md. Composition of Retro components C-30 (native segmented control on a black page,
// references/auto/retro/press/tc-2023-12-recaps.png phone 1), C-09 (pill on a photo, references/auto/retro/store/retro-store-03.png),
// C-16 / C-29 (camera.sendto's group rows in a native sheet), C-27 (no groups) in Dispo's / Lapse's order
// (references/auto/dispo/store/dispo-store-X-1.png: the 9AM · NOW switch; references/auto/dispo/help/
// help-4410178185492_userguide-nov21.png: the chosen rolls on the camera; references/auto/lapse/store/lapse-store-01.png:
// full viewfinder, no preview). Decisions: MERGE_DECISIONS ON-1 … ON-11.
package app.feature.capture.camera

import android.content.Context
import android.text.format.DateFormat
import androidx.compose.animation.Crossfade
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.selection.toggleable
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import app.data.model.Group
import app.designsystem.R
import app.designsystem.generated.Tokens
import app.feature.capture.sendto.SendToViewModel
import app.feature.capture.ui.OnMedia
import app.ui.components.ActivityIndicator
import app.ui.components.Avatar
import app.ui.components.CheckCircle
import app.ui.components.EmptyState
import app.ui.components.EmptyStateAction
import app.ui.components.Hairline
import app.ui.components.HeaderTextButton
import app.ui.components.SegmentedControl
import app.ui.foundation.DsMotion
import app.ui.foundation.PageRoles
import app.ui.foundation.tapClickable
import app.ui.format.Formats
import app.ui.haptics.rememberHaptics
import app.ui.system.DsBottomSheet
import app.ui.text.TextRoles
import java.time.Instant
import java.time.LocalTime
import java.time.ZoneId
import java.time.ZonedDateTime
import java.util.Date

/** The camera's two modes in Dispo's segment order (`camera.overnight.layout.modeControl` segments `later`, `now`). */
enum class CaptureMode {
    /** "9 AM": the next photos develop at the reveal (no preview, no send-to). */
    Later,

    /** `camera.capture` as specified: the default, at every app launch (MERGE_DECISIONS ON-1). */
    Now,
}

/** The reveal rule (`camera.overnight.layout.reveal`): wall-clock `time` (09:00) in the group's zone, the first after capture. */
object OvernightReveal {
    /** `camera.overnight.layout.reveal.time` ("09:00"). */
    val time: LocalTime get() = LocalTime.parse(Tokens.Layouts.CameraOvernightLayoutReveal.time)

    /** The first reveal strictly after [at] in [zone] (daylight-saving safe: the wall clock decides), as the server's `next_reveal_at`. */
    fun next(at: Instant, zone: ZoneId): Instant {
        val local = at.atZone(zone)
        var candidate = ZonedDateTime.of(local.toLocalDate(), time, zone)
        if (!candidate.toInstant().isAfter(at)) candidate = ZonedDateTime.of(local.toLocalDate().plusDays(1), time, zone)
        return candidate.toInstant()
    }

    /** The earliest reveal among [groups] (each in its own time zone), for the sheet's explanation and the capture announcement. */
    fun earliest(at: Instant, groups: List<Group>, fallback: ZoneId = ZoneId.systemDefault()): Instant {
        val zones = groups.mapNotNull { g -> runCatching { ZoneId.of(g.timeZone) }.getOrNull() }.ifEmpty { listOf(fallback) }
        return zones.minOf { next(at, it) }
    }
}

/**
 * `{time}` and `{reveal}` in the copy, formatted by the platform (camera.overnight → Platform notes): `{time}` = 09:00 in the
 * locale's short time format (`DateFormat.getTimeFormat`), `{reveal}` = the relative day and time inside the sentence
 * ("tomorrow, 9:00 AM": ICU's middle-of-sentence day word, [Formats.dayAndTimeInSentence]).
 */
object OvernightFormats {
    fun time(context: Context, zone: ZoneId = ZoneId.systemDefault()): String {
        val today = ZonedDateTime.now(zone).with(OvernightReveal.time)
        return DateFormat.getTimeFormat(context).format(Date.from(today.toInstant()))
    }

    fun reveal(context: Context, at: Instant): String =
        Formats.dayAndTimeInSentence(at, DateFormat.getTimeFormat(context).format(Date.from(at)))
}

/**
 * camera.overnight's additions to the camera: the platform-formatted `{time}` (segment label, hint) and `{reveal}` (sheet
 * explanation), the groups' cover images, and the callbacks of the mode control, destination pill and sheet.
 */
data class OvernightChrome(
    val time: String = "",
    val reveal: String = "",
    val covers: Map<String, Any?> = emptyMap(),
    val onMode: (CaptureMode) -> Unit = {},
    val onPill: () -> Unit = {},
    val onToggle: (String) -> Unit = {},
    val onDone: () -> Unit = {},
    val onCreateGroup: () -> Unit = {},
    val onRetryGroups: () -> Unit = {},
)

/**
 * The mode control (`camera.overnight.layout.modeControl`): C-30 native segmented control (M3
 * `SingleChoiceSegmentedButtonRow`, core:ui [SegmentedControl]) drawn in the dark appearance on the black camera page
 * (selection `color.global.system.secondaryContainer`, dark value), full width inside `size.global.screenMargin`;
 * segments `camera.overnight.mode.later` ({time}) · `camera.overnight.mode.now`. TalkBack: `camera.overnight.a11y.mode` with
 * the hint `camera.overnight.a11y.modeHint`; the segments read their text and selection (platform). Change:
 * `haptic.global.select`.
 */
@Composable
internal fun ModeControl(mode: CaptureMode, time: String, onMode: (CaptureMode) -> Unit, modifier: Modifier = Modifier) {
    val label = stringResource(R.string.camera_overnight_a11y_mode)
    val hint = stringResource(R.string.camera_overnight_a11y_modehint, time)
    val modes = CaptureMode.entries
    OnMedia {
        Box(
            modifier
                .fillMaxWidth()
                .padding(horizontal = Tokens.Sizes.globalScreenMargin)
                .semantics { contentDescription = listOf(label, hint).joinToString(", ") }
                .testTag("camera.mode"),
        ) {
            SegmentedControl(
                options = listOf(stringResource(R.string.camera_overnight_mode_later, time), stringResource(R.string.camera_overnight_mode_now)),
                selectedIndex = modes.indexOf(mode),
                onSelect = { onMode(modes[it]) },
            )
        }
    }
}

/** What the destination pill says (`camera.overnight.destination.*`): one group's name, all groups, or some — never a number. */
@Composable
internal fun destinationLabel(groups: List<Group>, selected: Set<String>): String {
    val chosen = groups.filter { it.id in selected }
    return when {
        chosen.size == 1 -> stringResource(R.string.camera_overnight_destination_one, chosen.single().name)
        chosen.isNotEmpty() && chosen.size == groups.size -> stringResource(R.string.camera_overnight_destination_all)
        else -> stringResource(R.string.camera_overnight_destination_some)
    }
}

/**
 * The destination pill (`camera.overnight.layout.destinationPill`): C-09 on media — fill `color.global.controlOnDeep`,
 * `icon.global.group` at `size.global.iconSmall`, `size.global.pillIconGap`, the label in text role `pill`
 * (`color.global.textOnMedia`, one line, truncated at the end), height `size.global.pillHeight`, paddings
 * `size.global.pillPaddingLeading` / `.pillPaddingTrailing`, width hugging the label up to [maxWidth]. A button → the
 * destination sheet (`haptic.global.tap`); TalkBack adds `camera.overnight.a11y.destinationHint`.
 */
@Composable
internal fun DestinationPill(text: String, maxWidth: Dp, onClick: () -> Unit, modifier: Modifier = Modifier) {
    val hint = stringResource(R.string.camera_overnight_a11y_destinationhint)
    Row(
        modifier
            .widthIn(max = maxWidth)
            .heightIn(min = Tokens.Sizes.globalPillHeight)
            .clip(CircleShape)
            .background(Tokens.Colors.globalControlOnDeep, CircleShape)
            .tapClickable(onClick = onClick)
            .clearAndSetSemantics {
                contentDescription = listOf(text, hint).joinToString(", ")
                role = Role.Button
            }
            .padding(PaddingValues(start = Tokens.Sizes.globalPillPaddingLeading, end = Tokens.Sizes.globalPillPaddingTrailing))
            .testTag("camera.destination"),
        horizontalArrangement = Arrangement.spacedBy(Tokens.Sizes.globalPillIconGap),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(Tokens.Icons.globalGroup, contentDescription = null, tint = Tokens.Colors.globalTextOnMedia, modifier = Modifier.size(Tokens.Sizes.globalIconSmall))
        Text(text, style = TextRoles.pill, color = Tokens.Colors.globalTextOnMedia, maxLines = 1, overflow = TextOverflow.Ellipsis)
    }
}

/**
 * The destination sheet (`camera.overnight.layout.destinationSheet`): a native sheet (C-29) in the appearance; the centred
 * title `camera.overnight.destination.title` (`sheetTitle`) with "Done" (C-08) trailing; the explanation
 * `camera.overnight.destination.detail` ({reveal}; `body`, `color.global.textSecondary`, at most 2 lines, inside
 * `size.global.screenMargin`); then exactly `camera.sendto.layout.recipientRow` rows in the sheet's colours (cover in a
 * `size.global.avatarPicker` circle, the name, the check circle; C-32 hairlines between); no groups → `camera.sendto`'s
 * empty state (C-27). Swiping it away keeps the choice as Done does.
 */
@OptIn(androidx.compose.material3.ExperimentalMaterial3Api::class)
@Composable
internal fun DestinationSheet(groups: SendToViewModel.Groups, selected: Set<String>, chrome: OvernightChrome) {
    DsBottomSheet(onDismissRequest = chrome.onDone, modifier = Modifier.testTag("camera.destinationSheet")) {
        Box(Modifier.fillMaxWidth().padding(horizontal = Tokens.Sizes.globalScreenMargin), contentAlignment = Alignment.Center) {
            Text(
                stringResource(R.string.camera_overnight_destination_title),
                style = TextRoles.sheetTitle,
                color = Tokens.Colors.globalTextPrimary,
                modifier = Modifier.semantics { heading() },
            )
            HeaderTextButton(stringResource(R.string.camera_overnight_destination_done), chrome.onDone, Modifier.align(Alignment.CenterEnd).testTag("camera.destination.done"))
        }
        Text(
            stringResource(R.string.camera_overnight_destination_detail, chrome.reveal),
            style = TextRoles.body,
            color = PageRoles.secondaryText(),
            maxLines = 2,
            overflow = TextOverflow.Ellipsis,
            modifier = Modifier.fillMaxWidth().padding(horizontal = Tokens.Sizes.globalScreenMargin, vertical = Tokens.Sizes.globalScreenMargin),
        )
        val rowPadding = Dp(Tokens.Layouts.CameraSendtoLayoutRecipientRow.padding)
        val area = Modifier.fillMaxWidth().padding(vertical = rowPadding)
        Column(Modifier.verticalScroll(rememberScrollState()).navigationBarsPadding()) {
            when (groups) {
                SendToViewModel.Groups.Loading -> Box(area, contentAlignment = Alignment.Center) {
                    ActivityIndicator(stringResource(R.string.global_a11y_loading))
                }
                SendToViewModel.Groups.Empty -> Box(area, contentAlignment = Alignment.Center) {
                    EmptyState(
                        title = stringResource(R.string.camera_sendto_empty_title),
                        detail = stringResource(R.string.camera_sendto_empty_detail),
                        action = EmptyStateAction(stringResource(R.string.camera_sendto_empty_button), chrome.onCreateGroup, Tokens.Icons.globalAdd),
                        icon = Tokens.Icons.globalGroup,
                    )
                }
                is SendToViewModel.Groups.Failed -> Box(area, contentAlignment = Alignment.Center) {
                    EmptyState(
                        title = stringResource(if (groups.offline) R.string.camera_sendto_error_offline else R.string.camera_sendto_error_generic),
                        detail = null,
                        action = EmptyStateAction(stringResource(R.string.camera_sendto_error_retry), chrome.onRetryGroups),
                    )
                }
                is SendToViewModel.Groups.Loaded -> groups.groups.forEachIndexed { index, group ->
                    if (index > 0) Hairline(Modifier.padding(horizontal = Tokens.Sizes.globalScreenMargin))
                    DestinationRow(group, chrome.covers[group.id], group.id in selected) { chrome.onToggle(group.id) }
                }
            }
        }
    }
}

/**
 * One group row (`camera.sendto.layout.recipientRow`, C-16) in the sheet's appearance: cover in a `size.global.avatarPicker`
 * circle (no cover: `icon.global.group`), the name `size.global.cardNameGap` after it (`listTitle`,
 * `color.global.textPrimary`), the check circle trailing; 16 above and below. Toggles as a checkbox with `haptic.global.tap`
 * (camera.overnight → Haptics: sheet rows); the check cross-fades.
 */
@Composable
private fun DestinationRow(group: Group, cover: Any?, selected: Boolean, onToggle: () -> Unit) {
    val haptics = rememberHaptics()
    Row(
        Modifier
            .fillMaxWidth()
            .toggleable(value = selected, role = Role.Checkbox) {
                haptics.tap()
                onToggle()
            }
            .semantics(mergeDescendants = true) {}
            .padding(horizontal = Tokens.Sizes.globalScreenMargin, vertical = Dp(Tokens.Layouts.CameraSendtoLayoutRecipientRow.padding))
            .testTag("camera.destination.row.${group.id}"),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Avatar(cover, Tokens.Sizes.globalAvatarPicker, fallbackIcon = Tokens.Icons.globalGroup)
        Spacer(Modifier.width(Tokens.Sizes.globalCardNameGap))
        Text(group.name, style = TextRoles.listTitle, color = Tokens.Colors.globalTextPrimary, maxLines = 1, overflow = TextOverflow.Ellipsis, modifier = Modifier.weight(1f))
        Spacer(Modifier.width(Tokens.Sizes.globalCardNameGap))
        Crossfade(selected, animationSpec = DsMotion.crossfade(), label = "check") { on -> CheckCircle(on) }
    }
}
