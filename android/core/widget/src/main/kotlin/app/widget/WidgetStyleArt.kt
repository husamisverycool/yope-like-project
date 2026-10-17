// Surface: widget.styles — the premium Date and Frame styles drawn for Glance (design/surfaces/widget.styles.md →
// Platform notes: "Glance has no blur or custom fonts: the backdrop, print and photo are drawn into one bitmap (Gaussian
// σ × density); the date title is drawn into a bitmap with the bundled display face, as the name stack is").
// References: ST-04 references/auto/retro/store/retro-store-04.png and PLAY-04 references/auto/retro/play/
// retro-play-04.png (the instant print on the C-34 backdrop), RWA references/auto/retro/press/tc-2025-12-rewind-device-a.png
// (Rewind's serif date over the full-bleed photo).
package app.widget

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.Rect
import android.graphics.RectF
import android.text.TextPaint
import android.text.TextUtils
import android.view.View
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.unit.Dp
import app.designsystem.generated.Tokens
import app.model.WidgetSnapshot
import java.io.File
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.time.format.FormatStyle
import java.util.Locale
import kotlin.math.ceil
import kotlin.math.exp
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt

/** A rectangle in pixels (plain numbers, so the geometry is unit-tested on the JVM). */
data class StyleRect(val left: Float, val top: Float, val width: Float, val height: Float) {
    val right: Float get() = left + width
    val bottom: Float get() = top + height
}

/**
 * The Frame style's print (`widget.styles.layout.frame`): the largest print of width ÷ height = 1 ÷ `aspect` inside
 * `fit` × the widget's width by `fit` × its height, centred; the square window `sideBorder` × the print width in from
 * its sides and `topBorder` × the print width below its top (the rest, `bottomBorder`, is paper under the window).
 */
object FramePrint {
    data class Geometry(val print: StyleRect, val window: StyleRect)

    fun geometry(widgetWidth: Float, widgetHeight: Float): Geometry {
        val frame = Tokens.Layouts.WidgetStylesLayoutFrame
        val width = min(frame.fit * widgetWidth, frame.fit * widgetHeight / frame.aspect)
        val height = width * frame.aspect
        val print = StyleRect((widgetWidth - width) / 2f, (widgetHeight - height) / 2f, width, height)
        val side = frame.sideBorder * width
        val window = width - 2f * side
        return Geometry(print, StyleRect(print.left + side, print.top + frame.topBorder * width, window, window))
    }
}

/** The premium styles' pixel art for Glance (RemoteViews has no blur, no custom font, no baseline placement). */
internal object WidgetStyleArt {

