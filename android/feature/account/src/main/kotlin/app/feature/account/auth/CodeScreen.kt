// Surface: auth.code — SMS code entry. Spec: design/surfaces/auth.code.md.
// References: as auth.phone (S24, S26, C24, BI, NG, HUD) plus
// references/auto/yope/frames/a-virgi-7686278541255642390-t31.23-signup-es.png x262-479 y76-94 (lime text link).
package app.feature.account.auth

import androidx.compose.foundation.layout.Spacer
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
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.autofill.ContentType
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.TextRange
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.TextFieldValue
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
import app.feature.account.common.CollectEvents
import app.feature.account.common.SignUpLayout
import app.feature.account.common.dataError
import app.feature.account.shell.AccountFlow
import app.ui.components.FormTextField
import app.ui.components.HeaderCircleButton
import app.ui.components.HeaderCircleFill
import app.ui.components.HudOverlay
import app.ui.components.OnboardingTitle
import app.ui.components.PrimaryButton
import app.ui.components.TextLink
import app.ui.text.TextRoles
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

/** Failure states whose presentation is BLOCKED (`auth.phone.layout.inlineError`): kept in state, not drawn. */
enum class CodeError(val copy: Int) {
    Wrong(R.string.auth_code_error_wrong),
    Expired(R.string.auth_code_error_expired),
    TooMany(R.string.auth_code_error_toomany),
}

data class CodeUiState(
    val phoneDisplay: String = "",
    val code: String = "",
    val verifying: Boolean = false,
    val offline: Boolean = false,
    val error: CodeError? = null,
    val resendLocked: Boolean = true,
) {
    val canContinue: Boolean get() = !verifying && code.any(Char::isDigit)
}

class CodeViewModel(private val env: AccountEnvironment) : AccountViewModel() {
    private val phone = env.signUp.phoneE164
    private val mutable = MutableStateFlow(CodeUiState(phoneDisplay = phone?.let(PhoneNumbers::display).orEmpty()))
    val state: StateFlow<CodeUiState> = mutable.asStateFlow()
    private var lockJob: Job? = null
    /** Set once the code is verified, so a retry after an offline failure only resolves the next step. */
    private var verifiedUser: String? = null

    init {
        startResendLock()
        viewModelScope.launch { env.backend.online.collect { online -> if (online) mutable.update { it.copy(offline = false) } } }
    }

    fun onCodeChange(text: String) = mutable.update { it.copy(code = text.filter(Char::isLetterOrDigit).take(MAX_CODE), error = null) }

    /** A code delivered by the SMS User Consent sheet: filled into the field (no auto-submit, spec). */
    fun onCodeReceived(code: String) = onCodeChange(code)

    fun submit() {
        val current = mutable.value
        val number = phone ?: return navigate(app.model.AppRoute.AuthPhone, clearStack = true)
        if (verifiedUser == null && !current.canContinue) return
        mutable.update { it.copy(verifying = true, error = null, offline = false) }
        viewModelScope.launch {
            try {
                val uid = verifiedUser ?: env.backend.verifyOtp(number, current.code).also { verifiedUser = it }
                val next = AccountFlow.nextAfterSignIn(env, uid, justVerified = true)
                mutable.update { it.copy(verifying = false) }
                haptic(Tokens.Haptics.globalSuccess)
                navigate(next, clearStack = true)
            } catch (t: Throwable) {
                val error = t.dataError()
                mutable.update {
                    when {
                        error == DataError.Network -> it.copy(verifying = false, offline = true)
                        error is DataError.Auth && error.kind == AuthFailure.RateLimited -> it.copy(verifying = false, error = CodeError.TooMany)
                        error is DataError.Auth && error.kind == AuthFailure.InvalidOrExpiredCode && isExpired() -> it.copy(verifying = false, error = CodeError.Expired, code = "")
                        else -> it.copy(verifying = false, error = CodeError.Wrong, code = "")
                    }
                }
                haptic(Tokens.Haptics.globalError)
            }
        }
    }

    fun resend() {
        val number = phone ?: return
        if (mutable.value.resendLocked) return
        env.signUp.codeSentAtMillis = env.clock.millis()
        startResendLock()
        viewModelScope.launch {
            try {
                env.backend.requestOtp(number)
                haptic(Tokens.Haptics.globalSuccess)
            } catch (t: Throwable) {
                val error = t.dataError()
                val rateLimited = error is DataError.Auth && error.kind == AuthFailure.RateLimited
                mutable.update {
                    when {
                        error == DataError.Network -> it.copy(offline = true)
                        rateLimited -> it.copy(error = CodeError.TooMany)
                        else -> it
                    }
                }
                haptic(Tokens.Haptics.globalError)
            }
        }
    }

