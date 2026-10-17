// Surface: paywall — the Premium screen. Spec: design/surfaces/paywall.md.
// References: references/auto/retro/lazyweb/retro-lazyweb-20260529-paywall.png (PAY, RAW iOS: blurred colour-rich backdrop, title
// + glass close, 248-pt media card r 27, serif headline + 17-pt description, plan-card pager — 36 corners, 27 padding, black
// 60-pt capsule 16 in, next card after 8 — card text #090A0A / #757A7D / #A5ABAF, "FREE" pill, footer),
// references/auto/retro/apk/retro-android-2026.10.1150-strings.txt (APK-S: retro_membership_paywall_*). Purchases: Play Billing (PLATFORM).
package app.feature.account.paywall

import android.app.Activity
import android.icu.text.DateTimePatternGenerator
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawing
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.Immutable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.derivedStateOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawWithContent
import androidx.compose.ui.graphics.BlendMode
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.CompositingStrategy
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextAlign
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewModelScope
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.navigation.NavController
import app.designsystem.R
import app.designsystem.dsTextStyle
import app.designsystem.generated.Tokens
import app.feature.account.AccountEnvironment
import app.feature.account.LocalAccountEnvironment
import app.feature.account.common.AccountEvent
import app.feature.account.common.AccountViewModel
import app.feature.account.common.CollectEvents
import app.feature.account.common.errorDismissLabel
import app.feature.account.common.newestGroupPhoto
import app.feature.account.platform.ExternalActions
import app.feature.account.platform.LegalLinks
import app.ui.components.ActivityIndicator
import app.ui.components.ColourFieldBackdrop
import app.ui.components.CircleButtonStyle
import app.ui.components.CircleIconButton
import app.ui.components.MediaPill
import app.ui.components.PageDots
import app.ui.components.PlanCard
import app.ui.components.PlanCardPager
import app.ui.components.PremiumPill
import app.ui.components.TickOnStep
import app.ui.foundation.DsImage
import app.ui.foundation.DsMotion
import app.ui.foundation.tapClickable
import app.ui.permissions.findActivity
import app.ui.system.ErrorAlert
import app.ui.text.TextRoles
import app.ui.theme.AppTheme
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import java.util.Locale

enum class PlansStatus { Loading, Ready, Unavailable, Offline }

/** Message-only alerts of the paywall states (`paywall.*`). */
enum class PaywallMessage(val copy: Int) {
    PurchaseFailed(R.string.paywall_error_purchase),
    Pending(R.string.paywall_pending),
    NothingToRestore(R.string.paywall_restore_none),

    /** A restore that failed without a connection (as iOS: `paywall.offline`). */
    Offline(R.string.paywall_offline),
}

/** What the success block says: bought, or restored. */
enum class PaywallWelcome { Purchased, Restored }

/** The benefits listed (directive Part 6: only this app's perks; history only while `free_history_days` is set). */
enum class Perk(val title: Int, val subtitle: Int) {
    Video(R.string.paywall_perk_video_title, R.string.paywall_perk_video_subtitle),
    History(R.string.paywall_perk_history_title, R.string.paywall_perk_history_subtitle),
    Widgets(R.string.paywall_perk_widgets_title, R.string.paywall_perk_widgets_subtitle),
    Export(R.string.paywall_perk_export_title, R.string.paywall_perk_export_subtitle),
    ;

    /** The perk's name in links (`app://premium?perk=widgets`, `DeepLinkCodec.PERK_WIDGETS`; iOS `PaywallPerk` raw values). */
    val wire: String get() = name.lowercase(java.util.Locale.ROOT)

    companion object {
        fun fromWire(value: String?): Perk? = entries.firstOrNull { it.wire == value }
    }
}

