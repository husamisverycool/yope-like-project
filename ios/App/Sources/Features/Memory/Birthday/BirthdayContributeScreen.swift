// Surface: birthday.contribute — reference: Tribute / VidDay.
// Reference images: references/auto/tribute/web/tribute-web-testimonials-upload-step1-info.png
// (+ tribute-web-testimonials-upload-step1.computed-styles.json), references/auto/vidday/frames/vidday-tour-t102-phone.png;
// https://www.tribute.co/help/creators/how-do-i-upload-a-video/, https://help.vidday.com/how-to-record-a-video-with-a-phone/
// (design/surfaces/birthday.contribute.md).
import AppData
import DesignSystem
import Foundation
import SwiftUI

/// Pick one photo you posted or are in, write one line, send. Full screen over `birthday.request`
/// (✕ on steps 1 and 3, ‹ on step 2); the steps are native pushes in the flow's own navigation stack.
@MainActor
struct BirthdayContributeScreen: View {
    let requestID: String
    @State private var model: BirthdayContributeModel
    private let onOpenGroup: ((String) -> Void)?
    @Environment(\.dismiss) private var dismiss

    /// - Parameter onOpenGroup: the empty state's "open group" action; nil = go to the group screen
    ///   on the main stack (`MemoryDependencies.openGroup`).
    init(requestID: String, model: BirthdayContributeModel? = nil, onOpenGroup: ((String) -> Void)? = nil) {
        self.requestID = requestID
        _model = State(initialValue: model ?? BirthdayContributeModel(requestID: TributeRequestID(requestID), dependencies: .current))
        self.onOpenGroup = onOpenGroup
    }

    var body: some View {
        NavigationStack(path: $model.path) {
            ContributeStep(model: model, step: 1) {
                ContributePhotoStep(model: model)
            }
            .navigationDestination(for: BirthdayContributeModel.Step.self) { step in
                switch step {
                case .message:
                    ContributeStep(model: model, step: 2) {
                        ContributeMessageStep(model: model)
                    }
                case .done:
                    ContributeStep(model: model, step: 3) {
                        ContributeDoneStep(model: model)
                    }
                }
            }
        }
        .task { await model.loadIfNeeded() }
        .onDisappear { model.stopListening() }
        .onChange(of: model.isFinished) { _, finished in
            guard finished else { return }
            if model.openGroupRequested, let groupID = model.groupID {
                if let onOpenGroup {
                    onOpenGroup(groupID.rawValue)
                } else {
                    MemoryDependencies.current.openGroup(groupID.rawValue)
                }
            }
            dismiss()
        }
        .accessibilityIdentifier("birthday.contribute")
    }
}

// MARK: - Step frame (header + stepper)

private struct ContributeStep<Content: View>: View {
    let model: BirthdayContributeModel
    let step: Int
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                if step == 2 {
                    MemoryHeaderCircle(icon: Tokens.Icons.globalBack, label: Copy.groupsScreenBackAccessibilityLabel) {
                        model.retake()
                    }
                    .accessibilityIdentifier("birthday.contribute.back")
                } else {
                    MemoryHeaderCircle(icon: Tokens.Icons.globalClose, label: Copy.birthdayContributeA11yClose) {
                        model.finish()
                    }
                    .accessibilityIdentifier("birthday.contribute.close")
                }
                Spacer()
            }
            .padding(.horizontal, Tokens.Sizes.globalHeaderInset)
            ContributeStepper(current: step)
                .padding(.horizontal, Tokens.Sizes.birthdayContributeMargin)
            if model.phase == .closed {
                MemoryStateMessage(title: Copy.birthdayContributeClosed(name: model.honoreeName))
                    .padding(.horizontal, Tokens.Sizes.birthdayContributeMargin)
                    .padding(.top, Tokens.Sizes.birthdayContributeHeadingGap)
                Spacer(minLength: 0)
            } else {
                content()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Tokens.Colors.globalBackgroundDeep.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
    }
}

/// Three circles (`layout.birthday.contribute.stepper`): the first and last `edgeInset` inside the
/// margins, the middle one centred; captions `labelGap` below. One accessibility element.
struct ContributeStepper: View {
    let current: Int

