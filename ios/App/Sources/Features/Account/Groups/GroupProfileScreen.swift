// Surface: groups.screen — view B, the group's profile page (tap on the header capsule). Reference app: Yope
// (design/surfaces/groups.screen.md "B. Profile page"). Reference images:
// references/auto/yope/frames/a-itsmthuyope-7644974799302823175-t51.73-group-profile-add-20-pics.png (G3),
// a-yrrah-7434441926000037121-t33.73-group-menu-leave-report-2024.png (M24).
import AppData
import AppModels
import DesignSystem
import SwiftUI

struct GroupProfileScreen: View {
    let groupID: String
    @Environment(AccountDependencies.self) private var dependencies

    var body: some View {
        GroupProfileView(model: GroupFeedModel(groupID: GroupID(groupID), data: dependencies.data))
    }
}

struct GroupProfileView: View {
    enum Segment: Hashable {
        case pics
        case wall
        case recaps
    }

    @State private var model: GroupFeedModel
    @State private var segment: Segment = .pics
    @State private var confirmLeave = false
    @State private var warningCount = 0
    @Environment(AccountDependencies.self) private var dependencies
    @Environment(\.dismiss) private var dismiss

    init(model: GroupFeedModel) {
        _model = State(initialValue: model)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                AvatarView(path: model.group?.coverPath, diameter: Tokens.Sizes.groupsScreenSizeProfileAvatar, placeholderIcon: Tokens.Icons.globalGroup)
                Text(model.group?.name ?? "")
                    .dsTextStyle(GroupScreenStyle.profileName)
                    .foregroundStyle(Tokens.Colors.globalTextPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .accessibilityAddTraits(.isHeader)
                    .padding(.horizontal, Tokens.Sizes.globalScreenMargin)
                Button {
                    dependencies.router.path.append(.account(.groupSettings(groupID: model.groupID.rawValue)))
                } label: {
                    AvatarStack(paths: model.members.map { $0.profile?.avatarPath })
                        .frame(minHeight: Tokens.Sizes.globalMinTouchTargetIos)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(Copy.groupsSettingsMembersHeader))
                SegmentedPills(
                    options: [
                        SegmentOption(Segment.pics, title: Copy.groupsScreenProfileSegmentPics),
                        SegmentOption(Segment.wall, title: Copy.groupsScreenProfileSegmentWall),
                        SegmentOption(Segment.recaps, title: Copy.groupsScreenProfileSegmentRecaps),
                    ],
                    selection: $segment
                )
                .padding(.horizontal, Tokens.Sizes.groupsScreenSizeSegmentMarginH)
                picsGrid
                    .padding(.top, Tokens.Sizes.groupsScreenSizeSegmentMarginH)
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) { header }
        .background(Tokens.Colors.globalBackgroundDeep.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .task { await model.load() }
        .onDisappear { model.stop() }
        .onChange(of: segment) { _, selected in open(selected) }
        .leaveGroupAlert(isPresented: $confirmLeave, group: model.group, isLastMember: model.members.count <= 1, data: dependencies.data) {
            warningCount += 1
            dependencies.router.path = []
        }
        .dsHaptic(Tokens.Haptics.globalWarning, trigger: warningCount)
        .accessibilityIdentifier("groups.profile")
    }

    /// ‹ (`color.global.controlOnDeep`) leading; ••• native menu trailing (`groups.screen.layout.menu`).
    private var header: some View {
        HStack {
            HeaderCircleButton(icon: Tokens.Icons.globalBack, accessibilityLabel: Copy.groupsScreenBackAccessibilityLabel, fill: .onDeep) {
                dismiss()
            }
            Spacer(minLength: 0)
            HeaderCircleMenu(icon: Tokens.Icons.globalMore, accessibilityLabel: Copy.groupsScreenProfileMoreAccessibilityLabel, fill: .onDeep) {
                Button(Copy.groupsScreenMenuShareInvite, systemImage: Tokens.Icons.globalShare) {
                    dependencies.router.modal = .account(.groupInvite(groupID: model.groupID.rawValue))
                }
                Button(Copy.groupsScreenMenuSettings, systemImage: Tokens.Icons.globalSettings) {
                    dependencies.router.path.append(.account(.groupSettings(groupID: model.groupID.rawValue)))
                }
                Button(Copy.groupsScreenMenuLeave, systemImage: Tokens.Icons.globalLeave, role: .destructive) {
                    confirmLeave = true
                }
                Button(Copy.groupsScreenMenuReport, systemImage: Tokens.Icons.globalReport, role: .destructive) {
                    dependencies.router.modal = .account(.report(ReportTarget(kind: .group, id: model.groupID.rawValue, name: model.group?.name)))
                }
            }
            .accessibilityIdentifier("groups.profile.more")
        }
        .padding(.horizontal, Tokens.Sizes.globalHeaderInset)
    }

    /// "pics": the group's photos (thumbnails) in Yope's photo grid — columns, gap and tile shape of the wall grid
    /// (`walls.mine.count.gridColumns`, `.dimension.gridGap`, `.aspectRatio.gridTile`; role reuse, the profile grid was
    /// not measured), corners `radius.global.photo`.
    private var picsGrid: some View {
        let columns = Array(
            repeating: GridItem(.flexible(), spacing: Tokens.Sizes.wallsMineDimensionGridGap),
            count: Int(Tokens.Counts.wallsMineCountGridColumns)
        )
        return LazyVGrid(columns: columns, spacing: Tokens.Sizes.wallsMineDimensionGridGap) {
            ForEach(model.posts) { post in
                Button {
                    dependencies.router.path.append(.post(groupID: model.groupID.rawValue, postID: post.id.rawValue))
                } label: {
                    Color.clear
                        .aspectRatio(Tokens.AspectRatios.wallsMineAspectRatioGridTile, contentMode: .fit)
                        .overlay {
                            StorageImage(path: post.media?.imagePath(for: .thumb)) { Tokens.Colors.globalControl }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: Tokens.Radii.globalPhoto))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(Copy.groupsScreenPhotoAccessibilityLabel(
                    firstName: model.profile(of: post.post.authorID)?.firstName ?? "",
                    time: AccountFormats.time(post.post.createdAt)
                )))
                .onAppear {
                    if post.id == model.posts.last?.id { Task { await model.loadMore() } }
                }
            }
        }
        .padding(.horizontal, Tokens.Sizes.groupsScreenSizeSegmentMarginH)
    }

