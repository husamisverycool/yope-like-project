package app.widget

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.BitmapShader
import android.graphics.Canvas
import android.graphics.LinearGradient
import android.graphics.Matrix
import android.graphics.Paint
import android.graphics.RectF
import android.graphics.Shader
import android.graphics.Typeface
import android.os.Build
import android.text.TextPaint
import android.text.TextUtils
import android.util.TypedValue
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.PathFillType
import androidx.compose.ui.graphics.asAndroidPath
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.graphics.vector.VectorGroup
import androidx.compose.ui.graphics.vector.VectorPath
import androidx.compose.ui.graphics.vector.toPath
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.TextUnit
import java.io.File
import kotlin.math.ceil
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt

/**
 * Pixel art for the Glance widget, drawn from token values. RemoteViews has no clip-to-circle or
 * gradient before Android 12 and no semibold text, so circles, gradients, the caption capsule and
 * the empty-state stack are drawn into bitmaps here; Glance shows them at their dp size.
 */
internal object WidgetArt {
    /** Height of the gradient strip (stretched to the widget; a vertical gradient needs no width). */
    private const val GRADIENT_STEPS = 256 // provenance-ok: bitmap resolution of a stretched gradient, not a design value

    fun px(context: Context, dp: Dp): Float = dp.value * context.resources.displayMetrics.density

