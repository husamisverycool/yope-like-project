// Surface: birthday.tribute — design/surfaces/birthday.tribute.md (B. the tribute screen)
// References: references/auto/vidday/store/vidday-store-08.png, -09.png (recipient page, Download, player);
// references/auto/tribute/mockups/tribute-home-phone-step-3-completed-page.png (finished page);
// references/auto/tribute/web/tribute-web-testimonials.computed-styles.json (secondary buttons).
package app.feature.memory.birthday

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.asPaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.BasicText
import androidx.compose.foundation.verticalScroll
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.stringResource
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
import app.feature.memory.common.MemoryBackend
import app.feature.memory.common.MemoryToast
import app.feature.memory.common.MessageBlock
import app.feature.memory.common.PlatformSpinner
import app.feature.memory.common.heading
import app.feature.memory.common.headerClearance
import app.feature.memory.common.rememberMemoryBackend
import app.feature.memory.common.roleStyle
import app.feature.memory.share.MemoryFiles
import java.time.Clock

/** The birthday person's video: title, group, player, Download and Share. */
@Composable
fun TributeScreen(
    state: TributeState,
    autoplay: Boolean,
    onDownload: () -> Unit,
    onShare: () -> Unit,
    onRetry: () -> Unit,
    onClose: () -> Unit,
    onDismissToast: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Box(modifier.fillMaxSize().background(Tokens.Colors.globalBackgroundDeep).testTag("birthday.tribute")) {
        when (val content = state.content) {
            TributeContent.NotFound -> MessageBlock(
                stringResource(R.string.birthday_tribute_notfound_title),
                stringResource(R.string.birthday_tribute_notfound_detail),
                Modifier.fillMaxSize(),
            )
            TributeContent.Failed -> MessageBlock(
                stringResource(R.string.birthday_tribute_error_title),
                stringResource(R.string.birthday_tribute_error_detail),
                Modifier.fillMaxSize(),
                action = stringResource(R.string.birthday_tribute_error_retry),
                onAction = onRetry,
            )
            else -> Page(state, content, autoplay, onDownload, onShare)
        }
        LeadingHeaderCircle(Tokens.Icons.globalClose, stringResource(R.string.birthday_tribute_a11y_close), onClose)
        MemoryToast(
            message = when (state.toast) {
                TributeState.Toast.Saved -> stringResource(R.string.birthday_tribute_saved)
                TributeState.Toast.SaveFailed -> stringResource(R.string.birthday_tribute_savefailed)
                null -> null
            },
            onDismiss = onDismissToast,
            success = state.toast == TributeState.Toast.Saved,
        )
    }
}

@Composable
private fun Page(state: TributeState, content: TributeContent, autoplay: Boolean, onDownload: () -> Unit, onShare: () -> Unit) {
    val navigation = WindowInsets.navigationBars.asPaddingValues().calculateBottomPadding()
    val headerBottom = headerClearance()
    Column(
        Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(start = Tokens.Sizes.birthdayRequestMargin, end = Tokens.Sizes.birthdayRequestMargin, top = headerBottom),
    ) {
        BasicText(
            stringResource(R.string.birthday_tribute_title),
            Modifier.heading(),
            style = roleStyle(Tokens.FontSizes.birthdayRequestTitle, Tokens.FontWeights.fontWeightBirthdayRequestTitle, Tokens.LineHeights.birthdayRequestTitle, Tokens.Fonts.birthday)
                .copy(color = Tokens.Colors.globalTextPrimary),
        )
        state.groupName?.let { name ->
            BasicText(
                name,
                style = roleStyle(Tokens.FontSizes.birthdayRequestMessage, Tokens.FontWeights.fontWeightGlobalListSubtitle, family = Tokens.Fonts.birthday)
                    .copy(color = Tokens.Colors.globalTextSecondary),
            )
        }
        if (content == TributeContent.Offline) {
            BasicText(
                stringResource(R.string.birthday_tribute_offline),
                style = roleStyle(Tokens.FontSizes.globalListSubtitle, Tokens.FontWeights.fontWeightGlobalListSubtitle).copy(color = Tokens.Colors.globalTextSecondary),
            )
        }
        Spacer(Modifier.size(Tokens.Sizes.birthdayRequestMessageGap))
        when (content) {
            is TributeContent.Ready -> TributePlayer(content.videoUrl, content.posterUrl, autoplay, Modifier.fillMaxWidth())
            TributeContent.Loading, TributeContent.Rendering -> Box(Modifier.fillMaxWidth().aspectRatio(tributeAspect), contentAlignment = Alignment.Center) {
                PlatformSpinner()
            }
            else -> Unit
        }
        val ready = content is TributeContent.Ready
        Spacer(Modifier.size(Tokens.Sizes.birthdayRequestCtaGap))
        TributeSecondaryButton(stringResource(R.string.birthday_tribute_download), onDownload, icon = Tokens.Icons.globalDownload, enabled = ready && !state.saving)
        Spacer(Modifier.size(Tokens.Sizes.birthdayTributeButtonGap))
        TributeSecondaryButton(stringResource(R.string.birthday_tribute_share), onShare, icon = Tokens.Icons.globalShare, enabled = ready)
        Spacer(Modifier.size(navigation + Tokens.Sizes.birthdayRequestMargin))
    }
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
    TributeScreen(
        state = state,
        autoplay = !reduceMotion,
        onDownload = {
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
        onDismissToast = vm::dismissToast,
    )
}
