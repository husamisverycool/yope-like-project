// Surface: camera.capture (+ camera.fromwidget: the widget deep link lands here). Retro has no camera: the page is
// composed from Retro components on its media surface (RC-1 … RC-4) — C-01 root header (serif "Week N", bare flash
// glyph), the photo container as viewfinder (3:4, 16 margins, 18 corners), the C-35 control row (shutter flanked
// by 64-pt C-11 circles), C-09 coach pill, C-27 states. References: references/auto/retro/lazyweb/
// retro-lazyweb-20251020-week43-dark.png (H43: header, container corners, tab bar on black);
// references/auto/retro/press/tc-2025-12-rewind-device-a.png (RWA: control row); references/auto/retro/store/
// retro-store-03.png (ST-03: pill on a photo); references/auto/locket/store/locket-store-07.png (shutter mechanics).
package app.feature.capture.camera

import android.Manifest
import android.content.Intent
import android.graphics.BitmapFactory
import android.media.MediaMetadataRetriever
import android.net.Uri
import android.os.Build
import android.provider.MediaStore
import android.provider.Settings
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
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBars
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Icon
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.produceState
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.invisibleToUser
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.LifecycleResumeEffect
import androidx.lifecycle.compose.LocalLifecycleOwner
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import app.designsystem.R
import app.designsystem.generated.Tokens
import app.feature.capture.data.CaptureDataProvider
import app.feature.capture.data.CaptureHandoff
import app.feature.capture.data.SharedCapturePrefs
import app.feature.capture.data.importPicked
import app.feature.capture.share.ShareInbox
import app.feature.capture.ui.ControlRow
import app.feature.capture.ui.MediaControlCircle
import app.feature.capture.ui.MediaEmptyState
import app.feature.capture.ui.RecordingOutline
import app.feature.capture.ui.Shutter
import app.media.MediaPermission
import app.media.MediaPermissions
import app.media.PhotoImport
import app.model.SessionPromptGate
import app.ui.components.EmptyStateAction
import app.ui.components.MediaPill
import app.ui.components.MediaPillStyle
import app.ui.components.ScreenHeader
import app.ui.copy.WeeklyQuestions
import app.ui.foundation.DsMotion
import app.ui.foundation.FadeVisibility
import app.ui.foundation.GlyphInk
import app.ui.foundation.centreAt
import app.ui.foundation.tapClickable
import app.ui.text.CapTop
import app.ui.text.TextRoles
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.File
import java.time.LocalDate
import java.time.temporal.IsoFields

