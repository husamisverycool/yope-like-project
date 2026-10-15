package app.feature.memory.yearstory

import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.text.BasicText
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.Stable
import androidx.compose.runtime.State
import androidx.compose.runtime.getValue
import androidx.compose.runtime.key
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.unit.Density
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import app.designsystem.R
import app.designsystem.rememberReduceMotion
import app.feature.memory.common.MemoryBlocked
import app.designsystem.generated.Tokens
import app.feature.memory.common.MemoryFormats
import app.feature.memory.common.MemoryImage
import app.feature.memory.common.roleStyle

/** Headline and subline copy of a text card (null subline = headline only). */
@Composable
internal fun cardText(card: StoryCard): Pair<String, String?> = when (card) {
    StoryCard.Intro -> stringResource(R.string.year_story_intro_title) to stringResource(R.string.year_story_intro_subtitle)
    StoryCard.MomentsSetup -> stringResource(R.string.year_story_moments_title) to null
    is StoryCard.Moments -> stringResource(R.string.year_story_moments_count, card.groupName, MemoryFormats.number(card.count)) to
        stringResource(R.string.year_story_moments_aside)
    is StoryCard.BusiestMonth -> stringResource(R.string.year_story_busiestmonth_title, MemoryFormats.storyMonth(card.month)) to
        stringResource(R.string.year_story_busiestmonth_aside)
    StoryCard.MostReactedSetup -> stringResource(R.string.year_story_mostreacted_title) to stringResource(R.string.year_story_mostreacted_aside)
    is StoryCard.MostReactedPhoto -> stringResource(R.string.year_story_mostreacted_photo, card.name, MemoryFormats.storyDate(card.date)) to null
    StoryCard.TogetherSetup -> stringResource(R.string.year_story_together_title) to stringResource(R.string.year_story_together_aside)
    is StoryCard.TogetherDay -> MemoryFormats.storyDate(card.date) to null
    StoryCard.Teaser -> stringResource(R.string.year_story_outro_teaser) to null
    StoryCard.Outro -> stringResource(R.string.year_story_outro_title) to stringResource(R.string.year_story_outro_subtitle)
    StoryCard.Summary -> "" to null
}

private val headlineStyle @Composable get() = roleStyle(
    Tokens.FontSizes.yearStoryHeadline, Tokens.FontWeights.fontWeightYearStoryHeadline, Tokens.LineHeights.yearStoryHeadline, Tokens.Fonts.yearStory,
).copy(color = Tokens.Colors.globalTextPrimary, textAlign = TextAlign.Center)

private val sublineStyle @Composable get() = roleStyle(
    Tokens.FontSizes.yearStoryBody, Tokens.FontWeights.fontWeightYearStoryBody, Tokens.LineHeights.yearStoryBody, Tokens.Fonts.yearStory,
).copy(color = Tokens.Colors.globalTextPrimary, textAlign = TextAlign.Center)

/**
 * The content of one card on the 9:16 canvas (no progress bar, chrome or share row) — what the
 * screen shows and what a share image draws. [revealed] skips the reveal (share images, previews).
 * [onSettled] runs once the card's image (if any) has loaded or failed.
 */
