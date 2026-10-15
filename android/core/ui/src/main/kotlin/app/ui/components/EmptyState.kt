package app.ui.components

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextAlign
import app.designsystem.generated.Tokens
import app.ui.text.TextRoles

/** The single white-pill action of an [EmptyState]. */
data class EmptyStateAction(val text: String, val onClick: () -> Unit, val icon: ImageVector? = null)

/**
 * Yope's empty-state layout (V-mthu t51.23 "you created group / and added mẹ, Anh / invite more
 * friends"), used for empty, error, offline and refusal states of app surfaces.
 *
 * Tokens: title text role `emptyTitle` (16 bold) in `color.global.textPrimary`; detail text role
 * `emptyDetail` (14 italic) in `color.global.textSecondary`, directly under the title (platform
 * leading; gap not measured); optional [LightPill] (`color.global.surfaceLight`,
 * `groups.screen.size.lightPillHeight`, `groups.screen.radius.lightPill`, label text role `button`).
 * Detail → pill gap: `groups.create.size.fieldToButton` (approximation: Yope's form-stack gap; the
 * empty-state gap is not measured). Everything centred; side margins `size.global.screenMargin`.
 */
@Composable
fun EmptyState(
    title: String?,
    detail: String?,
    modifier: Modifier = Modifier,
    action: EmptyStateAction? = null,
) {
    Column(
        modifier.padding(horizontal = Tokens.Sizes.globalScreenMargin),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        if (title != null) {
            Text(
                title,
                style = TextRoles.emptyTitle,
                color = Tokens.Colors.globalTextPrimary,
                textAlign = TextAlign.Center,
                modifier = Modifier.semantics { heading() },
            )
        }
        if (detail != null) {
            Text(detail, style = TextRoles.emptyDetail, color = Tokens.Colors.globalTextSecondary, textAlign = TextAlign.Center)
        }
        if (action != null) {
            Spacer(Modifier.height(Tokens.Sizes.groupsCreateSizeFieldToButton))
            LightPill(action.text, action.onClick, leadingIcon = action.icon)
        }
    }
}
