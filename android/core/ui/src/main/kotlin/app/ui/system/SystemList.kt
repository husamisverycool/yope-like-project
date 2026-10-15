package app.ui.system

import android.os.Build
import android.view.HapticFeedbackConstants
import androidx.compose.foundation.clickable
import androidx.compose.foundation.selection.toggleable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyListScope
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.LargeTopAppBar
import androidx.compose.material3.ListItem
import androidx.compose.material3.ListItemDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.material3.rememberTopAppBarState
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.input.nestedscroll.nestedScroll
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextAlign
import app.designsystem.generated.Tokens

/*
 * Native Material 3 list surfaces (`settings.root.layout.list`, android): a LazyColumn of M3
 * ListItem rows on `color.global.system.surface`; labels `color.global.system.onSurface` (M3
 * bodyLarge), supporting text and leading icons `color.global.system.onSurfaceVariant` (bodyMedium);
 * section headers and footers in bodyMedium / `color.global.system.onSurfaceVariant`; a
 * HorizontalDivider (`settings.root.size.divider.android`, `color.global.system.outline`) between
 * groups of rows. Row heights and paddings are M3 ListItem's own (the values recorded as
 * `settings.root.size.listItemOneLine.android` 56, `.listItemTwoLine.android` 72,
 * `.listItemPaddingH.android` 16, `.listItemPaddingV.android` 10). Type: MaterialTheme.typography
 * (`layout.global.system.typography`). Used by settings.*, groups.settings, safety.*.
 */

/** The screen frame of a system list: M3 Scaffold + top app bar ([large] = LargeTopAppBar, settings.root). */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SystemScaffold(
    title: String,
    backLabel: String?,
    onBack: (() -> Unit)?,
    modifier: Modifier = Modifier,
    large: Boolean = false,
    content: @Composable (PaddingValues) -> Unit,
) {
    val scroll = if (large) TopAppBarDefaults.exitUntilCollapsedScrollBehavior(rememberTopAppBarState()) else TopAppBarDefaults.pinnedScrollBehavior()
    val colors = TopAppBarDefaults.topAppBarColors(
        containerColor = Tokens.Colors.globalSystemSurface,
        scrolledContainerColor = Tokens.Colors.globalSystemSurface,
        titleContentColor = Tokens.Colors.globalSystemOnSurface,
        navigationIconContentColor = Tokens.Colors.globalSystemOnSurface,
    )
    val navigation: @Composable () -> Unit = {
        if (onBack != null && backLabel != null) {
            IconButton(onClick = onBack) { Icon(Tokens.Icons.globalBack, contentDescription = backLabel) }
        }
    }
    Scaffold(
        modifier = modifier.nestedScroll(scroll.nestedScrollConnection),
        containerColor = Tokens.Colors.globalSystemSurface,
        topBar = {
            if (large) {
                LargeTopAppBar(title = { Text(title) }, navigationIcon = navigation, colors = colors, scrollBehavior = scroll)
            } else {
                TopAppBar(title = { Text(title) }, navigationIcon = navigation, colors = colors, scrollBehavior = scroll)
            }
        },
        content = content,
    )
}

/** A LazyColumn filling the scaffold body. */
@Composable
fun SystemList(padding: PaddingValues, modifier: Modifier = Modifier, content: LazyListScope.() -> Unit) {
    LazyColumn(modifier.fillMaxSize(), contentPadding = padding, content = content)
}

/** Section header text (bodyMedium, onSurfaceVariant), announced as a heading. */
@Composable
fun SystemSectionHeader(text: String, modifier: Modifier = Modifier) {
    Text(
        text,
        style = MaterialTheme.typography.bodyMedium,
        color = Tokens.Colors.globalSystemOnSurfaceVariant,
        modifier = modifier
            .fillMaxWidth()
            .padding(horizontal = Tokens.Sizes.settingsRootSizeListItemPaddingHAndroid, vertical = Tokens.Sizes.settingsRootSizeListItemPaddingVAndroid)
            .semantics { heading() },
    )
}

/** Section footer text (bodyMedium, onSurfaceVariant); [isError] uses `color.global.system.error`. */
@Composable
fun SystemSectionFooter(text: String, modifier: Modifier = Modifier, isError: Boolean = false) {
    Text(
        text,
        style = MaterialTheme.typography.bodyMedium,
        color = if (isError) Tokens.Colors.globalSystemError else Tokens.Colors.globalSystemOnSurfaceVariant,
        modifier = modifier
            .fillMaxWidth()
            .padding(horizontal = Tokens.Sizes.settingsRootSizeListItemPaddingHAndroid, vertical = Tokens.Sizes.settingsRootSizeListItemPaddingVAndroid),
    )
}

