package app.feature.memory.yearstory

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import app.data.model.Media
import app.data.model.RenderStatus
import app.designsystem.generated.Tokens
import app.feature.memory.common.Failure
import app.feature.memory.common.MemoryBackend
import app.feature.memory.common.MemoryCache
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
    /**
     * The photos at least one member tagged themselves in ("I'm in this"), in time order; ids only — no names, no counts
     * (the cards say who is in each). Empty in stories computed before 2026-10-17.
     */
    val selfTagged: List<String> = emptyList(),
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
                selfTagged = o["self_tagged"]?.jsonArray?.mapNotNull { it.jsonPrimitive.contentOrNull }.orEmpty(),
            )
        }.getOrNull()
    }
}

/** One card of the story, in order (design/surfaces/year.story.md, B "Cards, in order"). */
sealed interface StoryCard {
    /**
     * Cards with the Share pill: the fact cards, the collages, the outro and the summary (group pieces made for sharing),
     * and a most-reacted photo only when it is your own (owner decision 12: someone else's photo never leaves the app).
     */
    val shareable: Boolean get() = false

    /** 1: "Year in Photos" + "{group} · {year}". */
    data class Intro(val groupName: String, val year: Int) : StoryCard

    /** 2: "Let's look back at your 52 weeks". */
    data object LookBack : StoryCard

    /** 3: photos the group shared this year (group-level, T3). */
    data class Moments(val groupName: String, val count: Int) : StoryCard { override val shareable get() = true }

    /** 4: the busiest month. */
    data class BusiestMonth(val month: Int) : StoryCard { override val shareable get() = true }

    /** 5: "The moments you reacted to most". */
    data object MostReactedSetup : StoryCard

    /** A photo card (full bleed, the date and a trailing line); shared only when it is your own (owner decision 12). */
    sealed interface Photo : StoryCard {
        val postId: String
        val url: String?
        /** The poster's first name. */
        val name: String
        val date: LocalDate
        val isMine: Boolean
        override val shareable get() = isMine
    }

    /** 6…10: one most-reacted photo, in the worker's order — no number, rank or reaction glyph (T2). [isMine]: you posted it. */
    data class MostReactedPhoto(
        override val postId: String,
        override val url: String?,
        override val name: String,
        override val date: LocalDate,
        override val isMine: Boolean = false,
    ) : Photo

    /** "The moments you were in": the photos members tagged themselves in (self-tags power the year story). */
    data object TaggedSetup : StoryCard

    /** One self-tagged photo, in time order: [names] = who tagged themselves in it (`tagging.with`), never a count. */
    data class TaggedPhoto(
        override val postId: String,
        override val url: String?,
        override val name: String,
        override val date: LocalDate,
        val names: List<String>,
        override val isMine: Boolean = false,
    ) : Photo

    /** 11: "You didn't go through these moments alone" + "Some days, everyone was there". */
    data object TogetherSetup : StoryCard

    /** 12…16: a day everyone answered the daily invitation: its collage, fitted, never cropped. */
    data class TogetherDay(val collageId: String, val url: String?, val date: LocalDate, val postIds: List<String>) : StoryCard {
        override val shareable get() = true
    }

    /** 17: "Here's to another year in the books". */
    data object Outro : StoryCard { override val shareable get() = true }

    /** 18: the summary — recap card and full-bleed cover in a pager. */
    data object Summary : StoryCard { override val shareable get() = true }
}

/** A photo of the summary's recap card grid. */
data class RecapPhoto(val postId: String, val thumbUrl: String?, val name: String, val date: LocalDate)

/** What the summary and the text cards' backdrop show. */
data class StoryRecap(
    val groupName: String,
    val year: Int,
    /** The cover: the first most-reacted photo, else the first post of the year (display rendition). */
    val coverUrl: String?,
    /** Most-reacted first, then the year's posts in order, deduplicated; whole rows only (`layout.year.story.recapCard`). */
    val photos: List<RecapPhoto>,
) {
    /** Style 1 (the recap card) is offered only with at least one full row. */
    val cardOffered: Boolean get() = RecapCardMetrics.offered(photos.size)

    /** The summary's styles in pager order. */
    val styles: List<SummaryStyle> get() = if (cardOffered) listOf(SummaryStyle.Card, SummaryStyle.Cover) else listOf(SummaryStyle.Cover)
}