    /// "wall" → walls.browse scoped to the group; "recaps" → week.history (other groups' screens, pushed); the
    /// page keeps showing "pics" when the person comes back.
    private func open(_ selected: Segment) {
        let route: AppRoute?
        switch selected {
        case .pics: return
        case .wall: route = CrossGroupRoutes.wallsBrowse(groupID: model.groupID.rawValue)
        case .recaps: route = CrossGroupRoutes.weekHistory(groupID: model.groupID.rawValue)
        }
        if let route { dependencies.router.path.append(route) }
        segment = .pics
    }
}

extension View {
    /// The leave confirmation shared by groups.settings and the profile ••• menu (`settings.account.layout.alert`):
    /// title `groups.settings.leave.title`, message `.message` or `.messageLast` (last member), destructive
    /// `.confirm`, `groups.settings.alert.cancel`. Confirm → `leave_group` → `onLeft`.
    func leaveGroupAlert(
        isPresented: Binding<Bool>,
        group: PhotoGroup?,
        isLastMember: Bool,
        data: AccountDataSource,
        onFailed: @escaping @MainActor () -> Void = {},
        onLeft: @escaping @MainActor () -> Void
    ) -> some View {
        alert(Text(Copy.groupsSettingsLeaveTitle(groupName: group?.name ?? "")), isPresented: isPresented) {
            Button(Copy.groupsSettingsAlertCancel, role: .cancel) {}
            Button(Copy.groupsSettingsLeaveConfirm, role: .destructive) {
                guard let group else { return }
                Task { @MainActor in
                    do {
                        try await data.leaveGroup(id: group.id)
                        onLeft()
                    } catch {
                        onFailed()
                    }
                }
            }
        } message: {
            Text(isLastMember ? Copy.groupsSettingsLeaveMessageLast : Copy.groupsSettingsLeaveMessage)
        }
    }
}
