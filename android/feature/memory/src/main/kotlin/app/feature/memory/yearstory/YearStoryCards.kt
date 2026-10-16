// Surface: year.story — the cards inside the recap-preview frame (design/surfaces/year.story.md B, C).
// References: references/auto/retro/press/tc-2023-12-recaps.png (TC-REC phones 2–3), references/auto/retro/store/retro-store-04.png (ST-04),
// mechanics references/auto/wrapped/frames/wrapped24-rec-emilycraig-sheet-every3s.png (reveal).
package app.feature.memory.yearstory

import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.Stable
import androidx.compose.runtime.State
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Density
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.min
import app.designsystem.R
import app.designsystem.generated.Tokens
import app.designsystem.rememberReduceMotion
import app.feature.memory.common.MemoryFormats
import app.feature.memory.common.MemoryBackdrop
import app.feature.memory.common.MemoryImage
import app.ui.foundation.PhotoScrimOverlay
import app.ui.text.CapTop
import app.ui.text.TextRoles
import app.ui.text.capTopAt
import app.ui.foundation.endAtLastBaseline

/** Headline and subline copy of a text card (null subline = headline only); null for photo, collage and summary cards. */
@Composable
internal fun cardText(card: StoryCard): Pair<String, String?>? = when (card) {
    is StoryCard.Intro -> stringResource(R.string.year_story_intro_title) to stringResource(R.string.year_story_intro_subtitle, card.groupName, card.year.toString())
    StoryCard.LookBack -> stringResource(R.string.year_story_lookback_title) to null
    is StoryCard.Moments -> stringResource(R.string.year_story_moments_count, card.groupName, MemoryFormats.number(card.count)) to null
    is StoryCard.BusiestMonth -> stringResource(R.string.year_story_busiestmonth_title, MemoryFormats.storyMonth(card.month)) to null
    StoryCard.MostReactedSetup -> stringResource(R.string.year_story_mostreacted_title) to null
    StoryCard.TogetherSetup -> stringResource(R.string.year_story_together_title) to stringResource(R.string.year_story_together_aside)
    StoryCard.Outro -> stringResource(R.string.year_story_outro_title) to null
    is StoryCard.MostReactedPhoto, is StoryCard.TogetherDay, StoryCard.Summary -> null
}

/**
 * The 9:16 content box (`layout.year.story.frame`: aspectWidth 9 × aspectHeight 16) inside a frame [width] × [height]:
 * as wide as the frame, fitted when the frame is shorter (so the footer never leaves the frame). The share image is
 * this box rendered at 1080 px wide.
 */
internal fun contentBox(width: Dp, height: Dp): Pair<Dp, Dp> {
    val frame = Tokens.Layouts.YearStoryFrame
    val w = min(width, height * frame.aspectWidth / frame.aspectHeight)
    return w to w * frame.aspectHeight / frame.aspectWidth
}

/**
 * A card inside the frame: its background over the whole frame ([CardBackground]) and its text / footer laid out in
 * the centred 9:16 box ([CardForeground]). [backdropDrawn]: the frame already shows the blurred cover (the recap
 * preview's backdrop) — the share image draws it itself.
 */
@Composable
internal fun StoryCardPage(card: StoryCard, recap: StoryRecap, revealed: Boolean, backdropDrawn: Boolean, onSettled: () -> Unit = {}, software: Boolean = false) {
    BoxWithConstraints(Modifier.fillMaxSize()) {
        CardBackground(card, recap, backdropDrawn, onSettled, software)
        val (w, h) = contentBox(maxWidth, maxHeight)
        Box(Modifier.size(w, h).align(Alignment.Center)) { CardForeground(card, revealed) }
    }
}

/**
 * Card backgrounds: text cards — the cover blurred over the frame (`layout.global.materials.backdrop`) under
 * `layout.global.photoScrim`; photo cards — the photo full bleed (aspect fill, display rendition) under the scrim;
 * collage cards — the collage on its own blurred backdrop, fitted whole (never cropped), under the scrim.
 */