/** The camera destination: permission, CameraX session, picker, and navigation out. */
@Composable
fun CameraRoute(
    groupId: String?,
    replyToPostId: String?,
    onOpenSendTo: () -> Unit,
    onOpenPaywall: () -> Unit,
    question: CameraQuestion? = null,
    /** The destination sheet's empty state (`camera.sendto.empty.button`). */
    onCreateGroup: () -> Unit = {},
) {
    val context = LocalContext.current
    val lifecycleOwner = LocalLifecycleOwner.current
    val vm: CameraViewModel = viewModel(key = "camera:$groupId:$replyToPostId:${question?.id}") {
        CameraViewModel(
            data = CaptureDataProvider.get(context),
            handoff = CaptureHandoff.process,
            prefs = SharedCapturePrefs(context),
            gate = SessionPromptGate.process,
            captureDir = CaptureHandoff.dir(context),
            contextGroupId = groupId,
            replyToPostId = replyToPostId,
            questionId = question?.id,
            durationOf = ::mediaDurationMs,
            sizeOf = ::photoSize,
        )
    }
    app.feature.capture.ui.MediaSystemBars()
    val state by vm.ui.collectAsStateWithLifecycle()
    val controller = remember(lifecycleOwner) { CameraControllers.factory(context, lifecycleOwner) }
    val scope = rememberCoroutineScope()
    val view = LocalView.current
    val recordingLabel = stringResource(R.string.camera_capture_a11y_recording)
    val sendFailed = stringResource(R.string.camera_sendto_error_sendfailed)

    val cameraPermission = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
        MediaPermissions.markRequested(context, MediaPermission.Camera)
        vm.onPermission(granted)
        if (granted) vm.attach(controller)
    }
    val microphonePermission = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) {
        MediaPermissions.markRequested(context, MediaPermission.Microphone)
    }
    // The library: up to `batch_max_photos` items (several photos in one post; one while unknown), in the order picked,
    // each with the day it was taken (`media.taken_on`).
    val onPickedUris: (List<Uri>) -> Unit = { uris ->
        if (uris.isNotEmpty()) scope.launch {
            val picked = withContext(Dispatchers.IO) { uris.mapIndexedNotNull { index, uri -> importPicked(context, uri, index) } }
            vm.onPickedAll(picked)
        }
    }
    val picker = rememberLauncherForActivityResult(PhotoImport.single()) { uri -> onPickedUris(listOfNotNull(uri)) }
    val multiPicker = rememberLauncherForActivityResult(PhotoImport.multiple(pickerLimit(state.selectionLimit).coerceAtLeast(2))) { uris -> onPickedUris(uris) }

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
                // camera.overnight: no preview follows a 9 AM photo, so it is announced; a failure is a C-26 toast.
                is CameraViewModel.Event.OvernightCaptured ->
                    announce(view, context.getString(R.string.camera_overnight_a11y_captured, OvernightFormats.reveal(context, event.reveal)))
                CameraViewModel.Event.OvernightFailed -> app.ui.components.PlatformToast.show(context, sendFailed)
            }
        }
    }
    // share.in: photos shared from another app arrive as a library selection (trimmer, then send-to) — not on the camera of
    // a reply or of the weekly question, which stays about that photo.
    if (replyToPostId == null && question == null) {
        val shared by ShareInbox.pending.collectAsStateWithLifecycle()
        LaunchedEffect(shared) {
            if (shared != null) ShareInbox.take()?.let(vm::onPickedAll)
        }
    }
    DisposableEffect(controller) {
        // The screen's scope is already cancelled here; CameraX also closes with the entry's lifecycle.
        onDispose { kotlinx.coroutines.MainScope().launch { runCatching { controller.unbind() } } }
    }
    val preview by controller.preview.collectAsStateWithLifecycle()
    val groupIds = (state.groups as? app.feature.capture.sendto.SendToViewModel.Groups.Loaded)?.groups.orEmpty()
    val covers by produceState<Map<String, Any?>>(initialValue = emptyMap(), groupIds.map { it.id }, state.destinationSheet) {
        val paths = groupIds.mapNotNull { g -> g.coverPath?.let { g.id to it } }
        if (state.destinationSheet && paths.isNotEmpty()) {
            val urls = runCatching { CaptureDataProvider.get(context).signedUrls(paths.map { it.second }) }.getOrDefault(emptyMap())
            value = paths.mapNotNull { (id, path) -> urls[path]?.let { id to it } }.toMap()
        }
    }
    val overnight = OvernightChrome(
        time = remember(context) { OvernightFormats.time(context) },
        reveal = if (state.destinationSheet) OvernightFormats.reveal(context, OvernightReveal.earliest(java.time.Instant.now(), state.destinationGroups)) else "",
        covers = covers,
        onMode = vm::selectMode,
        onPill = vm::openDestinations,
        onToggle = vm::toggleDestination,
        onDone = vm::confirmDestinations,
        onCreateGroup = onCreateGroup,
        onRetryGroups = vm::loadGroups,
    )

    CameraScreen(
        state = state,
        viewfinder = { preview?.let { CameraXViewfinder(surfaceRequest = it, modifier = Modifier.fillMaxSize(), contentScale = ContentScale.Crop) } },
        title = stringResource(R.string.camera_capture_title, currentWeekNumber().toString()),
        onShutterTap = vm::capturePhoto,
        onShutterLongPress = { vm.startVideo(MediaPermissions.wasRequested(context, MediaPermission.Microphone) || MediaPermissions.isGranted(context, MediaPermission.Microphone)) },
        onShutterRelease = vm::stopVideo,
        onFlash = vm::toggleFlash,
        onFlip = vm::flip,
        onLibrary = { if (pickerLimit(state.selectionLimit) > 1) multiPicker.launch(PhotoImport.imagesAndVideos) else picker.launch(PhotoImport.imagesAndVideos) },
        onCoachClose = vm::dismissCoach,
        onOpenSettings = {
            context.startActivity(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.fromParts("package", context.packageName, null)).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        },
        onRetry = vm::startSession,
        questionText = question?.let { q -> remember(q.key) { WeeklyQuestions.text(context, q.key) } },
        overnight = overnight,
    )
    // camera.trim: a library video over the limit, trimmed before send-to.
    state.trim?.let { request ->
        val target = remember(request) { vm.trimTarget() }
        VideoTrimRoute(request, target, onFinish = vm::onTrimmed)
    }
    if (state.videoTooLong) {
        val limit = remember(context) { app.feature.capture.camera.TrimWords.limit(context) }
        app.ui.system.SystemAlertDialog(
            title = stringResource(R.string.camera_capture_videotoolong_title),
            text = stringResource(R.string.camera_capture_videotoolong_message, limit),
            confirmLabel = stringResource(R.string.camera_capture_videotoolong_dismiss),
            onConfirm = vm::dismissVideoTooLong,
            dismissLabel = null,
            onDismiss = vm::dismissVideoTooLong,
        )
    }
    // Returning from Settings with access granted.
    LifecycleResumeEffect(state.permission) {
        if (state.permission == CameraViewModel.Permission.Denied && MediaPermissions.isGranted(context, MediaPermission.Camera)) {
            vm.onPermission(true)
            vm.attach(controller)
        }
        onPauseOrDispose { }
    }
}

