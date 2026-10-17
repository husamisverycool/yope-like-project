package app.feature.memory

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.EnterTransition
import androidx.compose.animation.ExitTransition
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.core.content.ContextCompat
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.navigation.NavGraphBuilder
import androidx.navigation.NavHostController
import androidx.navigation.compose.composable
import androidx.navigation.toRoute
import app.designsystem.R
import app.designsystem.ReduceMotion
import app.designsystem.generated.Tokens
import app.feature.memory.birthday.BirthdayAddScreen
import app.feature.memory.birthday.BirthdayAddViewModel
import app.feature.memory.birthday.BirthdayRequestDestination
import app.feature.memory.birthday.DateEntryPattern
import app.feature.memory.birthday.TributeDestination
import app.feature.memory.birthday.openAppSettings
import app.feature.memory.common.CollectEffects
import app.feature.memory.common.LightSystemBarIcons
import app.feature.memory.common.MemoryBackend
import app.feature.memory.common.MemoryFormats
import app.feature.memory.common.rememberMemoryBackend
import app.feature.memory.common.rememberSeenStore
import app.feature.memory.onthisday.OnThisDayActions
import app.feature.memory.onthisday.OnThisDayEvent
import app.feature.memory.onthisday.OnThisDayScreen
import app.feature.memory.onthisday.OnThisDayState
import app.feature.memory.onthisday.OnThisDayViewModel
import app.feature.memory.share.AndroidPhotoFiles
import app.feature.memory.share.MemoryFiles
import app.feature.memory.share.PhotoFiles
import app.feature.memory.yearstory.YearStoryDestination
import app.model.AppRoute
import app.model.SafetyReportContentRoute
import app.model.OnThisDayRoute
import app.model.SocialHandoff
import app.ui.components.PlatformToast
import app.ui.nav.emptyDestination
import java.time.Clock
import java.time.LocalDate
import java.time.ZoneId

/**
 * Destinations of the memory feature group (surface specs in design/surfaces/):
 * - [OnThisDayRoute] → `onthisday` (the day of one group; entry: `OnThisDayEntry`);
 * - [AppRoute.BirthdayAdd] → `birthday.add` (from the settings row);
 * - [AppRoute.BirthdayContribute] → `birthday.request` then `birthday.contribute` in a nested graph
 *   (push `DeepLink.BirthdayRequest` lands here; entry: `BirthdayRequestEntries`);
 * - [AppRoute.Tribute] → `birthday.tribute` (push `DeepLink.Tribute`);
 * - [AppRoute.YearStory] → `year.story` (deep link `DeepLink.YearStory`; entry: `YearStoryEntry`).
 *
 * [AppRoute.OnThisDay] carries no group id, so it cannot show a day; it stays an empty destination
 * and the day is opened with [OnThisDayRoute].
 */
fun NavGraphBuilder.memoryDestinations(navController: NavHostController) {
    emptyDestination<AppRoute.OnThisDay>()
    composable<OnThisDayRoute> { entry ->
        val route = entry.toRoute<OnThisDayRoute>()
        OnThisDayDestination(
            route.groupId,
            onClose = { navController.popBackStack() },
            onReport = { postId -> navController.navigate(AppRoute.SafetyReport(groupId = route.groupId, postId = postId)) },
            // "Then & now": the camera for this group, replying to the memory with a photo — photo.viewer's reply hand-off.
            onReply = { postId ->
                navController.navigate(AppRoute.Camera(route.groupId))
                navController.currentBackStackEntry?.savedStateHandle?.set(SocialHandoff.REPLY_TO_POST_ID, postId)
            },
        )
    }
    composable<AppRoute.BirthdayAdd> {
        BirthdayAddDestination(onClose = { navController.popBackStack() })
    }
    composable<AppRoute.BirthdayContribute>(
        enterTransition = { RequestSheetMotion.enter(navController.context) },
        popExitTransition = { RequestSheetMotion.exit(navController.context) },
    ) { entry ->
        val route = entry.toRoute<AppRoute.BirthdayContribute>()
        BirthdayRequestDestination(
            groupId = route.groupId,
            requestId = route.requestId,
            onClose = { navController.popBackStack() },
            onOpenGroup = { groupId -> navController.navigate(AppRoute.Group(groupId)) },
        )
    }
    composable<AppRoute.Tribute> { entry ->
        val route = entry.toRoute<AppRoute.Tribute>()
        TributeDestination(
            route.tributeId,
            onClose = { navController.popBackStack() },
            onReport = { groupId -> navController.navigate(SafetyReportContentRoute("tribute", route.tributeId, groupId)) },
        )
    }
    composable<AppRoute.YearStory> { entry ->
        val route = entry.toRoute<AppRoute.YearStory>()
        YearStoryDestination(
            route.groupId,
            route.year,
            onClose = { navController.popBackStack() },
            onReport = { storyId -> navController.navigate(SafetyReportContentRoute("year_story", storyId, route.groupId)) },
        )
    }
}

