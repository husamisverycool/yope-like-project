package app.ui.paywall

import androidx.navigation.NavController
import app.model.AppRoute
import app.model.SessionPromptGate

/**
 * Opening the premium screen from a locked perk (`paywall.layout.promptRule`): at most one prompt per
 * session (`SessionPromptGate`), never during capture or onboarding, never on launch, after a post
 * or on a timer. Call it from the person's tap on a locked control; it opens `paywall` only when the
 * gate grants the session's single prompt, and returns whether it did (otherwise the control just
 * keeps its "Premium" badge, `paywall.locked.badge`). The settings premium row opens
 * [AppRoute.Paywall] directly (navigation the person chose; not counted).
 */
fun NavController.openPaywallFromLockedPerk(gate: SessionPromptGate = SessionPromptGate.process): Boolean {
    if (!gate.tryClaim()) return false
    navigate(AppRoute.Paywall)
    return true
}
