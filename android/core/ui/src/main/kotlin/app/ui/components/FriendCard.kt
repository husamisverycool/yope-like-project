package app.ui.components

import androidx.compose.foundation.gestures.snapping.SnapPosition
import androidx.compose.foundation.gestures.snapping.rememberSnapFlingBehavior
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyListState
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.Immutable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.Role
import app.designsystem.generated.Tokens
import app.ui.foundation.DsImage
import app.ui.foundation.tapClickable
import app.ui.text.TextRoles

/** A friend's card for [FriendCardPager]. [contentDescription] (copy): "{name}'s week, new photos". [badge]: the "new" label (copy) or null. */
@Immutable
data class FriendCardSpec(
    val key: Any,
    val name: String,
    val avatar: Any?,
    val photo: Any?,
    val contentDescription: String,
    val onClick: () -> Unit,
    val badge: String? = null,
)

/**
 * C-18 Friend card: avatar (`size.global.avatarList`) + name (text role `listTitle`, `color.global.textPrimary`,
 * ink `size.global.cardNameGap` after the avatar) above a `size.global.friendCardWidth` × `.friendCardHeight`
 * (240 × 361, 2:3) aspect-fill photo card, `radius.global.card` corners, no border, no shadow, starting
 * `size.global.cardHeaderGap` below the avatar. [badge]: the C-24 "new" capsule `size.global.badgeInset` from the
 * card's top and right — never a count; Retro's "Seen" pill is do-not-copy. One button labelled
 * [contentDescription]; pressed: platform default + `haptic.global.tap` (the viewer opens with
 * `duration.global.photoOpen` — the caller's navigation).
 */
@Composable
fun FriendCard(
    name: String,
    avatar: Any?,
    photo: Any?,
    contentDescription: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    badge: String? = null,
) {
    Column(
        modifier
            .width(Tokens.Sizes.globalFriendCardWidth)
            .tapClickable(onClick = onClick)
            .clearAndSetSemantics {
                this.contentDescription = contentDescription
                role = Role.Button
            },
    ) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(Tokens.Sizes.globalCardNameGap)) {
            Avatar(avatar, Tokens.Sizes.globalAvatarList)
            Text(name, style = TextRoles.listTitle, color = Tokens.Colors.globalTextPrimary, maxLines = 1)
        }
        Spacer(Modifier.height(Tokens.Sizes.globalCardHeaderGap))
        Box(Modifier.size(Tokens.Sizes.globalFriendCardWidth, Tokens.Sizes.globalFriendCardHeight).clip(RoundedCornerShape(Tokens.Radii.globalCard))) {
            DsImage(photo, null, Modifier.fillMaxSize())
            if (badge != null) NewBadge(badge, Modifier.align(Alignment.TopEnd).padding(top = Tokens.Sizes.globalBadgeInset, end = Tokens.Sizes.globalBadgeInset))
        }
    }
}

/**
 * C-18 pager: friend cards in a horizontal row, the first at `size.global.screenMargin`, `size.global.cardGap`
 * apart, the next card peeking; flings settle on a card's leading edge (a pager).
 */
@Composable
fun FriendCardPager(cards: List<FriendCardSpec>, modifier: Modifier = Modifier, state: LazyListState = rememberLazyListState()) {
    LazyRow(
        modifier = modifier,
        state = state,
        contentPadding = PaddingValues(start = Tokens.Sizes.globalScreenMargin),
        horizontalArrangement = Arrangement.spacedBy(Tokens.Sizes.globalCardGap),
        flingBehavior = rememberSnapFlingBehavior(state, SnapPosition.Start),
    ) {
        items(cards, key = { it.key }) { card ->
            FriendCard(card.name, card.avatar, card.photo, card.contentDescription, card.onClick, badge = card.badge)
        }
    }
}
