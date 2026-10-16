// Surface: tagging — design/surfaces/tagging.md ("I'm in this", self-tag)
// References: references/auto/retro/press/tc-2023-07-retro-2b.jpg phone 2 (viewer footer: where the run sits),
// references/auto/retro/press/tc-2023-07-retro-1b.webp phone 2 (people rows), Retro strings media_viewer_footer_tagged_users_*,
// media_viewer_tagged_user_*, media_viewer_view_tagged_users_empty (references/auto/retro/apk/retro-android-2026.10.1150-strings.txt).
package app.feature.memory.tagging

import android.icu.text.ListFormatter
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.Immutable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.Stable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.disabled
import androidx.compose.ui.semantics.onClick
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.text.withStyle
import app.designsystem.R
import app.designsystem.generated.Tokens
import app.feature.memory.common.Failure
import app.feature.memory.common.FadeInItem
import app.feature.memory.common.MemoryBackend
import app.feature.memory.common.SystemAppearance
import app.feature.memory.common.attempt
import app.feature.memory.common.expandedTap
import app.feature.memory.common.failureOf
import app.feature.memory.common.memoryModel
import app.feature.memory.common.rememberMemoryBackend
import app.ui.components.Capsule
import app.ui.components.CapsuleStyle
import app.ui.components.EmptyState
import app.ui.components.HeaderAction
import app.ui.components.PeopleRow
import app.ui.components.PlatformToast
import app.ui.components.PrimaryButton
import app.ui.foundation.DsMotion
import app.ui.haptics.rememberHaptics
import app.ui.system.DsBottomSheet
import app.ui.system.SheetHeader
import app.ui.text.TextRoles
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.launch
import java.util.Locale

/** A member tagged in a photo: first name and avatar (a signed URL or any image model). */
@Immutable
data class TaggedPerson(val userId: String, val firstName: String, val avatar: Any?)

/**
 * State and behaviour of the tag run for one photo (design/surfaces/tagging.md): the photo's tagged members in tag
 * order, and your own tag — optimistic: "I'm in this" adds you at once and `tag_self` runs; "Remove tag" takes you
 * out at once and `untag_self` runs; a failure reverts with the spec's message. At most one call in flight per photo
 * ("pending": taps are ignored). Only ever tags yourself; nobody is notified.
 */
@Stable
class TagRunController(
    val postId: String,
    private val backend: MemoryBackend,
    private val scope: CoroutineScope,
    initialPeople: List<TaggedPerson>?,
    me: TaggedPerson?,
    private val haptic: (Int) -> Unit = {},
    private val onPhotoGone: () -> Unit = {},
) {
    /** Tagged members in tag order; null until known (the run draws nothing until then). */
    var people by mutableStateOf(initialPeople)
        private set

    /** A tag / untag call is running. */
    var pending by mutableStateOf(false)
        private set

    /** The last failure's message, until shown. */
    var message by mutableStateOf<Message?>(null)
        private set

    /** The "In this photo" sheet is open. */
    var sheetOpen by mutableStateOf(false)

    private var self by mutableStateOf(me)

    enum class Message { TagError, RemoveError, NotFound, Offline }

    /** Your user id (your row carries "Remove tag"). */
    val selfId: String? get() = backend.currentUserId

    private val myId: String? get() = selfId

    /** Whether you are tagged in the photo. */
    val isTagged: Boolean get() = people?.any { it.userId == myId } == true

    init {
        if (initialPeople == null || me == null) scope.launch { load(loadPeople = initialPeople == null) }
    }

    private suspend fun load(loadPeople: Boolean) {
        val me = myId
        val tags = if (loadPeople) attempt { backend.postTags(postId) }.getOrNull() else null
        val ids = (tags?.map { it.userId }.orEmpty() + listOfNotNull(me)).distinct()
        val profiles = attempt { backend.profiles(ids) }.getOrNull().orEmpty().associateBy { it.id }
        val urls = attempt { backend.signedUrls(profiles.values.mapNotNull { it.avatarPath }) }.getOrNull().orEmpty()
        fun person(id: String) = TaggedPerson(id, profiles[id]?.firstName.orEmpty(), profiles[id]?.avatarPath?.let(urls::get))
        if (self == null && me != null) self = person(me)
        if (loadPeople && tags != null) people = tags.map { person(it.userId) }
    }

    /** "I'm in this": tags you (optimistic, reverted on failure). */
    fun tag() {
        val before = people ?: return
        val me = self ?: myId?.let { TaggedPerson(it, "", null) } ?: return
        if (pending || isTagged) return
        if (!backend.isOnline()) {
            haptic(Tokens.Haptics.globalError)
            message = Message.Offline
            return
        }
        people = before + me
        run(before, Message.TagError) { backend.tagSelf(postId) }
    }

    /** "Remove tag": untags you (optimistic, reverted on failure). */
    fun untag() {
        val before = people ?: return
        if (pending || !isTagged) return
        if (!backend.isOnline()) {
            haptic(Tokens.Haptics.globalError)
            message = Message.Offline
            return
        }
        people = before.filterNot { it.userId == myId }
        run(before, Message.RemoveError) { backend.untagSelf(postId) }
    }

    private fun run(before: List<TaggedPerson>, failure: Message, call: suspend () -> Unit) {
        pending = true
        message = null
        haptic(Tokens.Haptics.globalSelect)
        scope.launch {
            attempt { call() }.onFailure { e ->
                people = before
                haptic(Tokens.Haptics.globalError)
                message = when (failureOf(e)) {
                    Failure.NotFound -> Message.NotFound.also { sheetOpen = false; onPhotoGone() }
                    Failure.Offline -> Message.Offline
                    else -> failure
                }
            }
            pending = false
        }
    }

    fun messageShown() {
        message = null
    }
}