/** Says [text] through TalkBack (a result the screen does not draw). */
@Suppress("DEPRECATION")
private fun announce(view: android.view.View, text: String) = view.announceForAccessibility(text)

/** `camera.capture.title` {number}: the current ISO-8601 week, as `week.history` numbers weeks. */
internal fun currentWeekNumber(today: LocalDate = LocalDate.now()): Int = today.get(IsoFields.WEEK_OF_WEEK_BASED_YEAR)

/**
 * The camera screen (stateless), on `color.global.backgroundDeep` in both appearances: the C-01 header at the
 * safe-area top, the 3:4 viewfinder `size.global.titleToContent` below the title baseline (it shrinks, 3:4 kept,
 * when the control row would get less than `size.global.screenMargin` above and below the shutter), the control
 * row centred between the viewfinder and the tab bar (C-04, drawn by the app shell over the bottom
 * `size.global.tabBarHeight` + the navigation bar). `camera.overnight` adds the 9 AM · Now mode control between the header
 * and the viewfinder, and in 9 AM mode the destination pill on the viewfinder and its sheet ([overnight]).
 */
@Composable
fun CameraScreen(
    state: CameraViewModel.UiState,
    viewfinder: @Composable () -> Unit,
    title: String,
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
    questionText: String? = null,
    overnight: OvernightChrome = OvernightChrome(),
) {
    val tabBar = Tokens.Sizes.globalTabBarHeight + WindowInsets.navigationBars.asPaddingValues().calculateBottomPadding()
    val margin = Tokens.Sizes.globalScreenMargin
    val shutter = Tokens.Sizes.cameraCaptureSizeShutterOuter
    Column(
        modifier
            .fillMaxSize()
            .background(Tokens.Colors.globalBackgroundDeep)
            .windowInsetsPadding(WindowInsets.statusBars)
            .padding(bottom = tabBar)
            .testTag("camera.capture"),
    ) {
        Box {
            ScreenHeader(title, titleColor = Tokens.Colors.globalTextOnMedia)
            if (state.hasFlash && state.showControls) {
                FlashGlyph(state.flashOn, onFlash, Modifier.align(Alignment.TopEnd))
            }
        }
        // camera.overnight: the mode control `size.global.titleToContent` below the title baseline (the header's end), shown
        // in both modes so the layout does not jump; the viewfinder `size.global.sectionHeaderToContent` below it.
        if (state.overnightAvailable) {
            ModeControl(state.mode, overnight.time, overnight.onMode)
            Spacer(Modifier.height(Tokens.Sizes.globalSectionHeaderToContent))
        }
        BoxWithConstraints(Modifier.weight(1f).fillMaxWidth()) {
            val fullWidth = maxWidth - margin * 2
            val vfHeight = minOf(fullWidth / Tokens.Layouts.CameraCaptureLayoutViewfinder.aspect, maxHeight - shutter - margin * 2).coerceAtLeast(0.dp)
            val vfWidth = vfHeight * Tokens.Layouts.CameraCaptureLayoutViewfinder.aspect
            Column(Modifier.fillMaxSize(), horizontalAlignment = Alignment.CenterHorizontally) {
                Viewfinder(state, viewfinder, onCoachClose, onOpenSettings, onRetry, Modifier.size(vfWidth, vfHeight), questionText, overnight, vfWidth - margin * 2)
                ControlRow(
                    modifier = Modifier.weight(1f),
                    leading = {
                        // 9 AM mode: the library circle fades out and the slot stays empty (the developing stack,
                        // `camera.overnight.layout.stackCards`, is BLOCKED).
                        FadeVisibility(visible = state.showLibrary) {
                            MediaControlCircle(Tokens.Icons.globalGallery, stringResource(R.string.camera_capture_a11y_library), onLibrary, Modifier.testTag("camera.library"))
                        }
                    },
                    trailing = if (state.showControls) {
                        { MediaControlCircle(Tokens.Icons.globalFlip, stringResource(R.string.camera_capture_a11y_flip), onFlip, Modifier.testTag("camera.flip")) }
                    } else {
                        null
                    },
                ) {
                    if (state.showControls) {
                        // 9 AM mode: tap = photo, hold = nothing (photos only).
                        val now = state.mode == CaptureMode.Now
                        Shutter(
                            label = stringResource(R.string.camera_capture_a11y_shutter),
                            onTap = onShutterTap,
                            onHoldStart = if (now) onShutterLongPress else null,
                            onHoldEnd = if (now) onShutterRelease else null,
                            holdActionLabel = if (state.videoAvailable && now) stringResource(R.string.camera_capture_a11y_recordvideo) else null,
                            holding = state.recording,
                            modifier = Modifier.testTag("camera.shutter"),
                        )
                    } else {
                        Spacer(Modifier.size(shutter))
                    }
                }
            }
        }
    }
    if (state.destinationSheet) DestinationSheet(state.groups, state.destinations, overnight)
}

