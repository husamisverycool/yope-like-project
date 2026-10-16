// Surface: birthday.add — composition of Retro components C-33, C-12, C-05, C-08, C-14, C-10, C-29 in the age gate's
// order (Retro has no birthday screen; design/surfaces/birthday.add.md, MERGE RM-1). Reference images:
// references/auto/retro/lazyweb/retro-lazyweb-20251119-social.png (LAND: centred block, 60-pt capsule, grey link),
// references/auto/retro/lazyweb/retro-lazyweb-20251020-week43-dark.png (H43: C-27 spacing),
// references/auto/retro/store/editorial/retro-appstore-story-1854931006-week3-albums.png (ED-W3: C-12 field).
import AppData
import DesignSystem
import SwiftUI

/// Add (or manage) your birthday for birthday videos. Pushed from the settings "Birthday" row (`MemoryRoute.birthdayAdd`)
/// in the settings stack (native back, inline title `birthday.add.manage.title`); never shown by the app on its own.
/// Follows the appearance.
///
/// - Parameter onFinish: called once when the screen closes after adding (`.added`) or with "Maybe later"
///   (`.dismissed`). The "Saved!" confirmation outlives the screen, so the presenter shows it (C-26 `ToastCenter`), as
///   `BirthdayAddRoute` does; without a presenter it is announced here.
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
        Group {
            switch model.phase {
            case .idle, .loading:
                LoadingHUD()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .add:
                addForm
            case let .manage(date):
                manage(date)
            }
        }
        .background(Tokens.Colors.globalBackground.ignoresSafeArea())
        .navigationTitle(Copy.birthdayAddManageTitle)
        .navigationBarTitleDisplayMode(.inline)
        .dsAnimation(ComponentMotion.crossfade, value: model.canConfirm)
        .task { await model.loadIfNeeded() }
        .onChange(of: model.outcome) { _, outcome in
            guard let outcome else { return }
            if let onFinish {
                onFinish(outcome)
            } else if outcome == .added {
                AccessibilityNotification.Announcement(Copy.birthdayAddAdded).post()
            }
            dismiss()
        }
        .alert(Copy.birthdayAddRemoveTitle, isPresented: $model.showsRemoveConfirmation) {
            Button(Copy.birthdayAddRemoveConfirm, role: .destructive) {
                Task { await model.remove() }
            }
            Button(Copy.birthdayAddRemoveCancel, role: .cancel) {}
        } message: {
            Text(Copy.birthdayAddRemoveMessage)
        }
        // A container: without .contain its identifier would replace every child's (XCUITest).
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("birthday.add")
    }

    // MARK: Not opted in

    /// A centred block in the free space above the bottom controls (C-27 placement): the headline (C-33), the two grey
    /// lines, the age gate's date field (C-12); pinned to the bottom, the primary capsule (C-05) and "Maybe later" (C-08).
    /// The block scrolls when the text grows; the capsule stays pinned.
    private var addForm: some View {
        GeometryReader { proxy in
            ScrollView {
                addBlock
                    .padding(.horizontal, Tokens.Sizes.globalScreenMargin)
                    .frame(maxWidth: .infinity, minHeight: proxy.size.height)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            bottomControls
        }
    }

    private var addBlock: some View {
        MetricStack(alignment: .center) {
            Text(Copy.birthdayAddTitle)
                .dsTextRole(TextRole.displayMedium)
                .foregroundStyle(Tokens.Colors.globalTextPrimary)
                .accessibilityAddTraits(.isHeader)
            Text(Copy.birthdayAddDetail)
                .dsTextRole(TextRole.body)
                .foregroundStyle(Tokens.Colors.globalTextSecondary)
                .metricGap(Tokens.Sizes.globalEmptyIconToTitle, from: .lastBaseline, to: .capTop)
            Text(Copy.birthdayAddPrivacy)
                .dsTextRole(TextRole.body)
                .foregroundStyle(Tokens.Colors.globalTextSecondary)
                .metricGap(Tokens.Sizes.globalListGap, from: .lastBaseline, to: .capTop)
            VStack(alignment: .leading) {
                FormField(
                    model.placeholder,
                    text: Binding(get: { model.dateText }, set: { model.setText($0) }),
                    accessibilityLabel: Copy.authAgegateFieldAccessibilityLabel,
                    keyboard: .numberPad,
                    contentType: .birthdate,
                    errorMessage: model.inline == .invalid ? Copy.birthdayAddInvalid : nil
                )
                .disabled(model.isSaving)
                .accessibilityHint(Text(model.entry.placeholderFormat))
                .accessibilityIdentifier("birthday.add.field")
                if model.inline == .offline {
                    // C-12 inline line: text role `meta`, `color.global.textSecondary`.
                    Text(Copy.birthdayAddOffline)
                        .dsTextStyle(TextRole.meta)
                        .foregroundStyle(Tokens.Colors.globalTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity)
            .metricGap(Tokens.Sizes.globalEmptyTitleToAction, from: .lastBaseline, to: .top)
        }
        .multilineTextAlignment(.center)
    }

    /// The C-27 error block above the capsule when saving failed (the capsule retries), the capsule (busy while saving),
    /// and the secondary link.
    private var bottomControls: some View {
        VStack {
            if model.showsError {
                EmptyStateView(title: Copy.birthdayAddErrorTitle, detail: Copy.birthdayAddErrorDetail)
                    .accessibilityIdentifier("birthday.add.error")
            }
            PrimaryButton(
                model.showsError ? Copy.birthdayAddErrorRetry : Copy.birthdayAddConfirm,
                isEnabled: model.canConfirm || model.isSaving,
                isBusy: model.isSaving
            ) {
                Task { await model.confirm() }
            }
            .padding(.horizontal, Tokens.Sizes.globalButtonMarginH)
            .accessibilityIdentifier("birthday.add.confirm")
            TextButton(Copy.birthdayAddLater, style: .link) {
                model.later()
            }
            .disabled(model.isSaving)
            .accessibilityIdentifier("birthday.add.later")
        }
        .background(Tokens.Colors.globalBackground)
    }

    // MARK: Opted in (manage)

    /// A C-14 group with the "Birthday" row and its value (day and month only, `layout.birthday.add.dateFormat`), the
    /// detail as the section footer (text role `meta`); a separate group with the destructive "Remove Birthday" row.
    private func manage(_ date: LocalDate) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Tokens.Sizes.globalSectionGap) {
                VStack(alignment: .leading) {
                    MemoryValueRow(title: Copy.birthdayAddManageTitle, value: MemoryFormat.dayMonth(date))
                    Text(Copy.birthdayAddDetail)
                        .dsTextStyle(TextRole.meta)
                        .foregroundStyle(Tokens.Colors.globalTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal)
                        .padding(.horizontal, Tokens.Sizes.globalScreenMargin)
                }
                GroupedSection(rows: [
                    GroupedRow(Copy.birthdayAddManageRemove, accessory: .none, role: .destructive) {
                        model.requestRemove()
                    },
                ])
                .disabled(model.isSaving)
                .accessibilityIdentifier("birthday.add.remove")
                if model.showsError {
                    EmptyStateView(title: Copy.birthdayAddErrorTitle, detail: Copy.birthdayAddErrorDetail)
                        .frame(maxWidth: .infinity)
                } else if model.inline == .offline {
                    Text(Copy.birthdayAddOffline)
                        .dsTextStyle(TextRole.meta)
                        .foregroundStyle(Tokens.Colors.globalTextSecondary)
                        .padding(.horizontal, Tokens.Sizes.globalScreenMargin)
                }
            }
            .padding(.top, Tokens.Sizes.globalScreenMargin)
        }
        .scrollBounceBehavior(.basedOnSize)
        // A container: without .contain its identifier would replace every child's (XCUITest).
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("birthday.add.manage")
    }
}

/// A C-14 row with a trailing value ("Birthday · July 5"): title text role `body` in `color.global.textPrimary`, value
/// text role `body` in `color.global.textSecondary`; fill `color.global.control`, corners `radius.global.groupedRow`
/// (continuous), platform row padding, inside `size.global.screenMargin`. `GroupedRow` has no trailing value (component
/// gap reported); this is its look with one. VoiceOver reads "Birthday, July 5".
struct MemoryValueRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
                .dsTextStyle(TextRole.body)
                .foregroundStyle(Tokens.Colors.globalTextPrimary)
            Spacer(minLength: 0)
            Text(value)
                .dsTextStyle(TextRole.body)
                .foregroundStyle(Tokens.Colors.globalTextSecondary)
        }
        .padding()
        .frame(minHeight: Tokens.Sizes.globalMinTouchTargetIos)
        .background(Tokens.Colors.globalControl, in: DSShape.rounded(Tokens.Radii.globalGroupedRow))
        .padding(.horizontal, Tokens.Sizes.globalScreenMargin)
        .accessibilityElement(children: .combine)
    }
}