@Immutable
data class PaywallUiState(
    val plans: List<PlanOption> = emptyList(),
    val status: PlansStatus = PlansStatus.Loading,
    /** The plan being bought: its card's capsule is busy (C-05); null when no purchase runs. */
    val purchasing: PlanPeriod? = null,
    val welcome: PaywallWelcome? = null,
    val message: PaywallMessage? = null,
    /** `public_app_config.free_history_days` set → the history perk is listed. */
    val historyLimited: Boolean = false,
    /** The person's newest group photo: the media card and the backdrop (none → no card, black backdrop). */
    val media: Any? = null,
    /** The benefit page shown first (a locked perk's paywall, `widget.styles`); null: the first page. */
    val initialPerk: Perk? = null,
) {
    val perks: List<Perk> get() = Perk.entries.filter { it != Perk.History || historyLimited }

    /** Annual first (Retro's default), then Monthly. */
    val orderedPlans: List<PlanOption> get() = plans.sortedBy { if (it.period == PlanPeriod.Yearly) 0 else 1 }
}

class PaywallViewModel(private val env: AccountEnvironment) : AccountViewModel() {
    private val mutable = MutableStateFlow(PaywallUiState())
    val state: StateFlow<PaywallUiState> = mutable.asStateFlow()

    init {
        viewModelScope.launch {
            // Already premium: the paywall is not shown (settings shows "Your Subscription" instead).
            if (runCatching { env.premium.refresh() }.getOrDefault(false)) emit(AccountEvent.Back)
        }
        viewModelScope.launch {
            val free = runCatching { env.backend.publicConfig().freeHistoryDays }.getOrNull()
            mutable.update { it.copy(historyLimited = free != null) }
        }
        viewModelScope.launch {
            newestGroupPhoto(env)?.url?.let { url -> mutable.update { it.copy(media = url) } }
        }
        loadPlans()
    }

    fun loadPlans() {
        mutable.update { it.copy(status = PlansStatus.Loading, message = null) }
        viewModelScope.launch {
            val online = runCatching { env.backend.online.first() }.getOrDefault(true)
            val plans = runCatching { env.premium.plans() }.getOrDefault(emptyList())
            mutable.update {
                it.copy(
                    plans = plans,
                    status = when {
                        plans.isNotEmpty() -> PlansStatus.Ready
                        !online -> PlansStatus.Offline
                        else -> PlansStatus.Unavailable
                    },
                )
            }
        }
    }

    fun dismissMessage() = mutable.update { it.copy(message = null) }

    fun purchase(activity: Activity?, plan: PlanOption) {
        if (activity == null || mutable.value.purchasing != null) return
        mutable.update { it.copy(purchasing = plan.period, message = null) }
        viewModelScope.launch {
            when (env.premium.purchase(activity, plan)) {
                PremiumResult.Done -> {
                    mutable.update { it.copy(purchasing = null, welcome = PaywallWelcome.Purchased) }
                    haptic(Tokens.Haptics.globalSuccess)
                }
                PremiumResult.Cancelled -> mutable.update { it.copy(purchasing = null) }
                PremiumResult.Pending -> mutable.update { it.copy(purchasing = null, message = PaywallMessage.Pending) }
                PremiumResult.Failed, PremiumResult.NotConfigured -> {
                    mutable.update { it.copy(purchasing = null, message = PaywallMessage.PurchaseFailed) }
                    haptic(Tokens.Haptics.globalError)
                }
            }
        }
    }

    fun restore() {
        viewModelScope.launch {
            val (result, active) = env.premium.restore()
            when {
                result == PremiumResult.Done && active -> {
                    mutable.update { it.copy(welcome = PaywallWelcome.Restored) }
                    haptic(Tokens.Haptics.globalSuccess)
                }
                result == PremiumResult.Done || result == PremiumResult.NotConfigured -> mutable.update { it.copy(message = PaywallMessage.NothingToRestore) }
                else -> {
                    // The store did not answer: offline → `paywall.offline`, else nothing to restore (as iOS).
                    val online = runCatching { env.backend.online.first() }.getOrDefault(true)
                    mutable.update { it.copy(message = if (online) PaywallMessage.NothingToRestore else PaywallMessage.Offline) }
                    haptic(Tokens.Haptics.globalError)
                }
            }
        }
    }
}

