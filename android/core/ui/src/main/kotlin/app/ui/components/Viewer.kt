package app.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.semantics.CustomAccessibilityAction
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.customActions
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.LayoutDirection
import app.designsystem.generated.Tokens
import app.ui.foundation.DsImage
import app.ui.system.DsDropdownMenu
import app.ui.system.DsMenuItem
import app.ui.text.TextRoles

/*
 * C-22 Photo / story viewer chrome. The page is black in both appearances (`color.global.backgroundDeep`);
 * text there is `color.global.textOnMedia` / `color.global.textSecondary`. Retro shows no progress bars and
 * advances by tap ("Tap anywhere to advance", "Tap left to go back"). Open from a card / tile:
 * `duration.global.photoOpen` (the caller's transition); advance and close motion not captured (Gap).
 */

/** Which side of the photo a tap landed on, for [ViewerTapZones] ([previousFraction] of the width at the start edge goes back). */
object ViewerTaps {
    fun isPrevious(x: Float, width: Float, previousFraction: Float, rtl: Boolean): Boolean {
        if (width <= 0f) return false
        val fromStart = if (rtl) width - x else x
        return fromStart < width * previousFraction
    }
}

/**
 * C-22 header row: [avatar] at `size.global.avatarHeader` (39 incl. a white ring whose width is not measured —
 * Gap, no ring drawn), then [name] (text role `listTitle`, `color.global.textOnMedia`) over [week] (text role
 * `listSubtitle`, `color.global.textSecondary`), `size.global.cardNameGap` after the avatar (the friend-card
 * avatar → name gap; the viewer's own is not measured); trailing optional [position] pill ([PositionPill]),
 * the "•••" [menu] and the close circle (C-11 on media), `size.global.pillGap` apart, inside
 * `size.global.screenMargin`.
 */
@Composable
fun ViewerHeader(
    name: String,
    avatar: Any?,
    onClose: () -> Unit,
    closeContentDescription: String,
    modifier: Modifier = Modifier,
    week: String? = null,
    position: String? = null,
    positionDescription: String? = null,
    menu: List<DsMenuItem> = emptyList(),
    moreContentDescription: String? = null,
) {
    Row(
        modifier.fillMaxWidth().padding(horizontal = Tokens.Sizes.globalScreenMargin),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(Tokens.Sizes.globalPillGap),
    ) {
        Row(Modifier.weight(1f).semantics(mergeDescendants = true) {}, verticalAlignment = Alignment.CenterVertically) {
            Avatar(avatar, Tokens.Sizes.globalAvatarHeader)
            Spacer(Modifier.width(Tokens.Sizes.globalCardNameGap))
            Column {
                Text(name, style = TextRoles.listTitle, color = Tokens.Colors.globalTextOnMedia, maxLines = 1)
                if (week != null) Text(week, style = TextRoles.listSubtitle, color = Tokens.ColorsDark.globalTextSecondary, maxLines = 1)
            }
        }
        if (position != null) PositionPill(position, positionDescription)
        if (menu.isNotEmpty() && moreContentDescription != null) {
            Box {
                var open by remember { mutableStateOf(false) }
                HeaderIconButton(Tokens.Icons.globalMore, moreContentDescription, { open = true }, tint = Tokens.Colors.globalTextOnMedia)
                DsDropdownMenu(open, { open = false }, menu)
            }
        }
        CircleIconButton(Tokens.Icons.globalClose, closeContentDescription, onClose, style = CircleButtonStyle.OnMedia)
    }
}

/**
 * C-22 position pill ("3 of 4" — position only, never a count of views or likes; Retro's red variant is
 * do-not-copy): capsule `size.global.positionPillHeight` in `color.global.controlOnDeep`, label text role
 * `badge` in `color.global.textOnMedia`, padding half its height. [description]: the position in words (copy).
 */
@Composable
fun PositionPill(text: String, description: String? = null, modifier: Modifier = Modifier) {
    val height = Tokens.Sizes.globalPositionPillHeight
    Box(
        modifier
            .height(height)
            .background(Tokens.Colors.globalControlOnDeep, CircleShape)
            .padding(horizontal = height / 2)
            .then(if (description != null) Modifier.clearAndSetSemantics { contentDescription = description } else Modifier),
        contentAlignment = Alignment.Center,
    ) {
        Text(text, style = TextRoles.badge, color = Tokens.Colors.globalTextOnMedia, maxLines = 1)
    }
}

/**
 * C-22 photo with tap zones: the photo at full width in its native aspect, letterboxed on black
 * (`radius.global.photo` 0, `ContentScale.Fit`), labelled [contentDescription] (copy: who, when, place). A tap in
 * the leading [previousFraction] of the width calls [onPrevious] ("Tap left to go back"), anywhere else
 * [onNext] ("Tap anywhere to advance"). The zone width is a mechanics value the viewer spec gives (not
 * captured — Gap). TalkBack gets the two as custom actions labelled [nextLabel] / [previousLabel] (copy).
 */
