package app.ui.system

import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.window.DialogProperties

/**
 * C-29 alert / dialog: the native M3 `AlertDialog` (PLATFORM), coloured by the theme's Retro scheme
 * (`color.global.system.*`: container surfaceContainerHigh, headline onSurface, text onSurfaceVariant, actions
 * primary #0A84FF; a [destructive] confirm label in error #EA3337 — Retro's "Yes, delete"). Shape, type and
 * motion are the platform's (`MaterialTheme.typography` with Retro's overrides). Dismissive leading, confirming
 * trailing; an optional [neutralLabel] sits before the dismissive one, as the platform `AlertDialog`'s neutral
 * button does (`AlertDialog.Builder.setNeutralButton`). While [confirmBusy] the confirm action shows the platform progress
 * indicator and is disabled. [dismissible] false: tapping outside and Back do not close it. M3 dialog actions in
 * Retro blue are a recorded contrast failure (CONTRAST failure 6).
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
    dismissible: Boolean = true,
    neutralLabel: String? = null,
    onNeutral: () -> Unit = {},
) {
    val scheme = MaterialTheme.colorScheme
    val dismiss: (@Composable () -> Unit)? = dismissLabel?.let { { TextButton(onClick = onDismiss, enabled = !confirmBusy) { Text(it, color = scheme.primary) } } }
    AlertDialog(
        onDismissRequest = { if (!confirmBusy) onDismiss() },
        modifier = modifier,
        properties = DialogProperties(dismissOnBackPress = dismissible, dismissOnClickOutside = dismissible),
        title = title?.let { { Text(it) } },
        text = text?.let { { Text(it) } },
        confirmButton = {
            TextButton(onClick = onConfirm, enabled = !confirmBusy) {
                if (confirmBusy) {
                    CircularProgressIndicator(color = scheme.primary)
                } else {
                    Text(confirmLabel, color = if (destructive) scheme.error else scheme.primary)
                }
            }
        },
        dismissButton = if (neutralLabel == null) {
            dismiss
        } else {
            {
                Row {
                    TextButton(onClick = onNeutral, enabled = !confirmBusy) { Text(neutralLabel, color = scheme.primary) }
                    dismiss?.invoke()
                }
            }
        },
    )
}

/**
 * C-29 alert with one text field (PLATFORM: Material 3's dialog with a text input, the counterpart of iOS's alert text
 * field): [title], the field ([value], [placeholder] as its hint, the theme's outlined field), the dismissive [dismissLabel]
 * leading and the confirming [confirmLabel] trailing. The caller keeps [value] (and any length limit) in
 * [onValueChange]. Shape, type and motion are the platform's, coloured by the theme's Retro scheme.
 */
@Composable
fun SystemTextFieldDialog(
    title: String,
    value: String,
    onValueChange: (String) -> Unit,
    placeholder: String,
    confirmLabel: String,
    onConfirm: () -> Unit,
    dismissLabel: String,
    onDismiss: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val scheme = MaterialTheme.colorScheme
    AlertDialog(
        onDismissRequest = onDismiss,
        modifier = modifier,
        title = { Text(title) },
        text = {
            OutlinedTextField(
                value = value,
                onValueChange = onValueChange,
                placeholder = { Text(placeholder) },
                modifier = Modifier.fillMaxWidth(),
            )
        },
        confirmButton = { TextButton(onClick = onConfirm) { Text(confirmLabel, color = scheme.primary) } },
        dismissButton = { TextButton(onClick = onDismiss) { Text(dismissLabel, color = scheme.primary) } },
    )
}

/**
 * A field-level error on form screens: the native dialog with no title, the error sentence as its message and
 * one button ([buttonLabel]) that closes it; tapping outside or Back does not close it.
 */
@Composable
fun ErrorAlert(message: String, buttonLabel: String, onDismiss: () -> Unit, modifier: Modifier = Modifier) {
    SystemAlertDialog(
        title = null,
        text = message,
        confirmLabel = buttonLabel,
        onConfirm = onDismiss,
        dismissLabel = null,
        onDismiss = onDismiss,
        modifier = modifier,
        dismissible = false,
    )
}
