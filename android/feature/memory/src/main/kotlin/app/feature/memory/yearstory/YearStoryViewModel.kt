package app.feature.memory.yearstory

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import app.data.model.Media
import app.data.model.RenderStatus
import app.designsystem.generated.Tokens
import app.feature.memory.common.Failure
import app.feature.memory.common.MemoryBackend
import app.feature.memory.common.attempt
import app.feature.memory.common.failureOf
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.contentOrNull
import kotlinx.serialization.json.intOrNull
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import java.time.Clock
import java.time.LocalDate
import java.time.ZoneId

/** `year_stories.data` as written by the worker (`YearStoryData` v1, backend/worker/src/jobs/year.ts). */
data class YearStoryData(
    val year: Int,
    val timeZone: String,
    /** Group-level number (docs/SPEC_FLAGS.md T3). */
    val momentsShared: Int,
    /** 1-12, or null. */
    val busiestMonth: Int?,
    /** Post ids, most-reacted first; never with numbers (T2). */
    val mostReacted: List<String>,
    val everyoneDays: List<EveryoneDay>,
) {
    data class EveryoneDay(val localDate: LocalDate, val collageId: String, val postIds: List<String>)

    companion object {
        /** Version 1 only; anything else reads as no data. */
        fun parse(json: JsonElement?): YearStoryData? = runCatching {
            val o = json as? JsonObject ?: return null
            if (o["version"]?.jsonPrimitive?.intOrNull != 1) return null
            YearStoryData(
                year = o.getValue("year").jsonPrimitive.intOrNull ?: return null,
                timeZone = o["time_zone"]?.jsonPrimitive?.contentOrNull ?: "UTC",
                momentsShared = o["moments_shared"]?.jsonPrimitive?.intOrNull ?: 0,
                busiestMonth = (o["busiest_month"] as? JsonObject)?.get("month")?.jsonPrimitive?.intOrNull?.takeIf { it in 1..12 },
                mostReacted = o["most_reacted"]?.jsonArray?.mapNotNull { it.jsonPrimitive.contentOrNull }.orEmpty(),
                everyoneDays = o["everyone_days"]?.jsonArray?.mapNotNull { e ->
                    val d = e.jsonObject
                    val date = d["local_date"]?.jsonPrimitive?.contentOrNull?.let(LocalDate::parse) ?: return@mapNotNull null
                    val collage = d["collage_id"]?.jsonPrimitive?.contentOrNull ?: return@mapNotNull null
                    EveryoneDay(date, collage, d["post_ids"]?.jsonArray?.mapNotNull { it.jsonPrimitive.contentOrNull }.orEmpty())
                }.orEmpty(),
            )
        }.getOrNull()
    }
}

/** One card of the story, in order (design/surfaces/year.story.md, B "Cards, in order"). */
sealed interface StoryCard {
    /** Fact cards carry the share row and become share images (`layout.year.story.share`). */
    val shareable: Boolean get() = false

    data object Intro : StoryCard
    data object MomentsSetup : StoryCard
    data class Moments(val groupName: String, val count: Int) : StoryCard { override val shareable get() = true }
    data class BusiestMonth(val month: Int) : StoryCard { override val shareable get() = true }
    data object MostReactedSetup : StoryCard

    /** One most-reacted photo, in the worker's order — no number, rank or reaction glyph. */
    data class MostReactedPhoto(val postId: String, val url: String?, val name: String, val date: LocalDate) : StoryCard {
        override val shareable get() = true
    }
    data object TogetherSetup : StoryCard

    /** A day when everyone answered the daily invitation: its collage, fitted. */
    data class TogetherDay(val collageId: String, val url: String?, val date: LocalDate, val postIds: List<String>) : StoryCard {
        override val shareable get() = true
    }
    data object Teaser : StoryCard
    data object Outro : StoryCard

    /** The last screen: share-card carousel, Share pill, Replay from beginning. */
    data object Summary : StoryCard
}

sealed interface YearStoryState {
    data object Loading : YearStoryState
    data class Failed(val offline: Boolean) : YearStoryState
    data class Story(val cards: List<StoryCard>, val index: Int) : YearStoryState {
        val card: StoryCard get() = cards[index]
        val shareCards: List<StoryCard> get() = cards.filter { it.shareable }
    }
}

/**
 * `year.story`: Wrapped 2024 tap-through, one fact per card. Tap-only while
 * `duration.year.story.card` is BLOCKED (no auto-advance, no pause). No writes; share images are
 * rendered on the device.
 */