@Composable
fun StoryCardContent(
    card: StoryCard,
    canvasWidth: Dp,
    canvasHeight: Dp,
    revealed: Boolean,
    modifier: Modifier = Modifier,
    softwareImages: Boolean = false,
    onSettled: () -> Unit = {},
) {
    val (headline, subline) = cardText(card)
    Box(modifier.fillMaxSize()) {
        when (card) {
            is StoryCard.MostReactedPhoto, is StoryCard.TogetherDay -> {
                val photoCard = Tokens.Layouts.YearStoryPhotoCard
                val box = canvasWidth * photoCard.boxWidthRatio
                val top = canvasHeight * photoCard.boxCenterYRatio - box / 2
                val url = if (card is StoryCard.MostReactedPhoto) card.url else (card as StoryCard.TogetherDay).url
                val collage = card is StoryCard.TogetherDay
                MemoryImage(
                    url,
                    // Photo cards: decorative (the headline says who and when); collages are labelled.
                    contentDescription = if (collage) stringResource(R.string.year_story_a11y_collage, MemoryFormats.spokenDate((card as StoryCard.TogetherDay).date)) else null,
                    modifier = Modifier.align(Alignment.TopCenter).offset(y = top).size(box),
                    // layout.year.story.photoCard: a photo fills the square, a collage is fitted inside it.
                    contentScale = if (collage) ContentScale.Fit else ContentScale.Crop,
                    software = softwareImages,
                    onSettled = onSettled,
                )
                Headline(
                    headline,
                    Modifier
                        .align(Alignment.TopCenter)
                        .padding(top = top + box + photoCard.textGap.dp)
                        .widthIn(max = Tokens.Sizes.yearStoryTextMaxWidth),
                )
            }
            StoryCard.Summary -> LaunchedEffect(Unit) { onSettled() }
            else -> {
                LaunchedEffect(Unit) { onSettled() }
                // One reveal per card: its animation state starts fresh on every card.
                key(card) { Column(
                    Modifier.align(Alignment.Center).widthIn(max = Tokens.Sizes.yearStoryTextMaxWidth),
                    horizontalAlignment = Alignment.CenterHorizontally,
                ) {
                    val reveal = rememberReveal(card, animate = !revealed && subline != null)
                    Headline(headline, Modifier.fillMaxWidth().graphicsLayer { translationY = reveal.headlineOffset() })
                    if (subline != null) {
                        BasicText(
                            subline,
                            Modifier.fillMaxWidth().graphicsLayer {
                                translationY = reveal.sublineOffset()
                                alpha = reveal.sublineAlpha()
                            },
                            style = sublineStyle,
                        )
                    }
                } }
            }
        }
    }
}

@Composable
private fun Headline(text: String, modifier: Modifier) {
    BasicText(
        text,
        modifier.semantics {
            heading()
            liveRegion = LiveRegionMode.Polite
        },
        style = headlineStyle,
    )
}

/**
 * The text reveal of a card with a subline (design/surfaces/year.story.md, Motion): the headline
 * moves up `dimension.year.story.reveal.headlineShift` over `duration.year.story.reveal.headline` on
 * `easing.year.story.reveal`; the subline appears `duration.year.story.reveal.sublineDelay` later,
 * `dimension.year.story.reveal.sublineOffset` below, and settles over `duration.year.story.reveal.subline`
 * on `easing.year.story.reveal.subline`. Under Reduce Motion (`layout.global.reduceMotion`) — or if a
 * curve were BLOCKED again — the movement becomes a cross-fade with the same timings: the headline
 * stays in place and the subline fades in.
 */
@Stable
internal class Reveal(private val headline: State<Float>, private val subline: State<Float>, private val moves: Boolean, private val density: Density) {
    fun headlineOffset(): Float = if (moves) with(density) { Tokens.Sizes.yearStoryRevealHeadlineShift.toPx() } * (1f - headline.value) else 0f
    fun sublineOffset(): Float = if (moves) with(density) { Tokens.Sizes.yearStoryRevealSublineOffset.toPx() } * (1f - subline.value) else 0f

    /** Moving: the subline is there from the moment it starts rising; cross-fade: it fades in. */
    fun sublineAlpha(): Float = if (moves) (if (subline.value > 0f) 1f else 0f) else subline.value
}

@Composable
internal fun rememberReveal(card: StoryCard, animate: Boolean): Reveal {
    val reduceMotion by rememberReduceMotion()
    val headlineCurve = MemoryBlocked.yearStoryRevealEasing
    val sublineCurve = MemoryBlocked.yearStoryRevealSublineEasing
    val moves = animate && headlineCurve != null && sublineCurve != null && !reduceMotion
    var started by remember(card) { mutableStateOf(!animate) }
    LaunchedEffect(card) { started = true }
    // A cross-fade interpolates opacity linearly over the token duration.
    val headline = animateFloatAsState(
        if (started) 1f else 0f,
        tween(Tokens.Durations.yearStoryRevealHeadline, easing = if (moves) headlineCurve!! else LinearEasing),
        label = "revealHeadline", // provenance-ok: animation inspector label, never shown
    )
    val subline = animateFloatAsState(
        if (started) 1f else 0f,
        tween(Tokens.Durations.yearStoryRevealSubline, Tokens.Durations.yearStoryRevealSublineDelay, if (moves) sublineCurve!! else LinearEasing),
        label = "revealSubline", // provenance-ok: animation inspector label, never shown
    )
    val density = LocalDensity.current
    return remember(card, moves, density) { Reveal(headline, subline, moves, density) }
}
