// Surface: camera.capture (+ camera.fromwidget: the widget deep link lands here).
// References: references/auto/yope/frames/a-jacob-7691153057177931039-t3.73-camera-hold-to-record.png (layout,
// viewfinder, hour overlay, flash, coach, shutter, library, flip); a-alexaa-7684388619099933966-t5.23-camera-hold-to-record-tabbar.png;
// a-chuongxetank-7694968408424582452-t4.73-camera.png; a-virgi-7686278541255642390-t36.23-camera-first-open-es.png /
// t35.23-camera-permission-alert.png (system alert over the camera); Locket shutter press
// references/auto/locket/frames/locket-tt-7069892557970345259-03.367s-shutter-pressed-2022.jpg.
package app.feature.capture.camera

import android.Manifest
import android.content.Context
import android.content.Intent
import android.graphics.BitmapFactory
import android.media.MediaMetadataRetriever
import android.net.Uri
import android.provider.Settings
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.camera.compose.CameraXViewfinder
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicText
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
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.CustomAccessibilityAction
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.customActions
import androidx.compose.ui.semantics.isTraversalGroup
import androidx.compose.ui.semantics.onClick
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.semantics.traversalIndex
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.LifecycleResumeEffect
import androidx.lifecycle.compose.LocalLifecycleOwner
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import app.data.model.MediaKind
import app.feature.capture.Blocked
import app.designsystem.R
import app.designsystem.dsAnimateFloatAsState
import app.designsystem.MotionChannel
import app.designsystem.generated.Tokens
import app.feature.capture.data.CaptureDataProvider
import app.feature.capture.data.CaptureHandoff
import app.feature.capture.data.SharedCapturePrefs
import app.feature.capture.ui.CaptureText
import app.feature.capture.ui.CircleIconButton
import app.feature.capture.ui.CoachTooltip
import app.feature.capture.ui.EmptyStateBlock
import app.feature.capture.ui.Glyph
import app.feature.capture.ui.MinTouchTargets
import app.feature.capture.ui.ShutterDisc
import app.feature.capture.ui.CaptureToastHost
import app.media.ImageEncoder
import app.media.MediaPermission
import app.media.MediaPermissions
import app.media.PhotoImport
import app.model.SessionPromptGate
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.File
import java.util.Date

/** The camera destination: permission, CameraX session, picker, and navigation out. */
@Composable
fun CameraRoute(
    groupId: String?,
    replyToPostId: String?,
    onOpenSendTo: () -> Unit,
    onOpenPaywall: () -> Unit,
) {
    val context = LocalContext.current
    val lifecycleOwner = LocalLifecycleOwner.current
    val vm: CameraViewModel = viewModel(key = "camera:$groupId:$replyToPostId") {
        CameraViewModel(
            data = CaptureDataProvider.get(context),
            handoff = CaptureHandoff.process,
            prefs = SharedCapturePrefs(context),
            gate = SessionPromptGate.process,
            captureDir = CaptureHandoff.dir(context),
            contextGroupId = groupId,
            replyToPostId = replyToPostId,
            durationOf = ::mediaDurationMs,
            sizeOf = ::photoSize,
        )
    }
    val state by vm.ui.collectAsStateWithLifecycle()
    val controller = remember(lifecycleOwner) { CameraControllers.factory(context, lifecycleOwner) }
    val scope = rememberCoroutineScope()
    val view = LocalView.current
    val recordingLabel = stringResource(R.string.camera_capture_a11y_recording)

    val cameraPermission = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
        MediaPermissions.markRequested(context, MediaPermission.Camera)
        vm.onPermission(granted)
        if (granted) vm.attach(controller)
    }
    val microphonePermission = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) {
        MediaPermissions.markRequested(context, MediaPermission.Microphone)
    }
    val picker = rememberLauncherForActivityResult(PhotoImport.single()) { uri ->
        if (uri != null) scope.launch {
            val picked = withContext(Dispatchers.IO) { copyPicked(context, uri) }
            if (picked != null) vm.onPicked(picked.first, picked.second)
        }
    }

    // First open: the system prompt appears directly over this screen (no pre-prompt).
    LaunchedEffect(Unit) {
        if (MediaPermissions.isGranted(context, MediaPermission.Camera)) {
            vm.onPermission(true)
            vm.attach(controller)
        } else {
            cameraPermission.launch(Manifest.permission.CAMERA)
        }
    }
    LaunchedEffect(vm) {
        vm.event.collect { event ->
            when (event) {
                CameraViewModel.Event.OpenSendTo -> onOpenSendTo()
                CameraViewModel.Event.OpenPaywall -> onOpenPaywall()
                CameraViewModel.Event.AskMicrophone -> microphonePermission.launch(Manifest.permission.RECORD_AUDIO)
                @Suppress("DEPRECATION") // the spec asks for an announcement when recording starts
                CameraViewModel.Event.RecordingStarted -> view.announceForAccessibility(recordingLabel)
            }
        }
    }
    DisposableEffect(controller) {
        onDispose { scope.launch { runCatching { controller.unbind() } } }
    }
    val preview by controller.preview.collectAsStateWithLifecycle()

    CameraScreen(
        state = state,
        viewfinder = { preview?.let { CameraXViewfinder(surfaceRequest = it, modifier = Modifier.fillMaxSize(), contentScale = ContentScale.Crop) } },
        hourText = rememberHourText(),
        onShutterTap = vm::capturePhoto,
        onShutterLongPress = { vm.startVideo(MediaPermissions.wasRequested(context, MediaPermission.Microphone) || MediaPermissions.isGranted(context, MediaPermission.Microphone)) },
        onShutterRelease = vm::stopVideo,
        onFlash = vm::toggleFlash,
        onFlip = vm::flip,
        onLibrary = { picker.launch(PhotoImport.imagesAndVideos) },
        onCoachClose = vm::dismissCoach,
        onOpenSettings = {
            context.startActivity(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.fromParts("package", context.packageName, null)).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        },
        onRetry = vm::startSession,
    )
    // Returning from Settings with access granted.
    LifecycleResumeEffect(state.permission) {
        if (state.permission == CameraViewModel.Permission.Denied && MediaPermissions.isGranted(context, MediaPermission.Camera)) {
            vm.onPermission(true)
            vm.attach(controller)
        }
        onPauseOrDispose { }
    }
}