/** [initialPerk]: opened for a locked perk (`widget.styles`: a widget's premium style) — that perk's page first. */
@Composable
fun PaywallRoute(nav: NavController, initialPerk: Perk? = null) {
    val env = LocalAccountEnvironment.current
    val context = LocalContext.current
    val vm = viewModel { PaywallViewModel(env) }
    val state by vm.state.collectAsStateWithLifecycle()
    CollectEvents(vm.events, nav)
    PaywallScreen(
        state = if (initialPerk == null) state else state.copy(initialPerk = initialPerk),
        legal = env.legal,
        actions = PaywallActions(
            onClose = { nav.popBackStack() },
            onSubscribe = { plan -> vm.purchase(context.findActivity(), plan) },
            onRestore = vm::restore,
            onRetry = vm::loadPlans,
            onUrl = { ExternalActions.openInAppBrowser(context, it) },
            onDone = { nav.popBackStack() },
            onDismissMessage = vm::dismissMessage,
        ),
    )
}

/** What the paywall does on each control. */
@Immutable
data class PaywallActions(
    val onClose: () -> Unit = {},
    val onSubscribe: (PlanOption) -> Unit = {},
    val onRestore: () -> Unit = {},
    val onRetry: () -> Unit = {},
    val onUrl: (String) -> Unit = {},
    val onDone: () -> Unit = {},
    val onDismissMessage: () -> Unit = {},
)

/** `{period}` of the billing line: the platform's localized period unit (ICU field display name, e.g. "month" / "year"). */
fun periodUnit(period: PlanPeriod, locale: Locale = Locale.getDefault()): String =
    DateTimePatternGenerator.getInstance(locale).getAppendItemName(
        if (period == PlanPeriod.Yearly) DateTimePatternGenerator.YEAR else DateTimePatternGenerator.MONTH,
    ).lowercase(locale)

/**
 * The paywall (full-screen modal; a media surface — text white in both appearances): the colour-field backdrop
 * (`layout.global.colourFieldBackdrop`, L-9: the person's newest group photo, blurred and dimmed; none → `color.global.backgroundDeep`); the header (title `paywall.title`, text
 * role `sheetTitle`, centred — BLOCKED while it names the app, omitted in release — and the C-11 glass-small close circle at
 * the trailing margin, centred on the title); the benefit pager (media card, serif headline, description, page dots)
 * centred in the space above the plan cards; the C-34 plan-card pager (Annual, Monthly; drawn in the light appearance —
 * `paywall.layout.planCard`: white card, black capsule in both appearances); the footer. Success / restore cross-fades
 * (`duration.global.pageTransition`) to the welcome block on the same backdrop.
 */
@Composable
fun PaywallScreen(state: PaywallUiState, legal: LegalLinks, actions: PaywallActions) {
    val context = LocalContext.current
    Box(Modifier.fillMaxSize().background(Tokens.Colors.globalBackgroundDeep)) {
        if (state.media != null) ColourFieldBackdrop(state.media)
        Column(Modifier.fillMaxSize().windowInsetsPadding(WindowInsets.safeDrawing)) {
            Header(context.getString(R.string.paywall_title), actions.onClose)
            AnimatedContent(
                targetState = state.welcome,
                transitionSpec = { androidx.compose.animation.fadeIn(DsMotion.pageTransition()) togetherWith androidx.compose.animation.fadeOut(DsMotion.pageTransition()) },
                modifier = Modifier.weight(1f).fillMaxWidth(),
                label = "paywallWelcome",
            ) { welcome ->
                if (welcome != null) {
                    Welcome(welcome, actions.onDone)
                } else {
                    Offer(state, legal, actions)
                }
            }
        }
    }
    state.message?.let { ErrorAlert(stringResource(it.copy), errorDismissLabel(), actions.onDismissMessage) }
}

