// Account group — the in-app QR invite card (groups.invite, owner decision 17; token groups.invite.layout.qrCard): the
// symbol CoreImage encodes, its quiet zone and whole-pixel modules, the rendered card read back by the system's QR
// detector (the link, error correction H), Save's outcomes, and the "Ideas to Get Started" covers in the asset catalog
// (groups.list.layout.templateCovers, owner decision 9).
@testable import App
import AppData
import AppModels
import AppServices
import CoreImage
import DesignSystem
import SwiftUI
import UIKit
import XCTest

@MainActor
final class AccountInviteQRTests: XCTestCase {
    private let link = "https://example.test/i/AbCdEfGhIjKlMnOpQrStUvWx"

    // MARK: Encoding

    func testMatrixIsASymbolWithItsThreeFinderPatterns() throws {
        let matrix = try XCTUnwrap(InviteQRCode.matrix(for: link))
        XCTAssertGreaterThanOrEqual(matrix.size, 21)
        XCTAssertEqual((matrix.size - 21) % 4, 0, "a QR version is 21 + 4k modules wide")
        let far = matrix.size - 7
        for (left, top) in [(0, 0), (far, 0), (0, far)] {
            for step in 0..<7 {
                XCTAssertTrue(matrix.isDark(x: left + step, y: top), "finder ring top")
                XCTAssertTrue(matrix.isDark(x: left + step, y: top + 6), "finder ring bottom")
                XCTAssertTrue(matrix.isDark(x: left, y: top + step), "finder ring left")
                XCTAssertTrue(matrix.isDark(x: left + 6, y: top + step), "finder ring right")
            }
            XCTAssertFalse(matrix.isDark(x: left + 1, y: top + 1), "light ring")
            XCTAssertTrue(matrix.isDark(x: left + 3, y: top + 3), "dark core")
        }
        XCTAssertEqual(InviteQRCode.matrix(for: link), matrix, "the same link always gives the same symbol")
    }

    func testImageAddsAFourModuleQuietZone() throws {
        let matrix = try XCTUnwrap(InviteQRCode.matrix(for: link))
        let image = try XCTUnwrap(InviteQRCode.image(of: matrix))
        XCTAssertEqual(InviteQRCode.quietZone, 4, "DENSO WAVE: a four-module margin on every side")
        XCTAssertEqual(image.width, matrix.size + 8)
        XCTAssertEqual(image.height, matrix.size + 8)
        let alpha = try alphaChannel(of: image)
        for index in 0..<4 {
            for along in 0..<image.width {
                XCTAssertEqual(alpha[index * image.width + along], 0, "top margin clear")
                XCTAssertEqual(alpha[along * image.width + index], 0, "left margin clear")
            }
        }
        XCTAssertEqual(alpha[4 * image.width + 4], 255, "the top-left finder starts after the margin")
    }

    func testModulesAreAWholeNumberOfPixels() {
        // 308 pt at 3× for a 41-module symbol (+ 8 quiet): floor(924 ÷ 49) = 18 px, as web/src/render/qr.ts floors.
        XCTAssertEqual(InviteQRCode.modulePixels(side: 924, symbolSize: 41), 18)
        XCTAssertEqual(InviteQRCode.modulePixels(side: 20, symbolSize: 41), 1, "never below one pixel")
    }

    func testRenderedCardReadsBackAsTheLinkAtLevelH() throws {
        let card = InviteQRCard(link: link, groupName: "Sunday Dinners", width: 324)
        let image = try XCTUnwrap(card.renderedImage())
        XCTAssertEqual(image.scale, Tokens.Layouts.GroupsInviteLayoutQrCard.exportScale, "exported at 3×")
        let feature = try XCTUnwrap(qrFeatures(in: image).first, "the system QR detector finds the code on the card")
        XCTAssertEqual(feature.messageString, link, "the card encodes the link the sheet shares")
        XCTAssertEqual(feature.symbolDescriptor?.errorCorrectionLevel, .levelH, "error correction H, as the web page")
    }

    func testCardReadsAsTheGroupsJoinCode() {
        XCTAssertEqual(Copy.groupsInviteQrAccessibilityLabel(groupName: "Sunday Dinners"), "QR code for joining Sunday Dinners")
        XCTAssertEqual(Copy.groupsInviteLinkQr, "QR Code")
    }

    // MARK: Save