    private var captions: [String] {
        [Copy.birthdayContributeStepPhoto, Copy.birthdayContributeStepMessage, Copy.birthdayContributeStepDone]
    }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(Array(captions.enumerated()), id: \.offset) { index, caption in
                if index > 0 { Spacer(minLength: 0) }
                step(number: index + 1, caption: caption)
            }
        }
        .padding(.horizontal, ContributeStepperMetrics.edgeInset)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(captions.indices.contains(current - 1) ? captions[current - 1] : "")
        .accessibilityIdentifier("birthday.contribute.stepper")
    }

    private func step(number: Int, caption: String) -> some View {
        let active = number == current
        let diameter = Tokens.Sizes.birthdayContributeStepperCircle
        return VStack(spacing: Tokens.Layouts.BirthdayContributeStepper.labelGap) {
            Text(String(number))
                .dsTextStyle(BirthdayType.stepperNumber)
                .foregroundStyle(active ? Tokens.Colors.globalTextPrimary : Tokens.Colors.birthdayContributeStepperInactiveLabel)
                .frame(width: diameter, height: diameter)
                .background(
                    active ? Tokens.Colors.birthdayContributeStepperActive : Tokens.Colors.birthdayContributeStepperInactive,
                    in: Circle()
                )
            Text(caption)
                .dsTextStyle(BirthdayType.stepperLabel(active: active))
                .foregroundStyle(active ? Tokens.Colors.globalTextPrimary : Tokens.Colors.birthdayContributeStepperInactiveLabel)
                .fixedSize()
                .frame(width: diameter)
        }
    }
}

enum ContributeStepperMetrics {
    /// The "11 pt inside the margin" of `layout.birthday.contribute.stepper.distribution`. The token
    /// carries this measured value only inside its text, so it is read from there.
    static let edgeInset: CGFloat = {
        let scanner = Scanner(string: Tokens.Layouts.BirthdayContributeStepper.distribution)
        _ = scanner.scanUpToCharacters(from: .decimalDigits)
        return CGFloat(scanner.scanDouble() ?? 0)
    }()
}

// MARK: - Step 1: Photo

private struct ContributePhotoStep: View {
    let model: BirthdayContributeModel

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 0) {
                    Text(Copy.birthdayContributeGreeting(name: model.honoreeName))
                        .dsTextStyle(BirthdayType.contributeHeading)
                        .foregroundStyle(Tokens.Colors.globalTextPrimary)
                        .accessibilityAddTraits(.isHeader)
                        .padding(.top, Tokens.Sizes.birthdayContributeHeadingGap)
                    Text(Copy.birthdayContributeThanks)
                        .dsTextStyle(BirthdayType.contributeSubheading)
                        .foregroundStyle(Tokens.Colors.globalTextPrimary.opacity(Tokens.Opacities.birthdayContributeSubheading))
                        .padding(.top, Tokens.Sizes.birthdayContributeSubheadingGap)
                    if model.inline == .notEligible {
                        inlineText(Copy.birthdayContributeNotEligible)
                            .padding(.top, Tokens.Sizes.birthdayContributeGroupGap)
                    }
                    stateContent
                        .padding(.top, Tokens.Sizes.birthdayContributeGroupGap)
                }
                .multilineTextAlignment(.center)
                .padding(.horizontal, Tokens.Sizes.birthdayContributeMargin)
            }
            .scrollBounceBehavior(.basedOnSize)
            if model.phase == .loaded {
                MemoryFilledButton.contributePrimary(Copy.birthdayContributeReviewUse) {
                    model.usePhoto()
                }
                .disabled(!model.canUsePhoto)
                .accessibilityIdentifier("birthday.contribute.use")
                .padding(.horizontal, Tokens.Sizes.birthdayContributeMargin)
                .padding(.bottom, Tokens.Sizes.birthdayContributeMargin)
            }
        }
    }

    @ViewBuilder
    private var stateContent: some View {
        switch model.phase {
        case .idle, .loading:
            MemoryLoadingIndicator(text: Copy.birthdayContributeLoading)
        case .empty:
            MemoryStateMessage(
                title: Copy.birthdayContributePickerEmptyTitle(group: model.groupName),
                detail: Copy.birthdayContributePickerEmptyDetail,
                actionTitle: Copy.birthdayContributePickerEmptyAction
            ) {
                model.openGroup()
            }
        case .error:
            MemoryStateMessage(
                title: Copy.birthdayContributeErrorTitle, detail: Copy.birthdayContributeErrorDetail,
                actionTitle: Copy.birthdayContributeErrorRetry
            ) {
                Task { await model.retry() }
            }
        case .offline:
            VStack {
                inlineText(Copy.birthdayContributeOffline)
                MemoryLightPill(title: Copy.birthdayContributeErrorRetry) {
                    Task { await model.retry() }
                }
            }
        case .loaded:
            ContributePhotoGrid(model: model)
        case .closed:
            EmptyView()
        }
    }
}

