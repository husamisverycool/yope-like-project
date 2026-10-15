// Surfaces: collage.view (+ collage.share: the share pill and the Sharesheet).
// References: design/collage-options/option-B.jpg (the composed pages); references/auto/yope/frames/b-presskit-wall.png;
// references/owner/yope-week-recap.jpg; references/auto/yope/frames/b-alexaa-7652512140875566349-t5.33-day-view-recap.png
// (screen: back circle, date title, page dots, paged content, bottom pill); a-itsmthuyope-7644974799302823175-t50.60-loading-hud.png
// (loading HUD); references/auto/yope/store/yope-store-04.png and b-derot-store-04-rot-3.65.png (share pill);
// b-yopeapp-7591560669967682847-t66.00-share-with-friends.png (9:16 export).
package app.feature.capture.collage

import android.content.ClipData
import android.content.Context
import android.content.Intent
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.PagerState
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicText
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.produceState
import androidx.compose.runtime.snapshotFlow
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.isTraversalGroup
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.traversalIndex
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.unit.dp
import androidx.core.content.FileProvider
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import app.designsystem.R
import app.designsystem.generated.Tokens
import app.feature.capture.Blocked
import app.feature.capture.data.CaptureDataProvider
import app.feature.capture.sendto.decodePreview
import app.feature.capture.ui.CaptureText
import app.feature.capture.ui.EmptyStateBlock
import app.feature.capture.ui.Glyph
import app.feature.capture.ui.MinTouchTargets
import app.ui.components.HeaderCircleButton
import app.ui.components.HeaderCircleFill
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.File
import java.time.LocalDate
import java.time.format.DateTimeFormatter
import java.util.Locale

/** The FileProvider that hands a shared page to other apps (read grant only). */
class CaptureFileProvider : FileProvider()

/** The collage destination. */
@Composable
fun CollageRoute(groupId: String, invitationId: String, onBack: () -> Unit, onOpenCamera: () -> Unit) {
    val context = LocalContext.current
    val vm: CollageViewModel = viewModel(key = "collage:$invitationId") {
        CollageViewModel(CaptureDataProvider.get(context), groupId, invitationId, context.cacheDir)
    }
    val state by vm.ui.collectAsStateWithLifecycle()
    val title = stringResource(R.string.collage_share_sheettitle)
    LaunchedEffect(vm) {
        vm.event.collect { event ->
            if (event is CollageViewModel.Event.Share) shareImage(context, event.file, title)
        }
    }
    val density = LocalDensity.current
    val pageWidthPx = with(density) { (context.resources.displayMetrics.widthPixels).toFloat() }.toInt()
    CollageScreen(
        state = state,
        pageImage = { file -> rememberPage(file, pageWidthPx) },
        onBack = onBack,
        onPage = vm::onPage,
        onShare = vm::share,
        onOpenCamera = onOpenCamera,
        onRetry = vm::load,
    )
}

@Composable
private fun rememberPage(file: File?, widthPx: Int): ImageBitmap? {
    val image by produceState<ImageBitmap?>(null, file) {
        value = file?.let { withContext(Dispatchers.IO) { decodePreview(it, widthPx) } }
    }
    return image
}

/** `collage.view.title`: the invitation's local date in 'd Month' form ('26 May'). */
internal fun collageDate(date: LocalDate, locale: Locale = Locale.getDefault()): String =
    DateTimeFormatter.ofPattern(COLLAGE_DATE_PATTERN, locale).format(date)

/** collage.view.title: "{date} = daily_invitations.local_date, 'd Month'". */
private const val COLLAGE_DATE_PATTERN = "d MMMM"

