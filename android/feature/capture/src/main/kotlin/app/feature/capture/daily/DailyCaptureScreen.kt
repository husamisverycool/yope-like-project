// Surfaces: daily.capture (+ daily.dualimage for the preview).
// References: references/auto/bereal/frames/appstore-preview-2026_t3.50s_capture.png (live layout: chevron, countdown,
// 3:4 viewfinder, flash / shutter / flip); appstore-preview-2026_timer-roll_f086-f129.png (countdown roll);
// tiktok-bereal-7339559678604627233_shutter-press_f518-f546.jpg, _capture-seq_f540-f681.jpg, _t17.63s_black-spinner-prompt.png,
// _t18.97s_back-photo-prompt.png (capture sequence); _t21.30s_preview-keep-smiling.png (preview: retake, chip, SEND);
// references/auto/bereal/help/help-21083708285725_bts-post-preview-2x.png (preview geometry);
// references/auto/bereal/help/help-21083730354333_feed-bonus-3x.png (dual image).
package app.feature.capture.daily

import android.Manifest
import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.provider.Settings
import androidx.activity.compose.BackHandler
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.camera.compose.CameraXViewfinder
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.paddingFromBaseline
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicText
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.produceState
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.isTraversalGroup
import androidx.compose.ui.semantics.onClick
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.semantics.traversalIndex
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.unit.dp
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import androidx.lifecycle.compose.LocalLifecycleOwner
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import app.designsystem.MotionChannel
import app.designsystem.R
import app.designsystem.dsAnimateAlphaAsState
import app.designsystem.dsAnimateFloatAsState
import app.designsystem.generated.Tokens
import app.feature.capture.Blocked
import app.feature.capture.camera.CameraControllers
import app.feature.capture.camera.photoSize
import app.feature.capture.data.CaptureDataProvider
import app.feature.capture.data.CaptureHandoff
import app.feature.capture.data.CaptureServices
import app.feature.capture.sendto.decodePreview
import app.feature.capture.ui.CaptureText
import app.feature.capture.ui.CaptureToastHost
import app.feature.capture.ui.CapsuleShape
import app.feature.capture.ui.CircleIconButton
import app.feature.capture.ui.DualImage
import app.feature.capture.ui.EmptyStateBlock
import app.feature.capture.ui.Glyph
import app.feature.capture.ui.LimeToast
import app.feature.capture.ui.MinTouchTargets
import app.feature.capture.ui.ShutterDisc
import app.feature.capture.ui.glyphTopToBaseline
import app.feature.capture.ui.haptic
import app.feature.capture.ui.springWithResponse
import app.media.MediaPermission
import app.media.MediaPermissions
import app.model.ServerClock
import app.model.SessionPromptGate
import app.push.InvitationClock
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