    fun px(context: Context, size: TextUnit): Float =
        TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_SP, size.value, context.resources.displayMetrics)

    /** A one-pixel-wide vertical gradient [top] → [bottom], stretched with ContentScale.FillBounds. */
    fun verticalGradient(top: Color, bottom: Color): Bitmap {
        val bitmap = Bitmap.createBitmap(1, GRADIENT_STEPS, Bitmap.Config.ARGB_8888)
        val paint = Paint().apply {
            shader = LinearGradient(0f, 0f, 0f, GRADIENT_STEPS.toFloat(), top.toArgb(), bottom.toArgb(), Shader.TileMode.CLAMP)
        }
        Canvas(bitmap).drawRect(0f, 0f, 1f, GRADIENT_STEPS.toFloat(), paint)
        return bitmap
    }

    /**
     * A circular avatar of [diameter]: the image at [file] centre-cropped into a circle, or (no
     * file / undecodable) the vertical gradient [placeholderTop] → [placeholderBottom]; then a
     * [ringWidth] ring in [ringColor] inside the edge (null = no ring).
     */
    fun avatar(
        context: Context,
        file: File?,
        diameter: Dp,
        placeholderTop: Color,
        placeholderBottom: Color,
        ringWidth: Dp?,
        ringColor: Color?,
    ): Bitmap {
        val size = max(1, px(context, diameter).roundToInt())
        val bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        val r = size / 2f
        val source = file?.takeIf(File::isFile)?.let { decodeSampled(it, size) }
        val fill = Paint(Paint.ANTI_ALIAS_FLAG)
        if (source != null) {
            val scale = max(size.toFloat() / source.width, size.toFloat() / source.height)
            val matrix = Matrix().apply {
                setScale(scale, scale)
                postTranslate((size - source.width * scale) / 2f, (size - source.height * scale) / 2f)
            }
            fill.shader = BitmapShader(source, Shader.TileMode.CLAMP, Shader.TileMode.CLAMP).apply { setLocalMatrix(matrix) }
        } else {
            fill.shader = LinearGradient(0f, 0f, 0f, size.toFloat(), placeholderTop.toArgb(), placeholderBottom.toArgb(), Shader.TileMode.CLAMP)
        }
        canvas.drawCircle(r, r, r, fill)
        if (ringWidth != null && ringColor != null) {
            val stroke = px(context, ringWidth)
            val ring = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                style = Paint.Style.STROKE
                strokeWidth = stroke
                color = ringColor.toArgb()
            }
            canvas.drawCircle(r, r, r - stroke / 2f, ring)
        }
        return bitmap
    }

    /** The caption capsule: [text] on one line, ellipsized to fit [maxWidthPx]. */
    class Pill(val bitmap: Bitmap, val widthDp: Float, val heightDp: Float)

    fun captionPill(
        context: Context,
        text: String,
        maxWidthPx: Float,
        height: Dp,
        padding: Dp,
        fill: Color,
        textColor: Color,
        textSize: TextUnit,
        weight: FontWeight,
    ): Pill? {
        val density = context.resources.displayMetrics.density
        val paint = TextPaint(Paint.ANTI_ALIAS_FLAG).apply {
            color = textColor.toArgb()
            this.textSize = px(context, textSize)
            typeface = typeface(weight)
        }
        val pad = px(context, padding)
        val available = maxWidthPx - 2 * pad
        if (available <= 0f) return null
        val shown = TextUtils.ellipsize(text, paint, available, TextUtils.TruncateAt.END).toString()
        if (shown.isEmpty()) return null
        val metrics = paint.fontMetrics
        val lineHeight = metrics.descent - metrics.ascent
        // The token height, grown only when a large font scale would clip the line (one line, truncated).
        val h = ceil(max(px(context, height), lineHeight)).toInt()
        val w = ceil(min(maxWidthPx, paint.measureText(shown) + 2 * pad)).toInt()
        val bitmap = Bitmap.createBitmap(max(1, w), max(1, h), Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        val radius = h / 2f // radius.global.capsule: height / 2
        canvas.drawRoundRect(RectF(0f, 0f, w.toFloat(), h.toFloat()), radius, radius, Paint(Paint.ANTI_ALIAS_FLAG).apply { color = fill.toArgb() })
        val baseline = h / 2f - (metrics.ascent + metrics.descent) / 2f
        canvas.drawText(shown, pad, baseline, paint)
        return Pill(bitmap, w / density, h / density)
    }

    /**
     * The empty-state stack (`Tokens.Layouts.WidgetHomeSmallLayoutEmpty`): a [ring]-diameter ring
     * of [ringStroke] in [ringColor] around a [circle]-diameter disc in [circleColor], holding
     * [glyph] fitted into [glyphWidth] × [glyphHeight] in [glyphColor].
     */
    fun emptyStack(
        context: Context,
        ring: Dp,
        ringStroke: Dp,
        ringColor: Color,
        circle: Dp,
        circleColor: Color,
        glyph: ImageVector,
        glyphWidth: Dp,
        glyphHeight: Dp,
        glyphColor: Color,
    ): Bitmap {
        val size = max(1, px(context, ring).roundToInt())
        val bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        val c = size / 2f
        val stroke = px(context, ringStroke)
        canvas.drawCircle(c, c, c - stroke / 2f, Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
            strokeWidth = stroke
            color = ringColor.toArgb()
        })
        canvas.drawCircle(c, c, px(context, circle) / 2f, Paint(Paint.ANTI_ALIAS_FLAG).apply { color = circleColor.toArgb() })
        drawVector(canvas, glyph, RectF(c - px(context, glyphWidth) / 2f, c - px(context, glyphHeight) / 2f, c + px(context, glyphWidth) / 2f, c + px(context, glyphHeight) / 2f), glyphColor)
        return bitmap
    }

    /** Draws [vector] fitted (aspect kept, centred) into [box] in [color]. */
    fun drawVector(canvas: Canvas, vector: ImageVector, box: RectF, color: Color) {
        val scale = min(box.width() / vector.viewportWidth, box.height() / vector.viewportHeight)
        val dx = box.left + (box.width() - vector.viewportWidth * scale) / 2f
        val dy = box.top + (box.height() - vector.viewportHeight * scale) / 2f
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply { this.color = color.toArgb() }
        canvas.save()
        canvas.translate(dx, dy)
        canvas.scale(scale, scale)
        drawGroup(canvas, vector.root, paint)
        canvas.restore()
    }

    private fun drawGroup(canvas: Canvas, group: VectorGroup, paint: Paint) {
        for (node in group) {
            when (node) {
                is VectorGroup -> drawGroup(canvas, node, paint)
                is VectorPath -> {
                    val path = node.pathData.toPath().asAndroidPath()
                    path.fillType = if (node.pathFillType == PathFillType.EvenOdd) android.graphics.Path.FillType.EVEN_ODD else android.graphics.Path.FillType.WINDING
                    canvas.drawPath(path, paint)
                }
            }
        }
    }

    private fun typeface(weight: FontWeight): Typeface =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            Typeface.create(Typeface.DEFAULT, weight.weight, false)
        } else {
            // Before API 28 only regular and bold faces can be selected from code.
            Typeface.create(Typeface.DEFAULT, if (weight >= FontWeight.SemiBold) Typeface.BOLD else Typeface.NORMAL)
        }

    private fun decodeSampled(file: File, targetPx: Int): Bitmap? {
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeFile(file.path, bounds)
        if (bounds.outWidth <= 0 || bounds.outHeight <= 0) return null
        var sample = 1
        while (bounds.outWidth / (sample * 2) >= targetPx && bounds.outHeight / (sample * 2) >= targetPx) sample *= 2
        return BitmapFactory.decodeFile(file.path, BitmapFactory.Options().apply { inSampleSize = sample })
    }
}