/** The collage screen (stateless). Positions from the screen top per `collage.view.layout.screen`. */
@Composable
fun CollageScreen(
    state: CollageViewModel.UiState,
    pageImage: @Composable (File?) -> ImageBitmap?,
    onBack: () -> Unit,
    onPage: (Int) -> Unit,
    onShare: () -> Unit,
    onOpenCamera: () -> Unit,
    onRetry: () -> Unit,
    modifier: Modifier = Modifier,
) = MinTouchTargets {
    val screen = Tokens.Layouts.CollageViewLayoutScreen
    val header = Tokens.Sizes.globalHeaderButton
    val dateText = state.date?.let { stringResource(R.string.collage_view_title, collageDate(it)) }
    BoxWithConstraints(
        modifier
            .fillMaxSize()
            .background(Tokens.Colors.globalBackgroundDeep)
            .semantics { isTraversalGroup = true }
            .testTag("collage.view"),
    ) {
        // Header: back circle and the date, centred on headerCenterFromTop.
        Box(Modifier.fillMaxWidth().padding(top = screen.headerCenterFromTop.dp - header / 2).height(header)) {
            HeaderCircleButton(
                icon = Tokens.Icons.globalBack,
                contentDescription = stringResource(R.string.collage_view_a11y_back),
                onClick = onBack,
                fill = HeaderCircleFill.OnDeep,
                modifier = Modifier.align(Alignment.CenterStart).padding(start = Tokens.Sizes.globalHeaderInset).semantics { traversalIndex = 0f }.testTag("collage.back"),
            )
            if (dateText != null) {
                BasicText(
                    dateText,
                    style = CaptureText.style(Tokens.FontSizes.collageViewFontSizeTitle, Tokens.FontWeights.collageViewFontWeightTitle)
                        .merge(TextStyle(color = Tokens.Colors.globalTextPrimary)),
                    modifier = Modifier.align(Alignment.Center).semantics { heading(); traversalIndex = 1f }.testTag("collage.title"),
                )
            }
        }

        val pageArea = Modifier
            .fillMaxSize()
            .padding(top = screen.pageTop.dp)
            .windowInsetsPadding(WindowInsets.navigationBars)
        when (val content = state.content) {
            CollageViewModel.Content.Loading -> Box(pageArea, contentAlignment = Alignment.Center) { CollageHud() }
            CollageViewModel.Content.Empty -> Box(pageArea, contentAlignment = Alignment.Center) {
                EmptyStateBlock(
                    title = stringResource(R.string.collage_view_empty_title),
                    detail = state.groupName?.let { stringResource(R.string.collage_view_empty_detail, it) },
                    buttonLabel = stringResource(R.string.collage_view_empty_button),
                    onButton = onOpenCamera,
                )
            }
            CollageViewModel.Content.Error -> Box(pageArea, contentAlignment = Alignment.Center) {
                EmptyStateBlock(stringResource(R.string.collage_view_error_title), null, stringResource(R.string.collage_view_error_button), onRetry)
            }
            CollageViewModel.Content.Offline -> Box(pageArea, contentAlignment = Alignment.Center) {
                EmptyStateBlock(stringResource(R.string.collage_view_offline_title), null, stringResource(R.string.collage_view_error_button), onRetry)
            }
            is CollageViewModel.Content.Ready -> {
                val pager = rememberPagerState(initialPage = state.page.coerceIn(0, (content.pages.size - 1).coerceAtLeast(0))) { content.pages.size }
                LaunchedEffect(pager) { snapshotFlow { pager.currentPage }.collect(onPage) }
                if (content.pages.size >= 2) PageDots(pager, content.pages.size, Modifier.padding(top = screen.dotsCenterFromTop.dp - Tokens.Layouts.CollageViewLayoutPageDots.diameter.dp / 2))
                val description = if (state.groupName != null && dateText != null) stringResource(R.string.collage_view_a11y_collage, state.groupName, dateText) else null
                HorizontalPager(state = pager, modifier = pageArea.testTag("collage.pager"), key = { it }) { index ->
                    Box(Modifier.fillMaxSize(), contentAlignment = Alignment.TopCenter) {
                        // 9:16, aspect-fit in the space above the home indicator, centred; the frame is
                        // reserved before the image loads (matte color.global.backgroundDeep).
                        val image = pageImage(content.pages[index])
                        Box(
                            Modifier
                                .fillMaxHeight()
                                .aspectRatio(Tokens.Layouts.CollageViewLayoutPage.canvasAspect, matchHeightConstraintsFirst = true)
                                .then(if (description != null) Modifier.clearAndSetSemantics { contentDescription = description } else Modifier),
                        ) {
                            if (image != null) Image(image, contentDescription = null, contentScale = ContentScale.Fit, modifier = Modifier.fillMaxSize())
                        }
                    }
                }
                if (content.shareable) SharePill(onShare, sharing = state.sharing, Modifier.align(Alignment.BottomCenter))
            }
        }
    }
}

