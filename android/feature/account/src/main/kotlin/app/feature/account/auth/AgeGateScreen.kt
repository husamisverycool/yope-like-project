// Surface: auth.agegate — birthday / age gate at sign-up (neutral age screen). Spec: design/surfaces/auth.agegate.md.
// References: references/auto/retro/lazyweb/retro-lazyweb-20251119-social.png (LAND: page, capsule),
// references/auto/retro/video/ig-DJXvmqRv2_N-referrals-sheet-f042-059.png (VID-SET: grouped row with a switch, C-14),
// references/auto/retro/apk/retro-android-2026.10.1150-strings.txt (APK-S patterns); FTC COPPA FAQ (PLATFORM_CONSTRAINTS §9).
// Composition of C-02, C-12, C-14, C-05 in Retro's sign-up order (MERGE RA-2, RA-4).
package app.feature.account.auth

import androidx.compose.animation.Crossfade
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.safeDrawing
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.TextRange
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.TextFieldValue
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewModelScope
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.navigation.NavController
import app.data.error.ApiError
import app.data.error.DataError
import app.designsystem.R
import app.designsystem.generated.Tokens
import app.feature.account.AccountEnvironment
import app.feature.account.LocalAccountEnvironment
import app.feature.account.common.AccountViewModel
import app.feature.account.common.CollectEvents
import app.feature.account.common.OnboardingForm
import app.feature.account.common.dataError
import app.feature.account.common.errorDismissLabel
import app.feature.account.platform.AgeRefusal
import app.feature.account.shell.AccountFlow
import app.ui.components.EmptyState
import app.ui.components.EmptyStateAction
import app.ui.components.FormTextField
import app.ui.components.GroupedPosition
import app.ui.components.GroupedRow
import app.ui.components.GroupedRowSpec
import app.ui.components.GroupedTrailing
import app.ui.components.PrimaryButton
import app.ui.foundation.DsMotion
import app.ui.foundation.PageRoles
import app.ui.system.ErrorAlert
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import java.time.LocalDate
import java.time.chrono.IsoChronology
import java.time.format.DateTimeFormatterBuilder
import java.time.format.FormatStyle
import java.util.Locale

/**
 * The neutral birthday entry (`auth.agegate.layout.dateEntry`): free numeric entry in the device
 * locale's short-date order, separators inserted while typing, a four-digit year, no default.
 */
data class DateEntryPattern(val order: List<Char>, val separator: Char) {
    /** "mm/dd/yyyy" in the locale's order, for the placeholder's `{date_format}`. */
    val placeholder: String get() = order.joinToString(separator.toString()) { field -> segment(field).lowercase() }

    fun format(digits: String): String {
        val sb = StringBuilder()
        var at = 0
        order.forEachIndexed { index, field ->
            val length = segment(field).length
            if (at >= digits.length) return sb.toString()
            if (index > 0) sb.append(separator)
            val end = minOf(digits.length, at + length)
            sb.append(digits, at, end)
            at = end
        }
        return sb.toString()
    }

    /** The date when every digit is typed and it exists in the calendar, else null. */
    fun parse(digits: String): LocalDate? {
        if (digits.length != MAX_DIGITS) return null
        var at = 0
        val values = HashMap<Char, Int>()
        for (field in order) {
            val length = segment(field).length
            values[field] = digits.substring(at, at + length).toInt()
            at += length
        }
        return try {
            LocalDate.of(values.getValue('y'), values.getValue('M'), values.getValue('d'))
        } catch (_: java.time.DateTimeException) {
            null
        }
    }

    private fun segment(field: Char): String = when (field) {
        'y' -> "yyyy"
        'M' -> "MM"
        else -> "dd"
    }

    companion object {
        const val MAX_DIGITS = 8

        fun of(locale: Locale): DateEntryPattern {
            val pattern = DateTimeFormatterBuilder.getLocalizedDateTimePattern(FormatStyle.SHORT, null, IsoChronology.INSTANCE, locale)
            val order = pattern.filter { it == 'y' || it == 'M' || it == 'd' }.toList().distinct()
            val separator = pattern.firstOrNull { !it.isLetter() && it != '\'' && !it.isWhitespace() } ?: '/'
            return DateEntryPattern(if (order.size == 3) order else listOf('M', 'd', 'y'), separator)
        }
    }
}

data class AgeGateUiState(
    val digits: String = "",
    val optIn: Boolean = false,
    val checking: Boolean = false,
    val invalidDate: Boolean = false,
    val notConfigured: Boolean = false,
    val offline: Boolean = false,
    /** Under the minimum age: the refusal (min age shown in the title when known). */
    val refusal: AgeRefusal? = null,
)

