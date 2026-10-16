// Shared component — C-05 primary capsule (full width, 60 pt) (design/components.md), replacing Yope's lime button.
// Evidence: LAND (y2032–2211), ST-03 ('Send Postcard'), PAY ('Claim'), TC-R3 phone 2 (disabled, dark); RV §3.4, §4 #6.
import DesignSystem
import SwiftUI

/// Full-width capsule with a centred label (text role `button`, Sentence case from copy).
///
/// - `.page`: fill `color.global.accent` (#000000 / #FFFFFF), label `color.global.onAccent`.
/// - `.media` (on media / colour surfaces: the landing in dark, the postcard composer, a card on a blurred backdrop):
///   fill `color.global.surfaceLight`, label `color.global.onSurfaceLight`.
/// - Disabled (captured in dark only): fill `color.global.controlRaised`, label `color.global.onAccent`; light disabled
///   was not captured (Gap) and uses the same tokens.
/// - Busy: the label is replaced by the platform activity indicator in the label colour (PLATFORM; Retro's busy button
///   was not captured — Gap); taps are ignored while busy.
///
/// Height `size.global.buttonHeight` (a minimum, so the label can grow with Dynamic Type), shape
/// `radius.global.capsule` (`radius.global.button` = height ÷ 2). The button fills the proposed width; callers apply
/// the side margin `size.global.buttonMarginH` (or `size.global.screenMargin` inside a card, PAY — no token of its own,
/// see the component report). The label's side inset for wrapped text was not measured — platform padding.
/// Pressed: platform default (iOS plays no tap haptic). Accessibility: button, label = the visible text.
struct PrimaryButton: View {
    enum Height {
        /// `size.global.buttonHeight` (a form or screen bottom).
        case form
        /// `size.global.buttonHeightSheet` (the bottom of a sheet; the same 60 pt in Retro).
        case sheet

        var value: CGFloat {
            switch self {
            case .form: return Tokens.Sizes.globalButtonHeight
            case .sheet: return Tokens.Sizes.globalButtonHeightSheet
            }
        }
    }

    enum Surface {
        case page
        case media
    }

    let title: String
    var height: Height = .form
    var surface: Surface = .page
    var isEnabled: Bool = true
    var isBusy: Bool = false
    let action: () -> Void

    init(
        _ title: String,
        height: Height = .form,
        surface: Surface = .page,
        isEnabled: Bool = true,
        isBusy: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.height = height
        self.surface = surface
        self.isEnabled = isEnabled
        self.isBusy = isBusy
        self.action = action
    }

    var body: some View {
        Button {
            guard !isBusy else { return }
            action()
        } label: {
            ZStack {
                Text(title)
                    .dsTextStyle(TextRole.button)
                    .multilineTextAlignment(.center)
                    .opacity(isBusy ? 0 : 1)
                if isBusy {
                    ProgressView()
                        .tint(labelColor)
                }
            }
            .foregroundStyle(labelColor)
            .padding(.horizontal)
            .frame(maxWidth: .infinity, minHeight: height.value)
            .background(fillColor, in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityLabel(Text(title))
        .accessibilityAddTraits(isBusy ? .updatesFrequently : [])
    }

    private var fillColor: Color {
        guard isEnabled else { return Tokens.Colors.globalControlRaised }
        switch surface {
        case .page: return Tokens.Colors.globalAccent
        case .media: return Tokens.Colors.globalSurfaceLight
        }
    }

    private var labelColor: Color {
        guard isEnabled else { return Tokens.Colors.globalOnAccent }
        switch surface {
        case .page: return Tokens.Colors.globalOnAccent
        case .media: return Tokens.Colors.globalOnSurfaceLight
        }
    }
}
