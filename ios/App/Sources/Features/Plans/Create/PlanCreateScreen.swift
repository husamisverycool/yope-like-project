// Surface: plans.create — make a plan in a group (also edit mode from plans.page). Visual reference: Retro's New Album
// flow as composed for groups.create step B (references/auto/retro/press/tc-2024-04-journals-1.webp phone 3, TC-J1:
// the book cover and its shadow; references/auto/retro/video/ig-DJXvmqRv2_N-referrals-sheet-f042-059.png, VID-SET: the
// sheet header); mechanics Apple Invites' create-an-event (field order; all-day option; edit) and Partiful's New Event
// sheet (references/auto/partiful/frames/pf-apppreview-t7.250.png: free-text place row). Composition of C-29, the cover,
// C-07 / C-06, C-12, C-14, C-05 (design/surfaces/plans.create.md; MERGE PL-*).
import AppData
import AppModels
import DesignSystem
import PhotosUI
import SwiftUI
import UIKit

/// plans.create as a page sheet. `editing`: the plan of plans.page's "Edit Plan" (edit mode).
@MainActor
struct PlanCreateScreen: View {
    let groupID: String
    let editing: Plan?

    var body: some View {
        PlanCreateView(model: PlanCreateModel(groupID: GroupID(groupID), editing: editing, services: .shared))
    }
}

struct PlanCreateView: View {
    @State private var model: PlanCreateModel
    @State private var pickerItem: PhotosPickerItem?
    @State private var picking = false
    @State private var confirmingDiscard = false
    @FocusState private var focus: Field?
    @Environment(AccountDependencies.self) private var dependencies: AccountDependencies?
    @Environment(\.dismiss) private var dismiss

    /// Called with the plan after a successful save in edit mode (plans.page refreshes).
    var onSaved: ((Plan) -> Void)?

    enum Field: Hashable {
        case title
        case place
        case note
    }

