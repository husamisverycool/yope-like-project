// Surface: chat.reactions — any-emoji reactions on photos, never shown as numbers.
// References: references/auto/locket/store/locket-store-04.png (cluster),
// references/auto/locket/frames/locket-tt-7460656081153445163-15.000s-emoji-picker-sheet-search-popular.jpg (picker),
// references/auto/locket/frames/locket-tt-7147749171762908462-05.300s-emoji-rain-rising-behind-photo.jpg (rain).
package app.feature.social.reactions

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.GridItemSpan
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.material3.TextField
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.runtime.withFrameMillis
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.drawWithContent
import androidx.compose.ui.graphics.BlendMode
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.CompositingStrategy
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.rememberTextMeasurer
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.TextUnit
import androidx.compose.ui.unit.TextUnitType
import androidx.compose.ui.zIndex
import androidx.compose.foundation.text.BasicText
import app.data.repo.ReactionEntry
import app.designsystem.R
import app.designsystem.generated.Tokens
import app.feature.social.common.EmojiNames
import app.feature.social.common.Glyph
import app.feature.social.common.Line
import app.feature.social.common.Type
import app.feature.social.common.stringRes
import kotlin.math.cos
import kotlin.math.roundToInt
import kotlin.math.sin
import kotlin.random.Random

/** Size of the text used to measure an emoji's rendered width (a measuring reference, not a drawn size). */
private const val MEASURE_REFERENCE_SP = 100f

/**
 * One emoji drawn [width] wide. Emoji fonts differ by platform, so sizes are rendered glyph
 * widths (design/surfaces/chat.reactions.md → Platform notes): the font size is solved from a
 * measurement. Emoji keep their size at any font scale.
 */
@Composable
fun EmojiGlyph(emoji: String, width: Dp, modifier: Modifier = Modifier) {
    val measurer = rememberTextMeasurer()
    val density = LocalDensity.current
    val reference = TextUnit(MEASURE_REFERENCE_SP, TextUnitType.Sp)
    val measured = remember(emoji, density) { measurer.measure(emoji, TextStyle(fontSize = reference)).size.width.coerceAtLeast(1) }
    val target = with(density) { width.toPx() }
    val size = TextUnit(MEASURE_REFERENCE_SP * target / measured, TextUnitType.Sp)
    BasicText(emoji, modifier, style = TextStyle(fontSize = size), maxLines = 1, softWrap = false)
}

/** Directions of the outline copies around a sticker (a drawing technique for a bitmap glyph's outline). */
private const val OUTLINE_STEPS = 16

/**
 * A reaction sticker: the emoji with a `chat.reactions.dimension.clusterOutline` outline in
 * `chat.reactions.color.clusterOutline`; [size] includes the outline.
 */
@Composable
fun Sticker(emoji: String, size: Dp, outline: Dp, modifier: Modifier = Modifier) {
    val glyph = size - outline * 2
    val px = with(LocalDensity.current) { outline.toPx() }
    Box(modifier.size(size), contentAlignment = Alignment.Center) {
        for (i in 0 until OUTLINE_STEPS) {
            val a = 2 * Math.PI * i / OUTLINE_STEPS
            EmojiGlyph(
                emoji,
                glyph,
                Modifier
                    .graphicsLayer {
                        compositingStrategy = CompositingStrategy.Offscreen
                        translationX = (cos(a) * px).toFloat()
                        translationY = (sin(a) * px).toFloat()
                    }
                    .drawWithContent {
                        drawContent()
                        drawRect(Tokens.Colors.chatReactionsColorClusterOutline, blendMode = BlendMode.SrcIn)
                    },
            )
        }
        EmojiGlyph(emoji, glyph)
    }
}

/** Distinct emoji in the order they were first reacted (cluster order is BLOCKED: data order). */
fun clusterEmoji(entries: List<ReactionEntry>): List<String> = entries.map { it.emoji }.distinct()

/** The TalkBack label of a cluster: emoji names only, never a count (`chat.reactions.a11y.cluster`). */
@Composable
fun clusterLabel(entries: List<ReactionEntry>): String =
    stringRes(R.string.chat_reactions_a11y_cluster, clusterEmoji(entries).joinToString(", ") { EmojiNames.name(it) })

/**
 * Locket's cluster at a photo's bottom-left: one sticker per distinct emoji, each
 * `chat.reactions.dimension.clusterStep` right of the previous and drawn over it. No numbers, no
 * avatars, no "+N". Hidden when nobody reacted. Max visible is BLOCKED: every sticker is drawn and
 * the photo clips them.
 */
