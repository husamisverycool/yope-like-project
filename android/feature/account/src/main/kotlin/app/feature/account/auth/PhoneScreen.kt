// Surface: auth.phone — A. landing, B. phone number entry (sign up or log in). Spec: design/surfaces/auth.phone.md.
// References: references/auto/retro/lazyweb/retro-lazyweb-20251119-social.png (LAND, RAW iOS dark: wordmark block, tagline,
// 60-pt capsule, grey link, fine print), references/auto/retro/web/retro.app-5bff8a0be69f7ec7.css (WEB, wordmark 4rem),
// references/auto/retro/lazyweb/retro-lazyweb-20251020-week43-dark.png (H43, title baseline 64),
// references/auto/retro/apk/retro-android-2026.10.1150-strings.txt (APK-S, form copy); B is the onboarding form composition
// of C-02, C-12, C-05, C-08 in Retro's sign-up order (MERGE RA-2).
package app.feature.account.auth

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.asPaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.paddingFrom
import androidx.compose.foundation.text.BasicText
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.TextAutoSize
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalFontFamilyResolver
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.autofill.ContentType
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.layout.LastBaseline
import androidx.compose.ui.layout.Layout
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.TextRange
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.TextFieldValue
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.max
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewModelScope
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.navigation.NavController
import app.data.error.AuthFailure
import app.data.error.DataError
import app.designsystem.R
import app.designsystem.dsTextStyle
import app.designsystem.generated.Tokens
import app.feature.account.AccountEnvironment
import app.feature.account.BuildConfig
import app.feature.account.LocalAccountEnvironment
import app.feature.account.blocked.BlockedCopy
import app.feature.account.common.AccountViewModel
import app.feature.account.common.CollectEvents
import app.feature.account.common.OnboardingForm
import app.feature.account.common.dataError
import app.feature.account.common.errorDismissLabel
import app.feature.account.platform.ExternalActions
import app.model.AppRoute
import app.ui.components.EmptyState
import app.ui.components.EmptyStateAction
import app.ui.components.FinePrint
import app.ui.components.FormTextField
import app.ui.components.HeaderAction
import app.ui.components.LandingLine
import app.ui.components.OnboardingPages
import app.ui.components.PrimaryButton
import app.ui.components.TextLink
import app.ui.components.finePrintText
import app.ui.foundation.PageRoles
import app.ui.foundation.endAtLastBaseline
import app.ui.system.ErrorAlert
import app.ui.text.CapTop
import app.ui.text.TextRoles
import app.ui.text.capTopAt
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlin.math.roundToInt

/** Field errors, shown as the message-only alert of `auth.phone.layout.inlineError` (one "OK"). */
enum class PhoneError(val copy: Int) {
    InvalidNumber(R.string.auth_phone_error_invalidnumber),
    RateLimited(R.string.auth_phone_error_ratelimited),
    SendFailed(R.string.auth_phone_error_sendfailed),
}

data class PhoneUiState(
    /** A. the landing (first screen when signed out) vs B. the phone form. */
    val landing: Boolean = true,
    val phone: String = "+",
    val prefill: String = "+",
    val sending: Boolean = false,
    val offline: Boolean = false,
    val error: PhoneError? = null,
    /** The region whose flag the field shows (`auth.phone.layout.countryCode`); null = no calling code yet. */
    val region: String? = null,
    /** The country list sheet is open. */
    val pickingCountry: Boolean = false,
) {
    val canContinue: Boolean get() = !sending && PhoneNumbers.hasDigitsAfterPrefix(phone, prefill)
}

class PhoneViewModel(private val env: AccountEnvironment) : AccountViewModel() {
    private val region = env.region()
    private val prefill = PhoneNumbers.prefill(region)
    /** The region preferred for a shared calling code: the device's, then the last country picked. */
    private var preferred: String? = region
    private val mutable = MutableStateFlow(
        // Back from auth.code (number kept): straight to the form.
        (env.signUp.phoneDisplay ?: prefill).let {
            PhoneUiState(landing = env.signUp.phoneDisplay == null, phone = it, prefill = prefill, region = PhoneNumbers.regionFor(it, region))
        },
    )
    val state: StateFlow<PhoneUiState> = mutable.asStateFlow()
    private var lastOnline = true

    init {
        viewModelScope.launch {
            env.backend.online.collect { online ->
                lastOnline = online
                mutable.update { it.copy(offline = !online) }
            }
        }
    }

    /** "Get started" or "already have an account?": one-time-code sign-in serves both (spec A → B). */
    fun showForm() = mutable.update { it.copy(landing = false) }

