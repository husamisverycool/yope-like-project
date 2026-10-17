// Surface: settings.downloads — "Download My Photos" (settings.root → Privacy) and albums.view's "Download Album".
// Spec: design/surfaces/settings.downloads.md. Mechanics: Retro "Download your package"
// (references/auto/retro/web/retro.app-web-copy-excerpts.txt /downloads), Yope "download all photos"
// (design/research/yope-a.md §2.13); composition of the C-29 sheet header with the C-02 back glyph (as the other Settings
// pages), C-27 (glyph + explanation), the platform progress bar (PLATFORM), C-05 / C-06 capsules and the C-29 alert.
package app.feature.social.downloads

import android.Manifest
import android.content.Intent
import android.net.Uri
import android.provider.Settings
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.WindowInsetsSides
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.only
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawing
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.coerceAtLeast
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.max
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import app.designsystem.R
import app.designsystem.generated.Tokens
import app.feature.social.common.SystemAppearance
import app.feature.social.common.announce
import app.feature.social.common.stringRes
import app.feature.social.data.GallerySaver
import app.ui.components.Capsule
import app.ui.components.CapsuleStyle
import app.ui.components.EmptyState
import app.ui.components.HeaderIconButton
import app.ui.components.PrimaryButton
import app.ui.foundation.GlyphInk
import app.ui.foundation.PageRoles
import app.ui.haptics.rememberHaptics
import app.ui.system.SheetHeader
import app.ui.system.SystemAlertDialog
import app.ui.text.TextRoles

/** Test tags (flow tests). */
object DownloadTags {
    const val ROOT = "settings.downloads"
    const val START = "settings.downloads.start"
    const val CANCEL = "settings.downloads.cancel"
    const val PROGRESS = "settings.downloads.progress"
}

/**
 * The download page with its view model: haptics for the end states (`haptic.global.success` / `.error`), TalkBack
 * announcements, the permission request before saving on API 26–28 (as Save to Camera Roll), the denied alert, and the
 * paywall when an album needs premium. [autoStart]: the album's menu item already asked for it.
 */
@Composable
fun DownloadRoute(
    vm: DownloadViewModel,
    title: String,
    detail: String,
    gallery: GallerySaver,
    onBack: () -> Unit,
    onPaywall: () -> Unit,
    autoStart: Boolean = false,
) {
    val state by vm.state.collectAsStateWithLifecycle()
    val context = LocalContext.current
    val view = LocalView.current
    val haptics = rememberHaptics()
    val paywall by rememberUpdatedState(onPaywall)
    val done = stringRes(R.string.settings_downloads_done)
    LaunchedEffect(vm) {
        vm.effects.collect { effect ->
            when (effect) {
                DownloadEffect.Done -> { haptics.perform(Tokens.Haptics.globalSuccess); announce(view, done) }
                DownloadEffect.Failed -> haptics.perform(Tokens.Haptics.globalError)
                DownloadEffect.Paywall -> paywall()
            }
        }
    }
    val askWrite = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { granted -> if (granted) vm.start() else vm.accessDenied() }
    val start: () -> Unit = {
        if (gallery.needsPermission(context)) askWrite.launch(Manifest.permission.WRITE_EXTERNAL_STORAGE) else vm.start()
    }
    LaunchedEffect(vm, autoStart) { if (autoStart && state.phase == DownloadUiState.Phase.Idle) start() }
    // The page closed: the download stops; Continue goes on from there next time.
    DisposableEffect(vm) { onDispose { vm.cancel() } }
    DownloadScreen(
        state = state,
        title = title,
        detail = detail,
        onBack = onBack,
        onStart = start,
        onCancel = vm::cancel,
        onOpenSettings = {
            vm.dismissDenied()
            context.startActivity(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.fromParts("package", context.packageName, null)))
        },
        onDismissDenied = vm::dismissDenied,
    )
}

/**
 * The page (the other Settings pages' chrome: the centred title with the C-02 back glyph): the C-27 block
 * (`icon.global.download`, the explanation), then the state line — the platform progress bar with "Downloading…" while
 * saving (indeterminate for your photos, a bar without figures for an album; never a number), "Saved!", the empty line or
 * the error / offline line — and pinned at the bottom the C-05 capsule (Download / Continue) or, while saving, the C-06
 * Cancel capsule, `size.global.buttonMarginH` from the edges. Denied access: the C-29 alert with the Settings button.
 */
