// Surface: chat.reactions (picker §3) — the Unicode emoji catalog the picker shows (design/surfaces/chat.reactions.md):
// AppModels' `EmojiCatalog` read from the bundled EmojiCatalog.txt (tools/emoji-catalog.mjs), without the emoji this
// device's emoji font cannot draw, as the system keyboard offers only what it can draw.
import AppModels
import CoreText
import Foundation

/// The bundled catalog, read once; its names label emoji for VoiceOver (`SocialEmoji.name`).
enum SocialEmojiCatalog {
    /// Every entry of the bundled file (no device filter): names and lookups.
    static let bundled: EmojiCatalog = {
        guard let url = Bundle.main.url(forResource: "EmojiCatalog", withExtension: "txt"), // provenance-ok: bundled resource name
              let text = try? String(contentsOf: url, encoding: .utf8) else { return EmojiCatalog(groups: []) }
        return EmojiCatalog(text: text)
    }()

    static let names: [String: String] = bundled.names

    /// The catalog without what this device cannot draw; computed off the main actor on first use, then kept.
    static func shown() async -> EmojiCatalog {
        await cache.shown()
    }

    private static let cache = Cache()

    private actor Cache {
        private var value: EmojiCatalog?

        func shown() -> EmojiCatalog {
            if let value { return value }
            let result = SocialEmojiCatalog.bundled.filtered(EmojiGlyphs.isDrawable)
            value = result
            return result
        }
    }
}

/// Whether the system emoji font draws a sequence as one glyph: a newer emoji falls back to another font or to
/// `.notdef`, a ZWJ sequence the font lacks draws as several glyphs (Core Text shaping, PLATFORM).
enum EmojiGlyphs {
    nonisolated(unsafe) private static let fontName = "AppleColorEmoji" as CFString // provenance-ok: the system emoji font's PostScript name (glyph check, not drawn)
    nonisolated(unsafe) private static let font = CTFontCreateWithName(fontName, 20, nil) // provenance-ok: any size works for a glyph check

    static func isDrawable(_ emoji: String) -> Bool {
        let attributes = [NSAttributedString.Key(kCTFontAttributeName as String): font]
        let line = CTLineCreateWithAttributedString(NSAttributedString(string: emoji, attributes: attributes))
        guard let runs = CTLineGetGlyphRuns(line) as? [CTRun] else { return false }
        var glyphCount = 0
        for run in runs {
            let count = CTRunGetGlyphCount(run)
            glyphCount += count
            let runAttributes = CTRunGetAttributes(run) as NSDictionary
            guard let runFontValue = runAttributes[kCTFontAttributeName as String] else { return false }
            let runFont = runFontValue as! CTFont // swiftlint:disable:this force_cast
            guard CTFontCopyPostScriptName(runFont) as String == fontName as String else { return false }
            var glyphs = [CGGlyph](repeating: 0, count: count)
            CTRunGetGlyphs(run, CFRange(location: 0, length: count), &glyphs)
            if glyphs.contains(0) { return false }
        }
        return glyphCount == 1
    }
}
