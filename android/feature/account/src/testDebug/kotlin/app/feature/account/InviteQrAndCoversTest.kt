package app.feature.account

import android.graphics.BitmapFactory
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.toPixelMap
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.SemanticsProperties
import androidx.compose.ui.test.SemanticsMatcher
import androidx.compose.ui.test.assert
import androidx.compose.ui.test.captureToImage
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.onRoot
import androidx.compose.ui.test.printToString
import androidx.compose.ui.unit.dp
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import app.data.model.GroupInvite
import app.data.model.GroupKind
import app.designsystem.R
import app.designsystem.generated.Tokens
import app.feature.account.groups.GROUP_INVITE_QR_CARD_TAG
import app.feature.account.groups.GroupInviteActions
import app.feature.account.groups.GroupInviteScreen
import app.feature.account.groups.GroupInviteUiState
import app.feature.account.groups.InviteQr
import app.feature.account.groups.InviteQrActions
import app.feature.account.groups.InviteQrCard
import app.feature.account.groups.QrMatrix
import app.feature.account.groups.templateCover
import app.feature.account.testing.fakeEnvironment
import app.ui.theme.AppTheme
import com.google.zxing.BinaryBitmap
import com.google.zxing.DecodeHintType
import com.google.zxing.RGBLuminanceSource
import com.google.zxing.ResultMetadataType
import com.google.zxing.common.HybridBinarizer
import com.google.zxing.qrcode.QRCodeReader
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode
import java.time.Instant
import java.time.ZoneId

/**
 * The in-app QR invite card (groups.invite, owner decision 17; `groups.invite.layout.qrCard`): the symbol ZXing encodes,
 * the drawn card read back by ZXing's decoder (the link the sheet shares, error correction H), its TalkBack label and
 * the "QR Code" target; and the "Ideas to Get Started" covers (`groups.list.layout.templateCovers`, owner decision 9).
 */