/**
 * A [TagRunController] for [postId], remembered across recompositions. [people]: the tagged members from the
 * viewer's batch read of `post_tags` (null = read here); [me]: your own name and avatar (null = read here).
 */
@Composable
fun rememberTagRunController(
    postId: String,
    people: List<TaggedPerson>? = null,
    me: TaggedPerson? = null,
    onPhotoGone: () -> Unit = {},
): TagRunController {
    val backend = rememberMemoryBackend()
    val scope = rememberCoroutineScope()
    val haptics = rememberHaptics()
    return remember(postId, backend) { TagRunController(postId, backend, scope, people, me, haptic = haptics::perform, onPhotoGone = onPhotoGone) }
}

/** Test tags. */
object TagRunTags {
    const val RUN = "tagging.run"
    const val SHEET = "tagging.sheet"
}

/**
 * **The tag run** (design/surfaces/tagging.md A) — the second line of the photo viewer's footer (C-22, placed by
 * `photo.viewer`, which draws the date and Retro's " · " separator before it): text role `listSubtitle`, one line,
 * tail-truncated, one button.
 * - nobody tagged: `tagging.toggle` ("I'm in this") in `color.global.textOnMedia`; tap = tag yourself at once;
 * - someone tagged: `tagging.with` ("with {names}", first names in tag order joined by the platform list
 *   formatter, the names in `fontWeight.global.listTitle`) in `color.global.textSecondary`; tap = the "In this
 *   photo" sheet ([InThisPhotoSheet], owned here). Never a count.
 * Text changes cross-fade over `duration.global.crossfade`. TalkBack: a button labelled `tagging.toggle`, or
 * `tagging.a11y.people` with the "with …" text as its state. Draws nothing until the tags are known; errors show as
 * a platform toast (C-26). Use inside the viewer's dark (media) subtree.
 *
 * @param postId the photo's post (not for collages).
 * @param people tagged members from the viewer's `post_tags` read, in tag order; null = read here.
 * @param me your own name and avatar for the optimistic update; null = read here.
 * @param onPhotoGone `post_not_found`: the viewer closes the photo.
 */
@Composable
fun TagRun(
    postId: String,
    modifier: Modifier = Modifier,
    people: List<TaggedPerson>? = null,
    me: TaggedPerson? = null,
    onPhotoGone: () -> Unit = {},
    controller: TagRunController = rememberTagRunController(postId, people, me, onPhotoGone),
) {
    TagRunMessages(controller)
    val tagged = controller.people ?: return
    val toggle = stringResource(R.string.tagging_toggle)
    val peopleLabel = stringResource(R.string.tagging_a11y_people)
    val locale = LocalConfiguration.current.locales[0]
    val withText = if (tagged.isEmpty()) null else withNames(stringResource(R.string.tagging_with, joinNames(tagged, locale)), tagged)
    val haptics = rememberHaptics()
    val activate = {
        haptics.tap()
        if (withText == null) controller.tag() else controller.sheetOpen = true
    }
    AnimatedContent(
        targetState = withText,
        label = "tagRun",
        transitionSpec = { DsMotion.fadeIn togetherWith DsMotion.fadeOut },
        modifier = modifier
            .testTag(TagRunTags.RUN)
            // One text line high in the footer, but taps land within `size.global.minTouchTarget.android`.
            .expandedTap(Tokens.Sizes.globalMinTouchTargetAndroid, enabled = !controller.pending, onTap = activate)
            .clearAndSetSemantics {
                role = Role.Button
                if (controller.pending) disabled()
                onClick { activate(); true }
                if (withText == null) {
                    contentDescription = toggle
                } else {
                    contentDescription = peopleLabel
                    stateDescription = withText.text
                }
            },
    ) { text ->
        if (text == null) {
            Text(toggle, style = TextRoles.listSubtitle, color = Tokens.Colors.globalTextOnMedia, maxLines = 1, overflow = TextOverflow.Ellipsis)
        } else {
            Text(text, style = TextRoles.listSubtitle, color = Tokens.ColorsDark.globalTextSecondary, maxLines = 1, overflow = TextOverflow.Ellipsis)
        }
    }
    if (controller.sheetOpen) InThisPhotoSheet(controller, onDismiss = { controller.sheetOpen = false })
}

