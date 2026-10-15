// Surface: settings.root — Settings. Reference: Apple HIG (lists and tables, settings; system surface); premium row from
// Locket's profile row (design/surfaces/settings.root.md). Reference images:
// references/auto/locket/lazyweb/locket-lazyweb-20260803-autocap-21.png (LZ21); HIG pages listed in the spec.
import AppData
import DesignSystem
import StoreKit
import SwiftUI

/// Native inset-grouped list (`settings.root.layout.list`, semantic system colours `color.global.system.ios`, built-in
/// text styles). No counts or badges on rows.
struct SettingsRootScreen: View {
    @Environment(AccountDependencies.self) private var dependencies
    @State private var isPremium = false
    @State private var showsManageSubscriptions = false
    @State private var signingOut = false

    var body: some View {
        List {
            premiumSection
            Section {
                NavigationLink(Copy.settingsRootNotifications, value: AppRoute.account(.settingsNotifications))
                NavigationLink(Copy.settingsRootAccount, value: AppRoute.account(.settingsAccount))
                    .accessibilityIdentifier("settings.root.account")
                NavigationLink(Copy.settingsRootBlocked, value: AppRoute.account(.settingsBlocked))
            }
            Section {
                linkRow(Copy.settingsRootPrivacy, url: dependencies.configuration.privacyURL)
                linkRow(Copy.settingsRootTerms, url: dependencies.configuration.termsURL)
                // "Contact Us" opens mail to the owner's support address, which config/app.json does not hold yet
                // (spec Gaps): the row is shown disabled until it exists.
                Button(Copy.settingsRootContact) {}
                    .disabled(true)
            }
            Section {
                Button(Copy.settingsRootSignOut) {
                    signingOut = true
                    Task { await dependencies.session.signOut() }
                }
                .disabled(signingOut)
                .accessibilityIdentifier("settings.root.signOut")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(Text(Copy.settingsRootTitle))
        .navigationBarTitleDisplayMode(.large)
        .opensLinksInAppBrowser()
        .manageSubscriptionsSheet(isPresented: $showsManageSubscriptions)
        .task {
            // Entitlement unknown → the not-subscribed row until `entitlements` loads.
            isPremium = dependencies.purchases.isPremium
            if let serverPremium = try? await dependencies.data.hasPremium() {
                isPremium = serverPremium || dependencies.purchases.isPremium
            }
        }
        .accessibilityIdentifier("settings.root")
    }

    /// Premium row → paywall (never counted as a prompt); "Manage Subscription" while premium is active. The row's
    /// title and subtitle name the app (`{app_name}`, BLOCKED): release builds omit the row until it is named.
    @ViewBuilder
    private var premiumSection: some View {
        if isPremium {
            Section {
                Button(Copy.settingsRootManageSubscription) { showsManageSubscriptions = true }
            }
        } else if let title = AccountBlockedCopy.premiumRowTitle {
            Section {
                Button {
                    dependencies.router.modal = .account(.paywall)
                } label: {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(title)
                                .foregroundStyle(.primary) // provenance-ok: system label colour (color.global.system.ios)
                            if let subtitle = AccountBlockedCopy.premiumRowSubtitle {
                                Text(subtitle)
                                    .font(.subheadline) // provenance-ok: system list subtitle style (layout.global.system.typography)
                                    .foregroundStyle(.secondary) // provenance-ok: system secondary label colour
                            }
                        }
                        Spacer(minLength: 0)
                        Image(systemName: Tokens.Icons.globalChevron)
                            .foregroundStyle(.tertiary) // provenance-ok: system disclosure indicator colour
                            .accessibilityHidden(true)
                    }
                }
            }
        }
    }

    /// A row that opens `url` in the in-app browser; disabled while config/app.json has no URL (owner, spec Gaps).
    private func linkRow(_ title: String, url: URL?) -> some View {
        Group {
            if let url {
                Link(title, destination: url)
            } else {
                Button(title) {}
                    .disabled(true)
            }
        }
    }
}
