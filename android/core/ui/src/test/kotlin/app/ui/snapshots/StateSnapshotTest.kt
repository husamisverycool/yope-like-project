package app.ui.snapshots

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import app.designsystem.generated.Tokens
import app.ui.components.ActivityIndicator
import app.ui.components.BusyOverlay
import app.ui.components.EmptyState
import app.ui.components.EmptyStateAction
import app.ui.components.FinePrint
import app.ui.components.Hairline
import app.ui.components.LandingHero
import app.ui.components.OnboardingTitle
import app.ui.components.PageDots
import app.ui.components.SegmentedControl
import app.ui.components.finePrintText
import app.ui.text.TextRoles
import org.junit.Test

/** C-27 empty / error / offline / permission states, C-28 loading, C-30 segmented control, C-31 page dots, C-32 divider, C-33 landing / onboarding. */
class StateSnapshotTest(appearance: Appearance) : SnapshotTest(appearance) {
    @Test fun c27Empty() = snap("c27-empty-state", "empty-cta") {
        EmptyState("Welcome to Week 43!", null, Modifier.fillMaxWidth(), action = EmptyStateAction("Get this week started", {}, Tokens.Icons.globalAdd), icon = Tokens.Icons.globalCalendar)
    }

    @Test fun c27ErrorRetry() = snap("c27-empty-state", "error-retry") {
        EmptyState("Error loading friends", "Check your connection and tap to try again.", Modifier.fillMaxWidth(), action = EmptyStateAction("Try again", {}))
    }

    @Test fun c27Offline() = snap("c27-empty-state", "offline") {
        EmptyState("You're offline", "Your weeks will be here when you're back online.", Modifier.fillMaxWidth(), icon = Tokens.Icons.globalCalendar)
    }

    @Test fun c27Permission() = snap("c27-empty-state", "permission-denied") {
        EmptyState("Allow photo access", "Pick photos from your library to add them to your week.", Modifier.fillMaxWidth(), action = EmptyStateAction("Open Settings", {}), icon = Tokens.Icons.globalGallery)
    }

    @Test fun c27FontScale200() = snap("c27-empty-state", "font-scale-200", fontScale = 2f) {
        EmptyState("Welcome to Week 43!", null, Modifier.fillMaxWidth(), action = EmptyStateAction("Get this week started", {}, Tokens.Icons.globalAdd), icon = Tokens.Icons.globalCalendar)
    }

    @Test fun c28IndicatorOnPage() = snap("c28-loading", "indicator-page") { Centre { ActivityIndicator("Loading") } }

    @Test fun c28IndicatorOnMedia() = snap("c28-loading", "indicator-media", surface = Surface.Media) { Centre { ActivityIndicator("Loading", onMedia = true) } }

    @Test fun c28BusyOverlay() = snap("c28-loading", "busy-overlay") {
        Box(Modifier.fillMaxWidth().height(Tokens.Sizes.globalFriendCardWidth)) {
            Text("Week 43", style = TextRoles.headerTitle, color = Tokens.Colors.globalTextPrimary, modifier = Modifier.padding(horizontal = Tokens.Sizes.globalScreenMargin))
            BusyOverlay(visible = true, contentDescription = "Saving")
        }
    }

    @Composable
    private fun Centre(content: @Composable () -> Unit) = Box(Modifier.fillMaxWidth(), contentAlignment = Alignment.Center) { content() }

    @Test fun c30FirstSelected() = snap("c30-segmented-control", "first-selected") {
        Box(Modifier.padding(horizontal = Tokens.Sizes.globalScreenMargin)) { SegmentedControl(listOf("Yearly", "Monthly", "Weekly", "All Posts"), 0, {}) }
    }

    @Test fun c30LastSelected() = snap("c30-segmented-control", "last-selected") {
        Box(Modifier.padding(horizontal = Tokens.Sizes.globalScreenMargin)) { SegmentedControl(listOf("Friends", "Family"), 1, {}) }
    }

    @Test fun c31OnPage() = snap("c31-page-dots", "page") { Centre { PageDots(4, 1, "Page 2 of 4") } }

    @Test fun c31OnMedia() = snap("c31-page-dots", "media", surface = Surface.Media) { Centre { PageDots(4, 0, "Page 1 of 4", onMedia = true) } }

    @Test fun c32Divider() = snap("c32-divider", "page") {
        Column(Modifier.padding(horizontal = Tokens.Sizes.globalScreenMargin), verticalArrangement = Arrangement.spacedBy(Tokens.Sizes.globalPillGap)) {
            Text("Subtotal", style = TextRoles.listTitle, color = Tokens.Colors.globalTextPrimary)
            Hairline()
            Text("Total", style = TextRoles.listTitle, color = Tokens.Colors.globalTextPrimary)
        }
    }

    @Test fun c32DividerOnMedia() = snap("c32-divider", "media", surface = Surface.Media) {
        Column(Modifier.padding(horizontal = Tokens.Sizes.globalScreenMargin), verticalArrangement = Arrangement.spacedBy(Tokens.Sizes.globalPillGap)) {
            Text("Mexico City", style = TextRoles.listTitle, color = Tokens.Colors.globalTextOnMedia)
            Hairline(onMedia = true)
            Text("elton so good", style = TextRoles.body, color = Tokens.Colors.globalTextOnMedia)
        }
    }

    @Test fun c33Landing() = snapScreen("c33-onboarding", "landing") {
        LandingHero(
            line = "Friends Only",
            primaryText = "Get started",
            onPrimary = {},
            linkText = "already have an account?",
            onLink = {},
            finePrint = finePrintText("By continuing, I confirm I have read the Terms and Privacy Policy", listOf("Terms" to {}, "Privacy Policy" to {})),
            modifier = Modifier.padding(vertical = Tokens.Sizes.globalTitleTop),
        )
    }

    @Test fun c33OnboardingTitle() = snap("c33-onboarding", "page-title") {
        Column(Modifier.padding(horizontal = Tokens.Sizes.globalScreenMargin), verticalArrangement = Arrangement.spacedBy(Tokens.Sizes.globalScreenMargin)) {
            OnboardingTitle("Who are your people?")
            FinePrint(finePrintText("We'll text you a code. Terms apply.", listOf("Terms" to {})))
        }
    }
}
