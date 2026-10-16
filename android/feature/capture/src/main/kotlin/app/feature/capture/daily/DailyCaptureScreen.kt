// Surface: daily.capture (+ daily.dualimage in its preview). Retro has no camera: this full-screen cover is
// composed from Retro components on the media surface (RC-12, RC-13) — C-29 sheet header with the countdown in the
// title slot and a C-11 close circle, the photo container as viewfinder, the C-35 control row, a C-11 glass circle
// on the photo, a C-09 pill, the C-05 capsule, C-27 / C-28 blocks. Mechanics: BeReal (window countdown, back +
// front, sequential fallback, retake). References: references/auto/retro/store/retro-store-03.png (ST-03: header,
// 20-pt photo gap, pill on a photo, capsule position); references/auto/retro/press/tc-2025-12-rewind-device-a.png
// (control row, glass circle); references/auto/bereal/frames/appstore-preview-2026_t3.50s_capture.png (mechanics).
package app.feature.capture.daily

import android.Manifest
import android.content.Intent
import android.net.Uri
import android.provider.Settings
import android.text.format.DateUtils
import androidx.activity.compose.BackHandler
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.camera.compose.CameraXViewfinder
import androidx.compose.animation.Crossfade
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.asPaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.paddingFrom
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBars
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.produceState
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.painter.BitmapPainter
import androidx.compose.ui.graphics.painter.Painter
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.layout.FirstBaseline
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.LocalLifecycleOwner
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import app.designsystem.R
import app.designsystem.generated.Tokens
import app.feature.capture.camera.CameraControllers
import app.feature.capture.camera.photoSize
import app.feature.capture.data.CaptureDataProvider
import app.feature.capture.data.CaptureHandoff
import app.feature.capture.sendto.decodePreview
import app.feature.capture.ui.ControlRow
import app.feature.capture.ui.CrossfadeText
import app.feature.capture.ui.DualImage
import app.feature.capture.ui.MediaControlCircle
import app.feature.capture.ui.MediaEmptyState
import app.feature.capture.ui.MediaLabelPill
import app.feature.capture.ui.MediaProgressBlock
import app.feature.capture.ui.MediaSheetHeader
import app.feature.capture.ui.OnMedia
import app.feature.capture.ui.SheetTitleText
import app.feature.capture.ui.Shutter
import app.feature.capture.ui.TABULAR_DIGITS
import app.feature.capture.ui.bottomClearance
import app.media.MediaPermission
import app.media.MediaPermissions
import app.model.CountdownState
import app.model.ServerClock
import app.model.SessionPromptGate
import app.push.InvitationClock
import app.ui.components.CircleButtonStyle
import app.ui.components.CircleIconButton
import app.ui.components.EmptyStateAction
import app.ui.components.PlatformToast
import app.ui.components.PrimaryButton
import app.ui.foundation.DsMotion
import app.ui.foundation.FadeVisibility
import app.ui.haptics.rememberHaptics
import app.ui.system.SystemAlertDialog
import app.ui.text.CapTop
import app.ui.text.TextRoles
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.util.Locale

