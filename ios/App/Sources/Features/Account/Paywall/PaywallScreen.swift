// Surface: paywall — the Premium screen. Visual reference: Retro Premium paywall
// (references/auto/retro/lazyweb/retro-lazyweb-20260529-paywall.png, PAY — RAW iOS: blurred colour-rich backdrop, title
// row with the glass close circle, the benefit's media card, serif headline + description, a pager of plan cards with a
// black 60-pt capsule, footer) and Retro's membership strings (references/auto/retro/apk/
// retro-android-2026.10.1150-strings.txt `retro_membership_paywall_*`). Purchases: StoreKit through RevenueCat
// (design/surfaces/paywall.md; MERGE RA-17, RA-18).
import AppData
import AppModels
import DesignSystem
import Observation
import SwiftUI

/// The paywall's text styles: plan-card roles from `paywall.fontSize.*` / `paywall.fontWeight.*` (the weights PAY did not
/// tokenise take the global role of the same text: body for the subtitle and footnote, textButton for the bullets).
enum PaywallStyle {
    private static func style(_ size: CGFloat, _ weight: Font.Weight, _ textStyle: Font.TextStyle) -> DSTextStyle {
        DSTextStyle(family: Tokens.Fonts.globalFamily, size: size, weight: weight, relativeTo: textStyle)
    }

    /// 'Annual' / 'Monthly': `paywall.fontSize.planTitle`, `paywall.fontWeight.planTitle`, title2.
    static let planTitle = style(Tokens.FontSizes.paywallFontSizePlanTitle, Tokens.FontWeights.paywallFontWeightPlanTitle, .title2)
    static let planSubtitle = style(Tokens.FontSizes.paywallFontSizePlanSubtitle, Tokens.FontWeights.fontWeightGlobalBody, .subheadline)
    static let planBullet = style(Tokens.FontSizes.paywallFontSizePlanBullet, Tokens.FontWeights.fontWeightGlobalTextButton, .body)
    static let planPrice = style(Tokens.FontSizes.paywallFontSizePlanPrice, Tokens.FontWeights.paywallFontWeightPlanPrice, .title2)
    static let planFootnote = style(Tokens.FontSizes.paywallFontSizePlanFootnote, Tokens.FontWeights.fontWeightGlobalBody, .subheadline)
}

/// One benefit page of the paywall (this app's perks only, directive Part 6).
enum PaywallPerk: String, CaseIterable, Identifiable {
    case video
    case history
    case widgets
    case export

    var id: String { rawValue }

    var title: String {
        switch self {
        case .video: return Copy.paywallPerkVideoTitle
        case .history: return Copy.paywallPerkHistoryTitle
        case .widgets: return Copy.paywallPerkWidgetsTitle
        case .export: return Copy.paywallPerkExportTitle
        }
    }

    var subtitle: String {
        switch self {
        case .video: return Copy.paywallPerkVideoSubtitle
        case .history: return Copy.paywallPerkHistorySubtitle
        case .widgets: return Copy.paywallPerkWidgetsSubtitle
        case .export: return Copy.paywallPerkExportSubtitle
        }
    }

    /// The perks listed: unlimited history only while the free history window is set (`free_history_days`).
    static func listed(showsHistory: Bool) -> [PaywallPerk] {
        allCases.filter { $0 != .history || showsHistory }
    }
}

/// `AccountModal.paywall` (full screen).
struct PaywallScreen: View {
    @Environment(AccountDependencies.self) private var dependencies

    var body: some View {
        PaywallView(model: PaywallModel(purchases: dependencies.purchases, data: dependencies.data))
    }
}

struct PaywallView: View {
    @State private var model: PaywallModel
    @State private var photo: PhotoSource?
    @State private var perkID: String?
    @State private var link: BrowserLink?
    @Environment(AccountDependencies.self) private var dependencies
    @Environment(\.dismiss) private var dismiss

