package app.feature.memory.common

import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.ui.platform.LocalView
import app.designsystem.Haptics
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.receiveAsFlow

/** A one-shot effect from a view model: a `haptic` token to play, or a request to close the screen. */
sealed interface MemoryEffect {
    /** `Tokens.Haptics.*` constant. */
    data class Haptic(val constant: Int) : MemoryEffect
    data object Close : MemoryEffect
}

/** One-shot effects, delivered once to whoever collects (the screen). */
class EffectQueue {
    private val channel = Channel<MemoryEffect>(Channel.BUFFERED)
    val effects: Flow<MemoryEffect> = channel.receiveAsFlow()

    fun haptic(constant: Int) {
        channel.trySend(MemoryEffect.Haptic(constant))
    }

    fun close() {
        channel.trySend(MemoryEffect.Close)
    }
}

/** Plays haptics on the current view (respecting the system setting) and handles close requests. */
@Composable
fun CollectEffects(effects: Flow<MemoryEffect>, onClose: () -> Unit) {
    val view = LocalView.current
    val close by rememberUpdatedState(onClose)
    LaunchedEffect(effects, view) {
        effects.collect { effect ->
            when (effect) {
                is MemoryEffect.Haptic -> Haptics.perform(view, effect.constant)
                MemoryEffect.Close -> close()
            }
        }
    }
}
