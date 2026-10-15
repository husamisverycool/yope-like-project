package app.ui.system

import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import app.designsystem.generated.Tokens

/**
 * The M3 basic dialog used for confirmations and permission rationales
 * (`settings.account.layout.alert`, android): container `color.global.system.surfaceContainerHigh`,
 * corners `settings.account.layout.alert` androidCornerDp (28), headline `headlineSmall` in
 * `color.global.system.onSurface`, text `bodyMedium` in `color.global.system.onSurfaceVariant`,
 * actions `labelLarge` text buttons in `color.global.system.primary`; at most 2 actions, dismissive
 * leading, confirming trailing; a [destructive] confirm label is `color.global.system.error`.
 * While [confirmBusy] the confirm action shows the platform progress indicator and is disabled
 * (safety.block "blocking", settings.account "deleting").
 */
@Composable
fun SystemAlertDialog(
    title: String?,
    text: String?,
    confirmLabel: String,
    onConfirm: () -> Unit,
    dismissLabel: String?,
    onDismiss: () -> Unit,
    modifier: Modifier = Modifier,
    destructive: Boolean = false,
    confirmBusy: Boolean = false,
) {
    AlertDialog(
        onDismissRequest = { if (!confirmBusy) onDismiss() },
        modifier = modifier,
        shape = RoundedCornerShape(Tokens.Layouts.SettingsAccountLayoutAlert.androidCornerDp.dp),
        containerColor = Tokens.Colors.globalSystemSurfaceContainerHigh,
        titleContentColor = Tokens.Colors.globalSystemOnSurface,
        textContentColor = Tokens.Colors.globalSystemOnSurfaceVariant,
        title = title?.let { { Text(it, style = MaterialTheme.typography.headlineSmall) } },
        text = text?.let { { Text(it, style = MaterialTheme.typography.bodyMedium) } },
        confirmButton = {
            TextButton(onClick = onConfirm, enabled = !confirmBusy) {
                if (confirmBusy) {
                    CircularProgressIndicator(color = Tokens.Colors.globalSystemPrimary)
                } else {
                    Text(
                        confirmLabel,
                        style = MaterialTheme.typography.labelLarge,
                        color = if (destructive) Tokens.Colors.globalSystemError else Tokens.Colors.globalSystemPrimary,
                    )
                }
            }
        },
        dismissButton = dismissLabel?.let {
            {
                TextButton(onClick = onDismiss, enabled = !confirmBusy) {
                    Text(it, style = MaterialTheme.typography.labelLarge, color = Tokens.Colors.globalSystemPrimary)
                }
            }
        },
    )
}