/**
 * The flash as a bare C-01 header glyph (`icon.global.flashOff` / `.flashOn`, `size.global.icon`,
 * `color.global.textOnMedia`): centred on the title's cap middle, its ink `size.global.headerInset` from the
 * trailing edge, hit area `size.global.headerButton` (≥ 48 dp); TalkBack "Flash" + "On" / "Off"; the glyph
 * cross-fades (`duration.global.crossfade`). Built beside [ScreenHeader] because C-01's `HeaderAction` has no
 * state description (reported gap).
 */
@Composable
private fun FlashGlyph(on: Boolean, onClick: () -> Unit, modifier: Modifier = Modifier) {
    val icon = if (on) Tokens.Icons.globalFlashOn else Tokens.Icons.globalFlashOff
    val box = Tokens.Sizes.globalIcon
    val hit = maxOf(Tokens.Sizes.globalHeaderButton, Tokens.Sizes.globalMinTouchTargetAndroid)
    val capMiddle = Tokens.Sizes.globalTitleTop - CapTop.height(TextRoles.headerTitle) / 2
    val end = Tokens.Sizes.globalHeaderInset - GlyphInk.trailing(icon, box) - (hit - box) / 2
    val label = stringResource(R.string.camera_capture_a11y_flash)
    val value = stringResource(if (on) R.string.camera_capture_a11y_flashon else R.string.camera_capture_a11y_flashoff)
    Box(
        modifier
            .padding(end = end.coerceAtLeast(0.dp))
            .centreAt(capMiddle)
            .size(hit)
            .clip(CircleShape)
            .tapClickable(onClick = onClick)
            .semantics {
                contentDescription = label
                stateDescription = value
            }
            .testTag("camera.flash"),
        contentAlignment = Alignment.Center,
    ) {
        Crossfade(icon, animationSpec = DsMotion.crossfade(), label = "flash") { glyph ->
            Icon(glyph, contentDescription = null, tint = Tokens.Colors.globalTextOnMedia, modifier = Modifier.size(box))
        }
    }
}