@RunWith(AndroidJUnit4::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@Config(qualifiers = "w393dp-h852dp-xhdpi")
class InviteQrAndCoversTest {
    @get:Rule val compose = createComposeRule()

    private val link = "https://example.test/i/AbCdEfGhIjKlMnOpQrStUvWx"
    private val context get() = ApplicationProvider.getApplicationContext<android.content.Context>()

    // Encoding --------------------------------------------------------------------------------------

    @Test fun matrixIsASymbolWithItsThreeFinderPatterns() {
        val m = InviteQr.matrix(link)
        assertTrue("a QR version is 21 + 4k modules wide", m.size >= 21 && (m.size - 21) % 4 == 0)
        val far = m.size - 7
        for ((left, top) in listOf(0 to 0, far to 0, 0 to far)) {
            for (step in 0 until 7) {
                assertTrue(m.isDark(left + step, top) && m.isDark(left + step, top + 6))
                assertTrue(m.isDark(left, top + step) && m.isDark(left + 6, top + step))
            }
            assertTrue("light ring", !m.isDark(left + 1, top + 1))
            assertTrue("dark core", m.isDark(left + 3, top + 3))
        }
    }

    @Test fun symbolReadsBackAsTheLinkAtLevelH() {
        val m = InviteQr.matrix(link)
        val module = 4
        val result = decode(render(m, module), (m.size + 2 * InviteQr.quietZone) * module)
        assertEquals(link, result.first)
        assertEquals("error correction H, as web/src/render/qr.ts", "H", result.second)
    }

    @Test fun quietZoneAndWholePixelModules() {
        assertEquals("DENSO WAVE: a four-module margin", 4, InviteQr.quietZone)
        // 308 dp at 3× for a 41-module symbol (+ 8 quiet): floor(924 ÷ 49) = 18 px, as the web floors.
        assertEquals(18f, InviteQr.modulePx(924f, 41))
        assertEquals("never below one pixel", 1f, InviteQr.modulePx(20f, 41))
    }

    // The drawn card --------------------------------------------------------------------------------

    @Test fun drawnCardReadsBackAsTheLinkAndIsOneLabelledImage() {
        compose.setContent { AppTheme(dark = true) { InviteQrCard(link, "Sunday Dinners", 324.dp) } }
        val label = context.getString(R.string.groups_invite_qr_accessibilitylabel, "Sunday Dinners")
        assertEquals("QR code for joining Sunday Dinners", label)
        compose.onNodeWithContentDescription(label).assert(SemanticsMatcher.expectValue(SemanticsProperties.Role, Role.Image))
        val image = compose.onNodeWithTag(GROUP_INVITE_QR_CARD_TAG).captureToImage()
        val decoded = decode(image)
        assertEquals("the card encodes the link the sheet shares (white card in the dark appearance)", link, decoded.first)
        assertEquals("H", decoded.second)
    }

    @Test fun qrCodeTargetOpensTheCardAndSaveHandsOverItsPixels() {
        var opened = false
        var saved: ImageBitmap? = null
        val invite = GroupInvite("i1", "g1", "AbCdEfGhIjKlMnOpQrStUvWx", "u-me", Instant.EPOCH, Instant.EPOCH.plusSeconds(86_400), null)
        val state = GroupInviteUiState(groupName = "Sunday Dinners", kind = GroupKind.Friends, invite = invite, loading = false)
        var qrLink by mutableStateOf<String?>(null)
        compose.setContent {
            CompositionLocalProvider(LocalAccountEnvironment provides fakeEnvironment()) {
                AppTheme {
                    GroupInviteScreen(
                        state,
                        ZoneId.of("UTC"),
                        GroupInviteActions(onQr = { opened = true; qrLink = link }, qr = InviteQrActions(onSave = { saved = it })),
                        qrLink = qrLink,
                    )
                }
            }
        }
        compose.onNodeWithText(context.getString(R.string.groups_invite_link_qr)).performClick()
        compose.waitForIdle()
        assertTrue("QR Code → the card", opened)
        println(compose.onRoot(useUnmergedTree = true).printToString())
        compose.onNodeWithTag(GROUP_INVITE_QR_CARD_TAG).assertExists()
        compose.onNodeWithContentDescription(context.getString(R.string.groups_invite_qr_save)).performClick()
        compose.waitUntil(timeoutMillis = 5_000) { saved != null }
        assertNotNull(saved)
        assertEquals("Save gets the card's own pixels", link, decode(saved!!).first)
    }

    // Template covers -------------------------------------------------------------------------------

    @Test fun everyKindHasItsBundledCoverAtThreeTimesTheThumbnail() {
        val covers = Tokens.Layouts.GroupsListLayoutTemplateCovers
        val expected = mapOf(
            GroupKind.Friends to covers.friends,
            GroupKind.Family to covers.family,
            GroupKind.Roommates to covers.roommates,
            GroupKind.Custom to covers.custom,
        )
        for ((kind, name) in expected) {
            val id = templateCover(kind)
            assertEquals("drawable named by the token", name, context.resources.getResourceEntryName(id))
            val bitmap = context.resources.openRawResource(id).use { BitmapFactory.decodeStream(it) }
            assertEquals(covers.pixelWidth.toInt(), bitmap.width)
            assertEquals(covers.pixelHeight.toInt(), bitmap.height)
        }
        assertEquals("one photo per kind", GroupKind.entries.size, expected.values.toSet().size)
    }

    // Helpers ---------------------------------------------------------------------------------------

    /** The symbol and its quiet zone, [module] pixels per module, black on white (ARGB). */
    private fun render(m: QrMatrix, module: Int): IntArray {
        val side = (m.size + 2 * InviteQr.quietZone) * module
        val pixels = IntArray(side * side) { WHITE }
        for (y in 0 until m.size) for (x in 0 until m.size) {
            if (!m.isDark(x, y)) continue
            for (dy in 0 until module) for (dx in 0 until module) {
                pixels[((y + InviteQr.quietZone) * module + dy) * side + (x + InviteQr.quietZone) * module + dx] = BLACK
            }
        }
        return pixels
    }

    /** ZXing's QR reader on [pixels] (ARGB, [side] wide): the text and the error correction level. */
    private fun decode(pixels: IntArray, side: Int): Pair<String, Any?> {
        val bitmap = BinaryBitmap(HybridBinarizer(RGBLuminanceSource(side, pixels.size / side, pixels)))
        val result = QRCodeReader().decode(bitmap, mapOf(DecodeHintType.TRY_HARDER to true))
        return result.text to result.resultMetadata[ResultMetadataType.ERROR_CORRECTION_LEVEL]
    }

    /** The captured card on white (its rounded corners are clear). */
    private fun decode(image: ImageBitmap): Pair<String, Any?> {
        val map = image.toPixelMap()
        val pixels = IntArray(map.width * map.height) { i ->
            val c = map[i % map.width, i / map.width]
            if (c.alpha < 0.5f) WHITE else android.graphics.Color.argb(255, (c.red * 255).toInt(), (c.green * 255).toInt(), (c.blue * 255).toInt())
        }
        return decode(pixels, map.width)
    }

    private companion object {
        const val WHITE = -0x1 // 0xFFFFFFFF
        const val BLACK = -0x1000000 // 0xFF000000
    }
}