/**
 * The camera screen (stateless). Positions are the spec's, from the screen top: viewfinder at
 * `camera.capture.layout.viewfinder.top`, full width, height = width × heightOverWidth; the control
 * row `camera.capture.size.shutterTopGap` below it.
 */
@Composable
fun CameraScreen(
    state: CameraViewModel.UiState,
    viewfinder: @Composable () -> Unit,
    hourText: String,
    onShutterTap: () -> Unit,
    onShutterLongPress: () -> Unit,
    onShutterRelease: () -> Unit,
    onFlash: () -> Unit,
    onFlip: () -> Unit,
    onLibrary: () -> Unit,
    onCoachClose: () -> Unit,
    onOpenSettings: () -> Unit,
    onRetry: () -> Unit,
    modifier: Modifier = Modifier,
) = MinTouchTargets {
    val vf = Tokens.Layouts.CameraCaptureLayoutViewfinder
    BoxWithConstraints(
        modifier
            .fillMaxSize()
            .background(Tokens.Colors.globalBackgroundDeep)
            .semantics { isTraversalGroup = true }
            .testTag("camera.capture"),
    ) {
        val width = maxWidth
        val vfTop = vf.top.dp
        val vfHeight = width * vf.heightOverWidth
        val rowTop = vfTop + vfHeight + Tokens.Sizes.cameraCaptureSizeShutterTopGap
        val outer = Tokens.Sizes.cameraCaptureSizeShutterOuter
        val rowCenterY = rowTop + outer / 2

        // Viewfinder.
        Box(
            Modifier
                .padding(top = vfTop)
                .fillMaxWidth()
                .height(vfHeight)
                .clip(RoundedCornerShape(Tokens.Radii.globalViewfinder))
                .background(Tokens.Colors.globalBackgroundDeep)
                .testTag("camera.viewfinder"),
        ) {
            when {
                state.permission == CameraViewModel.Permission.Denied -> EmptyStateBlock(
                    title = stringResource(R.string.camera_capture_denied_title),
                    detail = stringResource(R.string.camera_capture_denied_detail),
                    buttonLabel = stringResource(R.string.camera_capture_denied_button),
                    onButton = onOpenSettings,
                    modifier = Modifier.align(Alignment.Center),
                )
                state.session == CameraViewModel.Session.Unavailable -> EmptyStateBlock(
                    title = stringResource(R.string.camera_capture_unavailable_title),
                    detail = stringResource(R.string.camera_capture_unavailable_detail),
                    buttonLabel = stringResource(R.string.camera_capture_unavailable_button),
                    onButton = onRetry,
                    modifier = Modifier.align(Alignment.Center),
                )
                state.permission == CameraViewModel.Permission.Granted -> {
                    viewfinder()
                    BasicText(
                        hourText,
                        style = CaptureText.overlayTimeCamera.merge(TextStyle(color = Tokens.Colors.globalTextPrimary)),
                        modifier = Modifier.align(Alignment.Center).semantics { traversalIndex = HOUR_ORDER },
                    )
                    if (state.hasFlash) FlashToggle(state.flashOn, onFlash)
                    // Recording outline in color.global.accent (width BLOCKED → not drawn while null).
                    val outline = Blocked.recordingOutline
                    if (state.recording && outline != null) {
                        Box(Modifier.fillMaxSize().border(outline, Tokens.Colors.globalAccent, RoundedCornerShape(Tokens.Radii.globalViewfinder)))
                    }
                }
            }
        }

        // Control row: library (−sideControlOffset), shutter (centre), flip (+sideControlOffset).
        val side = Tokens.Sizes.cameraCaptureSizeSideControlOffset
        val thumb = Tokens.Sizes.cameraCaptureSizeLibraryThumb
        LibraryThumb(
            onLibrary,
            Modifier.offset(x = width / 2 - side - thumb / 2, y = rowCenterY - thumb / 2).semantics { traversalIndex = LIBRARY_ORDER },
        )
        if (state.showControls) {
            Shutter(
                state = state,
                onTap = onShutterTap,
                onLongPress = onShutterLongPress,
                onRelease = onShutterRelease,
                modifier = Modifier.offset(x = width / 2 - outer / 2, y = rowTop).semantics { traversalIndex = SHUTTER_ORDER },
            )
            val flip = Tokens.Sizes.cameraCaptureSizeFlipButton
            CircleIconButton(
                icon = Tokens.Icons.globalFlip,
                contentDescription = stringResource(R.string.camera_capture_a11y_flip),
                diameter = flip,
                fill = Tokens.Colors.cameraCaptureColorFlipButton,
                tint = Tokens.Colors.globalTextPrimary,
                onClick = onFlip,
                modifier = Modifier.offset(x = width / 2 + side - flip / 2, y = rowCenterY - flip / 2).semantics { traversalIndex = FLIP_ORDER },
            )
        }

        // Coach: pointer apex `pointerToTarget` above the shutter ring, centred on the shutter.
        if (state.coachVisible) {
            val apexY = rowTop - Tokens.Layouts.CameraCaptureLayoutCoach.pointerToTarget.dp
            Box(Modifier.fillMaxWidth().height(apexY), contentAlignment = Alignment.BottomCenter) {
                CoachTooltip(
                    text = stringResource(R.string.camera_capture_coach_holdtorecord),
                    closeLabel = stringResource(R.string.camera_capture_a11y_close),
                    onClose = onCoachClose,
                    leadingIcon = Tokens.Icons.cameraCaptureIconRecordHint,
                    modifier = Modifier.semantics { traversalIndex = COACH_ORDER },
                )
            }
        }
        CaptureToastHost()
    }
}

