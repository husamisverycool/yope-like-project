// Surface: settings.root — Settings. Visual reference: Retro Settings sheet
// (references/auto/retro/video/ig-DJXvmqRv2_N-referrals-sheet-f042-059.png frames 42–44, VID-SET: centred title + close
// circle, profile card in a Fill group, small grey section headers, grouped rows with grey subtitles and chevrons), the
// grouped row height (references/auto/retro/press/tc-2024-04-retro-journals-5.png, TC-J5) and the profile header pattern
// (references/auto/retro/store/retro-store-02.png, ST-02); section list from Retro's strings (APK `settings_*`)
// (design/surfaces/settings.root.md; MERGE RA-14).
import AppData
import AppModels
import DesignSystem
import StoreKit
import SwiftUI
import UIKit

/// settings.root: a page sheet with its own navigation (`settings.root.layout.list`); sub-pages push inside it with the
/// native back button and their centred title.
struct SettingsRootScreen: View {
    @Environment(AccountDependencies.self) private var dependencies
    @Environment(\.dismiss) private var dismiss
    @State private var path: [AppRoute] = []
    @State private var profile: Profile?
    @State private var isPremium = false
    @State private var premiumLoaded = false
    @State private var statuses: [SystemPermission: PermissionStatus] = [:]
    @State private var showsManageSubscriptions = false
    @State private var showsPaywall = false
    @State private var confirmSignOut = false
    @State private var signingOut = false
    @State private var link: BrowserLink?
    @Environment(\.openURL) private var openURL

    var body: some View {
        NavigationStack(path: $path) {
            VStack(spacing: 0) {
                SheetHeader(title: Copy.settingsRootTitle, closeAccessibilityLabel: Copy.settingsRootCloseAccessibilityLabel) {
                    dismiss()
                }
                SettingsList {
                    profileCard
                    subscriptionSection
                    SettingsGroup(header: Copy.settingsRootNotificationsHeader, rows: [
                        SettingsRow(Copy.settingsRootNotifications, kind: .navigation { path.append(.account(.settingsNotifications)) })
                            .accessibilityIdentifier("settings.root.notifications")
                            .asSettingsRow(),
                    ])
                    SettingsGroup(header: Copy.settingsRootWidgetsHeader, rows: [
                        SettingsRow(Copy.settingsRootWidgetsAdd, subtitle: Copy.settingsRootWidgetsDetail, kind: .navigation {
                            path.append(.account(.settingsWidgets))
                        })
                        .accessibilityIdentifier("settings.root.widgets")
                        .asSettingsRow(),
                    ])
                    SettingsGroup(header: Copy.settingsRootPrivacyHeader, rows: [
                        SettingsRow(Copy.settingsRootBlocked, kind: .navigation { path.append(.account(.settingsBlocked)) })
                            .accessibilityIdentifier("settings.root.blocked")
                            .asSettingsRow(),
                    ])
                    SettingsGroup(header: Copy.settingsRootPermissionsHeader, rows: SystemPermission.allCases.map { permission in
                        SettingsRow(
                            permission.title,
                            value: statuses[permission] == .denied ? Copy.settingsRootPermissionsDenied : nil,
                            kind: .navigation { openAppSettings() }
                        )
                        .asSettingsRow()
                    })
                    aboutSection
                    SettingsGroup(rows: [
                        SettingsRow(Copy.settingsRootSignOut, kind: signingOut ? SettingsRow.Kind.busy : SettingsRow.Kind.button(action: { confirmSignOut = true }))
                            .accessibilityIdentifier("settings.root.signOut")
                            .asSettingsRow(),
                    ])
                }
            }
            .background(Tokens.Colors.globalBackground.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: AppRoute.self) { route in
                RouteDestination(route: route)
            }
        }
        .environment(\.settingsPush) { route in path.append(route) }
        .dsSheetBackground()
        .sheet(item: $link) { link in
            SafariView(url: link.url)
                .ignoresSafeArea()
        }
        .fullScreenCover(isPresented: $showsPaywall) {
            PaywallScreen()
                .environment(dependencies)
                .environment(\.storageURLResolver, dependencies.storageURLResolver)
        }
        .manageSubscriptionsSheet(isPresented: $showsManageSubscriptions)
        .alert(Text(Copy.settingsRootSignOutTitle), isPresented: $confirmSignOut) {
            Button(Copy.settingsRootAlertCancel, role: .cancel) {}
            Button(Copy.settingsRootSignOutConfirm, role: .destructive) {
                signingOut = true
                Task { await dependencies.session.signOut() }
            }
        }
        .task { await load() }
        .accessibilityIdentifier("settings.root")
    }

