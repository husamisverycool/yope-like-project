// Surface: search.photos — Retro's pushed Albums page with its search field (C-02 + C-12) over Retro's album photo grid
// (C-21), the "I'm in this" toggle (C-06) as member and date chips. Spec: design/surfaces/search.photos.md.
// References: references/auto/retro/store/editorial/retro-appstore-story-1854931006-week3-albums.png (ED-W3: header,
// search field), references/auto/retro/press/tc-2024-04-journals-1.webp phone 3 (TC-J1: 3-column grid, 2 pt gaps);
// mechanics: Yope's search on the group list (design/research/yope-a.md §2.9), Apple Shared Albums filters
// (support.apple.com/108314). No face or AI search; no result count anywhere (tenet 2).
import AppData
import AppModels
import DesignSystem
import SwiftUI

struct SearchPhotosScreen: View {
    @State private var model: SearchPhotosModel
    @State private var viewer: PhotoViewerContext?
    @State private var datesOpen = false
    @Environment(\.dismiss) private var dismiss

    init(groupID: String?) {
        self.init(model: SearchPhotosModel(groupID: groupID.map { GroupID($0) }, data: SocialServices.shared.data))
    }

    init(model: SearchPhotosModel) {
        _model = State(initialValue: model)
    }

    /// The grid's columns (`search.photos.count.gridColumns`).
    private var columns: Int { Int(Tokens.Counts.searchPhotosCountGridColumns) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                PushedScreenHeader(title: Copy.searchPhotosTitle, backAccessibilityLabel: Copy.chatThreadA11yBack) { dismiss() }
                SearchField(Copy.searchPhotosField, text: $model.text, accessibilityLabel: Copy.searchPhotosFieldA11y) {
                    Task { await model.search() }
                }
                .padding(.horizontal, Tokens.Sizes.globalScreenMargin)
                chips
                    .padding(.top, Tokens.Sizes.globalSectionHeaderToContent)
                content
            }
            .padding(.bottom, Tokens.Sizes.globalSectionGap)
        }
        .scrollDismissesKeyboard(.interactively)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Tokens.Colors.globalBackground.ignoresSafeArea())
        .socialHidesNavigationBar()
        .socialAnnouncesLoading(model.phase == .loading)
        .onChange(of: model.text) { _, _ in model.textChanged() }
        .task { await model.loadMembers() }
        .socialPhotoViewer($viewer)
        .sheet(isPresented: $datesOpen) {
            SearchDatesSheet(from: model.from, to: model.to) { start, end in
                Task { await model.setDates(from: start, to: end) }
            }
        }
        .accessibilityIdentifier("search.photos") // provenance-ok: accessibility identifier for UI tests
    }

    // MARK: Chips

    /// The date chip, then one chip per member (you first), `size.global.pillGap` apart, scrolling sideways.
    private var chips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Tokens.Sizes.globalPillGap) {
                CapsuleToggle(title: dateTitle, isOn: Binding(
                    get: { model.hasDates },
                    set: { _ in
                        if model.hasDates {
                            Task { await model.clearDates() }
                        } else {
                            datesOpen = true
                        }
                    }
                ))
                ForEach(model.members) { member in
                    CapsuleToggle(title: member.isMe ? Copy.searchPhotosMemberYou : member.name, isOn: Binding(
                        get: { model.memberID == member.id },
                        set: { _ in Task { await model.toggle(member: member.id) } }
                    ))
                }
            }
            .padding(.horizontal, Tokens.Sizes.globalScreenMargin)
        }
    }

    private var dateTitle: String {
        guard let from = model.from, let to = model.to else { return Copy.searchPhotosDate }
        return SocialFormat.dayRange(from: from, to: to)
    }

    // MARK: Content by state

    @ViewBuilder
    private var content: some View {
        switch model.phase {
        case .idle:
            EmptyStateView(icon: Tokens.Icons.globalSearch, title: Copy.searchPhotosIdleTitle, detail: Copy.searchPhotosIdleDetail)
                .frame(maxWidth: .infinity)
                .padding(.top, Tokens.Sizes.globalSectionGap)
        case .loading:
            grid {
                ForEach(0..<(columns * 2), id: \.self) { _ in // provenance-ok: two rows of placeholder cells (spec loading state)
                    Tokens.Colors.globalControl
                        .aspectRatio(1, contentMode: .fit) // provenance-ok: square cells (C-21)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(Copy.weekHistoryA11yLoading))
            .padding(.top, Tokens.Sizes.globalTitleToContent)
        case .empty:
            EmptyStateView(title: Copy.searchPhotosEmptyTitle)
                .frame(maxWidth: .infinity)
                .padding(.top, Tokens.Sizes.globalSectionGap)
        case .error:
            SocialErrorLine(text: Copy.searchPhotosError) { Task { await model.search() } }
                .padding(.top, Tokens.Sizes.globalTitleToContent)
        case .offline:
            SocialErrorLine(text: Copy.searchPhotosOffline) { Task { await model.search() } }
                .padding(.top, Tokens.Sizes.globalTitleToContent)
        case .results:
            results
                .padding(.top, Tokens.Sizes.globalTitleToContent)
        }
    }

    private var results: some View {
        let posts = model.results
        return VStack(spacing: 0) {
            grid {
                ForEach(posts) { post in
                    Button {
                        viewer = model.viewer(start: post.id)
                    } label: {
                        PhotoView(source: SocialImages.source(post.media?.gridPath))
                            .aspectRatio(1, contentMode: .fit) // provenance-ok: square cells (C-21)
                            .clipShape(Rectangle())
                            .overlay(alignment: .topTrailing) {
                                if let durationMs = post.media?.videoDurationMs { VideoTileMarker(durationMs: durationMs) }
                            }
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(SocialA11y.withVideo(
                        SocialA11y.photo(post, author: model.profiles[post.post.authorID], me: model.me), media: post.media
                    )))
                    .onAppear {
                        if post.id == posts.last?.id { Task { await model.loadMore() } }
                    }
                }
            }
            .dsAnimation(ComponentMotion.crossfade, value: posts.map(\.id))
            if model.isLoadingMore {
                ProgressView()
                    .tint(Tokens.Colors.globalTextSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.top, Tokens.Sizes.globalSectionHeaderToContent)
            }
        }
    }

    /// C-21: square cells `size.global.stripGap` apart, full width inside `size.global.screenMargin`.
    private func grid<Cells: View>(@ViewBuilder _ cells: () -> Cells) -> some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: Tokens.Sizes.globalStripGap), count: max(1, columns)),
            spacing: Tokens.Sizes.globalStripGap
        ) {
            cells()
        }
        .padding(.horizontal, Tokens.Sizes.globalScreenMargin)
        .accessibilityElement(children: .contain)
    }
}

