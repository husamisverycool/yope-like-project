package app.ui.startup

import android.app.Application
import java.util.ServiceLoader

/**
 * Process-start hook points for feature groups that own UI plugged into foundation modules — the
 * capture group's `PhotoWidgetSlots.current` / `WidgetConfigureUi.current` (core:widget) and
 * notification UI (core:push).
 *
 * A feature module implements this interface and lists the class in its own
 * `src/main/resources/META-INF/services/app.ui.startup.AppStartupHook`; the app shell
 * (`app.main.App.onCreate`) runs every registered hook once, after the data layer is installed. No
 * edit of `:app` is needed to register one.
 */
interface AppStartupHook {
    fun install(application: Application)

    companion object {
        /** Runs every hook found on the class path; a failing hook does not stop the others. */
        fun runAll(application: Application, loader: ClassLoader = AppStartupHook::class.java.classLoader!!): List<AppStartupHook> {
            val hooks = ServiceLoader.load(AppStartupHook::class.java, loader).toList()
            hooks.forEach { hook -> runCatching { hook.install(application) } }
            return hooks
        }
    }
}