    private func load() async {
        profile = try? await dependencies.data.myProfile()
        // Entitlement unknown → the row shows the activity indicator until `entitlements` answers.
        isPremium = dependencies.purchases.isPremium
        if let serverPremium = try? await dependencies.data.hasPremium() {
            isPremium = serverPremium || dependencies.purchases.isPremium
        }
        premiumLoaded = true
        for permission in SystemPermission.allCases {
            statuses[permission] = await dependencies.status(of: permission)
        }
    }

    // MARK: Profile card

    /// C-14 single row with C-19's content: the display name (`listTitle`), the phone number under it (`listSubtitle`,
    /// grey), the avatar `size.global.avatarProfile` at the trailing edge; the whole card → settings.account
    /// ("Edit Profile").
    private var profileCard: some View {
        SettingsGroup(rows: [
            SettingsCustomRow(action: { path.append(.account(.settingsAccount)) }) {
                HStack {
                    VStack(alignment: .leading) {
                        Text(profile?.displayName ?? "")
                            .dsTextStyle(TextRole.listTitle)
                            .foregroundStyle(Tokens.Colors.globalTextPrimary)
                        if let phone = dependencies.currentPhone() {
                            Text(phone)
                                .dsTextStyle(TextRole.listSubtitle)
                                .foregroundStyle(Tokens.Colors.globalTextSecondary)
                        }
                    }
                    .multilineTextAlignment(.leading)
                    Spacer(minLength: 0)
                    AvatarView(path: profile?.avatarPath, diameter: Tokens.Sizes.globalAvatarProfile)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityHint(Text(Copy.settingsRootAccount))
            .accessibilityIdentifier("settings.root.account")
            .asSettingsRow(),
        ])
    }

    // MARK: Subscription

    /// Non-subscriber: "{app_name} Premium" (BLOCKED until the app is named: release builds omit the row) with "Unlock
    /// more of what you love." → paywall (never counted as a prompt). Subscriber: "Your Subscription" → the system's
    /// subscription sheet. Loading: the row's value is the activity indicator.
    @ViewBuilder
    private var subscriptionSection: some View {
        if isPremium {
            SettingsGroup(header: Copy.settingsRootSubscriptionHeader, rows: [
                SettingsRow(Copy.settingsRootManageSubscription, kind: .navigation { showsManageSubscriptions = true })
                    .asSettingsRow(),
            ])
        } else if let title = AccountBlockedCopy.premiumRowTitle {
            SettingsGroup(header: Copy.settingsRootSubscriptionHeader, rows: [
                SettingsRow(title, subtitle: Copy.settingsRootPremiumSubtitle, kind: .navigation { showsPaywall = true }, valueIsBusy: !premiumLoaded)
                    .accessibilityIdentifier("settings.root.premium")
                    .asSettingsRow(),
            ])
        }
    }

    // MARK: About

    /// Contact Us (mail to the owner's support address, not configured yet: disabled), Privacy Policy and Terms of Use (the
    /// in-app browser; disabled while config/app.json has no URL), Version (static value).
    private var aboutSection: some View {
        SettingsGroup(header: Copy.settingsRootAboutHeader, rows: [
            SettingsRow(Copy.settingsRootContact, kind: .button {}, isEnabled: false).asSettingsRow(),
            legalRow(Copy.settingsRootPrivacy, url: dependencies.configuration.privacyURL),
            legalRow(Copy.settingsRootTerms, url: dependencies.configuration.termsURL),
            SettingsRow(Copy.settingsRootVersion, value: Self.appVersion, kind: .value).asSettingsRow(),
        ])
    }

    private func legalRow(_ title: String, url: URL?) -> AnyView {
        SettingsRow(title, kind: .navigation { if let url { link = BrowserLink(url: url) } }, isEnabled: url != nil)
            .asSettingsRow()
    }

    /// The app's version (`CFBundleShortVersionString`).
    static var appVersion: String? {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String // provenance-ok: Info.plist key
    }

    /// The app's page in system Settings (`UIApplication.openSettingsURLString`).
    private func openAppSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
    }
}

/// onboarding.widget opened from settings.root → Widgets: the same page with the C-02 back chevron; "Next" returns too.
struct SettingsWidgetsPage: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        WidgetGuideRoute(onBack: { dismiss() }, onContinue: { dismiss() })
    }
}
