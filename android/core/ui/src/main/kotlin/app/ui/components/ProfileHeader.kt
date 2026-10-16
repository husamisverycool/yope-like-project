package app.ui.components

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.paddingFrom
import androidx.compose.foundation.layout.paddingFromBaseline
import androidx.compose.foundation.layout.size
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.Immutable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.layout.FirstBaseline
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import app.designsystem.generated.Tokens
import app.ui.foundation.PageRoles
import app.ui.foundation.centreAt
import app.ui.foundation.endAtLastBaseline
import app.ui.text.CapTop
import app.ui.text.TextRoles

/** An info row of the profile header: an outline glyph (`icon.global.location` / `.calendar` / `.camera`) and its text (copy; never "Weeks Posted: N"). */
@Immutable
data class ProfileInfo(val icon: ImageVector, val text: String)

/** A text capsule of the profile action row ("Recaps", "Share Profile"). */
@Immutable
data class ProfileAction(val text: String, val onClick: () -> Unit)

/**
 * C-19 Profile header.
 *
 * - [name]: display serif, text role `headerTitle`, placed like the C-01 title (first baseline
 *   `size.global.titleTop` from the top, `size.global.screenMargin` leading); header trait.
 * - [avatar] `size.global.avatarProfile` (64) with its edge on the right margin, centred on the name's cap
 *   middle; labelled [avatarDescription] (the person's name). The name keeps `size.global.screenMargin` clear of it.
 * - [realName] text role `meta` (13) in secondary text, under the name.
 * - [info] rows: glyph `size.global.iconSmall` in `color.global.textPrimary`, `size.global.pillIconGap` before the
 *   text (the row's own glyph → text gap is not measured — Gap) in text role `body`; baselines
 *   `size.global.infoRowPitch` apart (the first one that pitch below the previous line).
 * - [actions]: outline C-06 capsules of equal widths, `size.global.pillGap` apart, then [settings] as an
 *   icon-only capsule (`size.global.iconPillWidth`, `icon.global.settings`). The row starts
 *   `size.global.infoRowPitch` below the last baseline (ST-02 reads ≈34 — not a token, Gap).
 * - Below: week sections (C-20 + C-17), no divider (2026).
 */
@Composable
fun ProfileHeader(
    name: String,
    avatar: Any?,
    avatarDescription: String,
    modifier: Modifier = Modifier,
    realName: String? = null,
    info: List<ProfileInfo> = emptyList(),
    actions: List<ProfileAction> = emptyList(),
    settings: HeaderAction? = null,
) {
    val margin = Tokens.Sizes.globalScreenMargin
    val pitch = Tokens.Sizes.globalInfoRowPitch
    val capMiddle = Tokens.Sizes.globalTitleTop - CapTop.height(TextRoles.headerTitle) / 2
    Column(modifier.fillMaxWidth().padding(horizontal = margin)) {
        Box(Modifier.fillMaxWidth()) {
            Text(
                name,
                style = TextRoles.headerTitle,
                color = Tokens.Colors.globalTextPrimary,
                modifier = Modifier
                    .padding(end = Tokens.Sizes.globalAvatarProfile + margin)
                    .paddingFrom(FirstBaseline, before = Tokens.Sizes.globalTitleTop)
                    .endAtLastBaseline()
                    .semantics { heading() },
            )
            Box(Modifier.align(Alignment.TopEnd).centreAt(capMiddle)) {
                Avatar(avatar, Tokens.Sizes.globalAvatarProfile, contentDescription = avatarDescription)
            }
        }
        if (realName != null) {
            Text(realName, style = TextRoles.meta, color = PageRoles.secondaryText(), modifier = Modifier.paddingFromBaseline(top = pitch).endAtLastBaseline())
        }
        info.forEach { row ->
            Row(
                Modifier.paddingFromBaseline(top = pitch).endAtLastBaseline().semantics(mergeDescendants = true) {},
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(Tokens.Sizes.globalPillIconGap),
            ) {
                Icon(row.icon, contentDescription = null, tint = Tokens.Colors.globalTextPrimary, modifier = Modifier.size(Tokens.Sizes.globalIconSmall))
                Text(row.text, style = TextRoles.body, color = Tokens.Colors.globalTextPrimary)
            }
        }
        if (actions.isNotEmpty() || settings != null) {
            Row(Modifier.fillMaxWidth().padding(top = pitch), horizontalArrangement = CapsuleRowSpacing) {
                actions.forEach { Capsule(it.text, it.onClick, Modifier.weight(1f), style = CapsuleStyle.Outline) }
                if (settings != null) IconCapsule(settings.icon, settings.contentDescription, settings.onClick, style = CapsuleStyle.Outline)
            }
        }
    }
}
