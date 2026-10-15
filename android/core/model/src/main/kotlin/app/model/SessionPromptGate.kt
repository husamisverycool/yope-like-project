package app.model

/**
 * The premium prompt appears at most once per app process ("session"), and never while the
 * person is capturing or onboarding (directive: "at most one prompt per session").
 *
 * Screens that must never be interrupted wrap themselves in [enter]/[exit] (or [during]); the
 * code that wants to show the prompt calls [tryClaim] and shows it only on `true`.
 */
class SessionPromptGate {
    enum class Blocker { Capture, Onboarding }

    private val lock = Any()
    private val activeBlockers = mutableMapOf<Blocker, Int>()
    private var claimed = false

    fun enter(blocker: Blocker) = synchronized(lock) {
        activeBlockers[blocker] = (activeBlockers[blocker] ?: 0) + 1
    }

    fun exit(blocker: Blocker) = synchronized(lock) {
        val n = (activeBlockers[blocker] ?: 0) - 1
        if (n <= 0) activeBlockers.remove(blocker) else activeBlockers[blocker] = n
    }

    inline fun <T> during(blocker: Blocker, block: () -> T): T {
        enter(blocker)
        try {
            return block()
        } finally {
            exit(blocker)
        }
    }

    val isBlocked: Boolean get() = synchronized(lock) { activeBlockers.isNotEmpty() }

    /** True once this process has shown the prompt. */
    val hasPrompted: Boolean get() = synchronized(lock) { claimed }

    /** Whether a prompt could be shown right now, without claiming it. */
    val canPrompt: Boolean get() = synchronized(lock) { !claimed && activeBlockers.isEmpty() }

    /**
     * Claims the session's single prompt. Returns true at most once per instance, and only when no
     * blocker is active; the caller must then show the prompt.
     */
    fun tryClaim(): Boolean = synchronized(lock) {
        if (claimed || activeBlockers.isNotEmpty()) return false
        claimed = true
        true
    }

    companion object {
        /** The process-wide gate: one instance lives exactly as long as the app process. */
        val process: SessionPromptGate = SessionPromptGate()
    }
}