/**
 * `birthday.request` is a full-screen sheet (birthday.request.md → Motion, Platform notes): it rises
 * from the bottom on `spring.global.sheetPresent` and leaves the same way; Reduce Motion
 * (`layout.global.reduceMotion`) cross-fades over `duration.global.sheetPresent`.
 */
internal object RequestSheetMotion {
    fun enter(context: Context): EnterTransition =
        if (ReduceMotion.isEnabled(context)) fadeIn(tween(Tokens.Durations.globalSheetPresent))
        else slideInVertically(Tokens.Springs.globalSheetPresent.spec()) { height -> height }

    fun exit(context: Context): ExitTransition =
        if (ReduceMotion.isEnabled(context)) fadeOut(tween(Tokens.Durations.globalSheetPresent))
        else slideOutVertically(Tokens.Springs.globalSheetPresent.spec()) { height -> height }
}

/** Opens the day of [groupId] (for the `groups.screen` entry). */
fun NavHostController.openOnThisDay(groupId: String) = navigate(OnThisDayRoute(groupId))

/** The `onthisday` destination: the Rewind page of [groupId]; closes itself when the day has no memories. */
@Composable
fun OnThisDayDestination(
    groupId: String,
    onClose: () -> Unit,
    onReport: (postId: String) -> Unit,
    /** "Reply": the camera answering the memory [postId] with a photo in this group. */
    onReply: (postId: String) -> Unit = {},
    backend: MemoryBackend = rememberMemoryBackend(),
    files: PhotoFiles? = null,
    clock: Clock = Clock.systemUTC(),
) {
    val context = LocalContext.current
    val vm = viewModel(key = "onthisday/$groupId") { OnThisDayViewModel(groupId, backend, files ?: AndroidPhotoFiles(context), clock) }
    val state by vm.state.collectAsStateWithLifecycle()
    LaunchedEffect(state) { if (state == OnThisDayState.Finished) onClose() }
    LightSystemBarIcons()
    CollectEffects(vm.effects, onClose)
    var saveDenied by remember { mutableStateOf(false) }
    // The share sheet's preview: today's date as `layout.year.story.dateFormat` ("Tuesday, December 2") and "Memory".
    val previewTitle = MemoryFormats.storyDate(LocalDate.now(clock.withZone(ZoneId.systemDefault())))
    val previewLabel = stringResource(R.string.onthisday_share_subtitle)
    val saved = stringResource(R.string.onthisday_toast_saved)
    val saveFailed = stringResource(R.string.onthisday_savefailed)
    val deleted = stringResource(R.string.onthisday_toast_deleted)
    val hidden = stringResource(R.string.onthisday_toast_hidden)
    val hideFailed = stringResource(R.string.onthisday_error_detail)
    val hideOffline = stringResource(R.string.onthisday_offline_detail)
    val nothingOnDate = stringResource(R.string.onthisday_empty_title)
    val calendar by vm.calendar.collectAsStateWithLifecycle()
    LaunchedEffect(vm) {
        vm.requests.collect { event ->
            when (event) {
                is OnThisDayEvent.Share -> runCatching { context.startActivity(MemoryFiles.shareIntent(event.uri, MemoryFiles.MIME_JPEG, title = previewTitle, label = previewLabel)) }
                is OnThisDayEvent.Toast -> PlatformToast.show(
                    context,
                    when (event.kind) {
                        OnThisDayEvent.Toast.Kind.Saved -> saved
                        OnThisDayEvent.Toast.Kind.SaveFailed -> saveFailed
                        OnThisDayEvent.Toast.Kind.Deleted -> deleted
                        OnThisDayEvent.Toast.Kind.Hidden -> hidden
                        OnThisDayEvent.Toast.Kind.HideFailed -> hideFailed
                        OnThisDayEvent.Toast.Kind.HideOffline -> hideOffline
                        OnThisDayEvent.Toast.Kind.NothingOnDate -> nothingOnDate
                        OnThisDayEvent.Toast.Kind.LoadFailed -> hideFailed
                        OnThisDayEvent.Toast.Kind.LoadOffline -> hideOffline
                    },
                )
                OnThisDayEvent.SaveDenied -> saveDenied = true
            }
        }
    }
    // API 26-28: MediaStore writes need WRITE_EXTERNAL_STORAGE (maxSdkVersion 28 in the manifest).
    val askWrite = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { granted -> vm.save(granted) }
    // The feature intro: first open, once per account (onthisday.md C).
    val seen = rememberSeenStore()
    val me = backend.currentUserId
    var introDone by remember(me) { mutableStateOf(me == null || seen.seen(me, INTRO_KEY)) }
    OnThisDayScreen(
        state = state,
        actions = OnThisDayActions(
            onStep = vm::step,
            onTogglePlay = vm::togglePlay,
            onAdvance = vm::advance,
            onShuffle = vm::shuffle,
            onShowDay = vm::showDay,
            onOpenCalendar = vm::openCalendar,
            onPickDate = vm::pickDate,
            onCloseCalendar = vm::closeCalendar,
            onShare = vm::share,
            onReply = { vm.replyTarget()?.let(onReply) },
            onSave = {
                val legacy = Build.VERSION.SDK_INT < Build.VERSION_CODES.Q
                if (legacy && ContextCompat.checkSelfPermission(context, Manifest.permission.WRITE_EXTERNAL_STORAGE) != PackageManager.PERMISSION_GRANTED) {
                    askWrite.launch(Manifest.permission.WRITE_EXTERNAL_STORAGE)
                } else {
                    vm.save()
                }
            },
            onHidePhoto = vm::hidePhoto,
            onHideDay = vm::hideDay,
            onDelete = vm::delete,
            onReport = { (state as? OnThisDayState.Page)?.memory?.let { onReport(it.postId) } },
            onRetry = vm::retry,
            onBack = onClose,
            onIntroDone = {
                introDone = true
                if (me != null) seen.markSeen(me, INTRO_KEY)
            },
            onDismissSaveDenied = { saveDenied = false },
            onOpenSettings = {
                saveDenied = false
                openAppSettings(context)
            },
        ),
        isMine = vm::isMine,
        showIntro = !introDone,
        saveDenied = saveDenied,
        calendar = calendar,
    )
}

/** [app.feature.memory.common.SeenStore] key of the On This Day feature intro. */
private const val INTRO_KEY = "onthisday.nux"

/** The `birthday.add` destination. */
@Composable
fun BirthdayAddDestination(onClose: () -> Unit, backend: MemoryBackend = rememberMemoryBackend()) {
    val pattern = remember { DateEntryPattern.forLocale() }
    val vm = viewModel(key = "birthday.add") { BirthdayAddViewModel(backend, pattern) }
    val state by vm.state.collectAsStateWithLifecycle()
    CollectEffects(vm.effects, onClose)
    BirthdayAddScreen(
        state = state,
        pattern = pattern,
        onDigits = vm::setDigits,
        onAdd = vm::add,
        onRemove = vm::remove,
        onLater = vm::later,
        onBack = onClose,
        onDismissToast = vm::dismissToast,
    )
}