/** Header row: the centred title and the glass close circle (`size.global.circleButtonSmall`) at the trailing margin. */
@Composable
private fun Header(title: String?, onClose: () -> Unit) {
    Box(Modifier.fillMaxWidth().heightIn(min = Tokens.Sizes.globalMinTouchTargetAndroid).padding(horizontal = Tokens.Sizes.globalScreenMargin), contentAlignment = Alignment.Center) {
        if (title != null) {
            Text(title, style = TextRoles.sheetTitle, color = Tokens.Colors.globalTextOnMedia, textAlign = TextAlign.Center, modifier = Modifier.semantics { heading() })
        }
        CircleIconButton(
            Tokens.Icons.globalClose,
            stringResource(R.string.paywall_close_accessibilitylabel),
            onClose,
            Modifier.align(Alignment.CenterEnd),
            style = CircleButtonStyle.GlassSmall,
        )
    }
}

@Composable
private fun Offer(state: PaywallUiState, legal: LegalLinks, actions: PaywallActions) {
    val plans = state.orderedPlans
    val planList = rememberLazyListState()
    val visible by remember { derivedStateOf { planList.firstVisibleItemIndex + if (planList.firstVisibleItemScrollOffset > 0) 1 else 0 } }
    // A step on the plan pager ticks (`haptic.global.select`), as the benefit pager and iOS's plan selection do.
    TickOnStep(visible)
    Column(Modifier.fillMaxSize()) {
        Benefits(state, Modifier.weight(1f).fillMaxWidth())
        when (state.status) {
            PlansStatus.Unavailable, PlansStatus.Offline -> Unavailable(
                stringResource(if (state.status == PlansStatus.Offline) R.string.paywall_offline else R.string.paywall_error_products),
                actions.onRetry,
            )
            PlansStatus.Loading, PlansStatus.Ready -> {
                // The plan cards keep Retro's light card in both appearances (paywall.layout.planCard).
                AppTheme(dark = false) {
                    val count = if (state.status == PlansStatus.Loading) LOADING_CARDS else plans.size
                    PlanCardPager(count, state = planList) { index, _ ->
                        PlanCardContent(plans.getOrNull(index), loadingPeriod = if (index == 0) PlanPeriod.Yearly else PlanPeriod.Monthly, state, actions)
                    }
                }
            }
        }
        Footer(plans.getOrNull(visible.coerceAtMost(plans.lastIndex.coerceAtLeast(0))), legal, actions)
    }
}

/**
 * The benefit pager (one page per perk): the media card (`paywall.size.mediaCardWidth` wide, `paywall.radius.mediaCard`,
 * aspect-fill, as tall as the space allows up to 3:4, its bottom `paywall.size.mediaCardFade` fading into the backdrop;
 * no photo → no card), the headline `size.global.titleToContent`
 * under it (`font.global.display` `displayMedium`, white, centred), the description (text role `textButton`, white,
 * ≤ 2 lines) and the C-31 page dots on media; a page change ticks (`haptic.global.select`).
 */
