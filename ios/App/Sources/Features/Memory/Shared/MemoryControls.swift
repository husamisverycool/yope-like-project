// Controls shared by the memory surfaces, each built only from the tokens its spec names: the
// foundations roles (header circle, Yope primary / light pill, empty-state layout, toast) plus
// Tribute's buttons and the Message Ideas block. Built here because ios/App/Sources/Components/ did
// not exist when this pass started; they follow the same tokens as the shared components that the
// account pass added meanwhile (HeaderCircleButton, LightPill, EmptyStateView, ToastView) and can be
// swapped for them once those are final.
import AppData
import DesignSystem
import SwiftUI
import UIKit

// MARK: - Header circle

/// Header circle icon button (`size.global.headerButton`, fill `color.global.controlOnDeep`,
/// glyph `color.global.textPrimary`). The glyph keeps the platform's default symbol size
/// (no glyph-size token for header circles).
struct MemoryHeaderCircle: View {
    let icon: String
    let label: String
    var fill: Color = Tokens.Colors.globalControlOnDeep
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .foregroundStyle(Tokens.Colors.globalTextPrimary)
                .frame(width: Tokens.Sizes.globalHeaderButton, height: Tokens.Sizes.globalHeaderButton)
                .background(fill, in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

// MARK: - Buttons

/// The look of a full-width filled button (also used as a `ShareLink` label).
struct MemoryFilledLabel: View {
    let title: String
    let style: DSTextStyle
    let height: CGFloat
    let radius: CGFloat?
    let fill: Color
    let labelColor: Color
    var icon: String? = nil
    var isWorking = false

    var body: some View {
        ZStack {
            if isWorking {
                // `easing.global.native` activityIndicator in place of the label.
                ProgressView()
                    .tint(labelColor)
            } else if let icon {
                Label {
                    Text(title)
                } icon: {
                    Image(systemName: icon)
                }
                .labelStyle(.titleAndIcon)
            } else {
                Text(title)
            }
        }
        .dsTextStyle(style)
        .foregroundStyle(labelColor)
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity, minHeight: height)
        .background(fill, in: shape)
        .contentShape(shape)
    }

    private var shape: AnyShape {
        if let radius {
            AnyShape(RoundedRectangle(cornerRadius: radius))
        } else {
            AnyShape(Capsule()) // radius.global.capsule
        }
    }
}

/// A full-width filled button. Disabled appearance is the platform's (`.plain` button style).
struct MemoryFilledButton: View {
    let label: MemoryFilledLabel
    let action: () -> Void

    init(
        title: String, style: DSTextStyle, height: CGFloat, radius: CGFloat?, fill: Color, labelColor: Color,
        icon: String? = nil, isWorking: Bool = false, action: @escaping () -> Void
    ) {
        label = MemoryFilledLabel(
            title: title, style: style, height: height, radius: radius, fill: fill, labelColor: labelColor,
            icon: icon, isWorking: isWorking
        )
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            label
        }
        .buttonStyle(.plain)
    }
}

extension MemoryFilledButton {
    /// Yope lime primary (`color.global.accent`, `color.global.onAccent`, text role `button`,
    /// `size.global.buttonHeight`, `radius.global.button`).
    static func yopePrimary(_ title: String, isWorking: Bool = false, action: @escaping () -> Void) -> MemoryFilledButton {
        MemoryFilledButton(
            title: title, style: MemoryType.button, height: Tokens.Sizes.globalButtonHeight, radius: Tokens.Radii.globalButton,
            fill: Tokens.Colors.globalAccent, labelColor: Tokens.Colors.globalOnAccent, isWorking: isWorking, action: action
        )
    }

    /// Yope white secondary pill (`color.global.surfaceLight`, `color.global.onSurfaceLight`,
    /// `radius.global.capsule`, height `size.global.buttonHeight`).
    static func yopeLightPill(_ title: String, action: @escaping () -> Void) -> MemoryFilledButton {
        MemoryFilledButton(
            title: title, style: MemoryType.button, height: Tokens.Sizes.globalButtonHeight, radius: nil,
            fill: Tokens.Colors.globalSurfaceLight, labelColor: Tokens.Colors.globalOnSurfaceLight, action: action
        )
    }