class AgeGateViewModel(private val env: AccountEnvironment, private val pattern: DateEntryPattern) : AccountViewModel() {
    private val mutable = MutableStateFlow(AgeGateUiState(refusal = env.stores.ageRefusal()))
    val state: StateFlow<AgeGateUiState> = mutable.asStateFlow()

    val canContinue: Boolean get() = with(mutable.value) { !checking && pattern.parse(digits) != null }

    fun dismissError() = mutable.update { it.copy(invalidDate = false) }

    fun onDigits(text: String) = mutable.update { it.copy(digits = text.filter(Char::isDigit).take(DateEntryPattern.MAX_DIGITS), invalidDate = false) }

    fun onOptIn(value: Boolean) = mutable.update { it.copy(optIn = value) }

    fun retry() = mutable.update { it.copy(notConfigured = false, offline = false) }

    fun submit() {
        if (mutable.value.refusal != null) return
        val date = pattern.parse(mutable.value.digits)
        if (date == null) {
            mutable.update { it.copy(invalidDate = true) }
            haptic(Tokens.Haptics.globalError)
            return
        }
        val optIn = mutable.value.optIn
        mutable.update { it.copy(checking = true, invalidDate = false) }
        viewModelScope.launch {
            try {
                env.backend.confirmAge(date)
                if (optIn) env.backend.setBirthday(date, true)
                val uid = env.backend.currentUserId
                val next = if (uid != null) AccountFlow.nextAfterSignIn(env, uid, justVerified = false) else app.model.AppRoute.AuthProfile
                mutable.update { it.copy(checking = false) }
                haptic(Tokens.Haptics.globalSuccess)
                navigate(next, clearStack = true)
            } catch (t: Throwable) {
                val error = t.dataError()
                val code = (error as? DataError.Api)?.code
                when {
                    code == ApiError.UnderMinimumAge -> refuse()
                    code == ApiError.AgeGateNotConfigured -> mutable.update { it.copy(checking = false, notConfigured = true) }
                    code == ApiError.InvalidBirthdate -> mutable.update { it.copy(checking = false, invalidDate = true) }
                    error == DataError.Network -> mutable.update { it.copy(checking = false, offline = true) }
                    else -> mutable.update { it.copy(checking = false, invalidDate = true) }
                }
                haptic(Tokens.Haptics.globalError)
            }
        }
    }

    /**
     * `under_minimum_age`: remember the refusal on the device (cannot be retried by going back),
     * delete what was entered (the account the phone number created; the birthdate is never stored)
     * so the refusal detail ("we didn’t save your birthday or your number") holds, and sign out.
     */
    private suspend fun refuse() {
        val minAge = runCatching { env.backend.publicConfig().minAgeYears }.getOrNull()
        val refusal = AgeRefusal(minAge)
        env.stores.rememberAgeRefusal(refusal)
        mutable.update { it.copy(checking = false, refusal = refusal) }
        runCatching { env.backend.deleteAccount() }
        runCatching { env.backend.signOut() }
    }
}

@Composable
fun AgeGateRoute(nav: NavController) {
    val env = LocalAccountEnvironment.current
    val pattern = remember { DateEntryPattern.of(Locale.getDefault()) }
    val vm = viewModel { AgeGateViewModel(env, pattern) }
    val state by vm.state.collectAsStateWithLifecycle()
    CollectEvents(vm.events, nav)
    AgeGateScreen(state, pattern, vm.canContinue, vm::onDigits, vm::onOptIn, vm::submit, vm::retry, onDismissError = vm::dismissError)
}

/**
 * The onboarding form ([OnboardingForm], no back: the account exists after auth.code): title / explanation (no age is
 * shown); the C-12 birthday field (`auth.agegate.layout.dateEntry`: numeric, the locale's order as the placeholder,
 * separators inserted, empty by default); `size.global.titleToContent` below it the opt-in (`auth.agegate.layout.optIn`:
 * one C-14 row — title `body`, subtitle `meta`, native switch, off — at least `settings.root.size.rowHeight` high); C-05
 * "Next" (disabled until the date is complete; busy while checking). Not configured / under age: the C-27 block (no glyph)
 * centred on the page in place of the form; offline: the title block stays and the block replaces field, row and capsule.
 * State changes cross-fade `duration.global.crossfade`.
 */