/**
 * The viewfinder (`camera.capture.layout.viewfinder`): corners `radius.global.viewfinder`, filled
 * `color.global.backgroundDeep` until the first frame, then the live preview fades in (`duration.global.fade`).
 * On it while recording: the outline; first use: the coach pill (C-09 dark, `icon.global.video`), centred, its
 * bottom `camera.sendto.layout.messageField.bottomInset` above the frame bottom. Denied / unavailable: the C-27
 * block on media inside the frame.
 */
@Composable
private fun Viewfinder(
    state: CameraViewModel.UiState,
    viewfinder: @Composable () -> Unit,
    onCoachClose: () -> Unit,
    onOpenSettings: () -> Unit,
    onRetry: () -> Unit,
    modifier: Modifier,
    questionText: String? = null,
    overnight: OvernightChrome = OvernightChrome(),
    pillMaxWidth: Dp = Dp.Infinity,
) {
    Box(
        modifier
            .clip(RoundedCornerShape(Tokens.Radii.globalViewfinder))
            .background(Tokens.Colors.globalBackgroundDeep)
            .semantics { invisibleToUser() }
            .testTag("camera.viewfinder"),
        contentAlignment = Alignment.Center,
    ) {
        val denied = state.permission == CameraViewModel.Permission.Denied
        val unavailable = !denied && state.session == CameraViewModel.Session.Unavailable
        FadeVisibility(visible = state.permission == CameraViewModel.Permission.Granted && state.session == CameraViewModel.Session.Live, modifier = Modifier.fillMaxSize()) {
            Box(Modifier.fillMaxSize()) { viewfinder() }
        }
        RecordingOutline(state.recording)
        FadeVisibility(visible = denied, modifier = Modifier.semantics { }) {
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
        // The weekly question's pill takes the coach pill's slot (question.weekly B); dropped in 9 AM mode
        // (`question.weekly.layout.cameraPill.nineAm`).
        if (questionText != null && state.showControls && state.mode == CaptureMode.Now) {
            QuestionPill(questionText, Modifier.align(Alignment.BottomCenter).padding(bottom = Dp(Tokens.Layouts.CameraSendtoLayoutMessageField.bottomInset)))
        }
        FadeVisibility(
            visible = state.coachVisible && !state.recording && questionText == null,
            modifier = Modifier.align(Alignment.BottomCenter).padding(bottom = Dp(Tokens.Layouts.CameraSendtoLayoutMessageField.bottomInset)),
        ) {
            MediaPill(
                text = stringResource(R.string.camera_capture_coach_holdtorecord),
                onClick = onCoachClose,
                style = MediaPillStyle.Dark,
                icon = Tokens.Icons.globalVideo,
                modifier = Modifier.testTag("camera.coach"),
            )
        }
        // camera.overnight: the destination pill in the coach pill's slot (the coach is never shown in 9 AM mode).
        FadeVisibility(
            visible = state.mode == CaptureMode.Later && state.showControls,
            modifier = Modifier.align(Alignment.BottomCenter).padding(bottom = Dp(Tokens.Layouts.CameraSendtoLayoutMessageField.bottomInset)),
        ) {
            val groups = (state.groups as? app.feature.capture.sendto.SendToViewModel.Groups.Loaded)?.groups.orEmpty()
            DestinationPill(destinationLabel(groups, state.destinations), pillMaxWidth, overnight.onPill)
        }
    }
}

/**
 * The picker's limit: `batch_max_photos`, within what the system Photo Picker allows (`MediaStore.getPickImagesMaxLimit`,
 * Android 13+); `PickMultipleVisualMedia` needs at least 2, so 1 means the single-item picker.
 */
internal fun pickerLimit(limit: Int): Int {
    val system = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) MediaStore.getPickImagesMaxLimit() else limit
    return limit.coerceAtMost(system).coerceAtLeast(1)
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

