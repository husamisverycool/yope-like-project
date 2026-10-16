// Surface: groups.invite — the in-app QR invite card (owner decision 17; design/surfaces/groups.invite.md "QR card";
// token groups.invite.layout.qrCard). References: references/auto/retro/press/tc-2024-04-retro-journals-5.png (TC-J5
// phone 2: "QR Code" first of the share targets), references/auto/retro/apk/retro-android-2026.10.1150-strings.txt
// (APK-S: qr_card_content_subtitle, journal_qr_code_action_sheet_title), references/auto/retro/press/tc-2023-12-recaps.png
// (TC-REC: the recap card the QR sits in) and references/auto/retro/store/retro-store-04.png (ST-04: the recap preview
// around it). Encoding as the web invite page (web/src/render/qr.ts): error correction H, whole-pixel modules, black on
// white, a four-module quiet zone.
package app.feature.account.groups

import android.Manifest
import android.content.ClipData
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.paddingFromBaseline
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.wrapContentHeight
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.Immutable
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawWithContent
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.asAndroidBitmap
import androidx.compose.ui.graphics.layer.drawLayer
import androidx.compose.ui.graphics.rememberGraphicsLayer
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Density
import androidx.compose.ui.unit.Dp
import androidx.core.content.FileProvider
import app.designsystem.R
import app.designsystem.dsTextStyle
import app.designsystem.generated.Tokens
import app.feature.account.platform.ExternalActions
import app.ui.components.CircleButtonStyle
import app.ui.components.CircleIconButton
import app.ui.recap.RecapDots
import app.ui.recap.RecapPill
import app.ui.recap.RecapPreviewScreen
import app.ui.text.TextRoles
import com.google.zxing.qrcode.decoder.ErrorCorrectionLevel
import com.google.zxing.qrcode.encoder.Encoder
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.ByteArrayOutputStream
import java.io.File
import java.util.UUID
import kotlin.math.floor
import kotlin.math.min

/** The modules of a QR symbol, without its quiet zone: [size] × [size], row-major, true = dark. */
class QrMatrix(val size: Int, private val dark: BooleanArray) {
    init {
        require(dark.size == size * size) { "matrix is not square" }
    }

    fun isDark(x: Int, y: Int): Boolean = dark[y * size + x]
}

/** QR encoding of an invite link (`groups.invite.layout.qrCard`: error correction H, byte mode — as web/src/render/qr.ts). */
object InviteQr {
    private val spec get() = Tokens.Layouts.GroupsInviteLayoutQrCard

    /** Modules of white around the symbol on each side (`quietZoneModules`, DENSO WAVE: four). */
    val quietZone: Int get() = spec.quietZoneModules.toInt()

    /** The symbol of [link] (ZXing core [Encoder]; the URL is ASCII, so byte mode without an ECI header, as the web). */
    fun matrix(link: String): QrMatrix {
        val code = Encoder.encode(link, ErrorCorrectionLevel.valueOf(spec.errorCorrection))
        val m = code.matrix
        val n = m.width
        val bits = BooleanArray(n * n) { i -> m.get(i % n, i / n).toInt() == 1 }
        return QrMatrix(n, bits)
    }

    /**
     * Side of one module in whole pixels for a square [sidePx] wide holding the symbol and its quiet zone (web:
     * `floor(size / modules)`), never below one pixel.
     */
    fun modulePx(sidePx: Float, modules: Int): Float = maxOf(1f, floor(sidePx / (modules + 2 * quietZone)))
}

/**
 * The symbol drawn in black (`color.global.onSurfaceLight`) square modules of a whole number of pixels, centred in the
 * box it is given; the white around it (the card) is the quiet zone. Decorative (the card carries the label).
 */
@Composable
fun QrCodeImage(matrix: QrMatrix, modifier: Modifier = Modifier) {
    val ink = Tokens.Colors.globalOnSurfaceLight
    Canvas(modifier) {
        val n = matrix.size
        val module = InviteQr.modulePx(min(size.width, size.height), n)
        val drawn = module * n
        val left = floor((size.width - drawn) / 2)
        val top = floor((size.height - drawn) / 2)
        for (y in 0 until n) {
            var x = 0
            while (x < n) {
                if (!matrix.isDark(x, y)) {
                    x++
                    continue
                }
                var run = 1
                while (x + run < n && matrix.isDark(x + run, y)) run++
                drawRect(ink, topLeft = Offset(left + x * module, top + y * module), size = Size(run * module, module))
                x += run
            }
        }
    }
}