@Composable
private fun FlashToggle(on: Boolean, onClick: () -> Unit) {
    val g = Tokens.Layouts.CameraCaptureLayoutFlashGlyph
    val label = stringResource(R.string.camera_capture_a11y_flash)
    val value = stringResource(if (on) R.string.camera_capture_a11y_flashon else R.string.camera_capture_a11y_flashoff)
    BoxWithConstraints(Modifier.fillMaxSize()) {
        val glyph = g.glyphHeight.dp
        Box(
            Modifier
                .offset(x = g.centerFromLeading.dp - glyph / 2, y = maxHeight - g.centerFromBottom.dp - glyph / 2)
                .size(glyph)
                .clickable(onClick = onClick)
                .semantics {
                    contentDescription = label
                    stateDescription = value
                    role = Role.Button
                    traversalIndex = FLASH_ORDER
                }
                .testTag("camera.flash"),
        ) {
            Glyph(if (on) Tokens.Icons.globalFlashOn else Tokens.Icons.globalFlashOff, Tokens.Colors.globalTextPrimary, glyph)
        }
    }
}

@Composable
private fun LibraryThumb(onClick: () -> Unit, modifier: Modifier) {
    val size = Tokens.Sizes.cameraCaptureSizeLibraryThumb
    val shape = RoundedCornerShape(Tokens.Radii.cameraCaptureRadiusLibraryThumb)
    val label = stringResource(R.string.camera_capture_a11y_library)
    // The app reads no library (system Photo Picker only), so the slot shows icon.global.gallery.
    Box(
        modifier
            .size(size)
            .clip(shape)
            .border(Tokens.Sizes.cameraCaptureSizeLibraryThumbBorder, Tokens.Colors.globalTextPrimary, shape)
            .clickable(onClick = onClick)
            .semantics {
                contentDescription = label
                role = Role.Button
            }
            .testTag("camera.library"),
        contentAlignment = Alignment.Center,
    ) {
        Glyph(Tokens.Icons.globalGallery, Tokens.Colors.globalTextPrimary, null)
    }
}

