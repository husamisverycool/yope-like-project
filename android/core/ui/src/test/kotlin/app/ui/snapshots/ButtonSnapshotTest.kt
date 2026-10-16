package app.ui.snapshots

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import app.designsystem.generated.Tokens
import app.ui.components.Capsule
import app.ui.components.CapsuleRowSpacing
import app.ui.components.CapsuleStyle
import app.ui.components.CapsuleToggle
import app.ui.components.DestructiveTextButton
import app.ui.components.HeaderTextButton
import app.ui.components.IconCapsule
import app.ui.components.MediaPill
import app.ui.components.MediaPillStyle
import app.ui.components.OutlineCta
import app.ui.components.PrimaryButton
import app.ui.components.PrimaryButtonSize
import app.ui.components.TextLink
import app.ui.foundation.DsImage
import org.junit.Test

/** C-05 primary capsule, C-06 medium capsules, C-07 outline CTA, C-08 text buttons, C-09 media pills, C-10 destructive. */
class ButtonSnapshotTest(appearance: Appearance) : SnapshotTest(appearance) {
    @Composable
    private fun Margins(content: @Composable () -> Unit) = Box(Modifier.padding(horizontal = Tokens.Sizes.globalButtonMarginH)) { content() }

    @Test fun c05Enabled() = snap("c05-primary-capsule", "enabled") { Margins { PrimaryButton("Get started", {}) } }

    @Test fun c05Disabled() = snap("c05-primary-capsule", "disabled") { Margins { PrimaryButton("Get started", {}, enabled = false) } }

    @Test fun c05Loading() = snap("c05-primary-capsule", "loading") { Margins { PrimaryButton("Get started", {}, loading = true) } }

    @Test fun c05Sheet() = snap("c05-primary-capsule", "sheet") { Margins { PrimaryButton("Send Postcard", {}, size = PrimaryButtonSize.Sheet) } }

    @Test fun c05OnMedia() = snap("c05-primary-capsule", "on-media", surface = Surface.Media) { Margins { PrimaryButton("Send Postcard", {}, onMedia = true) } }

    @Test fun c05FontScale200() = snap("c05-primary-capsule", "font-scale-200", fontScale = 2f) { Margins { PrimaryButton("Get this week started", {}) } }

    @Composable
    private fun ActionRow(content: @Composable androidx.compose.foundation.layout.RowScope.() -> Unit) =
        Row(Modifier.fillMaxWidth().padding(horizontal = Tokens.Sizes.globalScreenMargin), horizontalArrangement = CapsuleRowSpacing, content = content)

    @Test fun c06Variants() = snap("c06-medium-capsules", "primary-outline-fill") {
        Stack {
            ActionRow {
                Capsule("Accept", {}, Modifier.weight(1f), style = CapsuleStyle.Primary)
                Capsule("Decide Later", {}, Modifier.weight(1f), style = CapsuleStyle.Outline)
            }
            ActionRow {
                Capsule("Recaps", {}, Modifier.weight(1f))
                Capsule("Share Profile", {}, Modifier.weight(1f))
                IconCapsule(Tokens.Icons.globalSettings, "Settings", {})
            }
            ActionRow { Capsule("Create", {}, style = CapsuleStyle.Fill) }
        }
    }

    @Test fun c06Disabled() = snap("c06-medium-capsules", "disabled") {
        ActionRow {
            Capsule("Accept", {}, Modifier.weight(1f), style = CapsuleStyle.Primary, enabled = false)
            Capsule("Decide Later", {}, Modifier.weight(1f), enabled = false)
            Capsule("Create", {}, style = CapsuleStyle.Fill, enabled = false)
        }
    }

    @Test fun c06Toggle() = snap("c06-medium-capsules", "toggle-off-on") {
        ActionRow {
            CapsuleToggle("I'm in this", selected = false, onSelectedChange = {})
            CapsuleToggle("I'm in this", selected = true, onSelectedChange = {})
        }
    }

    @Test fun c07OutlineCta() = snap("c07-outline-cta", "enabled-disabled") {
        Column(Modifier.fillMaxWidth(), horizontalAlignment = Alignment.CenterHorizontally) {
            Stack {
                Box(Modifier.fillMaxWidth(), contentAlignment = Alignment.Center) { OutlineCta("Get this week started", {}) }
                Box(Modifier.fillMaxWidth(), contentAlignment = Alignment.Center) { OutlineCta("Invite friends", {}, icon = Tokens.Icons.globalLink, enabled = false) }
            }
        }
    }

    @Test fun c08TextButtons() = snap("c08-text-buttons", "header-and-link") {
        Column(Modifier.padding(horizontal = Tokens.Sizes.globalScreenMargin)) {
            Stack {
                Row(horizontalArrangement = CapsuleRowSpacing) {
                    HeaderTextButton("Invite", {})
                    HeaderTextButton("Keys", {}, enabled = false)
                }
                TextLink("already have an account?", {}, Modifier.fillMaxWidth())
                TextLink("send a new code", {}, Modifier.fillMaxWidth(), enabled = false)
            }
        }
    }

    @Test fun c09MediaPills() = snap("c09-media-pills", "light-and-dark", surface = Surface.Photo) {
        Box(Modifier.fillMaxWidth().height(Tokens.Sizes.globalFriendCardWidth)) {
            DsImage(landscape(8), null, Modifier.fillMaxWidth().height(Tokens.Sizes.globalFriendCardWidth))
            Row(Modifier.align(Alignment.Center), horizontalArrangement = CapsuleRowSpacing) {
                MediaPill("Share", {})
                MediaPill("Add a message", {}, style = MediaPillStyle.Dark, icon = Tokens.Icons.globalEdit)
            }
        }
    }

    @Test fun c10Destructive() = snap("c10-destructive", "text-actions") {
        Column(Modifier.padding(horizontal = Tokens.Sizes.globalScreenMargin)) {
            Stack {
                DestructiveTextButton("Delete from Photos", {}, icon = Tokens.Icons.globalTrash)
                DestructiveTextButton("Leave group", {}, icon = Tokens.Icons.globalLeave)
                DestructiveTextButton("Report", {}, enabled = false)
            }
        }
    }
}
