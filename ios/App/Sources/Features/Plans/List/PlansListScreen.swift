// Surface: plans.list — every plan of a group: Upcoming, Past Plans, Canceled. Visual reference: Retro's Albums list as
// albums.list builds it (references/auto/retro/store/editorial/retro-appstore-story-1854931006-week3-albums.png, ED-W3:
// pushed serif header, C-15 rows with a 3:4 cover) with C-20 section labels; mechanics Apple Invites' categories
// "Upcoming" / "Past Events" and the "+" beside the title (references/auto/apple-invites/store/apple-invites-store-03.png;
// support guide view-your-events) and Partiful's Past Events (help 15525513) (design/surfaces/plans.list.md; MERGE FV-1).
import AppData
import AppModels
import DesignSystem
import SwiftUI

/// `AppRoute.plans(.list(groupID:))`.
@MainActor
struct PlansListScreen: View {
    let groupID: String

    var body: some View {
        PlansListView(model: PlansListModel(groupID: GroupID(groupID), services: .shared))
    }
}

struct PlansListView: View {
    @State private var model: PlansListModel
    @Environment(AccountDependencies.self) private var dependencies: AccountDependencies?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    init(model: PlansListModel) {
        _model = State(initialValue: model)
    }

    var body: some View {
        Group {
            if model.phase == .empty {
                VStack(alignment: .leading, spacing: 0) {
                    header
                    Spacer(minLength: 0)
                    EmptyStateView(
                        icon: Tokens.Icons.globalCalendar,
                        title: Copy.plansListEmptyTitle,
                        action: .init(Copy.plansCreateEntry) { create() }
                    )
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier("plans.list.empty")
                    Spacer(minLength: 0)
                }
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        header
                        content
                    }
                    .padding(.bottom, Tokens.Sizes.globalSectionGap)
                }
                .refreshable { await model.refresh() }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Tokens.Colors.globalBackground.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .task(id: PlansServices.shared.revision) { await model.refresh() }
        .task { await model.followChanges() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await model.refresh() } }
        }
        .onChange(of: model.phase) { _, phase in
            if phase == .removed { dismiss() }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("plans.list")
    }

    /// C-02 header "Plans" with the trailing "+" (Apple Invites' create beside "Upcoming") → plans.create.
    private var header: some View {
        PushedScreenHeader(
            title: Copy.plansListTitle,
            backAccessibilityLabel: Copy.plansListBackAccessibilityLabel,
            actions: [HeaderAction(icon: Tokens.Icons.globalAdd, accessibilityLabel: Copy.plansCreateEntry) { create() }]
        ) {
            dismiss()
        }
    }

    @ViewBuilder
    private var content: some View {
        switch model.phase {
        case .loading:
            // albums.list's loading state: three C-15 thumbnails, no text.
            VStack(alignment: .leading, spacing: Tokens.Sizes.globalListGap) {
                ForEach(0..<3, id: \.self) { _ in // provenance-ok: the spec's loading state "three rows"
                    Tokens.Colors.globalControl
                        .frame(width: Tokens.Sizes.globalRowThumbWidth, height: Tokens.Sizes.globalRowThumbHeight)
                        .clipShape(DSShape.rounded(Tokens.Radii.globalThumbnail))
                }
            }
            .padding(.horizontal, Tokens.Sizes.globalScreenMargin)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(Copy.weekHistoryA11yLoading))
        case .error:
            SocialErrorLine(text: Copy.plansListErrorTitle) { Task { await model.retry() } }
                .accessibilityIdentifier("plans.list.error")
        case .offline:
            SocialErrorLine(text: Copy.plansListOffline) { Task { await model.retry() } }
                .accessibilityIdentifier("plans.list.offline")
        case .loaded:
            WeekSectionList {
                ForEach(model.sections) { section in
                    sectionView(section)
                }
            }
            .dsTransition(.opacity)
        case .empty, .removed:
            EmptyView()
        }
    }

    /// C-20 label (no count) and, `size.global.sectionHeaderToContent` below its baseline, the C-15 rows
    /// `size.global.listGap` apart; sections `size.global.sectionGap` apart (`WeekSectionList`, as week.history).
    private func sectionView(_ section: PlansListModel.Section) -> some View {
        WeekStripSection {
            SectionHeader(title: Self.title(of: section.state))
        } content: {
            ThumbnailRowList {
                ForEach(section.plans) { plan in
                    PlanListRow(plan: plan, line: model.line(plan)) { open(plan) }
                }
            }
        }
        .accessibilityIdentifier("plans.list.section." + section.state.rawValue) // provenance-ok: UI-test identifier
    }

    /// `plans.list.section.*`.
    static func title(of state: GroupPlanState) -> String {
        switch state {
        case .upcoming, .unknown: return Copy.plansListSectionUpcoming
        case .past: return Copy.plansListSectionPast
        case .canceled: return Copy.plansListSectionCanceled
        }
    }

    private func open(_ plan: GroupPlan) {
        dependencies?.router.path.append(.plans(.page(planID: plan.id.rawValue, groupID: plan.groupID.rawValue)))
    }

    private func create() {
        dependencies?.router.modal = .plans(.create(groupID: model.groupID.rawValue))
    }
}

/// C-15 row: the plan's cover as the 3:4 thumbnail (no cover: `color.global.control` with `icon.global.calendar`, the
/// group cover's placeholder), the title (`listTitle`, up to two lines; cancelled: struck through in
/// `color.global.textSecondary`, as plans.page) over the day line (`listSubtitle`, grey). One button.
struct PlanListRow: View {
    let plan: GroupPlan
    let line: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Tokens.Sizes.globalRowThumbGap) {
                ZStack {
                    Tokens.Colors.globalControl
                    if let cover = plan.coverPath {
                        PhotoView(source: .storage(cover))
                    } else {
                        Glyph(Tokens.Icons.globalCalendar)
                            .foregroundStyle(Tokens.Colors.globalTextSecondary)
                    }
                }
                .frame(width: Tokens.Sizes.globalRowThumbWidth, height: Tokens.Sizes.globalRowThumbHeight)
                .clipShape(DSShape.rounded(Tokens.Radii.globalThumbnail))
                VStack(alignment: .leading) {
                    Text(plan.title)
                        .strikethrough(plan.state == .canceled)
                        .dsTextStyle(TextRole.listTitle)
                        .foregroundStyle(plan.state == .canceled ? Tokens.Colors.globalTextSecondary : Tokens.Colors.globalTextPrimary)
                        .lineLimit(2)
                    Text(line)
                        .dsTextStyle(TextRole.listSubtitle)
                        .foregroundStyle(Tokens.Colors.globalTextSecondary)
                }
                .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, Tokens.Sizes.globalScreenMargin)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text([plan.title, line].joined(separator: ", "))) // provenance-ok: joins the title and its platform-formatted day
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("plans.list.row")
    }
}