/** Shows the controller's failure as a platform toast (C-26: Android `Toast`, LENGTH_SHORT). */
@Composable
private fun TagRunMessages(controller: TagRunController) {
    val context = LocalContext.current
    val message = controller.message ?: return
    val text = stringResource(
        when (message) {
            TagRunController.Message.TagError -> R.string.tagging_error
            TagRunController.Message.RemoveError -> R.string.tagging_removeerror
            TagRunController.Message.NotFound -> R.string.tagging_notfound
            TagRunController.Message.Offline -> R.string.tagging_offline
        },
    )
    LaunchedEffect(message) {
        PlatformToast.show(context, text)
        controller.messageShown()
    }
}

/** First names in tag order joined by the platform list formatter ("Ana, Ben and Cleo"). */
internal fun joinNames(people: List<TaggedPerson>, locale: Locale): String =
    ListFormatter.getInstance(locale).format(people.map { it.firstName })

/** [text] with each tagged first name in `fontWeight.global.listTitle` (Retro sets names in grey lines in semibold, C-15). */
internal fun withNames(text: String, people: List<TaggedPerson>): AnnotatedString = buildAnnotatedString {
    var cursor = 0
    for (name in people.map { it.firstName }.filter { it.isNotEmpty() }) {
        val at = text.indexOf(name, cursor)
        if (at < 0) continue
        append(text.substring(cursor, at))
        withStyle(SpanStyle(fontWeight = Tokens.FontWeights.fontWeightGlobalListTitle)) { append(name) }
        cursor = at + name.length
    }
    append(text.substring(cursor))
}

/**
 * **"In this photo"** (design/surfaces/tagging.md B): the platform page sheet at its medium detent (C-29,
 * follows the system appearance): header `tagging.sheet.title` with the close circle (C-11 on the page); people rows
 * (C-16: `size.global.avatarPicker`, first name `listTitle`) inside `size.global.screenMargin`, your row with the
 * outline capsule `tagging.remove` (C-06); everyone untagged → C-27 title `tagging.sheet.empty`; while you are not
 * tagged, the primary capsule `tagging.toggle` (C-05) at the bottom inside `size.global.buttonMarginH`.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun InThisPhotoSheet(controller: TagRunController, onDismiss: () -> Unit) {
    SystemAppearance {
        DsBottomSheet(onDismissRequest = onDismiss, sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = false)) {
            InThisPhotoContent(controller, onDismiss)
        }
    }
}

/** The sheet's content (also used by the snapshot of the sheet). */
@Composable
internal fun InThisPhotoContent(controller: TagRunController, onClose: () -> Unit) {
    val people = controller.people.orEmpty()
    val tagged = controller.isTagged
    Column(Modifier.fillMaxWidth().windowInsetsPadding(WindowInsets.navigationBars).testTag(TagRunTags.SHEET)) {
        SheetHeader(
            stringResource(R.string.tagging_sheet_title),
            // tagging has no close label of its own (copy gap, reported): the memory group's "Close" (PLATFORM).
            close = HeaderAction(Tokens.Icons.globalClose, stringResource(R.string.birthday_request_a11y_close), onClose),
        )
        Spacer(Modifier.height(Tokens.Sizes.globalScreenMargin))
        if (people.isEmpty()) {
            Box(Modifier.fillMaxWidth().padding(vertical = Tokens.Sizes.globalListGap), contentAlignment = Alignment.Center) {
                EmptyState(stringResource(R.string.tagging_sheet_empty), null)
            }
        }
        people.forEach { person ->
            FadeInItem(person.userId) {
                Row(Modifier.fillMaxWidth().padding(bottom = Tokens.Sizes.globalListGap), verticalAlignment = Alignment.CenterVertically) {
                    PeopleRow(person.firstName, memoryModel(person.avatar), Modifier.weight(1f))
                    if (person.userId == controller.selfId) {
                        Capsule(stringResource(R.string.tagging_remove), controller::untag, style = CapsuleStyle.Outline, enabled = !controller.pending)
                        Spacer(Modifier.width(Tokens.Sizes.globalScreenMargin))
                    }
                }
            }
        }
        if (!tagged) {
            PrimaryButton(
                stringResource(R.string.tagging_toggle),
                controller::tag,
                Modifier.padding(horizontal = Tokens.Sizes.globalButtonMarginH, vertical = Tokens.Sizes.globalScreenMargin),
                enabled = !controller.pending,
            )
        }
    }
}
