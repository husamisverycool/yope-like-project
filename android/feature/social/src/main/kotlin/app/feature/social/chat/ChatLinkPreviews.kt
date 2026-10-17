package app.feature.social.chat

import app.data.model.LinkPreview
import app.feature.social.data.BitmapLinkImageEncoder
import app.feature.social.data.HttpLinkPageReader
import app.feature.social.data.LinkImageEncoder
import app.feature.social.data.LinkPageReader
import app.feature.social.data.LinkPreviewDraft
import java.net.URI

/**
 * `chat.thread.layout.linkPreview` (owner decision 34, research #16; migration 0053): which link of a sent text gets a
 * preview, and the limits `set_link_preview` checks.
 */
object ChatLinkPreviews {
    /** `p_url` ≤ 2000 characters (docs/API.md `set_link_preview`). */
    const val URL_MAX = 2000
    /** `p_title` ≤ 300 characters. */
    const val TITLE_MAX = 300
    /** `p_site` ≤ 100 characters. */
    const val SITE_MAX = 100

    /** The address exactly as written in the text ([text]: `set_link_preview` finds it in the body). */
    data class Candidate(val text: String)

    /**
     * The first link of the text (`chat.thread.layout.links`, Linkify) written with its own http / https scheme: an address
     * Linkify completed ("example.com") is not in the text as `p_url` must be, so it gets none.
     */
    fun candidate(body: String): Candidate? = ChatLinks.find(body).firstNotNullOfOrNull { link ->
        val literal = body.substring(link.start, link.end)
        val scheme = literal.startsWith("http://", ignoreCase = true) || literal.startsWith("https://", ignoreCase = true)
        val host = hostOf(literal)
        if (scheme && host != null && literal.none { it.isWhitespace() } && literal.codePointCount(0, literal.length) <= URL_MAX) Candidate(literal) else null
    }

    /** Trimmed, cut to [max] characters (Postgres counts code points), null when empty. */
    fun clip(text: String?, max: Int): String? {
        val trimmed = text?.trim()?.takeIf { it.isNotEmpty() } ?: return null
        if (trimmed.codePointCount(0, trimmed.length) <= max) return trimmed
        return trimmed.substring(0, trimmed.offsetByCodePoints(0, max)).trim().takeIf { it.isNotEmpty() }
    }

    /** The address's host without a leading "www." — the site line when the page names none. */
    fun host(url: String): String? {
        val host = hostOf(url) ?: return null
        return (if (host.startsWith("www.", ignoreCase = true)) host.substring(WWW) else host).takeIf { it.isNotEmpty() }
    }

    /** A preview still belongs to a text while the text holds its address (an edit that drops it drops the preview). */
    fun keeps(preview: LinkPreview?, body: String?): LinkPreview? =
        preview?.takeIf { body != null && body.contains(it.url) }

    private fun hostOf(address: String): String? = try {
        URI(address).host
    } catch (_: Exception) {
        null
    }

    private const val WWW = 4 // provenance-ok: length of the "www." host prefix
}

/**
 * The sender's pipeline (`chat.thread.layout.linkPreview`): the text's link → the page read once → its image downscaled to
 * a JPEG → the draft for `set_link_preview`. Null (no preview, nothing shown) when there is no link, the page cannot be
 * read, or it gives neither a title nor an image.
 */
class LinkPreviewBuilder(private val reader: LinkPageReader, private val encoder: LinkImageEncoder) {
    suspend fun build(body: String): LinkPreviewDraft? {
        val link = ChatLinkPreviews.candidate(body) ?: return null
        val page = reader.read(link.text) ?: return null
        val title = ChatLinkPreviews.clip(page.title, ChatLinkPreviews.TITLE_MAX)
        val site = ChatLinkPreviews.clip(page.site, ChatLinkPreviews.SITE_MAX)
            ?: ChatLinkPreviews.clip(ChatLinkPreviews.host(link.text), ChatLinkPreviews.SITE_MAX)
        val jpeg = page.image?.takeIf { it.isNotEmpty() }?.let { encoder.jpeg(it) }
        if (title == null && jpeg == null) return null
        return LinkPreviewDraft(link.text, title, site, jpeg)
    }

    companion object {
        /** The app's builder: one GET of the page (HttpURLConnection) and a Bitmap re-encode. */
        fun live(): LinkPreviewBuilder = LinkPreviewBuilder(HttpLinkPageReader(), BitmapLinkImageEncoder())
    }
}
