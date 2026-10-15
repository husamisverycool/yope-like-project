// Surface: paywall — premium screen and perks. Spec: design/surfaces/paywall.md.
// References: references/auto/locket/mobbin/locket-mobbin-paywall-screen.png (MB), locket-mobbin-gold-flow-2.png (MB2),
// locket-mobbin-gold-flow-3.png … -6.png (MB3–6), references/auto/locket/lazyweb/locket-lazyweb-20260803-cap-plan-picker.png (LZP),
// locket-lazyweb-20260803-autocap-21.png (LZ21), locket-lazyweb-20260803-autocap-25.png (LZ25).
package app.feature.account.paywall

import android.app.Activity
import android.icu.text.DateTimePatternGenerator
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawing
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.selection.selectable
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.Immutable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewModelScope
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.navigation.NavController
import app.designsystem.R
import app.designsystem.dsTextStyle
import app.designsystem.generated.Tokens
import app.feature.account.AccountEnvironment
import app.feature.account.LocalAccountEnvironment
import app.feature.account.blocked.BlockedCopy
import app.feature.account.common.AccountEvent
import app.feature.account.common.AccountViewModel
import app.feature.account.common.CollectEvents
import app.feature.account.platform.ExternalActions
import app.feature.account.platform.LegalLinks
import app.ui.permissions.findActivity
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import java.util.Locale

enum class PlansStatus { Loading, Ready, Unavailable, Offline }

/** Messages of the paywall states (`paywall.*`), shown in the legal block or under Subscribe. */
enum class PaywallMessage(val copy: Int) {
    PurchaseFailed(R.string.paywall_error_purchase),
    Pending(R.string.paywall_pending),
    Restored(R.string.paywall_restore_done),
    NothingToRestore(R.string.paywall_restore_none),
}

@Immutable
data class PaywallUiState(
    val plans: List<PlanOption> = emptyList(),
    val status: PlansStatus = PlansStatus.Loading,
    /** Default selection: yearly (Locket's default). */
    val selected: PlanPeriod = PlanPeriod.Yearly,
    val sheet: Boolean = false,
    val purchasing: Boolean = false,
    val welcome: Boolean = false,
    val message: PaywallMessage? = null,
    /** `public_app_config.free_history_days` set → the history perk is listed. */
    val historyLimited: Boolean = false,
) {
    val selectedPlan: PlanOption? get() = plans.firstOrNull { it.period == selected }
}

class PaywallViewModel(private val env: AccountEnvironment) : AccountViewModel() {
    private val mutable = MutableStateFlow(PaywallUiState())
    val state: StateFlow<PaywallUiState> = mutable.asStateFlow()

