package app.testing

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.Rect
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.FilterQuality
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.painter.BitmapPainter
import androidx.compose.ui.graphics.painter.Painter
import androidx.compose.ui.unit.IntSize
import coil3.ImageLoader
import coil3.asImage
import coil3.decode.DataSource
import coil3.intercept.Interceptor
import coil3.request.ImageResult
import coil3.request.SuccessResult
import java.io.ByteArrayOutputStream
import java.io.File
import kotlin.math.abs
import kotlin.math.ln
import kotlin.math.roundToInt

/**
 * Real photos for snapshot tests: `fixtures/photos/` at the repository root (Unsplash License; source,
 * photographer and content of each file in `fixtures/photos/INDEX.md`). Test data only, never shipped.
 *
 * File names carry the shape (`…-3x4`, `-4x5`, `-9x16`, `-1x1`, `-4x3`, `-3x2`) or are `avatar-NN`
 * (square head-and-shoulders portraits). Lists are sorted by name, so a pick by index or key is stable
 * until photos are added or removed (which changes the baselines that use those picks).
 */
object SamplePhotos {
    /** The system property the root build script sets on every unit-test JVM. */
    const val PROPERTY = "app.samplePhotos"

    /** `fixtures/photos/`: from [PROPERTY], else the first `fixtures/photos` above the working directory. */
    val dir: File by lazy {
        System.getProperty(PROPERTY)?.let(::File)?.takeIf(File::isDirectory)
            ?: generateSequence(File(System.getProperty("user.dir") ?: ".").absoluteFile) { it.parentFile }
                .map { File(it, "fixtures/photos") }
                .firstOrNull(File::isDirectory)
            ?: error("fixtures/photos not found: run the tests through Gradle (it sets -D$PROPERTY)")
    }

    /** Every photo (file name without `.jpg`), sorted. */
    val names: List<String> by lazy {
        dir.listFiles { file -> file.extension == "jpg" }.orEmpty().map { it.nameWithoutExtension }.sorted()
    }

    /** The square portraits used as avatars, sorted. */
    val avatars: List<String> by lazy { names.filter { it.startsWith("avatar-") } }

    /** Photo shapes, by the suffix of the file name. */
    enum class Shape(val width: Int, val height: Int, vararg val suffixes: String) {
        Portrait(3, 4, "3x4"),
        Tall(4, 5, "4x5"),
        Story(9, 16, "9x16"),
        Square(1, 1, "1x1"),
        Landscape(4, 3, "4x3", "3x2"),
        ;

        val ratio: Float get() = width.toFloat() / height
    }

    fun names(shape: Shape): List<String> = names.filter { name -> shape.suffixes.any { name.endsWith("-$it") } }

    /** The shape whose aspect (width / height) is closest to [aspect]. */
    fun closest(aspect: Float): Shape = Shape.entries.minBy { abs(ln(it.ratio / aspect)) }

    /** The [index]th photo of [shape] (wraps around, negative indexes too). */
    fun pick(index: Int, shape: Shape = Shape.Portrait): String = names(shape).let { it[Math.floorMod(index, it.size)] }

    /** The [index]th avatar (wraps around). */
    fun avatar(index: Int): String = avatars[Math.floorMod(index, avatars.size)]

    /** A photo for [key] (a storage path, an id), the same for the same key, of the shape closest to [aspect]. */
    fun forKey(key: String, aspect: Float = Shape.Portrait.ratio): String = pick(key.hashCode(), closest(aspect))

    /** An avatar for [key], the same for the same key. */
    fun avatarForKey(key: String): String = avatar(key.hashCode())

    fun file(name: String): File =
        File(dir, name.removeSuffix(".jpg") + ".jpg").also { require(it.isFile) { "no sample photo $it" } }

    fun bytes(name: String): ByteArray = file(name).readBytes()

    private val decoded = HashMap<String, Bitmap>()

    /** The photo at its stored size, decoded once and shared: do not recycle or draw into it. */
    @Synchronized
    fun bitmap(name: String): Bitmap = decoded.getOrPut(name) {
        val options = BitmapFactory.Options().apply { inPreferredConfig = Bitmap.Config.ARGB_8888 }
        BitmapFactory.decodeFile(file(name).path, options) ?: error("could not decode ${file(name)}")
    }

    /** The photo centre-cropped to [width] : [height] and scaled to exactly [width] × [height] pixels (a new bitmap). */
    fun bitmap(name: String, width: Int, height: Int): Bitmap {
        val source = bitmap(name)
        val out = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        Canvas(out).drawBitmap(source, centreCrop(source.width, source.height, width.toFloat() / height), Rect(0, 0, width, height), FILTER)
        return out
    }

    /** The photo centre-cropped to the aspect [aspectWidth] : [aspectHeight], [longSide] pixels on its longer side. */
    fun bitmapWithAspect(name: String, aspectWidth: Int, aspectHeight: Int, longSide: Int = DEFAULT_LONG_SIDE): Bitmap =
        if (aspectWidth >= aspectHeight) {
            bitmap(name, longSide, (longSide * aspectHeight.toFloat() / aspectWidth).roundToInt().coerceAtLeast(1))
        } else {
            bitmap(name, (longSide * aspectWidth.toFloat() / aspectHeight).roundToInt().coerceAtLeast(1), longSide)
        }

    /** A JPEG of the photo cropped and scaled to [width] × [height] (camera stills, widget renditions, files). */
    fun jpeg(name: String, width: Int, height: Int, quality: Int = JPEG_QUALITY): ByteArray {
        val out = ByteArrayOutputStream()
        bitmap(name, width, height).compress(Bitmap.CompressFormat.JPEG, quality, out)
        return out.toByteArray()
    }

