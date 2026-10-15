// Surface: auth.phone — phone number entry (sign up or log in). Spec: design/surfaces/auth.phone.md.
// References: references/auto/yope/frames/a-yrrah-7454430216123862280-t6.73-signup-2024.png (S24),
// a-virgi-7686278541255642390-t31.23-signup-es.png (S26), a-yrrah-7452976839846382855-t3.73-create-new-group-empty-2024.png (C24),
// references/auto/yope/web/a-bi-2025-create-group-composite.jpg (BI),
// a-itsmthuyope-7644974799302823175-t49.23-new-group-selected-create.png (NG), -t50.60-loading-hud.png (HUD).
package app.feature.account.auth

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawing
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.ui.Alignment
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.autofill.ContentType
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.LinkAnnotation
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.TextLinkStyles
import androidx.compose.ui.text.TextRange
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.TextFieldValue
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.withLink
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewModelScope
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.navigation.NavController
import app.data.error.AuthFailure
import app.data.error.DataError
import app.designsystem.R
import app.designsystem.generated.Tokens
import app.feature.account.AccountEnvironment
import app.feature.account.LocalAccountEnvironment
import app.feature.account.common.AccountViewModel
import app.feature.account.common.CenteredState
import app.feature.account.common.CollectEvents
import app.feature.account.common.SignUpLayout
import app.feature.account.common.SignUpStack
import app.feature.account.common.dataError
import app.feature.account.platform.ExternalActions
import app.model.AppRoute
import app.ui.components.EmptyState
import app.ui.components.EmptyStateAction
import app.ui.components.FormTextField
import app.ui.components.HudOverlay
import app.ui.system.ErrorAlert
import app.feature.account.common.errorDismissLabel
import app.ui.components.OnboardingTitle
import app.ui.components.PrimaryButton
import app.ui.text.TextRoles
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

/** Field errors, shown as the alert of `auth.phone.layout.inlineError` (message = the error sentence, one OK). */
enum class PhoneError(val copy: Int) {
    InvalidNumber(R.string.auth_phone_error_invalidnumber),
    RateLimited(R.string.auth_phone_error_ratelimited),
    SendFailed(R.string.auth_phone_error_sendfailed),
}

data class PhoneUiState(
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
        (env.signUp.phoneDisplay ?: prefill).let { PhoneUiState(phone = it, prefill = prefill, region = PhoneNumbers.regionFor(it, region)) },
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
                haptic(Tokens.Haptics.globalSuccess)
                toast(R.string.auth_phone_toast_codesent)
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
    PhoneScreen(
        state = state,
        onPhoneChange = vm::onPhoneChange,
        onContinue = vm::submit,
        onRetry = vm::retry,
        onDismissError = vm::dismissError,
        onFlag = vm::openCountries,
        onCountry = vm::onCountry,
        onCloseCountries = vm::closeCountries,
        onTerms = { env.legal.termsUrl?.let { ExternalActions.openInAppBrowser(context, it) } },
        onPrivacy = { env.legal.privacyUrl?.let { ExternalActions.openInAppBrowser(context, it) } },
    )
}

