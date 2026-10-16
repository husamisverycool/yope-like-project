package app.feature.memory

import app.data.model.OnThisDayItem
import app.data.model.ProfilePrivate
import app.feature.memory.FakeMemoryBackend.Companion.ANA
import app.feature.memory.FakeMemoryBackend.Companion.BEN
import app.feature.memory.FakeMemoryBackend.Companion.CLEO
import app.feature.memory.FakeMemoryBackend.Companion.GROUP
import app.feature.memory.FakeMemoryBackend.Companion.ME
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.TestDispatcher
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.setMain
import org.junit.rules.TestWatcher
import org.junit.runner.Description
import java.time.Clock
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneOffset

/** Runs view-model coroutines on a test dispatcher. */
@OptIn(ExperimentalCoroutinesApi::class)
class MainDispatcherRule(val dispatcher: TestDispatcher = UnconfinedTestDispatcher()) : TestWatcher() {
    override fun starting(description: Description) = Dispatchers.setMain(dispatcher)
    override fun finished(description: Description) = Dispatchers.resetMain()
}

/** One group with history: the data every test starts from (synthetic; no reference content). */
object Scenario {
    val clock: Clock = Clock.fixed(FakeMemoryBackend.NOW, ZoneOffset.UTC)

    fun at(iso: String): Instant = Instant.parse(iso)

    fun backend(): FakeMemoryBackend = FakeMemoryBackend().apply {
        groups[GROUP] = Rows.group()
        profiles[ME] = Rows.profile(ME, "Jesus B")
        profiles[ANA] = Rows.profile(ANA, "Ana Lima")
        profiles[BEN] = Rows.profile(BEN, "Ben Ortiz", avatar = false)
        profiles[CLEO] = Rows.profile(CLEO, "Cleo")

        // On this day (Dec 5): one photo 1 year ago, three photos 3 years ago.
        fun memory(id: String, author: String, at: String, years: Int, w: Int = 3, h: Int = 4): OnThisDayItem {
            posts[id] = Rows.post(id, author, at(at))
            media["m-$id"] = Rows.media("m-$id", author, w, h)
            return OnThisDayItem(id, "m-$id", author, at(at), years)
        }
        onThisDay[GROUP] = listOf(
            memory("p-2025", ANA, "2025-12-05T21:34:00Z", 1),
            memory("p-2023a", BEN, "2023-12-05T19:10:00Z", 3, 4, 3),
            memory("p-2023b", ANA, "2023-12-05T12:02:00Z", 3, 3, 4),
            memory("p-2023c", ME, "2023-12-05T09:45:00Z", 3, 9, 16),
        )

        // My photos and one I am tagged in (eligible for Ana's tribute); one of Ben's I am not in.
        fun photo(id: String, author: String, at: String) {
            posts[id] = Rows.post(id, author, at(at))
            media["m-$id"] = Rows.media("m-$id", author)
        }
        photo("p-mine1", ME, "2026-11-30T10:00:00Z")
        photo("p-mine2", ME, "2026-10-02T10:00:00Z")
        photo("p-tagged", BEN, "2026-11-12T10:00:00Z")
        photo("p-other", BEN, "2026-11-20T10:00:00Z")
        tags += "p-tagged" to ME

        requests["r-1"] = Rows.request("r-1", ANA)
        requests["r-mine"] = Rows.request("r-mine", ME, LocalDate.of(2026, 12, 10))

        // Year story 2026: five most-reacted photos (one hidden by a block), two everyone-days.
        photo("p-r1", ANA, "2026-02-25T10:00:00Z")
        photo("p-r2", BEN, "2026-03-14T10:00:00Z")
        photo("p-r3", CLEO, "2026-06-01T10:00:00Z")
        photo("p-r4", ME, "2026-07-19T10:00:00Z")
        photo("p-r5", ANA, "2026-08-08T10:00:00Z")
        photo("p-r6", ANA, "2026-09-09T10:00:00Z")
        collages["col-1"] = Rows.collage("col-1", listOf("p-r1", "p-r2"))
        collages["col-2"] = Rows.collage("col-2", listOf("p-r4"))
        // The rest of the year (recap card grid): twelve more photos.
        val year = (1..12).map { n -> "p-y$n".also { photo(it, listOf(ANA, BEN, CLEO, ME)[n % 4], "2026-0${1 + n % 9}-1${n % 10}T10:00:00Z") } }
        yearStories[GROUP to 2026] = Rows.yearStory(
            Rows.storyData(
                mostReacted = listOf("p-r1", "p-r2", "p-r3", "p-r4", "p-r5", "p-r6"),
                days = listOf(Triple("2026-04-02", "col-1", listOf("p-r1", "p-r2")), Triple("2026-09-21", "col-2", listOf("p-r4"))),
            ),
            postIds = listOf("p-r1", "p-r2", "p-r3", "p-r4", "p-r5", "p-r6") + year,
        )

        // The group's history for the dice: two weeks.
        history += app.data.model.HistoryWeek(LocalDate.of(2026, 11, 30), listOf("p-mine1"))
        history += app.data.model.HistoryWeek(LocalDate.of(2026, 11, 9), listOf("p-tagged", "p-other"))

        privateRow = ProfilePrivate(ME, null, false, null, FakeMemoryBackend.NOW)
    }
}
