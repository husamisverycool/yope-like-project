package app.feature.social

import app.designsystem.generated.Tokens
import app.feature.social.data.LinkPageTags
import app.feature.social.data.OgParser
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/** `chat.thread.layout.linkPreview`: the sender's small, size-limited Open Graph reader (https://ogp.me). */
class OgParserTest {
    private val page = "https://www.example.com/menu/friday"

    @Test fun openGraphTagsInAnyOrderAndQuoting() {
        val html = """
            <!doctype html><html><head>
            <meta charset="utf-8">
            <title>Fallback title</title>
            <meta content="Friday menu &amp; drinks" property="og:title">
            <meta property='og:site_name' content='Example Eats'>
            <META PROPERTY=og:image CONTENT=/img/friday.jpg>
            </head><body><meta property="og:title" content="not in the head"></body></html>
        """.trimIndent()
        assertEquals(
            LinkPageTags(title = "Friday menu & drinks", site = "Example Eats", imageUrl = "https://www.example.com/img/friday.jpg"),
            OgParser.parse(html, page),
        )
    }

    @Test fun theFirstOfEachTagWinsAndTheSecureImageComesFirst() {
        val html = """
            <head>
            <meta property="og:title" content="First">
            <meta property="og:title" content="Second">
            <meta property="og:image" content="http://cdn.example.com/a.jpg">
            <meta property="og:image:secure_url" content="https://cdn.example.com/a.jpg">
            </head>
        """.trimIndent()
        val tags = OgParser.parse(html, page)
        assertEquals("First", tags.title)
        assertEquals("https://cdn.example.com/a.jpg", tags.imageUrl)
    }

    @Test fun twitterTagsThenTheTitleElementWhenOpenGraphIsMissing() {
        val twitter = """<head><meta name="twitter:title" content="Tweet title"><meta name="twitter:image" content="//cdn.example.com/t.png"></head>"""
        assertEquals(LinkPageTags(title = "Tweet title", imageUrl = "https://cdn.example.com/t.png"), OgParser.parse(twitter, page))

        val plain = "<html><head><title>\n  Just a   page &#8212; &#x41;\n</title></head></html>"
        assertEquals(LinkPageTags(title = "Just a page — A"), OgParser.parse(plain, page))
        assertEquals(LinkPageTags(), OgParser.parse("<html><body>nothing</body></html>", page))
    }

    @Test fun onlyHttpImagesAreKept() {
        val html = """<head><meta property="og:title" content="T"><meta property="og:image" content="data:image/png;base64,AAAA"></head>"""
        assertNull(OgParser.parse(html, page).imageUrl)
        assertNull(OgParser.resolve(page, "javascript:alert(1)"))
        assertEquals("https://www.example.com/menu/b.jpg", OgParser.resolve(page, "b.jpg"))
    }

    @Test fun emptyContentIsIgnoredAndUnknownEntitiesStay() {
        val html = """<head><meta property="og:title" content="  "><meta property="og:site_name" content="A &bogus; B"><title>Real</title></head>"""
        assertEquals(LinkPageTags(title = "Real", site = "A &bogus; B"), OgParser.parse(html, page))
    }

    @Test fun nothingBeyondTheSizeLimitIsRead() {
        val limit = Tokens.Layouts.ChatThreadLayoutLinkPreview.htmlMaxBytes.toInt()
        val html = "<html><head>" + " ".repeat(limit) + """<meta property="og:title" content="Too far"></head>"""
        assertNull(OgParser.parse(html, page).title)
    }
}
