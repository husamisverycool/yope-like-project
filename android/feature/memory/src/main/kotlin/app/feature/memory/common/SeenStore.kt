package app.feature.memory.common

import android.content.Context
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.platform.LocalContext

/**
 * Remembers, per account, which one-time things a member has seen — the On This Day feature intro
 * (design/surfaces/onthisday.md C: "first open, once per account … never shown again").
 */
interface SeenStore {
    fun seen(userId: String, key: String): Boolean
    fun markSeen(userId: String, key: String)
}

/** [SeenStore] in app-private SharedPreferences. */
class PrefsSeenStore(context: Context) : SeenStore {
    private val prefs = context.applicationContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
    override fun seen(userId: String, key: String): Boolean = prefs.getBoolean("$key.$userId", false)
    override fun markSeen(userId: String, key: String) = prefs.edit().putBoolean("$key.$userId", true).apply()

    private companion object {
        const val PREFS = "memory.seen"
    }
}

/** Overrides the store below this point (tests). Null = SharedPreferences. */
val LocalSeenStore = staticCompositionLocalOf<SeenStore?> { null }

@Composable
fun rememberSeenStore(): SeenStore {
    LocalSeenStore.current?.let { return it }
    val context = LocalContext.current
    return remember(context) { PrefsSeenStore(context) }
}