@Composable
private fun Benefits(state: PaywallUiState, modifier: Modifier) {
    val perks = state.perks
    val pager = rememberPagerState(initialPage = state.initialPerk?.let { perks.indexOf(it) }?.coerceAtLeast(0) ?: 0) { perks.size }
    TickOnStep(pager.currentPage)
    Column(modifier, horizontalAlignment = Alignment.CenterHorizontally) {
        HorizontalPager(pager, Modifier.weight(1f).fillMaxWidth()) { page ->
            val perk = perks[page]
            Column(Modifier.fillMaxSize().padding(horizontal = Tokens.Sizes.globalScreenMargin), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.Center) {
                if (state.media != null) {
                    DsImage(
                        state.media,
                        null,
                        Modifier
                            .weight(1f, fill = false)
                            .width(Tokens.Sizes.paywallSizeMediaCardWidth)
                            // Retro's card keeps its 248 width and takes the height the page leaves (aspect-fill crop),
                            // never taller than 3:4.
                            .heightIn(max = Tokens.Sizes.paywallSizeMediaCardWidth / MEDIA_ASPECT)
                            .fillMaxHeight()
                            .clip(RoundedCornerShape(Tokens.Radii.paywallRadiusMediaCard))
                            .mediaCardFade(),
                    )
                }
                Text(
                    stringResource(perk.title),
                    style = TextRoles.displayMedium,
                    color = Tokens.Colors.globalTextOnMedia,
                    textAlign = TextAlign.Center,
                    modifier = Modifier.padding(top = if (state.media != null) Tokens.Sizes.globalTitleToContent else Tokens.Sizes.globalScreenMargin).semantics { heading() },
                )
                Text(
                    stringResource(perk.subtitle),
                    style = TextRoles.textButton,
                    color = Tokens.Colors.globalTextOnMedia,
                    textAlign = TextAlign.Center,
                    maxLines = DESCRIPTION_LINES,
                )
            }
        }
        if (perks.size > 1) {
            val position = stringResource(R.string.global_a11y_pageposition, (pager.currentPage + 1).toString(), perks.size.toString())
            PageDots(perks.size, pager.currentPage, position, Modifier.padding(vertical = Tokens.Sizes.globalScreenMargin), onMedia = true)
        }
    }
}

/**
 * One plan card's content (`paywall.layout.planCard`; C-34 [PlanCard]): title (`paywall.fontSize.planTitle` /
 * `.fontWeight.planTitle`, `paywall.color.planText`), subtitle (`paywall.fontSize.planSubtitle`, `.planTextSecondary`),
 * the two bullets (`paywall.fontSize.planBullet`, `.planText`; no marker), the price (`paywall.fontSize.planPrice` /
 * `.fontWeight.planPrice`) and the footnote (`paywall.fontSize.planFootnote`, `.planTextTertiary`) — the store's localized
 * strings; the blocks `size.global.screenMargin` apart (the card's inner spacing is not measured — Gap). A plan with a free
 * trial (owner decision 7: one week on the annual plan; core:billing reads it from Play's offer phases) shows the C-25
 * premium pill `paywall.plans.trial.badge` after the title, the capsule `paywall.plans.trial.cta` ("Try 1 week free") and
 * the footnote `.trialDetail`. Loading: price and footnote replaced by the platform indicator in
 * `paywall.color.planTextTertiary`, the capsule disabled; purchasing: that plan's capsule busy.
 */
