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
 * Pixel art for the Glance widget, drawn from token values. RemoteViews has no runtime gradient,
 * no clipping before Android 12, no exact baseline placement and no 600 weight, so the scrim, the
 * rounded corners below Android 12, the text stack and the state glyph are drawn into bitmaps here;
 * Glance shows them at their dp size.
 */
internal object WidgetArt {
    fun px(context: Context, dp: Dp): Float = dp.value * context.resources.displayMetrics.density

    fun px(context: Context, size: TextUnit): Float =
        TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_SP, size.value, context.resources.displayMetrics)

    /**
     * [photo] with the bottom scrim drawn in (`layout.global.photoScrim`): [start] down to
     * [startAt] of the height, then a linear ramp to [end] at the bottom edge.
     */
    fun withScrim(photo: Bitmap, start: Color, end: Color, startAt: Float): Bitmap {
        val out = if (photo.isMutable) photo else photo.copy(Bitmap.Config.ARGB_8888, true).also { if (it !== photo) photo.recycle() }
        val h = out.height.toFloat()
        val paint = Paint().apply {
            shader = LinearGradient(
                0f, 0f, 0f, h,
                intArrayOf(start.toArgb(), start.toArgb(), end.toArgb()),
                floatArrayOf(0f, startAt, 1f),
                Shader.TileMode.CLAMP,
            )
        }
        Canvas(out).drawRect(0f, 0f, out.width.toFloat(), h, paint)
        return out
    }

    /** [src] with its corners cut to [radiusPx] (transparent outside), for Android < 12. */
    fun rounded(src: Bitmap, radiusPx: Float): Bitmap {
        val out = Bitmap.createBitmap(src.width, src.height, Bitmap.Config.ARGB_8888)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply { shader = BitmapShader(src, Shader.TileMode.CLAMP, Shader.TileMode.CLAMP) }
        Canvas(out).drawRoundRect(RectF(0f, 0f, src.width.toFloat(), src.height.toFloat()), radiusPx, radiusPx, paint)
        if (out !== src) src.recycle()
        return out
    }

    /** A [width]×[height] rounded rectangle of [radius] in [color] (the states' background below Android 12). */
    fun roundedFill(context: Context, width: Dp, height: Dp, radius: Dp, color: Color): Bitmap {
        val w = max(1, px(context, width).roundToInt())
        val h = max(1, px(context, height).roundToInt())
        val out = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
        val r = px(context, radius)
        Canvas(out).drawRoundRect(RectF(0f, 0f, w.toFloat(), h.toFloat()), r, r, Paint(Paint.ANTI_ALIAS_FLAG).apply { this.color = color.toArgb() })
        return out
    }

    /** [vector] fitted into a [glyph] square centred in a [box] square, in [color]. */
    fun glyph(context: Context, vector: ImageVector, box: Dp, glyph: Dp, color: Color): Bitmap {
        val size = max(1, px(context, box).roundToInt())
        val out = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val g = px(context, glyph)
        val inset = (size - g) / 2f
        drawVector(Canvas(out), vector, RectF(inset, inset, inset + g, inset + g), color)
        return out
    }

    /** The text stack's bitmap and its size in dp. */
    class Stack(val bitmap: Bitmap, val widthDp: Dp, val heightDp: Dp)

    /**
     * The widget text stack (`widget.home.small.layout.overlay`): [lines] top to bottom, each one
     * line ellipsized at the end, aligned to the trailing edge [trailingInset] in, the last baseline
     * [lastBaselineFromBottom] above the bitmap's bottom, baselines [linePitch] apart (the pitch
     * follows the font scale with the text). [widthPx] is the space from the leading inset to the
     * widget's trailing edge; the bitmap sits at the widget's bottom-end corner.
     */
    fun textStack(
        context: Context,
        lines: List<String>,
        widthPx: Float,
        trailingInset: Dp,
        lastBaselineFromBottom: Dp,
        linePitch: Dp,
        textSize: TextUnit,
        weight: FontWeight,
        color: Color,
        rtl: Boolean,
    ): Stack? {
        if (lines.isEmpty() || widthPx <= 0f) return null
        val density = context.resources.displayMetrics.density
        val paint = TextPaint(Paint.ANTI_ALIAS_FLAG).apply {
            this.color = color.toArgb()
            this.textSize = px(context, textSize)
            typeface = typeface(weight)
            textAlign = if (rtl) Paint.Align.LEFT else Paint.Align.RIGHT
        }
        val inset = px(context, trailingInset)
        val available = widthPx - inset
        if (available <= 0f) return null
        val shown = lines.map { TextUtils.ellipsize(it, paint, available, TextUtils.TruncateAt.END).toString() }
        if (shown.all(String::isEmpty)) return null
        // The pitch scales with the font scale (sp px ÷ the same number in dp px).
        val fontScale = px(context, textSize) / px(context, Dp(textSize.value))
        val pitch = px(context, linePitch) * fontScale
        val lastBaseline = px(context, lastBaselineFromBottom)
        val metrics = paint.fontMetrics
        val h = ceil(-metrics.top + pitch * (shown.size - 1) + lastBaseline).toInt()
        val w = ceil(widthPx).toInt()
        val out = Bitmap.createBitmap(max(1, w), max(1, h), Bitmap.Config.ARGB_8888)
        val canvas = Canvas(out)
        val x = if (rtl) inset else w - inset
        shown.forEachIndexed { i, line ->
            val baseline = h - lastBaseline - pitch * (shown.size - 1 - i)
            canvas.drawText(line, x, baseline, paint)
        }
        return Stack(out, Dp(w / density), Dp(h / density))
    }

    /** The nearest Glance text weight (Glance offers normal / medium / bold). */
    fun glanceWeight(weight: FontWeight): androidx.glance.text.FontWeight = when {
        weight >= FontWeight.Bold -> androidx.glance.text.FontWeight.Bold
        weight >= FontWeight.Medium -> androidx.glance.text.FontWeight.Medium
        else -> androidx.glance.text.FontWeight.Normal
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
