// Surface: chat.thread — the sender's device reads a link's page once (`chat.thread.layout.linkPreview`; Apple
// LinkPresentation: https://developer.apple.com/documentation/linkpresentation/lpmetadataprovider) and downscales its
// image for the upload (AppServices `ImageEncoder`, no metadata). The model side is Core/ChatLinkPreviews.swift.
import AppServices
import DesignSystem
import Foundation
import LinkPresentation
import UniformTypeIdentifiers

extension LinkPreviewBuilder {
    /// The app's builder: LPMetadataProvider + ImageEncoder.
    static var live: LinkPreviewBuilder {
        LinkPreviewBuilder(reader: LinkPresentationPageReader(), encoder: LinkPreviewJPEGEncoder())
    }
}

/// Reads a page with `LPMetadataProvider` (title and image; the site line falls back to the host). Any error or the
/// timeout (`chat.thread.layout.linkPreview.timeoutSeconds`, LinkPresentation's own default) → nil.
struct LinkPresentationPageReader: LinkPageReading {
    /// Keeps the provider alive until its completion handler runs (one provider per page, as LinkPresentation asks).
    private final class ProviderBox: @unchecked Sendable {
        let provider = LPMetadataProvider()
    }

    func read(_ url: URL) async -> LinkPageMetadata? {
        await withCheckedContinuation { (continuation: CheckedContinuation<LinkPageMetadata?, Never>) in
            let box = ProviderBox()
            box.provider.timeout = TimeInterval(Tokens.Layouts.ChatThreadLayoutLinkPreview.timeoutSeconds)
            box.provider.startFetchingMetadata(for: url) { metadata, error in
                withExtendedLifetime(box) {}
                guard let metadata, error == nil else {
                    continuation.resume(returning: nil)
                    return
                }
                let title = metadata.title
                guard let images = metadata.imageProvider, images.hasItemConformingToTypeIdentifier(UTType.image.identifier) else {
                    continuation.resume(returning: LinkPageMetadata(title: title))
                    return
                }
                _ = images.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, _ in
                    let limit = Int(Tokens.Layouts.ChatThreadLayoutLinkPreview.imageMaxBytes)
                    let image = data.flatMap { $0.count <= limit ? $0 : nil }
                    continuation.resume(returning: LinkPageMetadata(title: title, imageData: image))
                }
            }
        }
    }
}

/// The page's image downscaled to `imageMaxPixels` on its longer side and re-encoded as JPEG at `jpegQuality` (the
/// worker's thumbnail size and quality), without metadata — off the main actor.
struct LinkPreviewJPEGEncoder: LinkPreviewImageEncoding {
    func jpeg(from data: Data) async -> Data? {
        let options = ImageEncoder.Options(
            maxPixelSize: Int(Tokens.Layouts.ChatThreadLayoutLinkPreview.imageMaxPixels),
            compressionQuality: Double(Tokens.Layouts.ChatThreadLayoutLinkPreview.jpegQuality)
        )
        return await Task.detached(priority: .utility) { try? ImageEncoder.jpegForUpload(data, options: options) }.value
    }
}
