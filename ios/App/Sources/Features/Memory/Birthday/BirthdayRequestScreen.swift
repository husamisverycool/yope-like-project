// Surface: birthday.request — composition of Retro components C-34 (card on a blurred backdrop), C-11, C-23, C-05, C-06,
// C-10, C-15, C-27, C-29 in Tribute / VidDay's order (Retro has no birthdays; design/surfaces/birthday.request.md, MERGE
// RM-10). Reference images: references/auto/retro/lazyweb/retro-lazyweb-20260529-paywall.png (PAY, RAW: glass close,
// serif headline + line, plan card with numbered steps and the 60-pt capsule, line under the card),
// references/auto/retro/press/tc-2023-12-retro3.png phone 1 (feature intro), references/auto/vidday/store/vidday-store-01.png
// and references/auto/tribute/mockups/tribute-home-phone-step-1-contribution-page.png (order, mechanics).
import AppData
import DesignSystem
import SwiftUI

/// The private request to add one photo and one line to a member's birthday video: the honoree's photo blurred over the
/// screen (dark in both appearances), their avatar and the serif headline, the invitation, the card (follows the
/// appearance) with "Message ideas" and "Add your photo" — or your contribution — and the due date under it.
/// Full screen, from the push (`AppRoute.birthdayRequest`) or the group screen's row (`BirthdayRequestsEntry`).
@MainActor
struct BirthdayRequestScreen: View {
    let requestID: String
    let groupID: String?
    @State private var model: BirthdayRequestModel
    /// The contribute empty state's "View {group}": this screen closes too, then the group shows.
    @State private var groupToOpen: String?
    @Environment(\.dismiss) private var dismiss

    init(requestID: String, groupID: String?, model: BirthdayRequestModel? = nil) {
        self.requestID = requestID
        self.groupID = groupID
        _model = State(initialValue: model ?? BirthdayRequestModel(requestID: TributeRequestID(requestID), dependencies: .current))
    }

