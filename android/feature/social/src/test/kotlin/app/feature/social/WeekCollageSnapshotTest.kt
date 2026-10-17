package app.feature.social

import app.data.model.GroupCollage
import app.feature.social.FakeSocialData.Companion.GROUP
import app.feature.social.week.HistoryNav
import app.feature.social.week.HistoryViewModel
import app.feature.social.week.RecapNav
import app.feature.social.week.RecapViewModel
import app.feature.social.week.WeekHistoryContent
import app.feature.social.week.WeekRecapPreview
import org.junit.Test
import java.time.LocalDate

/**
 * The same-moment collage in the group's history (migration 0033): its tile on its day in `week.history`, and its page
 * after the cover in `week.recap` (the year story's collage card).
 */
class WeekCollageSnapshotTest : SnapshotBase() {
    private val recapNav = RecapNav({}, {}, {}, {}, { _, _ -> }, {})
    private val historyNav = HistoryNav({}, { _, _ -> }, {}, {}, {})

    private fun collage(id: String, day: String) = GroupCollage(
        collageId = id,
        invitationId = "inv-$id",
        localDate = LocalDate.parse(day),
        imagePath = "g/$GROUP/collages/$id/1/display-1.jpg",
        widgetPath = "g/$GROUP/collages/$id/1/widget.jpg",
    )

    private fun seeded() = FakeSocialData().apply {
        seedWeek()
        val weeks = weeks.getValue(GROUP)
        weeks[0] = weeks[0].copy(collages = listOf(collage("c-1", "2026-10-13")))
        recaps["r-w"] = recaps.getValue("r-w").copy(collageIds = listOf("c-1"))
    }

    /** The current week's strip: Tuesday's collage before Tuesday's photo. */
    @Test fun historyWithCollage() {
        val data = seeded()
        snap(data) { WeekHistoryContent(HistoryViewModel(data, GROUP) { LocalDate.parse("2026-10-14") }.state.value, historyNav, {}, {}) }
    }

    /** Page 3: the week's collage fitted whole on its blurred page, its day in the footer. */
    @Test fun recapPreviewCollagePage() {
        val data = seeded()
        snap(data) { WeekRecapPreview(RecapViewModel(data, GROUP, "r-w").state.value, recapNav, {}, initialPage = 2) }
    }

    @Test fun recapPreviewCollagePageDark() {
        val data = seeded()
        snap(data, dark = true) { WeekRecapPreview(RecapViewModel(data, GROUP, "r-w").state.value, recapNav, {}, initialPage = 2) }
    }
}
