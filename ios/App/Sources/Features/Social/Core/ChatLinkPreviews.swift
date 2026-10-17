// Surface: chat.thread — link previews built on the sender's device (`chat.thread.layout.linkPreview`, owner decision 34,
// research #16; migration 0053, docs/API.md `set_link_preview`). The model side only (Foundation + AppData): which link
// of a sent text gets a preview, and the pipeline read page → downscaled JPEG → draft. The page is read by
// `LinkPresentationPageReader` (LPMetadataProvider) in the app; tests pass fakes.
import AppData
import Foundation

/// What the sender's device read from a page once.
struct LinkPageMetadata: Equatable, Sendable {
    var title: String?
    /// The site's own name when the page says it; nil → the address's host.
    var site: String?
    /// The page's image as the platform returned it (any ImageIO format); nil when none.
    var imageData: Data?

    init(title: String? = nil, site: String? = nil, imageData: Data? = nil) {
        self.title = title
        self.site = site
        self.imageData = imageData
    }
}

/// Reads a page once, on the sender's device (iOS: LPMetadataProvider). Nil on any failure: no preview.
protocol LinkPageReading: Sendable {
    func read(_ url: URL) async -> LinkPageMetadata?
}

/// Downscales a page's image and re-encodes it as a JPEG without metadata; nil when it cannot.
protocol LinkPreviewImageEncoding: Sendable {
    func jpeg(from data: Data) async -> Data?
}

/// What `set_link_preview` receives: the address as written in the text, the page's title and site, and the image to
/// upload first (`u/<uid>/links/<uuid>.jpg`).
struct LinkPreviewDraft: Equatable, Sendable {
    var url: String
    var title: String?
    var site: String?
    var jpeg: Data?
}

/// The link of a text message a preview is built for, and the limits `set_link_preview` checks.
enum ChatLinkPreviews {
    /// `p_url` ≤ 2000 characters (docs/API.md `set_link_preview`).
    static let urlMax = 2000
    /// `p_title` ≤ 300 characters.
    static let titleMax = 300
    /// `p_site` ≤ 100 characters.
    static let siteMax = 100

    struct Candidate: Equatable {
        /// The address exactly as written in the text (`set_link_preview` finds it in the body).
        let text: String
        let url: URL
    }

    /// The first link of the text (`chat.thread.layout.links`, NSDataDetector) written with its own http / https
    /// scheme: an address the detector completed ("example.com") is not in the text as `p_url` must be, so it gets none.
    static func candidate(in body: String) -> Candidate? {
        for link in ChatLinks.find(in: body) {
            let literal = String(body[link.range])
            let lowered = literal.lowercased()
            guard lowered.hasPrefix("http://") || lowered.hasPrefix("https://"),
                  literal.unicodeScalars.count <= urlMax,
                  !literal.contains(where: \.isWhitespace),
                  let url = URL(string: literal), let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https",
                  url.host() != nil else { continue }
            return Candidate(text: literal, url: url)
        }
        return nil
    }

    /// Trimmed, cut to `max` characters (Postgres counts code points), nil when empty.
    static func clip(_ text: String?, to max: Int) -> String? {
        guard let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else { return nil }
        guard trimmed.unicodeScalars.count > max else { return trimmed }
        var scalars = String.UnicodeScalarView()
        scalars.append(contentsOf: trimmed.unicodeScalars.prefix(max))
        let cut = String(scalars).trimmingCharacters(in: .whitespacesAndNewlines)
        return cut.isEmpty ? nil : cut
    }

    /// The address's host without a leading "www." — the site line when the page names none.
    static func host(of url: URL) -> String? {
        guard var host = url.host(), !host.isEmpty else { return nil }
        if host.lowercased().hasPrefix("www.") { host = String(host.dropFirst(4)) } // provenance-ok: host prefix, not copy
        return host.isEmpty ? nil : host
    }

    /// Whether a preview still belongs to a text (an edit that drops its address drops it, as the server does).
    static func keeps(_ preview: LinkPreview?, body: String?) -> LinkPreview? {
        guard let preview, let body, body.contains(preview.url) else { return nil }
        return preview
    }
}

/// The sender's pipeline (`chat.thread.layout.linkPreview`): the text's link → the page read once → its image downscaled
/// to a JPEG → the draft for `set_link_preview`. Nil (no preview, nothing shown) when there is no link, the page cannot
/// be read, or it gives neither a title nor an image.
struct LinkPreviewBuilder: Sendable {
    let reader: any LinkPageReading
    let encoder: any LinkPreviewImageEncoding

    func build(for body: String) async -> LinkPreviewDraft? {
        guard let link = ChatLinkPreviews.candidate(in: body), let page = await reader.read(link.url) else { return nil }
        let title = ChatLinkPreviews.clip(page.title, to: ChatLinkPreviews.titleMax)
        let site = ChatLinkPreviews.clip(page.site, to: ChatLinkPreviews.siteMax)
            ?? ChatLinkPreviews.clip(ChatLinkPreviews.host(of: link.url), to: ChatLinkPreviews.siteMax)
        var jpeg: Data?
        if let image = page.imageData, !image.isEmpty { jpeg = await encoder.jpeg(from: image) }
        guard title != nil || jpeg != nil else { return nil }
        return LinkPreviewDraft(url: link.text, title: title, site: site, jpeg: jpeg)
    }
}