    init {
        viewModelScope.launch {
            // Already premium: the paywall is not shown (settings shows Manage Subscription instead).
            if (runCatching { env.premium.refresh() }.getOrDefault(false)) emit(AccountEvent.Back)
        }
        viewModelScope.launch {
            val free = runCatching { env.backend.publicConfig().freeHistoryDays }.getOrNull()
            mutable.update { it.copy(historyLimited = free != null) }
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

    fun openPlans() = mutable.update { it.copy(sheet = true) }
    fun closePlans() = mutable.update { it.copy(sheet = false, message = null) }

    fun select(period: PlanPeriod) {
        if (period == mutable.value.selected) return
        mutable.update { it.copy(selected = period) }
        haptic(Tokens.Haptics.globalSelect)
    }

    fun purchase(activity: Activity?) {
        val plan = mutable.value.selectedPlan ?: return
        if (activity == null || mutable.value.purchasing) return
        mutable.update { it.copy(purchasing = true, message = null) }
        viewModelScope.launch {
            when (env.premium.purchase(activity, plan)) {
                PremiumResult.Done -> {
                    mutable.update { it.copy(purchasing = false, sheet = false, welcome = true) }
                    haptic(Tokens.Haptics.globalSuccess)
                }
                PremiumResult.Cancelled -> mutable.update { it.copy(purchasing = false) }
                PremiumResult.Pending -> mutable.update { it.copy(purchasing = false, message = PaywallMessage.Pending) }
                PremiumResult.Failed, PremiumResult.NotConfigured -> {
                    mutable.update { it.copy(purchasing = false, message = PaywallMessage.PurchaseFailed) }
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
                    mutable.update { it.copy(message = PaywallMessage.Restored) }
                    haptic(Tokens.Haptics.globalSuccess)
                }
                result == PremiumResult.Done || result == PremiumResult.NotConfigured -> mutable.update { it.copy(message = PaywallMessage.NothingToRestore) }
                else -> {
                    mutable.update { it.copy(message = PaywallMessage.NothingToRestore) }
                    haptic(Tokens.Haptics.globalError)
                }
            }
        }
    }
}

@Composable
fun PaywallRoute(nav: NavController) {
    val env = LocalAccountEnvironment.current
    val context = LocalContext.current
    // Release builds while `{app_name}` is BLOCKED have no title or CTA copy: the paywall is omitted
    // (an entry that reaches it closes it at once). Debug builds show it with the blocked copy.
    if (BlockedCopy.paywallCta(context) == null) {
        LaunchedEffect(Unit) { nav.popBackStack() }
        return
    }
    val vm = viewModel { PaywallViewModel(env) }
    val state by vm.state.collectAsStateWithLifecycle()
    CollectEvents(vm.events, nav)
    PaywallScreen(
        state = state,
        legal = env.legal,
        onDismiss = { nav.popBackStack() },
        onCta = vm::openPlans,
        onClosePlans = vm::closePlans,
        onSelect = vm::select,
        onSubscribe = { vm.purchase(context.findActivity()) },
        onRestore = vm::restore,
        onRetry = vm::loadPlans,
        onUrl = { ExternalActions.openInAppBrowser(context, it) },
        onWelcomeDone = { nav.popBackStack() },
    )
}

/** `{period}` of the billing line: the platform's localized period unit (ICU field display name, e.g. "month" / "year"). */
fun periodUnit(period: PlanPeriod, locale: Locale = Locale.getDefault()): String =
    DateTimePatternGenerator.getInstance(locale).getAppendItemName(
        if (period == PlanPeriod.Yearly) DateTimePatternGenerator.YEAR else DateTimePatternGenerator.MONTH,
    ).lowercase(locale)

/**
 * The full-screen paywall: background gradient `paywall.color.backgroundTop` → `.backgroundUpper` →
 * `.backgroundLower` → `.backgroundBottom` (stops 0.078 / 0.274 / 0.587 / 0.861 from the spec); scrolling
 * content (icon tile BLOCKED → omitted; title / subtitle BLOCKED in release; perks; legal block) with
 * side margins `paywall.size.perkMarginH`; CTA capsule and "No thanks!" pinned at the bottom.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun PaywallScreen(
    state: PaywallUiState,
    legal: LegalLinks,
    onDismiss: () -> Unit,
    onCta: () -> Unit,
    onClosePlans: () -> Unit,
    onSelect: (PlanPeriod) -> Unit,
    onSubscribe: () -> Unit,
    onRestore: () -> Unit,
    onRetry: () -> Unit,
    onUrl: (String) -> Unit,
    onWelcomeDone: () -> Unit,
) {
    val context = LocalContext.current
    val margin = Tokens.Sizes.paywallSizePerkMarginH
    Box(
        Modifier.fillMaxSize().background(
            Brush.verticalGradient(
                GRADIENT_TOP to Tokens.Colors.paywallColorBackgroundTop,
                GRADIENT_UPPER to Tokens.Colors.paywallColorBackgroundUpper,
                GRADIENT_LOWER to Tokens.Colors.paywallColorBackgroundLower,
                GRADIENT_BOTTOM to Tokens.Colors.paywallColorBackgroundBottom,
            ),
        ),
    ) {
        Column(Modifier.fillMaxSize().windowInsetsPadding(WindowInsets.safeDrawing)) {
            Column(
                Modifier.weight(1f).fillMaxWidth().verticalScroll(rememberScrollState()).padding(horizontal = margin),
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                Spacer(Modifier.height(Tokens.Sizes.paywallSizePerkGap))
                BlockedCopy.paywallTitle(context)?.let {
                    Text(it, style = dsTextStyle(Tokens.FontSizes.paywallFontSizeTitle, FontWeight.Bold), color = Tokens.Colors.paywallColorTitle, textAlign = TextAlign.Center, modifier = Modifier.semantics { heading() })
                }
                BlockedCopy.paywallSubtitle(context)?.let {
                    Text(
                        it,
                        style = TextStyle(fontSize = Tokens.FontSizes.paywallFontSizeSubtitle, lineHeight = Tokens.LineHeights.paywallLineHeightSubtitle),
                        color = Tokens.Colors.paywallColorSubtitle,
                        textAlign = TextAlign.Center,
                    )
                }
                Spacer(Modifier.height(Tokens.Sizes.paywallSizePerkMarginH))
                PerkStack(state.historyLimited)
                Spacer(Modifier.height(Tokens.Sizes.paywallSizePerkMarginH))
                LegalBlock(state, legal, onRestore, onRetry, onUrl)
            }
            Column(Modifier.fillMaxWidth().padding(horizontal = margin), horizontalAlignment = Alignment.CenterHorizontally) {
                BlockedCopy.paywallCta(context)?.let { Cta(it, onCta) }
                Text(
                    stringResource(R.string.paywall_dismiss),
                    style = TextStyle(fontSize = Tokens.FontSizes.paywallFontSizeDismiss),
                    color = Tokens.Colors.paywallColorDismiss,
                    modifier = Modifier.clickable(role = Role.Button, onClick = onDismiss).padding(vertical = Tokens.Sizes.paywallSizePerkGap),
                )
            }
        }
        if (state.sheet) {
            val sheet = rememberModalBottomSheetState(skipPartiallyExpanded = true)
            ModalBottomSheet(
                onDismissRequest = onClosePlans,
                sheetState = sheet,
                containerColor = Tokens.Colors.paywallColorPlanSheetTop,
                shape = RoundedCornerShape(topStart = Tokens.Layouts.GlobalSheet.android.dp, topEnd = Tokens.Layouts.GlobalSheet.android.dp),
            ) {
                PlanSheet(state, onSelect, onSubscribe, onRetry)
            }
        }
        if (state.welcome) {
            val sheet = rememberModalBottomSheetState(skipPartiallyExpanded = true)
            ModalBottomSheet(onDismissRequest = onWelcomeDone, sheetState = sheet, containerColor = Tokens.Colors.paywallColorPlanSheetTop) {
                WelcomeSheet(onWelcomeDone)
            }
        }
    }
}

// Stop positions measured with each colour (token `element`: "background gradient stop at 0.078 of the
// screen height", 0.274, 0.587, 0.861; design/tokens/account.json paywall.color.background*).
private const val GRADIENT_TOP = 0.078f
private const val GRADIENT_UPPER = 0.274f
private const val GRADIENT_LOWER = 0.587f
private const val GRADIENT_BOTTOM = 0.861f

/**
 * Perk cards: `paywall.color.perk`, height `paywall.size.perkHeight` (minimum; grows with text), gap
 * `paywall.size.perkGap`, outer corners `paywall.radius.perkOuter` (top of the first, bottom of the
 * last), inner `paywall.radius.perkInner`; emoji (decorative) at `paywall.size.perkIcon` centred in the
 * leading `paywall.size.perkTextInset` column (approximation: the spec's 39-pt centre has no token);
 * title `paywall.fontSize.perkTitle` / `.fontWeight.perkTitle` / `.color.perkTitle`, subtitle
 * `.fontSize.perkSubtitle` / `.color.perkSubtitle`. Order: video, widgets, history (only while
 * `free_history_days` is set; its emoji is BLOCKED → none), export.
 */
@Composable
private fun PerkStack(historyLimited: Boolean) {
    val context = LocalContext.current
    val perks = buildList {
        add(Triple(stringResource(R.string.paywall_perk_video_emoji), stringResource(R.string.paywall_perk_video_title), stringResource(R.string.paywall_perk_video_subtitle)))
        add(Triple(stringResource(R.string.paywall_perk_widgets_emoji), stringResource(R.string.paywall_perk_widgets_title), stringResource(R.string.paywall_perk_widgets_subtitle)))
        if (historyLimited) add(Triple(BlockedCopy.paywallHistoryEmoji(context), stringResource(R.string.paywall_perk_history_title), stringResource(R.string.paywall_perk_history_subtitle)))
        add(Triple(stringResource(R.string.paywall_perk_export_emoji), stringResource(R.string.paywall_perk_export_title), stringResource(R.string.paywall_perk_export_subtitle)))
    }
    val outer = Tokens.Radii.paywallRadiusPerkOuter
    val inner = Tokens.Radii.paywallRadiusPerkInner
    val emojiSize = with(LocalDensity.current) { Tokens.Sizes.paywallSizePerkIcon.toSp() }
    Column(verticalArrangement = Arrangement.spacedBy(Tokens.Sizes.paywallSizePerkGap)) {
        perks.forEachIndexed { index, (emoji, title, subtitle) ->
            val shape = RoundedCornerShape(
                topStart = if (index == 0) outer else inner,
                topEnd = if (index == 0) outer else inner,
                bottomStart = if (index == perks.lastIndex) outer else inner,
                bottomEnd = if (index == perks.lastIndex) outer else inner,
            )
            Row(
                Modifier.fillMaxWidth().heightIn(min = Tokens.Sizes.paywallSizePerkHeight).background(Tokens.Colors.paywallColorPerk, shape).semantics(mergeDescendants = true) {},
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Box(Modifier.width(Tokens.Sizes.paywallSizePerkTextInset).clearAndSetSemantics {}, contentAlignment = Alignment.Center) {
                    if (emoji != null) Text(emoji, style = TextStyle(fontSize = emojiSize))
                }
                Column(Modifier.weight(1f)) {
                    Text(title, style = dsTextStyle(Tokens.FontSizes.paywallFontSizePerkTitle, Tokens.FontWeights.paywallFontWeightPerkTitle), color = Tokens.Colors.paywallColorPerkTitle)
                    Text(subtitle, style = TextStyle(fontSize = Tokens.FontSizes.paywallFontSizePerkSubtitle), color = Tokens.Colors.paywallColorPerkSubtitle)
                }
            }
        }
    }
}

/**
 * Legal block: caption role (`fontSize.global.caption`, `lineHeight.global.caption`) in
 * `paywall.color.dismiss`; renewal sentence, the Android billing line for the selected plan (price
 * and period once known; native progress while loading), the optional line (BLOCKED in release),
 * messages (products error / offline + Try Again, restore results), then Restore Purchases · Terms of
 * Use · Privacy Policy as text buttons (link style = same colour at `paywall.fontWeight.perkTitle`,
 * approximation; Terms / Privacy omitted while their URLs are BLOCKED).
 */
@Composable
private fun LegalBlock(state: PaywallUiState, legal: LegalLinks, onRestore: () -> Unit, onRetry: () -> Unit, onUrl: (String) -> Unit) {
    val context = LocalContext.current
    val caption = TextStyle(fontSize = Tokens.FontSizes.globalCaption, lineHeight = Tokens.LineHeights.globalCaption)
    val link = caption.copy(fontWeight = Tokens.FontWeights.paywallFontWeightPerkTitle)
    val color = Tokens.Colors.paywallColorDismiss
    Column(horizontalAlignment = Alignment.CenterHorizontally) {
        Text(stringResource(R.string.paywall_legal_renews), style = caption, color = color, textAlign = TextAlign.Center)
        BillingLine(state, caption)
        BlockedCopy.paywallLegalOptional(context)?.let { Text(it, style = caption, color = color, textAlign = TextAlign.Center) }
        when (state.status) {
            PlansStatus.Unavailable -> RetryLine(stringResource(R.string.paywall_error_products), caption, link, onRetry)
            PlansStatus.Offline -> RetryLine(stringResource(R.string.paywall_offline), caption, link, onRetry)
            else -> Unit
        }
        state.message?.takeIf { it == PaywallMessage.Restored || it == PaywallMessage.NothingToRestore }?.let {
            Text(stringResource(it.copy), style = caption, color = color, textAlign = TextAlign.Center)
        }
        Row(horizontalArrangement = Arrangement.spacedBy(Tokens.Sizes.paywallSizePerkMarginH)) {
            Text(stringResource(R.string.paywall_restore), style = link, color = color, modifier = Modifier.clickable(role = Role.Button, onClick = onRestore))
            legal.termsUrl?.let { url -> Text(stringResource(R.string.paywall_terms), style = link, color = color, modifier = Modifier.clickable(role = Role.Button) { onUrl(url) }) }
            legal.privacyUrl?.let { url -> Text(stringResource(R.string.paywall_privacy), style = link, color = color, modifier = Modifier.clickable(role = Role.Button) { onUrl(url) }) }
        }
    }
}

@Composable
private fun BillingLine(state: PaywallUiState, style: TextStyle) {
    val plan = state.selectedPlan
    when {
        state.status == PlansStatus.Loading -> CircularProgressIndicator(color = Tokens.Colors.paywallColorDismiss)
        plan != null -> Text(
            stringResource(R.string.paywall_legal_billing_android, plan.price, periodUnit(plan.period)),
            style = style,
            color = Tokens.Colors.paywallColorDismiss,
            textAlign = TextAlign.Center,
        )
    }
}

@Composable
private fun RetryLine(message: String, style: TextStyle, link: TextStyle, onRetry: () -> Unit) {
    Text(message, style = style, color = Tokens.Colors.paywallColorDismiss, textAlign = TextAlign.Center)
    Text(stringResource(R.string.paywall_retry), style = link, color = Tokens.Colors.paywallColorDismiss, modifier = Modifier.clickable(role = Role.Button, onClick = onRetry))
}

/**
 * CTA capsule: height `paywall.size.ctaHeight`, fill `paywall.color.cta`, label
 * `paywall.fontSize.ctaLabel` bold in `paywall.color.ctaLabel` (BLOCKED copy: omitted in release) with
 * `paywall.icon.ctaUnlock`; full width minus `paywall.size.perkMarginH`.
 */
@Composable
private fun Cta(label: String, onClick: () -> Unit) {
    Row(
        Modifier
            .fillMaxWidth()
            .heightIn(min = Tokens.Sizes.paywallSizeCtaHeight)
            .clip(CircleShape)
            .background(Tokens.Colors.paywallColorCta, CircleShape)
            .clickable(role = Role.Button, onClick = onClick),
        horizontalArrangement = Arrangement.spacedBy(Tokens.Sizes.globalHeaderGap, Alignment.CenterHorizontally),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(Tokens.Icons.paywallIconCtaUnlock, contentDescription = null, tint = Tokens.Colors.paywallColorCtaLabel)
        Text(label, style = dsTextStyle(Tokens.FontSizes.paywallFontSizeCtaLabel, FontWeight.Bold), color = Tokens.Colors.paywallColorCtaLabel)
    }
}

/**
 * Plan sheet (`paywall.layout.planSheet` android: ModalBottomSheet, M3 drag handle, 28-dp corners):
 * fill gradient `paywall.color.planSheetTop` → `.planSheetBottom`; title (BLOCKED in release) at
 * `paywall.fontSize.planSheetTitle` / `paywall.lineHeight.planSheetTitle`; yearly card (selected:
 * `paywall.color.planSelected`, border `paywall.size.planBorder` `paywall.color.planBorder`, height
 * `paywall.size.planSelectedHeight`) and monthly card (`paywall.color.plan`, `paywall.size.planHeight`),
 * corners `radius.global.card` (approximation), side margins `paywall.size.planMarginH`, 16 pt apart (=
 * `paywall.size.planMarginH`); names `paywall.fontSize.planName` bold, prices `.planPrice` bold, both
 * `paywall.color.title`; the yearly detail line needs the monthly equivalent, which core:billing does
 * not expose (only the store's formatted price) → omitted. Subscribe capsule `paywall.size.subscribeHeight`,
 * `paywall.color.subscribe`, label `paywall.fontSize.subscribeLabel` in `.color.subscribeLabel`; native
 * progress while purchasing; billing line under it.
 */
@Composable
internal fun PlanSheet(state: PaywallUiState, onSelect: (PlanPeriod) -> Unit, onSubscribe: () -> Unit, onRetry: () -> Unit) {
    val context = LocalContext.current
    val margin = Tokens.Sizes.paywallSizePlanMarginH
    Column(
        Modifier
            .fillMaxWidth()
            .background(Brush.verticalGradient(listOf(Tokens.Colors.paywallColorPlanSheetTop, Tokens.Colors.paywallColorPlanSheetBottom)))
            .navigationBarsPadding()
            .padding(horizontal = margin),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(margin),
    ) {
        BlockedCopy.paywallPlansTitle(context)?.let {
            Text(
                it,
                style = dsTextStyle(Tokens.FontSizes.paywallFontSizePlanSheetTitle, FontWeight.Bold, lineHeight = Tokens.LineHeights.paywallLineHeightPlanSheetTitle),
                color = Tokens.Colors.paywallColorTitle,
                textAlign = TextAlign.Center,
                modifier = Modifier.semantics { heading() },
            )
        }
        val yearly = state.plans.firstOrNull { it.period == PlanPeriod.Yearly }
        val monthly = state.plans.firstOrNull { it.period == PlanPeriod.Monthly }
        if (state.status == PlansStatus.Loading) CircularProgressIndicator(color = Tokens.Colors.paywallColorTitle)
        yearly?.let { PlanCard(stringResource(R.string.paywall_plans_yearly_title), stringResource(R.string.paywall_plans_yearly_price, it.price), state.selected == PlanPeriod.Yearly) { onSelect(PlanPeriod.Yearly) } }
        monthly?.let { PlanCard(stringResource(R.string.paywall_plans_monthly_title), stringResource(R.string.paywall_plans_monthly_price, it.price), state.selected == PlanPeriod.Monthly) { onSelect(PlanPeriod.Monthly) } }
        val subscribeShape = CircleShape
        Box(
            Modifier
                .fillMaxWidth()
                .heightIn(min = Tokens.Sizes.paywallSizeSubscribeHeight)
                .clip(subscribeShape)
                .background(Tokens.Colors.paywallColorSubscribe, subscribeShape)
                .clickable(enabled = state.selectedPlan != null && !state.purchasing, role = Role.Button, onClick = onSubscribe),
            contentAlignment = Alignment.Center,
        ) {
            if (state.purchasing) {
                CircularProgressIndicator(color = Tokens.Colors.paywallColorSubscribeLabel)
            } else {
                Text(stringResource(R.string.paywall_plans_subscribe), style = TextStyle(fontSize = Tokens.FontSizes.paywallFontSizeSubscribeLabel), color = Tokens.Colors.paywallColorSubscribeLabel)
            }
        }
        val caption = TextStyle(fontSize = Tokens.FontSizes.globalCaption, lineHeight = Tokens.LineHeights.globalCaption)
        state.message?.takeIf { it == PaywallMessage.PurchaseFailed || it == PaywallMessage.Pending }?.let {
            Text(stringResource(it.copy), style = caption, color = Tokens.Colors.paywallColorDismiss, textAlign = TextAlign.Center)
        }
        when (state.status) {
            PlansStatus.Unavailable -> RetryLine(stringResource(R.string.paywall_error_products), caption, caption, onRetry)
            PlansStatus.Offline -> RetryLine(stringResource(R.string.paywall_offline), caption, caption, onRetry)
            else -> BillingLine(state, caption)
        }
    }
}

@Composable
private fun PlanCard(name: String, price: String, selected: Boolean, onClick: () -> Unit) {
    val shape = RoundedCornerShape(Tokens.Radii.globalCard)
    val selectedLabel = stringResource(R.string.paywall_plans_selected_accessibilitylabel)
    Row(
        Modifier
            .fillMaxWidth()
            .heightIn(min = if (selected) Tokens.Sizes.paywallSizePlanSelectedHeight else Tokens.Sizes.paywallSizePlanHeight)
            .clip(shape)
            .background(if (selected) Tokens.Colors.paywallColorPlanSelected else Tokens.Colors.paywallColorPlan, shape)
            .then(if (selected) Modifier.border(BorderStroke(Tokens.Sizes.paywallSizePlanBorder, Tokens.Colors.paywallColorPlanBorder), shape) else Modifier)
            .selectable(selected = selected, role = Role.RadioButton, onClick = onClick)
            .semantics { if (selected) stateDescription = selectedLabel }
            .padding(horizontal = Tokens.Sizes.paywallSizePlanMarginH),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(name, style = dsTextStyle(Tokens.FontSizes.paywallFontSizePlanName, FontWeight.Bold), color = Tokens.Colors.paywallColorTitle, modifier = Modifier.weight(1f))
        Text(price, style = dsTextStyle(Tokens.FontSizes.paywallFontSizePlanPrice, FontWeight.Bold), color = Tokens.Colors.paywallColorTitle)
    }
}

/** After purchase: `paywall.welcome.title`, `.body` (BLOCKED in release), `.done`. */
@Composable
internal fun WelcomeSheet(onDone: () -> Unit) {
    val context = LocalContext.current
    Column(
        Modifier.fillMaxWidth().navigationBarsPadding().padding(horizontal = Tokens.Sizes.paywallSizePlanMarginH),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(Tokens.Sizes.paywallSizePlanMarginH),
    ) {
        Text(stringResource(R.string.paywall_welcome_title), style = dsTextStyle(Tokens.FontSizes.paywallFontSizePlanSheetTitle, FontWeight.Bold), color = Tokens.Colors.paywallColorTitle, textAlign = TextAlign.Center)
        BlockedCopy.paywallWelcomeBody(context)?.let { Text(it, style = TextStyle(fontSize = Tokens.FontSizes.paywallFontSizeSubtitle), color = Tokens.Colors.paywallColorSubtitle, textAlign = TextAlign.Center) }
        Box(
            Modifier.fillMaxWidth().heightIn(min = Tokens.Sizes.paywallSizeSubscribeHeight).clip(CircleShape).background(Tokens.Colors.paywallColorSubscribe, CircleShape).clickable(role = Role.Button, onClick = onDone),
            contentAlignment = Alignment.Center,
        ) {
            Text(stringResource(R.string.paywall_welcome_done), style = TextStyle(fontSize = Tokens.FontSizes.paywallFontSizeSubscribeLabel), color = Tokens.Colors.paywallColorSubscribeLabel)
        }
    }
}
