package app.feature.account.common

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.WindowInsetsSides
import androidx.compose.foundation.layout.asPaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.only
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.paddingFrom
import androidx.compose.foundation.layout.safeDrawing
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.layout.FirstBaseline
import androidx.compose.ui.layout.LastBaseline
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.max
import app.designsystem.R
import app.designsystem.dsShadow
import app.designsystem.generated.Tokens
import app.ui.components.HeaderAction
import app.ui.components.HeaderIconButton
import app.ui.foundation.DsImage
import app.ui.foundation.GlyphInk
import app.ui.foundation.PageRoles
import app.ui.foundation.tapClickable
import app.ui.system.SheetHeader
import app.ui.text.TextRoles

/*
 * The account group's screen frames, composed only from the Pass 3 components (design/components.md) and global tokens:
 * the onboarding form every `auth.*` step and onboarding page uses (MERGE RA-2), the page sheet of `groups.create`,
 * `groups.invite`, `groups.settings` and `settings.*` (C-29, `settings.root.layout.list`), Retro's one-line list error,
 * and the album cover (C-24 / `groups.screen.size.cover*`, `groups.screen.shadow.cover`).
 */

/** Hit area of a header glyph (C-01 / C-02): `size.global.headerButton`, at least `size.global.minTouchTarget.android`. */
internal val HeaderHit: Dp get() = max(Tokens.Sizes.globalHeaderButton, Tokens.Sizes.globalMinTouchTargetAndroid)

/**
 * The C-02 back glyph on its own (a header row without a title): `icon.global.back` in [tint]
 * (`color.global.textPrimary`), its ink `size.global.backInset` from the leading edge, hit area [HeaderHit],
 * TalkBack label from copy. Pressed: platform default + `haptic.global.tap`.
 */
@Composable
fun BackGlyphButton(contentDescription: String, onClick: () -> Unit, modifier: Modifier = Modifier, tint: Color = Tokens.Colors.globalTextPrimary) {
    val back = Tokens.Icons.globalBack
    val box = Tokens.Sizes.globalIcon
    val start = (Tokens.Sizes.globalBackInset - GlyphInk.leading(back, box) - (HeaderHit - box) / 2).coerceAtLeast(0.dp)
    Box(modifier.padding(start = start)) { HeaderIconButton(back, contentDescription, onClick, tint = tint) }
}

/**
 * The onboarding form composition (auth.phone B, auth.code, auth.agegate, auth.profile, onboarding pages — MERGE RA-2):
 * page `color.global.background.android`; inside the safe area (and above the keyboard):
 * - [back]: the C-02 back glyph in the header row at the top of the safe area (no title in that row);
 * - the title: `font.global.display` text role `displayMedium`, `color.global.textPrimary`, leading
 *   `size.global.screenMargin`, first baseline `size.global.titleTop` below the safe-area top (the C-01 metric), header trait;
 * - [explanation] directly under it (text role `body`, secondary text) — the way C-19 sets the real name under the serif name;
 * - [content] (C-12 field …) `size.global.titleToContent` below the last baseline of the title block, inside
 *   `size.global.screenMargin`; the title block and content scroll when they do not fit (large text, keyboard);
 * - [bottom] (C-05 capsule, C-08 link) pinned `size.global.buttonMarginH` above the keyboard or the bottom safe area,
 *   sides `size.global.buttonMarginH`.
 * [replacement] (offline, not configured, under age): the C-27 block centred in the space under the title block, in place
 * of [content] and [bottom]. [scrollable] false (a page without a keyboard, e.g. the profile-photo step): [content] fills
 * the space between the title block and [bottom] instead of scrolling, so it can centre itself there.
 */
@Composable
fun OnboardingForm(
    title: String,
    explanation: String?,
    modifier: Modifier = Modifier,
    back: HeaderAction? = null,
    replacement: (@Composable () -> Unit)? = null,
    scrollable: Boolean = true,
    bottom: (@Composable ColumnScope.() -> Unit)? = null,
    content: @Composable ColumnScope.() -> Unit = {},
) {
    Box(modifier.fillMaxSize().background(PageRoles.page)) {
        Column(Modifier.fillMaxSize().windowInsetsPadding(WindowInsets.safeDrawing)) {
            if (replacement != null) {
                FormTitleBlock(title, explanation)
                Box(Modifier.weight(1f).fillMaxWidth(), contentAlignment = Alignment.Center) { replacement() }
            } else if (scrollable) {
                Column(Modifier.weight(1f).fillMaxWidth().verticalScroll(rememberScrollState())) {
                    FormTitleBlock(title, explanation)
                    Column(Modifier.fillMaxWidth().padding(horizontal = Tokens.Sizes.globalScreenMargin), content = content)
                }
            } else {
                FormTitleBlock(title, explanation)
                Column(Modifier.weight(1f).fillMaxWidth().padding(horizontal = Tokens.Sizes.globalScreenMargin), content = content)
            }
            if (replacement == null) {
                if (bottom != null) {
                    Column(
                        Modifier.fillMaxWidth().padding(start = Tokens.Sizes.globalButtonMarginH, end = Tokens.Sizes.globalButtonMarginH, bottom = Tokens.Sizes.globalButtonMarginH),
                        horizontalAlignment = Alignment.CenterHorizontally,
                        content = bottom,
                    )
                }
            }
        }
        if (back != null) {
            BackGlyphButton(back.contentDescription, back.onClick, Modifier.windowInsetsPadding(WindowInsets.safeDrawing.only(WindowInsetsSides.Top + WindowInsetsSides.Horizontal)))
        }
    }
}

