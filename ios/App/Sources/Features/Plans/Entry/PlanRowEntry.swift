// Surface: groups.screen — the plans block (design/research/plans.md §11 "group screen entry": one C-14 row, as the
// birthday request row of groups.screen item 6, for the group's next plan, with the "+" of plans.create.entry) and, while
// the group has any plan, the C-20 "Plans" label above it → plans.list (design/surfaces/plans.list.md "Entry on
// groups.screen"; MERGE FV-1). Its place next to the birthday row is date order (`GroupEntryOrder`).
import AppData
import AppModels
import DesignSystem
import Observation
import SwiftUI

@MainActor
@Observable
final class PlanRowModel {
    let groupID: GroupID
    /// The group's next plan (the first upcoming row of `group_plans`), nil when none is upcoming.
    private(set) var next: GroupPlan?
    /// Whether the group has any plan (upcoming, past or cancelled): the "Plans" label → plans.list shows.
    private(set) var hasPlans = false
    private(set) var timeZone: TimeZone = .current
    private(set) var isLoaded = false

    private let services: PlansServices

    init(groupID: GroupID, services: PlansServices) {
        self.groupID = groupID
        self.services = services
    }

    /// The row's second line: the plan's day (and time) in the locale's medium date / short time.
    var line: String? {
        next.map { PlanFormats.rowLine(startsAt: $0.startsAt, allDay: $0.allDay, localDate: $0.localDate, timeZone: timeZone) }
    }

    /// Refetches on the group's plan changes (a plan made, edited, cancelled or restored by another member; docs/API.md
    /// §14.2 Realtime) until the calling task ends.
    func followChanges() async {
        for await _ in services.plans.planChanges(groupID: groupID) {
            await refresh()
        }
    }

    /// The block's day for its place next to the birthday row: the next plan's day; none without an upcoming plan.
    var entryDay: LocalDate? { next?.localDate }

    func refresh() async {
        do {
            let plans = try await services.plans.groupPlans(groupID: groupID)
            next = plans.first { $0.state == .upcoming }
            hasPlans = !plans.isEmpty
            if let group = try? await services.plans.group(id: groupID) { timeZone = group.resolvedTimeZone }
            isLoaded = true
        } catch {
            // Keeps the last row; the group screen's own states cover a failed load.
        }
    }
}

/// The plans block, `size.global.sectionGap` under what precedes it:
/// - while the group has any plan: the C-20 label `plans.list.title` with `icon.global.chevron` (grey) at the right margin
///   as one button → plans.list (the week header's "see all"), the row `size.global.sectionHeaderToContent` below its
///   baseline;
/// - the plan row: one C-14 row inside `size.global.screenMargin` (fill `color.global.control`, `radius.global.groupedRow`).
///   Next plan: `icon.global.calendar`, the plan's title (`listTitle`) over its day (`listSubtitle`, grey), the trailing
///   `icon.global.chevron` → plans.page; then the "+" (`icon.global.add`, labelled `plans.create.entry`) → plans.create.
///   No upcoming plan: `icon.global.add` and `plans.create.entry` (`body`) → plans.create.
/// Renders nothing until loaded. Its day (`PlanRowModel.entryDay`) places it next to the birthday rows (`GroupEntryOrder`).
@MainActor
struct PlanRowEntry: View {
    @State private var model: PlanRowModel
    @Environment(AccountDependencies.self) private var dependencies: AccountDependencies?
    @ScaledMetric private var sectionLabelSize: CGFloat

    init(groupID: String, model: PlanRowModel? = nil) {
        _model = State(initialValue: model ?? PlanRowModel(groupID: GroupID(groupID), services: .shared))
        _sectionLabelSize = ScaledMetric(wrappedValue: TextRole.sectionLabel.size, relativeTo: TextRole.sectionLabel.relativeTo)
    }

