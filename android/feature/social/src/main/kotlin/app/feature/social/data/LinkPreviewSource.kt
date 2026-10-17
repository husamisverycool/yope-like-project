package app.feature.social.data

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import app.designsystem.generated.Tokens
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.coroutines.withTimeoutOrNull
import java.io.ByteArrayOutputStream
import java.io.InputStream
import java.net.HttpURLConnection
import java.net.URI
import java.net.URL
import java.nio.charset.Charset

/*
 * Link previews built on the sender's device (`chat.thread.layout.linkPreview`, owner decision 34, research #16; migration
 * 0053, docs/API.md `set_link_preview`): the page is read once with the platform's HTTP client (HttpURLConnection, as the
 * app's other plain fetches), its Open Graph tags parsed by [OgParser] within `htmlMaxBytes`, its image downscaled to a
 * JPEG. Recipients never contact the site; the server never fetches anything.
 */

/** What `set_link_preview` receives: the address as written in the text, title, site, and the JPEG to upload first. */
class LinkPreviewDraft(val url: String, val title: String?, val site: String?, val jpeg: ByteArray?) {
    override fun equals(other: Any?): Boolean =
        other is LinkPreviewDraft && other.url == url && other.title == title && other.site == site &&
            (other.jpeg?.contentEquals(jpeg) ?: (jpeg == null))

    override fun hashCode(): Int = listOf(url, title, site, jpeg?.contentHashCode()).hashCode()

    override fun toString(): String = "LinkPreviewDraft(url=$url, title=$title, site=$site, jpeg=${jpeg?.size})"
}

/** What a page's head says (`og:title`, `og:site_name`, `og:image`, with their fallbacks); [imageUrl] is absolute. */
data class LinkPageTags(val title: String? = null, val site: String? = null, val imageUrl: String? = null)

/** A page read once: its title and site, and its image's bytes (any format BitmapFactory reads). */
class LinkPage(val title: String? = null, val site: String? = null, val image: ByteArray? = null)

/** Reads a page once on the sender's device; null on any failure (no preview). */
fun interface LinkPageReader {
    suspend fun read(url: String): LinkPage?
}

/** Downscales a page's image and re-encodes it as JPEG; null when it cannot. */
fun interface LinkImageEncoder {
    suspend fun jpeg(image: ByteArray): ByteArray?
}

/**
 * A small, size-limited Open Graph reader (https://ogp.me): only the document's head (or its first `htmlMaxBytes` of
 * text) is looked at; `<meta property|name=… content=…>` in any attribute order and quoting; the usual entities decoded.
 * Title: og:title, twitter:title, then `<title>`; site: og:site_name; image: og:image:secure_url, og:image, og:image:url,
 * twitter:image, twitter:image:src — resolved against the page's address, http / https only.
 */
object OgParser {
    private val HEAD_END = Regex("</head\\s*>", RegexOption.IGNORE_CASE)
    private val META = Regex("<meta\\b[^>]*>", RegexOption.IGNORE_CASE)
    private val ATTRIBUTE = Regex("([A-Za-z_:][-A-Za-z0-9_:.]*)\\s*=\\s*(\"([^\"]*)\"|'([^']*)'|([^\\s\"'>]+))")
    private val TITLE = Regex("<title\\b[^>]*>([\\s\\S]*?)</title\\s*>", RegexOption.IGNORE_CASE)
    private val ENTITY = Regex("&(#[0-9]+|#[xX][0-9A-Fa-f]+|[A-Za-z]+);")
    private val SPACES = Regex("\\s+")
    private val NAMED = mapOf("amp" to "&", "lt" to "<", "gt" to ">", "quot" to "\"", "apos" to "'", "nbsp" to " ") // provenance-ok: HTML entities

    private val TITLE_KEYS = listOf("og:title", "twitter:title")
    private val IMAGE_KEYS = listOf("og:image:secure_url", "og:image", "og:image:url", "twitter:image", "twitter:image:src")