/** The divider between groups of rows (`settings.root.size.divider.android`, `color.global.system.outline`). */
@Composable
fun SystemDivider(modifier: Modifier = Modifier) {
    HorizontalDivider(modifier, thickness = Tokens.Sizes.settingsRootSizeDividerAndroid, color = Tokens.Colors.globalSystemOutline)
}

/**
 * One M3 list row. [destructive] draws the label (and leading icon) in `color.global.system.error`
 * (destructive actions on Android system surfaces). [onClick] null = not tappable. [trailing] holds
 * a value text, a Switch, a button or a progress indicator.
 */
@Composable
fun SystemRow(
    headline: String,
    modifier: Modifier = Modifier,
    supporting: String? = null,
    leading: (@Composable () -> Unit)? = null,
    trailing: (@Composable () -> Unit)? = null,
    destructive: Boolean = false,
    enabled: Boolean = true,
    onClick: (() -> Unit)? = null,
) {
    val label = if (destructive) Tokens.Colors.globalSystemError else Tokens.Colors.globalSystemOnSurface
    ListItem(
        headlineContent = { Text(headline) },
        supportingContent = supporting?.let { { Text(it) } },
        leadingContent = leading,
        trailingContent = trailing,
        colors = ListItemDefaults.colors(
            containerColor = Tokens.Colors.globalSystemSurface,
            headlineColor = label,
            leadingIconColor = if (destructive) Tokens.Colors.globalSystemError else Tokens.Colors.globalSystemOnSurfaceVariant,
            supportingColor = Tokens.Colors.globalSystemOnSurfaceVariant,
            trailingIconColor = Tokens.Colors.globalSystemOnSurfaceVariant,
        ),
        modifier = modifier.then(
            if (onClick != null) Modifier.clickable(enabled = enabled, role = Role.Button, onClick = onClick) else Modifier,
        ),
    )
}

/**
 * A row with a trailing M3 Switch; the whole row toggles. The M3 Switch plays no haptic of its own, so
 * the row plays `settings.root.layout.toggleHaptic` (android: TOGGLE_ON / TOGGLE_OFF, API 34+ only).
 */
@Composable
fun SystemSwitchRow(
    headline: String,
    checked: Boolean,
    onCheckedChange: (Boolean) -> Unit,
    modifier: Modifier = Modifier,
    supporting: String? = null,
    enabled: Boolean = true,
) {
    val view = LocalView.current
    ListItem(
        headlineContent = { Text(headline) },
        supportingContent = supporting?.let { { Text(it) } },
        trailingContent = { Switch(checked = checked, onCheckedChange = null, enabled = enabled) },
        colors = ListItemDefaults.colors(
            containerColor = Tokens.Colors.globalSystemSurface,
            headlineColor = Tokens.Colors.globalSystemOnSurface,
            supportingColor = Tokens.Colors.globalSystemOnSurfaceVariant,
        ),
        modifier = modifier.toggleable(value = checked, enabled = enabled, role = Role.Switch) { on ->
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                view.performHapticFeedback(if (on) HapticFeedbackConstants.TOGGLE_ON else HapticFeedbackConstants.TOGGLE_OFF)
            }
            onCheckedChange(on)
        },
    )
}

/** The platform progress indicator (`easing.global.native` activityIndicator) centred in the list area. */
@Composable
fun SystemLoading(modifier: Modifier = Modifier) {
    Box(modifier.fillMaxSize(), contentAlignment = Alignment.Center) { CircularProgressIndicator(color = Tokens.Colors.globalSystemPrimary) }
}

/**
 * `settings.blocked.layout.empty` (android): centred column, headline bodyLarge in
 * `color.global.system.onSurface`, supporting text bodyMedium in `color.global.system.onSurfaceVariant`.
 */
@Composable
fun SystemEmpty(title: String, message: String, modifier: Modifier = Modifier) {
    androidx.compose.foundation.layout.Column(
        modifier.fillMaxSize().padding(horizontal = Tokens.Sizes.settingsRootSizeListItemPaddingHAndroid),
        verticalArrangement = androidx.compose.foundation.layout.Arrangement.Center,
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text(title, style = MaterialTheme.typography.bodyLarge, color = Tokens.Colors.globalSystemOnSurface, textAlign = TextAlign.Center)
        Text(message, style = MaterialTheme.typography.bodyMedium, color = Tokens.Colors.globalSystemOnSurfaceVariant, textAlign = TextAlign.Center)
    }
}