    /**
     * The whole Frame-style widget as one bitmap ([widthPx] × [heightPx]): the photo aspect-filling the widget, blurred
     * (Gaussian σ `size.global.backdropBlur` × density) under `color.global.backdropDim`; the print in
     * `widget.styles.color.frame`, square corners; the photo aspect-filling its window. No text, no scrim. Rounded on
     * Android < 12 like the Photo style's bitmap. Null when the rendition cannot be decoded.
     */
    fun frame(context: Context, file: File, widthPx: Int, heightPx: Int): Bitmap? {
        if (widthPx <= 0 || heightPx <= 0) return null
        val backdrop = WidgetBitmaps.decodeCropped(file, widthPx, heightPx) ?: return null
        val out = Bitmap.createBitmap(widthPx, heightPx, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(out)
        val filter = Paint(Paint.FILTER_BITMAP_FLAG or Paint.ANTI_ALIAS_FLAG)
        // σ in the backdrop's own pixels (the decode may be smaller than the widget; it is scaled up to fill it).
        val sigma = WidgetArt.px(context, Tokens.Sizes.globalBackdropBlur) * backdrop.width / widthPx
        val blurred = gaussian(backdrop, sigma)
        canvas.drawBitmap(blurred, null, Rect(0, 0, widthPx, heightPx), filter)
        if (blurred !== backdrop) blurred.recycle()
        backdrop.recycle()
        canvas.drawColor(WidgetColors.pick(context) { it.globalBackdropDim }.toArgb())

        val geometry = FramePrint.geometry(widthPx.toFloat(), heightPx.toFloat())
        val paper = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = WidgetColors.pick(context) { it.widgetStylesColorFrame }.toArgb() }
        canvas.drawRect(geometry.print.rectF(), paper)
        val windowPx = max(1, geometry.window.width.roundToInt())
        WidgetBitmaps.decodeCropped(file, windowPx, windowPx)?.let { photo ->
            canvas.drawBitmap(photo, null, geometry.window.rectF(), filter)
            photo.recycle()
        }
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.S) return out
        return WidgetArt.rounded(out, WidgetArt.px(context, Tokens.Radii.widgetAndroidRadiusWidget))
    }

    /**
     * The Date style's title (`widget.styles.layout.date`): [text] in `font.global.display` at `displaySmall`
     * (`fontWeight.global.displaySmall`), `color.global.textOnMedia`, one line truncated at the end before the trailing
     * margin; its leading inset `size.global.screenMargin` and its cap top `size.global.screenMargin` below the top edge.
     * The bitmap spans the widget's width, from its top edge to the title's descent.
     */
    fun dateTitle(context: Context, text: String, widgetWidth: Dp): WidgetArt.Stack? {
        val density = context.resources.displayMetrics.density
        val margin = WidgetArt.px(context, Tokens.Sizes.globalScreenMargin)
        val widthPx = WidgetArt.px(context, widgetWidth)
        val available = widthPx - 2f * margin
        if (text.isBlank() || available <= 0f) return null
        val rtl = context.resources.configuration.layoutDirection == View.LAYOUT_DIRECTION_RTL
        val paint = TextPaint(Paint.ANTI_ALIAS_FLAG).apply {
            color = WidgetColors.pick(context) { it.globalTextOnMedia }.toArgb()
            textSize = WidgetArt.px(context, Tokens.FontSizes.globalDisplaySmall)
            typeface = WidgetArt.displayFace(context, Tokens.FontWeights.fontWeightGlobalDisplaySmall)
            textAlign = if (rtl) Paint.Align.RIGHT else Paint.Align.LEFT
        }
        val shown = TextUtils.ellipsize(text, paint, available, TextUtils.TruncateAt.END).toString()
        if (shown.isEmpty()) return null
        // Cap height: the top of a capital's ink above the baseline.
        val bounds = Rect()
        paint.getTextBounds(CAP_SAMPLE, 0, CAP_SAMPLE.length, bounds)
        val baseline = margin - bounds.top
        val w = max(1, ceil(widthPx).toInt())
        val h = max(1, ceil(baseline + paint.fontMetrics.descent).toInt())
        val out = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
        Canvas(out).drawText(shown, if (rtl) w - margin else margin, baseline, paint)
        return WidgetArt.Stack(out, Dp(w / density), Dp(h / density))
    }

    /** The item's day in `layout.onthisday.dateFormat` (the locale's medium date, "Jul 22, 2022"), in the device's zone. */
    fun dateText(at: Instant, locale: Locale = Locale.getDefault(), zone: ZoneId = ZoneId.systemDefault()): String =
        DateTimeFormatter.ofLocalizedDate(FormatStyle.MEDIUM).withLocale(locale).format(at.atZone(zone))

    /** [WidgetSnapshot]'s day for the Date style and the memories label. */
    fun dateText(snapshot: WidgetSnapshot): String = dateText(snapshot.postedAt)

    /**
     * A separable Gaussian blur of standard deviation [sigma] px (the kernel spans ±3σ, 99.7 % of its weight; edges
     * clamp). [src] is returned as is when σ is below half a pixel.
     */
    fun gaussian(src: Bitmap, sigma: Float): Bitmap {
        if (sigma < MIN_SIGMA_PX) return src
        val radius = ceil(sigma * KERNEL_SIGMAS).toInt()
        val kernel = FloatArray(2 * radius + 1) { i -> val d = (i - radius).toFloat(); exp(-(d * d) / (2f * sigma * sigma)) }
        val sum = kernel.sum()
        for (i in kernel.indices) kernel[i] /= sum
        val w = src.width
        val h = src.height
        val pixels = IntArray(w * h)
        src.getPixels(pixels, 0, w, 0, 0, w, h)
        val pass = IntArray(w * h)
        convolve(pixels, pass, w, h, kernel, radius, horizontal = true)
        convolve(pass, pixels, w, h, kernel, radius, horizontal = false)
        return Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888).apply { setPixels(pixels, 0, w, 0, 0, w, h) }
    }

    private fun convolve(src: IntArray, dst: IntArray, w: Int, h: Int, kernel: FloatArray, radius: Int, horizontal: Boolean) {
        for (y in 0 until h) {
            for (x in 0 until w) {
                var a = 0f
                var r = 0f
                var g = 0f
                var b = 0f
                for (k in -radius..radius) {
                    val sx = if (horizontal) (x + k).coerceIn(0, w - 1) else x
                    val sy = if (horizontal) y else (y + k).coerceIn(0, h - 1)
                    val c = src[sy * w + sx]
                    val weight = kernel[k + radius]
                    a += (c ushr ALPHA_SHIFT and CHANNEL) * weight
                    r += (c ushr RED_SHIFT and CHANNEL) * weight
                    g += (c ushr GREEN_SHIFT and CHANNEL) * weight
                    b += (c and CHANNEL) * weight
                }
                dst[y * w + x] = (channel(a) shl ALPHA_SHIFT) or (channel(r) shl RED_SHIFT) or (channel(g) shl GREEN_SHIFT) or channel(b)
            }
        }
    }

    private fun channel(v: Float): Int = v.roundToInt().coerceIn(0, CHANNEL)

    private fun StyleRect.rectF() = RectF(left, top, right, bottom)

    /** A capital whose ink top is the cap height (the spec places the title by its cap top). */
    private const val CAP_SAMPLE = "H"
    private const val KERNEL_SIGMAS = 3f
    private const val MIN_SIGMA_PX = 0.5f
    private const val CHANNEL = 0xFF
    private const val ALPHA_SHIFT = 24
    private const val RED_SHIFT = 16
    private const val GREEN_SHIFT = 8
}
