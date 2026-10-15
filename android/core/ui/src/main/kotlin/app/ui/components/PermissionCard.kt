package app.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.foundation.clickable
import app.designsystem.dsTextStyle
import app.designsystem.generated.Tokens

/**
 * Yope's inline permission card (CC: "can’t see your friends?" / "enable contacts" / "enable" / ✕),
 * used for contacts (groups.invite, Android), the camera-denied state (camera.capture) and the
 * photos-save-denied state (photo.viewer).
 *
 * Tokens (`onboarding.permission.contacts.*`): fill `.color.card`, minimum height `.size.cardHeight`
 * (grows with text), corners `radius.global.card`; text block left-aligned at
 * `groups.list.size.avatarInset` from the leading edge (`.layout.card` text rule) — title
 * `.fontSize.cardTitle` / `.fontWeight.cardTitle` in `color.global.textPrimary` (max 2 lines), detail
 * `.fontSize.cardDetail` in `color.global.textSecondary`; white "enable" pill `.size.cardButtonWidth` ×
 * `.size.cardButtonHeight`, capsule, vertically centred `groups.list.size.avatarInset` from the trailing
 * edge; optional dismiss ✕ (`icon.global.close`, `color.global.textPrimary`) at the top-trailing corner
 * (its touch target expands to `size.global.minTouchTarget.android`). The caller applies the side margin
 * `.size.cardMarginH`. Title + detail are read as one element, then the pill, then the ✕.
 */
@Composable
fun PermissionCard(
    title: String,
    detail: String,
    buttonText: String,
    onButton: () -> Unit,
    modifier: Modifier = Modifier,
    onDismiss: (() -> Unit)? = null,
    dismissLabel: String? = null,
) {
    val shape = RoundedCornerShape(Tokens.Radii.globalCard)
    val inset = Tokens.Sizes.groupsListSizeAvatarInset
    Box(
        modifier
            .fillMaxWidth()
            .heightIn(min = Tokens.Sizes.onboardingPermissionContactsSizeCardHeight)
            .background(Tokens.Colors.onboardingPermissionContactsColorCard, shape),
    ) {
        Row(
            Modifier.fillMaxWidth().heightIn(min = Tokens.Sizes.onboardingPermissionContactsSizeCardHeight).padding(horizontal = inset),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Column(Modifier.weight(1f).semantics(mergeDescendants = true) {}) {
                Text(
                    title,
                    style = dsTextStyle(Tokens.FontSizes.onboardingPermissionContactsFontSizeCardTitle, Tokens.FontWeights.onboardingPermissionContactsFontWeightCardTitle),
                    color = Tokens.Colors.globalTextPrimary,
                    maxLines = 2,
                )
                Text(
                    detail,
                    style = androidx.compose.ui.text.TextStyle(fontSize = Tokens.FontSizes.onboardingPermissionContactsFontSizeCardDetail),
                    color = Tokens.Colors.globalTextSecondary,
                )
            }
            LightPill(
                text = buttonText,
                onClick = onButton,
                shape = LightPillShape.Capsule,
                height = Tokens.Sizes.onboardingPermissionContactsSizeCardButtonHeight,
                modifier = Modifier.width(Tokens.Sizes.onboardingPermissionContactsSizeCardButtonWidth),
            )
        }
        if (onDismiss != null && dismissLabel != null) {
            // The glyph keeps its platform size in the corner; Compose expands its touch target to
            // size.global.minTouchTarget.android for near misses without covering the pill.
            Icon(
                Tokens.Icons.globalClose,
                contentDescription = null,
                tint = Tokens.Colors.globalTextPrimary,
                modifier = Modifier
                    .align(Alignment.TopEnd)
                    .clickable(role = Role.Button, onClick = onDismiss)
                    .semantics { contentDescription = dismissLabel },
            )
        }
    }
}
