// Shared component — Yope's floating tab bar (groups.list, `groups.list.layout.tabBar`).
import DesignSystem
import SwiftUI

/// The app's four destinations, in `groups.list.layout.tabBar.order`: camera · groups · walls · me.
enum AppTab: Hashable, CaseIterable {
    case camera
    case groups
    case walls
    case me

    /// `groups.list.tab.*.accessibilityLabel`
    var accessibilityLabel: String {
        switch self {
        case .camera: return Copy.groupsListTabCameraAccessibilityLabel
        case .groups: return Copy.groupsListTabGroupsAccessibilityLabel
        case .walls: return Copy.groupsListTabWallsAccessibilityLabel
        case .me: return Copy.groupsListTabMeAccessibilityLabel
        }
    }

    /// Glyph (fill variant in tab bars, `icon.global.variantRule`); `.me` shows the person's avatar instead.
    var icon: String {
        switch self {
        case .camera: return Tokens.Icons.globalCamera
        case .groups: return Tokens.Icons.globalChats
        case .walls: return Tokens.Icons.globalWall
        case .me: return Tokens.Icons.globalPerson
        }
    }
}

/// Floating capsule tab bar, icon-only, no badges.
///
/// Tokens: capsule `size.global.tabBarWidth` (maximum) × `size.global.tabBarHeight`, fill `color.global.control`,
/// `radius.global.capsule`, side inset `size.global.tabBarInset` (applied here); glyphs `size.global.tabBarIcon`,
/// selected glyph `color.global.textPrimary` on a `color.global.controlRaised` pill of
/// `size.global.tabBarSelectedWidth` × `.tabBarSelectedHeight`, unselected glyph `color.global.textSecondary`;
/// the "me" tab shows the person's avatar at `size.global.tabBarAvatar`. Items share the width equally.
/// Accessibility: each item is a button labelled from `groups.list.tab.*`, the current one with the selected trait.
struct FloatingTabBar: View {
    let selected: AppTab
    /// Storage path of the signed-in person's avatar (the "me" tab).
    var avatarPath: String?
    let onSelect: (AppTab) -> Void

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases, id: \.self) { tab in
                Button {
                    onSelect(tab)
                } label: {
                    item(tab)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(tab.accessibilityLabel))
                .accessibilityAddTraits(tab == selected ? .isSelected : [])
            }
        }
        .frame(maxWidth: Tokens.Sizes.globalTabBarWidth)
        .frame(height: Tokens.Sizes.globalTabBarHeight)
        .background(Tokens.Colors.globalControl, in: Capsule())
        .padding(.horizontal, Tokens.Sizes.globalTabBarInset)
    }

    @ViewBuilder
    private func item(_ tab: AppTab) -> some View {
        let isSelected = tab == selected
        ZStack {
            if isSelected {
                Capsule()
                    .fill(Tokens.Colors.globalControlRaised)
                    .frame(width: Tokens.Sizes.globalTabBarSelectedWidth, height: Tokens.Sizes.globalTabBarSelectedHeight)
            }
            if tab == .me {
                AvatarView(path: avatarPath, diameter: Tokens.Sizes.globalTabBarAvatar)
            } else {
                Image(systemName: tab.icon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: Tokens.Sizes.globalTabBarIcon, height: Tokens.Sizes.globalTabBarIcon)
                    .foregroundStyle(isSelected ? Tokens.Colors.globalTextPrimary : Tokens.Colors.globalTextSecondary)
            }
        }
    }
}