@Composable
fun ReactionCluster(entries: List<ReactionEntry>, onClick: (() -> Unit)?, modifier: Modifier = Modifier) {
    val emoji = clusterEmoji(entries)
    if (emoji.isEmpty()) return
    val label = clusterLabel(entries)
    val size = Tokens.Sizes.chatReactionsDimensionClusterEmoji
    val step = Tokens.Sizes.chatReactionsDimensionClusterStep
    Box(
        modifier
            .let { if (onClick != null) it.clickable(role = Role.Button, onClick = onClick) else it }
            // Without a tap action the cluster is read as part of its photo's label (chat.thread a11y).
            .clearAndSetSemantics {
                if (onClick != null) {
                    contentDescription = label
                    role = Role.Button
                }
            },
    ) {
        emoji.forEachIndexed { i, e ->
            Sticker(e, size, Tokens.Sizes.chatReactionsDimensionClusterOutline, Modifier.offset(x = step * i).zIndex(i.toFloat()))
        }
    }
}

/** One picker item: a section label or an emoji cell. */
private sealed interface PickerItem {
    data class Section(val label: String) : PickerItem
    data class Cell(val emoji: String, val section: Int) : PickerItem
}

/**
 * The emoji picker sheet (`chat.reactions.layout.picker`): native M3 sheet with a search field,
 * then Frequently Used, Popular and All in `chat.reactions.count.pickerColumns` columns. Tapping an
 * emoji picks it and closes the sheet.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ReactionPickerSheet(onPick: (String) -> Unit, onDismiss: () -> Unit) {
    val context = LocalContext.current
    val state = rememberModalBottomSheetState(skipPartiallyExpanded = false)
    var query by rememberSaveable { mutableStateOf("") }
    val frequent = remember { EmojiCatalog.recent(context) }
    val all = remember { EmojiCatalog.all(context) }
    val frequentLabel = stringRes(R.string.chat_reactions_picker_frequent)
    val popularLabel = stringRes(R.string.chat_reactions_picker_popular)
    val allLabel = stringRes(R.string.chat_reactions_picker_all)
    val items: List<PickerItem> = remember(query, frequent, all) {
        if (query.isNotBlank()) {
            val q = query.trim().lowercase()
            (EmojiCatalog.popular + all).distinct().filter { EmojiNames.name(it).contains(q) }.map<String, PickerItem> { PickerItem.Cell(it, 0) }
        } else buildList<PickerItem> {
            if (frequent.isNotEmpty()) {
                add(PickerItem.Section(frequentLabel))
                frequent.forEach { add(PickerItem.Cell(it, 1)) }
            }
            add(PickerItem.Section(popularLabel))
            EmojiCatalog.popular.forEach { add(PickerItem.Cell(it, 2)) }
            if (all.isNotEmpty()) {
                add(PickerItem.Section(allLabel))
                all.forEach { add(PickerItem.Cell(it, 3)) }
            }
        }
    }
    ModalBottomSheet(onDismissRequest = onDismiss, sheetState = state) {
        Column(Modifier.fillMaxWidth()) {
            TextField(
                value = query,
                onValueChange = { query = it },
                singleLine = true,
                placeholder = { Text(stringRes(R.string.chat_reactions_picker_search)) },
                leadingIcon = { Glyph(Tokens.Icons.globalSearch, MaterialTheme.colorScheme.onSurfaceVariant) },
                modifier = Modifier.fillMaxWidth().padding(horizontal = Tokens.Sizes.globalScreenMargin),
            )
            LazyVerticalGrid(columns = GridCells.Fixed(Tokens.Counts.chatReactionsCountPickerColumns), modifier = Modifier.fillMaxWidth()) {
                items(items, span = { item -> if (item is PickerItem.Section) GridItemSpan(maxLineSpan) else GridItemSpan(1) }, key = { item ->
                    when (item) {
                        is PickerItem.Section -> "s:" + item.label
                        is PickerItem.Cell -> "c:${item.section}:${item.emoji}"
                    }
                }) { item ->
                    when (item) {
                        is PickerItem.Section -> Line(
                            item.label,
                            Type.style(Tokens.FontSizes.chatReactionsFontSizePickerSection, Tokens.FontWeights.chatReactionsFontWeightPickerSection),
                            Tokens.Colors.globalTextSecondary,
                            Modifier.padding(horizontal = Tokens.Sizes.globalScreenMargin).semantics { heading() },
                        )
                        is PickerItem.Cell -> {
                            val name = EmojiNames.name(item.emoji)
                            Box(
                                Modifier.fillMaxWidth()
                                    .clickable(role = Role.Button) {
                                        EmojiCatalog.remember(context, item.emoji)
                                        onPick(item.emoji)
                                    }
                                    .clearAndSetSemantics { contentDescription = name; role = Role.Button },
                                contentAlignment = Alignment.Center,
                            ) { EmojiGlyph(item.emoji, Tokens.Sizes.chatReactionsDimensionPickerEmoji) }
                        }
                    }
                }
            }
        }
    }
}

/**
 * Emoji rain after you react (`chat.reactions.layout.rainPath`): `chat.reactions.count.rainCopies`
 * copies rise from just below the bottom edge to just past the top, one every
 * `chat.reactions.duration.rainSpawnInterval`, each taking `chat.reactions.duration.rainTravel`.
 * The speed curve is BLOCKED (`chat.reactions.easing.rain`): callers draw it only in development
 * builds (constant speed) and never under Reduce Motion. Not interactive; hidden from accessibility.
 */
