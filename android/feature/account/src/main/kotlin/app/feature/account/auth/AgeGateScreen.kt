// Surface: auth.agegate — birthday / age gate at sign-up. Spec: design/surfaces/auth.agegate.md.
// References: as auth.phone (S24, S26, C24, BI, NG, HUD) plus
// references/auto/yope/frames/a-itsmthuyope-7644974799302823175-t49.23-new-group-selected-create.png (check circles).
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
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
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
import app.feature.account.blocked.BlockedCopy
import app.feature.account.common.AccountViewModel
import app.feature.account.common.CenteredState
import app.feature.account.common.CollectEvents
import app.feature.account.common.SignUpLayout
import app.feature.account.common.SignUpStack
import app.feature.account.common.dataError
import app.feature.account.platform.AgeRefusal
import app.feature.account.shell.AccountFlow
import app.ui.components.CheckRow
import app.ui.components.EmptyState
import app.ui.components.EmptyStateAction
import app.ui.components.FormTextField
import app.ui.components.HudOverlay
import app.ui.components.OnboardingTitle
import app.ui.components.PrimaryButton
import app.ui.text.TextRoles
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
    AgeGateScreen(state, pattern, vm.canContinue, vm::onDigits, vm::onOptIn, vm::submit, vm::retry)
}

@Composable
fun AgeGateScreen(
    state: AgeGateUiState,
    pattern: DateEntryPattern,
    canContinue: Boolean,
    onDigits: (String) -> Unit,
    onOptIn: (Boolean) -> Unit,
    onContinue: () -> Unit,
    onRetry: () -> Unit,
    focusOnAppear: Boolean = true,
) {
    val context = LocalContext.current
    when {
        state.refusal != null -> {
            val minAge = state.refusal.minAge?.toString()
            CenteredState {
                EmptyState(
                    // BLOCKED in release ({app_name}); omitted there, the detail stays.
                    title = minAge?.let { BlockedCopy.ageGateUnderAgeTitle(context, it) },
                    detail = stringResource(R.string.auth_agegate_underage_detail),
                )
            }
            return
        }
        state.notConfigured -> {
            CenteredState {
                EmptyState(
                    title = stringResource(R.string.auth_agegate_notconfigured_title),
                    detail = stringResource(R.string.auth_agegate_notconfigured_detail),
                    action = EmptyStateAction(stringResource(R.string.auth_agegate_notconfigured_retry), onRetry),
                )
            }
            return
        }
        state.offline -> {
            SignUpOffline(stringResource(R.string.auth_agegate_offline_detail), onRetry)
            return
        }
    }
    val focus = remember { FocusRequester() }
    val formatted = pattern.format(state.digits)
    var field by remember { mutableStateOf(TextFieldValue(formatted, TextRange(formatted.length))) }
    if (field.text != formatted) field = TextFieldValue(formatted, TextRange(formatted.length))
    SignUpLayout(overlay = { HudOverlay(state.checking, stringResource(R.string.groups_create_hud_loading)) }) {
        OnboardingTitle(stringResource(R.string.auth_agegate_title), capTop = SignUpStack.titleCapTop)
        Text(stringResource(R.string.auth_agegate_subtitle), style = TextRoles.onboardingSubtitle, modifier = Modifier.fillMaxWidth())
        Spacer(Modifier.height(Tokens.Sizes.groupsCreateSizeTitleToContent))
        FormTextField(
            value = field,
            onValueChange = { onDigits(it.text) },
            placeholder = stringResource(R.string.auth_agegate_field_placeholder, pattern.placeholder),
            accessibilityLabel = stringResource(R.string.auth_agegate_field_accessibilitylabel),
            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number, imeAction = ImeAction.Done),
            keyboardActions = KeyboardActions(onDone = { onContinue() }),
            modifier = Modifier.focusRequester(focus),
        )
        Spacer(Modifier.height(Tokens.Sizes.groupsCreateSizeFieldToButton))
        CheckRow(
            label = stringResource(R.string.auth_agegate_optin_label),
            checked = state.optIn,
            onCheckedChange = onOptIn,
            accessibilityLabel = stringResource(R.string.auth_agegate_optin_accessibilitylabel),
            detail = stringResource(R.string.auth_agegate_optin_detail),
        )
        Spacer(Modifier.height(Tokens.Sizes.groupsCreateSizeFieldToButton))
        PrimaryButton(stringResource(R.string.auth_agegate_continue), onContinue, enabled = canContinue)
    }
    if (focusOnAppear) LaunchedEffect(Unit) { runCatching { focus.requestFocus() } }
}
