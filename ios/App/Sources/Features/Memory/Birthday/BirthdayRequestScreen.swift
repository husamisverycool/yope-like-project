// Surface: birthday.request — reference: Tribute / VidDay.
// Reference images: references/auto/tribute/web/tribute-web-testimonials-contribution-page-viewport.png,
// tribute-web-ayejaye-contribution-page-viewport.png, references/auto/tribute/mockups/tribute-home-phone-step-1-contribution-page.png,
// references/auto/vidday/store/vidday-store-01.png, references/auto/vidday/frames/vidday-tour-t064-phone.png,
// -t036-phone.png, -t042-phone.png, -t072-phone.png (design/surfaces/birthday.request.md).
// Replaces the container ios/App/Sources/Screens/BirthdayRequestScreen.swift (`AppRoute.birthdayRequest`).
import AppData
import DesignSystem
import SwiftUI

/// The private request to add one photo and one line to a member's birthday video.
///
/// Opened from the push (`AppRoute.birthdayRequest`, pushed by the shell) or from
/// `BirthdayRequestsEntry` on the group screen (a `.sheet` with `.presentationDetents([.large])`).
@MainActor
struct BirthdayRequestScreen: View {
    let requestID: String
    let groupID: String?
    @State private var model: BirthdayRequestModel
    /// The contribute empty state's "open group": this screen closes too, then the group shows.
    @State private var groupToOpen: String?
    @Environment(\.dismiss) private var dismiss

    init(requestID: String, groupID: String?, model: BirthdayRequestModel? = nil) {
        self.requestID = requestID
        self.groupID = groupID
        _model = State(initialValue: model ?? BirthdayRequestModel(requestID: TributeRequestID(requestID), dependencies: .current))
    }