    /// - Parameter photo: the benefit media (tests); the newest photo from the person's groups otherwise.
    init(model: PaywallModel, photo: PhotoSource? = nil) {
        _model = State(initialValue: model)
        _photo = State(initialValue: photo)
    }

    private static let reveal = DSAnimation.timing(duration: Tokens.Durations.globalPageTransition, easing: Tokens.Easings.globalStandard)
    private static let pageFade = DSAnimation.timing(duration: Tokens.Durations.globalFade, easing: Tokens.Easings.globalStandard)

    private var perks: [PaywallPerk] { PaywallPerk.listed(showsHistory: model.showsHistoryPerk) }

    var body: some View {
        ZStack {
            // The benefit's media blurred to a colour field (`layout.global.colourFieldBackdrop`, L-9); none → the media black.
            ColourFieldBackdrop(source: photo)
                .environment(\.colorScheme, .dark)
                .dsAnimation(Self.pageFade, value: perkID)
            VStack(spacing: 0) {
                header
                if let welcome = model.welcome {
                    welcomeBlock(welcome)
                        .transition(.opacity)
                } else {
                    VStack(spacing: 0) {
                        benefits
                        plansArea
                            .padding(.top, Tokens.Sizes.globalTitleToContent)
                        footer
                    }
                    .transition(.opacity)
                }
            }
        }
        .dsAnimation(Self.reveal, value: model.welcome)
        .sheet(item: $link) { link in
            SafariView(url: link.url)
                .ignoresSafeArea()
        }
        .task {
            if dependencies.purchases.isPremium {
                close()
                return
            }
            if photo == nil, let newest = await NewestGroupPhoto.load(from: dependencies.data) {
                photo = .storage(newest.path)
            }
            await model.load()
        }
        .dsHaptic(Tokens.Haptics.globalSuccess, trigger: model.successCount)
        .dsHaptic(Tokens.Haptics.globalError, trigger: model.errorCount)
        .dsHaptic(Tokens.Haptics.globalSelect, trigger: perkID)
        .dsHaptic(Tokens.Haptics.globalSelect, trigger: model.selectedPlanID)
        .formErrorAlert(model.alertMessage, trigger: model.alertCount)
        .accessibilityIdentifier("paywall")
    }

    // MARK: Header

    /// The title (text role `sheetTitle`, `color.global.textOnMedia`; "{app_name} Premium" — BLOCKED until the app is named,
    /// omitted in release) centred, the glass close circle (C-11 `.glassSmall`, always visible) at the trailing margin.
    private var header: some View {
        ZStack {
            if let title = AccountBlockedCopy.paywallTitle {
                Text(title)
                    .dsTextStyle(TextRole.sheetTitle)
                    .foregroundStyle(Tokens.Colors.globalTextOnMedia)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
                    .padding(.horizontal, Tokens.Sizes.globalCircleButtonSmall)
            }
            HStack {
                Spacer(minLength: 0)
                CircleButton(icon: Tokens.Icons.globalClose, accessibilityLabel: Copy.paywallCloseAccessibilityLabel, style: .glassSmall) {
                    close()
                }
                .accessibilityIdentifier("paywall.close")
            }
        }
        .frame(minHeight: Tokens.Sizes.globalMinTouchTargetIos)
        .padding(.horizontal, Tokens.Sizes.globalScreenMargin)
    }

    // MARK: Benefits

