package app.feature.memory.birthday

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import app.designsystem.generated.Tokens
import app.feature.memory.common.EffectQueue
import app.feature.memory.common.Failure
import app.feature.memory.common.MemoryBackend
import app.feature.memory.common.attempt
import app.feature.memory.common.failureOf
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import java.time.LocalDate

/** design/surfaces/birthday.add.md state. */
data class BirthdayAddState(
    /** Reading `profile_private` (manage vs. add). */
    val loading: Boolean = true,
    /** The saved birthday while opted in (manage); null = not opted in (add). */
    val saved: LocalDate? = null,
    /** Digits typed into the date field (the field inserts the separators). */
    val digits: String = "",
    /** A save / remove call is running: the primary shows the indicator, buttons disabled. */
    val busy: Boolean = false,
    /** Inline line under the date field. */
    val inline: Inline? = null,
    /** Error block above the buttons; the primary becomes "try again". */
    val error: Boolean = false,
    val toast: Toast? = null,
    /** Added: the screen closes (after the toast in debug builds). */
    val finished: Boolean = false,
) {
    enum class Inline { Invalid, Offline }
    enum class Toast { Added, Removed }

    val optedIn: Boolean get() = saved != null
}

/**
 * `birthday.add`: opt in with a date (`set_birthday(date, true)`), or remove (`set_birthday(saved,
 * false)`), never asked again automatically. "maybe later" makes no call.
 */
class BirthdayAddViewModel(private val backend: MemoryBackend, private val pattern: DateEntryPattern) : ViewModel() {
    private val _state = MutableStateFlow(BirthdayAddState())
    val state: StateFlow<BirthdayAddState> = _state.asStateFlow()
    private val queue = EffectQueue()
    val effects = queue.effects

    init {
        viewModelScope.launch {
            val row = attempt { backend.privateProfile() }.getOrNull()
            _state.update { it.copy(loading = false, saved = row?.birthday?.takeIf { row.birthdayOptIn }) }
        }
    }

    /** The complete date in the field, or null (the add button stays disabled). */
    val enteredDate: LocalDate? get() = pattern.parse(_state.value.digits)

    fun setDigits(digits: String) = _state.update {
        val complete = digits.length == pattern.length
        it.copy(digits = digits, inline = if (complete && pattern.parse(digits) == null) BirthdayAddState.Inline.Invalid else null, error = false)
    }

    /** "add my birthday" (or "try again" after an error). */
    fun add() {
        val date = enteredDate ?: return
        save(date, optIn = true)
    }

    /** "remove my birthday" (manage). */
    fun remove() {
        val date = _state.value.saved ?: return
        save(date, optIn = false)
    }

    /** "maybe later" / close: no call. */
    fun later() = queue.close()

    fun dismissToast() {
        val finished = _state.value.finished
        _state.update { it.copy(toast = null) }
        if (finished) queue.close()
    }

    private fun save(date: LocalDate, optIn: Boolean) {
        if (_state.value.busy) return
        if (!backend.isOnline()) {
            _state.update { it.copy(inline = BirthdayAddState.Inline.Offline) }
            return
        }
        _state.update { it.copy(busy = true, inline = null, error = false) }
        viewModelScope.launch {
            attempt { backend.setBirthday(date, optIn) }
                .onSuccess { row ->
                    queue.haptic(Tokens.Haptics.globalSuccess)
                    _state.update {
                        it.copy(
                            busy = false,
                            saved = row.birthday?.takeIf { row.birthdayOptIn },
                            digits = "",
                            toast = if (optIn) BirthdayAddState.Toast.Added else BirthdayAddState.Toast.Removed,
                            finished = optIn,
                        )
                    }
                }
                .onFailure { e ->
                    queue.haptic(Tokens.Haptics.globalError)
                    _state.update {
                        when (failureOf(e)) {
                            Failure.InvalidDate -> it.copy(busy = false, inline = BirthdayAddState.Inline.Invalid)
                            Failure.Offline -> it.copy(busy = false, inline = BirthdayAddState.Inline.Offline)
                            else -> it.copy(busy = false, error = true)
                        }
                    }
                }
        }
    }
}