@Composable
fun DownloadScreen(
    state: DownloadUiState,
    title: String,
    detail: String,
    onBack: () -> Unit,
    onStart: () -> Unit,
    onCancel: () -> Unit,
    onOpenSettings: () -> Unit = {},
    onDismissDenied: () -> Unit = {},
) {
    Column(
        Modifier
            .fillMaxSize()
            .background(PageRoles.page)
            .windowInsetsPadding(WindowInsets.safeDrawing.only(WindowInsetsSides.Top + WindowInsetsSides.Horizontal))
            .testTag(DownloadTags.ROOT),
    ) {
        Box(Modifier.fillMaxWidth(), contentAlignment = Alignment.CenterStart) {
            SheetHeader(title)
            BackGlyph(stringRes(R.string.groups_screen_back_accessibilitylabel), onBack)
        }
        Column(
            Modifier
                .weight(1f)
                .fillMaxWidth()
                .verticalScroll(rememberScrollState())
                .padding(top = Tokens.Sizes.globalTitleToContent),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            EmptyState(
                title = null,
                detail = detail + " " + stringRes(R.string.settings_downloads_detaillibrary), // provenance-ok: joins two copy sentences
                icon = Tokens.Icons.globalDownload,
            )
            Spacer(Modifier.height(Tokens.Sizes.globalSectionGap))
            StatusArea(state)
        }
        Box(
            Modifier
                .fillMaxWidth()
                .navigationBarsPadding()
                .padding(horizontal = Tokens.Sizes.globalButtonMarginH)
                .padding(bottom = Tokens.Sizes.globalSectionGap),
        ) {
            if (state.running) {
                Capsule(stringRes(R.string.settings_downloads_cancel), onCancel, Modifier.fillMaxWidth().testTag(DownloadTags.CANCEL), style = CapsuleStyle.Outline)
            } else {
                PrimaryButton(
                    stringRes(if (state.canResume) R.string.settings_downloads_resume else R.string.settings_downloads_start),
                    onStart,
                    Modifier.testTag(DownloadTags.START),
                )
            }
        }
    }
    if (state.denied) {
        SystemAppearance {
            SystemAlertDialog(
                title = stringRes(R.string.settings_downloads_denied_title),
                text = stringRes(R.string.settings_downloads_denied_message),
                confirmLabel = stringRes(R.string.settings_downloads_denied_button),
                onConfirm = onOpenSettings,
                dismissLabel = stringRes(R.string.settings_downloads_cancel),
                onDismiss = onDismissDenied,
            )
        }
    }
}

@Composable
private fun StatusArea(state: DownloadUiState) {
    val line = when (state.phase) {
        DownloadUiState.Phase.Running -> stringRes(R.string.settings_downloads_progress)
        DownloadUiState.Phase.Done -> stringRes(R.string.settings_downloads_done)
        DownloadUiState.Phase.Empty -> stringRes(R.string.settings_downloads_empty)
        DownloadUiState.Phase.Failed -> stringRes(R.string.settings_downloads_error)
        DownloadUiState.Phase.Offline -> stringRes(R.string.settings_downloads_offline)
        DownloadUiState.Phase.Idle -> null
    } ?: return
    Column(Modifier.fillMaxWidth().padding(horizontal = Tokens.Sizes.globalScreenMargin), horizontalAlignment = Alignment.CenterHorizontally) {
        if (state.running) {
            // Read as "Downloading…", never as a figure (tenet 2).
            val bar = Modifier
                .fillMaxWidth()
                .testTag(DownloadTags.PROGRESS)
                .clearAndSetSemantics { contentDescription = line; stateDescription = line }
            val fraction = state.fraction
            if (fraction != null) {
                LinearProgressIndicator(progress = { fraction }, modifier = bar, color = Tokens.Colors.globalAccent, trackColor = Tokens.Colors.globalControl)
            } else {
                LinearProgressIndicator(modifier = bar, color = Tokens.Colors.globalAccent, trackColor = Tokens.Colors.globalControl)
            }
            Spacer(Modifier.height(Tokens.Sizes.globalListGap))
        }
        Text(
            line,
            style = TextRoles.body,
            color = PageRoles.secondaryText(),
            textAlign = TextAlign.Center,
            modifier = if (state.running) Modifier.clearAndSetSemantics { } else Modifier.semantics { },
        )
    }
}

/** The C-02 back glyph on its own: `icon.global.back`, its ink `size.global.backInset` from the leading edge. */
@Composable
private fun BackGlyph(contentDescription: String, onClick: () -> Unit) {
    val back = Tokens.Icons.globalBack
    val box = Tokens.Sizes.globalIcon
    val hit = max(Tokens.Sizes.globalHeaderButton, Tokens.Sizes.globalMinTouchTargetAndroid)
    val start = (Tokens.Sizes.globalBackInset - GlyphInk.leading(back, box) - (hit - box) / 2).coerceAtLeast(0.dp)
    Box(Modifier.padding(start = start)) { HeaderIconButton(back, contentDescription, onClick) }
}
