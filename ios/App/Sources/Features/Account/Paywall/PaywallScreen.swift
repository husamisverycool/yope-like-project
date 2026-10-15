// Surface: paywall — premium screen and perks; plan sheet; welcome sheet. Reference app: Locket (Gold) for layout,
// palette and voice; store-required elements from Apple (design/surfaces/paywall.md). Reference images:
// references/auto/locket/mobbin/locket-mobbin-paywall-screen.png (MB), locket-mobbin-gold-flow-2.png … -6.png (MB2–6),
// references/auto/locket/lazyweb/locket-lazyweb-20260803-cap-plan-picker.png (LZP), …-autocap-21.png (LZ21), …-autocap-25.png (LZ25).
import AppData
import AppModels
import DesignSystem
import Observation
import SwiftUI

@MainActor
@Observable
final class PaywallModel {
    enum PlansPhase: Equatable {
        case loading
        case loaded
        case unavailable
        case offline
    }

    private(set) var plans: [PlanOption] = []
    private(set) var plansPhase: PlansPhase = .loading
    /// Yearly by default (Locket's default selection).
    var selectedPlanID: String?
    private(set) var isPurchasing = false
    /// Under Subscribe: `paywall.error.purchase` / `paywall.pending`.
    private(set) var purchaseMessage: String?
    /// In the legal block: `paywall.restore.done` / `.none`.
    private(set) var restoreMessage: String?
    private(set) var showsWelcome = false
    /// The history perk is listed only while the free history window is set (`free_history_days`, SPEC_FLAGS T1).
    private(set) var showsHistoryPerk = false
    private(set) var successCount = 0
    private(set) var errorCount = 0

    private let purchases: PurchasesProviding
    private let data: AccountDataSource

    init(purchases: PurchasesProviding, data: AccountDataSource) {
        self.purchases = purchases
        self.data = data
    }

    var selectedPlan: PlanOption? { plans.first { $0.id == selectedPlanID } }

    func load() async {
        if let config = try? await data.publicConfig() { showsHistoryPerk = config.freeHistoryDays != nil }
        await loadPlans()
    }

    func loadPlans() async {
        plansPhase = .loading
        do {
            plans = try await purchases.plans()
            selectedPlanID = (plans.first { $0.period == .year } ?? plans.first)?.id
            plansPhase = .loaded
        } catch {
            plansPhase = (error as? PurchasesFailure) == .offline ? .offline : .unavailable
        }
    }

    func select(_ plan: PlanOption) {
        selectedPlanID = plan.id
    }

    /// Subscribe: success → welcome sheet; cancelled → nothing; pending → message; failure → message.
    func purchase() async {
        guard let plan = selectedPlan, !isPurchasing else { return }
        purchaseMessage = nil
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            switch try await purchases.purchase(plan) {
            case .purchased:
                successCount += 1
                showsWelcome = true
            case .cancelled:
                break
            case .pending:
                purchaseMessage = Copy.paywallPending
            }
        } catch {
            errorCount += 1
            purchaseMessage = Copy.paywallErrorPurchase
        }
    }

    func restore() async {
        restoreMessage = nil
        do {
            if try await purchases.restore() {
                successCount += 1
                restoreMessage = Copy.paywallRestoreDone
            } else {
                restoreMessage = Copy.paywallRestoreNone
            }
        } catch {
            errorCount += 1
            restoreMessage = (error as? PurchasesFailure) == .offline ? Copy.paywallOffline : Copy.paywallRestoreNone
        }
    }

    func welcomeDismissed() {
        showsWelcome = false
    }

    /// The legal billing line of the selected plan: `paywall.legal.billing.ios` ({price}, {period}).
    var billingLine: String? {
        guard let plan = selectedPlan, let unit = plan.periodUnit else { return nil }
        return Copy.paywallLegalBillingIos(price: plan.price, period: unit.lowercased())
    }

    func seed(plans: [PlanOption], phase: PlansPhase, showsHistoryPerk: Bool = false) {
        self.plans = plans
        plansPhase = phase
        selectedPlanID = (plans.first { $0.period == .year } ?? plans.first)?.id
        self.showsHistoryPerk = showsHistoryPerk
    }
}

/// Text styles of the paywall (sizes and colours from `paywall.*`; weights from the spec where no weight token exists).
enum PaywallStyle {
    private static func style(_ size: CGFloat, _ weight: Font.Weight, _ textStyle: Font.TextStyle, lineHeight: CGFloat? = nil) -> DSTextStyle {
        DSTextStyle(family: Tokens.Fonts.globalFamily, size: size, weight: weight, relativeTo: textStyle, lineHeight: lineHeight)
    }