class YearStoryViewModel(
    private val groupId: String,
    private val year: Int,
    private val backend: MemoryBackend,
    private val clock: Clock = Clock.systemUTC(),
) : ViewModel() {
    private val _state = MutableStateFlow<YearStoryState>(YearStoryState.Loading)
    val state: StateFlow<YearStoryState> = _state.asStateFlow()
    private var load: Job? = null

    init {
        retry()
        viewModelScope.launch { backend.postDeletions(groupId).collect(::onPostDeleted) }
    }

    fun retry() {
        load?.cancel()
        _state.value = YearStoryState.Loading
        load = viewModelScope.launch {
            if (!backend.isOnline()) {
                _state.value = YearStoryState.Failed(offline = true)
                return@launch
            }
            _state.value = attempt { loadCards(backend, groupId, year) }
                .map { cards -> if (cards == null) YearStoryState.Failed(offline = false) else YearStoryState.Story(cards, 0) }
                .getOrElse { YearStoryState.Failed(offline = failureOf(it) == Failure.Offline) }
        }
    }

    /** Right half: next card (nothing on the summary). */
    fun next() = _state.update { s -> if (s is YearStoryState.Story && s.index < s.cards.lastIndex) s.copy(index = s.index + 1) else s }

    /** Left half: previous card (nothing on the first). */
    fun previous() = _state.update { s -> if (s is YearStoryState.Story && s.index > 0) s.copy(index = s.index - 1) else s }

    /** "Replay from beginning". */
    fun replay() = _state.update { s -> if (s is YearStoryState.Story) s.copy(index = 0) else s }

    /** `post_deleted`: drop that card (and a setup card left without cards to introduce). */
    fun onPostDeleted(postId: String) = _state.update { s ->
        if (s !is YearStoryState.Story) return@update s
        val current = s.card
        val kept = s.cards.filterNot { (it is StoryCard.MostReactedPhoto && it.postId == postId) || (it is StoryCard.TogetherDay && postId in it.postIds) }
        val cards = kept.filterNot { c ->
            (c == StoryCard.MostReactedSetup && kept.none { it is StoryCard.MostReactedPhoto }) ||
                (c == StoryCard.TogetherSetup && kept.none { it is StoryCard.TogetherDay })
        }
        val index = cards.indexOf(current).takeIf { it >= 0 } ?: s.index.coerceAtMost(cards.lastIndex)
        s.copy(cards = cards, index = index)
    }

    companion object {
        /** The cards for the group's story of [year]; null when there is no ready story. */
        suspend fun loadCards(backend: MemoryBackend, groupId: String, year: Int): List<StoryCard>? {
            val story = backend.yearStory(groupId, year) ?: return null
            if (story.status != RenderStatus.Ready) return null
            val data = YearStoryData.parse(story.data) ?: return null
            val zone = runCatching { ZoneId.of(data.timeZone) }.getOrDefault(ZoneId.of("UTC"))
            val groupName = backend.group(groupId)?.name.orEmpty()
            val listLength = Tokens.Counts.yearStoryListLength

            // Most-reacted: the first listLength ids, in order; posts hidden by a block are skipped.
            val ids = data.mostReacted.take(listLength)
            val posts = backend.posts(ids).associateBy { it.id }
            val media = backend.media(posts.values.map { it.mediaId }).associateBy { it.id }
            val names = backend.profiles(posts.values.map { it.authorId }.distinct()).associate { it.id to it.firstName.orEmpty() }
            val days = data.everyoneDays.take(listLength)
            val collages = backend.collages(days.map { it.collageId }).associateBy { it.id }
            val urls = backend.signedUrls(
                media.values.map { it.imagePath(Media.Rendition.Display) } + collages.values.mapNotNull { it.imagePath },
            )
            val photos = ids.mapNotNull { id ->
                val post = posts[id] ?: return@mapNotNull null
                val m = media[post.mediaId] ?: return@mapNotNull null
                StoryCard.MostReactedPhoto(id, urls[m.imagePath(Media.Rendition.Display)], names[post.authorId].orEmpty(), post.createdAt.atZone(zone).toLocalDate())
            }
            val together = days.mapNotNull { day ->
                val collage = collages[day.collageId] ?: return@mapNotNull null
                StoryCard.TogetherDay(collage.id, collage.imagePath?.let(urls::get), day.localDate, day.postIds)
            }
            return buildList {
                add(StoryCard.Intro)
                add(StoryCard.MomentsSetup)
                add(StoryCard.Moments(groupName, data.momentsShared))
                data.busiestMonth?.let { add(StoryCard.BusiestMonth(it)) }
                if (photos.isNotEmpty()) {
                    add(StoryCard.MostReactedSetup)
                    addAll(photos)
                }
                if (together.isNotEmpty()) {
                    add(StoryCard.TogetherSetup)
                    addAll(together)
                }
                add(StoryCard.Teaser)
                add(StoryCard.Outro)
                add(StoryCard.Summary)
            }
        }
    }
}