    fun parse(html: String, pageUrl: String): LinkPageTags {
        val limited = if (html.length > MAX_CHARS) html.substring(0, MAX_CHARS) else html
        val head = HEAD_END.find(limited)?.let { limited.substring(0, it.range.first) } ?: limited
        val tags = HashMap<String, String>()
        for (meta in META.findAll(head)) {
            val attributes = HashMap<String, String>()
            for (a in ATTRIBUTE.findAll(meta.value)) {
                val value = a.groups[3]?.value ?: a.groups[4]?.value ?: a.groups[5]?.value ?: continue
                attributes[a.groupValues[1].lowercase()] = value
            }
            val key = (attributes["property"] ?: attributes["name"])?.trim()?.lowercase() ?: continue
            val content = attributes["content"]?.let { text(it) } ?: continue
            if (content.isNotEmpty()) tags.putIfAbsent(key, content)
        }
        val title = TITLE_KEYS.firstNotNullOfOrNull { tags[it] } ?: TITLE.find(head)?.groupValues?.get(1)?.let { text(it) }?.takeIf { it.isNotEmpty() }
        val image = IMAGE_KEYS.firstNotNullOfOrNull { k -> tags[k]?.let { resolve(pageUrl, it) } }
        return LinkPageTags(title = title, site = tags["og:site_name"], imageUrl = image)
    }

    /** Entities decoded, whitespace runs collapsed, trimmed. */
    fun text(raw: String): String = ENTITY.replace(raw) { m ->
        val name = m.groupValues[1]
        when {
            name.startsWith("#x") || name.startsWith("#X") -> name.substring(2).toIntOrNull(HEX)?.let { codePoint(it) }
            name.startsWith("#") -> name.substring(1).toIntOrNull()?.let { codePoint(it) }
            else -> NAMED[name.lowercase()]
        } ?: m.value
    }.replace(SPACES, " ").trim()

    private fun codePoint(value: Int): String? =
        if (Character.isValidCodePoint(value) && value != 0) String(Character.toChars(value)) else null

    /** An absolute http / https address for [ref] on [pageUrl]'s page; null otherwise. */
    fun resolve(pageUrl: String, ref: String): String? = try {
        val resolved = URI(pageUrl).resolve(URI(ref.trim().replace(" ", "%20")))
        resolved.toString().takeIf { (resolved.scheme?.lowercase() == "http" || resolved.scheme?.lowercase() == "https") && resolved.host != null }
    } catch (_: Exception) {
        null
    }

    /** Characters looked at (the bytes the reader keeps can never decode to more). */
    private val MAX_CHARS = Tokens.Layouts.ChatThreadLayoutLinkPreview.htmlMaxBytes.toInt()
    private const val HEX = 16
}

/**
 * The page read once with HttpURLConnection: redirects followed by hand (http ↔ https as well), at most
 * `htmlMaxBytes` of an HTML response, its image at most `imageMaxBytes`; the whole within `timeoutSeconds`
 * (LinkPresentation's default). Cookies are not kept; nothing is sent but the GET.
 */
class HttpLinkPageReader : LinkPageReader {
    override suspend fun read(url: String): LinkPage? = withContext(Dispatchers.IO) {
        withTimeoutOrNull(TIMEOUT_MS.toLong()) {
            try {
                val (page, html) = get(url, HTML_MAX, html = true) ?: return@withTimeoutOrNull null
                val tags = OgParser.parse(String(html.bytes, html.charset), page)
                val image = tags.imageUrl?.let { get(it, IMAGE_MAX, html = false)?.second?.bytes }
                LinkPage(tags.title, tags.site, image)
            } catch (e: CancellationException) {
                throw e
            } catch (_: Exception) {
                null
            }
        }
    }

    private class Body(val bytes: ByteArray, val charset: Charset)

    /** The final address and the body, or null (not 2xx, wrong type, too large an image, too many redirects). */
    private fun get(start: String, limit: Int, html: Boolean): Pair<String, Body>? {
        var address = start
        repeat(MAX_REDIRECTS + 1) {
            val url = URL(address)
            if (url.protocol != "http" && url.protocol != "https") return null
            val connection = url.openConnection() as HttpURLConnection
            try {
                connection.instanceFollowRedirects = false
                connection.connectTimeout = TIMEOUT_MS
                connection.readTimeout = TIMEOUT_MS
                connection.setRequestProperty("Accept", if (html) "text/html,application/xhtml+xml" else "image/*")
                val code = connection.responseCode
                if (code in REDIRECT_CODES) {
                    address = OgParser.resolve(address, connection.getHeaderField("Location") ?: return null) ?: return null
                    return@repeat
                }
                if (code !in OK_CODES) return null
                val type = connection.contentType?.lowercase().orEmpty()
                if (html && type.isNotEmpty() && !type.contains("html")) return null
                if (!html && type.isNotEmpty() && !type.startsWith("image/")) return null
                val bytes = connection.inputStream.use { readCapped(it, limit, truncate = html) } ?: return null
                return address to Body(bytes, charsetOf(type))
            } finally {
                connection.disconnect()
            }
        }
        return null
    }

