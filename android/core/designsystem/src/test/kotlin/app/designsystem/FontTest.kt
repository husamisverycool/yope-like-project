package app.designsystem

import android.graphics.Paint
import android.graphics.Typeface
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.font.createFontFamilyResolver
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import app.designsystem.generated.Tokens
import org.junit.Assert.assertEquals
import org.junit.Assert.assertSame
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.annotation.GraphicsMode

/** `font.global.family` (Inter Variable) resolves to true instances of the `wght` axis, not synthesized weights. */
@RunWith(AndroidJUnit4::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
class FontTest {
    private val context get() = ApplicationProvider.getApplicationContext<android.content.Context>()

    private fun typeface(weight: Int): Typeface {
        val family = Tokens.Fonts.globalFamily.toFontFamily(context)
        return createFontFamilyResolver(context).resolve(family, FontWeight(weight)).value as Typeface
    }

    /** Advance width of [SAMPLE] drawn with [face]: Inter's advances change along the wght axis, so it tells instances apart. */
    private fun width(face: Typeface): Float = Paint().apply { typeface = face; textSize = SAMPLE_PX }.measureText(SAMPLE)

    /** The platform's own instance of the bundled font at wght = [weight] (no Compose involved). */
    private fun reference(weight: Int): Typeface {
        val id = context.resources.getIdentifier(Tokens.Fonts.globalFamily.let { it as DSFontFamily.Custom }.resourceName, "font", context.packageName)
        return Paint().apply { typeface = context.resources.getFont(id); fontVariationSettings = "'wght' $weight" }.typeface
    }

    @Test fun everyRoleWeightDrawsItsOwnWghtInstance() {
        val weights = listOf(400, Tokens.Layouts.GlobalVariableWeightAndroid.body.toInt(), 600, 700)
        weights.forEach { w -> assertEquals("weight $w", width(reference(w)), width(typeface(w)), 0f) }
        // Four different instances (not one face drawn four times, nor a synthesized bold).
        assertEquals(weights.size, weights.map { width(typeface(it)) }.distinct().size)
        weights.forEach { w -> assertTrue("weight $w must not be fake bold", !Paint().apply { typeface = typeface(w) }.isFakeBoldText) }
    }

    @Test fun familyIsSharedPerResource() {
        assertSame(Tokens.Fonts.globalFamily.toFontFamily(context), Tokens.Fonts.globalFamily.toFontFamily(context))
    }

    private companion object {
        const val SAMPLE = "Week 27 Jul 3 - 9 olson shared photos"
        const val SAMPLE_PX = 42f
    }
}
