import Foundation

/// The files the app keeps outside AppData for the person who is signed in: capture drafts (`CaptureDrafts`), voice
/// recordings, downloaded media copies and share images (all in the temporary directory) and rendered collage pages
/// (`CaptureCollagePages` in Caches). `SessionCoordinator` removes them when a session ends (sign-out, account
/// deletion, expiry) through `SessionHooks.removeSessionFiles`, so the next person on the device finds nothing of the
/// previous one's (the end-to-end sign-out audit; Android: `SessionEndCleanup`). The system may purge both places at
/// any time, so nothing in them is needed later.
enum SessionFiles {
    static let collagePagesFolder = "CaptureCollagePages"

    static func removeAll(fileManager: FileManager = .default) {
        removeContents(of: fileManager.temporaryDirectory, fileManager: fileManager)
        if let caches = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first {
            try? fileManager.removeItem(at: caches.appendingPathComponent(collagePagesFolder, isDirectory: true))
        }
    }

    static func removeContents(of directory: URL, fileManager: FileManager = .default) {
        let items = (try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        for item in items { try? fileManager.removeItem(at: item) }
    }
}
