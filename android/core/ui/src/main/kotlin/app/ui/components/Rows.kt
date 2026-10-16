package app.ui.components

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.Dp
import app.designsystem.generated.Tokens
import app.ui.foundation.DsImage
import app.ui.foundation.PageRoles
import app.ui.foundation.tapClickable
import app.ui.text.TextRoles

/**
 * A row subtitle with the actor's name in semibold ("**daniel** shared photos", C-15): the first occurrence of
 * [actor] in [text] (both copy) gets `fontWeight.global.listTitle`. Counts in such subtitles are a Retro
 * pattern our tenets drop (copy decides the words).
 */
fun subtitleWithActor(text: String, actor: String): AnnotatedString = buildAnnotatedString {
    val at = if (actor.isEmpty()) -1 else text.indexOf(actor)
    if (at < 0) {
        append(text)
    } else {
        append(text.substring(0, at))
        withStyle(SpanStyle(fontWeight = Tokens.FontWeights.fontWeightGlobalListTitle)) { append(actor) }
        append(text.substring(at + actor.length))
    }
}

/**
 * C-15 List row with thumbnail (albums / groups).
 *
 * Thumbnail `size.global.rowThumbWidth` × `.rowThumbHeight` (72 × 97, 3:4), `radius.global.thumbnail`,
 * aspect-fill, at `size.global.screenMargin`; the text block starts `size.global.rowThumbGap` after it: title
 * text role `listTitle` in `color.global.textPrimary`, [subtitle] text role `listSubtitle` in secondary text
 * (build it with [subtitleWithActor]), then the C-23 [avatars] stack (its gap under the subtitle is not
 * measured — Gap: directly below). Trailing [add]: a C-11 circle (`size.global.circleButton`,
 * `color.global.control`, `icon.global.add`) at the right margin. Rows sit `size.global.listGap` apart
 * ([ThumbnailRowSpacing]). The whole row is one button ([contentDescription] from copy, else title and subtitle
 * are read together); the "+" is a separate labelled button.
 */
@Composable
fun ThumbnailRow(
    title: String,
    subtitle: AnnotatedString?,
    thumbnail: Any?,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    avatars: List<Any?> = emptyList(),
    add: HeaderAction? = null,
    contentDescription: String? = null,
) {
    Row(
        modifier
            .fillMaxWidth()
            .tapClickable(onClick = onClick)
            .semantics(mergeDescendants = true) { if (contentDescription != null) this.contentDescription = contentDescription }
            .padding(horizontal = Tokens.Sizes.globalScreenMargin),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        val shape = RoundedCornerShape(Tokens.Radii.globalThumbnail)
        DsImage(thumbnail, null, Modifier.size(Tokens.Sizes.globalRowThumbWidth, Tokens.Sizes.globalRowThumbHeight).clip(shape))
        Spacer(Modifier.width(Tokens.Sizes.globalRowThumbGap))
        Column(Modifier.weight(1f)) {
            Text(title, style = TextRoles.listTitle, color = Tokens.Colors.globalTextPrimary)
            if (subtitle != null) Text(subtitle, style = TextRoles.listSubtitle, color = PageRoles.secondaryText())
            if (avatars.isNotEmpty()) AvatarStack(avatars)
        }
        if (add != null) CircleIconButton(add.icon, add.contentDescription, add.onClick, style = CircleButtonStyle.OnPage)
    }
}

/** Vertical spacing between [ThumbnailRow]s (`size.global.listGap`, row pitch 119.5). */
val ThumbnailRowSpacing: Arrangement.Vertical get() = Arrangement.spacedBy(Tokens.Sizes.globalListGap)

/**
 * C-16 People row (friend request / member / comment).
 *
 * [avatar] at [avatarSize] (`size.global.avatarPicker` in request and member rows; `size.global.avatarComment`
 * in comment rows), text `size.global.rowThumbGap` after it (TC-1B avatar → Accept 17); [name] text role
 * `listTitle`, an optional [timestamp] one space after it on the same line (text role `caption`, secondary
 * text: "elton 2h"); [line] text role `listSubtitle` in secondary text. [actions] — the C-06 pair ("Accept /
 * Decide Later", equal widths `Modifier.weight(1f)`, `size.global.pillGap` apart) — go under the text, a
 * `size.global.pillGap` below it (their vertical gap is not measured — Gap). [unread]: the C-24 dot at the
 * trailing end. [onMedia]: colours of the black viewer (`color.global.textOnMedia`, `color.global.textSecondary`).
 * With [onClick] the row is one button.
 */
@Composable
fun PeopleRow(
    name: String,
    avatar: Any?,
    modifier: Modifier = Modifier,
    line: String? = null,
    timestamp: String? = null,
    avatarSize: Dp = Tokens.Sizes.globalAvatarPicker,
    unread: Boolean = false,
    onMedia: Boolean = false,
    onClick: (() -> Unit)? = null,
    actions: (@Composable RowScope.() -> Unit)? = null,
) {
    val primary = if (onMedia) Tokens.Colors.globalTextOnMedia else Tokens.Colors.globalTextPrimary
    val secondary = PageRoles.secondaryText(onMedia)
    Row(
        modifier
            .fillMaxWidth()
            .then(if (onClick != null) Modifier.tapClickable(onClick = onClick) else Modifier)
            .semantics(mergeDescendants = actions == null) {}
            .padding(horizontal = Tokens.Sizes.globalScreenMargin),
        verticalAlignment = if (actions == null) Alignment.CenterVertically else Alignment.Top,
    ) {
        Avatar(avatar, avatarSize)
        Spacer(Modifier.width(Tokens.Sizes.globalRowThumbGap))
        Column(Modifier.weight(1f)) {
            Text(
                buildAnnotatedString {
                    withStyle(TextRoles.listTitle.toSpanStyle().copy(color = primary)) { append(name) }
                    if (timestamp != null) {
                        append(' ')
                        withStyle(TextRoles.caption.toSpanStyle().copy(color = secondary)) { append(timestamp) }
                    }
                },
                style = TextRoles.listTitle,
            )
            if (line != null) Text(line, style = TextRoles.listSubtitle, color = secondary)
            if (actions != null) {
                Row(Modifier.fillMaxWidth().padding(top = Tokens.Sizes.globalPillGap), horizontalArrangement = CapsuleRowSpacing, content = actions)
            }
        }
        if (unread) UnreadDot(Modifier.align(Alignment.CenterVertically).padding(start = Tokens.Sizes.globalPillGap))
    }
}
