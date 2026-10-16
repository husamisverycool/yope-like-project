// Surface: question.weekly A, C, D — the weekly question card in groups.screen's pager. Spec: design/surfaces/question.weekly.md;
// token question.weekly.layout.card. Visual reference: Retro's feed cards in the group screen's pager (C-18 geometry,
// layout.global.photoScrim, display text role, C-09 light pill; references/auto/retro/store/retro-store-01.png,
// references/auto/retro/store/editorial/retro-appstore-story-1840659619-albums.png) and Retro's prompt cards (one CTA,
// references/auto/retro/apk/nux_card_what_to_share_0.webp). Mechanics: Apple Journal's reflection prompt (eyebrow → prompt →
// action; "touch and hold the suggestion, then tap Remove"). Decisions: MERGE_DECISIONS WQ-1 … WQ-7.
package app.feature.account.question

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.Immutable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.produceState
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.CustomAccessibilityAction
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.customActions
import androidx.compose.ui.semantics.onClick
import androidx.compose.ui.semantics.role
import androidx.compose.ui.text.style.TextOverflow
import app.data.model.Media
import app.data.model.Post
import app.designsystem.R
import app.designsystem.generated.Tokens
import app.feature.account.plans.PlansBackend
import app.feature.account.plans.rememberPlansBackend
import app.ui.components.Capsule
import app.ui.components.CapsuleStyle
import app.ui.components.MediaPill
import app.ui.copy.WeeklyQuestions
import app.ui.foundation.DsImage
import app.ui.foundation.PhotoScrimOverlay
import app.ui.foundation.tapLongPressable
import app.ui.system.DsDropdownMenu
import app.ui.system.DsMenuItem
import app.ui.text.TextRoles
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.launch
import java.time.LocalDate
import java.util.concurrent.ConcurrentHashMap

/** This group week's question as the card shows it: its text, and the answers (oldest first) with the newest's photo. */
@Immutable
data class QuestionCardData(
    val questionId: String,
    val key: String,
    val text: String,
    val weekStart: LocalDate,
    val answers: List<Post>,
    /** The newest answer's display rendition (signed URL); null with no answers. */
    val newestPhotoUrl: String?,
)

/**
 * The weekly question card for `groups.screen`'s pager (placed by the screen as its first feed card): shown while
 * `current_group_question` returns a question you have not removed and this app has copy for its key; while loading,
 * on error, off for the group or removed, it composes nothing (`question.weekly` → States). The last card of each group
 * is kept for the process so it does not pop in on every visit. [refreshKey] changes refetch it (new posts).
 */
@Composable
fun QuestionCardEntry(
    groupId: String,
    refreshKey: Any?,
    onAnswer: (questionId: String, key: String) -> Unit,
    onOpenAnswers: (questionId: String, oldestPostId: String) -> Unit,
    modifier: Modifier = Modifier,
) {
    val backend = rememberPlansBackend()
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    var hidden by remember(groupId) { mutableStateOf(false) }
    val data = produceState(QuestionCardCache.get(groupId), groupId, refreshKey, backend) {
        value = loadQuestion(backend, groupId) { key -> WeeklyQuestions.text(context, key) }.also { QuestionCardCache.put(groupId, it) }
    }.value
    if (data == null || hidden) return
    QuestionCard(
        question = data.text,
        photo = data.newestPhotoUrl,
        hasAnswers = data.answers.isNotEmpty(),
        onAnswer = { onAnswer(data.questionId, data.key) },
        onOpenAnswers = { data.answers.firstOrNull()?.let { onOpenAnswers(data.questionId, it.id) } },
        onRemove = {
            // "Remove" hides the card for this member until the next question; no confirmation (Apple Journal).
            hidden = true
            QuestionCardCache.put(groupId, null)
            scope.launch { runCatching { backend.hideQuestion(data.questionId) } }
        },
        modifier = modifier,
    )
}

/** The card's data, or null (off, no catalogue, removed by you, a key without copy, or the read failed). */
internal suspend fun loadQuestion(backend: PlansBackend, groupId: String, text: (String) -> String?): QuestionCardData? = try {
    backend.currentQuestion(groupId)?.takeIf { !it.hiddenByMe }?.let { question ->
        val copy = text(question.questionKey) ?: return@let null
        val answers = backend.questionAnswers(question.id)
        val newest = answers.lastOrNull()
        val path = newest?.let { post -> backend.media(listOf(post.mediaId)).firstOrNull()?.imagePath(Media.Rendition.Display) }
        val url = path?.let { backend.signedUrls(listOf(it))[it] }
        QuestionCardData(question.id, question.questionKey, copy, question.weekStart, answers, url)
    }
} catch (e: CancellationException) {
    throw e
} catch (_: Exception) {
    null
}

