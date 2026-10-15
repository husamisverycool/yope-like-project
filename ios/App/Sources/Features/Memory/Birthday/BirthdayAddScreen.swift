// Surface: birthday.add — reference: Yope onboarding voice (no Yope birthday screen exists).
// Reference images: references/auto/yope/frames/a-chuongxetank-7694968408424582452-t7.73-posted-toast-contacts-card.png,
// references/auto/yope/frames/a-virgi-7686278541255642390-t31.23-signup-es.png,
// references/auto/yope/frames/a-itsmthuyope-7644974799302823175-t45.23-new-group-empty.png (design/surfaces/birthday.add.md).
import AppData
import DesignSystem
import SwiftUI

/// Add (or manage) your birthday for tributes. Opened from the settings "birthday" row
/// (`MemoryRoute.birthdayAdd`); never shown by the app on its own.
///
/// - Parameter onFinish: called once when the screen closes after adding (`.added`) or with
///   "maybe later" / ✕ (`.dismissed`). The spec's "added" toast cannot be shown here before the
///   screen closes (the toast dwell time is BLOCKED), so a presenter may show it.
@MainActor
struct BirthdayAddScreen: View {
    @State private var model: BirthdayAddModel
    private let onFinish: ((BirthdayAddModel.Outcome) -> Void)?
    @Environment(\.dismiss) private var dismiss

    init(model: BirthdayAddModel? = nil, onFinish: ((BirthdayAddModel.Outcome) -> Void)? = nil) {
        _model = State(initialValue: model ?? BirthdayAddModel(dependencies: .current))
        self.onFinish = onFinish
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                content
                    .padding(.horizontal, Tokens.Sizes.globalButtonMarginH)
            }
            .scrollBounceBehavior(.basedOnSize)
            buttons
                .padding(.horizontal, Tokens.Sizes.globalButtonMarginH)
                .padding(.bottom, Tokens.Sizes.globalButtonMarginH)
        }
        .background(Tokens.Colors.globalBackgroundDeep.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .memoryToast($model.toast)
        .task { await model.loadIfNeeded() }
        .onChange(of: model.outcome) { _, outcome in
            guard let outcome else { return }
            if outcome == .added {
                AccessibilityNotification.Announcement(Copy.birthdayAddAdded).post()
            }
            onFinish?(outcome)
            dismiss()
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("birthday.add")
    }

    private var header: some View {
        HStack {
            MemoryHeaderCircle(icon: Tokens.Icons.globalClose, label: Copy.birthdayAddA11yClose) {
                model.later()
            }
            Spacer()
        }
        .padding(.horizontal, Tokens.Sizes.globalHeaderInset)
    }

    @ViewBuilder
    private var content: some View {
        switch model.phase {
        case .idle, .loading:
            MemoryLoadingIndicator()
                .frame(maxWidth: .infinity)
        case .add:
            VStack(spacing: Tokens.Sizes.globalListGap) {
                Text(Copy.birthdayAddTitle)
                    .dsTextStyle(MemoryType.onboardingTitle)
                    .foregroundStyle(Tokens.Colors.globalTextPrimary)
                    .accessibilityAddTraits(.isHeader)
                Text(Copy.birthdayAddDetail)
                    .dsTextStyle(MemoryType.listSubtitle)
                    .foregroundStyle(Tokens.Colors.globalTextSecondary)
                Text(Copy.birthdayAddPrivacy)
                    .dsTextStyle(MemoryType.listSubtitle)
                    .foregroundStyle(Tokens.Colors.globalTextSecondary)
                BirthdayDateField(text: $model.dateText, entry: model.entry)
                    .disabled(model.isSaving)
                inlineLine
                errorBlock
            }
            .multilineTextAlignment(.center)
        case let .manage(date):
            VStack(spacing: Tokens.Sizes.globalListGap) {
                Text(Copy.birthdayAddManageTitle)
                    .dsTextStyle(MemoryType.sheetTitle)
                    .foregroundStyle(Tokens.Colors.globalTextPrimary)
                    .accessibilityAddTraits(.isHeader)
                Text(MemoryFormat.birthdayDayMonth(date))
                    .dsTextStyle(MemoryType.listTitle)
                    .foregroundStyle(Tokens.Colors.globalTextPrimary)
                Text(Copy.birthdayAddDetail)
                    .dsTextStyle(MemoryType.listSubtitle)
                    .foregroundStyle(Tokens.Colors.globalTextSecondary)
                inlineLine
                errorBlock
            }
            .multilineTextAlignment(.center)
        }
    }

    @ViewBuilder
    private var inlineLine: some View {
        if let inline = model.inline {
            Text(inline == .invalid ? Copy.birthdayAddInvalid : Copy.birthdayAddOffline)
                .dsTextStyle(MemoryType.listSubtitle)
                .foregroundStyle(Tokens.Colors.globalTextSecondary)
        }
    }

    @ViewBuilder
    private var errorBlock: some View {
        if model.showsError {
            MemoryStateMessage(title: Copy.birthdayAddErrorTitle, detail: Copy.birthdayAddErrorDetail)
        }
    }

    @ViewBuilder
    private var buttons: some View {
        switch model.phase {
        case .add:
            VStack(spacing: Tokens.Sizes.globalListGap) {
                MemoryFilledButton.yopePrimary(
                    model.showsError ? Copy.birthdayAddErrorRetry : Copy.birthdayAddConfirm,
                    isWorking: model.isSaving
                ) {
                    Task { await model.confirm() }
                }
                .disabled(!model.canConfirm)
                .accessibilityIdentifier("birthday.add.confirm")
                MemoryFilledButton.yopeLightPill(Copy.birthdayAddLater) {
                    model.later()
                }
                .disabled(model.isSaving)
            }
        case .manage:
            MemoryFilledButton.yopeLightPill(Copy.birthdayAddManageRemove) {
                Task { await model.remove() }
            }
            .disabled(model.isSaving)
        case .idle, .loading:
            EmptyView()
        }
    }
}
