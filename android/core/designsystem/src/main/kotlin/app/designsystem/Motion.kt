package app.designsystem

import android.animation.ValueAnimator
import android.content.ContentResolver
import android.content.Context
import android.database.ContentObserver
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import androidx.compose.animation.EnterTransition
import androidx.compose.animation.ExitTransition
import androidx.compose.animation.core.AnimationSpec
import androidx.compose.animation.core.FiniteAnimationSpec
import androidx.compose.animation.core.animateDpAsState
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.animateIntOffsetAsState
import androidx.compose.animation.core.snap
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideIn
import androidx.compose.animation.slideOut
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.State
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.IntSize

/**
 * Reduced motion: Android has no separate "reduce motion" switch; the accessibility setting
 * "Remove animations" sets the animator duration scale to 0, which is what we read.
 */
object ReduceMotion {
    fun isEnabled(context: Context): Boolean {
        val scale = Settings.Global.getFloat(context.contentResolver, Settings.Global.ANIMATOR_DURATION_SCALE, 1f)
        return scale == 0f || !ValueAnimator.areAnimatorsEnabled()
    }

    internal fun observe(resolver: ContentResolver, onChange: () -> Unit): () -> Unit {
        val observer = object : ContentObserver(Handler(Looper.getMainLooper())) {
            override fun onChange(selfChange: Boolean) = onChange()
        }
        resolver.registerContentObserver(Settings.Global.getUriFor(Settings.Global.ANIMATOR_DURATION_SCALE), false, observer)
        resolver.registerContentObserver(Settings.Global.getUriFor(Settings.Global.TRANSITION_ANIMATION_SCALE), false, observer)
        return { resolver.unregisterContentObserver(observer) }
    }
}

/** Overrides the system setting below this point (previews, snapshot tests). Null = follow the system. */
val LocalReduceMotionOverride = staticCompositionLocalOf<Boolean?> { null }

/** Whether movement should be dropped; follows the system setting live. */
@Composable
fun rememberReduceMotion(): State<Boolean> {
    val override = LocalReduceMotionOverride.current
    val context = LocalContext.current
    val state = remember(context) { mutableStateOf(override ?: ReduceMotion.isEnabled(context)) }
    DisposableEffect(context, override) {
        if (override != null) {
            state.value = override
            onDispose { }
        } else {
            state.value = ReduceMotion.isEnabled(context)
            val stop = ReduceMotion.observe(context.contentResolver) { state.value = ReduceMotion.isEnabled(context) }
            onDispose(stop)
        }
    }
    return state
}

/** What an animated value changes: movement is dropped under reduced motion, opacity is kept. */
enum class MotionChannel { Movement, Opacity }

/** The spec to use for [channel]: movement snaps to its target when [reduceMotion] is on. */
fun <T> dsMotionSpec(spec: AnimationSpec<T>, channel: MotionChannel, reduceMotion: Boolean): AnimationSpec<T> =
    if (reduceMotion && channel == MotionChannel.Movement) snap() else spec

@Composable
fun dsAnimateFloatAsState(
    targetValue: Float,
    animationSpec: AnimationSpec<Float>,
    channel: MotionChannel,
    label: String = "dsFloat",
): State<Float> {
    val reduce by rememberReduceMotion()
    return animateFloatAsState(targetValue, dsMotionSpec(animationSpec, channel, reduce), label = label)
}

/** Opacity is never dropped: fades still run under reduced motion. */
@Composable
fun dsAnimateAlphaAsState(targetValue: Float, animationSpec: AnimationSpec<Float>, label: String = "dsAlpha"): State<Float> =
    dsAnimateFloatAsState(targetValue, animationSpec, MotionChannel.Opacity, label)

@Composable
fun dsAnimateDpAsState(targetValue: Dp, animationSpec: AnimationSpec<Dp>, label: String = "dsDp"): State<Dp> {
    val reduce by rememberReduceMotion()
    return animateDpAsState(targetValue, dsMotionSpec(animationSpec, MotionChannel.Movement, reduce), label = label)
}

@Composable
fun dsAnimateOffsetAsState(targetValue: IntOffset, animationSpec: AnimationSpec<IntOffset>, label: String = "dsOffset"): State<IntOffset> {
    val reduce by rememberReduceMotion()
    return animateIntOffsetAsState(targetValue, dsMotionSpec(animationSpec, MotionChannel.Movement, reduce), label = label)
}

/** Enter transition: fade plus slide; under reduced motion the slide is dropped and the fade kept. */
fun dsEnterTransition(
    reduceMotion: Boolean,
    fade: FiniteAnimationSpec<Float>,
    slide: FiniteAnimationSpec<IntOffset>,
    initialOffset: (IntSize) -> IntOffset,
): EnterTransition = if (reduceMotion) fadeIn(fade) else fadeIn(fade) + slideIn(slide, initialOffset)

/** Exit transition: fade plus slide; under reduced motion the slide is dropped and the fade kept. */
fun dsExitTransition(
    reduceMotion: Boolean,
    fade: FiniteAnimationSpec<Float>,
    slide: FiniteAnimationSpec<IntOffset>,
    targetOffset: (IntSize) -> IntOffset,
): ExitTransition = if (reduceMotion) fadeOut(fade) else fadeOut(fade) + slideOut(slide, targetOffset)
