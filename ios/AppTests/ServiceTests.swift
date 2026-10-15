import AppModels
import AppServices
import DesignSystem
import ImageIO
import UniformTypeIdentifiers
import XCTest

/// Apple-only behavior that runs on a simulator without camera, microphone or network.
final class WidgetStoreSimulatorTests: XCTestCase {
    func testRoundTripThroughFallbackDirectory() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        // No App Group (unsigned simulator builds, tests): the store uses the fallback directory.
        let store = WidgetStore.resolve(appGroupIdentifier: nil, fallbackDirectory: directory)
        XCTAssertTrue(store.rootURL.path.hasPrefix(directory.path))

        try store.syncGroups([WidgetGroup(id: "g1", name: "Family")])
        let snapshot = WidgetSnapshot(groupID: "g1", groupName: "Family", sourceID: "p1", photoFileName: "photo-p1.jpg",
                                      senderDisplayName: "Ana", kind: .photo, postedAt: Date(timeIntervalSince1970: 1_000))
        try store.writeFile(Data([0xFF, 0xD8]), groupID: "g1", fileName: snapshot.photoFileName)
        try store.save(snapshot)

        let reopened = WidgetStore.resolve(appGroupIdentifier: nil, fallbackDirectory: directory)
        XCTAssertEqual(reopened.latestSnapshot(groupID: "g1"), snapshot)
        XCTAssertEqual(reopened.groups(), [WidgetGroup(id: "g1", name: "Family")])
        XCTAssertNotNil(reopened.photoURL(for: snapshot))
    }
}

final class ImageEncoderTests: XCTestCase {
    /// A 200×100 JPEG with a GPS dictionary and EXIF orientation 6 (displayed rotated to 100×200).
    private func photoWithLocation() throws -> Data {
        let context = try XCTUnwrap(CGContext(
            data: nil, width: 200, height: 100, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.setFillColor(red: 0.2, green: 0.4, blue: 0.6, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: 200, height: 100))
        let image = try XCTUnwrap(context.makeImage())
        let output = NSMutableData()
        let destination = try XCTUnwrap(CGImageDestinationCreateWithData(output as CFMutableData, UTType.jpeg.identifier as CFString, 1, nil))
        let gps: [CFString: Any] = [
            kCGImagePropertyGPSLatitude: 48.8584, kCGImagePropertyGPSLatitudeRef: "N",
            kCGImagePropertyGPSLongitude: 2.2945, kCGImagePropertyGPSLongitudeRef: "E",
        ]
        let properties: [CFString: Any] = [kCGImagePropertyGPSDictionary: gps, kCGImagePropertyOrientation: 6]
        CGImageDestinationAddImage(destination, image, properties as CFDictionary)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
        return output as Data
    }

    func testUploadEncodingStripsLocationAndAppliesOrientation() throws {
        let original = try photoWithLocation()
        XCTAssertTrue(ImageEncoder.containsLocation(original), "fixture carries GPS")

        let encoded = try ImageEncoder.jpegForUpload(original, options: .init(maxPixelSize: 64, compressionQuality: 0.8))
        XCTAssertFalse(ImageEncoder.containsLocation(encoded))
        let size = try XCTUnwrap(ImageEncoder.pixelSize(encoded))
        XCTAssertEqual(max(size.width, size.height), 64)
        XCTAssertLessThan(size.width, size.height, "EXIF orientation applied to the pixels")
    }

    func testLosslessLocationRemoval() throws {
        let original = try photoWithLocation()
        let stripped = try XCTUnwrap(ImageEncoder.removingLocation(from: original))
        XCTAssertFalse(ImageEncoder.containsLocation(stripped))
        XCTAssertEqual(ImageEncoder.pixelSize(stripped)?.width, 200)
    }

    func testRejectsNonImageData() {
        XCTAssertThrowsError(try ImageEncoder.jpegForUpload(Data("not an image".utf8), options: .init(maxPixelSize: 10, compressionQuality: 1)))
    }
}

final class CountdownSimulatorTests: XCTestCase {
    func testLiveActivityRangeAndState() {
        let now = Date()
        let closesAt = now.addingTimeInterval(90)
        XCTAssertEqual(CountdownState(opensAt: nil, closesAt: closesAt, now: now).remainingWholeSeconds, 90)
        XCTAssertEqual(CountdownState.timerRange(closesAt: closesAt, now: now), now...closesAt)
        let closed = CountdownState.timerRange(closesAt: now.addingTimeInterval(-5), now: now)
        XCTAssertEqual(closed.lowerBound, closed.upperBound, "never inverted after the close")
    }
}

final class DesignSystemTests: XCTestCase {
    func testCopyLookupFallsBackToCanonicalText() {
        XCTAssertEqual(CopyLookup.string("test.missing.key", default: "Default"), "Default")
        XCTAssertEqual(CopyLookup.format("test.missing.key", default: "Hi {name}", ["name": "Ana"]), "Hi Ana")
    }

    func testReducedMotionKeepsTimingAndRemovesBounce() {
        let timing = DSAnimation.timing(duration: 0.3, easing: .easeInOut)
        XCTAssertEqual(timing.reducedMotion, timing)
        let spring = DSAnimation.spring(DSSpring(response: 0.4, dampingFraction: 0.6))
        XCTAssertEqual(spring.reducedMotion, .spring(DSSpring(response: 0.4, dampingFraction: 1)))
    }

    func testHapticsMapToSensoryFeedback() {
        XCTAssertEqual(DSHaptic.allCases.count, 9)
        for haptic in DSHaptic.allCases { _ = haptic.sensoryFeedback }
    }
}
