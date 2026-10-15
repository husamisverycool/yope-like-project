package app.feature.account.common

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawing
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import app.designsystem.generated.Tokens

/**
 * The sign-up / onboarding form stack (Yope sign-in screen + onboarding form, auth.phone Structure):
 * background `color.global.backgroundDeep`; content inside the safe area, starting at the safe-area
 * top — the title places itself by cap top (`OnboardingTitle(capTop = SignUpStack.titleCapTop)`,
 * `groups.create.size.sheetTopToTitle` below the safe-area top); content side
 * margins `size.global.buttonMarginH` (the form column); the stack stays top-aligned above the
 * keyboard and scrolls when it no longer fits (large text). [footer] sits at the bottom (it moves up
 * with the stack while the keyboard is shown — approximation, auth.phone Gaps). [header] is drawn
 * over the top of the safe area (back circle at `size.global.headerInset`). [overlay] draws above
 * everything (Loading HUD).
 */
@Composable
fun SignUpLayout(
    modifier: Modifier = Modifier,
    background: Color = Tokens.Colors.globalBackgroundDeep,
    header: (@Composable BoxScope.() -> Unit)? = null,
    footer: (@Composable ColumnScope.() -> Unit)? = null,
    overlay: @Composable BoxScope.() -> Unit = {},
    content: @Composable ColumnScope.() -> Unit,
) {
    Box(modifier.fillMaxSize().background(background)) {
        BoxWithConstraints(Modifier.fillMaxSize().windowInsetsPadding(WindowInsets.safeDrawing).imePadding()) {
            val minHeight = maxHeight
            Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState())) {
                Column(
                    Modifier.fillMaxWidth().heightIn(min = minHeight),
                    verticalArrangement = Arrangement.SpaceBetween,
                ) {
                    Column(
                        Modifier.fillMaxWidth().padding(horizontal = Tokens.Sizes.globalButtonMarginH),
                        horizontalAlignment = Alignment.CenterHorizontally,
                        content = content,
                    )
                    if (footer != null) {
                        Column(
                            Modifier.fillMaxWidth().padding(horizontal = Tokens.Sizes.globalScreenMargin),
                            horizontalAlignment = Alignment.CenterHorizontally,
                            content = footer,
                        )
                    }
                }
            }
            if (header != null) {
                Box(Modifier.fillMaxWidth().padding(horizontal = Tokens.Sizes.globalHeaderInset), content = header)
            }
        }
        overlay()
    }
}

/** Constants of the sign-up stack. */
object SignUpStack {
    /** Safe-area top to the title's cap top (`groups.create.size.sheetTopToTitle`; auth.phone Structure 3). */
    val titleCapTop: androidx.compose.ui.unit.Dp get() = Tokens.Sizes.groupsCreateSizeSheetTopToTitle
}

/** A full-screen, centred Yope empty-state replacing the stack (offline, not configured, under age). */
@Composable
fun CenteredState(modifier: Modifier = Modifier, background: Color = Tokens.Colors.globalBackgroundDeep, content: @Composable BoxScope.() -> Unit) {
    Box(
        modifier.fillMaxSize().background(background).windowInsetsPadding(WindowInsets.safeDrawing),
        contentAlignment = Alignment.Center,
        content = content,
    )
}