/** The summary's share styles (`layout.year.story.summary`). */
enum class SummaryStyle { Card, Cover }

sealed interface YearStoryState {
    data object Loading : YearStoryState
    data class Failed(val offline: Boolean) : YearStoryState

    /** [paused]: auto-advance off (the leading circle); [style] = the summary page in view. */
    data class Story(
        val cards: List<StoryCard>,
        val index: Int,
        val recap: StoryRecap,
        val paused: Boolean = false,
        val style: Int = 0,
    ) : YearStoryState {
        val card: StoryCard get() = cards[index]

        /** "3 of 12": the position among the cards before the summary. */
        val position: Int get() = index + 1
        val total: Int get() = cards.count { it != StoryCard.Summary }
    }
}

/**
 * `year.story` (design/surfaces/year.story.md): Wrapped 2024 tap-through, one fact per card, auto-advance every
 * `duration.year.story.card` while playing (the story starts playing; TalkBack running → it starts paused), ending
 * on Retro's recap preview. No writes; share images are rendered on the device.
 */
class YearStoryViewModel(
    private val groupId: String,
    private val year: Int,
    private val backend: MemoryBackend,
    private val cache: MemoryCache = MemoryCache.shared,
) : ViewModel() {
    private data class Cached(val cards: List<StoryCard>, val recap: StoryRecap)

    private val cacheKey = MemoryCache.key(backend, "yearstory", groupId, year.toString())
    private val _state = MutableStateFlow<YearStoryState>(YearStoryState.Loading)
    val state: StateFlow<YearStoryState> = _state.asStateFlow()
    private var load: Job? = null

    init {
        // Cached content first: the story as last shown paints at once; the refresh replaces it.
        cache.get<Cached>(cacheKey)?.let { _state.value = YearStoryState.Story(it.cards, 0, it.recap) }
        refresh()
        viewModelScope.launch { backend.postDeletions(groupId).collect(::onPostDeleted) }
    }

    /** "Try Again" on the error / offline block. */
    fun retry() {
        _state.value = YearStoryState.Loading
        refresh()
    }

    private fun refresh() {
        load?.cancel()
        load = viewModelScope.launch {
            val shown = _state.value is YearStoryState.Story
            if (!backend.isOnline()) {
                if (!shown) _state.value = YearStoryState.Failed(offline = true)
                return@launch
            }
            attempt { loadStory(backend, groupId, year) }
                .onSuccess { loaded ->
                    if (loaded == null) {
                        cache.remove(cacheKey)
                        _state.value = YearStoryState.Failed(offline = false)
                    } else {
                        val (cards, recap) = loaded
                        cache.put(cacheKey, Cached(cards, recap))
                        _state.update { s ->
                            if (s is YearStoryState.Story) {
                                // Keep the viewer on the same card.
                                val at = cards.indexOf(s.card).takeIf { it >= 0 } ?: s.index.coerceAtMost(cards.lastIndex)
                                s.copy(cards = cards, index = at, recap = recap, style = s.style.coerceAtMost(recap.styles.lastIndex))
                            } else {
                                YearStoryState.Story(cards, 0, recap)
                            }
                        }
                    }
                }
                .onFailure { e -> if (!shown) _state.value = YearStoryState.Failed(offline = failureOf(e) == Failure.Offline) }
        }
    }

    /** Pause / play (the leading circle on cards). */
    fun togglePause() = _state.update { s -> if (s is YearStoryState.Story) s.copy(paused = !s.paused) else s }

    /** Starts paused (TalkBack running: auto-advance would cut speech, WCAG 2.2.2). */
    fun pause() = _state.update { s -> if (s is YearStoryState.Story) s.copy(paused = true) else s }

    /** Right half / auto-advance: next card (nothing on the summary). */
    fun next() = _state.update { s -> if (s is YearStoryState.Story && s.index < s.cards.lastIndex) s.copy(index = s.index + 1) else s }

    /** Left half: previous card (nothing on the first). */
    fun previous() = _state.update { s -> if (s is YearStoryState.Story && s.index > 0) s.copy(index = s.index - 1) else s }

    /** "Watch again" (the summary's leading circle): card 1, playing. */
    fun replay() = _state.update { s -> if (s is YearStoryState.Story) s.copy(index = 0, paused = false, style = 0) else s }

    /** The summary's pager moved to style [page]. */
    fun showStyle(page: Int) = _state.update { s -> if (s is YearStoryState.Story) s.copy(style = page.coerceIn(0, s.recap.styles.lastIndex)) else s }

    /** `post_deleted`: drop that card (and a setup card left without cards to introduce), and the photo from the recap. */
    fun onPostDeleted(postId: String) = _state.update { s ->
        if (s !is YearStoryState.Story) return@update s
        val current = s.card
        val kept = s.cards.filterNot { (it is StoryCard.Photo && it.postId == postId) || (it is StoryCard.TogetherDay && postId in it.postIds) }
        val cards = kept.filterNot { c ->
            (c == StoryCard.MostReactedSetup && kept.none { it is StoryCard.MostReactedPhoto }) ||
                (c == StoryCard.TaggedSetup && kept.none { it is StoryCard.TaggedPhoto }) ||
                (c == StoryCard.TogetherSetup && kept.none { it is StoryCard.TogetherDay })
        }
        val left = s.recap.photos.filterNot { it.postId == postId }
        val recap = s.recap.copy(photos = left.take(RecapCardMetrics.shown(left.size)))
        val index = cards.indexOf(current).takeIf { it >= 0 } ?: s.index.coerceAtMost(cards.lastIndex)
        cache.put(cacheKey, Cached(cards, recap))
        s.copy(cards = cards, index = index, recap = recap, style = s.style.coerceAtMost(recap.styles.lastIndex))
    }

    companion object {
        /**
         * The cards and the recap for the group's story of [year]; null when there is no ready story. Cards
         * without data are skipped; posts hidden by a block (RLS) are skipped, never replaced.
         */
        suspend fun loadStory(backend: MemoryBackend, groupId: String, year: Int): Pair<List<StoryCard>, StoryRecap>? {
            val story = backend.yearStory(groupId, year) ?: return null
            if (story.status != RenderStatus.Ready) return null
            val data = YearStoryData.parse(story.data) ?: return null
            val zone = runCatching { ZoneId.of(data.timeZone) }.getOrDefault(ZoneId.of("UTC"))
            val groupName = backend.group(groupId)?.name.orEmpty()
            val listLength = Tokens.Counts.yearStoryListLength
            val gridMax = RecapCardMetrics.columns * RecapCardMetrics.maxRows

            // Most-reacted: the first listLength ids, in order. Recap grid: most-reacted first, then the year's posts.
            val reacted = data.mostReacted.take(listLength)
            val candidates = (data.mostReacted + story.postIds).distinct().take(gridMax * CANDIDATE_FACTOR)
            val posts = backend.posts((reacted + candidates).distinct()).associateBy { it.id }
            val media = backend.media(posts.values.map { it.mediaId }.distinct()).associateBy { it.id }
            val names = backend.profiles(posts.values.map { it.authorId }.distinct()).associate { it.id to it.firstName.orEmpty() }
            val days = data.everyoneDays.take(listLength)
            val collages = backend.collages(days.map { it.collageId }).associateBy { it.id }
            val gridIds = candidates.filter { id -> posts[id]?.let { media[it.mediaId] } != null }.let { it.take(RecapCardMetrics.shown(it.size)) }
            val coverId = (data.mostReacted + story.postIds).firstOrNull { id -> posts[id]?.let { media[it.mediaId] } != null }
            val urls = backend.signedUrls(
                buildSet {
                    reacted.forEach { id -> posts[id]?.let { media[it.mediaId] }?.let { add(it.imagePath(Media.Rendition.Display)) } }
                    coverId?.let { id -> posts[id]?.let { media[it.mediaId] }?.let { add(it.imagePath(Media.Rendition.Display)) } }
                    gridIds.forEach { id -> posts[id]?.let { media[it.mediaId] }?.let { add(it.imagePath(Media.Rendition.Thumb)) } }
                    collages.values.mapNotNullTo(this) { it.imagePath }
                },
            )
            fun displayUrl(id: String): String? = posts[id]?.let { media[it.mediaId] }?.let { urls[it.imagePath(Media.Rendition.Display)] }
            val photos = reacted.mapNotNull { id ->
                val post = posts[id] ?: return@mapNotNull null
                if (media[post.mediaId] == null) return@mapNotNull null
                StoryCard.MostReactedPhoto(
                    id, displayUrl(id), names[post.authorId].orEmpty(), post.createdAt.atZone(zone).toLocalDate(),
                    isMine = backend.currentUserId != null && post.authorId == backend.currentUserId,
                )
            }
            // Self-tagged photos not already shown above, spread evenly over the year; each says who is in it.
            val tagged = taggedPhotos(backend, data, zone, exclude = photos.map { it.postId }.toSet(), known = media)
            val together = days.mapNotNull { day ->
                val collage = collages[day.collageId] ?: return@mapNotNull null
                StoryCard.TogetherDay(collage.id, collage.imagePath?.let(urls::get), day.localDate, day.postIds)
            }
            val recap = StoryRecap(
                groupName = groupName,
                year = year,
                coverUrl = coverId?.let(::displayUrl),
                photos = gridIds.map { id ->
                    val post = posts.getValue(id)
                    RecapPhoto(id, urls[media.getValue(post.mediaId).imagePath(Media.Rendition.Thumb)], names[post.authorId].orEmpty(), post.createdAt.atZone(zone).toLocalDate())
                },
            )
            val cards = buildList {
                add(StoryCard.Intro(groupName, year))
                add(StoryCard.LookBack)
                add(StoryCard.Moments(groupName, data.momentsShared))
                data.busiestMonth?.let { add(StoryCard.BusiestMonth(it)) }
                if (photos.isNotEmpty()) {
                    add(StoryCard.MostReactedSetup)
                    addAll(photos)
                }
                if (tagged.isNotEmpty()) {
                    add(StoryCard.TaggedSetup)
                    addAll(tagged)
                }
                if (together.isNotEmpty()) {
                    add(StoryCard.TogetherSetup)
                    addAll(together)
                }
                add(StoryCard.Outro)
                add(StoryCard.Summary)
            }
            return cards to recap
        }

        /**
         * The self-tagged photos (`data.self_tagged`) not in [exclude], at most `count.year.story.listLength` spread evenly
         * over the year, in time order; posts hidden by a block (RLS) are skipped. Each carries the first names of the
         * members who tagged themselves in it (the tags the caller can read) — names only, never a count or a ranking.
         */
        suspend fun taggedPhotos(backend: MemoryBackend, data: YearStoryData, zone: ZoneId, exclude: Set<String>, known: Map<String, Media> = emptyMap()): List<StoryCard.TaggedPhoto> {
            val wanted = data.selfTagged.filter { it !in exclude }
            if (wanted.isEmpty()) return emptyList()
            val order = wanted.withIndex().associate { it.value to it.index }
            val posts = backend.posts(wanted).filter { it.id in order }.sortedBy { order.getValue(it.id) }
            val missing = posts.map { it.mediaId }.filter { it !in known }.distinct()
            val media = known + (if (missing.isEmpty()) emptyMap() else backend.media(missing).associateBy { it.id })
            val picked = spread(posts.filter { media[it.mediaId] != null }, Tokens.Counts.yearStoryListLength)
            if (picked.isEmpty()) return emptyList()
            val inIt = picked.associate { p -> p.id to backend.postTags(p.id).map { it.userId } }
            val names = backend.profiles((inIt.values.flatten() + picked.map { it.authorId }).distinct()).associate { it.id to it.firstName.orEmpty() }
            val urls = backend.signedUrls(picked.mapNotNull { p -> media[p.mediaId]?.imagePath(Media.Rendition.Display) }.toSet())
            return picked.mapNotNull { p ->
                val people = inIt[p.id].orEmpty().mapNotNull { names[it]?.takeIf(String::isNotEmpty) }
                if (people.isEmpty()) return@mapNotNull null // every tag removed (or hidden) since the story was computed
                StoryCard.TaggedPhoto(
                    p.id, media[p.mediaId]?.let { urls[it.imagePath(Media.Rendition.Display)] }, names[p.authorId].orEmpty(),
                    p.createdAt.atZone(zone).toLocalDate(), people,
                    isMine = backend.currentUserId != null && p.authorId == backend.currentUserId,
                )
            }
        }

        /** [count] items spread evenly over [items] (first and last included), in order. */
        fun <T> spread(items: List<T>, count: Int): List<T> {
            if (items.size <= count || count <= 1) return items.take(count.coerceAtLeast(0))
            val step = (items.size - 1).toDouble() / (count - 1)
            return (0 until count).map { items[Math.round(it * step).toInt()] }
        }

        /** Candidate ids read for the recap grid: twice the grid, so posts hidden by a block can be skipped. */
        private const val CANDIDATE_FACTOR = 2
    }
}
