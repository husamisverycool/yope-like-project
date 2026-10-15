package app.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
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
import androidx.compose.ui.unit.Dp
import app.designsystem.generated.Tokens
import coil3.compose.AsyncImage

/**
 * A circular avatar (person or group cover).
 *
 * - [image] is a URL / Uri / File (Coil model) or a [Painter] (tests, local previews); drawn
 *   `scaledToFill` (`ContentScale.Crop`) inside the circle.
 * - With no image (or while it loads / when it fails) the fallback is the default-avatar look:
 *   circle in `color.global.controlRaised` with [fallbackIcon] (`icon.global.person` for people,
 *   `icon.global.group` for groups) in `color.global.textSecondary` at the platform icon size
 *   (`auth.profile.layout.avatarPicker` empty look; groups.list empty-cover rule).
 * - [size]: `size.global.avatarList` 64, `.avatarPicker` 40, `.avatarSmall` 32.6, `.avatarHeader` 28,
 *   `.tabBarAvatar` 34, `auth.profile.size.avatar` 92, `groups.screen.size.profileAvatar` 92,
 *   `settings.root.size.listItemAvatar.android` 40.
 * The image is decorative unless [contentDescription] is given.
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
        modifier.size(size).clip(shape).background(Tokens.Colors.globalControlRaised, shape),
        contentAlignment = Alignment.Center,
    ) {
        when {
            image is Painter -> androidx.compose.foundation.Image(
                painter = image,
                contentDescription = contentDescription,
                contentScale = ContentScale.Crop,
                modifier = Modifier.size(size),
            )
            image != null && !failed -> AsyncImage(
                model = image,
                contentDescription = contentDescription,
                contentScale = ContentScale.Crop,
                modifier = Modifier.size(size),
                onError = { failed = true },
            )
            else -> Icon(fallbackIcon, contentDescription = contentDescription, tint = Tokens.Colors.globalTextSecondary)
        }
    }
}
