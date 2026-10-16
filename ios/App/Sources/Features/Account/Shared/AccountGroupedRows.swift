// Account group — C-14 grouped sections for the settings surfaces (settings.root, settings.notifications,
// settings.account, settings.blocked, groups.settings) and the auth.agegate opt-in row: C-14's group (fill
// `color.global.control`, corners `radius.global.groupedRow`, hairline between rows, inset `size.global.screenMargin`,
// header and footer in text role `meta`) with rows of at least `settings.root.size.rowHeight` (the 58.7 pt grouped row
// measured on TC-J5, MERGE RA-14). A local variant of `GroupedSection` / `GroupedRow` (Components/GroupedSection.swift):
// the component's rows take a 44-pt minimum and cannot hold a trailing value, an avatar or a capsule (reported as a
// component gap). Shared with the App Clip (auth.agegate).
import DesignSystem
import SwiftUI

/// One row of a `SettingsGroup`.
struct SettingsRow: View {
    enum Kind {
        /// Title (+ subtitle) (+ trailing value), `icon.global.chevron`; the row is a button.
        case navigation(action: () -> Void)
        /// Title + trailing value; static text (version, phone number).
        case value
        /// Title (+ subtitle) + a native switch (tint `color.global.selection`); the whole row toggles.
        case toggle(Binding<Bool>)
        /// Title in `color.global.destructive` (C-10) with an optional leading glyph; the row is a button.
        case destructive(action: () -> Void)
        /// The platform activity indicator (C-28) in the row (loading, signing out).
        case busy
    }

    let title: String
    var subtitle: String?
    var value: String?
    var icon: String?
    let kind: Kind
    var isEnabled: Bool = true
    /// The row's trailing value is the platform activity indicator (C-28) instead of `value`.
    var valueIsBusy: Bool = false

    init(_ title: String, subtitle: String? = nil, value: String? = nil, icon: String? = nil, kind: Kind, isEnabled: Bool = true, valueIsBusy: Bool = false) {
        self.title = title
        self.subtitle = subtitle
        self.value = value
        self.icon = icon
        self.kind = kind
        self.isEnabled = isEnabled
        self.valueIsBusy = valueIsBusy
    }

    var body: some View {
        switch kind {
        case let .toggle(isOn):
            Toggle(isOn: isOn) { labels }
                .tint(Tokens.Colors.globalSelection)
                .disabled(!isEnabled)
                .modifier(SettingsRowFrame())
        case let .navigation(action), let .destructive(action):
            Button(action: action) {
                HStack {
                    labels
                    Spacer(minLength: 0)
                    trailingValue
                    if case .navigation = kind {
                        Glyph(Tokens.Icons.globalChevron, relativeTo: TextRole.body.relativeTo)
                            .foregroundStyle(Tokens.Colors.globalTextSecondary)
                    }
                }
                .modifier(SettingsRowFrame())
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!isEnabled)
        case .value:
            HStack {
                labels
                Spacer(minLength: 0)
                trailingValue
            }
            .modifier(SettingsRowFrame())
            .accessibilityElement(children: .combine)
        case .busy:
            HStack {
                labels
                Spacer(minLength: 0)
                LoadingHUD()
            }
            .modifier(SettingsRowFrame())
        }
    }

    private var isDestructive: Bool {
        if case .destructive = kind { return true }
        return false
    }

    private var titleColor: Color {
        if isDestructive { return Tokens.Colors.globalDestructive }
        return isEnabled ? Tokens.Colors.globalTextPrimary : Tokens.Colors.globalTextTertiary
    }

    @ViewBuilder
    private var trailingValue: some View {
        if valueIsBusy {
            LoadingHUD()
        } else if let value {
            Text(value)
                .dsTextStyle(TextRole.listSubtitle)
                .foregroundStyle(Tokens.Colors.globalTextSecondary)
                .multilineTextAlignment(.trailing)
        }
    }

    private var labels: some View {
        HStack {
            if let icon {
                Glyph(icon, relativeTo: TextRole.body.relativeTo)
                    .foregroundStyle(titleColor)
            }
            VStack(alignment: .leading) {
                Text(title)
                    .dsTextStyle(TextRole.body)
                    .foregroundStyle(titleColor)
                if let subtitle {
                    Text(subtitle)
                        .dsTextStyle(TextRole.meta)
                        .foregroundStyle(Tokens.Colors.globalTextSecondary)
                }
            }
            .multilineTextAlignment(.leading)
        }
    }
}

/// C-14 row padding (the platform's 16, as `GroupedRow`) and the settings row height `settings.root.size.rowHeight`
/// (a minimum: rows grow with Dynamic Type).
struct SettingsRowFrame: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding()
            .frame(maxWidth: .infinity, minHeight: Tokens.Sizes.settingsRootSizeRowHeight, alignment: .leading)
    }
}

/// A C-14 row whose content is drawn by the caller (a member row, a profile card, a capsule row), with the row padding
/// and height of `SettingsRow`. `action` makes the whole row a button.
struct SettingsCustomRow<Content: View>: View {
    var action: (() -> Void)?
    @ViewBuilder let content: () -> Content

    init(action: (() -> Void)? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.action = action
        self.content = content
    }

    var body: some View {
        if let action {
            Button(action: action) {
                content()
                    .modifier(SettingsRowFrame())
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        } else {
            content()
                .modifier(SettingsRowFrame())
        }
    }
}

/// A C-14 group: optional header (text role `meta`, `color.global.textSecondary`, header trait), the rows in one
/// rounded group with hairlines between them, an optional footer (text role `meta`, `color.global.textSecondary`), inset
/// `size.global.screenMargin` from the screen edges. Header → group and group → footer spacing were not measured (C-14
/// Gap): platform stack spacing, as `GroupedSection`.
struct SettingsGroup: View {
    var header: String?
    var footer: [String]
    let rows: [AnyView]

    init(header: String? = nil, footer: [String] = [], rows: [AnyView]) {
        self.header = header
        self.footer = footer
        self.rows = rows
    }

    var body: some View {
        VStack(alignment: .leading) {
            if let header {
                Text(header)
                    .dsTextStyle(TextRole.meta)
                    .foregroundStyle(Tokens.Colors.globalTextSecondary)
                    .accessibilityAddTraits(.isHeader)
                    .padding(.horizontal)
            }
            VStack(spacing: 0) {
                ForEach(rows.indices, id: \.self) { index in
                    if index > 0 {
                        HairlineDivider()
                    }
                    rows[index]
                }
            }
            .background(Tokens.Colors.globalControl)
            .clipShape(DSShape.rounded(Tokens.Radii.globalGroupedRow))
            ForEach(footer.indices, id: \.self) { index in
                Text(footer[index])
                    .dsTextStyle(TextRole.meta)
                    .foregroundStyle(Tokens.Colors.globalTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal)
            }
        }
        .padding(.horizontal, Tokens.Sizes.globalScreenMargin)
    }
}

/// Settings sections stacked `size.global.sectionGap` apart (`settings.root.layout.list` sectionGap) in a scroll view on
/// `color.global.background`.
struct SettingsList<Content: View>: View {
    @ViewBuilder let content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Tokens.Sizes.globalSectionGap) {
                content()
            }
            .padding(.vertical, Tokens.Sizes.globalTitleToContent)
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(Tokens.Colors.globalBackground.ignoresSafeArea())
    }
}

extension View {
    /// The view as a row of a `SettingsGroup`.
    func asSettingsRow() -> AnyView {
        AnyView(self)
    }
}