/// The eligible photos in the Yope wall grid (`walls.mine.count.gridColumns`,
/// `walls.mine.dimension.gridGap`, `walls.mine.aspectRatio.gridTile`) with `radius.global.photo`
/// corners and the global selection check in each cell's top-right corner.
private struct ContributePhotoGrid: View {
    let model: BirthdayContributeModel

    private var columns: [GridItem] {
        Array(
            repeating: GridItem(.flexible(), spacing: Tokens.Sizes.wallsMineDimensionGridGap),
            count: Int(Tokens.Counts.wallsMineCountGridColumns)
        )
    }

    var body: some View {
        LazyVGrid(columns: columns, spacing: Tokens.Sizes.wallsMineDimensionGridGap) {
            ForEach(Array(model.photos.enumerated()), id: \.element.id) { index, photo in
                let selected = model.selectedID == photo.id
                Button {
                    model.select(photo.id)
                } label: {
                    MemoryRemoteImage(url: photo.thumbURL)
                        .aspectRatio(Tokens.AspectRatios.wallsMineAspectRatioGridTile, contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: Tokens.Radii.globalPhoto))
                        .overlay(alignment: .topTrailing) {
                            Image(systemName: selected ? Tokens.Icons.globalCheck : Tokens.Icons.globalUncheck)
                                .resizable()
                                .scaledToFit()
                                .foregroundStyle(selected ? Tokens.Colors.globalSelection : Tokens.Colors.globalTextPrimary)
                                .frame(width: Tokens.Sizes.globalCheckCircle, height: Tokens.Sizes.globalCheckCircle)
                                // No inset token for the check: the grid's own gap is used.
                                .padding(Tokens.Sizes.wallsMineDimensionGridGap)
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Copy.birthdayContributeA11yPhoto(date: ContributeFormat.spokenDate(photo.createdAt)))
                .accessibilityAddTraits(selected ? [.isSelected] : [])
                .accessibilityIdentifier("birthday.contribute.photo.\(index)")
            }
        }
    }
}

