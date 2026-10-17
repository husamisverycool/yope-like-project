// camera.capture zoom arithmetic (`camera.capture.layout.zoom`, design/surfaces/camera.capture.md).
@testable import App
import AppServices
import XCTest

final class CaptureZoomTests: XCTestCase {
    func testLimitIsDeviceMaxCappedAtTenOnTheBackCameraOnly() {
        XCTAssertEqual(CaptureZoom.limit(deviceMax: 16, position: .back), 10)
        XCTAssertEqual(CaptureZoom.limit(deviceMax: 4, position: .back), 4)
        XCTAssertEqual(CaptureZoom.limit(deviceMax: 0.5, position: .back), 1)
        XCTAssertEqual(CaptureZoom.limit(deviceMax: 16, position: .front), 1)
    }

    func testPinchAndStepsStayWithinOneAndTheLimit() {
        XCTAssertEqual(CaptureZoom.pinched(from: 2, magnification: 1.5, limit: 10), 3)
        XCTAssertEqual(CaptureZoom.pinched(from: 8, magnification: 3, limit: 10), 10)
        XCTAssertEqual(CaptureZoom.pinched(from: 2, magnification: 0.1, limit: 10), 1)
        XCTAssertEqual(CaptureZoom.clamp(.nan, limit: 10), 1)
        XCTAssertEqual(CaptureZoom.stepped(from: 1.4, up: true, limit: 10), 2)
        XCTAssertEqual(CaptureZoom.stepped(from: 1.6, up: false, limit: 10), 1)
        XCTAssertEqual(CaptureZoom.stepped(from: 10, up: true, limit: 10), 10)
        XCTAssertEqual(CaptureZoom.stepped(from: 1, up: false, limit: 10), 1)
    }
}