@Composable
private fun PlanCardContent(plan: PlanOption?, loadingPeriod: PlanPeriod, state: PaywallUiState, actions: PaywallActions) {
    val period = plan?.period ?: loadingPeriod
    val yearly = period == PlanPeriod.Yearly
    val trial = plan?.trialDuration
    PlanCard(
        if (trial != null) stringResource(R.string.paywall_plans_trial_cta, trial) else stringResource(R.string.paywall_plans_subscribe),
        { plan?.let(actions.onSubscribe) },
        actionEnabled = plan != null,
        actionLoading = plan != null && state.purchasing == plan.period,
    ) {
        val text = Tokens.Colors.paywallColorPlanText
        // Title with the C-25 premium pill "FREE" on a plan with a free trial (PAY: centred on the title's cap middle,
        // `paywall.size.planPillInset` from the card's edge — outside the text padding, so shifted by the difference).
        Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
            Text(
                stringResource(if (yearly) R.string.paywall_plans_yearly_title else R.string.paywall_plans_monthly_title),
                style = dsTextStyle(Tokens.FontSizes.paywallFontSizePlanTitle, Tokens.FontWeights.paywallFontWeightPlanTitle, Tokens.Fonts.globalFamily),
                color = text,
                modifier = Modifier.weight(1f),
            )
            if (trial != null) {
                PremiumPill(
                    stringResource(R.string.paywall_plans_trial_badge),
                    Modifier.offset(x = Tokens.Sizes.globalPlanCardPadding - Tokens.Sizes.paywallSizePlanPillInset),
                )
            }
        }
        Text(
            stringResource(if (yearly) R.string.paywall_plans_yearly_subtitle else R.string.paywall_plans_monthly_subtitle),
            style = dsTextStyle(Tokens.FontSizes.paywallFontSizePlanSubtitle, Tokens.FontWeights.fontWeightGlobalListSubtitle, Tokens.Fonts.globalFamily),
            color = Tokens.Colors.paywallColorPlanTextSecondary,
        )
        val bullet = dsTextStyle(Tokens.FontSizes.paywallFontSizePlanBullet, Tokens.FontWeights.fontWeightGlobalBody, Tokens.Fonts.globalFamily)
        Column(Modifier.padding(top = Tokens.Sizes.globalScreenMargin)) {
            Text(stringResource(if (yearly) R.string.paywall_plans_yearly_bullet1 else R.string.paywall_plans_monthly_bullet1), style = bullet, color = text)
            Text(stringResource(if (yearly) R.string.paywall_plans_yearly_bullet2 else R.string.paywall_plans_monthly_bullet2), style = bullet, color = text)
        }
        Column(Modifier.padding(top = Tokens.Sizes.globalScreenMargin)) {
            if (plan == null) {
                ActivityIndicator(
                    stringResource(R.string.global_a11y_loading),
                    Modifier.padding(vertical = Tokens.Sizes.globalSectionHeaderToContent),
                    color = Tokens.Colors.paywallColorPlanTextTertiary,
                )
            } else {
                Text(
                    stringResource(if (yearly) R.string.paywall_plans_yearly_price else R.string.paywall_plans_monthly_price, plan.price),
                    style = dsTextStyle(Tokens.FontSizes.paywallFontSizePlanPrice, Tokens.FontWeights.paywallFontWeightPlanPrice, Tokens.Fonts.globalFamily),
                    color = text,
                )
                // "Billed {price} yearly", or on a plan with a free trial "And then billed {price} yearly after"
                // (`paywall.plans.<plan>.trialDetail`: how long the trial lasts is the capsule, the price after it this line).
                val footnote = when {
                    trial != null && yearly -> R.string.paywall_plans_yearly_trialdetail
                    trial != null -> R.string.paywall_plans_monthly_trialdetail
                    yearly -> R.string.paywall_plans_yearly_detail
                    else -> R.string.paywall_plans_monthly_detail
                }
                Text(
                    stringResource(footnote, plan.price),
                    style = dsTextStyle(Tokens.FontSizes.paywallFontSizePlanFootnote, Tokens.FontWeights.fontWeightGlobalCaption, Tokens.Fonts.globalFamily),
                    color = Tokens.Colors.paywallColorPlanTextTertiary,
                )
            }
        }
    }
}

/** Products unavailable / offline: one white line and the C-09 light pill "Try again", in place of the card pager. */
@Composable
private fun Unavailable(line: String, onRetry: () -> Unit) {
    Column(Modifier.fillMaxWidth().padding(horizontal = Tokens.Sizes.globalButtonMarginH), horizontalAlignment = Alignment.CenterHorizontally) {
        Text(line, style = TextRoles.textButton, color = Tokens.Colors.globalTextOnMedia, textAlign = TextAlign.Center)
        MediaPill(stringResource(R.string.paywall_retry), onRetry, Modifier.padding(top = Tokens.Sizes.globalScreenMargin))
    }
}

/**
 * The footer under the cards, centred, text role `caption` in white: "Cancel anytime. No questions asked.", the billing
 * line of the visible plan (`paywall.legal.billing.android`), "You don't need a subscription…" (BLOCKED while it names the
 * app), then the text buttons Restore purchase · Terms · Privacy (same style; Terms / Privacy omitted while their URLs
 * are BLOCKED), each at least `size.global.minTouchTarget.android` high.
 */
