// Surfaces: collage.view and collage.share — Retro's 2026 recap preview (ST-04) holding the worker's collage page as
// its card: the rounded media page with the collage's first photo blurred (L-7), the close circle, page dots below the page, the white "Share"
// pill. The chrome is the shared core:ui `RecapPreviewScreen` (also used by week.recap and year.story).
// References: references/auto/retro/store/retro-store-04.png (ST-04); references/auto/retro/press/tc-2023-12-recaps.png
// (card on the blurred backdrop); design/collage-options/option-B.jpg (the pages). Decisions: RC-14, RC-15, RC-19.
package app.feature.capture.collage

import android.content.ClipData
import android.content.Context
import android.content.Intent
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.produceState
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.painter.BitmapPainter
import androidx.compose.ui.graphics.painter.Painter
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextAlign
import androidx.core.content.FileProvider
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import app.designsystem.R
import app.designsystem.generated.Tokens
import app.feature.capture.data.CaptureDataProvider
import app.feature.capture.sendto.decodePreview
import app.feature.capture.ui.FadeImage
import app.feature.capture.ui.MediaEmptyState
import app.feature.capture.ui.MediaProgressBlock
import app.ui.components.EmptyStateAction
import app.ui.components.PlatformToast
import app.ui.foundation.tapClickable
import app.ui.format.Formats
import app.ui.recap.MediaReportMenu
import app.ui.recap.RecapPill
import app.ui.recap.RecapPreviewDefaults
import app.ui.recap.RecapPreviewScreen
import app.ui.text.TextRoles
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.File

/** The collage destination: view model, page decoding, share sheet and navigation out. */
@Composable
fun CollageRoute(
    groupId: String,
    invitationId: String,
    onBack: () -> Unit,
    onOpenCamera: () -> Unit,
    onReport: (collageId: String) -> Unit = {},
) {
    val context = LocalContext.current
    val vm: CollageViewModel = viewModel(key = "collage:$invitationId") {
        CollageViewModel(CaptureDataProvider.get(context), groupId, invitationId, context.cacheDir)
    }
    app.feature.capture.ui.MediaSystemBars()
    val state by vm.ui.collectAsStateWithLifecycle()
    val date = state.date?.let(Formats::longDate).orEmpty()
    val sheetTitle = stringResource(R.string.collage_share_sheettitle, date)
    val offline = stringResource(R.string.camera_sendto_error_offline)
    val generic = stringResource(R.string.camera_sendto_error_generic)
    LaunchedEffect(vm, sheetTitle) {
        vm.event.collect { event ->
            when (event) {
                is CollageViewModel.Event.Share -> shareImage(context, event.file, sheetTitle)
                is CollageViewModel.Event.ShareFailed -> PlatformToast.show(context, if (event.offline) offline else generic)
            }
        }
    }
    val pageWidthPx = context.resources.displayMetrics.widthPixels
    CollageScreen(
        state = state,
        pageImage = { file -> rememberPage(file, pageWidthPx) },
        onBack = onBack,
        onPage = vm::onPage,
        onShare = vm::share,
        onOpenCamera = onOpenCamera,
        onRetry = vm::load,
        onReport = { state.collageId?.let(onReport) },
    )
}

@Composable
private fun rememberPage(file: File?, widthPx: Int): Painter? {
    val image by produceState<Painter?>(null, file) {
        value = file?.let { withContext(Dispatchers.IO) { decodePreview(it, widthPx) } }?.let(::BitmapPainter)
    }
    return image
}

/**
 * The collage screen (stateless) in the recap preview (`collage.view.layout.screen`): the backdrop is the collage's
 * first photo blurred (`mediaPage`, MERGE_DECISIONS L-7; page 1 until it loads);
 * the card is the current page, aspect-fit in the media page inset by [RecapPreviewDefaults.collageCardPadding] and
 * clipped to `collage.view.layout.page.outerRadiusRatio` × its width. Loading / empty / error / offline fill the
 * media page with `color.global.controlOnDeep` (no dots, no Share).
 */
