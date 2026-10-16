// Surface: birthday.tribute — design/surfaces/birthday.tribute.md (B. the tribute screen)
// References: references/auto/retro/press/tc-2025-12-rewind-device-a.png (serif title on the media page),
// references/auto/retro/store/retro-store-04.png (recap-preview bottom row), references/auto/retro/press/tc-2023-07-retro-2b.jpg phone 2 (media letterboxed).
package app.feature.memory.birthday

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.paddingFrom
import androidx.compose.foundation.layout.statusBars
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.layout.FirstBaseline
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.LineBreak
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.core.content.ContextCompat
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.LocalLifecycleOwner
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import app.designsystem.R
import app.designsystem.generated.Tokens
import app.designsystem.rememberReduceMotion
import app.feature.memory.common.CollectEffects
import app.feature.memory.common.LightSystemBarIcons
import app.feature.memory.common.MediaAppearance
import app.feature.memory.common.MediaMessage
import app.feature.memory.common.MemoryBackend
import app.feature.memory.common.RecapBottomRow
import app.feature.memory.common.SystemAppearance
import app.feature.memory.common.rememberMemoryBackend
import app.feature.memory.common.recapRowCentre
import app.feature.memory.share.MemoryFiles
import app.ui.components.ActivityIndicator
import app.ui.components.CircleButtonStyle
import app.ui.components.CircleIconButton
import app.ui.components.EmptyState
import app.ui.components.EmptyStateFill
import app.ui.components.PlatformToast
import app.ui.foundation.centreAt
import app.ui.foundation.endAtLastBaseline
import app.ui.recap.RecapPill
import app.ui.system.SystemAlertDialog
import app.ui.text.CapTop
import app.ui.text.TextRoles
import java.time.Clock

/** Test tags (flow tests). */
object TributeTags {
    const val ROOT = "birthday.tribute"
    const val SAVE = "birthday.tribute.save"
}

/** The tribute screen's actions. */
data class TributeActions(
    val onSave: () -> Unit = {},
    val onShare: () -> Unit = {},
    val onRetry: () -> Unit = {},
    val onClose: () -> Unit = {},
    val onToastShown: () -> Unit = {},
    val onDismissSaveDenied: () -> Unit = {},
    val onOpenSettings: () -> Unit = {},
)

/**
 * The birthday video's screen (birthday.tribute.md B), dark in both appearances: the C-35 header — the serif title
 * ("Your birthday video" for the honoree, "{name}'s birthday video" for anyone else; `headerTitle`, up to two lines,
 * leading `size.global.screenMargin`, baseline `size.global.titleTop`) with the group name under it (`textButton`,
 * `color.global.textSecondary`, `dimension.onthisday.subtitleBaseline` below) and the close circle on media (C-11) at
 * `size.global.headerInset`, centred on the title's cap middle; the 16:9 player full width, centred between the
 * header and the bar (native controls, the poster first); for the honoree only (owner decision 12), the recap
 * preview's bottom row — "Save to Camera Roll" circle and the white "Share" pill. Members watch it in the app.
 */
@Composable
fun TributeScreen(
    state: TributeState,
    autoplay: Boolean,
    player: TributePlayerHolder?,
    actions: TributeActions,
    modifier: Modifier = Modifier,
) {
    val context = LocalContext.current
    val toast = when (state.toast) {
        TributeState.Toast.Saved -> stringResource(R.string.birthday_tribute_saved)
        TributeState.Toast.SaveFailed -> stringResource(R.string.birthday_tribute_savefailed)
        null -> null
    }
    LaunchedEffect(toast) {
        if (toast != null) {
            PlatformToast.show(context, toast)
            actions.onToastShown()
        }
    }
    MediaAppearance {
        Box(modifier.fillMaxSize().background(Tokens.Colors.globalBackgroundDeep).testTag(TributeTags.ROOT)) {
            val content = state.content
            when (content) {
                TributeContent.NotFound -> EmptyStateFill { EmptyState(stringResource(R.string.birthday_tribute_notfound_title), null) }
                TributeContent.Failed, TributeContent.Offline -> EmptyStateFill {
                    val offline = content == TributeContent.Offline
                    MediaMessage(
                        stringResource(if (offline) R.string.birthday_tribute_offline_title else R.string.birthday_tribute_error_title),
                        stringResource(if (offline) R.string.birthday_tribute_offline else R.string.birthday_tribute_error_detail),
                        retry = stringResource(R.string.birthday_tribute_error_retry),
                        onRetry = actions.onRetry,
                    )
                }
                else -> Page(state, content, autoplay, player, actions)
            }
            if (content == TributeContent.NotFound || content == TributeContent.Failed || content == TributeContent.Offline) Header(null, null, actions.onClose)
        }
        if (state.saveDenied) {
            SystemAppearance {
                SystemAlertDialog(
                    title = stringResource(R.string.birthday_tribute_savedenied_title),
                    text = stringResource(R.string.birthday_tribute_savedenied_message),
                    confirmLabel = stringResource(R.string.birthday_tribute_savedenied_button),
                    onConfirm = actions.onOpenSettings,
                    dismissLabel = null,
                    onDismiss = actions.onDismissSaveDenied,
                )
            }
        }
    }
}

