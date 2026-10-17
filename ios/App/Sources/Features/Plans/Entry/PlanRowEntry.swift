// Surface: groups.screen — the plan row (design/research/plans.md §11 "group screen entry": one C-14 row, as the birthday
// request row of groups.screen item 6, for the group's next plan, with the "+" of plans.create.entry). Its order next to
// the birthday row is BLOCKED (plans.md §12 item 6): `GroupFeedView` places it.
import AppData
import AppModels
import DesignSystem
import Observation
import SwiftUI

@MainActor
@Observable
final class PlanRowModel {
    let groupID: GroupID
    /// The group's next plan (`next_plans(p_group_id)`), nil when none is upcoming.
    private(set) var next: UpcomingPlan?
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

    func refresh() async {
        do {
            next = try await services.plans.nextPlans(groupID: groupID).first
            if let group = try? await services.plans.group(id: groupID) { timeZone = group.resolvedTimeZone }
            isLoaded = true
        } catch {
            // Keeps the last row; the group screen's own states cover a failed load.
        }
    }
}

/// The plan row: one C-14 row inside `size.global.screenMargin` (fill `color.global.control`, `radius.global.groupedRow`),
/// `size.global.sectionGap` under what precedes it.
/// - Next plan: `icon.global.calendar`, the plan's title (`listTitle`) over its day (`listSubtitle`, grey), the trailing
///   `icon.global.chevron` → plans.page; then the "+" (`icon.global.add`, labelled `plans.create.entry`) → plans.create.
/// - No upcoming plan: `icon.global.add` and `plans.create.entry` (`body`) → plans.create.
/// Renders nothing until loaded.
@MainActor
struct PlanRowEntry: View {
    @State private var model: PlanRowModel
    @Environment(AccountDependencies.self) private var dependencies: AccountDependencies?

    init(groupID: String, model: PlanRowModel? = nil) {
        _model = State(initialValue: model ?? PlanRowModel(groupID: GroupID(groupID), services: .shared))
    }

    var body: some View {
        VStack(spacing: 0) {
            if model.isLoaded {
                SettingsGroup(rows: [row.asSettingsRow()])
                    .padding(.top, Tokens.Sizes.globalSectionGap)
                    .dsTransition(.opacity)
            }
        }
        .dsAnimation(ComponentMotion.fade, value: model.next?.id)
        .task(id: PlansServices.shared.revision) { await model.refresh() }
        .task { await model.followChanges() }
        .accessibilityIdentifier("groups.screen.plan")
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

    private func open(_ plan: UpcomingPlan) {
        dependencies?.router.path.append(.plans(.page(planID: plan.id.rawValue, groupID: plan.groupID.rawValue)))
    }

    private func create() {
        dependencies?.router.modal = .plans(.create(groupID: model.groupID.rawValue))
    }
}