    func testSaveConfirmsWithTheSavedLine() async throws {
        let toasts = ToastCenter()
        let saved = SavedImages()
        let model = GroupInviteQRModel(link: try XCTUnwrap(URL(string: link)), groupName: "Sunday Dinners", cover: nil, toasts: toasts) {
            await saved.add($0)
        }
        XCTAssertNotNil(model.matrix)
        await model.save(png: Data([1, 2, 3]))
        let count = await saved.count
        XCTAssertEqual(count, 1)
        XCTAssertEqual(toasts.message, Copy.groupsInviteQrSaved)
        XCTAssertEqual(model.successCount, 1)
        XCTAssertFalse(model.isSaving)
    }

    func testDeniedPhotoAccessShowsTheSettingsAlert() async throws {
        let toasts = ToastCenter()
        let model = GroupInviteQRModel(link: try XCTUnwrap(URL(string: link)), groupName: "Sunday Dinners", cover: nil, toasts: toasts) { _ in
            throw PhotoLibraryService.LibraryError.notAuthorized(.denied)
        }
        await model.save(png: Data([1]))
        XCTAssertTrue(model.showsSaveDenied)
        XCTAssertNil(toasts.message)
        XCTAssertEqual(model.errorCount, 1)
    }

    func testFailedSaveSaysSo() async throws {
        let toasts = ToastCenter()
        let model = GroupInviteQRModel(link: try XCTUnwrap(URL(string: link)), groupName: "Sunday Dinners", cover: nil, toasts: toasts) { _ in
            throw PhotoLibraryService.LibraryError.unreadableItem
        }
        await model.save(png: Data([1]))
        XCTAssertEqual(toasts.message, Copy.groupsInviteQrSaveFailed)
        XCTAssertFalse(model.showsSaveDenied)

        toasts.dismiss()
        await model.save(png: nil)
        XCTAssertEqual(toasts.message, Copy.groupsInviteQrSaveFailed, "no image rendered: nothing to save")
        XCTAssertEqual(model.errorCount, 2)
    }

    // MARK: Template covers

    func testEveryKindHasItsCoverInTheAssetCatalog() throws {
        var names = Set<String>()
        for kind in GroupKindCopy.kinds {
            let name = GroupKindCopy.coverAsset(kind)
            names.insert(name)
            let image = try XCTUnwrap(UIImage(named: name), "\(name) is in ios/App/Resources/Assets.xcassets")
            XCTAssertEqual(image.size.width, Tokens.Sizes.globalRowThumbWidth, accuracy: 0.01, "72-pt thumbnail")
            XCTAssertEqual(image.size.height, Tokens.Sizes.globalRowThumbHeight, accuracy: 0.01, "97-pt thumbnail")
            XCTAssertEqual(image.size.width * image.scale, Tokens.Layouts.GroupsListLayoutTemplateCovers.pixelWidth, accuracy: 0.01)
            XCTAssertEqual(image.size.height * image.scale, Tokens.Layouts.GroupsListLayoutTemplateCovers.pixelHeight, accuracy: 0.01)
        }
        XCTAssertEqual(names.count, 4, "one photo per kind")
    }

    // MARK: Helpers

    private func alphaChannel(of image: CGImage) throws -> [UInt8] {
        var rgba = [UInt8](repeating: 0, count: image.width * image.height * 4)
        let drawn = rgba.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(
                data: buffer.baseAddress, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: image.width * 4,
                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
            return true
        }
        XCTAssertTrue(drawn)
        return stride(from: 3, to: rgba.count, by: 4).map { rgba[$0] }
    }

    /// The card on white (its corners are clear), read by CoreImage's QR detector.
    private func qrFeatures(in image: UIImage) -> [CIQRCodeFeature] {
        let format = UIGraphicsImageRendererFormat()
        format.scale = image.scale
        format.opaque = true
        let flattened = UIGraphicsImageRenderer(size: image.size, format: format).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: image.size))
            image.draw(at: .zero)
        }
        guard let cgImage = flattened.cgImage,
              let detector = CIDetector(ofType: CIDetectorTypeQRCode, context: nil, options: [CIDetectorAccuracy: CIDetectorAccuracyHigh])
        else { return [] }
        return detector.features(in: CIImage(cgImage: cgImage)).compactMap { $0 as? CIQRCodeFeature }
    }
}

/// Images handed to the saver (Save's test double).
private actor SavedImages {
    private(set) var count = 0

    func add(_ data: Data) {
        count += 1
    }
}