/** Title (display serif, first baseline at `size.global.titleTop`) and explanation; the block ends `size.global.titleToContent` below its last baseline. */
@Composable
private fun FormTitleBlock(title: String, explanation: String?) {
    val toContent = Tokens.Sizes.globalTitleToContent
    Column(Modifier.fillMaxWidth().padding(horizontal = Tokens.Sizes.globalScreenMargin)) {
        Text(
            title,
            style = TextRoles.displayMedium,
            color = Tokens.Colors.globalTextPrimary,
            modifier = Modifier
                .fillMaxWidth()
                .paddingFrom(FirstBaseline, before = Tokens.Sizes.globalTitleTop)
                .then(if (explanation == null) Modifier.paddingFrom(LastBaseline, after = toContent) else Modifier)
                .semantics { heading() },
        )
        if (explanation != null) {
            Text(
                explanation,
                style = TextRoles.body,
                color = PageRoles.secondaryText(),
                modifier = Modifier.fillMaxWidth().paddingFrom(LastBaseline, after = toContent),
            )
        }
    }
}

/**
 * A page sheet (C-29; `settings.root.layout.list` sheet) as a full-screen destination — the spec's Android form
 * ("ModalBottomSheet (expanded) or a full-screen destination with an inner nav host"): page
 * `color.global.background.android` under the status bar, the C-29 sheet header (centred title in text role
 * `sheetTitle`, trailing [close] C-11 circle on the page; pushed pages inside the sheet: a leading [back] glyph and
 * the same centred title), then [content] (which handles its own scrolling and the bottom inset).
 */
@Composable
fun SheetPage(
    title: String,
    modifier: Modifier = Modifier,
    close: HeaderAction? = null,
    back: HeaderAction? = null,
    content: @Composable ColumnScope.() -> Unit,
) {
    Column(
        modifier
            .fillMaxSize()
            .background(PageRoles.page)
            .windowInsetsPadding(WindowInsets.safeDrawing.only(WindowInsetsSides.Top + WindowInsetsSides.Horizontal)),
    ) {
        Box(Modifier.fillMaxWidth(), contentAlignment = Alignment.CenterStart) {
            SheetHeader(title, close = close)
            if (back != null) BackGlyphButton(back.contentDescription, back.onClick)
        }
        content()
    }
}

/** The bottom inset of a sheet's scrolling content: the navigation bar plus `size.global.sectionGap` of breathing room after the last group. */
@Composable
fun sheetBottomPadding(): Dp = WindowInsets.navigationBars.asPaddingValues().calculateBottomPadding() + Tokens.Sizes.globalSectionGap

/**
 * Retro's list error ("Error loading friends. Tap here to try again."): one line of text role `body` in secondary text,
 * centred inside `size.global.screenMargin`; tapping it retries. TalkBack: a button with the line as its label.
 */
@Composable
fun TapLine(text: String, onClick: () -> Unit, modifier: Modifier = Modifier) {
    Text(
        text,
        style = TextRoles.body,
        color = PageRoles.secondaryText(),
        textAlign = TextAlign.Center,
        modifier = modifier.fillMaxWidth().tapClickable(onClick = onClick).padding(horizontal = Tokens.Sizes.globalScreenMargin),
    )
}

/**
 * The album cover (C-24; groups.screen, groups.create, groups.invite): [width] × [height] (`groups.screen.size.cover*` /
 * `groups.invite.size.cover*`), aspect-fill, corners `radius.global.thumbnail`, drop shadow `groups.screen.shadow.cover`
 * (TC-J1 fit; invisible on the dark page — groups.screen Gaps); no photo → `color.global.control` fill with [glyph]
 * (`icon.global.group`, null = none) centred in secondary text. Labelled [contentDescription] when given, else decorative.
 */
@Composable
fun BookCover(
    model: Any?,
    width: Dp,
    height: Dp,
    modifier: Modifier = Modifier,
    contentDescription: String? = null,
    glyph: ImageVector? = Tokens.Icons.globalGroup,
) {
    val shape = RoundedCornerShape(Tokens.Radii.globalThumbnail)
    Box(
        modifier
            .size(width, height)
            .dsShadow(Tokens.Shadows.groupsScreenShadowCover, shape)
            .clip(shape)
            .background(Tokens.Colors.globalControl, shape)
            .then(if (contentDescription != null) Modifier.clearAndSetSemantics { this.contentDescription = contentDescription } else Modifier.clearAndSetSemantics { }),
        contentAlignment = Alignment.Center,
    ) {
        if (model != null) {
            DsImage(model, null, Modifier.fillMaxSize())
        } else if (glyph != null) {
            Icon(glyph, contentDescription = null, tint = PageRoles.secondaryText(), modifier = Modifier.size(Tokens.Sizes.globalIcon))
        }
    }
}

/** Centres a block in the space it is given (C-27 placement) — a [BoxScope] host for screens that stack it under content. */
@Composable
fun CentredBlock(modifier: Modifier = Modifier, content: @Composable BoxScope.() -> Unit) {
    Box(modifier.fillMaxSize(), contentAlignment = Alignment.Center, content = content)
}

/** The one button of the message-only alert (`auth.phone.layout.inlineError`): `auth.phone.error.dismiss` ("OK"). */
@Composable
fun errorDismissLabel(): String = stringResource(R.string.auth_phone_error_dismiss)