/** The daily-capture destination (full-screen cover, status bar hidden). */
@Composable
fun DailyCaptureRoute(groupId: String, invitationId: String, onDismiss: () -> Unit) {
    val context = LocalContext.current
    val lifecycleOwner = LocalLifecycleOwner.current
    val view = LocalView.current
    val vm: DailyCaptureViewModel = viewModel(key = "daily:$invitationId") {
        DailyCaptureViewModel(
            data = CaptureDataProvider.get(context),
            tracker = CaptureServices.tracker(context),
            gate = SessionPromptGate.process,
            captureDir = CaptureHandoff.dir(context),
            groupId = groupId,
            invitationId = invitationId,
            clock = ServerClock(InvitationClock.offset(invitationId) ?: java.time.Duration.ZERO),
            sizeOf = ::photoSize,
        )
    }
    val state by vm.ui.collectAsStateWithLifecycle()
    val controller = remember(lifecycleOwner) { CameraControllers.factory(context, lifecycleOwner) }
    val scope = rememberCoroutineScope()
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
        vm.event.collect {
            if (it == DailyCaptureViewModel.Event.Sent) {
                // Optimistic: queued = sent (it uploads in the background); a later failure shows the
                // error toast with haptic.global.error.
                view.haptic(Tokens.Haptics.globalSend)
                onDismiss()
            }
        }
    }
    // Status bar hidden while the cover shows (as in the reference).
    DisposableEffect(view) {
        val window = (view.context as? Activity)?.window
        val insets = window?.let { WindowCompat.getInsetsController(it, view) }
        insets?.hide(WindowInsetsCompat.Type.statusBars())
        onDispose {
            insets?.show(WindowInsetsCompat.Type.statusBars())
            scope.launch { runCatching { controller.unbind() } }
        }
    }
    BackHandler { vm.discard(); onDismiss() }
    val preview by controller.preview.collectAsStateWithLifecycle()
    val density = LocalDensity.current
    val targetPx = with(density) { Tokens.Layouts.DailyCaptureLayoutViewfinder.width.dp.roundToPx() }
    val mainImage by produceState<ImageBitmap?>(null, state.main) { value = state.main?.let { withContext(Dispatchers.IO) { decodePreview(it, targetPx) } } }
    val insetImage by produceState<ImageBitmap?>(null, state.inset) { value = state.inset?.let { withContext(Dispatchers.IO) { decodePreview(it, targetPx / 3) } } }

    DailyCaptureScreen(
        state = state,
        viewfinder = { preview?.let { CameraXViewfinder(surfaceRequest = it, modifier = Modifier.fillMaxSize(), contentScale = ContentScale.Crop) } },
        mainImage = mainImage,
        insetImage = insetImage,
        posterName = null,
        onDismiss = { vm.discard(); onDismiss() },
        onFlash = vm::toggleFlash,
        onFlip = vm::flip,
        onShutter = vm::capture,
        onRetake = vm::retake,
        onSend = vm::send,
        onOpenSettings = {
            context.startActivity(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.fromParts("package", context.packageName, null)).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        },
        onRetry = vm::startSession,
    )
}

/** The daily capture cover (stateless): live → capturing → preview. Positions per `daily.capture.layout.*`. */
@Composable
fun DailyCaptureScreen(
    state: DailyCaptureViewModel.UiState,
    viewfinder: @Composable () -> Unit,
    mainImage: ImageBitmap?,
    insetImage: ImageBitmap?,
    posterName: String?,
    onDismiss: () -> Unit,
    onFlash: () -> Unit,
    onFlip: () -> Unit,
    onShutter: () -> Unit,
    onRetake: () -> Unit,
    onSend: () -> Unit,
    onOpenSettings: () -> Unit,
    onRetry: () -> Unit,
    modifier: Modifier = Modifier,
) = MinTouchTargets {
    val text = Tokens.Colors.dailyCaptureColorText
    val vf = Tokens.Layouts.DailyCaptureLayoutViewfinder
    val capturing = state.phase == DailyCaptureViewModel.Phase.Capturing
    val previewing = state.phase == DailyCaptureViewModel.Phase.Preview

    BoxWithConstraints(
        modifier
            .fillMaxSize()
            .background(Tokens.Colors.globalBackgroundDeep)
            .semantics { isTraversalGroup = true }
            .testTag("daily.capture"),
    ) {
        val width = maxWidth
        val vfWidth = width - vf.sideMargin.dp * 2
        val vfHeight = vfWidth / vf.aspect

        // Dismiss chevron.
        val d = Tokens.Layouts.DailyCaptureLayoutDismiss
        val chevron = Tokens.Sizes.globalMinTouchTargetAndroid
        CircleIconButton(
            icon = Tokens.Icons.globalChevronDown,
            contentDescription = stringResource(R.string.daily_capture_a11y_dismiss),
            diameter = chevron,
            fill = null,
            tint = text,
            onClick = onDismiss,
            modifier = Modifier.offset(x = d.centerFromLeading.dp - chevron / 2, y = d.centerFromTop.dp - chevron / 2).semantics { traversalIndex = 0f },
        )

        // Countdown: digit tops at countdown.digitsTop, centred (weight BLOCKED → omitted in release).
        val weight = Blocked.countdownWeight
        if (weight != null) {
            val toBaseline = glyphTopToBaseline(Tokens.FontSizes.dailyCaptureFontSizeCountdown, weight, DIGIT_SAMPLE)
            Box(Modifier.fillMaxWidth(), contentAlignment = Alignment.TopCenter) {
                CountdownText(
                    countdown = state.countdown,
                    weight = weight,
                    modifier = Modifier
                        .paddingFromBaseline(top = Tokens.Layouts.DailyCaptureLayoutCountdown.digitsTop.dp + toBaseline)
                        .semantics { traversalIndex = 1f },
                )
            }
        }

        // Viewfinder / capture area / preview image.
        Box(
            Modifier
                .offset(x = vf.sideMargin.dp, y = vf.top.dp)
                .size(vfWidth, vfHeight)
                .semantics { traversalIndex = 2f },
        ) {
            if (previewing) {
                DualImage(
                    main = mainImage,
                    inset = insetImage,
                    contentDescription = posterName?.let { stringResource(R.string.daily_dualimage_a11y_label, it) },
                    modifier = Modifier.fillMaxWidth().testTag("daily.dualimage"),
                )
                PreviewOverlay(state.groupName, onRetake)
            } else {
                LiveArea(state, capturing, viewfinder, mainImage, onOpenSettings, onRetry)
            }
        }

        if (previewing) {
            SendLabel(onSend, Modifier.padding(top = vf.top.dp + vfHeight))
        } else if (state.permission == DailyCaptureViewModel.Permission.Granted && state.session != DailyCaptureViewModel.Session.Unavailable) {
            ControlRow(state, capturing, onFlash, onFlip, onShutter)
        }

        if (state.sendError != null) {
            Box(Modifier.fillMaxWidth().padding(top = Tokens.Layouts.CameraSendtoLayoutToast.top.dp)) {
                LimeToast(
                    text = stringResource(if (state.sendError == app.data.error.DataError.Network) R.string.camera_sendto_error_offline else R.string.camera_sendto_error_sendfailed),
                    actionLabel = stringResource(R.string.camera_sendto_error_retry),
                    onAction = onSend,
                )
            }
        }
        CaptureToastHost()
    }
}