    /// Tribute's secondary button (`dimension.birthday.tribute.button.height`,
    /// `radius.birthday.tribute.button`, `color.global.surfaceLight`, label
    /// `color.birthday.tribute.button.label`, `fontSize/fontWeight.birthday.tribute.button`).
    static func tributeSecondary(_ title: String, icon: String? = nil, action: @escaping () -> Void) -> MemoryFilledButton {
        MemoryFilledButton(
            title: title, style: BirthdayType.tributeButton, height: Tokens.Sizes.birthdayTributeButtonHeight,
            radius: Tokens.Radii.birthdayTributeButton, fill: Tokens.Colors.globalSurfaceLight,
            labelColor: Tokens.Colors.birthdayTributeButtonLabel, icon: icon, action: action
        )
    }

    /// Tribute's step button in the app accent (`dimension.birthday.contribute.button.height`,
    /// `radius.birthday.contribute.button`, `fontSize/fontWeight.birthday.contribute.button`).
    static func contributePrimary(_ title: String, isWorking: Bool = false, action: @escaping () -> Void) -> MemoryFilledButton {
        MemoryFilledButton(
            title: title, style: BirthdayType.contributeButton, height: Tokens.Sizes.birthdayContributeButtonHeight,
            radius: Tokens.Radii.birthdayContributeButton, fill: Tokens.Colors.globalAccent,
            labelColor: Tokens.Colors.globalOnAccent, isWorking: isWorking, action: action
        )
    }
}