@Composable
private fun Shutter(
    state: CameraViewModel.UiState,
    onTap: () -> Unit,
    onLongPress: () -> Unit,
    onRelease: () -> Unit,
    modifier: Modifier,
) {
    var pressed by remember { mutableStateOf(false) }
    // Press: scale to camera.capture.layout.shutterPress.scale on camera.capture.spring.shutterPress
    // (Reduce Motion: no scale, the disc colour change only).
    val scale by dsAnimateFloatAsState(
        targetValue = if (pressed || state.recording) Tokens.Layouts.CameraCaptureLayoutShutterPress.scale else 1f,
        animationSpec = Tokens.Springs.cameraCaptureSpringShutterPress.spec(),
        channel = MotionChannel.Movement,
        label = "shutterPress", // provenance-ok: animation debug label (tooling only)
    )
    val label = stringResource(R.string.camera_capture_a11y_shutter)
    val recordLabel = stringResource(R.string.camera_capture_a11y_recordvideo)
    Box(
        modifier
            .size(Tokens.Sizes.cameraCaptureSizeShutterOuter)
            .graphicsLayer { scaleX = scale; scaleY = scale }
            .pointerInput(state.videoAvailable) {
                detectTapGestures(
                    onPress = {
                        pressed = true
                        tryAwaitRelease()
                        pressed = false
                        onRelease()
                    },
                    onTap = { onTap() },
                    onLongPress = { onLongPress() },
                )
            }
            .semantics {
                contentDescription = label
                role = Role.Button
                onClick { onTap(); true }
                if (state.videoAvailable) {
                    customActions = listOf(
                        CustomAccessibilityAction(recordLabel) {
                            if (state.recording) onRelease() else onLongPress()
                            true
                        },
                    )
                }
            }
            .testTag("camera.shutter"),
    ) {
        ShutterDisc(
            outer = Tokens.Sizes.cameraCaptureSizeShutterOuter,
            ring = Tokens.Sizes.cameraCaptureSizeShutterRing,
            disc = Tokens.Sizes.cameraCaptureSizeShutterDisc,
            ringColor = Tokens.Colors.globalAccent,
            gapColor = Tokens.Colors.globalBackgroundDeep,
            discColor = if (pressed || state.recording) Tokens.Colors.cameraCaptureColorShutterDiscPressed else Tokens.Colors.globalSurfaceLight,
        )
    }
}

/** `camera.capture.hourOverlay`: the start of the current hour in the device's short time style; updates on the hour. */
@Composable
fun rememberHourText(now: () -> Long = System::currentTimeMillis): String {
    val context = LocalContext.current
    val text by produceState(initialValue = hourText(context, now())) {
        while (true) {
            val t = now()
            value = hourText(context, t)
            delay(HOUR_MS - t % HOUR_MS)
        }
    }
    return text
}

fun hourText(context: Context, epochMillis: Long): String {
    val zone = java.util.TimeZone.getDefault()
    val offset = zone.getOffset(epochMillis)
    val hourStart = (epochMillis + offset) / HOUR_MS * HOUR_MS - offset
    return context.getString(R.string.camera_capture_houroverlay, android.text.format.DateFormat.getTimeFormat(context).format(Date(hourStart)))
}

private const val HOUR_MS = 3_600_000L // provenance-ok: one hour, the overlay's unit (spec: start of the current hour)
private const val COACH_ORDER = -1f
private const val FLASH_ORDER = 0f
private const val HOUR_ORDER = 0.5f
private const val SHUTTER_ORDER = 1f
private const val LIBRARY_ORDER = 2f
private const val FLIP_ORDER = 3f

/** Copies a picked item into the capture directory; images lose their location tags. */
internal fun copyPicked(context: Context, uri: Uri): Pair<File, MediaKind>? {
    val type = context.contentResolver.getType(uri).orEmpty()
    val video = type.startsWith("video/")
    val file = File(CaptureHandoff.dir(context), "pick-${System.currentTimeMillis()}.${if (video) "mp4" else "jpg"}")
    return try {
        context.contentResolver.openInputStream(uri)?.use { input -> file.outputStream().use { input.copyTo(it) } } ?: return null
        if (!video) runCatching { ImageEncoder.stripLocation(file) }
        file to (if (video) MediaKind.Video else MediaKind.Photo)
    } catch (_: Exception) {
        file.delete()
        null
    }
}

internal fun mediaDurationMs(file: File): Long? {
    val retriever = MediaMetadataRetriever()
    return try {
        retriever.setDataSource(file.absolutePath)
        retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)?.toLongOrNull()
    } catch (_: RuntimeException) {
        null
    } finally {
        retriever.release()
    }
}

/** Pixel size with EXIF orientation applied (90 / 270 swap the axes). */
internal fun photoSize(file: File): Pair<Int, Int>? {
    val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
    BitmapFactory.decodeFile(file.path, bounds)
    if (bounds.outWidth <= 0 || bounds.outHeight <= 0) return null
    val rotation = app.feature.capture.data.exifRotation(file)
    return if (rotation % 180 != 0) bounds.outHeight to bounds.outWidth else bounds.outWidth to bounds.outHeight
}
