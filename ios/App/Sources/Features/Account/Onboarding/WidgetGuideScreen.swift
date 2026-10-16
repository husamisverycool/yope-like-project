// Surface: onboarding.widget — guided add-the-widget step. Visual reference: Retro Settings → Widgets
// (references/auto/retro/video/ig-DJXvmqRv2_N-referrals-sheet-f042-059.png, VID-SET: rounded widget thumbnails with
// their names) and Retro's widget art (references/auto/retro/apk/widget_preview_friends.webp, 22-dp corners); step text
// from Locket's public add-widget help (https://help.locket.com/en/articles/7914857). Composition of C-33
// (page title), the widget preview, C-11 numbered circles, C-05 (design/surfaces/onboarding.widget.md).
import DesignSystem
import SwiftUI

/// What the preview tile shows: the newest photo from the person's groups and its sender (nil: the empty tile).
struct WidgetPreviewContent: Equatable {
    var photo: PhotoSource?
    var firstName: String?
}

/// The steps and a "Next" capsule that always moves on (no check, no gate, no "did you add it?"). Inside onboarding
/// there is no back; opened from Settings (settings.root → Widgets) the C-02 chevron returns there.
struct WidgetGuideScreen: View {
    var preview: WidgetPreviewContent?
    /// From Settings: back to settings.root; nil inside onboarding.
    var onBack: (() -> Void)?
    /// Onboarding's "Next"; nil from Settings (the page has no capsule there: back is the way out).
    var onContinue: (() -> Void)?

    init(preview: WidgetPreviewContent? = nil, onBack: (() -> Void)? = nil, onContinue: (() -> Void)? = nil) {
        self.preview = preview
        self.onBack = onBack
        self.onContinue = onContinue
    }

    /// The iOS steps (`onboarding.widget.step.ios.1` … `.5`); step 4 names the app.
    static var steps: [String] {
        [
            Copy.onboardingWidgetStepIos1,
            Copy.onboardingWidgetStepIos2,
            Copy.onboardingWidgetStepIos3,
            Copy.onboardingWidgetStepIos4,
            Copy.onboardingWidgetStepIos5,
        ]
    }

    var body: some View {
        SignUpLayout(
            back: onBack.map { FormBackButton(accessibilityLabel: Copy.authCodeBackAccessibilityLabel, identifier: "onboarding.widget.back", action: $0) },
            title: Copy.onboardingWidgetTitle,
            explanation: Copy.onboardingWidgetDetail
        ) {
            MetricStack {
                WidgetPreviewTile(content: preview)
                    .frame(maxWidth: .infinity)
                Text(Copy.widgetHomeSmallGalleryName)
                    .dsTextRole(TextRole.meta)
                    .foregroundStyle(Tokens.Colors.globalTextSecondary)
                    .frame(maxWidth: .infinity)
                    .metricGap(Tokens.Sizes.globalSectionHeaderToContent, from: .bottom, to: .capTop)
                stepList
                    .metricGap(Tokens.Sizes.globalTitleToContent, from: .lastBaseline, to: .top)
            }
            .padding(.horizontal, Tokens.Sizes.globalScreenMargin)
        } bottom: {
            if let onContinue {
                PrimaryButton(Copy.onboardingWidgetContinue, action: onContinue)
                    .accessibilityIdentifier("onboarding.widget.continue")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("onboarding.widget")
    }

    /// One row per step (`size.global.sectionHeaderToContent` apart), then "You're done!" and the arrival note.
    private var stepList: some View {
        VStack(alignment: .leading, spacing: Tokens.Sizes.globalSectionHeaderToContent) {
            ForEach(Array(Self.steps.enumerated()), id: \.offset) { index, step in
                WidgetStepRow(number: index + 1, text: step)
            }
            Text(Copy.onboardingWidgetDone)
                .dsTextStyle(TextRole.listTitle)
                .foregroundStyle(Tokens.Colors.globalTextPrimary)
            Text(Copy.widgetArrivalHelpDelay)
                .dsTextStyle(TextRole.meta)
                .foregroundStyle(Tokens.Colors.globalTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// A step: the numeral (text role `listTitle`, `color.global.textPrimary`) in a `size.global.circleButton` circle filled
/// `color.global.control` (C-11 on the page), then the step (text role `body`, `color.global.textPrimary`)
/// `size.global.rowThumbGap` after the circle. Read as one element: "Step {number}" with the text as its value.
struct WidgetStepRow: View {
    let number: Int
    let text: String

    var body: some View {
        HStack(spacing: Tokens.Sizes.globalRowThumbGap) {
            Text(String(number))
                .dsTextStyle(TextRole.listTitle)
                .monospacedDigit()
                .foregroundStyle(Tokens.Colors.globalTextPrimary)
                .frame(width: Tokens.Sizes.globalCircleButton, height: Tokens.Sizes.globalCircleButton)
                .background(Tokens.Colors.globalControl, in: Circle())
            Text(text)
                .dsTextStyle(TextRole.body)
                .foregroundStyle(Tokens.Colors.globalTextPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(Copy.onboardingWidgetStepNumberAccessibilityLabel(number: String(number))))
        .accessibilityValue(Text(text))
    }
}

/// The widget preview: `onboarding.widget.size.preview` square, corners `onboarding.widget.radius.preview` (continuous),
/// centred: the photo aspect-fill under `layout.global.photoScrim` with the sender's first name (text role `listTitle`,
/// `color.global.textOnMedia`) at the bottom trailing corner (Retro's widget art: the name stack bottom-right, inset
/// `size.global.badgeInset` as the card badge — Retro's own inset was not measured); no photo yet: `color.global.control`
/// with `icon.global.gallery` in `color.global.textSecondary`. The photo fades in (`duration.global.fade`). One image
/// for VoiceOver (`onboarding.widget.preview.accessibilityLabel`).
struct WidgetPreviewTile: View {
    let content: WidgetPreviewContent?

    private static let fade = DSAnimation.timing(duration: Tokens.Durations.globalFade, easing: Tokens.Easings.globalStandard)

    var body: some View {
        ZStack {
            Tokens.Colors.globalControl
            if let photo = content?.photo {
                PhotoView(source: photo)
                    .overlay { PhotoScrim() }
                    .overlay(alignment: .bottomTrailing) {
                        if let name = content?.firstName {
                            Text(name)
                                .dsTextStyle(TextRole.listTitle)
                                .foregroundStyle(Tokens.Colors.globalTextOnMedia)
                                .lineLimit(1)
                                .padding(Tokens.Sizes.globalBadgeInset)
                        }
                    }
                    .transition(.opacity)
            } else {
                Glyph(Tokens.Icons.globalGallery)
                    .foregroundStyle(Tokens.Colors.globalTextSecondary)
            }
        }
        .frame(width: Tokens.Sizes.onboardingWidgetSizePreview, height: Tokens.Sizes.onboardingWidgetSizePreview)
        .clipShape(DSShape.rounded(Tokens.Radii.onboardingWidgetRadiusPreview))
        .dsAnimation(Self.fade, value: content?.photo)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(Copy.onboardingWidgetPreviewAccessibilityLabel))
        .accessibilityAddTraits(.isImage)
    }
}