/** Android page dots (`collage.view.layout.pageDots`; iOS uses the native control). */
@Composable
private fun PageDots(pager: PagerState, count: Int, modifier: Modifier) {
    val dots = Tokens.Layouts.CollageViewLayoutPageDots
    val label = stringResource(R.string.collage_view_a11y_page, (pager.currentPage + 1).toString(), count.toString())
    Box(modifier.fillMaxWidth(), contentAlignment = Alignment.TopCenter) {
        Row(
            Modifier.semantics { contentDescription = label; traversalIndex = 2f }.testTag("collage.dots"),
            horizontalArrangement = Arrangement.spacedBy(dots.pitch.dp - dots.diameter.dp),
        ) {
            repeat(count) { i ->
                Box(
                    Modifier
                        .size(dots.diameter.dp)
                        .clip(CircleShape)
                        .background(if (i == pager.currentPage) Tokens.Colors.collageViewColorPageDotActive else Tokens.Colors.globalControlRaised),
                )
            }
        }
    }
}

/** The loading HUD (`collage.view.layout.hud`, `collage.view.color.hud`): platform indicator over `collage.view.loading`. */
@Composable
private fun CollageHud() {
    val hud = Tokens.Layouts.CollageViewLayoutHud
    Column(
        Modifier
            .size(hud.width.dp, hud.height.dp)
            .clip(RoundedCornerShape(hud.cornerRadius.dp))
            .background(Tokens.Colors.collageViewColorHud)
            .testTag("collage.hud"),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.SpaceEvenly,
    ) {
        CircularProgressIndicator(color = Tokens.Colors.globalTextPrimary)
        BasicText(stringResource(R.string.collage_view_loading), style = CaptureText.body.merge(TextStyle(color = Tokens.Colors.globalTextPrimary)))
    }
}

/**
 * The share pill (`collage.share.layout.pill`): 126 × 58, corner 10, bottom edge 36 above the
 * screen bottom; glyph `collage.share.icon.share` + label `collage.share.button`
 * (`collage.share.fontSize.label` / `.fontWeight.label`), both `color.global.textPrimary`. Its
 * frosted fill is BLOCKED ([Blocked.sharePillFill]).
 */
@Composable
private fun SharePill(onShare: () -> Unit, sharing: Boolean, modifier: Modifier) {
    val pill = Tokens.Layouts.CollageShareLayoutPill
    val label = stringResource(R.string.collage_share_button)
    val shape = RoundedCornerShape(pill.cornerRadius.dp)
    Row(
        modifier
            .padding(bottom = pill.bottomFromScreenBottom.dp)
            .size(pill.width.dp, pill.height.dp)
            .clip(shape)
            .then(Blocked.sharePillFill?.let { Modifier.background(it) } ?: Modifier)
            .clickable(enabled = !sharing, onClick = onShare)
            .testTag("collage.share")
            .clearAndSetSemantics { contentDescription = label; role = Role.Button; traversalIndex = 4f },
        horizontalArrangement = Arrangement.Center,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Glyph(Tokens.Icons.collageShareIconShare, Tokens.Colors.globalTextPrimary, pill.glyph.dp)
        BasicText(
            label,
            style = CaptureText.style(Tokens.FontSizes.collageShareFontSizeLabel, Tokens.FontWeights.collageShareFontWeightLabel)
                .merge(TextStyle(color = Tokens.Colors.globalTextPrimary)),
        )
    }
}

/** The Android Sharesheet with the page JPEG (content://, read grant) and the preview title. */
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