@Composable
fun PhoneScreen(
    state: PhoneUiState,
    onPhoneChange: (String) -> Unit,
    onContinue: () -> Unit,
    onRetry: () -> Unit,
    onTerms: () -> Unit,
    onPrivacy: () -> Unit,
    onDismissError: () -> Unit = {},
    onFlag: () -> Unit = {},
    onCountry: (String) -> Unit = {},
    onCloseCountries: () -> Unit = {},
    focusOnAppear: Boolean = true,
) {
    if (state.offline) {
        OfflineWithFooter(footer = { LegalFooter(onTerms, onPrivacy) }) {
            EmptyState(
                title = stringResource(R.string.auth_phone_offline_title),
                detail = stringResource(R.string.auth_phone_offline_detail),
                action = EmptyStateAction(stringResource(R.string.auth_phone_offline_retry), onRetry),
            )
        }
        return
    }
    val focus = remember { FocusRequester() }
    var field by remember { mutableStateOf(TextFieldValue(state.phone, TextRange(state.phone.length))) }
    if (field.text != state.phone) field = TextFieldValue(state.phone, TextRange(state.phone.length))
    SignUpLayout(
        footer = { LegalFooter(onTerms, onPrivacy) },
        overlay = { HudOverlay(state.sending, stringResource(R.string.groups_create_hud_loading)) },
    ) {
        OnboardingTitle(stringResource(R.string.auth_phone_title), capTop = SignUpStack.titleCapTop)
        Text(stringResource(R.string.auth_phone_subtitle), style = TextRoles.onboardingSubtitle, modifier = Modifier.fillMaxWidth())
        Spacer(Modifier.height(Tokens.Sizes.groupsCreateSizeTitleToContent))
        FormTextField(
            value = field,
            onValueChange = { field = it; onPhoneChange(it.text) },
            placeholder = stringResource(R.string.auth_phone_field_placeholder),
            accessibilityLabel = stringResource(R.string.auth_phone_field_accessibilitylabel),
            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Phone, imeAction = ImeAction.Done),
            keyboardActions = KeyboardActions(onDone = { onContinue() }),
            autofill = ContentType.PhoneNumber,
            modifier = Modifier.focusRequester(focus),
            leading = state.region?.let { region -> { CountryFlagButton(region, onFlag) } },
            leadingInset = CountryFlagSlot.inset,
            leadingClearance = CountryFlagSlot.clearance,
        )
        Spacer(Modifier.height(Tokens.Sizes.groupsCreateSizeFieldToButton))
        PrimaryButton(stringResource(R.string.auth_phone_continue), onContinue, enabled = state.canContinue)
    }
    state.error?.let { ErrorAlert(stringResource(it.copy), errorDismissLabel(), onDismissError) }
    if (state.pickingCountry) CountryPickerSheet(state.region, onCountry, onCloseCountries)
    if (focusOnAppear) LaunchedEffect(Unit) { runCatching { focus.requestFocus() } }
}

/** The legal footer (`auth.phone.layout.legalFooter`): caption role, secondary colour, link phrases bold. */
@Composable
internal fun LegalFooter(onTerms: () -> Unit, onPrivacy: () -> Unit) {
    val text = stringResource(R.string.auth_phone_legal_text)
    val terms = stringResource(R.string.auth_phone_legal_terms)
    val privacy = stringResource(R.string.auth_phone_legal_privacy)
    val linkStyle = TextLinkStyles(style = SpanStyle(fontWeight = FontWeight.Bold)) // auth.phone.layout.legalFooter links: "bold weight"
    val annotated = buildAnnotatedString {
        val ranges = listOf(terms to onTerms, privacy to onPrivacy)
            .mapNotNull { (phrase, action) -> text.indexOf(phrase).takeIf { it >= 0 }?.let { Triple(it, phrase, action) } }
            .sortedBy { it.first }
        var at = 0
        for ((start, phrase, action) in ranges) {
            if (start < at) continue
            append(text.substring(at, start))
            withLink(LinkAnnotation.Clickable(tag = phrase, styles = linkStyle) { action() }) { append(phrase) }
            at = start + phrase.length
        }
        append(text.substring(at))
    }
    Text(
        annotated,
        style = TextRoles.caption, // F-24: the global caption role (footer weight not measured separately)
        color = Tokens.Colors.globalTextSecondary,
        textAlign = TextAlign.Center,
        modifier = Modifier.fillMaxWidth(),
    )
}

/** The offline variant of the stack: the empty state centred in place of 3–8, the footer kept at the bottom. */
@Composable
private fun OfflineWithFooter(footer: @Composable () -> Unit, content: @Composable () -> Unit) {
    Column(
        Modifier.fillMaxSize().background(Tokens.Colors.globalBackgroundDeep).windowInsetsPadding(WindowInsets.safeDrawing),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Box(Modifier.weight(1f).fillMaxWidth(), contentAlignment = Alignment.Center) { content() }
        Box(Modifier.fillMaxWidth().padding(horizontal = Tokens.Sizes.globalScreenMargin)) { footer() }
    }
}

/** Kept for the shared offline layout of later steps (auth.code, auth.agegate, auth.profile). */
@Composable
internal fun SignUpOffline(detail: String, onRetry: () -> Unit) {
    CenteredState {
        EmptyState(
            title = stringResource(R.string.auth_phone_offline_title),
            detail = detail,
            action = EmptyStateAction(stringResource(R.string.auth_phone_offline_retry), onRetry),
        )
    }
}
