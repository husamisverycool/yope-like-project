package app.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.selection.selectable
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import app.designsystem.dsAnimateAlphaAsState
import app.designsystem.dsAnimateDpAsState
import app.designsystem.dsTextStyle
import app.designsystem.generated.Tokens
import app.designsystem.rememberReduceMotion
import app.ui.haptics.rememberHaptics

/**
 * Yope's segmented control (group profile "pics | wall | recaps", GP; reused for the group type in
 * groups.create).
 *
 * Tokens: track `groups.screen.color.segmentTrack`, minimum height `groups.screen.size.segmentHeight`
 * (grows with text; labels wrap, no scale factor), shape `radius.global.capsule`; selected pill
 * `color.global.surfaceLight` inset `groups.screen.size.segmentInset`, its label
 * `color.global.onSurfaceLight`; labels `groups.screen.fontSize.segmentLabel` /
 * `.fontWeight.segmentLabel`, unselected `color.global.textPrimary`. The pill moves with
 * `spring.global.platformDefault.android`; under Reduce Motion (`layout.global.reduceMotion`) it
 * cross-fades between segments instead. Segment change plays `haptic.global.select`. Semantics:
 * each segment is `Role.Tab` with `selected`. Side margins come from the caller.
 */
@Composable
fun SegmentedControl(
    options: List<String>,
    selectedIndex: Int,
    onSelect: (Int) -> Unit,
    modifier: Modifier = Modifier,
) {
    val haptics = rememberHaptics()
    val reduceMotion by rememberReduceMotion()
    val inset = Tokens.Sizes.groupsScreenSizeSegmentInset
    val spring = Tokens.Springs.globalPlatformDefaultAndroid
    BoxWithConstraints(
        modifier
            .fillMaxWidth()
            .heightIn(min = Tokens.Sizes.groupsScreenSizeSegmentHeight)
            .background(Tokens.Colors.groupsScreenColorSegmentTrack, CircleShape)
            .padding(inset),
    ) {
        val segment: Dp = maxWidth / options.size.coerceAtLeast(1)
        if (!reduceMotion) {
            val x by dsAnimateDpAsState(segment * selectedIndex, spring.spec(), label = "segmentPill")
            Box(Modifier.matchParentSize()) {
                Box(
                    Modifier
                        .offset(x = x)
                        .width(segment)
                        .fillMaxHeight()
                        .background(Tokens.Colors.globalSurfaceLight, CircleShape),
                )
            }
        }
        val inner = Tokens.Sizes.groupsScreenSizeSegmentHeight - inset - inset
        Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
            options.forEachIndexed { index, label ->
                val selected = index == selectedIndex
                Box(
                    Modifier
                        .weight(1f)
                        .heightIn(min = inner)
                        .selectable(selected = selected, role = Role.Tab) {
                            if (!selected) {
                                haptics.perform(Tokens.Haptics.globalSelect)
                                onSelect(index)
                            }
                        },
                    contentAlignment = Alignment.Center,
                ) {
                    if (reduceMotion) {
                        val alpha by dsAnimateAlphaAsState(if (selected) 1f else 0f, spring.spec(), label = "segmentFade")
                        Box(Modifier.matchParentSize().alpha(alpha).background(Tokens.Colors.globalSurfaceLight, CircleShape))
                    }
                    Text(
                        label,
                        style = dsTextStyle(Tokens.FontSizes.groupsScreenFontSizeSegmentLabel, Tokens.FontWeights.groupsScreenFontWeightSegmentLabel),
                        color = if (selected) Tokens.Colors.globalOnSurfaceLight else Tokens.Colors.globalTextPrimary,
                        textAlign = TextAlign.Center,
                    )
                }
            }
        }
    }
}