@Composable
fun EmojiRain(emoji: String, key: Any, onFinished: () -> Unit, modifier: Modifier = Modifier) {
    val copies = Tokens.Counts.chatReactionsCountRainCopies
    val spawn = Tokens.Durations.chatReactionsDurationRainSpawnInterval
    val travel = Tokens.Durations.chatReactionsDurationRainTravel
    val total = Tokens.Durations.chatReactionsDurationRainTotal
    val xs = remember(key) { List(copies) { Random.nextFloat() } }
    var elapsed by remember(key) { mutableLongStateOf(0L) }
    LaunchedEffect(key) {
        val start = withFrameMillis { it }
        while (elapsed < total) withFrameMillis { now -> elapsed = now - start }
        onFinished()
    }
    BoxWithConstraints(modifier.fillMaxSize().clearAndSetSemantics { }) {
        val density = LocalDensity.current
        val size = Tokens.Sizes.chatReactionsDimensionRainEmoji
        val w = with(density) { maxWidth.toPx() }
        val h = with(density) { maxHeight.toPx() }
        val s = with(density) { size.toPx() }
        for (i in 0 until copies) {
            val progress = (elapsed - i * spawn).toFloat() / travel
            if (progress < 0f || progress > 1f) continue
            val y = h - progress * (h + s)
            val x = xs[i] * (w - s).coerceAtLeast(0f)
            EmojiGlyph(emoji, size, Modifier.offset { IntOffset(x.roundToInt(), y.roundToInt()) })
        }
    }
}

/**
 * The reactions list ("Activity"): who reacted with what, never a count. Its row layout and order
 * are BLOCKED (`chat.reactions.layout.activitySheet`): callers open it only in development builds,
 * as a native sheet with one platform list line per reaction, in data order.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ActivitySheet(entries: List<ReactionEntry>, me: String?, nameOf: (String) -> String, posterName: String, onDismiss: () -> Unit) {
    val state = rememberModalBottomSheetState(skipPartiallyExpanded = false)
    ModalBottomSheet(onDismissRequest = onDismiss, sheetState = state) {
        Column(Modifier.fillMaxWidth().padding(horizontal = Tokens.Sizes.globalScreenMargin)) {
            Text(stringRes(R.string.chat_reactions_activity_title), style = MaterialTheme.typography.headlineSmall, modifier = Modifier.semantics { heading() })
            if (entries.isEmpty()) {
                Text(stringRes(R.string.chat_reactions_empty), style = MaterialTheme.typography.bodyLarge)
            } else {
                LazyColumn {
                    items(entries, key = { it.userId + it.emoji }) { entry ->
                        val line = if (entry.userId == me) stringRes(R.string.chat_reactions_activity_rowmine, entry.emoji, posterName)
                        else stringRes(R.string.chat_reactions_activity_row, nameOf(entry.userId), entry.emoji)
                        Text(line, style = MaterialTheme.typography.bodyLarge)
                    }
                }
            }
        }
    }
}

/** Optimistic reaction rows: [entries] plus `(me, emoji)` unless already there. */
fun withReaction(entries: List<ReactionEntry>, me: String, emoji: String): List<ReactionEntry> =
    if (entries.any { it.userId == me && it.emoji == emoji }) entries else entries + ReactionEntry(me, emoji)

/** Removes `(me, emoji)` (the optimistic row after a failed `react`). */
fun withoutReaction(entries: List<ReactionEntry>, me: String, emoji: String): List<ReactionEntry> =
    entries.filterNot { it.userId == me && it.emoji == emoji }