/** The daily-capture destination (full-screen cover; status bar visible, light content). */
@Composable
fun DailyCaptureRoute(groupId: String, invitationId: String, onDismiss: () -> Unit) {
    val context = LocalContext.current
    val lifecycleOwner = LocalLifecycleOwner.current
    val haptics = rememberHaptics()
    val vm: DailyCaptureViewModel = viewModel(key = "daily:$invitationId") {
        DailyCaptureViewModel(
            data = CaptureDataProvider.get(context),
            gate = SessionPromptGate.process,
            captureDir = CaptureHandoff.dir(context),
            groupId = groupId,
            invitationId = invitationId,
            clock = ServerClock(InvitationClock.offset(invitationId) ?: java.time.Duration.ZERO),
            sizeOf = ::photoSize,
        )
    }
    app.feature.capture.ui.MediaSystemBars()
    val state by vm.ui.collectAsStateWithLifecycle()
    val controller = remember(lifecycleOwner) { CameraControllers.factory(context, lifecycleOwner) }
    val permission = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
        MediaPermissions.markRequested(context, MediaPermission.Camera)
        vm.onPermission(granted)
        if (granted) vm.attach(controller)
    }
    LaunchedEffect(Unit) {
        if (MediaPermissions.isGranted(context, MediaPermission.Camera)) {
            vm.onPermission(true)
            vm.attach(controller)
        } else {
            permission.launch(Manifest.permission.CAMERA)
        }
    }
    LaunchedEffect(vm) {
        vm.event.collect { event ->
            when (event) {
                is DailyCaptureViewModel.Event.Sent -> {
                    haptics.perform(Tokens.Haptics.globalSend)
                    event.groupName?.let { PlatformToast.show(context, context.getString(R.string.camera_sendto_toast_postedone, it)) }
                    onDismiss()
                }
                DailyCaptureViewModel.Event.Failed -> haptics.perform(Tokens.Haptics.globalError)
            }
        }
    }
    DisposableEffect(controller) {
        onDispose { kotlinx.coroutines.MainScope().launch { runCatching { controller.unbind() } } }
    }
    BackHandler(enabled = !state.sending) { vm.discard(); onDismiss() }
    val preview by controller.preview.collectAsStateWithLifecycle()
    // Decoded at about the screen width (the frame is the screen width minus the margins).
    val targetPx = context.resources.displayMetrics.widthPixels
    val mainImage by produceState<Painter?>(null, state.main) {
        value = state.main?.let { withContext(Dispatchers.IO) { decodePreview(it, targetPx) } }?.let(::BitmapPainter)
    }
    val insetImage by produceState<Painter?>(null, state.inset) {
        value = state.inset?.let { withContext(Dispatchers.IO) { decodePreview(it, targetPx / INSET_DECODE_DIVISOR) } }?.let(::BitmapPainter)
    }

    DailyCaptureScreen(
        state = state,
        viewfinder = { preview?.let { CameraXViewfinder(surfaceRequest = it, modifier = Modifier.fillMaxSize(), contentScale = ContentScale.Crop) } },
        mainImage = mainImage,
        insetImage = insetImage,
        onDismiss = { vm.discard(); onDismiss() },
        onFlash = vm::toggleFlash,
        onFlip = vm::flip,
        onShutter = vm::capture,
        onRetake = vm::retake,
        onSend = vm::send,
        onRetrySend = vm::retrySend,
        onDismissSendError = vm::dismissSendError,
        onOpenSettings = {
            context.startActivity(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.fromParts("package", context.packageName, null)).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        },
        onRetry = vm::startSession,
    )
}

/** The inset is about a third of the main width (0.31 W): decode it that much smaller. */
private const val INSET_DECODE_DIVISOR = 3 // provenance-ok: decode size only (daily.dualimage insetWidthRatio ≈ 1/3), nothing drawn from it

/**
 * The daily capture cover (stateless): live → capturing → preview on `color.global.backgroundDeep`. Header
 * `camera.sendto.layout.header`; viewfinder `daily.capture.layout.viewfinder` (3:4, 16 margins, 18 corners, 20 below
 * the close circle); the control row centred between the viewfinder and the safe-area bottom; in the preview the
 * C-05 capsule at `camera.sendto.size.sendButtonBottom`.
 */
