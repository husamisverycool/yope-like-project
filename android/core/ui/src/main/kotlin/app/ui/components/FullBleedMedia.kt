package app.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.paddingFrom
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBars
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.layout.FirstBaseline
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import app.designsystem.generated.Tokens
import app.ui.foundation.DsImage
import app.ui.foundation.PhotoScrimOverlay
import app.ui.foundation.centreAt
import app.ui.foundation.tapClickable
import app.ui.haptics.rememberHaptics
import app.ui.system.DsDropdownMenu
import app.ui.system.DsMenuItem
import app.ui.text.CapTop
import app.ui.text.TextRoles

/**
 * C-35 Full-bleed media page (Rewind-style): the [photo] full-bleed on `color.global.backgroundDeep`
 * (labelled [photoDescription]), `layout.global.photoScrim` at the bottom; the display date [title] (text role
 * `headerTitle`, `color.global.textOnMedia`) placed like the C-01 title below the status bar, with
 * `icon.global.chevronDown` after it when [onTitleClick] opens a picker; [subtitle] ("On this week") in text role
 * `textButton` in `color.global.textOnMedia` (Retro's reduced opacity is not measurable — Gap); top-right glass
 * "•••" (`size.global.circleButtonPhoto`) opening [menu]; at the bottom the [centre] control flanked by the glass
 * [leading] / [trailing] circles (`size.global.circleButtonLarge`, `icon.global.share` / `icon.global.random`),
 * spread evenly (their spacing is not measured), above the [tabBar] slot (C-04 with `overMedia = true`).
 */
@Composable
fun FullBleedMediaPage(
    photo: Any?,
    photoDescription: String,
    title: String,
    modifier: Modifier = Modifier,
    subtitle: String? = null,
    onTitleClick: (() -> Unit)? = null,
    titleClickLabel: String? = null,
    menu: List<DsMenuItem> = emptyList(),
    moreContentDescription: String? = null,
    leading: HeaderAction? = null,
    trailing: HeaderAction? = null,
    centre: (@Composable () -> Unit)? = null,
    tabBar: (@Composable () -> Unit)? = null,
) {
    val titleStyle = TextRoles.headerTitle
    val capMiddle = Tokens.Sizes.globalTitleTop - CapTop.height(titleStyle) / 2
    Box(modifier.fillMaxSize().background(Tokens.Colors.globalBackgroundDeep)) {
        DsImage(photo, null, Modifier.fillMaxSize().clearAndSetSemantics { contentDescription = photoDescription }, placeholder = Tokens.Colors.globalBackgroundDeep)
        PhotoScrimOverlay()
        Row(Modifier.fillMaxWidth().windowInsetsPadding(WindowInsets.statusBars).padding(horizontal = Tokens.Sizes.globalScreenMargin), verticalAlignment = Alignment.Top) {
            Column(Modifier.weight(1f)) {
                Row(
                    Modifier
                        .then(if (onTitleClick != null) Modifier.tapClickable(onClickLabel = titleClickLabel, onClick = onTitleClick) else Modifier)
                        .semantics(mergeDescendants = true) { heading() },
                ) {
                    Text(title, style = titleStyle, color = Tokens.Colors.globalTextOnMedia, modifier = Modifier.paddingFrom(FirstBaseline, before = Tokens.Sizes.globalTitleTop))
                    if (onTitleClick != null) {
                        Icon(Tokens.Icons.globalChevronDown, contentDescription = null, tint = Tokens.Colors.globalTextOnMedia, modifier = Modifier.centreAt(capMiddle).size(Tokens.Sizes.globalIcon))
                    }
                }
                if (subtitle != null) Text(subtitle, style = TextRoles.textButton, color = Tokens.Colors.globalTextOnMedia)
            }
            if (menu.isNotEmpty() && moreContentDescription != null) {
                Box(Modifier.centreAt(capMiddle)) {
                    var open by remember { mutableStateOf(false) }
                    CircleIconButton(Tokens.Icons.globalMore, moreContentDescription, { open = true }, style = CircleButtonStyle.Glass)
                    DsDropdownMenu(open, { open = false }, menu)
                }
            }
        }
        Column(Modifier.align(Alignment.BottomCenter).fillMaxWidth()) {
            if (leading != null || trailing != null || centre != null) {
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceEvenly, verticalAlignment = Alignment.CenterVertically) {
                    leading?.let { CircleIconButton(it.icon, it.contentDescription, it.onClick, style = CircleButtonStyle.GlassLarge) }
                    centre?.invoke()
                    trailing?.let { CircleIconButton(it.icon, it.contentDescription, it.onClick, style = CircleButtonStyle.GlassLarge) }
                }
            }
            tabBar?.invoke()
        }
    }
}

/**
 * Plays `haptic.global.select` once per change of [step] (a dial or scrubber position — Retro's Rewind dial ticks
 * once per memory, RP §3.8). The first composition plays nothing.
 */
@Composable
fun TickOnStep(step: Int) {
    val haptics = rememberHaptics()
    var last by remember { mutableStateOf(step) }
    LaunchedEffect(step) {
        if (step != last) {
            haptics.tick()
            last = step
        }
    }
}
