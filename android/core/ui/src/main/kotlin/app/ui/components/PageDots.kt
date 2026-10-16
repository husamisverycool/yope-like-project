package app.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.stateDescription
import app.designsystem.generated.Tokens

/**
 * C-31 Page dots: [count] circles of `size.global.pageDot`, centre to centre `size.global.pageDotPitch`; the
 * [selected] one `color.global.textPrimary` (on media `color.global.textOnMedia`), the others
 * `color.global.pageDotInactive` (on media — black in both appearances — its dark value #808080, TC-REC
 * "white / grey on dark"). TalkBack reads [description] (copy, "page 2 of 4" — platform page-control
 * semantics). Inactive dots on white fail contrast (CONTRAST failure 9).
 */
@Composable
fun PageDots(count: Int, selected: Int, description: String, modifier: Modifier = Modifier, onMedia: Boolean = false) {
    val active = if (onMedia) Tokens.Colors.globalTextOnMedia else Tokens.Colors.globalTextPrimary
    val inactive = if (onMedia) Tokens.ColorsDark.globalPageDotInactive else Tokens.Colors.globalPageDotInactive
    Row(
        modifier.clearAndSetSemantics { stateDescription = description },
        horizontalArrangement = Arrangement.spacedBy(Tokens.Sizes.globalPageDotPitch - Tokens.Sizes.globalPageDot),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        repeat(count) { i ->
            Box(Modifier.size(Tokens.Sizes.globalPageDot).background(if (i == selected) active else inactive, CircleShape))
        }
    }
}
