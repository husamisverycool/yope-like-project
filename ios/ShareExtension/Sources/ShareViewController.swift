// Surface: share.in — "Share to Jolt" from Photos and other apps (design/surfaces/share.in.md; docs/RESEARCH_FEATURES_
// 2026-10-17.md #4). Mechanics: Apple Shared Albums "Share → Add to Shared Album" (support.apple.com/108314): the app
// appears in the system share sheet for photos and videos (Info.plist NSExtensionActivationRule, up to
// `batch_max_photos` = 20 of each); choosing it hands the items to the app, which opens on camera.sendto with them.
// This extension draws nothing of its own: it copies the items into the App Group inbox (AppModels `ShareInbox`), opens
// the app with `<app scheme>://share` and finishes. Signed in or not, the app decides (signed out: sign-in first, then
// send-to). Nothing but the files is kept — no caption, no place, no sender.
import AppModels
import UIKit
import UniformTypeIdentifiers

final class ShareViewController: UIViewController {
    private var handedOver = false

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !handedOver else { return }
        handedOver = true
        Task { await handOver() }
    }

    private func handOver() async {
        let providers = (extensionContext?.inputItems as? [NSExtensionItem] ?? []).flatMap { $0.attachments ?? [] }
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        var files: [ShareInbox.File] = []
        for provider in providers {
            if let file = await Self.copy(provider, into: folder) { files.append(file) }
        }
        var stored = false
        if !files.isEmpty {
            stored = (try? ShareInbox.forBundle(.main).replace(with: files)) != nil
        }
        try? FileManager.default.removeItem(at: folder)
        if stored, let scheme = ShareInLink.scheme(in: .main), let url = ShareInLink.url(scheme: scheme) {
            openContainingApp(url)
        }
        extensionContext?.completeRequest(returningItems: nil)
    }

    /// Share extensions have no `openURL`; the responder chain reaches the extension's `UIApplication`, which opens the
    /// containing app's own scheme. When it cannot, the items wait in the inbox and the app takes them the next time it
    /// comes to the foreground.
    private func openContainingApp(_ url: URL) {
        var responder: UIResponder? = self
        while let current = responder {
            if let application = current as? UIApplication {
                application.open(url, options: [:], completionHandler: nil)
                return
            }
            responder = current.next
        }
    }

    /// A movie or an image of the share, copied out of the provider's temporary file (deleted when the callback returns).
    private static func copy(_ provider: NSItemProvider, into folder: URL) async -> ShareInbox.File? {
        if provider.hasItemConformingToTypeIdentifier(UTType.movie.identifier),
           let url = await copyFile(provider, type: UTType.movie, into: folder) {
            return ShareInbox.File(url: url, kind: .movie)
        }
        if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
            if let url = await copyFile(provider, type: UTType.image, into: folder) {
                return ShareInbox.File(url: url, kind: .image)
            }
            if let data = await imageData(provider) {
                let url = folder.appendingPathComponent(UUID().uuidString).appendingPathExtension(UTType.image.preferredFilenameExtension ?? "img")
                if (try? data.write(to: url, options: [.atomic])) != nil {
                    return ShareInbox.File(url: url, kind: .image)
                }
            }
        }
        return nil
    }

    private static func copyFile(_ provider: NSItemProvider, type: UTType, into folder: URL) async -> URL? {
        await withCheckedContinuation { (continuation: CheckedContinuation<URL?, Never>) in
            _ = provider.loadFileRepresentation(forTypeIdentifier: type.identifier) { url, _ in
                guard let url else {
                    continuation.resume(returning: nil)
                    return
                }
                let copy = folder.appendingPathComponent(UUID().uuidString).appendingPathExtension(url.pathExtension)
                do {
                    try FileManager.default.copyItem(at: url, to: copy)
                    continuation.resume(returning: copy)
                } catch {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    private static func imageData(_ provider: NSItemProvider) async -> Data? {
        await withCheckedContinuation { (continuation: CheckedContinuation<Data?, Never>) in
            _ = provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, _ in
                continuation.resume(returning: data)
            }
        }
    }
}