    /** Back on B → A. */
    fun showLanding() = mutable.update { if (it.sending) it else it.copy(landing = true, pickingCountry = false) }

    fun onPhoneChange(text: String) = mutable.update {
        val next = PhoneNumbers.edit(it.phone, PhoneNumbers.sanitize(text))
        it.copy(phone = next, region = PhoneNumbers.regionFor(next, preferred), error = null)
    }

    fun openCountries() = mutable.update { it.copy(pickingCountry = true) }

    fun closeCountries() = mutable.update { it.copy(pickingCountry = false) }

    /** A country chosen in the list: its calling code replaces the typed one. */
    fun onCountry(region: String) {
        preferred = region
        mutable.update { it.copy(phone = PhoneNumbers.withRegion(it.phone, region), region = region, pickingCountry = false, error = null) }
        haptic(Tokens.Haptics.globalSelect)
    }

    fun retry() = mutable.update { it.copy(offline = !lastOnline) }

    fun dismissError() = mutable.update { it.copy(error = null) }

    fun submit() {
        val current = mutable.value
        if (!current.canContinue) return
        val e164 = PhoneNumbers.toE164(current.phone, region)
        if (e164 == null) {
            mutable.update { it.copy(error = PhoneError.InvalidNumber) }
            haptic(Tokens.Haptics.globalError)
            return
        }
        mutable.update { it.copy(sending = true, error = null) }
        viewModelScope.launch {
            try {
                env.backend.requestOtp(e164)
                env.signUp.phoneE164 = e164
                env.signUp.phoneDisplay = current.phone
                env.signUp.codeSentAtMillis = env.clock.millis()
                mutable.update { it.copy(sending = false) }
                navigate(AppRoute.AuthCode)
            } catch (t: Throwable) {
                val error = t.dataError()
                mutable.update {
                    when {
                        error == DataError.Network -> it.copy(sending = false, offline = true)
                        error is DataError.Auth && error.kind == AuthFailure.InvalidPhone -> it.copy(sending = false, error = PhoneError.InvalidNumber)
                        error is DataError.Auth && error.kind == AuthFailure.RateLimited -> it.copy(sending = false, error = PhoneError.RateLimited)
                        else -> it.copy(sending = false, error = PhoneError.SendFailed)
                    }
                }
                haptic(Tokens.Haptics.globalError)
            }
        }
    }
}

@Composable
fun PhoneRoute(nav: NavController) {
    val env = LocalAccountEnvironment.current
    val vm = viewModel { PhoneViewModel(env) }
    val state by vm.state.collectAsStateWithLifecycle()
    val context = LocalContext.current
    CollectEvents(vm.events, nav)
    BackHandler(enabled = !state.landing) { vm.showLanding() }
    PhoneScreen(
        state = state,
        onPhoneChange = vm::onPhoneChange,
        onContinue = vm::submit,
        onRetry = vm::retry,
        onTerms = { env.legal.termsUrl?.let { ExternalActions.openInAppBrowser(context, it) } },
        onPrivacy = { env.legal.privacyUrl?.let { ExternalActions.openInAppBrowser(context, it) } },
        onGetStarted = vm::showForm,
        onBack = vm::showLanding,
        onDismissError = vm::dismissError,
        onFlag = vm::openCountries,
        onCountry = vm::onCountry,
        onCloseCountries = vm::closeCountries,
    )
}

/**
 * A (landing) and B (form) are pages of one surface: they change with Retro's onboarding page transition (C-33:
 * fade + expand / fade + shrink, `duration.global.pageTransition`; Reduce Motion keeps the fades).
 */
@Composable
fun PhoneScreen(
    state: PhoneUiState,
    onPhoneChange: (String) -> Unit,
    onContinue: () -> Unit,
    onRetry: () -> Unit,
    onTerms: () -> Unit,
    onPrivacy: () -> Unit,
    onGetStarted: () -> Unit = {},
    onBack: () -> Unit = {},
    onDismissError: () -> Unit = {},
    onFlag: () -> Unit = {},
    onCountry: (String) -> Unit = {},
    onCloseCountries: () -> Unit = {},
    focusOnAppear: Boolean = true,
) {
    OnboardingPages(if (state.landing) LANDING else FORM) { page ->
        if (page == LANDING) {
            Landing(onGetStarted, onTerms, onPrivacy)
        } else {
            PhoneForm(state, onPhoneChange, onContinue, onRetry, onBack, onFlag, focusOnAppear)
        }
    }
    if (!state.landing) {
        state.error?.let { ErrorAlert(stringResource(it.copy), errorDismissLabel(), onDismissError) }
        if (state.pickingCountry) CountryPickerSheet(state.region, onCountry, onCloseCountries)
    }
}