@Composable
fun ViewerPhoto(
    photo: Any?,
    contentDescription: String,
    onNext: () -> Unit,
    onPrevious: () -> Unit,
    nextLabel: String,
    previousLabel: String,
    previousFraction: Float,
    modifier: Modifier = Modifier,
) {
    val next by rememberUpdatedState(onNext)
    val previous by rememberUpdatedState(onPrevious)
    val rtl = LocalLayoutDirection.current == LayoutDirection.Rtl
    Box(
        modifier
            .fillMaxWidth()
            .pointerInput(previousFraction, rtl) {
                detectTapGestures { offset ->
                    if (ViewerTaps.isPrevious(offset.x, size.width.toFloat(), previousFraction, rtl)) previous() else next()
                }
            }
            .clearAndSetSemantics {
                this.contentDescription = contentDescription
                customActions = listOf(
                    CustomAccessibilityAction(nextLabel) { next(); true },
                    CustomAccessibilityAction(previousLabel) { previous(); true },
                )
            },
        contentAlignment = Alignment.Center,
    ) {
        DsImage(photo, null, Modifier.fillMaxWidth(), contentScale = ContentScale.FillWidth, placeholder = Tokens.Colors.globalBackgroundDeep)
    }
}

/**
 * C-22 footer: [location] (text role `listTitle`, `color.global.textOnMedia`) over [date] (text role
 * `listSubtitle`, `color.global.textSecondary`) inside `size.global.screenMargin`, with a [trailing] reaction
 * slot (mechanics: Locket reactions; Retro's heart like is do-not-copy).
 */
@Composable
fun ViewerFooter(modifier: Modifier = Modifier, location: String? = null, date: String? = null, trailing: (@Composable () -> Unit)? = null) {
    Row(modifier.fillMaxWidth().padding(horizontal = Tokens.Sizes.globalScreenMargin), verticalAlignment = Alignment.CenterVertically) {
        Column(Modifier.weight(1f).semantics(mergeDescendants = true) {}) {
            if (location != null) Text(location, style = TextRoles.listTitle, color = Tokens.Colors.globalTextOnMedia)
            if (date != null) Text(date, style = TextRoles.listSubtitle, color = Tokens.ColorsDark.globalTextSecondary)
        }
        trailing?.invoke()
    }
}

/**
 * C-22 comment row (C-16 on media): avatar `size.global.avatarComment`, text `size.global.rowThumbGap` after it,
 * "name 2h" one space apart on one line (name `listTitle` in `color.global.textOnMedia`, time `caption` in
 * `color.global.textSecondary`), the comment in text role `body` in `color.global.textOnMedia`. Read as one element.
 */
@Composable
fun CommentRow(name: String, text: String, avatar: Any?, modifier: Modifier = Modifier, timestamp: String? = null) {
    Row(modifier.fillMaxWidth().padding(horizontal = Tokens.Sizes.globalScreenMargin).semantics(mergeDescendants = true) {}, verticalAlignment = Alignment.Top) {
        Avatar(avatar, Tokens.Sizes.globalAvatarComment)
        Spacer(Modifier.width(Tokens.Sizes.globalRowThumbGap))
        Column(Modifier.weight(1f)) {
            Text(
                buildAnnotatedString {
                    withStyle(TextRoles.listTitle.toSpanStyle().copy(color = Tokens.Colors.globalTextOnMedia)) { append(name) }
                    if (timestamp != null) {
                        append(' ')
                        withStyle(TextRoles.caption.toSpanStyle().copy(color = Tokens.ColorsDark.globalTextSecondary)) { append(timestamp) }
                    }
                },
                style = TextRoles.listTitle,
            )
            Text(text, style = TextRoles.body, color = Tokens.Colors.globalTextOnMedia)
        }
    }
}

/**
 * C-22 page: black (`color.global.backgroundDeep`) in both appearances; [header], the photo, [footer], a
 * hairline (the separator's dark value), then [comments] and the reply bar the caller places.
 */
@Composable
fun ViewerPage(
    modifier: Modifier = Modifier,
    header: @Composable () -> Unit,
    photo: @Composable () -> Unit,
    footer: (@Composable () -> Unit)? = null,
    comments: (@Composable ColumnScope.() -> Unit)? = null,
) {
    Column(modifier.fillMaxSize().background(Tokens.Colors.globalBackgroundDeep)) {
        header()
        Box(Modifier.weight(1f).fillMaxWidth(), contentAlignment = Alignment.Center) { photo() }
        footer?.invoke()
        if (comments != null) {
            Hairline(Modifier.padding(horizontal = Tokens.Sizes.globalScreenMargin), onMedia = true)
            comments()
        }
    }
}