@Composable
fun DailyCaptureScreen(
    state: DailyCaptureViewModel.UiState,
    viewfinder: @Composable () -> Unit,
    mainImage: Painter?,
    insetImage: Painter?,
    onDismiss: () -> Unit,
    onFlash: () -> Unit,
    onFlip: () -> Unit,
    onShutter: () -> Unit,
    onRetake: () -> Unit,
    onSend: () -> Unit,
    onRetrySend: () -> Unit,
    onDismissSendError: () -> Unit,
    onOpenSettings: () -> Unit,
    onRetry: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val previewing = state.phase == DailyCaptureViewModel.Phase.Preview
    val capturing = state.phase == DailyCaptureViewModel.Phase.Capturing
    val denied = state.permission == DailyCaptureViewModel.Permission.Denied
    val unavailable = !denied && state.session == DailyCaptureViewModel.Session.Unavailable
    val controls = !denied && !unavailable && state.permission == DailyCaptureViewModel.Permission.Granted
    val margin = Tokens.Sizes.globalScreenMargin
    val navBar = WindowInsets.navigationBars.asPaddingValues().calculateBottomPadding()
    Column(
        modifier
            .fillMaxSize()
            .background(Tokens.Colors.globalBackgroundDeep)
            .windowInsetsPadding(WindowInsets.statusBars)
            .testTag("daily.capture"),
    ) {
        MediaSheetHeader(
            trailing = {
                CircleIconButton(Tokens.Icons.globalClose, stringResource(R.string.daily_capture_a11y_dismiss), onDismiss, Modifier.testTag("daily.dismiss"), style = CircleButtonStyle.OnMedia, enabled = !state.sending)
            },
        ) { centre -> TitleSlot(state.countdown, state.groupName, centre) }
        Spacer(Modifier.height(Dp(Tokens.Layouts.CameraSendtoLayoutPreview.topBelowHeaderCircle)))
        BoxWithConstraints(Modifier.weight(1f).fillMaxWidth()) {
            // The frame keeps one size through live → preview: room for the control row (shutter + a margin above
            // and below) and for the capsule at its measured bottom.
            val below = maxOf(
                Tokens.Sizes.cameraCaptureSizeShutterOuter + margin * 2 + navBar,
                Tokens.Sizes.globalButtonHeight + bottomClearance(Tokens.Sizes.cameraSendtoSizeSendButtonBottom) + margin,
            )
            val vfHeight = minOf((maxWidth - margin * 2) / Tokens.Layouts.DailyCaptureLayoutViewfinder.aspect, maxHeight - below).coerceAtLeast(0.dp)
            val vfWidth = vfHeight * Tokens.Layouts.DailyCaptureLayoutViewfinder.aspect
            Column(Modifier.fillMaxSize(), horizontalAlignment = Alignment.CenterHorizontally) {
                Frame(state, viewfinder, mainImage, insetImage, denied, unavailable, onRetake, onOpenSettings, onRetry, Modifier.size(vfWidth, vfHeight))
                Box(Modifier.weight(1f).fillMaxWidth()) {
                    FadeVisibility(visible = controls && !previewing && !capturing, modifier = Modifier.fillMaxSize().padding(bottom = navBar)) {
                        ControlRow(
                            modifier = Modifier.fillMaxSize(),
                            leading = if (state.hasFlash) {
                                {
                                    MediaControlCircle(
                                        if (state.flashOn) Tokens.Icons.globalFlashOn else Tokens.Icons.globalFlashOff,
                                        stringResource(R.string.daily_capture_a11y_flash),
                                        onFlash,
                                        Modifier.testTag("daily.flash"),
                                        stateDescription = stringResource(if (state.flashOn) R.string.daily_capture_a11y_flashon else R.string.daily_capture_a11y_flashoff),
                                    )
                                }
                            } else {
                                null
                            },
                            trailing = { MediaControlCircle(Tokens.Icons.globalFlip, stringResource(R.string.daily_capture_a11y_flip), onFlip, Modifier.testTag("daily.flip")) },
                        ) {
                            Shutter(stringResource(R.string.daily_capture_a11y_shutter), onTap = onShutter, modifier = Modifier.testTag("daily.shutter"))
                        }
                    }
                    FadeVisibility(visible = previewing, modifier = Modifier.align(Alignment.BottomCenter)) {
                        OnMedia {
                            PrimaryButton(
                                text = stringResource(R.string.daily_capture_send),
                                onClick = onSend,
                                loading = state.sending,
                                onMedia = true,
                                modifier = Modifier
                                    .padding(horizontal = Tokens.Sizes.globalButtonMarginH)
                                    .padding(bottom = bottomClearance(Tokens.Sizes.cameraSendtoSizeSendButtonBottom))
                                    .testTag("daily.send"),
                            )
                        }
                    }
                }
            }
        }
    }
    state.sendFailedOffline?.let { offline ->
        SystemAlertDialog(
            title = stringResource(R.string.camera_sendto_error_sendfailed),
            text = stringResource(if (offline) R.string.camera_sendto_error_offline else R.string.camera_sendto_error_generic),
            confirmLabel = stringResource(R.string.camera_sendto_error_retry),
            onConfirm = onRetrySend,
            dismissLabel = stringResource(R.string.camera_sendto_cancel),
            onDismiss = onDismissSendError,
        )
    }
}

/**
 * The title slot: while the window is open the countdown `daily.capture.countdown` (MM:SS, text role `sheetTitle`,
 * monospaced digits, changed digits cross-fade); after `closes_at` the group name in the same role, cross-faded.
 * TalkBack reads the remaining time as the platform's elapsed-time string.
 */
@Composable
private fun TitleSlot(countdown: CountdownState.Open?, groupName: String?, capMiddle: Dp) {
    val style = TextRoles.sheetTitle.copy(fontFeatureSettings = TABULAR_DIGITS)
    Crossfade(countdown != null, animationSpec = DsMotion.crossfade(), label = "titleSlot") { open ->
        if (open && countdown != null) {
            val seconds = countdown.remainingSeconds
            CrossfadeText(
                countdownText(seconds),
                style = style,
                color = Tokens.Colors.globalTextOnMedia,
                modifier = Modifier
                    .paddingFrom(FirstBaseline, before = capMiddle + CapTop.height(style) / 2)
                    .clearAndSetSemantics {
                        heading()
                        stateDescription = DateUtils.formatElapsedTime(seconds)
                    }
                    .testTag("daily.countdown"),
            )
        } else if (groupName != null) {
            SheetTitleText(groupName, capMiddle, Tokens.Colors.globalTextOnMedia)
        }
    }
}

