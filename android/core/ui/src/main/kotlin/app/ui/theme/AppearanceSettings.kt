package app.ui.theme

import android.content.Context
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.core.content.edit
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow

/**
 * Android-only appearance options kept on this device (settings.root → Appearance; owner decision 21: Retro's
 * "true black" dark scheme, `colorScheme = isDark ? (trueBlack ? d42.w : d42.v) : d42.u` —
 * design/research/retro-package-copy-motion.md §3.1). Persisted the way the app keeps its other device settings
 * (app-private SharedPreferences behind an interface with an in-memory twin, as `DeviceAccountStores` /
 * `SharedCapturePrefs`); [trueBlack] is a flow so the theme follows a change at once.
 */
interface AppearanceSettings {
    /** Settings → True Black: the dark appearance draws its page in `color.global.background.android.trueBlack`. */
    val trueBlack: StateFlow<Boolean>

    fun setTrueBlack(on: Boolean)

    companion object {
        /** The device's settings (one per process). */
        fun device(context: Context): AppearanceSettings = DeviceAppearanceSettings.get(context)
    }
}

/** [AppearanceSettings] in app-private preferences; off until the person turns it on (Retro's default dark scheme). */
private class DeviceAppearanceSettings private constructor(context: Context) : AppearanceSettings {
    private val prefs = context.applicationContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
    private val state = MutableStateFlow(prefs.getBoolean(KEY_TRUE_BLACK, false))

    override val trueBlack: StateFlow<Boolean> = state

    override fun setTrueBlack(on: Boolean) {
        prefs.edit { putBoolean(KEY_TRUE_BLACK, on) }
        state.value = on
    }

    companion object {
        private const val PREFS = "appearance"
        private const val KEY_TRUE_BLACK = "true_black"

        @Volatile private var instance: DeviceAppearanceSettings? = null

        fun get(context: Context): DeviceAppearanceSettings = instance ?: synchronized(this) {
            instance ?: DeviceAppearanceSettings(context).also { instance = it }
        }
    }
}

/** In-memory [AppearanceSettings] (tests, previews). */
class MemoryAppearanceSettings(trueBlack: Boolean = false) : AppearanceSettings {
    private val state = MutableStateFlow(trueBlack)
    override val trueBlack: StateFlow<Boolean> = state
    override fun setTrueBlack(on: Boolean) {
        state.value = on
    }
}

/**
 * The settings [AppTheme] follows; the app shell provides the device's ([AppearanceSettings.device]). Without one
 * (tests, previews, the widget configuration activity) True Black is off unless the caller passes it.
 */
val LocalAppearanceSettings = staticCompositionLocalOf<AppearanceSettings?> { null }

/** Settings → True Black as the composition sees it (false without [LocalAppearanceSettings]). */
@Composable
fun currentTrueBlack(): Boolean = LocalAppearanceSettings.current?.trueBlack?.collectAsState()?.value ?: false
