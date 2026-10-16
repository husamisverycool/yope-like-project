package app.ui.components

import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.Icon
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Shape
import androidx.compose.ui.graphics.painter.Painter
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.Dp
import app.designsystem.generated.Tokens
import app.ui.foundation.PageRoles
import coil3.compose.AsyncImage

/**
 * C-23 Avatar: a circle with the photo aspect-filled. Sizes (`size.global.*`): `avatarSmall` 22.6 (stack),
 * `avatarList` 26.5 (friend-card header), `avatarComment` 30 (comment rows, reply field), `avatarPicker` 37
 * (request / member rows), `avatarHeader` 39 (viewer header), `avatarProfile` 64, `avatarGrid` 81.
 *
 * [image] is a Coil model (URL / Uri / File) or a [Painter] (tests, local previews). With no photo (or while it
 * loads / after it fails) the fallback is [fallbackIcon] (`icon.global.person`; `icon.global.group` for groups)
 * on `color.global.control` — Retro's initials-on-colour avatar is not measurable yet (components.md C-23 Gap) —
 * the glyph in secondary text at `size.global.icon` (never larger than the circle). Decorative next to a
 * visible name (no [contentDescription]); alone, labelled with the person's name.
 */
@Composable
fun Avatar(
    image: Any?,
    size: Dp,
    modifier: Modifier = Modifier,
    fallbackIcon: ImageVector = Tokens.Icons.globalPerson,
    contentDescription: String? = null,
    shape: Shape = CircleShape,
) {
    var failed by remember(image) { mutableStateOf(false) }
    Box(
        modifier
            .size(size)
            .clip(shape)
            .background(Tokens.Colors.globalControl, shape)
            .then(
                if (contentDescription != null) Modifier.clearAndSetSemantics { this.contentDescription = contentDescription }
                else Modifier.clearAndSetSemantics { },
            ),
        contentAlignment = Alignment.Center,
    ) {
        when {
            image is Painter -> Image(image, contentDescription = null, contentScale = ContentScale.Crop, modifier = Modifier.size(size))
            image != null && !failed -> AsyncImage(
                model = image,
                contentDescription = null,
                contentScale = ContentScale.Crop,
                modifier = Modifier.size(size),
                onError = { failed = true },
            )
            else -> Icon(
                fallbackIcon,
                contentDescription = null,
                tint = PageRoles.secondaryText(),
                modifier = Modifier.size(minOf(size, Tokens.Sizes.globalIcon)),
            )
        }
    }
}

/**
 * C-23 Avatar stack (album rows): avatars of [size] (`size.global.avatarSmall`) overlapping by
 * `size.global.avatarStackOverlap`, later ones on top. Retro draws a white ring around each; its width is not
 * measured (components.md C-23 Gap), so no ring is drawn yet. Decorative unless [contentDescription] (copy,
 * e.g. the members' names) is given.
 */
@Composable
fun AvatarStack(
    images: List<Any?>,
    modifier: Modifier = Modifier,
    size: Dp = Tokens.Sizes.globalAvatarSmall,
    fallbackIcon: ImageVector = Tokens.Icons.globalPerson,
    contentDescription: String? = null,
) {
    Row(
        modifier.semantics(mergeDescendants = true) { if (contentDescription != null) this.contentDescription = contentDescription },
        horizontalArrangement = Arrangement.spacedBy(-Tokens.Sizes.globalAvatarStackOverlap),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        images.forEach { Avatar(it, size, fallbackIcon = fallbackIcon) }
    }
}