    /** Writes [jpeg] to [file] (parent directories created) and returns it. */
    fun writeJpeg(file: File, name: String, width: Int, height: Int): File {
        file.parentFile?.mkdirs()
        file.writeBytes(jpeg(name, width, height))
        return file
    }

    private val painters = HashMap<String, Painter>()

    /** A painter of the photo at its stored shape. */
    fun painter(name: String): Painter = synchronized(painters) {
        painters.getOrPut(name) { BitmapPainter(bitmap(name).asImageBitmap()) }
    }

    /** A painter of the photo centre-cropped to [aspectWidth] : [aspectHeight] (its intrinsic size has that shape). */
    fun painter(name: String, aspectWidth: Int, aspectHeight: Int): Painter = synchronized(painters) {
        painters.getOrPut("$name@$aspectWidth:$aspectHeight") {
            BitmapPainter(bitmapWithAspect(name, aspectWidth, aspectHeight).asImageBitmap())
        }
    }

    /**
     * A painter of the photo centre-cropped to [aspectWidth] : [aspectHeight] that reports [intrinsicWidth] ×
     * [intrinsicHeight] pixels as its intrinsic size and draws the photo sharp at whatever size it is given: a
     * drop-in for a generated test image of that size, so layouts that size an image by its intrinsic size
     * (e.g. `ContentScale.Fit` without a fill modifier) stay exactly as they were.
     */
    fun painter(name: String, aspectWidth: Int, aspectHeight: Int, intrinsicWidth: Float, intrinsicHeight: Float): Painter =
        synchronized(painters) {
            painters.getOrPut("$name@$aspectWidth:$aspectHeight@${intrinsicWidth}x$intrinsicHeight") {
                SizedPainter(bitmapWithAspect(name, aspectWidth, aspectHeight).asImageBitmap(), Size(intrinsicWidth, intrinsicHeight))
            }
        }

    /** [image] (e.g. a collage) as a painter reporting [intrinsicWidth] × [intrinsicHeight]; give it the same shape. */
    fun painter(image: Bitmap, intrinsicWidth: Float, intrinsicHeight: Float): Painter =
        SizedPainter(image.asImageBitmap(), Size(intrinsicWidth, intrinsicHeight))

    private class SizedPainter(private val image: ImageBitmap, override val intrinsicSize: Size) : Painter() {
        override fun DrawScope.onDraw() {
            drawImage(image, dstSize = IntSize(size.width.roundToInt(), size.height.roundToInt()), filterQuality = FilterQuality.High)
        }
    }

    /**
     * A grid of [photos] ([columns] across, row by row, each tile centre-cropped) on black with [gap] pixels
     * between tiles: a stand-in for a server-composed collage.
     */
    fun collage(width: Int, height: Int, photos: List<String>, columns: Int, gap: Int = 0): Bitmap {
        val rows = (photos.size + columns - 1) / columns
        val tileW = (width - gap * (columns - 1)) / columns
        val tileH = (height - gap * (rows - 1)) / rows
        val out = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(out)
        canvas.drawColor(android.graphics.Color.BLACK)
        photos.forEachIndexed { i, name ->
            val x = (i % columns) * (tileW + gap)
            val y = (i / columns) * (tileH + gap)
            val source = bitmap(name)
            canvas.drawBitmap(source, centreCrop(source.width, source.height, tileW.toFloat() / tileH), Rect(x, y, x + tileW, y + tileH), FILTER)
        }
        return out
    }

    /** The URL tests hand to screens that load through Coil; [imageLoader] answers it with the photo. */
    fun url(name: String): String = URL_PREFIX + name.removeSuffix(".jpg") + ".jpg"

    /** The photo a [url] names, or null for any other URL. */
    fun nameOfUrl(url: String): String? = url.takeIf { it.startsWith(URL_PREFIX) }?.removePrefix(URL_PREFIX)?.removeSuffix(".jpg")

    /**
     * A Coil image loader that answers [url]s from the photo files without a network or disk cache (install
     * it with `SingletonImageLoader.setUnsafe` for screens that call `AsyncImage(model = url)`).
     */
    fun imageLoader(context: Context): ImageLoader =
        ImageLoader.Builder(context)
            .components { add(PhotoInterceptor) }
            .build()

    private object PhotoInterceptor : Interceptor {
        override suspend fun intercept(chain: Interceptor.Chain): ImageResult {
            val name = (chain.request.data as? String)?.let(::nameOfUrl) ?: return chain.proceed()
            return SuccessResult(image = bitmap(name).asImage(), request = chain.request, dataSource = DataSource.MEMORY)
        }
    }

    private fun centreCrop(width: Int, height: Int, aspect: Float): Rect =
        if (width.toFloat() / height > aspect) {
            val w = (height * aspect).roundToInt().coerceIn(1, width)
            val x = (width - w) / 2
            Rect(x, 0, x + w, height)
        } else {
            val h = (width / aspect).roundToInt().coerceIn(1, height)
            val y = (height - h) / 2
            Rect(0, y, width, y + h)
        }

    private val FILTER = Paint(Paint.FILTER_BITMAP_FLAG or Paint.ANTI_ALIAS_FLAG)
    private const val DEFAULT_LONG_SIDE = 720
    private const val JPEG_QUALITY = 90
    private const val URL_PREFIX = "https://sample-photos.test/"
}
