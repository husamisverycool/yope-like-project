// Value types referenced by generated `Tokens.Shadows`, `Tokens.Haptics` and `Tokens.Fonts`.
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Shadow

/// A shadow token (`Tokens.Shadows.*`).
public struct DSShadow: Hashable, Sendable {
    public var color: Color
    public var radius: CGFloat
    public var x: CGFloat
    public var y: CGFloat

    public init(color: Color, radius: CGFloat, x: CGFloat, y: CGFloat) {
        self.color = color
        self.radius = radius
        self.x = x
        self.y = y
    }
}

extension View {
    public func dsShadow(_ shadow: DSShadow) -> some View {
        self.shadow(color: shadow.color, radius: shadow.radius, x: shadow.x, y: shadow.y)
    }
}

// MARK: - Haptics

/// A haptic token (`Tokens.Haptics.*`). Case names follow the token's `ios` value
/// (`impact.light` → `impactLight`).
public enum DSHaptic: String, Hashable, Sendable, CaseIterable {
    case impactLight
    case impactMedium
    case impactHeavy
    case impactSoft
    case impactRigid
    case selection
    case notificationSuccess
    case notificationWarning
    case notificationError

    /// For SwiftUI's `.sensoryFeedback(_:trigger:)`.
    public var sensoryFeedback: SensoryFeedback {
        switch self {
        case .impactLight: return .impact(weight: .light)
        case .impactMedium: return .impact(weight: .medium)
        case .impactHeavy: return .impact(weight: .heavy)
        case .impactSoft: return .impact(flexibility: .soft)
        case .impactRigid: return .impact(flexibility: .rigid)
        case .selection: return .selection
        case .notificationSuccess: return .success
        case .notificationWarning: return .warning
        case .notificationError: return .error
        }
    }

    #if canImport(UIKit) && os(iOS)
    /// Plays the haptic once with a UIKit feedback generator (no-op where the hardware has none).
    @MainActor
    public func play() {
        switch self {
        case .impactLight: UIImpactFeedbackGenerator(style: .light).impactOccurred()
        case .impactMedium: UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        case .impactHeavy: UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        case .impactSoft: UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        case .impactRigid: UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
        case .selection: UISelectionFeedbackGenerator().selectionChanged()
        case .notificationSuccess: UINotificationFeedbackGenerator().notificationOccurred(.success)
        case .notificationWarning: UINotificationFeedbackGenerator().notificationOccurred(.warning)
        case .notificationError: UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }
    #endif
}

extension View {
    /// Plays `haptic` whenever `trigger` changes.
    public func dsHaptic<T: Equatable>(_ haptic: DSHaptic, trigger: T) -> some View {
        sensoryFeedback(haptic.sensoryFeedback, trigger: trigger)
    }
}

// MARK: - Fonts

/// A font family token (`Tokens.Fonts.*`): the platform font (SF Pro) or a bundled custom font.
public enum DSFontFamily: Hashable, Sendable {
    case system
    /// The platform serif (New York), level PLATFORM: fills a serif role until a licensed face is bundled.
    case systemSerif
    case custom(String)

    /// A font of this family at a fixed point size. Use `DSTextStyle` / `.dsTextStyle` for text
    /// that follows Dynamic Type.
    public func font(size: CGFloat, weight: Font.Weight) -> Font {
        switch self {
        case .system:
            return .system(size: size, weight: weight) // provenance-ok: size and weight are token parameters
        case .systemSerif:
            return .system(size: size, weight: weight, design: .serif) // provenance-ok: size and weight are token parameters
        case let .custom(name):
            return .custom(name, fixedSize: size).weight(weight)
        }
    }
}

// MARK: - Appearance

extension Color {
    /// A colour token with a value per appearance (`{light, dark}` in design/tokens): resolves against the
    /// environment's colour scheme / trait collection, so it follows the system Light / Dark setting.
    public init(light: Color, dark: Color) {
        #if canImport(UIKit)
        self.init(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
        #else
        self = light
        #endif
    }
}