@Composable
internal fun BoxScope.CardBackground(card: StoryCard, recap: StoryRecap, backdropDrawn: Boolean, onSettled: () -> Unit, software: Boolean) {
    when (card) {
        is StoryCard.MostReactedPhoto -> {
            val label = stringResource(R.string.year_story_a11y_photo, card.name, MemoryFormats.spokenDate(card.date))
            MemoryImage(card.url, null, Modifier.fillMaxSize().clearAndSetSemantics { contentDescription = label }, software = software, onSettled = onSettled)
        }
        is StoryCard.TogetherDay -> {
            val label = stringResource(R.string.year_story_a11y_collage, MemoryFormats.spokenDate(card.date))
            Backdrop(card.url, software, onSettled)
            MemoryImage(
                card.url,
                null,
                Modifier.fillMaxSize().clearAndSetSemantics { contentDescription = label },
                contentScale = ContentScale.Fit,
                placeholder = androidx.compose.ui.graphics.Color.Transparent,
                software = software,
                onSettled = onSettled,
            )
        }
        StoryCard.Summary -> Unit
        else -> if (!backdropDrawn) Backdrop(recap.coverUrl, software, onSettled)
    }
    if (card != StoryCard.Summary) PhotoScrimOverlay()
}

/** The cover (or a collage) as the C-34 backdrop over the whole frame (`layout.global.materials.backdrop`). */
@Composable
internal fun Backdrop(url: String?, software: Boolean = false, onSettled: () -> Unit = {}) = MemoryBackdrop(url, software = software, onSettled = onSettled)

/** How many images a share image of [card] (summary [style]) waits for before it is recorded. */
internal fun exportImages(card: StoryCard, style: SummaryStyle, recap: StoryRecap): Int = when (card) {
    is StoryCard.TogetherDay -> 2
    StoryCard.Summary -> if (style == SummaryStyle.Card) 1 + recap.photos.size else 1
    else -> 1
}

/**
 * Card text in the 9:16 box: text cards — a centred block `dimension.year.story.frame.padding` from the sides, the
 * headline in the display serif (text role `displayMedium`, `color.global.textOnMedia`, header, announced) and the
 * subline (text role `textButton`) its cap top `dimension.birthday.request.headlineToMessage` below the headline's
 * baseline, revealed (Motion); photo cards — footer: the date (`layout.year.story.dateFormat`, `displaySmall`) and
 * `year.story.mostReacted.photo` ("Post by {name}", `listTitle`); collage cards — footer: the date.
 */
@Composable
internal fun BoxScope.CardForeground(card: StoryCard, revealed: Boolean) {
    when (card) {
        is StoryCard.MostReactedPhoto -> RecapFooter(
            MemoryFormats.storyDate(card.date),
            stringResource(R.string.year_story_mostreacted_photo, card.name),
            null,
            TextRoles.displaySmall,
            Tokens.Colors.globalTextOnMedia,
            Modifier.align(Alignment.BottomCenter),
        )
        is StoryCard.TogetherDay -> RecapFooter(MemoryFormats.storyDate(card.date), null, null, TextRoles.displaySmall, Tokens.Colors.globalTextOnMedia, Modifier.align(Alignment.BottomCenter))
        StoryCard.Summary -> Unit
        else -> {
            val (headline, subline) = cardText(card) ?: return
            TextBlock(card, headline, subline, revealed, Modifier.align(Alignment.Center))
        }
    }
}

@Composable
private fun TextBlock(card: StoryCard, headline: String, subline: String?, revealed: Boolean, modifier: Modifier) {
    val reveal = rememberReveal(card, animate = !revealed)
    Column(modifier.fillMaxWidth().padding(horizontal = Tokens.Sizes.yearStoryFramePadding), horizontalAlignment = Alignment.CenterHorizontally) {
        Text(
            headline,
            style = TextRoles.displayMedium,
            color = Tokens.Colors.globalTextOnMedia,
            textAlign = TextAlign.Center,
            modifier = Modifier
                .fillMaxWidth()
                .endAtLastBaseline()
                .graphicsLayer {
                    translationY = reveal.headlineOffset()
                    alpha = reveal.headlineAlpha()
                }
                .semantics {
                    heading()
                    liveRegion = LiveRegionMode.Polite
                },
        )
        if (subline != null) {
            val style = TextRoles.textButton
            Text(
                subline,
                style = style,
                color = Tokens.Colors.globalTextOnMedia,
                textAlign = TextAlign.Center,
                modifier = Modifier
                    .fillMaxWidth()
                    .capTopAt(Tokens.Sizes.birthdayRequestHeadlineToMessage, CapTop.height(style))
                    .graphicsLayer {
                        translationY = reveal.sublineOffset()
                        alpha = reveal.sublineAlpha()
                    },
            )
        }
    }
}

