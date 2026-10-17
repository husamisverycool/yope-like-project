package app.feature.account.groups

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.produceState
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
import androidx.lifecycle.compose.LifecycleResumeEffect
import app.data.model.DailyInvitation
import app.designsystem.R
import app.designsystem.generated.Tokens
import app.feature.account.data.AccountBackend
import app.ui.components.Avatar
import app.ui.foundation.PageRoles
import app.ui.foundation.tapClickable
import app.ui.format.InvitationCountdown
import app.ui.format.InvitationCountdownText
import app.ui.text.TextRoles

/**
 * The group's daily invitation while it is open (`open_invitations`, migration 0035), read when the screen shows and
 * comes back and when [refreshKey] changes (a new post); a failed read keeps what is shown until its window closes.
 * The row ([OpenInvitationRow]) opens the daily capture for it — the same answer the notification opens — and goes at
 * `closes_at`; nothing marks the time after (tenet 5).
 */
@Composable
internal fun OpenInvitationEntry(backend: AccountBackend, groupId: String, refreshKey: Any?, onOpen: (invitationId: String) -> Unit) {
    var resumes by remember(groupId) { mutableIntStateOf(0) }
    LifecycleResumeEffect(groupId) {
        resumes++
        onPauseOrDispose { }
    }
    val invitation by produceState<DailyInvitation?>(null, groupId, refreshKey, resumes) {
        try {
            value = backend.openInvitation(groupId)
        } catch (e: kotlinx.coroutines.CancellationException) {
            throw e
        } catch (_: Exception) {
            // keep what is shown: the countdown removes it at closes_at
        }
    }
    val open = invitation ?: return
    val seconds = InvitationCountdown.rememberSeconds(open.closesAt) ?: return
    OpenInvitationRow(seconds) { onOpen(open.id) }
}

/**
 * One C-14 single row `size.global.sectionGap` under the capsules, drawn as the birthday request row: the C-16
 * `size.global.avatarPicker` circle with `icon.global.camera` (the avatar's fallback), `notifications.push.dailyInvitation.body`
 * (`listTitle`) over the countdown (`daily.capture.countdown`, `listSubtitle`, secondary text, tabular figures) and the
 * chevron. TalkBack: the title with the time left as its state.
 */
@Composable
internal fun OpenInvitationRow(seconds: Long, onClick: () -> Unit) {
    val shape = RoundedCornerShape(Tokens.Radii.globalGroupedRow)
    val secondary = PageRoles.secondaryText()
    Row(
        Modifier
            .padding(start = Tokens.Sizes.globalScreenMargin, end = Tokens.Sizes.globalScreenMargin, top = Tokens.Sizes.globalSectionGap)
            .fillMaxWidth()
            .clip(shape)
            .background(PageRoles.secondarySurface, shape)
            .tapClickable(onClick = onClick)
            .semantics(mergeDescendants = true) { stateDescription = InvitationCountdown.spoken(seconds) }
            .padding(Tokens.Sizes.globalScreenMargin)
            .testTag("groups.screen.invitation"),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Avatar(null, Tokens.Sizes.globalAvatarPicker, fallbackIcon = Tokens.Icons.globalCamera)
        Spacer(Modifier.width(Tokens.Sizes.globalRowThumbGap))
        Column(Modifier.weight(1f)) {
            Text(stringResource(R.string.notifications_push_dailyinvitation_body), style = TextRoles.listTitle, color = Tokens.Colors.globalTextPrimary)
            // spoken through the row's state instead
            InvitationCountdownText(seconds, secondary, Modifier.clearAndSetSemantics { })
        }
        Icon(Tokens.Icons.globalChevron, contentDescription = null, tint = secondary, modifier = Modifier.size(Tokens.Sizes.globalIcon))
    }
}
