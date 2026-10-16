// Surfaces: collage.view + collage.share — visual reference Retro's recap preview (ST-04 2026, TC-REC 2023); the collage
// itself is the worker's composition of BeReal dual images (option B pages, owner-pending — RC-14).
// Reference images: references/auto/retro/store/retro-store-04.png, references/auto/retro/press/tc-2023-12-recaps.png,
// design/collage-options/option-B.jpg (design/surfaces/collage.view.md, collage.share.md).
import AppData
import AppModels
import CoreTransferable
import DesignSystem
import Foundation
import Observation
import UIKit
import UniformTypeIdentifiers

@MainActor
@Observable
final class CollageModel {
    enum State: Equatable {
        /// Before the cache answered: nothing is drawn, so cached pages appear without a HUD frame.
        case idle
        /// Collage `pending` (composing) or its image downloading.
        case loading
        case ready
        /// Window closed with no answer: no collage row.
        case empty
        /// `status = failed`, or the download failed.
        case error
        /// No connection and nothing cached.
        case offline
    }

    let groupID: String
    let invitationID: String

    private(set) var state: State = .idle
    private(set) var collage: Collage? = nil
    /// Page images by 1-based page number.
    private(set) var pages: [Int: UIImage] = [:]
    /// The collage's first photo (`post_ids[0]`, display rendition) for the recap-preview backdrop (MERGE L-7).
    private(set) var firstPhoto: UIImage? = nil
    /// The post ids whose first photo `firstPhoto` shows (reloaded when a recompose changes them).
    @ObservationIgnored private var firstPhotoPostIDs: [PostID]? = nil
    /// The selected page (1-based). The view calls `pageChanged()` after a swipe.
    var currentPage = 1
    private(set) var dateText = ""
    private(set) var groupName = ""

    let collages: CaptureCollageSource
    private let invitations: CaptureInvitationSource
    private let navigation: CaptureNavigation

    init(
        groupID: String,
        invitationID: String,
        collages: CaptureCollageSource,
        invitations: CaptureInvitationSource,
        navigation: CaptureNavigation
    ) {
        self.groupID = groupID
        self.invitationID = invitationID
        self.collages = collages
        self.invitations = invitations
        self.navigation = navigation
    }

    var pageCount: Int { max(1, collage?.pageCount ?? 1) }

    /// The share pill shows once the share image exists (`collages.share_path`).
    var canShare: Bool { state == .ready && collage?.sharePath != nil }

    /// `collage.share.sheetTitle`: the share sheet's preview title, the invitation's day.
    var shareSheetTitle: String { Copy.collageShareSheetTitle(date: dateText) }

    var pageAccessibilityLabel: String {
        Copy.collageViewA11yCollage(group: groupName, date: dateText)
    }

    // MARK: Loading

    func load() async {
        async let details: Void = loadDetails()
        if collage == nil, let cached = await collages.cachedCollage(invitationID: invitationID), cached.isReady,
           let path = cached.imagePath(page: 1), let image = await collages.cachedImage(path: path) {
            collage = cached
            pages = [1: image]
            state = .ready
        }
        if state == .idle { state = .loading }
        do {
            await apply(try await collages.collage(invitationID: invitationID))
        } catch {
            failIfNothingShown(error)
        }
        await details
        await loadPages(around: currentPage)
        await loadFirstPhoto()
    }

    /// collage.view media page (MERGE L-7): the collage's first photo, aspect-filled and blurred; page 1's image until
    /// that photo loads (or when it cannot be resolved — offline, blocked, deleted).
    var backdropImage: UIImage? {
        guard state == .ready else { return nil }
        return firstPhoto ?? pages[1]
    }

    private func loadFirstPhoto() async {
        guard let collage, collage.isReady, firstPhotoPostIDs != collage.postIDs else { return }
        // A recompose that removed the first post must not keep showing it.
        if firstPhotoPostIDs?.first != collage.postIDs.first { firstPhoto = nil }
        guard let path = await collages.firstPhotoPath(postIDs: collage.postIDs),
              let image = try? await collages.image(path: path) else { return }
        firstPhotoPostIDs = collage.postIDs
        firstPhoto = image
    }

    func reload() async {
        if pages.isEmpty { state = .loading }
        await load()
    }

    private func loadDetails() async {
        groupName = await invitations.groupName(groupID: groupID)
        if let invitation = try? await invitations.invitation(id: invitationID, groupID: groupID) {
            if !invitation.groupName.isEmpty { groupName = invitation.groupName }
            if let date = invitation.localDate { dateText = CaptureFormat.collageDate(date) }
        }
    }

    private func apply(_ fresh: Collage?) async {
        guard let fresh else {
            // No collage row: the window closed with no answers.
            if pages.isEmpty { state = .empty }
            return
        }
        switch fresh.status {
        case .failed:
            if pages.isEmpty { state = .error }
        case .ready where fresh.imagePath != nil:
            if fresh.imagePath == collage?.imagePath {
                collage = fresh
                return
            }
            // A new version (first load or recomposed): the shown pages stay until the new first
            // page is decoded, then the pages swap in one frame.
            guard let path = fresh.imagePath(page: 1) else { return }
            do {
                let image = try await collages.image(path: path)
                collage = fresh
                pages = [1: image]
                currentPage = 1
                state = .ready
            } catch {
                failIfNothingShown(error)
            }
        default:
            // Pending, or recomposing (`image_path` null): the previous pages stay, else loading.
            if pages.isEmpty { state = .loading }
        }
    }

    private func failIfNothingShown(_ error: Error) {
        guard pages.isEmpty else { return }
        state = (collages.isOffline || DataError.from(error) == .offline) ? .offline : .error
    }

    /// Loads the current page and its neighbours (paging is horizontal).
    func loadPages(around page: Int) async {
        guard let collage, collage.isReady else { return }
        for number in [page, page + 1, page - 1] where number >= 1 && number <= pageCount && pages[number] == nil {
            guard let path = collage.imagePath(page: number) else { continue }
            do {
                pages[number] = try await collages.image(path: path)
                if number == page { state = .ready }
            } catch {
                if number == page { failIfNothingShown(error) }
            }
        }
    }

    func pageChanged() async {
        await loadPages(around: currentPage)
    }

    // MARK: Actions

    /// Empty state: open the camera with the group preselected.
    func openCamera() {
        navigation.openCamera(groupID: groupID)
    }

    /// The current page's Stories-sized share image (`share-<n>.jpg`), exported lazily.
    func shareItem() -> CollageSharePage? {
        guard let path = collage?.sharePath(page: currentPage) else { return nil }
        return CollageSharePage(path: path, source: collages)
    }
}

/// `collage.share`: the worker's page JPEG as is (9:16, 1080 × 1920), downloaded when the member
/// picks a destination in the system share sheet.
struct CollageSharePage: Transferable {
    let path: String
    let source: CaptureCollageSource

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .jpeg) { page in
            SentTransferredFile(try await page.source.shareFile(path: page.path))
        }
    }
}