/// The date filter (iOS): two native date pickers (Start / End) under the system toolbar (Cancel / Date / Done), as the
/// invitation hours sheet. They open on the chosen days, or today.
struct SearchDatesSheet: View {
    let from: LocalDate?
    let to: LocalDate?
    let onDone: (LocalDate, LocalDate) -> Void
    @State private var start = Date()
    @State private var end = Date()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            SettingsList {
                SettingsGroup(rows: [
                    SettingsCustomRow {
                        DatePicker(selection: $start, in: ...Date(), displayedComponents: .date) {
                            Text(Copy.searchPhotosDateStart)
                                .dsTextStyle(TextRole.body)
                                .foregroundStyle(Tokens.Colors.globalTextPrimary)
                        }
                    }
                    .asSettingsRow(),
                    SettingsCustomRow {
                        DatePicker(selection: $end, in: ...Date(), displayedComponents: .date) {
                            Text(Copy.searchPhotosDateEnd)
                                .dsTextStyle(TextRole.body)
                                .foregroundStyle(Tokens.Colors.globalTextPrimary)
                        }
                    }
                    .asSettingsRow(),
                ])
            }
            .sheetToolbar(
                title: Copy.searchPhotosDate,
                cancelTitle: Copy.searchPhotosDateCancel,
                onCancel: { dismiss() },
                confirmTitle: Copy.searchPhotosDateDone,
                onConfirm: {
                    onDone(LocalDate(start, in: .current), LocalDate(end, in: .current))
                    dismiss()
                }
            )
        }
        .presentationDetents([.medium])
        .dsSheetBackground()
        .onAppear {
            start = from.map { SocialCalendar.start(of: $0, in: .current) } ?? Date()
            end = to.map { SocialCalendar.start(of: $0, in: .current) } ?? Date()
        }
    }
}