    var body: some View {
        VStack(spacing: 0) {
            if model.isLoaded {
                if model.hasPlans {
                    WeekStripSection {
                        listHeader
                    } content: {
                        SettingsGroup(rows: [row.asSettingsRow()])
                    }
                    .padding(.top, Tokens.Sizes.globalSectionGap)
                    .dsTransition(.opacity)
                } else {
                    SettingsGroup(rows: [row.asSettingsRow()])
                        .padding(.top, Tokens.Sizes.globalSectionGap)
                        .dsTransition(.opacity)
                }
            }
        }
        .dsAnimation(ComponentMotion.fade, value: model.next?.id)
        .dsAnimation(ComponentMotion.fade, value: model.hasPlans)
        .task(id: PlansServices.shared.revision) { await model.refresh() }
        .task { await model.followChanges() }
        .accessibilityIdentifier("groups.screen.plan")
    }

    /// C-20 "Plans" + the grey chevron at the right margin, one button → plans.list (header trait, hint "All Plans").
    private var listHeader: some View {
        Button {
            dependencies?.router.path.append(.plans(.list(groupID: model.groupID.rawValue)))
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Text(Copy.plansListTitle)
                    .dsTextStyle(TextRole.sectionLabel)
                    .foregroundStyle(Tokens.Colors.globalTextPrimary)
                Spacer(minLength: 0)
                Glyph(Tokens.Icons.globalChevron, relativeTo: TextRole.sectionLabel.relativeTo)
                    .foregroundStyle(Tokens.Colors.globalTextSecondary)
                    // centred on the label's cap middle, as the week header's chevron
                    .alignmentGuide(.firstTextBaseline) { glyph in
                        glyph[VerticalAlignment.center] + TextMetrics(style: TextRole.sectionLabel, size: sectionLabelSize).capHeight / 2
                    }
            }
            .lineLimit(1)
            .padding(.horizontal, Tokens.Sizes.globalScreenMargin)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(Copy.plansListTitle))
        .accessibilityHint(Text(Copy.plansListEntryAccessibilityHint))
        .accessibilityAddTraits([.isHeader, .isButton])
        .accessibilityIdentifier("groups.screen.plans.all")
        .capHeight(of: TextRole.sectionLabel)
    }

    @ViewBuilder
    private var row: some View {
        if let next = model.next {
            HStack(spacing: 0) {
                Button {
                    open(next)
                } label: {
                    HStack {
                        Glyph(Tokens.Icons.globalCalendar, relativeTo: TextRole.body.relativeTo)
                            .foregroundStyle(Tokens.Colors.globalTextPrimary)
                        VStack(alignment: .leading) {
                            Text(next.title)
                                .dsTextStyle(TextRole.listTitle)
                                .foregroundStyle(Tokens.Colors.globalTextPrimary)
                                .lineLimit(1)
                            if let line = model.line {
                                Text(line)
                                    .dsTextStyle(TextRole.listSubtitle)
                                    .foregroundStyle(Tokens.Colors.globalTextSecondary)
                            }
                        }
                        .multilineTextAlignment(.leading)
                        Spacer(minLength: 0)
                        Glyph(Tokens.Icons.globalChevron, relativeTo: TextRole.body.relativeTo)
                            .foregroundStyle(Tokens.Colors.globalTextSecondary)
                    }
                    .modifier(SettingsRowFrame())
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isButton)
                .accessibilityIdentifier("groups.screen.plan.open")
                HeaderIconButton(icon: Tokens.Icons.globalAdd, accessibilityLabel: Copy.plansCreateEntry) {
                    create()
                }
                .padding(.trailing, Tokens.Sizes.globalScreenMargin - (Tokens.Sizes.globalHeaderButton - Tokens.Sizes.globalIcon) / 2)
                .accessibilityIdentifier("groups.screen.plan.create")
            }
        } else {
            SettingsRow(Copy.plansCreateEntry, icon: Tokens.Icons.globalAdd, kind: .button { create() })
                .accessibilityIdentifier("groups.screen.plan.create")
        }
    }

    private func open(_ plan: GroupPlan) {
        dependencies?.router.path.append(.plans(.page(planID: plan.id.rawValue, groupID: plan.groupID.rawValue)))
    }

    private func create() {
        dependencies?.router.modal = .plans(.create(groupID: model.groupID.rawValue))
    }
}
