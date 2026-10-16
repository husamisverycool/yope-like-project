// Surface: question.weekly B (answering) on camera.capture — the question on the viewfinder. Spec:
// design/surfaces/question.weekly.md; token question.weekly.layout.cameraPill. Visual reference: Retro's C-09 pill on a photo
// (references/auto/retro/store/retro-store-03.png); mechanics: BeReal shows its prompt over the capture screen
// (design/research/bereal.md §2).
package app.feature.capture.camera

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.text.style.TextOverflow
import app.designsystem.R
import app.designsystem.generated.Tokens
import app.ui.text.TextRoles

/**
 * The weekly question the camera was opened to answer (`QuestionHandoff` keys on the camera entry): its id (the post to
 * the camera's group is linked to it after posting) and its copy key (the pill's text).
 */
data class CameraQuestion(val id: String, val key: String) {
    companion object {
        fun from(id: String?, key: String?): CameraQuestion? = if (id != null && key != null) CameraQuestion(id, key) else null
    }
}

/**
 * The question on the viewfinder (`question.weekly.layout.cameraPill`): a C-09 pill on media — fill
 * `color.global.controlOnDeep`, the question in text role `pill`, `color.global.textOnMedia`, one line truncated at the
 * end, at most the viewfinder width − 2 × `size.global.screenMargin` — in the coach pill's slot (the caller places it
 * `camera.sendto.layout.messageField` bottomInset above the viewfinder bottom). Not a button; TalkBack reads
 * `question.weekly.camera.a11y` ("Answering: {question}").
 */
@Composable
internal fun QuestionPill(question: String, modifier: Modifier = Modifier) {
    val label = stringResource(R.string.question_weekly_camera_a11y, question)
    BoxWithConstraints(modifier.fillMaxWidth(), contentAlignment = Alignment.Center) {
        Box(
            Modifier
                .widthIn(max = maxWidth - Tokens.Sizes.globalScreenMargin * 2)
                .heightIn(min = Tokens.Sizes.globalPillHeight)
                .background(Tokens.Colors.globalControlOnDeep, CircleShape)
                .clearAndSetSemantics { contentDescription = label }
                .padding(horizontal = Tokens.Sizes.globalPillPaddingTrailing),
            contentAlignment = Alignment.Center,
        ) {
            Text(question, style = TextRoles.pill, color = Tokens.Colors.globalTextOnMedia, maxLines = 1, overflow = TextOverflow.Ellipsis)
        }
    }
}