@Composable
private fun LiveArea(
    state: DailyCaptureViewModel.UiState,
    capturing: Boolean,
    viewfinder: @Composable () -> Unit,
    firstImage: ImageBitmap?,
    onOpenSettings: () -> Unit,
    onRetry: () -> Unit,
) {
    val vf = Tokens.Layouts.DailyCaptureLayoutViewfinder
    val seq = Tokens.Layouts.DailyCaptureLayoutCaptureSequence
    val text = Tokens.Colors.dailyCaptureColorText
    // Capturing: the viewfinder fades to black, then spinner + prompt; the first photo fades in behind them.
    val blackout by dsAnimateAlphaAsState(if (capturing) 1f else 0f, springWithResponse(seq.viewfinderFadeOut).spec(), label = "blackout") // provenance-ok: animation debug label (tooling only)
    val firstIn by dsAnimateAlphaAsState(if (capturing && state.firstTaken) 1f else 0f, springWithResponse(seq.backPhotoFadeIn).spec(), label = "firstIn") // provenance-ok: animation debug label (tooling only)
    Box(
        Modifier
            .fillMaxSize()
            .clip(RoundedCornerShape(vf.cornerRadius.dp))
            .background(Tokens.Colors.globalBackgroundDeep)
            .testTag("daily.viewfinder"),
    ) {
        when {
            state.permission == DailyCaptureViewModel.Permission.Denied -> EmptyStateBlock(
                title = stringResource(R.string.camera_capture_denied_title),
                detail = stringResource(R.string.camera_capture_denied_detail),
                buttonLabel = stringResource(R.string.camera_capture_denied_button),
                onButton = onOpenSettings,
                modifier = Modifier.align(Alignment.Center),
            )
            state.session == DailyCaptureViewModel.Session.Unavailable -> EmptyStateBlock(
                title = stringResource(R.string.camera_capture_unavailable_title),
                detail = stringResource(R.string.camera_capture_unavailable_detail),
                buttonLabel = stringResource(R.string.camera_capture_unavailable_button),
                onButton = onRetry,
                modifier = Modifier.align(Alignment.Center),
            )
            state.permission == DailyCaptureViewModel.Permission.Granted -> {
                viewfinder()
                Box(Modifier.fillMaxSize().alpha(blackout).background(Tokens.Colors.globalBackgroundDeep))
                if (firstImage != null) {
                    Image(firstImage, contentDescription = null, contentScale = ContentScale.Crop, modifier = Modifier.fillMaxSize().alpha(firstIn))
                }
                if (capturing) {
                    Column(Modifier.align(Alignment.Center), horizontalAlignment = Alignment.CenterHorizontally) {
                        CircularProgressIndicator(color = text, modifier = Modifier.size(Tokens.Sizes.dailyCaptureSizeProgress).testTag("daily.progress"))
                        Spacer(Modifier.height(Tokens.Layouts.DailyCaptureLayoutPrompt.gapBelowSpinner.dp))
                        BasicText(
                            stringResource(R.string.daily_capture_prompt),
                            style = CaptureText.style(Tokens.FontSizes.dailyCaptureFontSizePrompt, null).merge(TextStyle(color = text)),
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun ControlRow(state: DailyCaptureViewModel.UiState, capturing: Boolean, onFlash: () -> Unit, onFlip: () -> Unit, onShutter: () -> Unit) {
    val sh = Tokens.Layouts.DailyCaptureLayoutShutter
    val side = Tokens.Layouts.DailyCaptureLayoutSideControls
    val seq = Tokens.Layouts.DailyCaptureLayoutCaptureSequence
    val text = Tokens.Colors.dailyCaptureColorText
    var pressed by remember { mutableStateOf(false) }
    // Press → pressScale (press ms); capturing → the shutter shrinks to 0 (controlsOut ms); flash and flip go.
    val scale by dsAnimateFloatAsState(
        targetValue = when {
            capturing -> 0f
            pressed -> seq.pressScale
            else -> 1f
        },
        animationSpec = springWithResponse(if (capturing) seq.controlsOut else seq.press).spec(),
        channel = MotionChannel.Movement,
        label = "dailyShutter", // provenance-ok: animation debug label (tooling only)
    )
    val controlsAlpha by dsAnimateAlphaAsState(if (capturing) 0f else 1f, springWithResponse(seq.controlsOut).spec(), label = "controls") // provenance-ok: animation debug label (tooling only)
    val flashLabel = stringResource(R.string.daily_capture_a11y_flash)
    val flashValue = stringResource(if (state.flashOn) R.string.daily_capture_a11y_flashon else R.string.daily_capture_a11y_flashoff)
    val shutterLabel = stringResource(R.string.daily_capture_a11y_shutter)
    BoxWithConstraints(Modifier.fillMaxSize()) {
        val centerY = maxHeight - sh.centerFromBottom.dp
        val touch = Tokens.Sizes.globalMinTouchTargetAndroid
        if (state.hasFlash) {
            Box(
                Modifier
                    .offset(x = side.flashCenterFromLeading.dp - touch / 2, y = centerY - touch / 2)
                    .size(touch)
                    .alpha(controlsAlpha)
                    .clickable(enabled = !capturing, onClick = onFlash)
                    .semantics {
                        contentDescription = flashLabel
                        stateDescription = flashValue
                        role = Role.Button
                        traversalIndex = 3f
                    },
                contentAlignment = Alignment.Center,
            ) { Glyph(if (state.flashOn) Tokens.Icons.globalFlashOn else Tokens.Icons.globalFlashOff, text, null) }
        }
        Box(
            Modifier
                .offset(x = maxWidth / 2 - sh.outer.dp / 2, y = centerY - sh.outer.dp / 2)
                .size(sh.outer.dp)
                .graphicsLayer { scaleX = scale; scaleY = scale }
                .pointerInput(capturing) {
                    if (!capturing) detectTapGestures(onPress = { pressed = true; tryAwaitRelease(); pressed = false }, onTap = { onShutter() })
                }
                .semantics {
                    contentDescription = shutterLabel
                    role = Role.Button
                    onClick { onShutter(); true }
                    traversalIndex = 4f
                }
                .testTag("daily.shutter"),
        ) {
            ShutterDisc(
                outer = sh.outer.dp,
                ring = sh.ring.dp,
                disc = sh.disc.dp,
                ringColor = Tokens.Colors.globalSurfaceLight,
                gapColor = Tokens.Colors.globalBackgroundDeep,
                discColor = Tokens.Colors.globalSurfaceLight,
            )
        }
        CircleIconButton(
            icon = Tokens.Icons.globalFlip,
            contentDescription = stringResource(R.string.daily_capture_a11y_flip),
            diameter = touch,
            fill = null,
            tint = text,
            onClick = { if (!capturing) onFlip() },
            modifier = Modifier
                .offset(x = maxWidth - side.flipCenterFromTrailing.dp - touch / 2, y = centerY - touch / 2)
                .alpha(controlsAlpha)
                .semantics { traversalIndex = 5f },
        )
    }
}

/** Retake ✕ (top-trailing) and the audience chip (bottom centre) over the preview image. */
@Composable
private fun PreviewOverlay(groupName: String?, onRetake: () -> Unit) {
    val r = Tokens.Layouts.DailyCaptureLayoutRetake
    val chip = Tokens.Layouts.DailyCaptureLayoutAudienceChip
    val text = Tokens.Colors.dailyCaptureColorText
    Box(Modifier.fillMaxSize()) {
        // Fill daily.capture.color.overlayControl is BLOCKED: circle and chip are drawn without it.
        CircleIconButton(
            icon = Tokens.Icons.globalClose,
            contentDescription = stringResource(R.string.daily_capture_a11y_retake),
            diameter = r.diameter.dp,
            fill = Blocked.overlayControlFill,
            tint = text,
            onClick = onRetake,
            glyphSize = r.glyph.dp,
            modifier = Modifier.align(Alignment.TopEnd).padding(top = r.inset.dp, end = r.inset.dp).semantics { traversalIndex = 3f }.testTag("daily.retake"),
        )
        if (groupName != null) {
            Row(
                Modifier
                    .align(Alignment.BottomCenter)
                    .padding(bottom = chip.bottomInset.dp)
                    .height(chip.height.dp)
                    .clip(CapsuleShape)
                    .then(Blocked.overlayControlFill?.let { Modifier.background(it) } ?: Modifier)
                    .padding(start = chip.paddingLeading.dp, end = chip.paddingTrailing.dp)
                    .semantics(mergeDescendants = true) { traversalIndex = 4f }
                    .testTag("daily.chip"),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(chip.glyphToText.dp),
            ) {
                Glyph(Tokens.Icons.globalGroup, text, null, Modifier.clearAndSetSemantics { })
                BasicText(
                    stringResource(R.string.daily_capture_audience, groupName),
                    style = CaptureText.style(Tokens.FontSizes.dailyCaptureFontSizeChip, null).merge(TextStyle(color = text)),
                    maxLines = 1,
                )
            }
        }
    }
}

/** SEND + the right-pointing triangle, centred, cap top `capTopBelowImage` under the image. */
@Composable
private fun SendLabel(onSend: () -> Unit, modifier: Modifier) {
    val s = Tokens.Layouts.DailyCaptureLayoutSend
    val text = Tokens.Colors.dailyCaptureColorText
    val label = stringResource(R.string.daily_capture_send)
    val a11y = stringResource(R.string.daily_capture_a11y_send)
    val toBaseline = glyphTopToBaseline(Tokens.FontSizes.dailyCaptureFontSizeSend, Tokens.FontWeights.dailyCaptureFontWeightSend, label)
    Box(modifier.fillMaxWidth(), contentAlignment = Alignment.TopCenter) {
        Row(
            Modifier
                .clickable(onClick = onSend)
                .clearAndSetSemantics {
                    contentDescription = a11y
                    role = Role.Button
                    traversalIndex = 5f
                    onClick { onSend(); true }
                }
                .testTag("daily.send"),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            BasicText(
                label,
                style = CaptureText.style(Tokens.FontSizes.dailyCaptureFontSizeSend, Tokens.FontWeights.dailyCaptureFontWeightSend).merge(TextStyle(color = text)),
                modifier = Modifier.paddingFromBaseline(top = s.capTopBelowImage.dp + toBaseline),
            )
            Spacer(Modifier.width(s.glyphGap.dp))
            Glyph(Tokens.Icons.globalPlay, text, s.glyph.dp, Modifier.padding(top = s.capTopBelowImage.dp))
        }
    }
}

/** Digit used to place the countdown by its digit top. */
private const val DIGIT_SAMPLE = "0" // provenance-ok: glyph sample for measuring digit height