    var body: some View {
        GeometryReader { proxy in
            let safeTop = proxy.safeAreaInsets.top
            ZStack(alignment: .topLeading) {
                Tokens.Colors.globalBackgroundDeep
                switch model.phase {
                case .notFound:
                    centred(MemoryStateMessage(title: Copy.birthdayRequestNotFoundTitle, detail: Copy.birthdayRequestNotFoundDetail))
                case .error:
                    centred(MemoryStateMessage(
                        title: Copy.birthdayRequestErrorTitle, detail: Copy.birthdayRequestErrorDetail,
                        actionTitle: Copy.birthdayRequestErrorRetry
                    ) {
                        Task { await model.retry() }
                    })
                default:
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            hero(safeTop: safeTop)
                            if model.isOffline {
                                offlineLine
                            }
                            belowHero
                        }
                        .padding(.bottom, proxy.safeAreaInsets.bottom + Tokens.Sizes.birthdayRequestMargin)
                    }
                    .scrollBounceBehavior(.basedOnSize)
                }
                closeButton
                    .padding(.top, safeTop)
                    .padding(.leading, Tokens.Sizes.globalHeaderInset)
            }
            .ignoresSafeArea()
        }
        .toolbar(.hidden, for: .navigationBar)
        .task { await model.loadIfNeeded() }
        .fullScreenCover(isPresented: $model.showsContribute, onDismiss: {
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
        .accessibilityIdentifier("birthday.request")
    }

    private var closeButton: some View {
        MemoryHeaderCircle(icon: Tokens.Icons.globalClose, label: Copy.birthdayRequestA11yClose) {
            dismiss()
        }
        .accessibilityIdentifier("birthday.request.close")
        .accessibilitySortPriority(1)
    }

    private func centred(_ content: some View) -> some View {
        content
            .padding(.horizontal, Tokens.Sizes.birthdayRequestMargin)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Hero

    /// Honoree photo at `opacity.birthday.request.hero.image` over black, title, due line, message.
    /// Its height (`dimension.birthday.request.hero.height`) is a minimum: it grows with the text.
    private func hero(safeTop: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if model.phase != .loading {
                Text(model.title)
                    .dsTextStyle(BirthdayType.requestTitle)
                    .foregroundStyle(Tokens.Colors.globalTextPrimary)
                    .accessibilityAddTraits(.isHeader)
                Text(model.dueText)
                    .dsTextStyle(BirthdayType.message)
                    .foregroundStyle(Tokens.Colors.globalTextPrimary.opacity(Tokens.Opacities.birthdayRequestMessage))
                if model.phase != .closed {
                    Text(model.message)
                        .dsTextStyle(BirthdayType.message)
                        .foregroundStyle(Tokens.Colors.globalTextPrimary.opacity(Tokens.Opacities.birthdayRequestMessage))
                        .padding(.top, Tokens.Sizes.birthdayRequestMessageGap)
                }
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        // Title top from the hero top, kept clear of the status bar and the close circle.
        .padding(.top, max(Tokens.Sizes.birthdayRequestTitleTop, safeTop + Tokens.Sizes.globalHeaderButton))
        .padding(.horizontal, Tokens.Sizes.birthdayRequestMargin)
        .frame(maxWidth: .infinity, minHeight: Tokens.Sizes.birthdayRequestHeroHeight, alignment: .topLeading)
        .background {
            ZStack {
                Tokens.Colors.globalBackgroundDeep
                MemoryRemoteImage(url: model.heroURL)
                    .opacity(Tokens.Opacities.birthdayRequestHeroImage)
                    .accessibilityHidden(true)
            }
        }
    }

    // MARK: Below the hero

    @ViewBuilder
    private var belowHero: some View {
        switch model.phase {
        case .idle, .loading:
            MemoryLoadingIndicator(text: Copy.birthdayRequestLoading)
                .frame(maxWidth: .infinity)
                .padding(.top, Tokens.Sizes.birthdayRequestCtaGap)
        case .offline:
            offlineLine
        case .closed:
            MemoryStateMessage(title: Copy.birthdayRequestClosedTitle, detail: Copy.birthdayRequestClosedDetail(name: model.honoreeName))
                .padding(.horizontal, Tokens.Sizes.birthdayRequestMargin)
                .padding(.top, Tokens.Sizes.birthdayRequestCtaGap)
        case .open:
            VStack(alignment: .leading, spacing: 0) {
                if let contribution = model.contribution {
                    ownContribution(contribution)
                } else {
                    MemoryFilledButton(
                        title: Copy.birthdayRequestCta, style: BirthdayType.cta, height: Tokens.Sizes.birthdayRequestCtaHeight,
                        radius: Tokens.Radii.birthdayRequestCta, fill: Tokens.Colors.globalAccent, labelColor: Tokens.Colors.globalOnAccent
                    ) {
                        model.addPhoto()
                    }
                    .accessibilityIdentifier("birthday.request.cta")
                }
                MemoryMessageIdeas(honoreeName: model.honoreeName)
                    .padding(.top, Tokens.Sizes.birthdayRequestPromptsGap)
            }
            .padding(.horizontal, Tokens.Sizes.birthdayRequestMargin)
            .padding(.top, Tokens.Sizes.birthdayRequestCtaGap)
        case .notFound, .error:
            EmptyView()
        }
    }

    /// `birthday.request.offline` under the hero (`fontSize.global.listSubtitle`, `color.global.textSecondary`).
    private var offlineLine: some View {
        Text(Copy.birthdayRequestOffline)
            .dsTextStyle(MemoryType.listSubtitle)
            .foregroundStyle(Tokens.Colors.globalTextSecondary)
            .padding(.horizontal, Tokens.Sizes.birthdayRequestMargin)
            .padding(.top, Tokens.Sizes.birthdayRequestCtaGap)
    }

    /// The member's own block: heading, photo (`radius.global.photo`, content width), line, then
    /// "Retake" and "Remove" (Tribute secondary buttons).
    private func ownContribution(_ contribution: BirthdayRequestModel.OwnContribution) -> some View {
        VStack(alignment: .leading) {
            Text(Copy.birthdayRequestContributedTitle)
                .dsTextStyle(BirthdayType.contributeLabel)
                .foregroundStyle(Tokens.Colors.globalTextPrimary)
                .accessibilityAddTraits(.isHeader)
            MemoryRemoteImage(url: contribution.imageURL)
                .aspectRatio(contribution.aspectRatio ?? OnThisDayMasonry.unknownAspectRatio, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: Tokens.Radii.globalPhoto))
                .accessibilityHidden(true)
            Text(contribution.line)
                .dsTextStyle(BirthdayType.message)
                .foregroundStyle(Tokens.Colors.globalTextPrimary)
            VStack(spacing: Tokens.Sizes.birthdayTributeButtonGap) {
                MemoryFilledButton.tributeSecondary(Copy.birthdayRequestContributedChange) {
                    model.addPhoto()
                }
                .accessibilityIdentifier("birthday.request.change")
                MemoryFilledButton.tributeSecondary(Copy.birthdayRequestContributedRemove) {
                    Task { await model.remove() }
                }
                .disabled(model.isRemoving)
                .accessibilityIdentifier("birthday.request.remove")
            }
            if let inline = model.inline {
                Text(inline == .offline ? Copy.birthdayRequestOffline : Copy.birthdayRequestErrorDetail)
                    .dsTextStyle(MemoryType.listSubtitle)
                    .foregroundStyle(Tokens.Colors.globalTextSecondary)
            }
        }
        .accessibilityIdentifier("birthday.request.own")
    }
}
