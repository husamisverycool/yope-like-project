// Motion primitives referenced by generated `Tokens.Easings` / `Tokens.Springs` /
// `Tokens.Durations`, plus Reduce-Motion-aware helpers that apply them. No values live here:
// every duration, curve and spring comes from a token.
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// An easing curve token (`Tokens.Easings.*`). Named cases map to the platform's curves; the
/// control points of `cubicBezier` come from the token file.
public enum DSEasing: Hashable, Sendable {
    case linear
    case easeIn
    case easeOut
    case easeInOut
    /// Control points (x1, y1, x2, y2), as in CSS `cubic-bezier()`.
    case cubicBezier(Double, Double, Double, Double)

    /// A timing-curve animation with this easing over `duration` seconds (`Tokens.Durations.*`).
    public func animation(duration: TimeInterval) -> Animation {
        switch self {
        case .linear: return .linear(duration: duration) // provenance-ok: token easing name mapped to its platform curve
        case .easeIn: return .easeIn(duration: duration) // provenance-ok: token easing name mapped to its platform curve
        case .easeOut: return .easeOut(duration: duration) // provenance-ok: token easing name mapped to its platform curve
        case .easeInOut: return .easeInOut(duration: duration) // provenance-ok: token easing name mapped to its platform curve
        case let .cubicBezier(x1, y1, x2, y2): return .timingCurve(x1, y1, x2, y2, duration: duration)
        }
    }

    /// The same curve as a `UnitCurve`, for driving progress values outside an `Animation`.
    public var unitCurve: UnitCurve {
        switch self {
        case .linear: return .linear // provenance-ok: token easing name mapped to its platform curve
        case .easeIn: return .easeIn // provenance-ok: token easing name mapped to its platform curve
        case .easeOut: return .easeOut // provenance-ok: token easing name mapped to its platform curve
        case .easeInOut: return .easeInOut // provenance-ok: token easing name mapped to its platform curve
        case let .cubicBezier(x1, y1, x2, y2):
            return .bezier(startControlPoint: UnitPoint(x: x1, y: y1), endControlPoint: UnitPoint(x: x2, y: y2))
        }
    }
}

/// A spring token (`Tokens.Springs.*`) in SwiftUI's response / damping-fraction terms.
public struct DSSpring: Hashable, Sendable {
    public var response: Double
    public var dampingFraction: Double

    public init(response: Double, dampingFraction: Double) {
        self.response = response
        self.dampingFraction = dampingFraction
    }

    public var animation: Animation {
        .spring(response: response, dampingFraction: dampingFraction)
    }

    /// The same response with critical damping: settles without overshoot. Used in place of
    /// this spring when Reduce Motion is on (bouncing is motion the setting asks to avoid).
    public var withoutBounce: DSSpring {
        DSSpring(response: response, dampingFraction: 1) // provenance-ok: 1 = critical damping (physics constant), Reduce Motion substitute
    }
}

/// An animation built from tokens: a duration with an easing, or a spring.
public enum DSAnimation: Hashable, Sendable {
    case timing(duration: TimeInterval, easing: DSEasing)
    case spring(DSSpring)

    public var animation: Animation {
        switch self {
        case let .timing(duration, easing): return easing.animation(duration: duration)
        case let .spring(spring): return spring.animation
        }
    }

    /// The animation to use when Reduce Motion is on: timing curves are kept (they carry
    /// cross-fades), springs lose their bounce.
    public var reducedMotion: DSAnimation {
        switch self {
        case .timing: return self
        case let .spring(spring): return .spring(spring.withoutBounce)
        }
    }

    public func resolved(reduceMotion: Bool) -> Animation {
        (reduceMotion ? reducedMotion : self).animation
    }
}

/// `withAnimation` with a token animation, honoring the system Reduce Motion setting.
///
/// Under Reduce Motion the body still animates (cross-fades stay), springs lose their bounce,
/// and views that move should use `.dsMotion` / `.dsTransition`, which drop the movement.
@MainActor
public func withDSAnimation<Result>(_ animation: DSAnimation?, _ body: () throws -> Result) rethrows -> Result {
    try withAnimation(animation?.resolved(reduceMotion: DSAccessibility.isReduceMotionEnabled), body)
}

public enum DSAccessibility {
    @MainActor
    public static var isReduceMotionEnabled: Bool {
        #if canImport(UIKit)
        return UIAccessibility.isReduceMotionEnabled
        #else
        return false
        #endif
    }
}

extension View {
    /// `.animation(_:value:)` with a token animation; under Reduce Motion springs lose their bounce.
    public func dsAnimation<V: Equatable>(_ animation: DSAnimation, value: V) -> some View {
        modifier(DSValueAnimationModifier(animation: animation, value: value))
    }

    /// Animates a view's opacity, offset and scale with a token animation. When
    /// `accessibilityReduceMotion` is on, the offset and scale are dropped (the view stays in
    /// place at its natural size) and only the opacity animates.
    public func dsMotion(_ animation: DSAnimation, opacity: Double, offset: CGSize = .zero, scale: CGFloat = 1) -> some View {
        modifier(DSMotionModifier(animation: animation, opacity: opacity, offset: offset, scale: scale))
    }

    /// Insertion/removal transition that becomes a plain cross-fade under Reduce Motion.
    public func dsTransition(_ transition: AnyTransition) -> some View {
        modifier(DSTransitionModifier(transition: transition))
    }
}

struct DSValueAnimationModifier<V: Equatable>: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let animation: DSAnimation
    let value: V

    func body(content: Content) -> some View {
        content.animation(animation.resolved(reduceMotion: reduceMotion), value: value)
    }
}

struct DSMotionModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let animation: DSAnimation
    let opacity: Double
    let offset: CGSize
    let scale: CGFloat

    func body(content: Content) -> some View {
        let moves = !reduceMotion
        content
            .animation(animation.resolved(reduceMotion: reduceMotion)) { view in
                view.opacity(opacity)
            }
            .animation(moves ? animation.animation : nil) { view in
                view
                    .scaleEffect(moves ? scale : 1)
                    .offset(moves ? offset : .zero)
            }
    }
}

struct DSTransitionModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let transition: AnyTransition

    func body(content: Content) -> some View {
        content.transition(reduceMotion ? .opacity : transition)
    }
}