    /// `paywall.fontSize.title`, bold (spec), title1.
    static let title = style(Tokens.FontSizes.paywallFontSizeTitle, Font.Weight.bold, .title)
    /// `paywall.fontSize.subtitle` / `.lineHeight.subtitle`, regular, body.
    static let subtitle = style(Tokens.FontSizes.paywallFontSizeSubtitle, Font.Weight.regular, .body, lineHeight: Tokens.LineHeights.paywallLineHeightSubtitle)
    static let perkTitle = style(Tokens.FontSizes.paywallFontSizePerkTitle, Tokens.FontWeights.paywallFontWeightPerkTitle, .headline)
    static let perkSubtitle = style(Tokens.FontSizes.paywallFontSizePerkSubtitle, Font.Weight.regular, .subheadline)
    /// Perk emoji at `paywall.size.perkIcon`.
    static let perkIcon = style(Tokens.Sizes.paywallSizePerkIcon, Font.Weight.regular, .headline)
    /// `paywall.fontSize.ctaLabel`, bold (spec), headline.
    static let cta = style(Tokens.FontSizes.paywallFontSizeCtaLabel, Font.Weight.bold, .headline)
    static let dismiss = style(Tokens.FontSizes.paywallFontSizeDismiss, Font.Weight.regular, .callout)
    /// Legal block: global caption role; link labels at `paywall.fontWeight.perkTitle` (approximation, spec).
    static let legal = TextRole.caption
    static let legalLink = style(Tokens.FontSizes.globalCaption, Tokens.FontWeights.paywallFontWeightPerkTitle, .caption, lineHeight: Tokens.LineHeights.globalCaption)
    /// `paywall.fontSize.planSheetTitle` / `.lineHeight.planSheetTitle`, bold (Locket), title2.
    static let planSheetTitle = style(Tokens.FontSizes.paywallFontSizePlanSheetTitle, Font.Weight.bold, .title2, lineHeight: Tokens.LineHeights.paywallLineHeightPlanSheetTitle)
    static let planName = style(Tokens.FontSizes.paywallFontSizePlanName, Font.Weight.bold, .headline)
    static let planPrice = style(Tokens.FontSizes.paywallFontSizePlanPrice, Font.Weight.bold, .headline)
    static let planDetail = style(Tokens.FontSizes.paywallFontSizePlanDetail, Font.Weight.regular, .subheadline)
    /// `paywall.fontSize.subscribeLabel` at the global button weight (`fontWeight.global.button`; Locket's not measured), title3.
    static let subscribe = style(Tokens.FontSizes.paywallFontSizeSubscribeLabel, Tokens.FontWeights.fontWeightGlobalButton, .title3)
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
    @State private var showsPlans = false
    @Environment(AccountDependencies.self) private var dependencies