/** The last loaded card per group (process memory only). */
internal object QuestionCardCache {
    private val cards = ConcurrentHashMap<String, QuestionCardData>()

    fun get(groupId: String): QuestionCardData? = cards[groupId]

    fun put(groupId: String, card: QuestionCardData?) {
        if (card == null) cards.remove(groupId) else cards[groupId] = card
    }
}

/**
 * The card (`question.weekly.layout.card`), C-18 geometry: the label line `question.weekly.card.label` (`listTitle`,
 * `color.global.textPrimary`, no glyph) in the friend card's header slot (`size.global.avatarList` high),
 * `size.global.cardHeaderGap` above a `size.global.friendCardWidth` × `.friendCardHeight` card (`radius.global.card`):
 * - no answers: fill `color.global.control`; at the bottom inside `size.global.screenMargin` the question (`displaySmall`,
 *   `font.global.displayNarrow`, `color.global.textPrimary`, ≤ 4 lines) and `size.global.pillGap` below it the C-06 primary
 *   capsule "Add a photo" (hugging its label);
 * - with answers: the newest answer's photo, aspect-fill, under `layout.global.photoScrim`; the question in
 *   `color.global.textOnMedia`; the C-09 light pill "Add a photo". No names, no number, no "you answered" mark.
 * The button opens the camera with the question; with answers a tap on the card opens the answers in the viewer. Long press:
 * the native menu "Remove" (`haptic.global.longPressStart`). One TalkBack element `question.weekly.card.a11y` (button:
 * "Add a photo"), custom actions "See answers" (with answers) and "Remove".
 */
@Composable
fun QuestionCard(
    question: String,
    photo: Any?,
    hasAnswers: Boolean,
    onAnswer: () -> Unit,
    onOpenAnswers: () -> Unit,
    onRemove: () -> Unit,
    modifier: Modifier = Modifier,
) {
    var menuOpen by remember { mutableStateOf(false) }
    val label = stringResource(R.string.question_weekly_card_a11y, question)
    val button = stringResource(R.string.question_weekly_card_button)
    val seeAnswers = stringResource(R.string.question_weekly_card_a11y_answers)
    val remove = stringResource(R.string.question_weekly_menu_remove)
    Column(
        modifier
            .padding(top = Tokens.Sizes.globalSectionGap)
            .width(Tokens.Sizes.globalFriendCardWidth)
            .clearAndSetSemantics {
                contentDescription = label
                role = Role.Button
                onClick(button) { onAnswer(); true }
                customActions = listOfNotNull(
                    if (hasAnswers) CustomAccessibilityAction(seeAnswers) { onOpenAnswers(); true } else null,
                    CustomAccessibilityAction(remove) { onRemove(); true },
                )
            },
    ) {
        Box(Modifier.height(Tokens.Sizes.globalAvatarList), contentAlignment = Alignment.CenterStart) {
            Text(stringResource(R.string.question_weekly_card_label), style = TextRoles.listTitle, color = Tokens.Colors.globalTextPrimary, maxLines = 1)
        }
        Spacer(Modifier.height(Tokens.Sizes.globalCardHeaderGap))
        Box(
            Modifier
                .size(Tokens.Sizes.globalFriendCardWidth, Tokens.Sizes.globalFriendCardHeight)
                .clip(RoundedCornerShape(Tokens.Radii.globalCard))
                .background(Tokens.Colors.globalControl)
                .tapLongPressable(onClick = if (hasAnswers) onOpenAnswers else onAnswer, onLongClick = { menuOpen = true }),
        ) {
            if (hasAnswers) {
                DsImage(photo, null, Modifier.fillMaxSize())
                PhotoScrimOverlay()
            }
            Column(Modifier.align(Alignment.BottomStart).padding(Tokens.Sizes.globalScreenMargin)) {
                Text(
                    question,
                    style = TextRoles.displaySmall,
                    color = if (hasAnswers) Tokens.Colors.globalTextOnMedia else Tokens.Colors.globalTextPrimary,
                    maxLines = QUESTION_MAX_LINES,
                    overflow = TextOverflow.Ellipsis,
                )
                Spacer(Modifier.height(Tokens.Sizes.globalPillGap))
                if (hasAnswers) MediaPill(button, onAnswer) else Capsule(button, onAnswer, style = CapsuleStyle.Primary)
            }
            DsDropdownMenu(expanded = menuOpen, onDismissRequest = { menuOpen = false }, items = listOf(DsMenuItem(remove, onRemove)))
        }
    }
}

/** `question.weekly.layout.card` maxLines: the question runs up to 4 lines, then truncates (the TalkBack label carries it whole). */
private val QUESTION_MAX_LINES = Tokens.Layouts.QuestionWeeklyLayoutCard.maxLines.toInt()