@Composable
fun AgeGateScreen(
    state: AgeGateUiState,
    pattern: DateEntryPattern,
    canContinue: Boolean,
    onDigits: (String) -> Unit,
    onOptIn: (Boolean) -> Unit,
    onContinue: () -> Unit,
    onRetry: () -> Unit,
    onDismissError: () -> Unit = {},
    focusOnAppear: Boolean = true,
) {
    val phase = when {
        state.refusal != null -> AgePhase.Refused
        state.notConfigured -> AgePhase.NotConfigured
        else -> AgePhase.Form
    }
    Crossfade(targetState = phase, animationSpec = DsMotion.crossfade(), label = "ageGatePhase") { shown ->
        when (shown) {
            AgePhase.Refused -> PageBlock {
                EmptyState(
                    title = state.refusal?.minAge?.let { stringResource(R.string.auth_agegate_underage_title, it.toString()) },
                    detail = stringResource(R.string.auth_agegate_underage_detail),
                )
            }
            AgePhase.NotConfigured -> PageBlock {
                EmptyState(
                    title = stringResource(R.string.auth_agegate_notconfigured_title),
                    detail = stringResource(R.string.auth_agegate_notconfigured_detail),
                    action = EmptyStateAction(stringResource(R.string.auth_agegate_notconfigured_retry), onRetry),
                )
            }
            AgePhase.Form -> AgeForm(state, pattern, canContinue, onDigits, onOptIn, onContinue, onRetry, focusOnAppear)
        }
    }
    if (phase == AgePhase.Form && state.invalidDate) ErrorAlert(stringResource(R.string.auth_agegate_error_invaliddate), errorDismissLabel(), onDismissError)
}

private enum class AgePhase { Form, NotConfigured, Refused }

/** A C-27 block centred on the page (inside the safe area). */
@Composable
private fun PageBlock(content: @Composable () -> Unit) {
    Box(
        Modifier.fillMaxSize().background(PageRoles.page).windowInsetsPadding(WindowInsets.safeDrawing),
        contentAlignment = Alignment.Center,
    ) { content() }
}

@Composable
private fun AgeForm(
    state: AgeGateUiState,
    pattern: DateEntryPattern,
    canContinue: Boolean,
    onDigits: (String) -> Unit,
    onOptIn: (Boolean) -> Unit,
    onContinue: () -> Unit,
    onRetry: () -> Unit,
    focusOnAppear: Boolean,
) {
    val focus = remember { FocusRequester() }
    val formatted = pattern.format(state.digits)
    var field by remember { mutableStateOf(TextFieldValue(formatted, TextRange(formatted.length))) }
    if (field.text != formatted) field = TextFieldValue(formatted, TextRange(formatted.length))
    OnboardingForm(
        title = stringResource(R.string.auth_agegate_title),
        explanation = stringResource(R.string.auth_agegate_subtitle),
        replacement = if (state.offline) {
            { OfflineBlock(onRetry) }
        } else {
            null
        },
        bottom = { PrimaryButton(stringResource(R.string.auth_agegate_continue), onContinue, enabled = canContinue || state.checking, loading = state.checking) },
    ) {
        FormTextField(
            value = field,
            onValueChange = { onDigits(it.text) },
            placeholder = stringResource(R.string.auth_agegate_field_placeholder, pattern.placeholder),
            accessibilityLabel = stringResource(R.string.auth_agegate_field_accessibilitylabel),
            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number, imeAction = ImeAction.Done),
            keyboardActions = KeyboardActions(onDone = { onContinue() }),
            enabled = !state.checking,
            modifier = Modifier.focusRequester(focus),
        )
        Spacer(Modifier.height(Tokens.Sizes.globalTitleToContent))
        val optInLabel = stringResource(R.string.auth_agegate_optin_accessibilitylabel)
        // The C-14 single row sits inside the form's margin (the C-14 group inset is the same size.global.screenMargin).
        GroupedRow(
            GroupedRowSpec(
                title = stringResource(R.string.auth_agegate_optin_label),
                subtitle = stringResource(R.string.auth_agegate_optin_detail),
                trailing = GroupedTrailing.Toggle(state.optIn, onOptIn),
                enabled = !state.checking,
            ),
            GroupedPosition.Single,
            Modifier.semantics { contentDescription = optInLabel },
            minHeight = Tokens.Sizes.settingsRootSizeRowHeight,
        )
    }
    if (focusOnAppear && !state.offline) LaunchedEffect(Unit) { runCatching { focus.requestFocus() } }
}