enum ContributeFormat {
    /// `{date}` of `birthday.contribute.a11y.photo`: the platform's long date (no format token).
    static func spokenDate(_ date: Date, locale: Locale = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

// MARK: - Step 2: Message

private struct ContributeMessageStep: View {
    @Bindable var model: BirthdayContributeModel
    @FocusState private var fieldFocused: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if let photo = model.selectedPhoto {
                    MemoryRemoteImage(url: photo.displayURL)
                        .aspectRatio(photo.aspectRatio ?? OnThisDayMasonry.unknownAspectRatio, contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: Tokens.Radii.globalPhoto))
                        .accessibilityHidden(true)
                        .padding(.top, Tokens.Sizes.birthdayContributeGroupGap)
                }
                Text(Copy.birthdayContributeLineLabel)
                    .dsTextStyle(BirthdayType.contributeLabel)
                    .foregroundStyle(Tokens.Colors.globalTextPrimary)
                    .padding(.top, Tokens.Sizes.birthdayContributeGroupGap)
                    .accessibilityHidden(true)
                TextField(text: $model.line, prompt: nil, axis: .vertical) {
                    Text(Copy.birthdayContributeLineLabel)
                }
                .focused($fieldFocused)
                .submitLabel(.done)
                .dsTextStyle(BirthdayType.contributeInput)
                .foregroundStyle(Tokens.Colors.birthdayContributeInputText)
                .padding(.horizontal, Tokens.Sizes.birthdayContributeLabelGap)
                .frame(maxWidth: .infinity, minHeight: Tokens.Sizes.birthdayContributeInputHeight, alignment: .leading)
                .background(Tokens.Colors.birthdayContributeInputFill, in: RoundedRectangle(cornerRadius: Tokens.Radii.birthdayContributeInput))
                .padding(.top, Tokens.Sizes.birthdayContributeLabelGap)
                .accessibilityIdentifier("birthday.contribute.line")
                .onChange(of: model.line) { _, value in
                    // One line of meaning: the return key ends the entry instead of adding a line.
                    if value.contains("\n") {
                        model.line = value.replacingOccurrences(of: "\n", with: "")
                        fieldFocused = false
                    }
                    // UI limit once `layout.birthday.contribute.lineMax` is sourced (no visible counter).
                    if let limit = MemoryBlocked.contributeLineMax, model.line.count > limit {
                        model.line = String(model.line.prefix(limit))
                    }
                }
                MemoryMessageIdeas(honoreeName: model.honoreeName)
                    .padding(.top, Tokens.Sizes.birthdayContributeGroupGap)
                MemoryFilledButton.contributePrimary(
                    model.inline == .error ? Copy.birthdayContributeErrorRetry : Copy.birthdayContributeSubmit,
                    isWorking: model.isSending
                ) {
                    fieldFocused = false
                    Task { await model.submit() }
                }
                .disabled(!model.canSubmit)
                .accessibilityIdentifier("birthday.contribute.submit")
                .padding(.top, Tokens.Sizes.birthdayContributeButtonGap)
                inlineLines
                MemoryFilledButton(
                    title: Copy.birthdayContributeReviewRetake, style: BirthdayType.contributeButton,
                    height: Tokens.Sizes.birthdayContributeButtonHeight, radius: Tokens.Radii.birthdayContributeButton,
                    fill: Tokens.Colors.globalSurfaceLight, labelColor: Tokens.Colors.globalOnSurfaceLight
                ) {
                    model.retake()
                }
                .disabled(model.isSending)
                .accessibilityIdentifier("birthday.contribute.retake")
                .padding(.top, Tokens.Sizes.birthdayContributeGroupGap)
            }
            .padding(.horizontal, Tokens.Sizes.birthdayContributeMargin)
            .padding(.bottom, Tokens.Sizes.birthdayContributeMargin)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    @ViewBuilder
    private var inlineLines: some View {
        switch model.inline {
        case .offline?:
            inlineText(Copy.birthdayContributeOffline)
                .padding(.top, Tokens.Sizes.birthdayContributeLabelGap)
        case .error?:
            VStack(alignment: .leading) {
                Text(Copy.birthdayContributeErrorTitle)
                    .dsTextStyle(MemoryType.emptyTitle)
                    .foregroundStyle(Tokens.Colors.globalTextPrimary)
                inlineText(Copy.birthdayContributeErrorDetail)
            }
            .padding(.top, Tokens.Sizes.birthdayContributeLabelGap)
        case .notEligible?, nil:
            EmptyView()
        }
    }
}

// MARK: - Step 3: Done

private struct ContributeDoneStep: View {
    let model: BirthdayContributeModel

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: Tokens.Sizes.birthdayContributeGroupGap) {
                    Text(Copy.birthdayContributeDoneTitle)
                        .dsTextStyle(BirthdayType.contributeHeading)
                        .foregroundStyle(Tokens.Colors.globalTextPrimary)
                        .multilineTextAlignment(.center)
                        .accessibilityAddTraits(.isHeader)
                    if let photo = model.selectedPhoto {
                        MemoryRemoteImage(url: photo.displayURL)
                            .aspectRatio(photo.aspectRatio ?? OnThisDayMasonry.unknownAspectRatio, contentMode: .fit)
                            .clipShape(RoundedRectangle(cornerRadius: Tokens.Radii.globalPhoto))
                            .accessibilityHidden(true)
                    }
                    Text(model.trimmedLine)
                        .dsTextStyle(BirthdayType.message)
                        .foregroundStyle(Tokens.Colors.globalTextPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.top, Tokens.Sizes.birthdayContributeHeadingGap)
                .padding(.horizontal, Tokens.Sizes.birthdayContributeMargin)
            }
            .scrollBounceBehavior(.basedOnSize)
            // While the optimistic send is unanswered the button shows the platform activity indicator.
            MemoryFilledButton.contributePrimary(Copy.birthdayContributeDoneButton, isWorking: model.isSending) {
                model.finish()
            }
            .disabled(model.isSending)
            .accessibilityIdentifier("birthday.contribute.done")
            .padding(.horizontal, Tokens.Sizes.birthdayContributeMargin)
            .padding(.bottom, Tokens.Sizes.birthdayContributeMargin)
        }
    }
}

/// Inline line (`fontSize.global.listSubtitle`, `color.global.textSecondary`).
@MainActor
private func inlineText(_ text: String) -> some View {
    Text(text)
        .dsTextStyle(MemoryType.listSubtitle)
        .foregroundStyle(Tokens.Colors.globalTextSecondary)
}