@Composable
private fun Footer(plan: PlanOption?, legal: LegalLinks, actions: PaywallActions) {
    val context = LocalContext.current
    val caption = TextRoles.caption
    val white = Tokens.Colors.globalTextOnMedia
    Column(Modifier.fillMaxWidth().padding(start = Tokens.Sizes.globalButtonMarginH, end = Tokens.Sizes.globalButtonMarginH, top = Tokens.Sizes.globalScreenMargin), horizontalAlignment = Alignment.CenterHorizontally) {
        Text(stringResource(R.string.paywall_footer), style = caption, color = white, textAlign = TextAlign.Center)
        if (plan != null) {
            Text(stringResource(R.string.paywall_legal_billing_android, plan.price, periodUnit(plan.period)), style = caption, color = white, textAlign = TextAlign.Center)
        }
        Text(stringResource(R.string.paywall_legal_optional), style = caption, color = white, textAlign = TextAlign.Center)
        Row(horizontalArrangement = Arrangement.spacedBy(Tokens.Sizes.globalScreenMargin), verticalAlignment = Alignment.CenterVertically) {
            FooterButton(stringResource(R.string.paywall_restore), actions.onRestore)
            legal.termsUrl?.let { url -> FooterButton(stringResource(R.string.paywall_terms)) { actions.onUrl(url) } }
            legal.privacyUrl?.let { url -> FooterButton(stringResource(R.string.paywall_privacy)) { actions.onUrl(url) } }
        }
    }
}

@Composable
private fun FooterButton(text: String, onClick: () -> Unit) {
    Box(Modifier.heightIn(min = Tokens.Sizes.globalMinTouchTargetAndroid).tapClickable(onClick = onClick), contentAlignment = Alignment.Center) {
        Text(text, style = TextRoles.caption, color = Tokens.Colors.globalTextOnMedia)
    }
}

/** Success / restored: headline (`displayMedium`, white), body (`textButton`, white), the C-09 light capsule "Done"; centred. */
@Composable
private fun Welcome(welcome: PaywallWelcome, onDone: () -> Unit) {
    Column(Modifier.fillMaxSize().padding(horizontal = Tokens.Sizes.globalButtonMarginH), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.Center) {
        Text(
            stringResource(if (welcome == PaywallWelcome.Restored) R.string.paywall_restore_done else R.string.paywall_welcome_title),
            style = TextRoles.displayMedium,
            color = Tokens.Colors.globalTextOnMedia,
            textAlign = TextAlign.Center,
            modifier = Modifier.semantics { heading() },
        )
        Text(stringResource(R.string.paywall_welcome_body), style = TextRoles.textButton, color = Tokens.Colors.globalTextOnMedia, textAlign = TextAlign.Center)
        MediaPill(stringResource(R.string.paywall_welcome_done), onDone, Modifier.padding(top = Tokens.Sizes.globalTitleToContent))
    }
}

/** The media card's tallest shape: 3:4, the shape of the app's photos (the card's own height is not measured). */
private const val MEDIA_ASPECT = 3f / 4f

/**
 * The media card's alpha mask: opaque down to `paywall.size.mediaCardFade` above the bottom edge, then a linear ramp to
 * clear at the edge (Retro's card fades into the paywall backdrop, PAY). Only the mask's alpha counts.
 */
private fun Modifier.mediaCardFade(): Modifier =
    graphicsLayer { compositingStrategy = CompositingStrategy.Offscreen }
        .drawWithContent {
            drawContent()
            val opaqueTo = (1f - Tokens.Sizes.paywallSizeMediaCardFade.toPx() / size.height).coerceIn(0f, 1f)
            drawRect(
                Brush.verticalGradient(0f to Tokens.Colors.globalBackgroundDeep, opaqueTo to Tokens.Colors.globalBackgroundDeep, 1f to Color.Transparent),
                blendMode = BlendMode.DstIn,
            )
        }
private const val DESCRIPTION_LINES = 2
private const val LOADING_CARDS = 2