/// Yope white pill that hugs its label (retry / action in empty and error states):
/// `color.global.surfaceLight`, `color.global.onSurfaceLight`, `radius.global.capsule`, height
/// `size.global.buttonHeight`; the label is inset by the capsule's corner radius (height / 2).
struct MemoryLightPill: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .dsTextStyle(MemoryType.button)
                .foregroundStyle(Tokens.Colors.globalOnSurfaceLight)
                .padding(.horizontal, Tokens.Sizes.globalButtonHeight / 2)
                .frame(minHeight: Tokens.Sizes.globalButtonHeight)
                .background(Tokens.Colors.globalSurfaceLight, in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - States

/// Yope empty / error layout: text roles `emptyTitle` (`color.global.textPrimary`) and
/// `emptyDetail` (italic, `color.global.textSecondary`), centred, with an optional light pill.
struct MemoryStateMessage: View {
    let title: String
    var detail: String? = nil
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack {
            Text(title)
                .dsTextStyle(MemoryType.emptyTitle)
                .foregroundStyle(Tokens.Colors.globalTextPrimary)
                .accessibilityAddTraits(.isHeader)
            if let detail {
                Text(detail)
                    .dsTextStyle(MemoryType.emptyDetail)
                    .italic()
                    .foregroundStyle(Tokens.Colors.globalTextSecondary)
            }
            if let actionTitle, let action {
                MemoryLightPill(title: actionTitle, action: action)
            }
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
    }
}

/// Platform activity indicator (`easing.global.native` activityIndicator) with an optional
/// loading word (`fontSize.global.listSubtitle`, `color.global.textSecondary`).
struct MemoryLoadingIndicator: View {
    var text: String? = nil

    var body: some View {
        VStack {
            ProgressView()
                .tint(Tokens.Colors.globalTextSecondary)
            if let text {
                Text(text)
                    .dsTextStyle(MemoryType.listSubtitle)
                    .foregroundStyle(Tokens.Colors.globalTextSecondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Toast

/// A confirmation / error line shown in the foundations toast.
struct MemoryToastMessage: Equatable, Identifiable {
    let id = UUID()
    let text: String
    /// `icon.global.checkmark` for confirmations ("saved to your photos"); none for errors.
    var showsCheckmark = false
}

extension View {
    /// Shows the foundations toast (lime pill: `color.global.accent` / `color.global.onAccent`,
    /// `icon.global.checkmark`, text role `button`, `radius.global.capsule`, full width minus
    /// `size.global.screenMargin`, top under the status bar; metrics of the measured Yope toast
    /// `camera.sendto.layout.toast`), as the shared `ToastView` does. It stays for the toast dwell
    /// (`Tokens.Durations.safetyBlockDurationToast`, same as `ToastCenter`), or until it is tapped or
    /// replaced, and its text is also posted as a VoiceOver announcement.
    func memoryToast(_ message: Binding<MemoryToastMessage?>) -> some View {
        modifier(MemoryToastModifier(message: message))
    }
}

private struct MemoryToastModifier: ViewModifier {
    @Binding var message: MemoryToastMessage?

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if let message {
                    toast(message)
                        .dsTransition(.move(edge: .top).combined(with: .opacity))
                        .id(message.id)
                }
            }
            .dsAnimation(.spring(Tokens.Springs.globalPlatformDefaultIos), value: message?.id)
            .onChange(of: message?.id) { _, id in
                guard id != nil, let text = message?.text else { return }
                AccessibilityNotification.Announcement(text).post()
            }
            .task(id: message?.id) {
                guard message != nil else { return }
                try? await Task.sleep(for: .seconds(Tokens.Durations.safetyBlockDurationToast))
                if !Task.isCancelled { message = nil }
            }
    }

    private func toast(_ message: MemoryToastMessage) -> some View {
        HStack(spacing: Tokens.Layouts.CameraSendtoLayoutToast.glyphToText) {
            if message.showsCheckmark {
                Image(systemName: Tokens.Icons.globalCheckmark)
                    .resizable()
                    .scaledToFit()
                    .frame(height: Tokens.Layouts.CameraSendtoLayoutToast.glyph)
                    .accessibilityHidden(true)
            }
            Text(message.text)
                .dsTextStyle(MemoryType.button)
            Spacer(minLength: 0)
        }
        .foregroundStyle(Tokens.Colors.globalOnAccent)
        .padding(.horizontal, Tokens.Layouts.CameraSendtoLayoutToast.glyphInset)
        .frame(maxWidth: .infinity, minHeight: Tokens.Layouts.CameraSendtoLayoutToast.height)
        .background(Tokens.Colors.globalAccent, in: Capsule())
        .padding(.horizontal, Tokens.Sizes.globalScreenMargin)
        .contentShape(Capsule())
        .onTapGesture { self.message = nil }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isStaticText)
    }
}

// MARK: - Message Ideas (birthday.request, birthday.contribute)

/// Tribute's prompts block with VidDay's "Message Ideas": header bar
/// (`color.birthday.request.prompts.header`, top corners `radius.birthday.request.prompts`,
/// `dimension.birthday.request.prompts.headerHeight` / `.headerPadding`) and two bulleted prompts.
struct MemoryMessageIdeas: View {
    let honoreeName: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(Copy.birthdayRequestPromptsTitle)
                .dsTextStyle(BirthdayType.promptsHeader)
                .foregroundStyle(Tokens.Colors.globalTextPrimary)
                .padding(.horizontal, Tokens.Sizes.birthdayRequestPromptsHeaderPadding)
                .frame(maxWidth: .infinity, minHeight: Tokens.Sizes.birthdayRequestPromptsHeaderHeight, alignment: .leading)
                .background(
                    Tokens.Colors.birthdayRequestPromptsHeader,
                    in: UnevenRoundedRectangle(
                        topLeadingRadius: Tokens.Radii.birthdayRequestPrompts,
                        topTrailingRadius: Tokens.Radii.birthdayRequestPrompts
                    )
                )
                .accessibilityAddTraits(.isHeader)
            VStack(alignment: .leading, spacing: Tokens.Sizes.birthdayRequestPromptGap) {
                prompt(Copy.birthdayRequestPromptAppreciate(name: honoreeName))
                prompt(Copy.birthdayRequestPromptImpact(name: honoreeName))
            }
            .padding(.top, Tokens.Sizes.birthdayRequestPromptTop)
        }
    }

    private func prompt(_ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            // The list bullet sits between the block edge and the text (`dimension.birthday.request.prompt.indent`).
            Text(verbatim: "\u{2022}") // provenance-ok: list bullet glyph of the bulleted prompts (not copy)
                .frame(width: Tokens.Sizes.birthdayRequestPromptIndent)
                .accessibilityHidden(true)
            Text(text)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .dsTextStyle(BirthdayType.prompt)
        .foregroundStyle(Tokens.Colors.globalTextPrimary)
    }
}

// MARK: - Birthday text roles

enum BirthdayType {
    private static let family = Tokens.Fonts.birthday

    static var requestTitle: DSTextStyle {
        MemoryType.style(family, size: Tokens.FontSizes.birthdayRequestTitle, weight: Tokens.FontWeights.fontWeightBirthdayRequestTitle,
                         relativeTo: Tokens.Layouts.BirthdayRequestTextStyleMap.title, lineHeight: Tokens.LineHeights.birthdayRequestTitle)
    }

    static var message: DSTextStyle {
        MemoryType.style(family, size: Tokens.FontSizes.birthdayRequestMessage,
                         relativeTo: Tokens.Layouts.BirthdayRequestTextStyleMap.message, lineHeight: Tokens.LineHeights.birthdayRequestMessage)
    }

    static var cta: DSTextStyle {
        MemoryType.style(family, size: Tokens.FontSizes.birthdayRequestCta, weight: Tokens.FontWeights.fontWeightBirthdayRequestCta,
                         relativeTo: Tokens.Layouts.BirthdayRequestTextStyleMap.cta)
    }

    static var promptsHeader: DSTextStyle {
        MemoryType.style(family, size: Tokens.FontSizes.birthdayRequestPromptsHeader,
                         weight: Tokens.FontWeights.fontWeightBirthdayRequestPromptsHeader,
                         relativeTo: Tokens.Layouts.BirthdayRequestTextStyleMap.promptsHeader)
    }

    static var prompt: DSTextStyle {
        MemoryType.style(family, size: Tokens.FontSizes.birthdayRequestPrompt,
                         relativeTo: Tokens.Layouts.BirthdayRequestTextStyleMap.prompt, lineHeight: Tokens.LineHeights.birthdayRequestPrompt)
    }

    /// Tribute's 14-pt secondary button label → `subheadline` (spec: MERGE F-13).
    static var tributeButton: DSTextStyle {
        MemoryType.style(family, size: Tokens.FontSizes.birthdayTributeButton, weight: Tokens.FontWeights.fontWeightBirthdayTributeButton,
                         relativeTo: Tokens.Layouts.GlobalTextStyleMap.button)
    }

    static var contributeHeading: DSTextStyle {
        MemoryType.style(family, size: Tokens.FontSizes.birthdayContributeHeading,
                         weight: Tokens.FontWeights.fontWeightBirthdayContributeHeading,
                         relativeTo: Tokens.Layouts.BirthdayContributeTextStyleMap.heading)
    }

    static var contributeSubheading: DSTextStyle {
        MemoryType.style(family, size: Tokens.FontSizes.birthdayContributeSubheading,
                         relativeTo: Tokens.Layouts.BirthdayContributeTextStyleMap.subheading)
    }

    static var contributeLabel: DSTextStyle {
        MemoryType.style(family, size: Tokens.FontSizes.birthdayContributeLabel, weight: Tokens.FontWeights.fontWeightBirthdayContributeLabel,
                         relativeTo: Tokens.Layouts.BirthdayContributeTextStyleMap.label)
    }

    static var contributeInput: DSTextStyle {
        MemoryType.style(family, size: Tokens.FontSizes.birthdayContributeInput,
                         relativeTo: Tokens.Layouts.BirthdayContributeTextStyleMap.input)
    }

    static var contributeButton: DSTextStyle {
        MemoryType.style(family, size: Tokens.FontSizes.birthdayContributeButton, weight: Tokens.FontWeights.fontWeightBirthdayContributeButton,
                         relativeTo: Tokens.Layouts.BirthdayContributeTextStyleMap.button)
    }

    static var stepperNumber: DSTextStyle {
        MemoryType.style(family, size: Tokens.FontSizes.birthdayContributeStepperNumber,
                         weight: Tokens.FontWeights.fontWeightBirthdayContributeStepperNumber,
                         relativeTo: Tokens.Layouts.BirthdayContributeTextStyleMap.stepperNumber)
    }

    static func stepperLabel(active: Bool) -> DSTextStyle {
        MemoryType.style(family, size: Tokens.FontSizes.birthdayContributeStepperLabel,
                         weight: active ? Tokens.FontWeights.fontWeightBirthdayContributeStepperLabelActive
                             : Tokens.FontWeights.fontWeightBirthdayContributeStepperLabel,
                         relativeTo: Tokens.Layouts.BirthdayContributeTextStyleMap.stepperLabel)
    }
}
