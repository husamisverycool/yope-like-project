package app.ui.foundation

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.EnterTransition
import androidx.compose.animation.ExitTransition
import androidx.compose.animation.core.FiniteAnimationSpec
import androidx.compose.animation.core.tween
import androidx.compose.animation.expandVertically
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.shrinkVertically
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.IntSize
import app.designsystem.dsMotionSpec
import app.designsystem.MotionChannel
import app.designsystem.generated.Tokens
import app.designsystem.rememberReduceMotion

/**
 * The motion every component uses (design/components.md "Rules" → Motion; tokens README → motion):
 * appear / disappear = fade `duration.global.fade` (150 ms) with `easing.global.standard` (Retro's house
 * FastOutSlowIn); state crossfades `duration.global.crossfade` (100 ms); onboarding pages
 * `duration.global.pageTransition` (500 ms); photo open `duration.global.photoOpen`; strip insert
 * `duration.global.stripInsert`. Reduce Motion (`layout.global.reduceMotion`, read by
 * [rememberReduceMotion]): movement / size changes are dropped (snap) and the fades stay.
 */
object DsMotion {
    fun <T> fade(): FiniteAnimationSpec<T> = tween(Tokens.Durations.globalFade, easing = Tokens.Easings.globalStandard)

    fun <T> crossfade(): FiniteAnimationSpec<T> = tween(Tokens.Durations.globalCrossfade, easing = Tokens.Easings.globalStandard)

    fun <T> pageTransition(): FiniteAnimationSpec<T> = tween(Tokens.Durations.globalPageTransition, easing = Tokens.Easings.globalStandard)

    fun <T> photoOpen(): FiniteAnimationSpec<T> = tween(Tokens.Durations.globalPhotoOpen, easing = Tokens.Easings.globalStandard)

    fun <T> stripInsert(): FiniteAnimationSpec<T> = tween(Tokens.Durations.globalStripInsert, easing = Tokens.Easings.globalStandard)

    /** Appear: fade in (kept under Reduce Motion). */
    val fadeIn: EnterTransition get() = fadeIn(fade())

    /** Disappear: fade out (kept under Reduce Motion). */
    val fadeOut: ExitTransition get() = fadeOut(fade())

    /**
     * Onboarding page enter (RP §3.7: fadeIn + expand, 500 ms); under Reduce Motion the expansion is
     * dropped and the fade kept.
     */
    fun pageEnter(reduceMotion: Boolean): EnterTransition =
        if (reduceMotion) fadeIn(pageTransition()) else fadeIn(pageTransition()) + expandVertically(pageTransition<IntSize>())

    /** Onboarding page exit (fadeOut + shrink, 500 ms); Reduce Motion keeps the fade only. */
    fun pageExit(reduceMotion: Boolean): ExitTransition =
        if (reduceMotion) fadeOut(pageTransition()) else fadeOut(pageTransition()) + shrinkVertically(pageTransition<IntSize>())

    /** A movement spec (offsets, placement) that snaps under Reduce Motion. */
    fun movement(spec: FiniteAnimationSpec<IntOffset>, reduceMotion: Boolean): FiniteAnimationSpec<IntOffset> =
        dsMotionSpec(spec, MotionChannel.Movement, reduceMotion) as FiniteAnimationSpec<IntOffset>
}

/** Shows [content] with the house fade (C-28 "Appearance of loaded content: fade `duration.global.fade`"). */
@Composable
fun FadeVisibility(visible: Boolean, modifier: Modifier = Modifier, content: @Composable () -> Unit) {
    AnimatedVisibility(visible = visible, modifier = modifier, enter = DsMotion.fadeIn, exit = DsMotion.fadeOut) { content() }
}

/** Whether Reduce Motion is on (Android: animator duration scale 0 / animators disabled). */
@Composable
fun reduceMotion(): Boolean {
    val reduce by rememberReduceMotion()
    return reduce
}