/**
 * The QR card (`groups.invite.layout.qrCard`): Retro's recap card shell (`layout.year.story.recapCard`, white in both
 * appearances — L-4) [width] wide, corners `cornerRadiusRatio` × the width, padding `paddingRatio` × the width; the
 * symbol of [link] in its square grid area (width − 2 × padding); then the footer, `footerHeightRatio` × the width:
 * [groupName] (text role `displayTitle`, `color.global.onSurfaceLight`, one line) over the tagline
 * `groups.invite.qr.tagline` (`groups.invite.fontSize.qrTagline` in `font.global.family`, `groups.invite.color.note`), at
 * the padding, placed by baselines (`lastBaselineFromBottomRatio`, `baselinePitchRatio`, measured on TC-REC). A picture (also the saved / shared image): its text ignores the font scale. TalkBack:
 * one image, `groups.invite.qr.accessibilityLabel`.
 */
@Composable
fun InviteQrCard(link: String, groupName: String, width: Dp, modifier: Modifier = Modifier) {
    val card = Tokens.Layouts.YearStoryRecapCard
    val matrix = remember(link) { InviteQr.matrix(link) }
    val padding = width * card.paddingRatio
    val label = stringResource(R.string.groups_invite_qr_accessibilitylabel, groupName)
    val tagline = dsTextStyle(Tokens.FontSizes.groupsInviteFontSizeQrTagline, FontWeight.Normal, Tokens.Fonts.globalFamily)
    CompositionLocalProvider(LocalDensity provides Density(LocalDensity.current.density, fontScale = 1f)) {
        Column(
            modifier
                .width(width)
                .clip(RoundedCornerShape(width * card.cornerRadiusRatio))
                .background(Tokens.Colors.globalSurfaceLight)
                .clearAndSetSemantics {
                    contentDescription = label
                    role = Role.Image
                    testTag = GROUP_INVITE_QR_CARD_TAG
                },
        ) {
            QrCodeImage(matrix, Modifier.padding(start = padding, top = padding, end = padding).size(width - padding * 2))
            // Placed by baselines, as Retro's recap card footer (TC-REC): the tagline's baseline `lastBaselineFromBottomRatio`
            // × width above the card's bottom edge, the name's `baselinePitchRatio` × width above it.
            val taglineBaseline = width * Tokens.Layouts.GroupsInviteLayoutQrCard.lastBaselineFromBottomRatio
            val namePitch = width * Tokens.Layouts.GroupsInviteLayoutQrCard.baselinePitchRatio
            Box(Modifier.fillMaxWidth().height(width * card.footerHeightRatio).padding(horizontal = padding)) {
                Text(
                    stringResource(R.string.groups_invite_qr_tagline),
                    style = tagline,
                    color = Tokens.Colors.groupsInviteColorNote,
                    maxLines = 1,
                    modifier = Modifier.align(Alignment.BottomStart).paddingFromBaseline(bottom = taglineBaseline),
                )
                Text(
                    groupName,
                    style = TextRoles.displayTitle,
                    color = Tokens.Colors.globalOnSurfaceLight,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                    // Unbounded: the name's line box may rise above the footer (its ink stays inside) rather than push it down.
                    modifier = Modifier
                        .align(Alignment.BottomStart)
                        .wrapContentHeight(Alignment.Bottom, unbounded = true)
                        .paddingFromBaseline(bottom = taglineBaseline + namePitch),
                )
            }
        }
    }
}

/** Test tag of the QR card (measurements). */
const val GROUP_INVITE_QR_CARD_TAG = "groups.invite.qr.card" // provenance-ok: test tag, not shown

/** What the QR screen does: close, and Save / Share with the card's pixels. */
@Immutable
data class InviteQrActions(
    val onClose: () -> Unit = {},
    val onSave: (ImageBitmap) -> Unit = {},
    val onShare: (ImageBitmap) -> Unit = {},
)

/**
 * The QR screen (`groups.invite.layout.qrCard` presentation): Retro's recap preview (`RecapPreviewScreen`, ST-04) — the
 * group's cover blurred in the media page ([coverUrl]; none → `color.global.controlOnDeep`), the [InviteQrCard] centred
 * at the recap card's width ratio of the page, the close circle, the Save circle (C-11 on media, `icon.global.download`)
 * bottom-leading and the light "Share" pill trailing. Save and Share hand the card's drawn layer (the card alone, no
 * backdrop) to [actions]. Media surface: black in both appearances.
 */