    var body: some View {
        MemoryImageScope { images in
            ZStack {
                backdrop(images)
                content(images)
            }
            .overlay(alignment: .topTrailing) { closeButton }
        }
        .toolbar(.hidden, for: .navigationBar)
        .dsAnimation(ComponentMotion.crossfade, value: model.contribution)
        .task { await model.loadIfNeeded() }
        .sheet(isPresented: $model.showsContribute, onDismiss: {
            if let groupID = groupToOpen {
                groupToOpen = nil
                dismiss()
                MemoryDependencies.current.openGroup(groupID)
            } else {
                Task { await model.reloadContribution() }
            }
        }) {
            BirthdayContributeScreen(requestID: requestID) { groupID in
                groupToOpen = groupID
            }
        }
        .alert(Copy.birthdayRequestRemoveTitle, isPresented: $model.showsRemoveConfirmation) {
            Button(Copy.birthdayRequestRemoveConfirm, role: .destructive) {
                Task { await model.remove() }
            }
            Button(Copy.birthdayRequestRemoveCancel, role: .cancel) {}
        } message: {
            Text(Copy.birthdayRequestRemoveMessage(name: model.honoreeName))
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("birthday.request")
    }

    // MARK: Backdrop and close

    /// The honoree's photo blurred over the whole screen (C-34); no photo, loading or not found →
    /// `color.global.backgroundDeep`.
    @ViewBuilder
    private func backdrop(_ images: any MemoryImageLoading) -> some View {
        Group {
            if model.phase == .open || model.phase == .closed || model.phase == .error || model.phase == .offline,
               let avatar = model.avatarURL {
                BlurredBackdrop(source: images.source(avatar))
            } else {
                Tokens.Colors.globalBackgroundDeep
                    .ignoresSafeArea()
            }
        }
        .environment(\.colorScheme, .dark)
    }

    /// C-11 small glass circle (`size.global.circleButtonSmall`, `color.global.glass`, `icon.global.close`): its right edge
    /// `dimension.birthday.request.close.inset` from the screen edge, its centre `.close.centerY` below the safe-area top.
    private var closeButton: some View {
        CircleButton(
            icon: Tokens.Icons.globalClose, accessibilityLabel: Copy.birthdayRequestA11yClose, style: .glassSmall
        ) {
            dismiss()
        }
        .padding(.trailing, Tokens.Sizes.birthdayRequestCloseInset)
        .padding(.top, Tokens.Sizes.birthdayRequestCloseCenterY - Tokens.Sizes.globalCircleButtonSmall / 2)
        .accessibilitySortPriority(10)
        .accessibilityIdentifier("birthday.request.close")
    }

    // MARK: States

    @ViewBuilder
    private func content(_ images: any MemoryImageLoading) -> some View {
        switch model.phase {
        case .idle, .loading:
            MemoryLoadingIndicator(announcement: Copy.birthdayRequestLoading)
                .environment(\.colorScheme, .dark)
        case .notFound:
            EmptyStateView(title: Copy.birthdayRequestNotFoundTitle)
                .environment(\.colorScheme, .dark)
                .accessibilityIdentifier("birthday.request.notFound")
        case .error:
            MemoryMediaStateBlock(
                title: Copy.birthdayRequestErrorTitle, detail: Copy.birthdayRequestErrorDetail, retryTitle: Copy.birthdayRequestErrorRetry
            ) {
                Task { await model.retry() }
            }
            .environment(\.colorScheme, .dark)
        case .offline:
            MemoryMediaStateBlock(
                title: Copy.birthdayRequestOfflineTitle, detail: Copy.birthdayRequestOffline, retryTitle: Copy.birthdayRequestErrorRetry
            ) {
                Task { await model.retry() }
            }
            .environment(\.colorScheme, .dark)
        case .open, .closed:
            page(images)
        }
    }

    // MARK: Page

    /// Bottom-anchored above the safe-area bottom; scrolls at large text sizes.
    private func page(_ images: any MemoryImageLoading) -> some View {
        GeometryReader { proxy in
            ScrollView {
                MetricStack(alignment: .center) {
                    AvatarView(source: images.source(model.avatarURL), diameter: Tokens.Sizes.globalAvatarProfile)
                        .environment(\.colorScheme, .dark)
                    Text(model.title)
                        .dsTextRole(TextRole.displayMedium)
                        .foregroundStyle(Tokens.Colors.globalTextOnMedia)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Tokens.Sizes.globalButtonMarginH)
                        .accessibilityAddTraits(.isHeader)
                        .accessibilitySortPriority(9)
                        .metricGap(Tokens.Sizes.globalEmptyIconToTitle, from: .bottom, to: .capTop)
                    Text(model.message)
                        .dsTextRole(TextRole.textButton)
                        .foregroundStyle(Tokens.Colors.globalTextOnMedia)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Tokens.Sizes.globalButtonMarginH)
                        .accessibilitySortPriority(8)
                        .metricGap(Tokens.Sizes.birthdayRequestHeadlineToMessage, from: .lastBaseline, to: .capTop)
                    card(images)
                        .padding(.horizontal, Tokens.Sizes.globalButtonMarginH)
                        .accessibilitySortPriority(7)
                        .metricGap(Tokens.Sizes.birthdayRequestMessageToCard, from: .bottom, to: .top)
                    if model.phase == .open {
                        footerLine(model.isOffline ? Copy.birthdayRequestOffline : model.dueText)
                            .metricGap(Tokens.Sizes.birthdayRequestCardToFooter, from: .bottom, to: .top)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: proxy.size.height, alignment: .bottom)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
    }

    /// The due line (`birthday.request.due`, a date — never a countdown): text role `caption`, `color.global.textOnMedia`,
    /// centred. Offline, the line says so instead.
    private func footerLine(_ text: String) -> some View {
        Text(text)
            .dsTextStyle(TextRole.caption)
            .foregroundStyle(Tokens.Colors.globalTextOnMedia)
            .multilineTextAlignment(.center)
            .padding(.horizontal, Tokens.Sizes.globalButtonMarginH)
            .accessibilitySortPriority(1)
            .accessibilityIdentifier("birthday.request.due")
    }

    // MARK: Card (C-34 plan card)

    /// `color.global.surfaceElevated` (follows the appearance), `radius.global.cardLarge`, padding
    /// `size.global.planCardPadding`; a capsule inside sits `size.global.screenMargin` from the card's sides and bottom
    /// (C-34).
    private func card(_ images: any MemoryImageLoading) -> some View {
        let hasCapsule = model.phase == .open && model.contribution == nil
        return Group {
            if model.phase == .closed {
                EmptyStateView(title: Copy.birthdayRequestClosedTitle, detail: Copy.birthdayRequestClosedDetail(name: model.honoreeName))
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier("birthday.request.closed")
            } else if let contribution = model.contribution {
                ownContribution(contribution, images: images)
            } else {
                prompts
            }
        }
        .padding([.top, .horizontal], Tokens.Sizes.globalPlanCardPadding)
        .padding(.bottom, hasCapsule ? Tokens.Sizes.globalScreenMargin : Tokens.Sizes.globalPlanCardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Tokens.Colors.globalSurfaceElevated, in: DSShape.rounded(Tokens.Radii.globalCardLarge))
        .accessibilityElement(children: .contain)
    }

    /// The card title (`fontSize.birthday.request.cardTitle` / `fontWeight.birthday.request.cardTitle`, the platform UI
    /// face), scaled with the 24-pt display role's text style (`layout.global.textStyleMap.displaySmall`).
    private static let cardTitle = DSTextStyle(
        family: Tokens.Fonts.globalFamily,
        size: Tokens.FontSizes.birthdayRequestCardTitle,
        weight: Tokens.FontWeights.fontWeightBirthdayRequestCardTitle,
        relativeTo: Font.TextStyle(tokenName: Tokens.Layouts.GlobalTextStyleMap.displaySmall)
    )

    /// "Message ideas", the grey line, two numbered prompt rows and "Add your photo".
    private var prompts: some View {
        MetricStack {
            Text(Copy.birthdayRequestPromptsTitle)
                .dsTextRole(Self.cardTitle)
                .foregroundStyle(Tokens.Colors.globalTextPrimary)
                .accessibilityAddTraits(.isHeader)
            Text(Copy.birthdayRequestCardDetail)
                .dsTextRole(TextRole.body)
                .foregroundStyle(Tokens.Colors.globalTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .metricGap(Tokens.Sizes.birthdayRequestCardTitleToDetail, from: .lastBaseline, to: .capTop)
            promptRow(1, Copy.birthdayRequestPromptAppreciate(name: model.honoreeName))
                .metricGap(Tokens.Sizes.birthdayRequestCardBlockGap, from: .bottom, to: .top)
            promptRow(2, Copy.birthdayRequestPromptImpact(name: model.honoreeName))
                .metricGap(Tokens.Sizes.birthdayRequestCardRowPitch, from: .lastBaseline, to: .firstBaseline)
            PrimaryButton(Copy.birthdayRequestCta) {
                model.addPhoto()
            }
            // The capsule sits `size.global.screenMargin` from the card's sides (the card pads `planCardPadding`).
            .padding(.horizontal, Tokens.Sizes.globalScreenMargin - Tokens.Sizes.globalPlanCardPadding)
            .accessibilityIdentifier("birthday.request.cta")
            .metricGap(Tokens.Sizes.birthdayRequestCardBlockGap, from: .bottom, to: .top)
        }
    }

    /// A numbered prompt: the marker circle (`dimension.birthday.request.card.marker`, `color.global.accent`, the number in
    /// text role `badge`, `color.global.onAccent`) centred on the first line's cap middle, `.markerGap`, then the prompt
    /// (text role `textButton`, `color.global.textPrimary`) wrapping under its own leading edge.
    private func promptRow(_ number: Int, _ text: String) -> some View {
        Text(text)
            .dsTextRole(TextRole.textButton)
            .foregroundStyle(Tokens.Colors.globalTextPrimary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.leading, Tokens.Sizes.birthdayRequestCardMarker + Tokens.Sizes.birthdayRequestCardMarkerGap)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(alignment: Alignment(horizontal: .leading, vertical: .capMiddle)) {
                Text(MemoryFormat.number(number))
                    .dsTextStyle(TextRole.badge)
                    .foregroundStyle(Tokens.Colors.globalOnAccent)
                    .frame(width: Tokens.Sizes.birthdayRequestCardMarker, height: Tokens.Sizes.birthdayRequestCardMarker)
                    .background(Tokens.Colors.globalAccent, in: Circle())
                    .accessibilityHidden(true)
            }
    }

    /// After contributing: "You added a photo", your photo (C-15 thumbnail) with your line beside it, then "Change photo"
    /// (C-06 outline) and "Remove" (C-10) side by side, `size.global.pillGap` apart.
    private func ownContribution(_ contribution: BirthdayRequestModel.OwnContribution, images: any MemoryImageLoading) -> some View {
        MetricStack {
            Text(Copy.birthdayRequestContributedTitle)
                .dsTextRole(Self.cardTitle)
                .foregroundStyle(Tokens.Colors.globalTextPrimary)
                .accessibilityAddTraits(.isHeader)
            HStack(alignment: .top, spacing: Tokens.Sizes.globalRowThumbGap) {
                PhotoView(source: images.source(contribution.imageURL))
                    .frame(width: Tokens.Sizes.globalRowThumbWidth, height: Tokens.Sizes.globalRowThumbHeight)
                    .clipShape(DSShape.rounded(Tokens.Radii.globalThumbnail))
                    .accessibilityHidden(true)
                Text(contribution.line)
                    .dsTextStyle(TextRole.body)
                    .foregroundStyle(Tokens.Colors.globalTextPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .metricGap(Tokens.Sizes.birthdayRequestCardTitleToDetail, from: .lastBaseline, to: .top)
            VStack(alignment: .leading) {
                HStack(spacing: Tokens.Sizes.globalPillGap) {
                    CapsuleButton(Copy.birthdayRequestContributedChange, style: .outline, isEnabled: !model.isRemoving) {
                        model.addPhoto()
                    }
                    .accessibilityIdentifier("birthday.request.change")
                    DestructiveButton(Copy.birthdayRequestContributedRemove) {
                        model.requestRemove()
                    }
                    .disabled(model.isRemoving)
                    .accessibilityIdentifier("birthday.request.remove")
                }
                if let inline = model.inline {
                    Text(inline == .offline ? Copy.birthdayRequestOffline : Copy.birthdayRequestErrorDetail)
                        .dsTextStyle(TextRole.meta)
                        .foregroundStyle(Tokens.Colors.globalTextSecondary)
                }
            }
            .metricGap(Tokens.Sizes.birthdayRequestCardBlockGap, from: .bottom, to: .top)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("birthday.request.own")
    }
}