private const val LANDING = 0
private const val FORM = 1

/**
 * A. Landing (LAND, C-33): the wordmark block — the app's name in `font.global.display` at `auth.phone.fontSize.wordmark`,
 * regular, `color.global.textPrimary` (BLOCKED until `config/app.json` `displayName`: debug shows the placeholder, release
 * omits it), the tagline `auth.phone.size.wordmarkToTagline` below its baseline (C-33 [LandingLine]) — centred at
 * `auth.phone.layout.landingBlock.centreY` of the screen height; at the bottom the C-05 capsule at
 * `size.global.buttonMarginH`, the C-08 link `auth.phone.size.capsuleToLink` below it (ink), the fine print
 * `auth.phone.size.linkToLegal` below the link with "Terms" / "Privacy Policy" underlined, its last baseline
 * `auth.phone.size.legalToBottom` above the screen bottom (or the navigation bar, when that is taller).
 */
@Composable
private fun Landing(onGetStarted: () -> Unit, onTerms: () -> Unit, onPrivacy: () -> Unit) {
    val wordmark = BuildConfig.APP_DISPLAY_NAME ?: BlockedCopy.appName()
    val linkStyle = TextRoles.listTitle
    val legalStyle = TextRoles.caption
    val navigation = WindowInsets.navigationBars.asPaddingValues().calculateBottomPadding()
    Layout(
        modifier = Modifier.fillMaxSize().background(PageRoles.page),
        content = {
            Column(Modifier.fillMaxWidth().padding(horizontal = Tokens.Sizes.globalScreenMargin), horizontalAlignment = Alignment.CenterHorizontally) {
                if (wordmark != null) {
                    // One line, as Retro's wordmark: a name too long for the width steps down from the token size.
                    BasicText(
                        wordmark,
                        style = dsTextStyle(Tokens.FontSizes.authPhoneFontSizeWordmark, Tokens.FontWeights.fontWeightGlobalHeaderTitle, Tokens.Fonts.globalDisplay)
                            .copy(color = Tokens.Colors.globalTextPrimary, textAlign = TextAlign.Center),
                        maxLines = 1,
                        autoSize = TextAutoSize.StepBased(maxFontSize = Tokens.FontSizes.authPhoneFontSizeWordmark),
                        modifier = Modifier.endAtLastBaseline().semantics { heading() },
                    )
                }
                // The tagline's cap top `auth.phone.size.wordmarkToTagline` below the wordmark's baseline (LAND ink gap).
                val taglineGap = if (wordmark != null) Tokens.Sizes.authPhoneSizeWordmarkToTagline else Dp.Unspecified
                LandingLine(stringResource(R.string.auth_phone_tagline), Modifier.capTopAt(taglineGap, CapTop.height(TextRoles.onboardingTitle)))
            }
            Column(Modifier.fillMaxWidth(), horizontalAlignment = Alignment.CenterHorizontally) {
                PrimaryButton(stringResource(R.string.auth_phone_getstarted), onGetStarted, Modifier.padding(horizontal = Tokens.Sizes.globalButtonMarginH))
                TextLink(
                    stringResource(R.string.auth_phone_signin),
                    onGetStarted,
                    Modifier.capTopAt(Tokens.Sizes.authPhoneSizeCapsuleToLink, CapTop.height(linkStyle)),
                )
                val text = stringResource(R.string.auth_phone_legal_text)
                val terms = stringResource(R.string.auth_phone_legal_terms)
                val privacy = stringResource(R.string.auth_phone_legal_privacy)
                FinePrint(
                    finePrintText(text, listOf(terms to onTerms, privacy to onPrivacy)),
                    Modifier
                        .padding(horizontal = Tokens.Sizes.globalScreenMargin)
                        .capTopAt(Tokens.Sizes.authPhoneSizeLinkToLegal, CapTop.height(legalStyle))
                        // LAND measures the last line's ink bottom (the descenders), not its baseline.
                        .paddingFrom(LastBaseline, after = max(Tokens.Sizes.authPhoneSizeLegalToBottom + inkDescent(legalStyle, text), navigation)),
                )
            }
        },
    ) { measurables, constraints ->
        val loose = constraints.copy(minWidth = 0, minHeight = 0)
        val block = measurables[0].measure(loose)
        val footer = measurables[1].measure(loose)
        val height = constraints.maxHeight
        val footerTop = height - footer.height
        // The block's centre at the measured fraction of the screen height, never under the footer.
        val centre = (height * Tokens.Layouts.AuthPhoneLayoutLandingBlock.centreY).roundToInt()
        val blockTop = (centre - block.height / 2).coerceAtMost(footerTop - block.height).coerceAtLeast(0)
        layout(constraints.maxWidth, height) {
            block.place((constraints.maxWidth - block.width) / 2, blockTop)
            footer.place(0, footerTop)
        }
    }
}