    init(model: PaywallModel) {
        _model = State(initialValue: model)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Tokens.Sizes.paywallSizePerkGap) {
                header
                perks
                legalBlock
            }
            .padding(.horizontal, Tokens.Sizes.paywallSizePerkMarginH)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) { pinnedActions }
        .background(background.ignoresSafeArea())
        .opensLinksInAppBrowser()
        .sheet(isPresented: $showsPlans) {
            PlanSheet(model: model, onClose: close)
        }
        .task {
            if dependencies.purchases.isPremium {
                close()
                return
            }
            await model.load()
        }
        .dsHaptic(Tokens.Haptics.globalSuccess, trigger: model.successCount)
        .dsHaptic(Tokens.Haptics.globalError, trigger: model.errorCount)
        .accessibilityIdentifier("paywall")
    }

    /// Vertical gradient through the four stops at the screen-height fractions named by the tokens' elements.
    private var background: some View {
        LinearGradient(
            stops: [
                .init(color: Tokens.Colors.paywallColorBackgroundTop, location: 0.078), // provenance-ok: stop position of paywall.color.backgroundTop
                .init(color: Tokens.Colors.paywallColorBackgroundUpper, location: 0.274), // provenance-ok: stop position of paywall.color.backgroundUpper
                .init(color: Tokens.Colors.paywallColorBackgroundLower, location: 0.587), // provenance-ok: stop position of paywall.color.backgroundLower
                .init(color: Tokens.Colors.paywallColorBackgroundBottom, location: 0.861), // provenance-ok: stop position of paywall.color.backgroundBottom
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    /// Icon tile (art BLOCKED → omitted), title and subtitle (both name the app: BLOCKED → omitted in release).
    private var header: some View {
        VStack {
            if let title = AccountBlockedCopy.paywallTitle {
                Text(title)
                    .dsTextStyle(PaywallStyle.title)
                    .foregroundStyle(Tokens.Colors.paywallColorTitle)
                    .accessibilityAddTraits(.isHeader)
            }
            if let subtitle = AccountBlockedCopy.paywallSubtitle {
                Text(subtitle)
                    .dsTextStyle(PaywallStyle.subtitle)
                    .foregroundStyle(Tokens.Colors.paywallColorSubtitle)
            }
        }
        .multilineTextAlignment(.center)
    }

    private struct Perk: Identifiable {
        let id: String
        let emoji: String?
        let title: String
        let subtitle: String
    }

    private var perkList: [Perk] {
        var list = [
            Perk(id: "video", emoji: Copy.paywallPerkVideoEmoji, title: Copy.paywallPerkVideoTitle, subtitle: Copy.paywallPerkVideoSubtitle), // provenance-ok: identifier
            Perk(id: "widgets", emoji: Copy.paywallPerkWidgetsEmoji, title: Copy.paywallPerkWidgetsTitle, subtitle: Copy.paywallPerkWidgetsSubtitle), // provenance-ok: identifier
        ]
        if model.showsHistoryPerk {
            list.append(Perk(id: "history", emoji: AccountBlockedCopy.paywallHistoryEmoji, title: Copy.paywallPerkHistoryTitle, subtitle: Copy.paywallPerkHistorySubtitle)) // provenance-ok: identifier
        }
        list.append(Perk(id: "export", emoji: Copy.paywallPerkExportEmoji, title: Copy.paywallPerkExportTitle, subtitle: Copy.paywallPerkExportSubtitle)) // provenance-ok: identifier
        return list
    }

    /// Perk cards `paywall.size.perkHeight` (minimum), `paywall.size.perkGap` apart, outer corners
    /// `paywall.radius.perkOuter` (top of the first, bottom of the last), inner `paywall.radius.perkInner`.
    private var perks: some View {
        let list = perkList
        return VStack(spacing: Tokens.Sizes.paywallSizePerkGap) {
            ForEach(Array(list.enumerated()), id: \.element.id) { index, perk in
                HStack(spacing: 0) {
                    Text(perk.emoji ?? "")
                        .dsTextStyle(PaywallStyle.perkIcon)
                        .frame(width: Tokens.Sizes.paywallSizePerkTextInset)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading) {
                        Text(perk.title)
                            .dsTextStyle(PaywallStyle.perkTitle)
                            .foregroundStyle(Tokens.Colors.paywallColorPerkTitle)
                        Text(perk.subtitle)
                            .dsTextStyle(PaywallStyle.perkSubtitle)
                            .foregroundStyle(Tokens.Colors.paywallColorPerkSubtitle)
                    }
                    Spacer(minLength: 0)
                }
                .frame(minHeight: Tokens.Sizes.paywallSizePerkHeight)
                .background(Tokens.Colors.paywallColorPerk, in: UnevenRoundedRectangle(
                    topLeadingRadius: index == 0 ? Tokens.Radii.paywallRadiusPerkOuter : Tokens.Radii.paywallRadiusPerkInner,
                    bottomLeadingRadius: index == list.count - 1 ? Tokens.Radii.paywallRadiusPerkOuter : Tokens.Radii.paywallRadiusPerkInner,
                    bottomTrailingRadius: index == list.count - 1 ? Tokens.Radii.paywallRadiusPerkOuter : Tokens.Radii.paywallRadiusPerkInner,
                    topTrailingRadius: index == 0 ? Tokens.Radii.paywallRadiusPerkOuter : Tokens.Radii.paywallRadiusPerkInner
                ))
                .accessibilityElement(children: .combine)
            }
        }
    }

    /// Renewal sentence, the selected plan's billing line, the "optional" line, then Restore · Terms · Privacy.
    private var legalBlock: some View {
        VStack {
            Text(Copy.paywallLegalRenews)
            switch model.plansPhase {
            case .loading:
                ProgressView()
            case .loaded:
                if let line = model.billingLine { Text(line) }
            case .unavailable, .offline:
                Text(model.plansPhase == .offline ? Copy.paywallOffline : Copy.paywallErrorProducts)
                Button(Copy.paywallRetry) { Task { await model.loadPlans() } }
                    .dsTextStyle(PaywallStyle.legalLink)
            }
            if let optional = AccountBlockedCopy.paywallLegalOptional { Text(optional) }
            if let message = model.restoreMessage { Text(message) }
            HStack {
                Button(Copy.paywallRestore) { Task { await model.restore() } }
                if let terms = dependencies.configuration.termsURL {
                    Link(Copy.paywallTerms, destination: terms)
                } else {
                    Text(Copy.paywallTerms)
                }
                if let privacy = dependencies.configuration.privacyURL {
                    Link(Copy.paywallPrivacy, destination: privacy)
                } else {
                    Text(Copy.paywallPrivacy)
                }
            }
            .dsTextStyle(PaywallStyle.legalLink)
        }
        .dsTextStyle(PaywallStyle.legal)
        .foregroundStyle(Tokens.Colors.paywallColorDismiss)
        .tint(Tokens.Colors.paywallColorDismiss)
        .multilineTextAlignment(.center)
        .padding(.vertical, Tokens.Sizes.paywallSizePerkMarginH)
    }

    /// CTA capsule (`paywall.size.ctaHeight`, `paywall.color.cta`, label `paywall.fontSize.ctaLabel` bold in
    /// `paywall.color.ctaLabel` + `paywall.icon.ctaUnlock`) and "No thanks!", pinned over the scroll.
    private var pinnedActions: some View {
        VStack {
            Button {
                showsPlans = true
            } label: {
                HStack {
                    if let label = AccountBlockedCopy.paywallCTA {
                        Text(label).dsTextStyle(PaywallStyle.cta)
                    }
                    Image(systemName: Tokens.Icons.paywallIconCtaUnlock)
                        .accessibilityHidden(true)
                }
                .foregroundStyle(Tokens.Colors.paywallColorCtaLabel)
                .frame(maxWidth: .infinity, minHeight: Tokens.Sizes.paywallSizeCtaHeight)
                .background(Tokens.Colors.paywallColorCta, in: Capsule())
            }
            .buttonStyle(.plain)
            // The CTA's label names the app (BLOCKED in release); VoiceOver reads the plan sheet's action instead.
            .accessibilityLabel(Text(AccountBlockedCopy.paywallCTA ?? Copy.paywallPlansSubscribe))
            .accessibilityIdentifier("paywall.cta")
            Button(Copy.paywallDismiss) { close() }
                .dsTextStyle(PaywallStyle.dismiss)
                .foregroundStyle(Tokens.Colors.paywallColorDismiss)
                .frame(minHeight: Tokens.Sizes.globalMinTouchTargetIos)
                .accessibilityIdentifier("paywall.dismiss")
        }
        .padding(.horizontal, Tokens.Sizes.paywallSizePerkMarginH)
    }

    private func close() {
        dependencies.router.modal = nil
    }
}

/// Plan sheet (`paywall.layout.planSheet`: medium detent, visible grabber, system corner radius).
struct PlanSheet: View {
    @Bindable var model: PaywallModel
    /// Closes the paywall (after the welcome sheet's Done).
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: Tokens.Sizes.paywallSizePlanMarginH) {
            if let title = AccountBlockedCopy.paywallPlansTitle {
                Text(title)
                    .dsTextStyle(PaywallStyle.planSheetTitle)
                    .foregroundStyle(Tokens.Colors.paywallColorTitle)
                    .multilineTextAlignment(.center)
            }
            if model.plansPhase == .loading {
                ProgressView()
            }
            ForEach(model.plans) { plan in
                planCard(plan)
            }
            SubscribeCapsule(
                title: Copy.paywallPlansSubscribe,
                isWorking: model.isPurchasing,
                isEnabled: model.plansPhase == .loaded && model.selectedPlan != nil
            ) {
                Task { await model.purchase() }
            }
            .accessibilityIdentifier("paywall.subscribe")
            if let message = model.purchaseMessage {
                Text(message)
                    .dsTextStyle(PaywallStyle.legal)
                    .foregroundStyle(Tokens.Colors.paywallColorDismiss)
            }
            if let line = model.billingLine {
                Text(line)
                    .dsTextStyle(PaywallStyle.legal)
                    .foregroundStyle(Tokens.Colors.paywallColorDismiss)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, Tokens.Sizes.paywallSizePlanMarginH)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(LinearGradient(colors: [Tokens.Colors.paywallColorPlanSheetTop, Tokens.Colors.paywallColorPlanSheetBottom], startPoint: .top, endPoint: .bottom).ignoresSafeArea())
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .dsHaptic(Tokens.Haptics.globalSelect, trigger: model.selectedPlanID)
        .sheet(isPresented: Binding(get: { model.showsWelcome }, set: { if !$0 { model.welcomeDismissed() } })) {
            welcome
        }
    }

    /// "Welcome to Premium!" sheet (body names the app: BLOCKED → omitted in release).
    private var welcome: some View {
        VStack {
            Text(Copy.paywallWelcomeTitle)
                .dsTextStyle(PaywallStyle.planSheetTitle)
                .foregroundStyle(Tokens.Colors.paywallColorTitle)
            if let body = AccountBlockedCopy.paywallWelcomeBody {
                Text(body)
                    .dsTextStyle(PaywallStyle.planDetail)
                    .foregroundStyle(Tokens.Colors.paywallColorPlanDetail)
            }
            SubscribeCapsule(title: Copy.paywallWelcomeDone, isWorking: false, isEnabled: true) {
                model.welcomeDismissed()
                onClose()
            }
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, Tokens.Sizes.paywallSizePlanMarginH)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(LinearGradient(colors: [Tokens.Colors.paywallColorPlanSheetTop, Tokens.Colors.paywallColorPlanSheetBottom], startPoint: .top, endPoint: .bottom).ignoresSafeArea())
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    /// Selected: fill `paywall.color.planSelected`, border `paywall.size.planBorder` in `paywall.color.planBorder`, height
    /// `paywall.size.planSelectedHeight`; else fill `paywall.color.plan`, height `paywall.size.planHeight`. Corners
    /// `radius.global.card` (approximation: not measured). The billed amount is the prominent price.
    private func planCard(_ plan: PlanOption) -> some View {
        let selected = plan.id == model.selectedPlanID
        let shape = RoundedRectangle(cornerRadius: Tokens.Radii.globalCard)
        return Button {
            model.select(plan)
        } label: {
            HStack {
                VStack(alignment: .leading) {
                    Text(plan.period == .year ? Copy.paywallPlansYearlyTitle : Copy.paywallPlansMonthlyTitle)
                        .dsTextStyle(PaywallStyle.planName)
                        .foregroundStyle(Tokens.Colors.paywallColorTitle)
                    if plan.period == .year, let monthly = plan.monthlyEquivalent {
                        Text(Copy.paywallPlansYearlyDetail(monthlyEquivalent: monthly))
                            .dsTextStyle(PaywallStyle.planDetail)
                            .foregroundStyle(Tokens.Colors.paywallColorPlanDetail)
                    }
                }
                Spacer(minLength: 0)
                Text(plan.period == .year ? Copy.paywallPlansYearlyPrice(yearlyPrice: plan.price) : Copy.paywallPlansMonthlyPrice(monthlyPrice: plan.price))
                    .dsTextStyle(PaywallStyle.planPrice)
                    .foregroundStyle(Tokens.Colors.paywallColorTitle)
            }
            .padding(.horizontal, Tokens.Sizes.paywallSizePlanMarginH)
            .frame(maxWidth: .infinity, minHeight: selected ? Tokens.Sizes.paywallSizePlanSelectedHeight : Tokens.Sizes.paywallSizePlanHeight)
            .background(selected ? Tokens.Colors.paywallColorPlanSelected : Tokens.Colors.paywallColorPlan, in: shape)
            .overlay {
                if selected {
                    shape.strokeBorder(Tokens.Colors.paywallColorPlanBorder, lineWidth: Tokens.Sizes.paywallSizePlanBorder)
                }
            }
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : [.isButton])
    }
}

/// The plan sheet's Subscribe capsule (`paywall.size.subscribeHeight`, `paywall.color.subscribe`, label
/// `paywall.fontSize.subscribeLabel` in `paywall.color.subscribeLabel`); native progress while purchasing (MB4).
struct SubscribeCapsule: View {
    let title: String
    let isWorking: Bool
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Group {
                if isWorking {
                    ProgressView()
                } else {
                    Text(title).dsTextStyle(PaywallStyle.subscribe)
                }
            }
            .foregroundStyle(Tokens.Colors.paywallColorSubscribeLabel)
            .frame(maxWidth: .infinity, minHeight: Tokens.Sizes.paywallSizeSubscribeHeight)
            .background(Tokens.Colors.paywallColorSubscribe, in: Capsule())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled || isWorking)
    }
}
