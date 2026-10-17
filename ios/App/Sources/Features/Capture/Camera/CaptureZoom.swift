// Surface: camera.capture — pinch to zoom on the viewfinder (`camera.capture.layout.zoom`, design/surfaces/camera.capture.md).
import AppServices
import CoreGraphics
import DesignSystem
import Foundation

/// The zoom arithmetic of camera.capture: back camera only, from `camera.capture.layout.zoom.min` up to the smaller of
/// the device's largest zoom and `camera.capture.layout.zoom.max`.
enum CaptureZoom {
    static var minimum: CGFloat { Tokens.Layouts.CameraCaptureLayoutZoom.min }

    /// The largest factor offered for the camera at `position` (the front camera does not zoom).
    static func limit(deviceMax: CGFloat, position: CameraPosition) -> CGFloat {
        switch position {
        case .back: return max(minimum, min(deviceMax, Tokens.Layouts.CameraCaptureLayoutZoom.max))
        case .front: return minimum
        }
    }

    static func clamp(_ factor: CGFloat, limit: CGFloat) -> CGFloat {
        guard factor.isFinite else { return minimum }
        return min(max(factor, minimum), max(minimum, limit))
    }

    /// A pinch: the factor at the pinch start times the pinch scale.
    static func pinched(from start: CGFloat, magnification: CGFloat, limit: CGFloat) -> CGFloat {
        clamp(start * magnification, limit: limit)
    }

    /// The accessibility increment / decrement: the next whole step up or down.
    static func stepped(from factor: CGFloat, up: Bool, limit: CGFloat) -> CGFloat {
        let step = Tokens.Layouts.CameraCaptureLayoutZoom.step
        let whole = (factor / step).rounded() * step
        let next: CGFloat
        if up {
            next = whole > factor ? whole : whole + step
        } else {
            next = whole < factor ? whole : whole - step
        }
        return clamp(next, limit: limit)
    }

    /// `camera.capture.a11y.zoomValue`'s {factor}: at most one decimal, in the locale's digits.
    static func spoken(_ factor: CGFloat) -> String {
        Double(factor).formatted(.number.precision(.fractionLength(0...1)))
    }
}