    fun retryOffline() = if (verifiedUser != null) submit() else mutable.update { it.copy(offline = false) }

    /** GoTrue reports wrong and expired codes alike; a code older than its 1-h lifetime is "expired". */
    private fun isExpired(): Boolean {
        val sent = env.signUp.codeSentAtMillis ?: return false
        return env.clock.millis() - sent > CODE_LIFETIME_MS
    }

    /** "send new code" is disabled for `auth.code.duration.resendLock` after each request (no countdown shown). */
    private fun startResendLock() {
        lockJob?.cancel()
        val sent = env.signUp.codeSentAtMillis ?: env.clock.millis()
        val remaining = Tokens.Durations.authCodeDurationResendLock - (env.clock.millis() - sent)
        mutable.update { it.copy(resendLocked = remaining > 0) }
        if (remaining > 0) {
            lockJob = viewModelScope.launch {
                delay(remaining)
                mutable.update { it.copy(resendLocked = false) }
            }
        }
    }

    private companion object {
        const val MAX_CODE = 10
        /** Supabase: OTPs "expire after 1 hour" (docs/PLATFORM_CONSTRAINTS.md §7). */
        const val CODE_LIFETIME_MS = 60 * 60 * 1000L
    }
}

@Composable
fun CodeRoute(nav: NavController) {
    val env = LocalAccountEnvironment.current
    val vm = viewModel { CodeViewModel(env) }
    val state by vm.state.collectAsStateWithLifecycle()
    CollectEvents(vm.events, nav)
    SmsUserConsentEffect(enabled = env.smsUserConsent, restartKey = env.signUp.codeSentAtMillis, onCode = vm::onCodeReceived)
    CodeScreen(state, vm::onCodeChange, vm::submit, vm::resend, onBack = { nav.popBackStack() }, onRetry = vm::retryOffline)
}

@Composable
fun CodeScreen(
    state: CodeUiState,
    onCodeChange: (String) -> Unit,
    onContinue: () -> Unit,
    onResend: () -> Unit,
    onBack: () -> Unit,
    onRetry: () -> Unit,
    focusOnAppear: Boolean = true,
) {
    if (state.offline) {
        SignUpOffline(stringResource(R.string.auth_code_offline_detail), onRetry)
        return
    }
    val focus = remember { FocusRequester() }
    var field by remember { mutableStateOf(TextFieldValue(state.code, TextRange(state.code.length))) }
    if (field.text != state.code) field = TextFieldValue(state.code, TextRange(state.code.length))
    SignUpLayout(
        header = {
            HeaderCircleButton(
                Tokens.Icons.globalBack,
                stringResource(R.string.auth_code_back_accessibilitylabel),
                onBack,
                fill = HeaderCircleFill.OnDeep,
                modifier = Modifier.align(Alignment.TopStart),
            )
        },
        overlay = { HudOverlay(state.verifying, stringResource(R.string.groups_create_hud_loading)) },
    ) {
        OnboardingTitle(stringResource(R.string.auth_code_title))
        Text(stringResource(R.string.auth_code_subtitle, state.phoneDisplay), style = TextRoles.onboardingSubtitle, modifier = Modifier.fillMaxWidth())
        Spacer(Modifier.height(Tokens.Sizes.groupsCreateSizeTitleToContent))
        FormTextField(
            value = field,
            onValueChange = { field = it; onCodeChange(it.text) },
            placeholder = stringResource(R.string.auth_code_field_placeholder),
            accessibilityLabel = stringResource(R.string.auth_code_field_accessibilitylabel),
            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.NumberPassword, imeAction = ImeAction.Done),
            keyboardActions = KeyboardActions(onDone = { onContinue() }),
            autofill = ContentType.SmsOtpCode,
            modifier = Modifier.focusRequester(focus),
        )
        Spacer(Modifier.height(Tokens.Sizes.groupsCreateSizeFieldToButton))
        PrimaryButton(stringResource(R.string.auth_code_continue), onContinue, enabled = state.canContinue)
        Spacer(Modifier.height(Tokens.Sizes.groupsCreateSizeFieldToButton))
        TextLink(stringResource(R.string.auth_code_resend), onResend, enabled = !state.resendLocked)
    }
    if (focusOnAppear) LaunchedEffect(Unit) { runCatching { focus.requestFocus() } }
}