/**
 * The text reveal (design/surfaces/year.story.md → Motion, Wrapped mechanics): the headline moves up
 * `dimension.year.story.reveal.headlineShift` over `duration.year.story.reveal.headline` on `easing.year.story.reveal`;
 * the subline starts `duration.year.story.reveal.sublineDelay` later from `dimension.year.story.reveal.sublineOffset`
 * below over `duration.year.story.reveal.subline` on `easing.year.story.reveal.subline`; both fade in over
 * `duration.global.fade`. Reduce Motion (`layout.global.reduceMotion`): a cross-fade of the same durations.
 */
@Stable
internal class Reveal(
    private val headline: State<Float>,
    private val subline: State<Float>,
    private val headlineFade: State<Float>,
    private val sublineFade: State<Float>,
    private val moves: Boolean,
    private val density: Density,
) {
    fun headlineOffset(): Float = if (moves) with(density) { Tokens.Sizes.yearStoryRevealHeadlineShift.toPx() } * (1f - headline.value) else 0f
    fun sublineOffset(): Float = if (moves) with(density) { Tokens.Sizes.yearStoryRevealSublineOffset.toPx() } * (1f - subline.value) else 0f
    fun headlineAlpha(): Float = if (moves) headlineFade.value else headline.value
    fun sublineAlpha(): Float = if (moves) sublineFade.value else subline.value
}

@Composable
internal fun rememberReveal(card: StoryCard, animate: Boolean): Reveal {
    val reduceMotion by rememberReduceMotion()
    val moves = animate && !reduceMotion
    var started by remember(card) { mutableStateOf(!animate) }
    LaunchedEffect(card) { started = true }
    val target = if (started) 1f else 0f
    // Moving: each part travels on its own curve and fades in over the house fade; cross-fade: opacity over the reveal's durations.
    val headline = animateFloatAsState(target, tween(Tokens.Durations.yearStoryRevealHeadline, easing = if (moves) Tokens.Easings.yearStoryReveal else LinearEasing), label = "revealHeadline")
    val subline = animateFloatAsState(
        target,
        tween(Tokens.Durations.yearStoryRevealSubline, Tokens.Durations.yearStoryRevealSublineDelay, if (moves) Tokens.Easings.yearStoryRevealSubline else LinearEasing),
        label = "revealSubline",
    )
    val headlineFade = animateFloatAsState(target, tween(Tokens.Durations.globalFade, easing = Tokens.Easings.globalStandard), label = "revealHeadlineFade")
    val sublineFade = animateFloatAsState(target, tween(Tokens.Durations.globalFade, Tokens.Durations.yearStoryRevealSublineDelay, Tokens.Easings.globalStandard), label = "revealSublineFade")
    val density = LocalDensity.current
    return remember(card, moves, density) { Reveal(headline, subline, headlineFade, sublineFade, moves, density) }
}

/**
 * The summary's styles (`layout.year.story.summary`): [SummaryStyle.Card] — the recap card on the blurred cover
 * ([RecapCardPage]; the year, the group name; the app line `year.story.card.app` is BLOCKED and left out);
 * [SummaryStyle.Cover] — the cover full bleed with the footer ([RecapCoverPage]). [backdropDrawn]: the frame already
 * shows the blurred cover.
 */
@Composable
internal fun SummaryPage(style: SummaryStyle, recap: StoryRecap, backdropDrawn: Boolean, onSettled: () -> Unit = {}, software: Boolean = false) {
    val year = recap.year.toString()
    when (style) {
        SummaryStyle.Card -> {
            val photos = recap.photos.map { p ->
                RecapCardPhoto(p.thumbUrl, stringResource(R.string.year_story_a11y_photo, p.name, MemoryFormats.spokenDate(p.date)))
            }
            RecapCardPage(
                photos,
                year,
                name = recap.groupName,
                backdrop = { if (!backdropDrawn) Backdrop(recap.coverUrl, software, onSettled) },
                image = { photo, m -> MemoryImage(photo.image as String?, null, m, placeholder = Tokens.ColorsLight.globalControl, software = software, onSettled = onSettled) },
            )
        }
        SummaryStyle.Cover -> RecapCoverPage(year, name = recap.groupName) {
            MemoryImage(recap.coverUrl, null, Modifier.fillMaxSize(), software = software, onSettled = onSettled)
        }
    }
}
