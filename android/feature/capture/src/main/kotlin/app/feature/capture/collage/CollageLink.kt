// Surface: collage.view — opened by the collage's id (a widget showing the group's collage of the day, deep link
// `app://collage?group=<id>&collage=<id>`). Resolves the collage's invitation, then shows the collage destination
// (design/surfaces/collage.view.md; Retro recap preview, references/auto/retro/store/retro-store-04.png). While it
// resolves: the media page with `collage.view.loading`; a failure: the collage's error / offline line (tap to retry);
// a collage that is gone: the collage's empty state.
package app.feature.capture.collage

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.style.TextAlign
import app.data.error.DataError
import app.data.error.DataException
import app.designsystem.R
import app.designsystem.generated.Tokens
import app.feature.capture.data.CaptureDataProvider
import app.feature.capture.ui.MediaEmptyState
import app.feature.capture.ui.MediaProgressBlock
import app.ui.components.EmptyStateAction
import app.ui.foundation.tapClickable
import app.ui.text.TextRoles

/** What resolving a collage id gave. */
internal sealed interface CollageLink {
    data object Loading : CollageLink
    data class Ready(val invitationId: String) : CollageLink
    data object Gone : CollageLink
    data class Failed(val offline: Boolean) : CollageLink
}

/** The collage with id [collageId]: resolves its invitation, then [CollageRoute]. */
@Composable
fun CollageLinkRoute(
    groupId: String,
    collageId: String,
    onBack: () -> Unit,
    onOpenCamera: () -> Unit,
    onReport: (collageId: String) -> Unit = {},
) {
    val context = LocalContext.current
    var attempt by remember { mutableIntStateOf(0) }
    var link: CollageLink by remember { mutableStateOf(CollageLink.Loading) }
    LaunchedEffect(collageId, attempt) {
        link = CollageLink.Loading
        link = try {
            CaptureDataProvider.get(context).collageById(collageId)?.invitationId?.let { CollageLink.Ready(it) } ?: CollageLink.Gone
        } catch (e: DataException) {
            CollageLink.Failed(offline = e.error == DataError.Network)
        }
    }
    when (val current = link) {
        is CollageLink.Ready -> CollageRoute(groupId, current.invitationId, onBack, onOpenCamera, onReport)
        else -> Box(Modifier.fillMaxSize().background(Tokens.Colors.globalBackgroundDeep), contentAlignment = Alignment.Center) {
            when (current) {
                CollageLink.Loading -> MediaProgressBlock(stringResource(R.string.collage_view_loading))
                CollageLink.Gone -> MediaEmptyState(
                    title = stringResource(R.string.collage_view_empty_title),
                    detail = stringResource(R.string.collage_view_empty_detail),
                    action = EmptyStateAction(stringResource(R.string.collage_view_empty_button), onOpenCamera, Tokens.Icons.globalCamera),
                    icon = Tokens.Icons.globalCamera,
                )
                is CollageLink.Failed -> Text(
                    stringResource(if (current.offline) R.string.collage_view_offline_title else R.string.collage_view_error_title),
                    style = TextRoles.body,
                    color = Tokens.Colors.globalTextOnMedia,
                    textAlign = TextAlign.Center,
                    modifier = Modifier
                        .tapClickable { attempt += 1 }
                        .padding(Tokens.Sizes.globalScreenMargin)
                        .testTag("collage.link.retry"),
                )
                is CollageLink.Ready -> Unit
            }
        }
    }
}
