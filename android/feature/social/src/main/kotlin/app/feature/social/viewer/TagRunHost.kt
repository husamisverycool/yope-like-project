// Surface: tagging (memory group) as hosted by photo.viewer — design/surfaces/tagging.md, photo.viewer.md (footer line 2)
// References: references/auto/retro/press/tc-2023-07-retro-2b.jpg phone 2 (footer date line),
// references/auto/retro/apk/retro-android-2026.10.1150-strings.txt (" · with ", "In this photo", "Remove tag").
package app.feature.social.viewer

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.withStyle
import app.designsystem.R
import app.designsystem.generated.Tokens
import app.feature.social.common.Formats
import app.feature.social.common.SystemAppearance
import app.feature.social.common.photoModel
import app.feature.social.common.stringRes
import app.ui.components.Capsule
import app.ui.components.CapsuleStyle
import app.ui.components.EmptyState
import app.ui.components.HeaderAction
import app.ui.components.PeopleRow
import app.ui.components.PrimaryButton
import app.ui.system.DsBottomSheet
import app.ui.system.SheetHeader

/*
 * The memory group owns the tag run and its sheet (tagging.md: "The control lives in the photo.viewer footer
 * (C-22), placed by the photo.viewer pass; tagging owns its content, the sheet and the behaviour"). Its Android
 * pass is rebuilding them in parallel; until `:feature:memory` publishes the composables, the viewer draws them
 * here from tagging.md — this file is the one place to switch to the memory group's run and sheet.
 */

/**
 * The footer run's text, appended after the date and " · " (tagging.md A): nobody tagged → `tagging.toggle`
 * ("I'm in this") in `color.global.textOnMedia`; someone tagged → `tagging.with` ("with {names}", the names in
 * `fontWeight.global.listTitle`, joined by the platform list formatter) in the footer's secondary colour.
 */
@Composable
fun tagRunText(names: List<String>): AnnotatedString {
    if (names.isEmpty()) {
        val toggle = stringRes(R.string.tagging_toggle)
        return buildAnnotatedString { withStyle(SpanStyle(color = Tokens.Colors.globalTextOnMedia)) { append(toggle) } }
    }
    val joined = Formats.nameList(names)
    val text = stringRes(R.string.tagging_with, joined)
    val at = text.indexOf(joined)
    return buildAnnotatedString {
        if (at < 0) {
            append(text)
        } else {
            append(text.substring(0, at))
            withStyle(SpanStyle(fontWeight = Tokens.FontWeights.fontWeightGlobalListTitle)) { append(joined) }
            append(text.substring(at + joined.length))
        }
    }
}

/** A tagged member of the "In this photo" sheet. */
data class TaggedPerson(val userId: String, val firstName: String, val avatarPath: String?, val me: Boolean)

/**
 * The "In this photo" sheet (tagging.md B; C-29 page sheet in the system appearance): `tagging.sheet.title`
 * (`sheetTitle`) with the close circle; C-16 rows (avatar `size.global.avatarPicker`, first name `listTitle`);
 * your row ends in the C-06 outline capsule `tagging.remove`; empty → `tagging.sheet.empty` (C-27 title); when
 * you are not tagged, the C-05 primary capsule `tagging.toggle` at the bottom.
 */
@Composable
fun InThisPhotoSheet(people: List<TaggedPerson>, taggedByMe: Boolean, onTag: (Boolean) -> Unit, onDismiss: () -> Unit) {
    SystemAppearance {
        DsBottomSheet(onDismissRequest = onDismiss) {
            SheetHeader(
                stringRes(R.string.tagging_sheet_title),
                close = HeaderAction(Tokens.Icons.globalClose, stringRes(R.string.photo_viewer_a11y_close), onDismiss),
            )
            Spacer(Modifier.height(Tokens.Sizes.globalSectionHeaderToContent))
            if (people.isEmpty()) {
                Box(Modifier.fillMaxWidth().padding(vertical = Tokens.Sizes.globalSectionGap), contentAlignment = Alignment.Center) {
                    EmptyState(stringRes(R.string.tagging_sheet_empty), null)
                }
            } else {
                Column(verticalArrangement = Arrangement.spacedBy(Tokens.Sizes.globalListGap)) {
                    people.forEach { p ->
                        Box(Modifier.fillMaxWidth()) {
                            PeopleRow(name = p.firstName, avatar = photoModel(p.avatarPath), modifier = Modifier.align(Alignment.CenterStart))
                            if (p.me) {
                                Capsule(
                                    stringRes(R.string.tagging_remove),
                                    { onTag(false) },
                                    Modifier.align(Alignment.CenterEnd).padding(end = Tokens.Sizes.globalScreenMargin),
                                    style = CapsuleStyle.Outline,
                                )
                            }
                        }
                    }
                }
            }
            if (!taggedByMe) {
                Spacer(Modifier.height(Tokens.Sizes.globalSectionGap))
                PrimaryButton(
                    stringRes(R.string.tagging_toggle),
                    { onTag(true) },
                    Modifier.padding(horizontal = Tokens.Sizes.globalButtonMarginH),
                )
            }
            Spacer(Modifier.height(Tokens.Sizes.globalButtonMarginH))
        }
    }
}

/** Cross-fades a footer run change (`duration.global.crossfade`). */
@Composable
fun TagRunCrossfade(text: AnnotatedString, content: @Composable (AnnotatedString) -> Unit) {
    AnimatedContent(text, transitionSpec = { fadeIn(app.ui.foundation.DsMotion.crossfade()) togetherWith fadeOut(app.ui.foundation.DsMotion.crossfade()) }, label = "tagRun") { content(it) }
}