    init(model: PlanCreateModel, onSaved: ((Plan) -> Void)? = nil) {
        _model = State(initialValue: model)
        self.onSaved = onSaved
    }

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(
                title: model.isEditing ? Copy.plansCreateTitleEdit : Copy.plansCreateTitle,
                closeAccessibilityLabel: Copy.plansCreateCloseAccessibilityLabel
            ) {
                requestClose()
            }
            .accessibilityIdentifier("plans.create.header")
            form
            footer
        }
        .background(Tokens.Colors.globalBackground.ignoresSafeArea())
        .presentationDetents([.large])
        .dsSheetBackground()
        .interactiveDismissDisabled(model.hasInput)
        .photosPicker(isPresented: $picking, selection: $pickerItem, matching: .images, preferredItemEncoding: .compatible)
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    model.setCover(imageData: data)
                }
                pickerItem = nil
            }
        }
        .alert(Text(Copy.plansCreateDiscardTitle), isPresented: $confirmingDiscard) {
            Button(Copy.plansCreateDiscardCancel, role: .cancel) {}
            Button(Copy.plansCreateDiscardConfirm, role: .destructive) { close() }
        }
        .task { await model.load() }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("plans.create")
    }

    // MARK: Form

    private var form: some View {
        ScrollView {
            MetricStack(alignment: .center) {
                cover
                    .metricGap(Tokens.Sizes.globalTitleToContent, from: .top, to: .top)
                coverAction
                    .metricGap(Tokens.Sizes.groupsScreenSizeCoverToTitle, from: .bottom, to: .top)
                titleField
                    .metricGap(Tokens.Sizes.globalTitleToContent, from: .bottom, to: .top)
                details
                    .metricGap(Tokens.Sizes.globalSectionGap, from: .bottom, to: .top)
                noteField
                    .metricGap(Tokens.Sizes.globalSectionGap, from: .bottom, to: .top)
            }
            .padding(.bottom, Tokens.Sizes.globalButtonMarginH)
        }
        .scrollBounceBehavior(.basedOnSize)
        .scrollDismissesKeyboard(.interactively)
        .disabled(model.isWorking)
    }

    /// Cover (`groups.screen.size.coverWidth` × `.coverHeight`, `radius.global.thumbnail`, `groups.screen.shadow.cover`;
    /// empty = `color.global.control`) → the system photo picker.
    private var cover: some View {
        Button {
            picking = true
        } label: {
            GroupCover(
                source: model.coverImage.map { PhotoSource.image($0) } ?? model.existingCoverPath.map { PhotoSource.storage($0) },
                width: Tokens.Sizes.groupsScreenSizeCoverWidth,
                height: Tokens.Sizes.groupsScreenSizeCoverHeight,
                showsGroupGlyph: false
            )
            .dsAnimation(ComponentMotion.fade, value: model.hasCover)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(model.hasCover ? Copy.plansCreateCoverEdit : Copy.plansCreateCoverAccessibilityLabel))
        .accessibilityAddTraits(.isImage)
        .accessibilityIdentifier("plans.create.cover")
    }

    /// C-07 "+ Add cover image" while empty, C-06 outline "Edit cover image" once chosen → the system photo picker. The
    /// spec's "Remove" item has no copy key in design/copy/plans.json (reported), so the cover is replaced, not removed.
    @ViewBuilder
    private var coverAction: some View {
        if model.hasCover {
            CapsuleButton(Copy.plansCreateCoverEdit, style: .outline) { picking = true }
                .fixedSize()
                .accessibilityIdentifier("plans.create.coverEdit")
        } else {
            OutlineCTA(Copy.plansCreateCoverAdd) { picking = true }
                .fixedSize()
                .accessibilityIdentifier("plans.create.coverAdd")
        }
    }

    private var titleField: some View {
        FormField(
            Copy.plansCreateNamePlaceholder,
            text: Binding(get: { model.title }, set: { model.setTitle($0) }),
            accessibilityLabel: Copy.plansCreateNameAccessibilityLabel,
            submitLabel: .next,
            errorMessage: model.isTitleTooLong ? Copy.plansCreateErrorTooLong : nil
        ) {
            // Return moves to the date row.
            focus = nil
            model.openPicker = .date
        }
        .focused($focus, equals: .title)
        .accessibilityIdentifier("plans.create.name")
        .padding(.horizontal, Tokens.Sizes.globalScreenMargin)
    }

    // MARK: Details (C-14: date, all-day, time, place — Apple's order)

    private var details: some View {
        var rows: [AnyView] = [
            valueRow(icon: Tokens.Icons.globalCalendar, label: Copy.plansCreateDate, value: model.dateText ?? Copy.plansCreateDateNone) {
                model.toggle(.date)
            }
            .accessibilityIdentifier("plans.create.date")
            .asSettingsRow(),
        ]
        if model.openPicker == .date {
            rows.append(
                SettingsCustomRow {
                    DatePicker(
                        selection: Binding(get: { model.day ?? model.minimumDate }, set: { model.setDay($0) }),
                        in: model.minimumDate...,
                        displayedComponents: .date
                    ) {
                        Text(Copy.plansCreateDate)
                    }
                    .datePickerStyle(.graphical)
                    .tint(Tokens.Colors.globalSelection)
                    .environment(\.timeZone, model.timeZone)
                }
                .asSettingsRow()
            )
        }
        rows.append(
            SettingsCustomRow {
                Toggle(isOn: Binding(get: { model.allDay }, set: { value in withDSAnimation(timeRowMotion) { model.setAllDay(value) } })) {
                    Text(Copy.plansCreateAllDay)
                        .dsTextStyle(TextRole.body)
                        .foregroundStyle(Tokens.Colors.globalTextPrimary)
                }
                .tint(Tokens.Colors.globalSelection)
            }
            .accessibilityIdentifier("plans.create.allDay")
            .asSettingsRow()
        )
        if !model.allDay {
            rows.append(
                valueRow(icon: nil, label: Copy.plansCreateTime, value: model.timeText) {
                    model.toggle(.time)
                }
                .accessibilityIdentifier("plans.create.time")
                .asSettingsRow()
            )
            if model.openPicker == .time {
                rows.append(
                    SettingsCustomRow {
                        DatePicker(
                            selection: Binding(get: { model.time ?? model.minimumDate }, set: { model.setTime($0) }),
                            displayedComponents: .hourAndMinute
                        ) {
                            Text(Copy.plansCreateTime)
                        }
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                        .frame(maxWidth: .infinity)
                        .environment(\.timeZone, model.timeZone)
                    }
                    .asSettingsRow()
                )
            }
        }
        rows.append(placeRow.asSettingsRow())
        return SettingsGroup(rows: rows)
            .dsAnimation(timeRowMotion, value: model.openPicker)
            .accessibilityElement(children: .contain)
    }

    /// The time row shows / hides with the All-day switch and the pickers open: `duration.global.fade` +
    /// `easing.global.standard` (Reduce Motion: the DS animation keeps a cross-fade only).
    private var timeRowMotion: DSAnimation { ComponentMotion.fade }

    /// A row read as one element "Date, Saturday, October 24": optional leading glyph (`size.global.iconSmall`), the label
    /// (`body`), the trailing value (`body`, `color.global.textSecondary`).
    private func valueRow(icon: String?, label: String, value: String?, action: @escaping () -> Void) -> some View {
        SettingsCustomRow(action: action) {
            HStack {
                if let icon {
                    Glyph(icon, size: Tokens.Sizes.globalIconSmall, relativeTo: TextRole.body.relativeTo)
                        .foregroundStyle(Tokens.Colors.globalTextPrimary)
                }
                Text(label)
                    .dsTextStyle(TextRole.body)
                    .foregroundStyle(Tokens.Colors.globalTextPrimary)
                Spacer(minLength: 0)
                if let value {
                    Text(value)
                        .dsTextStyle(TextRole.body)
                        .foregroundStyle(Tokens.Colors.globalTextSecondary)
                        .multilineTextAlignment(.trailing)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }

    /// `icon.global.location` and an inline text field (typed text only: no search, suggestions or Maps).
    private var placeRow: some View {
        SettingsCustomRow {
            HStack {
                Glyph(Tokens.Icons.globalLocation, size: Tokens.Sizes.globalIconSmall, relativeTo: TextRole.body.relativeTo)
                    .foregroundStyle(Tokens.Colors.globalTextPrimary)
                TextField(
                    text: Binding(get: { model.place }, set: { model.setPlace($0) }),
                    prompt: Text(Copy.plansCreatePlacePlaceholder).foregroundStyle(Tokens.Colors.globalTextSecondary)
                ) {
                    Text(Copy.plansCreatePlacePlaceholder)
                }
                .dsTextStyle(TextRole.body)
                .foregroundStyle(Tokens.Colors.globalTextPrimary)
                .focused($focus, equals: .place)
                .submitLabel(.next)
                .onSubmit { focus = .note }
            }
        }
        .accessibilityIdentifier("plans.create.place")
    }

    /// Multi-line C-12 field: grows to 6 lines, then scrolls (`plans.create.note.placeholder`).
    private var noteField: some View {
        TextField(
            text: Binding(get: { model.note }, set: { model.setNote($0) }),
            prompt: Text(Copy.plansCreateNotePlaceholder).foregroundStyle(Tokens.Colors.globalTextSecondary),
            axis: .vertical
        ) {
            Text(Copy.plansCreateNotePlaceholder)
        }
        .lineLimit(1...Self.noteMaxLines)
        .dsTextStyle(TextRole.placeholder)
        .foregroundStyle(Tokens.Colors.globalTextPrimary)
        .focused($focus, equals: .note)
        .padding()
        .frame(maxWidth: .infinity, minHeight: Tokens.Sizes.globalFieldHeight, alignment: .leading)
        .background(Tokens.Colors.globalControl, in: DSShape.rounded(Tokens.Radii.globalField))
        .padding(.horizontal, Tokens.Sizes.globalScreenMargin)
        .accessibilityIdentifier("plans.create.note")
    }

    /// plans.create Structure 5: "grows to 6 lines, then scrolls".
    static let noteMaxLines = 6 // provenance-ok: line count named by the spec

    // MARK: Button

    /// The inline failure line (`meta`, `color.global.destructive`), then C-05 "Create Plan" / "Save" pinned
    /// `size.global.buttonMarginH` above the keyboard / bottom safe area; disabled until a title and a date are set;
    /// busy while saving.
    private var footer: some View {
        VStack {
            PrimaryButton(
                model.isEditing ? Copy.plansCreateSave : Copy.plansCreateCta,
                height: .sheet,
                isEnabled: model.canSubmit || model.isWorking,
                isBusy: model.isWorking
            ) {
                Task { await submit() }
            }
            .accessibilityIdentifier("plans.create.submit")
            if let failure = model.failureMessage {
                Text(failure)
                    .dsTextStyle(TextRole.meta)
                    .foregroundStyle(Tokens.Colors.globalDestructive)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("plans.create.error")
            }
        }
        .padding(.horizontal, Tokens.Sizes.globalButtonMarginHSheet)
        .padding(.bottom, Tokens.Sizes.globalButtonMarginHSheet)
    }

    // MARK: Actions

    /// True when this sheet is the router's modal (opened from groups.screen); false when plans.page hosts it (edit).
    private var isRouterModal: Bool {
        if case .plans(.create)? = dependencies?.router.modal { return true }
        return false
    }

    private func requestClose() {
        if model.hasInput {
            confirmingDiscard = true
        } else {
            close()
        }
    }

    private func close() {
        if isRouterModal {
            dependencies?.router.modal = nil
        } else {
            dismiss()
        }
    }

    /// After create: the sheet closes and plans.page for the new plan is pushed; after an edit: the sheet closes and
    /// plans.page refreshes. No haptic (owner decision 15: creating a plan is a send).
    private func submit() async {
        AccessibilityNotification.Announcement(Copy.plansCreateCreating).post()
        guard let plan = await model.submit() else { return }
        if model.isEditing {
            onSaved?(plan)
            dismiss()
            return
        }
        guard isRouterModal, let router = dependencies?.router else {
            dismiss()
            return
        }
        router.modal = nil
        router.path.append(.plans(.page(planID: plan.id.rawValue, groupID: plan.groupID.rawValue)))
    }
}
