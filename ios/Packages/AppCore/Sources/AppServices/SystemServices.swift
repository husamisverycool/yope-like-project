#if os(iOS)
import AppModels
import DesignSystem
import Foundation
import UIKit
import WidgetKit

/// Plays `DSHaptic` tokens with prepared UIKit generators (lower latency than creating one per tap).
@MainActor
public final class HapticsService {
    private var impactGenerators: [UIImpactFeedbackGenerator.FeedbackStyle: UIImpactFeedbackGenerator] = [:]
    private lazy var selectionGenerator = UISelectionFeedbackGenerator()
    private lazy var notificationGenerator = UINotificationFeedbackGenerator()

    public init() {}

    /// Readies the hardware for a haptic expected shortly (e.g. when the shutter appears).
    public func prepare(_ haptic: DSHaptic) {
        switch Self.kind(of: haptic) {
        case let .impact(style): impactGenerator(style).prepare()
        case .selection: selectionGenerator.prepare()
        case .notification: notificationGenerator.prepare()
        }
    }

    public func play(_ haptic: DSHaptic) {
        switch Self.kind(of: haptic) {
        case let .impact(style): impactGenerator(style).impactOccurred()
        case .selection: selectionGenerator.selectionChanged()
        case let .notification(type): notificationGenerator.notificationOccurred(type)
        }
    }

    private enum Kind {
        case impact(UIImpactFeedbackGenerator.FeedbackStyle)
        case selection
        case notification(UINotificationFeedbackGenerator.FeedbackType)
    }

    private static func kind(of haptic: DSHaptic) -> Kind {
        switch haptic {
        case .impactLight: return .impact(.light)
        case .impactMedium: return .impact(.medium)
        case .impactHeavy: return .impact(.heavy)
        case .impactSoft: return .impact(.soft)
        case .impactRigid: return .impact(.rigid)
        case .selection: return .selection
        case .notificationSuccess: return .notification(.success)
        case .notificationWarning: return .notification(.warning)
        case .notificationError: return .notification(.error)
        }
    }

    private func impactGenerator(_ style: UIImpactFeedbackGenerator.FeedbackStyle) -> UIImpactFeedbackGenerator {
        if let generator = impactGenerators[style] { return generator }
        let generator = UIImpactFeedbackGenerator(style: style)
        impactGenerators[style] = generator
        return generator
    }
}

/// WidgetKit reloads. Reloads requested while the app is in the foreground do not count against
/// the widget's daily refresh budget.
public enum WidgetReloader {
    public struct InstalledWidget: Hashable, Sendable {
        public let kind: String
        public let family: String
    }

    public static func reloadGroupWidgets() {
        WidgetCenter.shared.reloadTimelines(ofKind: WidgetKind.groupPhoto)
    }

    public static func reloadAll() {
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Widgets the user has placed (for the guided add-the-widget step, `onboarding.widget`).
    public static func installedWidgets() async -> [InstalledWidget] {
        await withCheckedContinuation { (continuation: CheckedContinuation<[InstalledWidget], Never>) in
            WidgetCenter.shared.getCurrentConfigurations { result in
                let widgets = (try? result.get()) ?? []
                continuation.resume(returning: widgets.map { InstalledWidget(kind: $0.kind, family: String(describing: $0.family)) })
            }
        }
    }
}
#endif