    /// One page per perk (swipe), centred in the space between the header and the plans: the media card
    /// (`paywall.size.mediaCardWidth`, `paywall.radius.mediaCard`, aspect-fill, its bottom `paywall.size.mediaCardFade`
    /// fading into the backdrop; none without a photo), the headline
    /// `size.global.titleToContent` below it (display serif `displayMedium`, white), the description under it
    /// (`textButton`, white, ≤ 2 lines); page dots (C-31 on media) under the pages.
    private var benefits: some View {
        VStack(spacing: Tokens.Sizes.globalSectionHeaderToContent) {
            TabView(selection: Binding(get: { perkID ?? perks.first?.id }, set: { perkID = $0 })) {
                ForEach(perks) { perk in
                    benefitPage(perk)
                        .tag(Optional(perk.id))
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            if perks.count > 1 {
                let index = perks.firstIndex { $0.id == (perkID ?? perks.first?.id) } ?? 0
                PageDots(
                    count: perks.count,
                    index: index,
                    onMedia: true,
                    accessibilityValue: Copy.globalA11yPagePosition(position: String(index + 1), count: String(perks.count))
                ) { page in perkID = perks[page].id }
            }
        }
        .frame(maxHeight: .infinity)
    }

    private func benefitPage(_ perk: PaywallPerk) -> some View {
        MetricStack(alignment: .center) {
            if let photo {
                // Retro's card is ≈ 248 × 183 (PAY): no height token — the C-15 cover proportion turned landscape.
                let height = Tokens.Sizes.paywallSizeMediaCardWidth * Tokens.Sizes.globalRowThumbWidth / Tokens.Sizes.globalRowThumbHeight
                PhotoView(source: photo)
                    .frame(width: Tokens.Sizes.paywallSizeMediaCardWidth, height: height)
                    .clipShape(DSShape.rounded(Tokens.Radii.paywallRadiusMediaCard))
                    .mask { MediaCardFade(height: height) }
                    .accessibilityHidden(true)
            }
            VStack {
                Text(perk.title)
                    .dsTextStyle(TextRole.displayMedium)
                    .accessibilityAddTraits(.isHeader)
                Text(perk.subtitle)
                    .dsTextStyle(TextRole.textButton)
                    .lineLimit(2)
            }
            .foregroundStyle(Tokens.Colors.globalTextOnMedia)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .capHeight(of: TextRole.displayMedium)
            .padding(.horizontal, Tokens.Sizes.globalButtonMarginH)
            .metricGap(photo == nil ? 0 : Tokens.Sizes.globalTitleToContent, from: .bottom, to: .capTop)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: Plans

    @ViewBuilder
    private var plansArea: some View {
        switch model.plansPhase {
        case .unavailable, .offline:
            // The card pager is replaced by one line and the C-09 light pill.
            VStack(spacing: Tokens.Sizes.globalSectionHeaderToContent) {
                Text(model.plansPhase == .offline ? Copy.paywallOffline : Copy.paywallErrorProducts)
                    .dsTextStyle(TextRole.body)
                    .foregroundStyle(Tokens.Colors.globalTextOnMedia)
                    .multilineTextAlignment(.center)
                LightPill(Copy.paywallRetry) { Task { await model.loadPlans() } }
                    .accessibilityIdentifier("paywall.retry")
            }
            .padding(.horizontal, Tokens.Sizes.globalButtonMarginH)
        case .loading, .loaded:
            planPager
        }
    }

    /// Annual (first) and Monthly cards, width = screen − 2 × `size.global.buttonMarginH`, the next card peeking after
    /// `size.global.planCardGap`; the card in view is the selected plan.
    private var planPager: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: Tokens.Sizes.globalPlanCardGap) {
                ForEach([PlanOption.Period.year, PlanOption.Period.month], id: \.self) { period in
                    PlanCard(
                        period: period,
                        plan: model.plan(for: period),
                        isLoading: model.plansPhase == .loading,
                        isPurchasing: model.isPurchasing && model.selectedPlan?.period == period
                    ) {
                        if let plan = model.plan(for: period) {
                            model.select(plan)
                            Task { await model.purchase() }
                        }
                    }
                    .containerRelativeFrame(.horizontal)
                    .id(model.plan(for: period)?.id)
                }
            }
            .scrollTargetLayout()
        }
        .contentMargins(.horizontal, Tokens.Sizes.globalButtonMarginH, for: .scrollContent)
        .scrollTargetBehavior(.viewAligned)
        .scrollPosition(id: $model.selectedPlanID)
        .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: Footer

    /// "Cancel anytime. No questions asked.", the visible plan's billing line, then Restore · Terms · Privacy (C-08 in the
    /// footer's style: text role `caption`, `color.global.textOnMedia`, hit areas ≥ `size.global.minTouchTarget.ios`).
    private var footer: some View {
        VStack(spacing: 0) {
            Text(Copy.paywallFooter)
            if let line = model.billingLine {
                Text(line)
            }
            HStack {
                footerButton(Copy.paywallRestore) { Task { await model.restore() } }
                    .accessibilityIdentifier("paywall.restore")
                footerButton(Copy.paywallTerms) { open(dependencies.configuration.termsURL) }
                    .disabled(dependencies.configuration.termsURL == nil)
                footerButton(Copy.paywallPrivacy) { open(dependencies.configuration.privacyURL) }
                    .disabled(dependencies.configuration.privacyURL == nil)
            }
        }
        .dsTextStyle(TextRole.caption)
        .foregroundStyle(Tokens.Colors.globalTextOnMedia)
        .multilineTextAlignment(.center)
        .padding(.horizontal, Tokens.Sizes.globalScreenMargin)
        .padding(.top, Tokens.Sizes.globalSectionHeaderToContent)
    }

    private func footerButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .dsTextStyle(TextRole.caption)
                .foregroundStyle(Tokens.Colors.globalTextOnMedia)
                .frame(minWidth: Tokens.Sizes.globalMinTouchTargetIos, minHeight: Tokens.Sizes.globalMinTouchTargetIos)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func open(_ url: URL?) {
        if let url { link = BrowserLink(url: url) }
    }

    // MARK: Welcome

    /// Success / restored: the benefits and plans cross-fade (`duration.global.pageTransition`) to the welcome block on
    /// the same backdrop — headline (`displayMedium`, white), body (`textButton`, white), the C-09 light pill "Done".
    private func welcomeBlock(_ welcome: PaywallModel.Welcome) -> some View {
        VStack(spacing: Tokens.Sizes.globalTitleToContent) {
            Spacer(minLength: 0)
            VStack {
                Text(welcome == .restored ? Copy.paywallRestoreDone : Copy.paywallWelcomeTitle)
                    .dsTextStyle(TextRole.displayMedium)
                    .accessibilityAddTraits(.isHeader)
                Text(Copy.paywallWelcomeBody)
                    .dsTextStyle(TextRole.textButton)
            }
            .foregroundStyle(Tokens.Colors.globalTextOnMedia)
            .multilineTextAlignment(.center)
            .padding(.horizontal, Tokens.Sizes.globalButtonMarginH)
            LightPill(Copy.paywallWelcomeDone) {
                model.welcomeDismissed()
                close()
            }
            .accessibilityIdentifier("paywall.welcome.done")
            Spacer(minLength: 0)
        }
        .accessibilityIdentifier("paywall.welcome")
    }

    private func close() {
        if case .account(.paywall)? = dependencies.router.modal {
            dependencies.router.modal = nil
        } else {
            dismiss()
        }
    }
}

/// A plan card (`paywall.layout.planCard`): fill `color.global.surfaceLight` in both appearances, corners
/// `radius.global.cardLarge`, padding `size.global.planCardPadding`; title + the premium pill (C-25) on a plan with a free
/// trial; subtitle; the two bullets (no marker); price; footnote; then C-05 with the light values pinned (#000000 /
/// #FFFFFF), `size.global.screenMargin` from the card's sides and bottom. Loading: the price and footnote are the
/// platform indicator in `paywall.color.planTextTertiary` and the capsule is disabled.
struct PlanCard: View {
    let period: PlanOption.Period
    let plan: PlanOption?
    let isLoading: Bool
    let isPurchasing: Bool
    let onSubscribe: () -> Void

    private var isYearly: Bool { period == .year }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading) {
                HStack(alignment: .center) {
                    Text(isYearly ? Copy.paywallPlansYearlyTitle : Copy.paywallPlansMonthlyTitle)
                        .dsTextStyle(PaywallStyle.planTitle)
                        .foregroundStyle(Tokens.Colors.paywallColorPlanText)
                    Spacer(minLength: 0)
                    if plan?.trialDuration != nil {
                        PremiumPill(label: Copy.paywallPlansTrialBadge)
                    }
                }
                Text(isYearly ? Copy.paywallPlansYearlySubtitle : Copy.paywallPlansMonthlySubtitle)
                    .dsTextStyle(PaywallStyle.planSubtitle)
                    .foregroundStyle(Tokens.Colors.paywallColorPlanTextSecondary)
                VStack(alignment: .leading, spacing: 0) {
                    Text(isYearly ? Copy.paywallPlansYearlyBullet1 : Copy.paywallPlansMonthlyBullet1)
                    Text(isYearly ? Copy.paywallPlansYearlyBullet2 : Copy.paywallPlansMonthlyBullet2)
                }
                .dsTextStyle(PaywallStyle.planBullet)
                .foregroundStyle(Tokens.Colors.paywallColorPlanText)
                if let plan, !isLoading {
                    Text(isYearly ? Copy.paywallPlansYearlyPrice(yearlyPrice: plan.price) : Copy.paywallPlansMonthlyPrice(monthlyPrice: plan.price))
                        .dsTextStyle(PaywallStyle.planPrice)
                        .foregroundStyle(Tokens.Colors.paywallColorPlanText)
                    Text(footnote(plan))
                        .dsTextStyle(PaywallStyle.planFootnote)
                        .foregroundStyle(Tokens.Colors.paywallColorPlanTextTertiary)
                } else {
                    ProgressView()
                        .tint(Tokens.Colors.paywallColorPlanTextTertiary)
                        .accessibilityLabel(Text(Copy.globalA11yLoading))
                }
            }
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .padding(Tokens.Sizes.globalPlanCardPadding)
            PrimaryButton(
                plan?.trialDuration.map { Copy.paywallPlansTrialCta(trialDuration: $0) } ?? Copy.paywallPlansSubscribe,
                isEnabled: plan != nil && !isLoading,
                isBusy: isPurchasing,
                action: onSubscribe
            )
            .accessibilityIdentifier("paywall.subscribe")
            .padding(.horizontal, Tokens.Sizes.globalScreenMargin)
            .padding(.bottom, Tokens.Sizes.globalScreenMargin)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Tokens.Colors.globalSurfaceLight, in: DSShape.rounded(Tokens.Radii.globalCardLarge))
        // The card and its capsule keep their light values in both appearances (PAY, `paywall.layout.planCard`).
        .environment(\.colorScheme, .light)
        .accessibilityElement(children: .contain)
    }

    /// `paywall.plans.*.detail` ("Billed {price} …"), or `.trialDetail` on a plan with a free trial.
    private func footnote(_ plan: PlanOption) -> String {
        switch (isYearly, plan.trialDuration != nil) {
        case (true, false): return Copy.paywallPlansYearlyDetail(yearlyPrice: plan.price)
        case (true, true): return Copy.paywallPlansYearlyTrialDetail(yearlyPrice: plan.price)
        case (false, false): return Copy.paywallPlansMonthlyDetail(monthlyPrice: plan.price)
        case (false, true): return Copy.paywallPlansMonthlyTrialDetail(monthlyPrice: plan.price)
        }
    }
}

/// The media card's alpha mask: opaque down to `paywall.size.mediaCardFade` above the bottom edge, then a linear ramp to
/// clear at the edge (Retro's card fades into the paywall backdrop, PAY). Only the mask's alpha counts.
private struct MediaCardFade: View {
    let height: CGFloat

    var body: some View {
        LinearGradient(
            stops: [
                Gradient.Stop(color: Tokens.Colors.globalBackgroundDeep, location: 0),
                Gradient.Stop(color: Tokens.Colors.globalBackgroundDeep, location: max(0, 1 - Tokens.Sizes.paywallSizeMediaCardFade / height)),
                Gradient.Stop(color: .clear, location: 1),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}