@Composable
fun CollageScreen(
    state: CollageViewModel.UiState,
    pageImage: @Composable (File?) -> Painter?,
    onBack: () -> Unit,
    onPage: (Int) -> Unit,
    onShare: () -> Unit,
    onOpenCamera: () -> Unit,
    onRetry: () -> Unit,
    modifier: Modifier = Modifier,
    /** "Report Collage" (safety.report, MERGE FV-4): the "•••" before the close circle once the collage is composed. */
    onReport: () -> Unit = {},
) {
    val ready = state.content as? CollageViewModel.Content.Ready
    val pages = ready?.pages.orEmpty()
    // The collage's first photo, aspect-filled and blurred (L-7); page 1's image only until it has loaded.
    val firstPhoto = pageImage(state.backdrop)
    val pageOne = ready?.let { pageImage(pages.firstOrNull()) }
    val backdrop = if (ready != null) firstPhoto ?: pageOne else null
    val pageLabel = stringResource(R.string.collage_view_a11y_collage, state.groupName.orEmpty(), state.date?.let(Formats::longDate).orEmpty())
    RecapPreviewScreen(
        backdrop = backdrop,
        pageCount = pages.size.coerceAtLeast(1),
        currentPage = state.page.coerceIn(0, (pages.size - 1).coerceAtLeast(0)),
        onPageChange = onPage,
        onClose = onBack,
        closeContentDescription = stringResource(R.string.collage_view_a11y_close),
        modifier = modifier.testTag("collage.view"),
        pill = if (ready != null && ready.shareable) RecapPill(stringResource(R.string.collage_share_button), onShare, busy = state.sharing) else null,
        dotsDescription = stringResource(R.string.collage_view_a11y_page, state.page + 1, pages.size),
        beforeClose = if (ready != null && state.collageId != null) ({
            MediaReportMenu(stringResource(R.string.safety_report_menuitem_collage), onReport)
        }) else null,
    ) { page ->
        when (val content = state.content) {
            is CollageViewModel.Content.Ready -> CollageCard(pageImage(content.pages.getOrNull(page)), pageLabel)
            CollageViewModel.Content.Loading -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                MediaProgressBlock(stringResource(R.string.collage_view_loading))
            }
            CollageViewModel.Content.Empty -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                MediaEmptyState(
                    title = stringResource(R.string.collage_view_empty_title),
                    detail = stringResource(R.string.collage_view_empty_detail),
                    action = EmptyStateAction(stringResource(R.string.collage_view_empty_button), onOpenCamera, Tokens.Icons.globalCamera),
                    icon = Tokens.Icons.globalCamera,
                )
            }
            CollageViewModel.Content.Error -> ErrorLine(stringResource(R.string.collage_view_error_title), onRetry)
            CollageViewModel.Content.Offline -> ErrorLine(stringResource(R.string.collage_view_offline_title), onRetry)
        }
    }
}

/** The current page as the recap card: aspect-fit (9:16) in the card box, clipped to the page's own corner ratio; fades in. */
@Composable
private fun CollageCard(image: Painter?, label: String) {
    val page = Tokens.Layouts.CollageViewLayoutPage
    Box(Modifier.fillMaxSize().padding(RecapPreviewDefaults.collageCardPadding), contentAlignment = Alignment.Center) {
        androidx.compose.foundation.layout.BoxWithConstraints(Modifier.aspectRatio(page.canvasAspect)) {
            Box(
                Modifier
                    .fillMaxSize()
                    .clip(RoundedCornerShape(maxWidth * page.outerRadiusRatio))
                    .semantics {
                        contentDescription = label
                        role = Role.Image
                    }
                    .testTag("collage.page"),
            ) { FadeImage(image, Modifier.fillMaxSize()) }
        }
    }
}

/** Retro's list-error line: one tappable line centred, text role `body`, `color.global.textOnMedia`; a tap refetches. */
@Composable
private fun ErrorLine(text: String, onRetry: () -> Unit) {
    Box(Modifier.fillMaxSize().padding(horizontal = Tokens.Sizes.globalScreenMargin), contentAlignment = Alignment.Center) {
        Text(
            text,
            style = TextRoles.body,
            color = Tokens.Colors.globalTextOnMedia,
            textAlign = TextAlign.Center,
            modifier = Modifier
                .tapClickable(onClick = onRetry)
                .padding(Tokens.Sizes.globalScreenMargin)
                .testTag("collage.retry"),
        )
    }
}

/** Hands [file] (the worker's 9:16 share image) to the Android Sharesheet titled [title] (`collage.share.layout.sheet`). */
internal fun shareImage(context: Context, file: File, title: String) {
    val uri = FileProvider.getUriForFile(context, context.packageName + ".capture.files", file)
    val send = Intent(Intent.ACTION_SEND)
        .setType(SHARE_MIME)
        .putExtra(Intent.EXTRA_STREAM, uri)
        .putExtra(Intent.EXTRA_TITLE, title)
        .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
    send.clipData = ClipData.newRawUri(title, uri)
    context.startActivity(Intent.createChooser(send, title).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
}

private const val SHARE_MIME = "image/jpeg" // provenance-ok: MIME type of the worker's share-<n>.jpg
