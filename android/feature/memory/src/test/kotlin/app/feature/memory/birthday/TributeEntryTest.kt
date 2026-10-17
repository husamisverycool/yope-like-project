package app.feature.memory.birthday

import app.data.error.DataError
import app.data.model.RenderStatus
import app.feature.memory.FakeMemoryBackend.Companion.ANA
import app.feature.memory.FakeMemoryBackend.Companion.GROUP
import app.feature.memory.FakeMemoryBackend.Companion.ME
import app.feature.memory.Rows
import app.feature.memory.Scenario
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDate

/** The group screen's birthday video cards (`group_tributes`, migration 0034, MERGE FV-3). */
class TributeEntryTest {
    private val delivered = Scenario.at("2026-12-04T08:00:00Z")

    @Test fun theHonoreeFindsTheirVideoInTheGroupAfterTheDay() = runTest {
        val backend = Scenario.backend().apply {
            tributes["t-1"] = Rows.tribute(honoree = ME, delivered = delivered).copy(requestId = "r-mine")
        }
        val cards = tributeEntryCards(backend, GROUP)!!
        assertEquals(
            listOf(TributeEntryCard("t-1", forMe = true, honoreeName = "", birthday = LocalDate.of(2026, 12, 10), posterUrl = "https://signed.test/g/g-1/tributes/t-1/poster.jpg")),
            cards,
        )
    }

    @Test fun noCardBeforeDeliveryOrWhileRendering() = runTest {
        val early = Scenario.backend().apply { tributes["t-1"] = Rows.tribute(honoree = ME, delivered = null) }
        assertEquals(emptyList<TributeEntryCard>(), tributeEntryCards(early, GROUP))
        val rendering = Scenario.backend().apply { tributes["t-1"] = Rows.tribute(honoree = ME, delivered = delivered, status = RenderStatus.Pending) }
        assertEquals(emptyList<TributeEntryCard>(), tributeEntryCards(rendering, GROUP))
    }

    @Test fun aContributorGetsTheCardWithTheHonoreesNameAndOtherMembersDoNot() = runTest {
        val bystander = Scenario.backend().apply { tributes["t-1"] = Rows.tribute(honoree = ANA, delivered = delivered) }
        assertEquals(emptyList<TributeEntryCard>(), tributeEntryCards(bystander, GROUP))
        val contributor = Scenario.backend().apply {
            tributes["t-1"] = Rows.tribute(honoree = ANA, delivered = delivered)
            contributed()
        }
        val card = tributeEntryCards(contributor, GROUP)!!.single()
        assertEquals("Ana", card.honoreeName)
        assertEquals(false, card.forMe)
        assertEquals(LocalDate.of(2026, 12, 12), card.birthday)
    }

    @Test fun newestDeliveryFirst() = runTest {
        val backend = Scenario.backend().apply {
            tributes["t-old"] = Rows.tribute(id = "t-old", honoree = ME, delivered = Scenario.at("2025-12-10T08:00:00Z"))
            tributes["t-new"] = Rows.tribute(id = "t-new", honoree = ANA, delivered = delivered)
            contributed()
        }
        assertEquals(listOf("t-new", "t-old"), tributeEntryCards(backend, GROUP)!!.map { it.tributeId })
    }

    @Test fun aFailedReadKeepsWhatIsShown() = runTest {
        val backend = Scenario.backend().apply { failNext["groupTributes"] = DataError.Network }
        assertNull(tributeEntryCards(backend, GROUP))
        assertTrue(tributeEntryCards(Scenario.backend().apply { online = false }, GROUP) == null)
    }
}
