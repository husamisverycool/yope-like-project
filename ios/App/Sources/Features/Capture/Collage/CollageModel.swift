// Surfaces: collage.view + collage.share — reference: BeReal dual image + Yope wall composition and
// day view. Reference images: design/collage-options/option-B.jpg,
// references/auto/yope/frames/b-alexaa-7652512140875566349-t5.33-day-view-recap.png,
// references/auto/yope/frames/a-itsmthuyope-7644974799302823175-t50.60-loading-hud.png
// (design/surfaces/collage.view.md, collage.share.md). Option B pages (production fallback).
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

    private(set) var state: State = .loading
    private(set) var collage: Collage? = nil
    /// Page images by 1-based page number.
    private(set) var pages: [Int: UIImage] = [:]
    /// The selected page (1-based). The view calls `pageChanged()` after a swipe.
    var currentPage = 1
    private(set) var dateText = ""
    private(set) var groupName = ""

    @ObservationIgnored let collages: CaptureCollageSource
    @ObservationIgnored private let invitations: CaptureInvitationSource
    @ObservationIgnored private let navigation: CaptureNavigation

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

    var title: String { dateText.isEmpty ? "" : Copy.collageViewTitle(date: dateText) }

    var pageAccessibilityLabel: String {
        Copy.collageViewA11yCollage(group: groupName, date: dateText)
    }

    // MARK: Loading

    func load() async {
        async let details: Void = loadDetails()
        if let cached = await collages.cachedCollage(invitationID: invitationID), cached.imagePath != nil {
            collage = cached
            if let image = collages.cachedImage(path: cached.imagePath(page: 1) ?? "") {
                pages[1] = image
                state = .ready
            }
        }
        do {
            let fresh = try await collages.collage(invitationID: invitationID)
            apply(fresh)
        } catch {
            if pages.isEmpty {
                state = (collages.isOffline || DataError.from(error) == .offline) ? .offline : .error
            }
        }
        await details
        await loadPages(around: currentPage)
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

    private func apply(_ fresh: Collage?) {
        guard let fresh else {
            // No collage row: the window closed with no answers.
            if pages.isEmpty { state = .empty }
            return
        }
        switch fresh.status {
        case .failed:
            if pages.isEmpty { state = .error }
        case .ready where fresh.imagePath != nil:
            if fresh.imagePath != collage?.imagePath { pages = [:] }
            collage = fresh
            state = pages.isEmpty ? .loading : .ready
        default:
            // Pending or recomposing (`image_path` null): the previous pages stay, else loading.
            if pages.isEmpty { state = .loading }
        }
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
                if number == page && pages.isEmpty {
                    state = (collages.isOffline || DataError.from(error) == .offline) ? .offline : .error
                }
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