/** MM:SS of [seconds] through the copy pattern `daily.capture.countdown` ("{mm}:{ss}"). */
@Composable
internal fun countdownText(seconds: Long): String {
    val m = seconds / SECONDS_PER_MINUTE
    val s = seconds % SECONDS_PER_MINUTE
    return stringResource(R.string.daily_capture_countdown, String.format(Locale.ROOT, TWO_DIGITS, m), String.format(Locale.ROOT, TWO_DIGITS, s))
}

private const val SECONDS_PER_MINUTE = 60L // provenance-ok: unit conversion
private const val TWO_DIGITS = "%02d" // provenance-ok: MM:SS digit format of the copy pattern

/**
 * The frame (`daily.capture.layout.viewfinder`): live preview (fading in after the first frame), the capturing
 * block (C-28 indicator + `daily.capture.prompt`), the preview — the dual image with the frame's corners, the
 * retake glass circle (C-11 `Glass`, 40) `size.global.badgeInset` from the top and trailing edges, the audience pill
 * (C-09 dark, `icon.global.group`) centred `camera.sendto.layout.messageField.bottomInset` above the bottom — or the
 * C-27 blocks of `camera.capture` (denied / unavailable).
 */
@Composable
private fun Frame(
    state: DailyCaptureViewModel.UiState,
    viewfinder: @Composable () -> Unit,
    mainImage: Painter?,
    insetImage: Painter?,
    denied: Boolean,
    unavailable: Boolean,
    onRetake: () -> Unit,
    onOpenSettings: () -> Unit,
    onRetry: () -> Unit,
    modifier: Modifier,
) {
    val previewing = state.phase == DailyCaptureViewModel.Phase.Preview
    val capturing = state.phase == DailyCaptureViewModel.Phase.Capturing
    Box(
        modifier
            .clip(RoundedCornerShape(Tokens.Radii.globalViewfinder))
            .background(Tokens.Colors.globalBackgroundDeep)
            .testTag("daily.viewfinder"),
        contentAlignment = Alignment.Center,
    ) {
        FadeVisibility(
            visible = !previewing && !capturing && state.permission == DailyCaptureViewModel.Permission.Granted && state.session == DailyCaptureViewModel.Session.Live,
            modifier = Modifier.fillMaxSize(),
        ) { Box(Modifier.fillMaxSize()) { viewfinder() } }
        FadeVisibility(visible = capturing) { MediaProgressBlock(stringResource(R.string.daily_capture_prompt)) }
        FadeVisibility(visible = previewing, modifier = Modifier.fillMaxSize()) {
            Box(Modifier.fillMaxSize()) {
                DualImage(
                    main = mainImage,
                    inset = insetImage,
                    contentDescription = stringResource(R.string.daily_dualimage_a11y_label, state.myName.orEmpty()),
                    cornerRadius = Tokens.Radii.globalViewfinder,
                    modifier = Modifier.fillMaxSize().testTag("daily.dualimage"),
                )
                CircleIconButton(
                    Tokens.Icons.globalClose,
                    stringResource(R.string.daily_capture_a11y_retake),
                    onRetake,
                    Modifier.align(Alignment.TopEnd).padding(top = Tokens.Sizes.globalBadgeInset, end = Tokens.Sizes.globalBadgeInset).testTag("daily.retake"),
                    style = CircleButtonStyle.Glass,
                    enabled = !state.sending,
                )
                state.groupName?.let { name ->
                    MediaLabelPill(
                        stringResource(R.string.daily_capture_audience, name),
                        Tokens.Icons.globalGroup,
                        Modifier.align(Alignment.BottomCenter).padding(bottom = Dp(Tokens.Layouts.CameraSendtoLayoutMessageField.bottomInset)).testTag("daily.audience"),
                    )
                }
            }
        }
        FadeVisibility(visible = denied) {
            MediaEmptyState(
                title = stringResource(R.string.camera_capture_denied_title),
                detail = stringResource(R.string.camera_capture_denied_detail),
                action = EmptyStateAction(stringResource(R.string.camera_capture_denied_button), onOpenSettings),
                icon = Tokens.Icons.globalCamera,
            )
        }
        FadeVisibility(visible = unavailable) {
            MediaEmptyState(
                title = stringResource(R.string.camera_capture_unavailable_title),
                detail = stringResource(R.string.camera_capture_unavailable_detail),
                action = EmptyStateAction(stringResource(R.string.camera_capture_unavailable_button), onRetry),
                icon = Tokens.Icons.globalCamera,
            )
        }
    }
}