    /** At most [limit] bytes; beyond it an HTML page is cut (its head comes first), an image is refused. */
    private fun readCapped(input: InputStream, limit: Int, truncate: Boolean): ByteArray? {
        val out = ByteArrayOutputStream()
        val buffer = ByteArray(BUFFER)
        while (out.size() < limit) {
            val n = input.read(buffer, 0, minOf(buffer.size, limit - out.size()))
            if (n < 0) return out.toByteArray()
            out.write(buffer, 0, n)
        }
        if (truncate) return out.toByteArray()
        return if (input.read() < 0) out.toByteArray() else null
    }

    private fun charsetOf(contentType: String): Charset {
        val name = contentType.substringAfter("charset=", "").substringBefore(';').trim().trim('"')
        return try {
            if (name.isEmpty()) Charsets.UTF_8 else Charset.forName(name)
        } catch (_: Exception) {
            Charsets.UTF_8
        }
    }

    private companion object {
        val TIMEOUT_MS = (Tokens.Layouts.ChatThreadLayoutLinkPreview.timeoutSeconds * MS_PER_SECOND).toInt()
        val HTML_MAX = Tokens.Layouts.ChatThreadLayoutLinkPreview.htmlMaxBytes.toInt()
        val IMAGE_MAX = Tokens.Layouts.ChatThreadLayoutLinkPreview.imageMaxBytes.toInt()
        const val MAX_REDIRECTS = 5 // provenance-ok: HTTP redirect hops followed (not a design value)
        const val BUFFER = 8192 // provenance-ok: read buffer size
        val REDIRECT_CODES = setOf(301, 302, 303, 307, 308) // provenance-ok: HTTP status codes
        val OK_CODES = 200..299 // provenance-ok: HTTP status codes
    }
}

private const val MS_PER_SECOND = 1000f

/**
 * The page's image downscaled to `imageMaxPixels` on its longer side and re-encoded as JPEG at `jpegQuality` (the
 * worker's thumbnail size and quality); a re-encoded bitmap carries no metadata. Off the main thread.
 */
class BitmapLinkImageEncoder : LinkImageEncoder {
    override suspend fun jpeg(image: ByteArray): ByteArray? = withContext(Dispatchers.Default) {
        try {
            val max = Tokens.Layouts.ChatThreadLayoutLinkPreview.imageMaxPixels.toInt()
            val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
            BitmapFactory.decodeByteArray(image, 0, image.size, bounds)
            if (bounds.outWidth <= 0 || bounds.outHeight <= 0) return@withContext null
            var sample = 1
            while (maxOf(bounds.outWidth, bounds.outHeight) / (sample * 2) >= max) sample *= 2
            val decoded = BitmapFactory.decodeByteArray(image, 0, image.size, BitmapFactory.Options().apply { inSampleSize = sample })
                ?: return@withContext null
            val longer = maxOf(decoded.width, decoded.height)
            val scaled = if (longer > max) {
                val ratio = max.toFloat() / longer
                Bitmap.createScaledBitmap(decoded, maxOf(1, (decoded.width * ratio).toInt()), maxOf(1, (decoded.height * ratio).toInt()), true)
            } else {
                decoded
            }
            val out = ByteArrayOutputStream()
            val quality = (Tokens.Layouts.ChatThreadLayoutLinkPreview.jpegQuality * PERCENT).toInt()
            val ok = scaled.compress(Bitmap.CompressFormat.JPEG, quality, out)
            if (scaled !== decoded) scaled.recycle()
            decoded.recycle()
            if (ok) out.toByteArray() else null
        } catch (e: CancellationException) {
            throw e
        } catch (_: Exception) {
            null
        } catch (_: OutOfMemoryError) {
            null
        }
    }

    private companion object {
        const val PERCENT = 100f // provenance-ok: 0…1 quality to Bitmap.compress's 0…100
    }
}