@Composable
fun GroupInviteQrScreen(link: String, groupName: String, coverUrl: Any?, actions: InviteQrActions, modifier: Modifier = Modifier) {
    val layer = rememberGraphicsLayer()
    val scope = rememberCoroutineScope()
    fun capture(then: (ImageBitmap) -> Unit) {
        // The layer holds the card once it has been drawn (before that there is nothing to save or share).
        if (layer.size.width > 0 && layer.size.height > 0) scope.launch { then(layer.toImageBitmap()) }
    }
    RecapPreviewScreen(
        backdrop = coverUrl,
        pageCount = 1,
        currentPage = 0,
        onPageChange = {},
        onClose = actions.onClose,
        closeContentDescription = stringResource(R.string.groups_invite_close_accessibilitylabel),
        modifier = modifier,
        pill = RecapPill(stringResource(R.string.groups_invite_qr_share), { capture(actions.onShare) }),
        dots = RecapDots.Hidden,
        bottomLeading = {
            CircleIconButton(
                Tokens.Icons.globalDownload,
                stringResource(R.string.groups_invite_qr_save),
                { capture(actions.onSave) },
                Modifier.padding(start = Tokens.Sizes.globalButtonMarginH),
                style = CircleButtonStyle.OnMedia,
            )
        },
    ) {
        BoxWithConstraints(Modifier.matchParentSize(), contentAlignment = Alignment.Center) {
            val width = maxWidth * Tokens.Layouts.YearStoryRecapCard.widthRatio
            InviteQrCard(
                link,
                groupName,
                width,
                Modifier.drawWithContent {
                    layer.record { this@drawWithContent.drawContent() }
                    drawLayer(layer)
                },
            )
        }
    }
}

/** Saving and sharing the QR card image (`groups.invite.layout.qrCard` export: PNG). */
object InviteQrExport {
    /** API 26–28 need WRITE_EXTERNAL_STORAGE to insert into the shared Pictures collection; 29+ need nothing. */
    fun needsPermission(context: Context): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.Q &&
            context.checkSelfPermission(Manifest.permission.WRITE_EXTERNAL_STORAGE) != PackageManager.PERMISSION_GRANTED

    fun png(image: ImageBitmap): ByteArray = ByteArrayOutputStream().use { out ->
        image.asAndroidBitmap().compress(Bitmap.CompressFormat.PNG, PNG_QUALITY, out)
        out.toByteArray()
    }

    /** Inserts [png] into Pictures (MediaStore); false when it failed. */
    suspend fun save(context: Context, png: ByteArray): Boolean = withContext(Dispatchers.IO) {
        val resolver = context.contentResolver
        val values = ContentValues().apply {
            put(MediaStore.MediaColumns.DISPLAY_NAME, "${UUID.randomUUID()}.png") // provenance-ok: file name, not shown
            put(MediaStore.MediaColumns.MIME_TYPE, PNG_TYPE)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                put(MediaStore.MediaColumns.RELATIVE_PATH, Environment.DIRECTORY_PICTURES)
                put(MediaStore.MediaColumns.IS_PENDING, 1)
            }
        }
        val uri = runCatching { resolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values) }.getOrNull() ?: return@withContext false
        val written = runCatching { resolver.openOutputStream(uri)?.use { it.write(png) } != null }.getOrDefault(false)
        if (!written) {
            runCatching { resolver.delete(uri, null, null) }
            return@withContext false
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            resolver.update(uri, ContentValues().apply { put(MediaStore.MediaColumns.IS_PENDING, 0) }, null, null)
        }
        true
    }

    /** The Sharesheet with [png] (`groups.invite.layout.share`: `Intent.createChooser(ACTION_SEND)`, here image/png). */
    suspend fun share(context: Context, png: ByteArray) {
        val file = withContext(Dispatchers.IO) {
            File(context.cacheDir, "invite/${UUID.randomUUID()}.png").also { // provenance-ok: cache file name, not shown
                it.parentFile?.mkdirs()
                it.writeBytes(png)
            }
        }
        val uri = FileProvider.getUriForFile(context, context.packageName + ".account.files", file)
        val send = Intent(Intent.ACTION_SEND)
            .setType(PNG_TYPE)
            .putExtra(Intent.EXTRA_STREAM, uri)
            .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        send.clipData = ClipData.newRawUri(null, uri)
        ExternalActions.start(context, Intent.createChooser(send, null))
    }

    private const val PNG_TYPE = "image/png" // provenance-ok: MIME type
    private const val PNG_QUALITY = 100 // provenance-ok: PNG is lossless (the argument is ignored)
}