/**
 * B. The phone form (onboarding form composition, [OnboardingForm]): back → A; title / explanation; C-12 phone field
 * with the flag slot and inline calling code (`auth.phone.layout.countryCode`, `auth.phone.layout.keyboard`); C-05 "Next"
 * (disabled until digits follow the calling code; busy while sending — field and back disabled). Offline: the C-27 block
 * (no glyph) with the outline "Try again" in place of field and capsule.
 */
@Composable
private fun PhoneForm(
    state: PhoneUiState,
    onPhoneChange: (String) -> Unit,
    onContinue: () -> Unit,
    onRetry: () -> Unit,
    onBack: () -> Unit,
    onFlag: () -> Unit,
    focusOnAppear: Boolean,
) {
    val focus = remember { FocusRequester() }
    var field by remember { mutableStateOf(TextFieldValue(state.phone, TextRange(state.phone.length))) }
    if (field.text != state.phone) field = TextFieldValue(state.phone, TextRange(state.phone.length))
    OnboardingForm(
        title = stringResource(R.string.auth_phone_title),
        explanation = stringResource(R.string.auth_phone_subtitle),
        back = HeaderAction(Tokens.Icons.globalBack, stringResource(R.string.auth_code_back_accessibilitylabel)) { if (!state.sending) onBack() },
        replacement = if (state.offline) {
            { OfflineBlock(onRetry) }
        } else {
            null
        },
        bottom = { PrimaryButton(stringResource(R.string.auth_phone_continue), onContinue, enabled = state.canContinue || state.sending, loading = state.sending) },
    ) {
        FormTextField(
            value = field,
            onValueChange = { field = it; onPhoneChange(it.text) },
            placeholder = stringResource(R.string.auth_phone_field_placeholder),
            accessibilityLabel = stringResource(R.string.auth_phone_field_accessibilitylabel),
            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Phone, imeAction = ImeAction.Done),
            keyboardActions = KeyboardActions(onDone = { onContinue() }),
            autofill = ContentType.PhoneNumber,
            enabled = !state.sending,
            modifier = Modifier.focusRequester(focus),
            leading = state.region?.let { region -> { CountryFlagButton(region, onFlag) } },
            leadingInset = CountryFlagSlot.inset,
            leadingClearance = CountryFlagSlot.clearance,
        )
    }
    if (focusOnAppear && !state.offline) LaunchedEffect(Unit) { runCatching { focus.requestFocus() } }
}

/** The sign-up offline block (C-27 error / offline variant, no glyph): `auth.phone.offline.*`, outline capsule "Try again". */
@Composable
internal fun OfflineBlock(onRetry: () -> Unit) {
    EmptyState(
        title = stringResource(R.string.auth_phone_offline_title),
        detail = stringResource(R.string.auth_phone_offline_detail),
        action = EmptyStateAction(stringResource(R.string.auth_phone_offline_retry), onRetry),
    )
}

/** How far [text]'s lowest glyph (a descender) reaches below the baseline in [style]'s resolved platform font. */
@Composable
private fun inkDescent(style: androidx.compose.ui.text.TextStyle, text: String): Dp {
    val density = LocalDensity.current
    val resolver = LocalFontFamilyResolver.current
    return remember(style, text, density, resolver) {
        val typeface = resolver.resolve(
            style.fontFamily,
            style.fontWeight ?: androidx.compose.ui.text.font.FontWeight.Normal,
            style.fontStyle ?: androidx.compose.ui.text.font.FontStyle.Normal,
            style.fontSynthesis ?: androidx.compose.ui.text.font.FontSynthesis.All,
        ).value as? android.graphics.Typeface ?: android.graphics.Typeface.DEFAULT
        val paint = android.graphics.Paint(android.graphics.Paint.ANTI_ALIAS_FLAG).apply {
            this.typeface = typeface
            textSize = with(density) { style.fontSize.toPx() }
        }
        val bounds = android.graphics.Rect()
        paint.getTextBounds(text, 0, text.length, bounds)
        with(density) { bounds.bottom.coerceAtLeast(0).toDp() }
    }
}
