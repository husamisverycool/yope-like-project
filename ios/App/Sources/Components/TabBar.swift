// Shared component — C-04 tab bar (design/components.md), replacing Yope's floating capsule (FloatingTabBar).
// Evidence: H43 / H22 (5 icon-only items evenly spread, no labels, no hairline, background = page, selected by glyph
// colour only, 4 pt red unread dot 5 pt under the glyph), RWA (over a photo); MERGE_DECISIONS R-16, R-19.
import DesignSystem
import SwiftUI

/// What the tab bar is drawn on.
enum TabBarSurface {
    /// An app page: background `color.global.background`; selected `color.global.textPrimary`, unselected
    /// `color.global.tabInactive`.
    case page
    /// A media surface that is black in both appearances (the camera tab): background `color.global.backgroundDeep`;
    /// glyphs in the over-photo colours (selected `color.global.textOnMedia`, unselected
    /// `color.global.tabInactiveOnMedia`) — composition of C-04's over-photo variant on the media page.
    case media
    /// Over a full-bleed photo (C-35): no background (the page draws `layout.global.photoScrim` under the bar); glyphs
    /// in the over-photo colours.
    case overPhoto
}

/// One tab: its glyph (outline variant, `icon.global.variantRule.tabBar`), its label from copy, and an optional
/// count-free unread marker whose spoken value comes from copy ("new activity" — never a count).
struct TabBarItem<ID: Hashable>: Identifiable {
    let id: ID
    let icon: String
    let accessibilityLabel: String
    var unreadValue: String?

    init(id: ID, icon: String, accessibilityLabel: String, unreadValue: String? = nil) {
        self.id = id
        self.icon = icon
        self.accessibilityLabel = accessibilityLabel
        self.unreadValue = unreadValue
    }
}

/// C-04: a standard-height bar (`size.global.tabBarHeight` above the home indicator), spanning the width
/// (`size.global.tabBarInset` 0) with icon-only items distributed evenly; glyph box `size.global.tabBarIcon`; selection
/// shown by glyph colour only; unread dot `size.global.tabBadgeDot` in `color.global.badge`, centred,
/// `size.global.tabBadgeOffset` below the glyph. Place it with `.safeAreaInset(edge: .bottom, spacing: 0)`; its
/// background extends under the home indicator. Pressed: platform default; tab switch: platform default (Retro's not
/// captured). Accessibility: each item is a button with its label, the selected trait on the current one, and the
/// unread value when marked. Contrast: inactive glyphs fail non-text contrast in light (2.12:1) and the dark state
/// change (2.85:1) — CONTRAST failure 4, reported, not changed.
struct TabBar<ID: Hashable>: View {
    let items: [TabBarItem<ID>]
    let selected: ID
    var surface: TabBarSurface = .page
    let onSelect: (ID) -> Void

    init(items: [TabBarItem<ID>], selected: ID, surface: TabBarSurface = .page, onSelect: @escaping (ID) -> Void) {
        self.items = items
        self.selected = selected
        self.surface = surface
        self.onSelect = onSelect
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(items) { item in
                let isSelected = item.id == selected
                Button {
                    onSelect(item.id)
                } label: {
                    TabBarGlyph(icon: item.icon, color: glyphColor(selected: isSelected), showsDot: item.unreadValue != nil)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(item.accessibilityLabel))
                .accessibilityValue(Text(item.unreadValue ?? ""))
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .frame(height: Tokens.Sizes.globalTabBarHeight)
        .padding(.horizontal, Tokens.Sizes.globalTabBarInset)
        .background(background.ignoresSafeArea(edges: .bottom))
    }

    private var background: Color {
        switch surface {
        case .page: return Tokens.Colors.globalBackground
        case .media: return Tokens.Colors.globalBackgroundDeep
        case .overPhoto: return Color.clear
        }
    }

    private func glyphColor(selected: Bool) -> Color {
        switch surface {
        case .page:
            return selected ? Tokens.Colors.globalTextPrimary : Tokens.Colors.globalTabInactive
        case .media, .overPhoto:
            return selected ? Tokens.Colors.globalTextOnMedia : Tokens.Colors.globalTabInactiveOnMedia
        }
    }
}

/// The glyph and its unread dot.
private struct TabBarGlyph: View {
    let icon: String
    let color: Color
    let showsDot: Bool

    var body: some View {
        Glyph(icon, size: Tokens.Sizes.globalTabBarIcon)
            .foregroundStyle(color)
            .overlay(alignment: .bottom) {
                if showsDot {
                    UnreadDot()
                        .alignmentGuide(.bottom) { dot in dot[.top] - Tokens.Sizes.globalTabBadgeOffset }
                }
            }
    }
}

// MARK: - The app's tabs

/// The app's destinations, in the shell's order: camera · groups · walls · me (the account group owns the set and the
/// order — groups.list spec, Pass 2).
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

    /// Outline glyph (C-04) by the Retro screen each destination follows (docs/SURFACES.md): camera.capture →
    /// `icon.global.camera`; groups.list (Retro home, screens 2 / 10) → `icon.global.home`; walls.browse (Retro
    /// Friends, screen 8) → `icon.global.group`; walls.mine (Retro profile, screen 4) → `icon.global.wall`.
    var icon: String {
        switch self {
        case .camera: return Tokens.Icons.globalCamera
        case .groups: return Tokens.Icons.globalHome
        case .walls: return Tokens.Icons.globalGroup
        case .me: return Tokens.Icons.globalWall
        }
    }
}

/// C-04 for the app's tabs. `unread` marks tabs with the count-free dot; `unreadValue` (copy) is what VoiceOver reads
/// with it.
struct AppTabBar: View {
    let selected: AppTab
    var unread: Set<AppTab> = []
    var unreadValue: String?
    var surface: TabBarSurface = .page
    let onSelect: (AppTab) -> Void

    init(
        selected: AppTab,
        unread: Set<AppTab> = [],
        unreadValue: String? = nil,
        surface: TabBarSurface = .page,
        onSelect: @escaping (AppTab) -> Void
    ) {
        self.selected = selected
        self.unread = unread
        self.unreadValue = unreadValue
        self.surface = surface
        self.onSelect = onSelect
    }

    var body: some View {
        TabBar(items: items, selected: selected, surface: surface, onSelect: onSelect)
    }

    var items: [TabBarItem<AppTab>] {
        AppTab.allCases.map { tab in
            TabBarItem(
                id: tab,
                icon: tab.icon,
                accessibilityLabel: tab.accessibilityLabel,
                unreadValue: unread.contains(tab) ? (unreadValue ?? "") : nil
            )
        }
    }
}

extension AppTabBar {
    /// Yope-era signature. `avatarPath` is ignored: Retro's profile tab is a glyph (`icon.global.wall`), not the
    /// person's avatar (`size.global.tabBarAvatar` was removed).
    @available(*, deprecated, message: "Use AppTabBar(selected:unread:unreadValue:surface:onSelect:) — the profile tab is a glyph (C-04)")
    init(selected: AppTab, avatarPath: String?, onSelect: @escaping (AppTab) -> Void) {
        self.init(selected: selected, onSelect: onSelect)
    }
}

/// Yope's floating capsule tab bar is replaced by C-04.
@available(*, deprecated, renamed: "AppTabBar")
typealias FloatingTabBar = AppTabBar
