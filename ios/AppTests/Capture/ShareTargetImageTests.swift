// share.in — the share sheet's per-group suggestions carry the group's image (design/surfaces/share.in.md "Per-group
// targets"): its cover when decoded on the device, else its initials as Android's share-target icon draws them.
@testable import App
import Intents
import UIKit
import XCTest

@MainActor
final class ShareTargetImageTests: XCTestCase {
    func testInitialsAreTheFirstLettersOfTheFirstTwoWords() {
        XCTAssertEqual(ShareTargetDonations.initials("Book club"), "BC")
        XCTAssertEqual(ShareTargetDonations.initials("  sunday   dinners and more "), "SD")
        XCTAssertEqual(ShareTargetDonations.initials("(roommates)"), "R")
        XCTAssertEqual(ShareTargetDonations.initials("   "), "")
    }

    func testTheDonationCarriesTheGroupImageOnItsName() {
        let group = ShareTargetDonations.Group(id: "g-1", name: "Book club")
        let data = ShareTargetDonations.imageData(for: group)
        XCTAssertNotNil(data, "no cover cached: the initials")
        let intent = ShareTargetDonations.intent(for: group, image: data.map { INImage(imageData: $0) })
        XCTAssertNotNil(intent.image(forParameterNamed: \.speakableGroupName))
    }

    func testACachedCoverIsUsedOverTheInitials() {
        let path = "u/test/covers/share-target.jpg" // provenance-ok: test storage path
        let cover = UIGraphicsImageRenderer(size: CGSize(width: 20, height: 10)).image { context in
            UIColor.systemRed.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 20, height: 10))
        }
        ImagePipeline.shared.insert(cover, path: path, pixels: 20)
        defer { ImagePipeline.shared.removeAll() }
        let withCover = ShareTargetDonations.imageData(for: ShareTargetDonations.Group(id: "g-1", name: "Book club", coverPath: path))
        let initials = ShareTargetDonations.imageData(for: ShareTargetDonations.Group(id: "g-1", name: "Book club"))
        XCTAssertNotNil(withCover)
        XCTAssertNotEqual(withCover, initials)
    }
}