@Composable
private fun androidx.compose.foundation.layout.BoxScope.Page(state: TributeState, content: TributeContent, autoplay: Boolean, player: TributePlayerHolder?, actions: TributeActions) {
    val ready = content is TributeContent.Ready
    val title = when {
        state.forMe -> stringResource(R.string.birthday_tribute_title)
        state.honoreeName != null -> stringResource(R.string.birthday_tribute_title_member, state.honoreeName)
        else -> null
    }
    Column(Modifier.fillMaxSize()) {
        Header(title, state.groupName, actions.onClose)
        Box(Modifier.weight(1f).fillMaxWidth(), contentAlignment = Alignment.Center) {
            when (content) {
                is TributeContent.Ready -> TributePlayer(player, content.videoUrl, content.posterUrl, autoplay, Modifier.fillMaxWidth())
                else -> Box(Modifier.fillMaxWidth().aspectRatio(tributeAspect), contentAlignment = Alignment.Center) {
                    ActivityIndicator(stringResource(R.string.birthday_tribute_loading), onMedia = true)
                }
            }
        }
        // The player is centred between the header and the top of the bar (the pill's top edge).
        Spacer(Modifier.height(recapRowCentre() + Dp(Tokens.Layouts.CollageShareLayoutPill.height) / 2))
    }
    if (!state.forMe) return
    RecapBottomRow(
        leading = {
            CircleIconButton(
                Tokens.Icons.globalDownload,
                stringResource(R.string.birthday_tribute_download),
                actions.onSave,
                Modifier.testTag(TributeTags.SAVE),
                style = CircleButtonStyle.OnMedia,
                enabled = ready && !state.saving,
            )
        },
        pill = RecapPill(stringResource(R.string.birthday_tribute_share), actions.onShare, enabled = ready),
        modifier = Modifier.align(Alignment.BottomCenter),
    )
}

@Composable
private fun Header(title: String?, group: String?, onClose: () -> Unit) {
    val style = TextRoles.headerTitle.copy(lineBreak = LineBreak.Heading)
    val capMiddle = Tokens.Sizes.globalTitleTop - CapTop.height(style) / 2
    Box(Modifier.fillMaxWidth().windowInsetsPadding(WindowInsets.statusBars)) {
        if (title != null) {
            Column(Modifier.padding(start = Tokens.Sizes.globalScreenMargin, end = Tokens.Sizes.globalHeaderInset + Tokens.Sizes.globalCircleButton + Tokens.Sizes.globalHeaderGap)) {
                Text(
                    title,
                    style = style,
                    color = Tokens.Colors.globalTextOnMedia,
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis,
                    modifier = Modifier.paddingFrom(FirstBaseline, before = Tokens.Sizes.globalTitleTop).endAtLastBaseline().semantics { heading() },
                )
                if (group != null) {
                    Text(
                        group,
                        style = TextRoles.textButton,
                        color = Tokens.Colors.globalTextSecondary,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                        modifier = Modifier.paddingFrom(FirstBaseline, before = Tokens.Sizes.onthisdaySubtitleBaseline),
                    )
                }
            }
        }
        Box(Modifier.align(Alignment.TopEnd).padding(end = Tokens.Sizes.globalHeaderInset).centreAt(capMiddle)) {
            CircleIconButton(Tokens.Icons.globalClose, stringResource(R.string.birthday_tribute_a11y_close), onClose, style = CircleButtonStyle.OnMedia)
        }
    }
}

/** Opens the app's system settings page (the "Allow Photo Access" button of the denied alert). */
internal fun openAppSettings(context: android.content.Context) {
    val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.fromParts("package", context.packageName, null)).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
    runCatching { context.startActivity(intent) }
}

/** The tribute destination: loads the tribute, plays it, saves / shares the MP4. */
@Composable
fun TributeDestination(
    tributeId: String,
    onClose: () -> Unit,
    backend: MemoryBackend = rememberMemoryBackend(),
    files: TributeFiles? = null,
    clock: Clock = Clock.systemUTC(),
) {
    val context = LocalContext.current
    val vm = viewModel(key = "birthday.tribute/$tributeId") {
        TributeViewModel(tributeId, backend, files ?: AndroidTributeFiles(context), clock)
    }
    val state by vm.state.collectAsStateWithLifecycle()
    CollectEffects(vm.effects, onClose)
    LightSystemBarIcons()
    LaunchedEffect(vm) { vm.shareRequests.collect { uri -> context.startActivity(MemoryFiles.shareIntent(uri, MemoryFiles.MIME_MP4)) } }
    val lifecycle = LocalLifecycleOwner.current.lifecycle
    DisposableEffect(lifecycle, vm) {
        val observer = LifecycleEventObserver { _, event -> if (event == Lifecycle.Event.ON_RESUME) vm.refreshIfRendering() }
        lifecycle.addObserver(observer)
        onDispose { lifecycle.removeObserver(observer) }
    }
    // API 26-28: MediaStore writes need WRITE_EXTERNAL_STORAGE (maxSdkVersion 28 in the manifest).
    val askWrite = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { granted -> vm.save(granted) }
    val reduceMotion by rememberReduceMotion()
    // Created on open (while the tribute row loads) and prepared as soon as the URL is known.
    val player = rememberTributePlayerHolder()
    TributeScreen(
        state = state,
        autoplay = !reduceMotion,
        player = player,
        actions = TributeActions(
            onSave = {
                val legacy = Build.VERSION.SDK_INT < Build.VERSION_CODES.Q
                if (legacy && ContextCompat.checkSelfPermission(context, Manifest.permission.WRITE_EXTERNAL_STORAGE) != PackageManager.PERMISSION_GRANTED) {
                    askWrite.launch(Manifest.permission.WRITE_EXTERNAL_STORAGE)
                } else {
                    vm.save()
                }
            },
            onShare = vm::share,
            onRetry = vm::retry,
            onClose = onClose,
            onToastShown = vm::dismissToast,
            onDismissSaveDenied = vm::dismissSaveDenied,
            onOpenSettings = {
                vm.dismissSaveDenied()
                openAppSettings(context)
            },
        ),
    )
}
