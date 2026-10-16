package app.ui.foundation

import androidx.compose.runtime.Composable
import androidx.compose.runtime.ReadOnlyComposable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import app.designsystem.LocalDsTrueBlack
import app.designsystem.generated.Tokens

/**
 * The colour roles that differ on Android (design/components.md "Rules" → Android page; tokens README →
 * Platform pairs): Retro's Android app draws the page in `color.global.background.android` (#FFFFFF /
 * #1C1C1E), grouped rows, chips and the reply bar in `color.global.surfaceSecondary.android` where iOS uses
 * `color.global.control`, and secondary text in `color.global.textSecondary.android` (black 50 % / white
 * 60 %). On media surfaces (black in both appearances) secondary text stays `color.global.textSecondary`
 * (#999999), as the README's "Media stays dark" rule says.
 */
object PageRoles {
    /**
     * Page background (Android): `color.global.background.android`, or with Settings → True Black
     * (`LocalDsTrueBlack`, owner decision 21) `color.global.background.android.trueBlack` — #000000 in dark, the same
     * #FFFFFF in light.
     */
    val page: Color @Composable @ReadOnlyComposable get() =
        if (LocalDsTrueBlack.current) Tokens.Colors.globalBackgroundAndroidTrueBlack else Tokens.Colors.globalBackgroundAndroid

    /** Rows, chips, reply bar, sheet cards (Android). */
    val secondarySurface: Color @Composable @ReadOnlyComposable get() = Tokens.Colors.globalSurfaceSecondaryAndroid

    /** Secondary text and glyphs on the page (Android); [onMedia] = the media-surface value. */
    @Composable
    @ReadOnlyComposable
    fun secondaryText(onMedia: Boolean = false): Color =
        if (onMedia) Tokens.Colors.globalTextSecondary else Tokens.Colors.globalTextSecondaryAndroid
}

/**
 * Stroke of outline capsules (C-06 outline variant, C-07): **1 pt** `color.global.textPrimary`
 * (design/components.md C-06 / C-07, tokens README quick role finder "outline 1 pt", H43). global.json has
 * no size token for it yet (reported as a spec gap by Pass 3); this is the one place the value lives.
 */
object Outline {
    val width: Dp = 1.dp // provenance-ok: outline capsule stroke 1 pt (components.md C-06/C-07, H43); no size token in global.json yet — reported gap
}
